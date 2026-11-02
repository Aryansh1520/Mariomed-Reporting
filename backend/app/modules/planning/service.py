from collections import defaultdict
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.core.exceptions import BadRequest, Conflict, NotFound
from app.modules.audit import service as audit
from app.modules.contacts import service as contacts_service
from app.modules.planning import repository
from app.modules.planning.models import DayPlanItem
from app.modules.planning.schemas import PlanDayRead, PlanItemCreate, PlanItemRead
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm
from app.modules.rbac.principal import Principal
from app.modules.territories import service as territories_service
from app.modules.visits import service as visits_service

PLAN_HORIZON_DAYS = 31
PLAN_NOT_ALLOWED = "Plans can only be made for today or a future day, up to a month ahead."
PAST_LOCKED = "Plans for past days cannot be changed."
PLAN_ON_LEAVE = "This day is marked as leave. Remove the leave to plan calls."
PLAN_DUPLICATE = "This contact is already planned for this day."
PLAN_NOT_FOUND = "This planned call does not exist."
LEAVE_HAS_PLANS = "Remove the planned calls before marking this day as leave."


def list_plans(db: Session, principal: Principal, date_from: date | None, date_to: date | None) -> list[PlanDayRead]:
    """The caller's own plans and leave days. Nobody else's plans are reachable."""
    rbac_service.require_scope(principal, Perm.PLANS_READ)
    today = visits_service.business_today()
    start = date_from or visits_service.reporting_window_start()
    end = date_to or today + timedelta(days=PLAN_HORIZON_DAYS)
    items = repository.list_items(db, principal.user_id, start, end)
    leave = visits_service.leave_dates(db, principal.user_id, start, end)
    achieved = visits_service.visited_pairs(db, principal.user_id, start, end)
    names = contacts_service.contact_summaries(db, {item.contact_id for item in items})
    locations = territories_service.subzone_locations(db, {ref.subzone_id for ref in names.values()})

    by_day: dict[date, list[PlanItemRead]] = defaultdict(list)
    for item in items:
        contact = names[item.contact_id]
        place = locations[contact.subzone_id]
        by_day[item.plan_date].append(
            PlanItemRead(
                id=item.id,
                plan_date=item.plan_date,
                contact_id=item.contact_id,
                contact_name=contact.name,
                category_name=contact.category_name,
                type_name=contact.type_name,
                zone_name=place.zone_name,
                subzone_name=place.name,
                status=_status(item.plan_date, (item.plan_date, item.contact_id) in achieved, today),
            )
        )
    days = sorted(set(by_day) | leave)
    return [PlanDayRead(plan_date=day, is_leave=day in leave, items=by_day.get(day, [])) for day in days]


def add_item(db: Session, principal: Principal, plan_date: date, data: PlanItemCreate) -> PlanItemRead:
    rbac_service.require_scope(principal, Perm.PLANS_MANAGE)
    visits_service.ensure_field_reporting(principal)
    _ensure_future(plan_date)
    visits_service.ensure_not_sunday(plan_date)
    if visits_service.is_leave(db, principal.user_id, plan_date):
        raise BadRequest(PLAN_ON_LEAVE)
    contact = contacts_service.reachable_contact(db, principal, data.contact_id)
    if repository.exists(db, principal.user_id, plan_date, contact.id):
        raise Conflict(PLAN_DUPLICATE)
    item = repository.add(
        db,
        DayPlanItem(
            user_id=principal.user_id,
            plan_date=plan_date,
            contact_id=contact.id,
            created_by=principal.user_id,
            updated_by=principal.user_id,
        ),
    )
    audit.record(db, principal.user_id, "plan_item.create", "plan_item", item.id)
    db.commit()
    return _read(db, item)


def remove_item(db: Session, principal: Principal, item_id: int) -> None:
    rbac_service.require_scope(principal, Perm.PLANS_MANAGE)
    visits_service.ensure_field_reporting(principal)
    item = repository.get_item(db, item_id)
    if item is None or item.user_id != principal.user_id:
        raise NotFound(PLAN_NOT_FOUND)
    if item.plan_date < visits_service.business_today():
        raise BadRequest(PAST_LOCKED)
    audit.record(db, principal.user_id, "plan_item.delete", "plan_item", item.id)
    repository.delete(db, item)
    db.commit()


def set_leave(db: Session, principal: Principal, plan_date: date) -> PlanDayRead:
    rbac_service.require_scope(principal, Perm.PLANS_MANAGE)
    visits_service.ensure_field_reporting(principal)
    if repository.items_on(db, principal.user_id, plan_date):
        raise BadRequest(LEAVE_HAS_PLANS)
    visits_service.mark_leave(db, principal.user_id, plan_date)
    audit.record(db, principal.user_id, "plan_leave.set", "visit_day", None)
    db.commit()
    return PlanDayRead(plan_date=plan_date, is_leave=True, items=[])


def clear_leave(db: Session, principal: Principal, plan_date: date) -> None:
    rbac_service.require_scope(principal, Perm.PLANS_MANAGE)
    visits_service.ensure_field_reporting(principal)
    visits_service.clear_leave(db, principal.user_id, plan_date)
    audit.record(db, principal.user_id, "plan_leave.clear", "visit_day", None)
    db.commit()


def team_plan_items(db: Session, date_from: date, date_to: date) -> list[tuple[int, date, int]]:
    """Every planned call in the period as (user_id, plan_date, contact_id). The caller checks the grant."""
    return [(item.user_id, item.plan_date, item.contact_id) for item in repository.list_all_items(db, date_from, date_to)]


def plan_outcomes(db: Session, user_id: int, date_from: date, date_to: date) -> tuple[int, int]:
    """How many of the user's planned calls fell due by today, and how many of those were achieved."""
    today = visits_service.business_today()
    due = [item for item in repository.list_items(db, user_id, date_from, date_to) if item.plan_date <= today]
    visited = visits_service.visited_pairs(db, user_id, date_from, date_to)
    achieved = sum(1 for item in due if (item.plan_date, item.contact_id) in visited)
    return len(due), achieved


def _ensure_future(plan_date: date) -> None:
    today = visits_service.business_today()
    if not today <= plan_date <= today + timedelta(days=PLAN_HORIZON_DAYS):
        raise BadRequest(PLAN_NOT_ALLOWED)


def _status(plan_date: date, achieved: bool, today: date) -> str:
    """Achieved once the contact was visited that day. Before that: planned for a future day, open while the day
    can still be reported, and missed after that."""
    if achieved:
        return "achieved"
    if plan_date > today:
        return "planned"
    if plan_date >= visits_service.reporting_window_start():
        return "open"
    return "missed"


def _read(db: Session, item: DayPlanItem) -> PlanItemRead:
    contact = contacts_service.contact_summaries(db, {item.contact_id})[item.contact_id]
    place = territories_service.subzone_locations(db, {contact.subzone_id})[contact.subzone_id]
    return PlanItemRead(
        id=item.id,
        plan_date=item.plan_date,
        contact_id=item.contact_id,
        contact_name=contact.name,
        category_name=contact.category_name,
        type_name=contact.type_name,
        zone_name=place.zone_name,
        subzone_name=place.name,
        status=_status(item.plan_date, False, visits_service.business_today()),
    )
