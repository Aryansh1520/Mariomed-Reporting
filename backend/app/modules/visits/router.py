from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.pagination import Page
from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.rbac.principal import Principal
from app.modules.visits import service
from app.modules.visits.schemas import (
    DisputeDecision,
    JointPartnerRead,
    JointRequestRead,
    UnlistedCreate,
    UnlistedDetailRead,
    UnlistedListQuery,
    UnlistedRead,
    UnlistedSimilarQuery,
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
    subzone_id: int | None = None,
    contact_id: int | None = None,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[JointPartnerRead]:
    return service.list_joint_partners(db, principal, subzone_id, contact_id)


@router.post("/unlisted-contacts", response_model=UnlistedRead)
def create_unlisted(
    body: UnlistedCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> UnlistedRead:
    return service.create_unlisted(db, principal, body)


@router.get("/unlisted-contacts", response_model=Page[UnlistedRead])
def list_unlisted(
    subzone_id: int,
    include_converted: bool = False,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=100, ge=1, le=100),
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> Page[UnlistedRead]:
    query = UnlistedListQuery(
        subzone_id=subzone_id, include_converted=include_converted, page=page, page_size=page_size
    )
    return service.list_unlisted(db, principal, query)


@router.get("/unlisted-contacts/similar", response_model=list[UnlistedRead])
def find_similar_unlisted(
    subzone_id: int,
    name: str = Query(min_length=1, max_length=120),
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[UnlistedRead]:
    return service.find_similar_unlisted(db, principal, UnlistedSimilarQuery(subzone_id=subzone_id, name=name))


@router.get("/unlisted-contacts/{unlisted_id}", response_model=UnlistedDetailRead)
def unlisted_detail(
    unlisted_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> UnlistedDetailRead:
    return service.unlisted_detail(db, principal, unlisted_id)


@router.post("/unlisted-contacts/{unlisted_id}/convert", response_model=UnlistedRead)
def convert_unlisted(
    unlisted_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> UnlistedRead:
    return service.convert_unlisted(db, principal, unlisted_id)


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
