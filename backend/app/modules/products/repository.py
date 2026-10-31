from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.products.models import Product


def get_by_id(db: Session, product_id: int) -> Product | None:
    return db.get(Product, product_id)


def get_by_name_or_code(db: Session, name: str, code: str) -> list[Product]:
    return list(db.scalars(select(Product).where((Product.name == name) | (Product.code == code))))


def list_page(db: Session, offset: int, limit: int) -> tuple[list[Product], int]:
    total = db.scalar(select(func.count()).select_from(Product)) or 0
    items = list(db.scalars(select(Product).order_by(Product.name).offset(offset).limit(limit)))
    return items, total


def add(db: Session, product: Product) -> Product:
    db.add(product)
    db.flush()
    return product


def count_active(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(Product).where(Product.is_active.is_(True))) or 0


def list_by_ids(db: Session, product_ids: set[int]) -> list[Product]:
    return list(db.scalars(select(Product).where(Product.id.in_(product_ids))))
