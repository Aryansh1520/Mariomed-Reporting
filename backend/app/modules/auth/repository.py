from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.modules.auth.models import AuthSession, PasswordResetToken


def add(db: Session, session: AuthSession) -> AuthSession:
    db.add(session)
    db.flush()
    return session


def get_by_id(db: Session, session_id: int) -> AuthSession | None:
    return db.get(AuthSession, session_id)


def get_by_token_hash(db: Session, token_hash: str) -> AuthSession | None:
    return db.scalar(select(AuthSession).where(AuthSession.token_hash == token_hash))


def live_session_ids(db: Session, user_ids: list[int], now: datetime) -> list[int]:
    return list(
        db.scalars(
            select(AuthSession.id).where(
                AuthSession.user_id.in_(user_ids),
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now,
            )
        )
    )


def revoke_for_user(db: Session, user_id: int, revoked_at: datetime) -> None:
    db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=revoked_at)
    )


def add_reset_token(db: Session, token: PasswordResetToken) -> PasswordResetToken:
    db.add(token)
    db.flush()
    return token


def get_open_reset_token(db: Session, user_id: int, now: datetime) -> PasswordResetToken | None:
    """The newest code that is unused and not expired. Older codes were voided when it was issued."""
    return db.scalar(
        select(PasswordResetToken)
        .where(
            PasswordResetToken.user_id == user_id,
            PasswordResetToken.used_at.is_(None),
            PasswordResetToken.expires_at > now,
        )
        .order_by(PasswordResetToken.id.desc())
        .limit(1)
    )


def void_open_reset_tokens(db: Session, user_id: int, now: datetime) -> None:
    db.execute(
        update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user_id, PasswordResetToken.used_at.is_(None))
        .values(used_at=now)
    )
