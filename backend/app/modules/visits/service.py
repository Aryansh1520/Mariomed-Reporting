from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import BadRequest, Conflict, Forbidden, NotFound
from app.modules.audit import service as audit
from app.modules.contacts import service as contacts_service
from app.modules.contacts.schemas import ContactRef
from app.modules.products import service as products_service
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm, PermissionScope
from app.modules.rbac.principal import Principal
from app.modules.territories import service as territories_service
from app.modules.territories.schemas import SubzoneRef
from app.modules.users import service as users_service
from app.modules.visits import repository
from app.modules.visits.models import Visit, VisitDay, VisitParticipation
from app.modules.visits.schemas import (
    DisputeDecision,
    JointPartnerRead,
    JointRequestRead,
    ProductRef,
    VisitCreate,
    VisitDayRead,
    VisitRead,
    VisitUpdate,
)

WINDOW_CLOSED = "Visits can only be reported for today and the last {days} days."
VISIT_NOT_FOUND = "This visit does not exist."
VISIT_LOCKED = "This visit can no longer be changed because its day has ended."
DAY_ENDED = "This day has already ended."
DAY_IS_LEAVE = "This day is marked as leave. Remove the leave to report calls on it."
LEAVE_NOT_ALLOWED = "Leave can only be set or removed for today or a future day, up to a month ahead."
LEAVE_HAS_VISITS = "This day has calls recorded, so it cannot be marked as leave."
LEAVE_HORIZON_DAYS = 31
SUNDAY_LEAVE = "Sunday is a leave day for everyone. No calls can be recorded or planned on it."
SUNDAY = 6
NOT_REPORTER = "Only people who report their own calls can record them. Your access manages the team."
PARTNER_NOT_FOUND = "The joint partner does not exist or is switched off."
PARTNER_IS_SELF = "You cannot add yourself as the joint partner."
PARTNER_OUTSIDE = "The joint partner must be assigned to the same zone or subzone."
JOINT_NOT_FOUND = "This joint call does not exist."
JOINT_CLOSED = "This joint call has already been answered."


@dataclass(frozen=True)
class _Placement:
    """Where a visit sits and who joined it, after the caller's territories are checked."""

    contact_id: int
    zone_id: int
    subzone_id: int
    partner_user_id: int | None


@dataclass(frozen=True)
class _Lookups:
    """Names and states a batch of visits needs, fetched once for the whole batch."""

    contacts: dict[int, ContactRef]
    subzones: dict[int, SubzoneRef]
    product_ids: dict[int, list[int]]
    product_names: dict[int, str]
    participations: dict[int, VisitParticipation]
    day_statuses: dict[int, str]
    rep_names: dict[int, str]


def record_visit(db: Session, principal: Principal, data: VisitCreate) -> VisitRead:
    rbac_service.require_scope(principal, Perm.VISITS_MANAGE)
    ensure_field_reporting(principal)
    _ensure_in_window(data.visit_date)
    ensure_not_sunday(data.visit_date)
    day = _open_day(db, principal, data.visit_date)
    placement = _placement(db, principal, data.contact_id, data.partner_user_id)
    product_ids = sorted(set(data.product_ids))
    products_service.require_active_products(db, set(product_ids))
    visit = repository.add(
        db,
        Visit(
            day_id=day.id,
            user_id=principal.user_id,
            visit_date=data.visit_date,
            visit_time=data.visit_time,
            contact_id=placement.contact_id,
            zone_id=placement.zone_id,
            subzone_id=placement.subzone_id,
            remarks=data.remarks,
            status="open",
            partner_user_id=placement.partner_user_id,
            created_by=principal.user_id,
            updated_by=principal.user_id,
        ),
    )
    repository.set_products(db, visit.id, product_ids)
    audit.record(db, principal.user_id, "visit.create", "visit", visit.id)
    db.commit()
    return _read_many(db, [visit], principal.user_id)[0]


def update_visit(db: Session, principal: Principal, visit_id: int, data: VisitUpdate) -> VisitRead:
    rbac_service.require_scope(principal, Perm.VISITS_MANAGE)
    ensure_field_reporting(principal)
    visit = _editable_visit(db, principal, visit_id)
    contact_id = data.contact_id if data.contact_id is not None else visit.contact_id
    partner_id = data.partner_user_id if "partner_user_id" in data.model_fields_set else visit.partner_user_id
    placement = _placement(db, principal, contact_id, partner_id)
    if data.product_ids is not None:
        product_ids = sorted(set(data.product_ids))
        products_service.require_active_products(db, set(product_ids))
        repository.set_products(db, visit.id, product_ids)
    visit.contact_id = placement.contact_id
    visit.zone_id = placement.zone_id
    visit.subzone_id = placement.subzone_id
    visit.partner_user_id = placement.partner_user_id
    if data.visit_time is not None:
        visit.visit_time = data.visit_time
    if data.remarks is not None:
        visit.remarks = data.remarks
    visit.updated_by = principal.user_id
    audit.record(db, principal.user_id, "visit.update", "visit", visit.id)
    db.commit()
    return _read_many(db, [visit], principal.user_id)[0]


def delete_visit(db: Session, principal: Principal, visit_id: int) -> None:
    rbac_service.require_scope(principal, Perm.VISITS_MANAGE)
    ensure_field_reporting(principal)
    visit = _editable_visit(db, principal, visit_id)
    audit.record(db, principal.user_id, "visit.delete", "visit", visit.id)
    repository.delete_visit(db, visit)
    db.commit()


def end_day(db: Session, principal: Principal, visit_date: date) -> VisitDayRead:
    rbac_service.require_scope(principal, Perm.VISITS_MANAGE)
    ensure_field_reporting(principal)
    _ensure_in_window(visit_date)
    ensure_not_sunday(visit_date)
    day = repository.get_day(db, principal.user_id, visit_date)
    if day is None:
        day = repository.add(
            db,
            VisitDay(user_id=principal.user_id, visit_date=visit_date, status="open", created_by=principal.user_id, updated_by=principal.user_id),
        )
    if day.status == "ended":
        raise Conflict(DAY_ENDED)
    if day.status == "leave":
        raise Conflict(DAY_IS_LEAVE)
    now = _now()
    _close_visits(db, day)
    for participation in repository.pending_participations_on(db, principal.user_id, visit_date):
        _resolve(participation, "accepted", now)
    _settle_expired(db, now)
    day.status = "ended"
    day.ended_at = now
    day.updated_by = principal.user_id
    audit.record(db, principal.user_id, "visit_day.end", "visit_day", day.id)
    db.commit()
    return _day_read(day)


def list_visits(
    db: Session, principal: Principal, date_from: date | None, date_to: date | None, mine: bool = False
) -> list[VisitRead]:
    start, end = _range(date_from, date_to)
    visits = repository.list_visits(db, _reporter_filter(principal, Perm.VISITS_READ, mine), start, end)
    return _read_many(db, visits, principal.user_id)


def list_days(
    db: Session, principal: Principal, date_from: date | None, date_to: date | None, mine: bool = False
) -> list[VisitDayRead]:
    start, end = _range(date_from, date_to)
    return [_day_read(day) for day in repository.list_days(db, _reporter_filter(principal, Perm.VISITS_READ, mine), start, end)]


def team_visits(db: Session, viewer_id: int, date_from: date, date_to: date) -> list[VisitRead]:
    """Every rep's calls in the period, for the team dashboard. The caller's grant is checked by that report."""
    return _read_many(db, repository.list_visits(db, None, date_from, date_to), viewer_id)


def team_days(db: Session, date_from: date, date_to: date) -> list[VisitDayRead]:
    return [_day_read(day) for day in repository.list_days(db, None, date_from, date_to)]


def list_joint_requests(db: Session, principal: Principal) -> list[JointRequestRead]:
    rbac_service.require_scope(principal, Perm.VISITS_READ)
    _settle_expired(db, _now())
    db.commit()
    rows = repository.participations_for_user(db, principal.user_id, _window_start())
    lookups = _lookups(db, [visit for _, visit in rows])
    return [_joint_read(participation, visit, lookups) for participation, visit in rows]


def list_joint_partners(db: Session, principal: Principal, contact_id: int) -> list[JointPartnerRead]:
    """The other reps assigned to the contact's zone or subzone, who can join a call on that contact."""
    rbac_service.require_scope(principal, Perm.VISITS_MANAGE)
    contact = contacts_service.reachable_contact(db, principal, contact_id)
    user_ids = territories_service.users_assigned_to_subzone(db, contact.subzone_id) - {principal.user_id}
    partners = sorted(users_service.active_by_ids(db, user_ids), key=lambda user: user.full_name)
    return [JointPartnerRead(user_id=user.id, full_name=user.full_name) for user in partners]


def accept_joint(db: Session, principal: Principal, visit_id: int) -> JointRequestRead:
    return _respond(db, principal, visit_id, "accepted")


def dispute_joint(db: Session, principal: Principal, visit_id: int) -> JointRequestRead:
    return _respond(db, principal, visit_id, "disputed")


def _respond(db: Session, principal: Principal, visit_id: int, status: str) -> JointRequestRead:
    rbac_service.require_scope(principal, Perm.VISITS_MANAGE)
    now = _now()
    _settle_expired(db, now)
    participation = repository.get_participation(db, visit_id)
    if participation is None or participation.user_id != principal.user_id:
        raise NotFound(JOINT_NOT_FOUND)
    if participation.status != "pending":
        db.commit()
        raise Conflict(JOINT_CLOSED)
    visit = repository.get_visit(db, visit_id)
    _resolve(participation, status, now)
    if status == "disputed":
        visit.status = "disputed"
    audit.record(db, principal.user_id, f"visit.joint_{status}", "visit", visit.id)
    db.commit()
    return _joint_read(participation, visit, _lookups(db, [visit]))


def _close_visits(db: Session, day: VisitDay) -> None:
    """Completes each visit of the day. A joint call also opens a pending request for its partner."""
    for visit in repository.visits_of_day(db, day.id):
        visit.status = "completed"
        if visit.partner_user_id is not None:
            repository.add(
                db,
                VisitParticipation(
                    visit_id=visit.id,
                    user_id=visit.partner_user_id,
                    status="pending",
                    created_by=day.user_id,
                    updated_by=day.user_id,
                ),
            )


def _settle_expired(db: Session, now: datetime) -> None:
    """A joint call still pending after the grace period is disputed. Repeated calls change nothing more."""
    for participation, visit in repository.pending_participations_before(db, _window_start()):
        _resolve(participation, "disputed", now)
        visit.status = "disputed"


def _resolve(participation: VisitParticipation, status: str, now: datetime) -> None:
    participation.status = status
    participation.resolved_at = now


def _open_day(db: Session, principal: Principal, visit_date: date) -> VisitDay:
    day = repository.get_day(db, principal.user_id, visit_date)
    if day is None:
        return repository.add(
            db,
            VisitDay(user_id=principal.user_id, visit_date=visit_date, status="open", created_by=principal.user_id, updated_by=principal.user_id),
        )
    if day.status == "ended":
        raise Conflict(DAY_ENDED)
    if day.status == "leave":
        raise Conflict(DAY_IS_LEAVE)
    return day


def _editable_visit(db: Session, principal: Principal, visit_id: int) -> Visit:
    visit = repository.get_visit(db, visit_id)
    reporter = _reporter_filter(principal, Perm.VISITS_MANAGE)
    if visit is None or (reporter is not None and visit.user_id != reporter):
        raise NotFound(VISIT_NOT_FOUND)
    if visit.status != "open" or repository.day_statuses(db, {visit.day_id})[visit.day_id] == "ended":
        raise Conflict(VISIT_LOCKED)
    _ensure_in_window(visit.visit_date)
    return visit


def _placement(db: Session, principal: Principal, contact_id: int, partner_user_id: int | None) -> _Placement:
    contact = contacts_service.reachable_contact(db, principal, contact_id)
    location = territories_service.subzone_locations(db, {contact.subzone_id})[contact.subzone_id]
    partner_id = _checked_partner(db, principal.user_id, partner_user_id, contact.subzone_id)
    return _Placement(
        contact_id=contact.id,
        zone_id=location.zone_id,
        subzone_id=contact.subzone_id,
        partner_user_id=partner_id,
    )


def _checked_partner(db: Session, reporter_id: int, partner_id: int | None, subzone_id: int) -> int | None:
    """A joint partner must be an active rep assigned to the same zone or subzone as the call."""
    if partner_id is None:
        return None
    if partner_id == reporter_id:
        raise BadRequest(PARTNER_IS_SELF)
    partner = users_service.get_by_id(db, partner_id)
    if partner is None or not partner.is_active:
        raise BadRequest(PARTNER_NOT_FOUND)
    if subzone_id not in territories_service.user_territory_ids(db, partner_id):
        raise BadRequest(PARTNER_OUTSIDE)
    return partner_id


def _reporter_filter(principal: Principal, code: Perm, mine: bool = False) -> int | None:
    """None when the caller's grant reaches every reporter's records. Otherwise only the caller's own.
    `mine` narrows to the caller's own records even for a wide grant; the permission is still required."""
    scope = rbac_service.require_scope(principal, code)
    return principal.user_id if mine or scope != PermissionScope.ALL else None


def _lookups(db: Session, visits: list[Visit]) -> _Lookups:
    visit_ids = {visit.id for visit in visits}
    product_ids = repository.products_of_visits(db, visit_ids)
    all_products = {product_id for ids in product_ids.values() for product_id in ids}
    return _Lookups(
        contacts=contacts_service.contact_summaries(db, {visit.contact_id for visit in visits}),
        subzones=territories_service.subzone_locations(db, {visit.subzone_id for visit in visits}),
        product_ids=product_ids,
        product_names=products_service.product_names(db, all_products),
        participations=repository.participations_by_visit(db, visit_ids),
        day_statuses=repository.day_statuses(db, {visit.day_id for visit in visits}),
        rep_names=users_service.full_names(db, {visit.user_id for visit in visits}),
    )


def _read_many(db: Session, visits: list[Visit], viewer_id: int) -> list[VisitRead]:
    lookups = _lookups(db, visits)
    return [_visit_read(visit, lookups, viewer_id) for visit in visits]


def _visit_read(visit: Visit, lookups: _Lookups, viewer_id: int) -> VisitRead:
    contact = lookups.contacts[visit.contact_id]
    subzone = lookups.subzones[visit.subzone_id]
    participation = lookups.participations.get(visit.id)
    return VisitRead(
        id=visit.id,
        user_id=visit.user_id,
        rep_name=lookups.rep_names.get(visit.user_id, ""),
        visit_date=visit.visit_date,
        visit_time=visit.visit_time,
        status=visit.status,
        remarks=visit.remarks,
        contact_id=contact.id,
        contact_name=contact.name,
        category_name=contact.category_name,
        type_name=contact.type_name,
        zone_id=subzone.zone_id,
        zone_name=subzone.zone_name,
        subzone_id=subzone.id,
        subzone_name=subzone.name,
        products=_product_refs(visit.id, lookups),
        partner_user_id=visit.partner_user_id,
        partner_status=participation.status if participation is not None else None,
        is_editable=visit.user_id == viewer_id
        and visit.status == "open"
        and lookups.day_statuses[visit.day_id] == "open"
        and _is_in_window(visit.visit_date),
    )


def _joint_read(participation: VisitParticipation, visit: Visit, lookups: _Lookups) -> JointRequestRead:
    contact = lookups.contacts[visit.contact_id]
    subzone = lookups.subzones[visit.subzone_id]
    return JointRequestRead(
        visit_id=visit.id,
        initiator_user_id=visit.user_id,
        visit_date=visit.visit_date,
        visit_time=visit.visit_time,
        contact_name=contact.name,
        category_name=contact.category_name,
        type_name=contact.type_name,
        zone_name=subzone.zone_name,
        subzone_name=subzone.name,
        remarks=visit.remarks,
        products=_product_refs(visit.id, lookups),
        status=participation.status,
        can_respond=participation.status == "pending",
    )


def _product_refs(visit_id: int, lookups: _Lookups) -> list[ProductRef]:
    return [ProductRef(id=pid, name=lookups.product_names[pid]) for pid in lookups.product_ids.get(visit_id, [])]


def _day_read(day: VisitDay) -> VisitDayRead:
    return VisitDayRead(id=day.id, user_id=day.user_id, visit_date=day.visit_date, status=day.status, ended_at=day.ended_at)


def _today() -> date:
    return datetime.now(ZoneInfo(settings.business_timezone)).date()


def _window_start() -> date:
    return _today() - timedelta(days=settings.reporting_grace_days)


def _is_in_window(visit_date: date) -> bool:
    return _window_start() <= visit_date <= _today()


def ensure_not_sunday(visit_date: date) -> None:
    if visit_date.weekday() == SUNDAY:
        raise BadRequest(SUNDAY_LEAVE)


def _ensure_in_window(visit_date: date) -> None:
    if not _is_in_window(visit_date):
        raise BadRequest(WINDOW_CLOSED.format(days=settings.reporting_grace_days))


def _range(date_from: date | None, date_to: date | None) -> tuple[date, date]:
    return date_from or _window_start(), date_to or _today()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_field_reporting(principal: Principal) -> None:
    """Recording is for people who report their own calls. A grant of `all` is oversight: it can read and manage,
    but it cannot make calls of its own."""
    if principal.permissions.get(Perm.VISITS_MANAGE.value) == PermissionScope.ALL:
        raise Forbidden(NOT_REPORTER)


def business_today() -> date:
    return _today()


def reporting_window_start() -> date:
    return _window_start()


def own_day_statuses(db: Session, user_id: int, date_from: date, date_to: date) -> dict[date, str]:
    return {day.visit_date: day.status for day in repository.list_days(db, user_id, date_from, date_to)}


def mark_leave(db: Session, user_id: int, visit_date: date) -> None:
    ensure_not_sunday(visit_date)
    """Marks a day as leave. Only today or a future day within the planning horizon, and only a day with no calls."""
    if not _today() <= visit_date <= _today() + timedelta(days=LEAVE_HORIZON_DAYS):
        raise BadRequest(LEAVE_NOT_ALLOWED)
    day = repository.get_day(db, user_id, visit_date)
    if day is None:
        repository.add(db, VisitDay(user_id=user_id, visit_date=visit_date, status="leave", created_by=user_id, updated_by=user_id))
        return
    if day.status == "leave":
        return
    if day.status == "ended" or repository.has_visits(db, day.id):
        raise BadRequest(LEAVE_HAS_VISITS)
    day.status = "leave"
    day.updated_by = user_id


def clear_leave(db: Session, user_id: int, visit_date: date) -> None:
    ensure_not_sunday(visit_date)
    if visit_date < _today():
        raise BadRequest(LEAVE_NOT_ALLOWED)
    day = repository.get_day(db, user_id, visit_date)
    if day is not None and day.status == "leave":
        repository.delete_day(db, day)


def is_leave(db: Session, user_id: int, visit_date: date) -> bool:
    day = repository.get_day(db, user_id, visit_date)
    return day is not None and day.status == "leave"


def leave_dates(db: Session, user_id: int, date_from: date, date_to: date) -> set[date]:
    return {day.visit_date for day in repository.list_days(db, user_id, date_from, date_to) if day.status == "leave"}


def visited_pairs(db: Session, user_id: int, date_from: date, date_to: date) -> set[tuple[date, int]]:
    return repository.visited_pairs(db, user_id, date_from, date_to)


DISPUTE_NOT_FOUND = "This call does not exist."
NOT_IN_DISPUTE = "Only a disputed call can be settled."


def resolve_dispute(db: Session, principal: Principal, visit_id: int, decision: DisputeDecision) -> VisitRead:
    """Settles a disputed joint call. Both reps are credited, only the recorder, or nobody."""
    rbac_service.require_scope(principal, Perm.VISITS_REVIEW)
    visit = repository.get_visit(db, visit_id)
    if visit is None:
        raise NotFound(DISPUTE_NOT_FOUND)
    if visit.status != "disputed":
        raise Conflict(NOT_IN_DISPUTE)
    participation = repository.get_participation(db, visit_id)
    if decision == "both":
        visit.status = "completed"
        if participation is not None:
            participation.status = "accepted"
    elif decision == "them":
        visit.status = "completed"
        if participation is not None:
            participation.status = "disputed"
    else:
        visit.status = "rejected"
        if participation is not None:
            participation.status = "disputed"
    audit.record(db, principal.user_id, f"visit.dispute_{decision}", "visit", visit.id)
    db.commit()
    return _read_many(db, [visit], principal.user_id)[0]
