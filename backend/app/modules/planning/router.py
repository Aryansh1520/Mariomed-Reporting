from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.planning import service
from app.modules.planning.schemas import PlanDayRead, PlanItemCreate, PlanItemRead
from app.modules.rbac.principal import Principal

router = APIRouter()


@router.get("/days", response_model=list[PlanDayRead])
def list_plans(
    date_from: date | None = None,
    date_to: date | None = None,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[PlanDayRead]:
    return service.list_plans(db, principal, date_from, date_to)


@router.post("/days/{plan_date}/items", response_model=PlanItemRead)
def add_item(
    plan_date: date,
    body: PlanItemCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> PlanItemRead:
    return service.add_item(db, principal, plan_date, body)


@router.delete("/items/{item_id}", response_model=None)
def remove_item(
    item_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> None:
    service.remove_item(db, principal, item_id)


@router.put("/days/{plan_date}/leave", response_model=PlanDayRead)
def set_leave(
    plan_date: date,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> PlanDayRead:
    return service.set_leave(db, principal, plan_date)


@router.delete("/days/{plan_date}/leave", response_model=None)
def clear_leave(
    plan_date: date,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> None:
    service.clear_leave(db, principal, plan_date)
