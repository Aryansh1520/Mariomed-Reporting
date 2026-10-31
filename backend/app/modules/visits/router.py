from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.rbac.principal import Principal
from app.modules.visits import service
from app.modules.visits.schemas import (
    DisputeDecision,
    JointPartnerRead,
    JointRequestRead,
    VisitCreate,
    VisitDayRead,
    VisitRead,
    VisitUpdate,
)

router = APIRouter()


@router.post("", response_model=VisitRead)
def record_visit(
    body: VisitCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> VisitRead:
    return service.record_visit(db, principal, body)


@router.get("", response_model=list[VisitRead])
def list_visits(
    date_from: date | None = None,
    date_to: date | None = None,
    mine: bool = False,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[VisitRead]:
    return service.list_visits(db, principal, date_from, date_to, mine)


@router.get("/joint-partners", response_model=list[JointPartnerRead])
def list_joint_partners(
    contact_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[JointPartnerRead]:
    return service.list_joint_partners(db, principal, contact_id)


@router.get("/days", response_model=list[VisitDayRead])
def list_days(
    date_from: date | None = None,
    date_to: date | None = None,
    mine: bool = False,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[VisitDayRead]:
    return service.list_days(db, principal, date_from, date_to, mine)


@router.post("/days/{visit_date}/end", response_model=VisitDayRead)
def end_day(
    visit_date: date,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> VisitDayRead:
    return service.end_day(db, principal, visit_date)


@router.get("/joint-requests", response_model=list[JointRequestRead])
def list_joint_requests(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[JointRequestRead]:
    return service.list_joint_requests(db, principal)


@router.post("/{visit_id}/joint/accept", response_model=JointRequestRead)
def accept_joint(
    visit_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> JointRequestRead:
    return service.accept_joint(db, principal, visit_id)


@router.post("/{visit_id}/joint/dispute", response_model=JointRequestRead)
def dispute_joint(
    visit_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> JointRequestRead:
    return service.dispute_joint(db, principal, visit_id)


@router.patch("/{visit_id}", response_model=VisitRead)
def update_visit(
    visit_id: int,
    body: VisitUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> VisitRead:
    return service.update_visit(db, principal, visit_id, body)


@router.delete("/{visit_id}", response_model=None)
def delete_visit(
    visit_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> None:
    service.delete_visit(db, principal, visit_id)


@router.post("/{visit_id}/dispute/resolve", response_model=VisitRead)
def resolve_dispute(
    visit_id: int,
    body: DisputeDecision,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> VisitRead:
    return service.resolve_dispute(db, principal, visit_id, body)
