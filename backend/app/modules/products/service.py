from sqlalchemy.orm import Session

from app.core.exceptions import BadRequest, Conflict, NotFound
from app.core.pagination import Page, PageQuery
from app.modules.audit import service as audit
from app.modules.products import repository
from app.modules.products.models import Product
from app.modules.products.schemas import ProductCreate, ProductRead, ProductUpdate
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm
from app.modules.rbac.principal import Principal

PRODUCT_NOT_FOUND = "This product does not exist."
PRODUCT_TAKEN = "A product with this name or code already exists."
PRODUCT_UNAVAILABLE = "One of the products is switched off or does not exist."


def list_products(db: Session, principal: Principal, query: PageQuery) -> Page[ProductRead]:
    rbac_service.require_scope(principal, Perm.PRODUCTS_READ)
    items, total = repository.list_page(db, query.offset, query.page_size)
    return Page[ProductRead](
        items=[ProductRead.model_validate(item) for item in items],
        total=total,
        page=query.page,
        page_size=query.page_size,
    )


def create_product(db: Session, principal: Principal, data: ProductCreate) -> Product:
    rbac_service.require_scope(principal, Perm.PRODUCTS_MANAGE)
    _ensure_unique(db, data.name, data.code)
    product = repository.add(
        db,
        Product(
            name=data.name,
            code=data.code,
            description=data.description,
            created_by=principal.user_id,
            updated_by=principal.user_id,
        ),
    )
    audit.record(db, principal.user_id, "product.create", "product", product.id)
    db.commit()
    return product


def update_product(db: Session, principal: Principal, product_id: int, data: ProductUpdate) -> Product:
    rbac_service.require_scope(principal, Perm.PRODUCTS_MANAGE)
    product = _require(db, product_id)
    _ensure_unique(db, data.name or product.name, data.code or product.code, exclude_id=product.id)
    for field in ("name", "code", "description", "is_active"):
        value = getattr(data, field)
        if value is not None:
            setattr(product, field, value)
    product.updated_by = principal.user_id
    audit.record(db, principal.user_id, "product.update", "product", product.id)
    db.commit()
    return product


def get_product(db: Session, principal: Principal, product_id: int) -> Product:
    rbac_service.require_scope(principal, Perm.PRODUCTS_READ)
    return _require(db, product_id)


def _require(db: Session, product_id: int) -> Product:
    product = repository.get_by_id(db, product_id)
    if product is None:
        raise NotFound(PRODUCT_NOT_FOUND)
    return product


def _ensure_unique(db: Session, name: str, code: str, exclude_id: int | None = None) -> None:
    for existing in repository.get_by_name_or_code(db, name, code):
        if existing.id != exclude_id:
            raise Conflict(PRODUCT_TAKEN)


def require_active_products(db: Session, product_ids: set[int]) -> None:
    """For visits: every product must exist and be active. Products are switched off, never deleted."""
    products = repository.list_by_ids(db, product_ids)
    if len(products) != len(product_ids) or not all(product.is_active for product in products):
        raise BadRequest(PRODUCT_UNAVAILABLE)


def count_active(db: Session) -> int:
    return repository.count_active(db)


def product_names(db: Session, product_ids: set[int]) -> dict[int, str]:
    return {product.id: product.name for product in repository.list_by_ids(db, product_ids)}
