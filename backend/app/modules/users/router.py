from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.pagination import Page, PageQuery
from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.rbac.principal import Principal
from app.modules.users import service
from app.modules.users.schemas import (
    ActivationRequest,
    TeamUserCreate,
    TeamUserRead,
    TeamUserUpdate,
)

router = APIRouter()


@router.get("", response_model=Page[TeamUserRead])
def list_team_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> Page[TeamUserRead]:
    return service.list_team(db, principal, PageQuery(page=page, page_size=page_size))


@router.get("/{user_id}", response_model=TeamUserRead)
def get_team_user(
    user_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TeamUserRead:
    return service.get_team_user(db, principal, user_id)


@router.post("", response_model=TeamUserRead)
def create_team_user(
    body: TeamUserCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TeamUserRead:
    return service.create_team_user(db, principal, body)


@router.patch("/{user_id}", response_model=TeamUserRead)
def update_team_user(
    user_id: int,
    body: TeamUserUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TeamUserRead:
    return service.update_team_user(db, principal, user_id, body)


@router.post("/{user_id}/activation", response_model=TeamUserRead)
def set_team_user_active(
    user_id: int,
    body: ActivationRequest,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TeamUserRead:
    return service.set_team_user_active(db, principal, user_id, body.is_active)
