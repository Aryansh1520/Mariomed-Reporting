from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Base class for all ORM models. Models are imported in app/db/models.py
    so Alembic autogenerate can see them."""
