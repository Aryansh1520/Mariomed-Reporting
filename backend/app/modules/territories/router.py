from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.rbac.principal import Principal
from app.modules.territories import service
from app.modules.territories.schemas import (
    MapRead,
    TerritoryCreate,
    TerritoryRead,
    TerritoryUpdate,
    UserTerritoriesRead,
    UserTerritoriesUpdate,
)

router = APIRouter()


@router.get("/map", response_model=MapRead)
def get_map(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> MapRead:
    return service.get_map(db, principal)


@router.post("", response_model=TerritoryRead)
def create_territory(
    body: TerritoryCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TerritoryRead:
    return service.create_territory(db, principal, body)


@router.patch("/{territory_id}", response_model=TerritoryRead)
def update_territory(
    territory_id: int,
    body: TerritoryUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TerritoryRead:
    return service.update_territory(db, principal, territory_id, body)


@router.delete("/{territory_id}", response_model=None)
def delete_territory(
    territory_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> None:
    service.delete_territory(db, principal, territory_id)


@router.get("/users/{user_id}", response_model=UserTerritoriesRead)
def get_user_territories(
    user_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> UserTerritoriesRead:
    return service.get_user_territories(db, principal, user_id)


@router.put("/users/{user_id}", response_model=UserTerritoriesRead)
def set_user_territories(
    user_id: int,
    body: UserTerritoriesUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> UserTerritoriesRead:
    return service.set_user_territories(db, principal, user_id, body)
