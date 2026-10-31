from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.rbac.principal import Principal
from app.modules.reports import service
from app.modules.reports.schemas import (
    MemberDetail,
    MemberRow,
    MissedContactLine,
    TeamCallLine,
    TeamDashboard,
)

router = APIRouter()


@router.get("/team", response_model=TeamDashboard)
def team_dashboard(
    date_from: date,
    date_to: date,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> TeamDashboard:
    return service.team_dashboard(db, principal, date_from, date_to)


@router.get("/team/missed", response_model=list[MissedContactLine])
def team_missed(
    day: date,
    zone_id: int | None = None,
    category_name: str | None = None,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[MissedContactLine]:
    return service.team_missed(db, principal, day, zone_id, category_name)


@router.get("/team/calls", response_model=list[TeamCallLine])
def team_calls(
    date_from: date,
    date_to: date,
    zone_id: int | None = None,
    product_id: int | None = None,
    category_name: str | None = None,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[TeamCallLine]:
    return service.team_calls(db, principal, date_from, date_to, zone_id, product_id, category_name)


@router.get("/members", response_model=list[MemberRow])
def member_report(
    date_from: date,
    date_to: date,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[MemberRow]:
    return service.member_report(db, principal, date_from, date_to)


@router.get("/members/{user_id}", response_model=MemberDetail)
def member_detail(
    user_id: int,
    date_from: date,
    date_to: date,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> MemberDetail:
    return service.member_detail(db, principal, user_id, date_from, date_to)
