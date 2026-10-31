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
