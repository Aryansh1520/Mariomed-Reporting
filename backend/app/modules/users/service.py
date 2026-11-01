from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core import login_guard
from app.core.exceptions import BadRequest, Conflict, Forbidden, NotFound, Unauthorized
from app.core.pagination import Page, PageQuery
from app.core.security import hash_password, verify_password
from app.core.validators import normalize_email, normalize_mobile
from app.modules.rbac import repository as rbac_repository
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm, PermissionScope
from app.modules.rbac.models import Role
from app.modules.rbac.principal import Principal
from app.modules.users import repository
from app.modules.users.models import User
from app.modules.users.schemas import TeamUserCreate, TeamUserRead, TeamUserUpdate, UserCreate

INVALID_CREDENTIALS = "Mobile, email or password is incorrect."
TEAM_USER_NOT_FOUND = "This user does not exist."
ROLE_NOT_ASSIGNABLE = "This role does not exist."
ADMIN_LOCKED = "The administrator account cannot be switched off."
EMAIL_OR_MOBILE_TAKEN = "A user with this email or mobile already exists."

# Checked when the identifier matches no user, so unknown and wrong-password logins take the same time.
_UNKNOWN_USER_HASH = hash_password("unknown-user")


def authenticate(db: Session, identifier: str, password: str) -> User:
    login_guard.check(identifier)
    user = _find_by_identifier(db, identifier)
    stored_hash = user.password_hash if user is not None else _UNKNOWN_USER_HASH
    password_matches = verify_password(password, stored_hash)
    if user is None or not password_matches:
        login_guard.record_failure(identifier)
        raise Unauthorized(INVALID_CREDENTIALS)
    if not user.is_active:
        raise Forbidden("This account is deactivated. Contact your admin.")
    login_guard.record_success(identifier)
    return user


def get_by_id(db: Session, user_id: int) -> User | None:
    return repository.get_by_id(db, user_id)


def count_active(db: Session) -> int:
    return repository.count_active(db)


def list_active(db: Session) -> list[User]:
    return repository.list_active(db)


def full_names(db: Session, user_ids: set[int]) -> dict[int, str]:
    return {user.id: user.full_name for user in repository.list_by_ids(db, user_ids)}


def active_by_ids(db: Session, user_ids: set[int]) -> list[User]:
    return [user for user in repository.list_by_ids(db, user_ids) if user.is_active]


def find_by_mobile(db: Session, mobile: str) -> User | None:
    return repository.get_by_mobile(db, mobile)


def find_by_identifier(db: Session, identifier: str) -> User | None:
    return _find_by_identifier(db, identifier)


def set_password(user: User, password: str) -> None:
    user.password_hash = hash_password(password)


def record_login(user: User) -> None:
    user.last_login_at = datetime.now(UTC)


def create_user(db: Session, role_id: int, data: UserCreate, created_by: int | None) -> User:
    _ensure_unique(db, data.email, data.mobile)
    return repository.add(
        db,
        User(
            role_id=role_id,
            full_name=data.full_name,
            email=data.email,
            mobile=data.mobile,
            password_hash=hash_password(data.password),
            created_by=created_by,
            updated_by=created_by,
        ),
    )


def list_team(db: Session, principal: Principal, query: PageQuery) -> Page[TeamUserRead]:
    rbac_service.require_scope(principal, Perm.USERS_READ)
    users, total = repository.list_page(
        db, _only_own_account(principal, Perm.USERS_READ), query.offset, query.page_size
    )
    roles = rbac_service.roles_by_id(db)
    return Page[TeamUserRead](
        items=[_to_read(user, roles[user.role_id]) for user in users],
        total=total,
        page=query.page,
        page_size=query.page_size,
    )


def get_team_user(db: Session, principal: Principal, user_id: int) -> TeamUserRead:
    user = _team_user(db, principal, user_id, Perm.USERS_READ)
    return _to_read(user, rbac_service.roles_by_id(db)[user.role_id])


def create_team_user(db: Session, principal: Principal, data: TeamUserCreate) -> TeamUserRead:
    rbac_service.require_scope(principal, Perm.USERS_MANAGE)
    role = _assignable_role(db, data.role_code)
    _ensure_unique(db, data.email, data.mobile)
    user = repository.add(
        db,
        User(
            role_id=role.id,
            full_name=data.full_name,
            email=data.email,
            mobile=data.mobile,
            password_hash=hash_password(data.password),
            created_by=principal.user_id,
            updated_by=principal.user_id,
        ),
    )
    db.commit()
    return _to_read(user, role)


def update_team_user(
    db: Session, principal: Principal, user_id: int, data: TeamUserUpdate
) -> TeamUserRead:
    rbac_service.require_scope(principal, Perm.USERS_MANAGE)
    user = _team_user(db, principal, user_id, Perm.USERS_MANAGE)
    if data.email is not None or data.mobile is not None:
        _ensure_unique(db, data.email or user.email, data.mobile or user.mobile, exclude_id=user.id)
    if data.full_name is not None:
        user.full_name = data.full_name
    if data.email is not None:
        user.email = data.email
    if data.mobile is not None:
        user.mobile = data.mobile
    if data.role_code is not None:
        user.role_id = _assignable_role(db, data.role_code).id
    if data.password is not None:
        user.password_hash = hash_password(data.password)
    user.updated_by = principal.user_id
    db.commit()
    return _to_read(user, rbac_service.roles_by_id(db)[user.role_id])


def set_team_user_active(
    db: Session, principal: Principal, user_id: int, is_active: bool
) -> TeamUserRead:
    rbac_service.require_scope(principal, Perm.USERS_MANAGE)
    user = _team_user(db, principal, user_id, Perm.USERS_MANAGE)
    if not is_active and user.id == principal.user_id:
        raise BadRequest("You cannot deactivate your own account.")
    if not is_active and rbac_service.roles_by_id(db)[user.role_id].is_locked:
        raise BadRequest(ADMIN_LOCKED)
    user.is_active = is_active
    user.updated_by = principal.user_id
    db.commit()
    return _to_read(user, rbac_service.roles_by_id(db)[user.role_id])


def _only_own_account(principal: Principal, code: Perm) -> int | None:
    """Users are not owned or assigned, so a narrower scope on team permissions reaches only the caller's own account."""
    scope = rbac_service.require_scope(principal, code)
    return None if scope == PermissionScope.ALL else principal.user_id


def _team_user(db: Session, principal: Principal, user_id: int, code: Perm) -> User:
    only_user_id = _only_own_account(principal, code)
    if only_user_id is not None and only_user_id != user_id:
        raise NotFound(TEAM_USER_NOT_FOUND)
    user = repository.get_by_id(db, user_id)
    if user is None:
        raise NotFound(TEAM_USER_NOT_FOUND)
    return user


def _assignable_role(db: Session, code: str) -> Role:
    role = rbac_repository.get_role_by_code(db, code)
    if role is None:
        raise BadRequest(ROLE_NOT_ASSIGNABLE)
    return role


def _find_by_identifier(db: Session, identifier: str) -> User | None:
    value = identifier.strip()
    try:
        if "@" in value:
            return repository.get_by_email(db, normalize_email(value))
        return repository.get_by_mobile(db, normalize_mobile(value))
    except ValueError:
        return None


def _ensure_unique(db: Session, email: str, mobile: str, exclude_id: int | None = None) -> None:
    for existing in (repository.get_by_email(db, email), repository.get_by_mobile(db, mobile)):
        if existing is not None and existing.id != exclude_id:
            raise Conflict(EMAIL_OR_MOBILE_TAKEN)


def _to_read(user: User, role: Role) -> TeamUserRead:
    return TeamUserRead(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        mobile=user.mobile,
        role_code=role.code,
        role_name=role.name,
        is_active=user.is_active,
        last_login_at=user.last_login_at,
    )
