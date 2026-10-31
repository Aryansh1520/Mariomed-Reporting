import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import BadRequest, Unauthorized
from app.core.mailer import MailError, get_mailer
from app.core.security import hash_token, new_token
from app.modules.auth import repository
from app.modules.auth.models import AuthSession, PasswordResetToken
from app.modules.auth.schemas import CurrentUserRead, LoginRequest, LoginResponse, PermissionRead
from app.modules.rbac import service as rbac_service
from app.modules.rbac.principal import Principal
from app.modules.users import service as users_service
from app.modules.users.models import User

logger = logging.getLogger(__name__)

SESSION_ENDED = "Your session has ended. Sign in again."
RESET_CODE_INVALID = "This reset code is invalid or has expired. Request a new one."


def login(db: Session, body: LoginRequest) -> LoginResponse:
    user = users_service.authenticate(db, body.identifier, body.password)

    token = new_token()
    expires_at = datetime.now(UTC) + timedelta(hours=settings.session_hours)
    session = repository.add(
        db,
        AuthSession(
            user_id=user.id,
            token_hash=hash_token(token),
            expires_at=expires_at,
            created_by=user.id,
            updated_by=user.id,
        ),
    )
    users_service.record_login(user)
    db.commit()

    principal = _principal_for(db, user, session.id)
    return LoginResponse(
        access_token=token,
        expires_at=expires_at,
        user=_profile(user, principal),
    )


def authenticate_token(db: Session, token: str) -> Principal:
    session = repository.get_by_token_hash(db, hash_token(token))
    if session is None or session.revoked_at is not None:
        raise Unauthorized(SESSION_ENDED)
    if session.expires_at <= datetime.now(UTC):
        raise Unauthorized(SESSION_ENDED)

    user = users_service.get_by_id(db, session.user_id)
    if user is None or not user.is_active:
        raise Unauthorized(SESSION_ENDED)
    return _principal_for(db, user, session.id)


def logout(db: Session, principal: Principal) -> None:
    session = repository.get_by_id(db, principal.session_id)
    if session is not None:
        session.revoked_at = datetime.now(UTC)
    db.commit()


def live_session_ids(db: Session, user_ids: list[int]) -> list[int]:
    """Sessions that still count as signed in: not revoked, not expired, and the user is still active."""
    active_ids = [
        user_id
        for user_id in user_ids
        if (user := users_service.get_by_id(db, user_id)) is not None and user.is_active
    ]
    return repository.live_session_ids(db, active_ids, datetime.now(UTC))


def current_user(db: Session, principal: Principal) -> CurrentUserRead:
    user = users_service.get_by_id(db, principal.user_id)
    if user is None:
        raise Unauthorized(SESSION_ENDED)
    return _profile(user, principal)


def request_password_reset(db: Session, identifier: str) -> None:
    """Always returns normally, so the response never reveals whether the account exists."""
    user = users_service.find_by_identifier(db, identifier)
    if user is None or not user.is_active:
        return

    token = new_token()
    expires_at = datetime.now(UTC) + timedelta(minutes=settings.password_reset_minutes)
    repository.add_reset_token(
        db,
        PasswordResetToken(
            user_id=user.id,
            token_hash=hash_token(token),
            expires_at=expires_at,
            created_by=user.id,
            updated_by=user.id,
        ),
    )
    db.commit()
    _send_reset_email(user, token)


def confirm_password_reset(db: Session, token: str, new_password: str) -> None:
    reset = repository.get_reset_token_by_hash(db, hash_token(token))
    now = datetime.now(UTC)
    if reset is None or reset.used_at is not None or reset.expires_at <= now:
        raise BadRequest(RESET_CODE_INVALID)

    user = users_service.get_by_id(db, reset.user_id)
    if user is None or not user.is_active:
        raise BadRequest(RESET_CODE_INVALID)

    users_service.set_password(user, new_password)
    reset.used_at = now
    repository.revoke_for_user(db, user.id, now)
    db.commit()


def _send_reset_email(user: User, token: str) -> None:
    body = (
        f"Hi {user.full_name},\n\n"
        "To choose a new password, open the My Mariomed app, tap Forgot password, "
        "and enter this reset code:\n\n"
        f"{token}\n\n"
        f"The code expires in {settings.password_reset_minutes} minutes and works once.\n\n"
        "If you did not ask for this, you can ignore this email."
    )
    try:
        get_mailer().send(user.email, "Reset your password", body)
    except MailError:
        # The reset row is already saved, so the user can request again. The reason is logged without the body.
        logger.error("Password reset email could not be sent.")


def _principal_for(db: Session, user: User, session_id: int) -> Principal:
    access = rbac_service.load_role_access(db, user.role_id)
    return Principal(
        user_id=user.id,
        session_id=session_id,
        role_id=user.role_id,
        role_code=access.role_code,
        role_name=access.role_name,
        permissions=access.permissions,
    )


def _profile(user: User, principal: Principal) -> CurrentUserRead:
    return CurrentUserRead(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        mobile=user.mobile,
        role_code=principal.role_code,
        role_name=principal.role_name,
        permissions=[
            PermissionRead(code=code, scope=scope) for code, scope in principal.permissions.items()
        ],
    )
