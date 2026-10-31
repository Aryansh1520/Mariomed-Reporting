from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.users.models import User


def get_by_id(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def count_active(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(User).where(User.is_active.is_(True))) or 0


def list_active(db: Session) -> list[User]:
    return list(db.scalars(select(User).where(User.is_active.is_(True)).order_by(User.full_name)))


def list_by_ids(db: Session, user_ids: set[int]) -> list[User]:
    return list(db.scalars(select(User).where(User.id.in_(user_ids))))


def get_by_email(db: Session, email: str) -> User | None:
    return db.scalar(select(User).where(User.email == email))


def get_by_mobile(db: Session, mobile: str) -> User | None:
    return db.scalar(select(User).where(User.mobile == mobile))


def list_page(db: Session, only_user_id: int | None, offset: int, limit: int) -> tuple[list[User], int]:
    """All users, or just one account when only_user_id is set."""
    statement = select(User)
    if only_user_id is not None:
        statement = statement.where(User.id == only_user_id)
    total = db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    items = list(db.scalars(statement.order_by(User.full_name).offset(offset).limit(limit)))
    return items, total


def add(db: Session, user: User) -> User:
    db.add(user)
    db.flush()
    return user
