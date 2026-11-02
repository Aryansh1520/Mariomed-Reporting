from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.pagination import Page
from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.contacts import service
from app.modules.contacts.schemas import (
    CategoryCreate,
    CategoryRead,
    CategoryUpdate,
    ContactCreate,
    ContactListQuery,
    ContactRead,
    ContactUpdate,
    TypeCreate,
    TypeListQuery,
    TypeRead,
    TypeUpdate,
)
from app.modules.rbac.principal import Principal

router = APIRouter()


@router.get("/categories", response_model=list[CategoryRead])
def list_categories(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[CategoryRead]:
    return service.list_categories(db, principal)


@router.post("/categories", response_model=CategoryRead)
def create_category(
    body: CategoryCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> CategoryRead:
    return service.create_category(db, principal, body)


@router.patch("/categories/{category_id}", response_model=CategoryRead)
def update_category(
    category_id: int,
    body: CategoryUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> CategoryRead:
    return service.update_category(db, principal, category_id, body)


@router.get("/types", response_model=Page[TypeRead])
def list_types(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=100),
    category_id: int | None = None,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> Page[TypeRead]:
    query = TypeListQuery(page=page, page_size=page_size, category_id=category_id)
    return service.list_types(db, principal, query)


@router.post("/types", response_model=TypeRead)
def create_type(
    body: TypeCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TypeRead:
    return service.create_type(db, principal, body)


@router.patch("/types/{type_id}", response_model=TypeRead)
def update_type(
    type_id: int,
    body: TypeUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TypeRead:
    return service.update_type(db, principal, type_id, body)


@router.get("", response_model=Page[ContactRead])
def list_contacts(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    zone_id: int | None = None,
    subzone_id: int | None = None,
    category_id: int | None = None,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> Page[ContactRead]:
    query = ContactListQuery(
        page=page,
        page_size=page_size,
        zone_id=zone_id,
        subzone_id=subzone_id,
        category_id=category_id,
    )
    return service.list_contacts(db, principal, query)


@router.post("", response_model=ContactRead)
def create_contact(
    body: ContactCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> ContactRead:
    return service.create_contact(db, principal, body)


@router.patch("/{contact_id}", response_model=ContactRead)
def update_contact(
    contact_id: int,
    body: ContactUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> ContactRead:
    return service.update_contact(db, principal, contact_id, body)
