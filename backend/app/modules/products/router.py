from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.pagination import Page, PageQuery
from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.products import service
from app.modules.products.schemas import ProductCreate, ProductRead, ProductUpdate
from app.modules.rbac.principal import Principal

router = APIRouter()


@router.get("", response_model=Page[ProductRead])
def list_products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> Page[ProductRead]:
    return service.list_products(db, principal, PageQuery(page=page, page_size=page_size))


@router.get("/{product_id}", response_model=ProductRead)
def get_product(
    product_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> ProductRead:
    return ProductRead.model_validate(service.get_product(db, principal, product_id))


@router.post("", response_model=ProductRead)
def create_product(
    body: ProductCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> ProductRead:
    return ProductRead.model_validate(service.create_product(db, principal, body))


@router.patch("/{product_id}", response_model=ProductRead)
def update_product(
    product_id: int,
    body: ProductUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> ProductRead:
    return ProductRead.model_validate(service.update_product(db, principal, product_id, body))
