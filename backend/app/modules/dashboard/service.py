from datetime import timedelta

from sqlalchemy.orm import Session

from app.modules.contacts import service as contacts_service
from app.modules.products import service as products_service
from app.modules.territories import service as territories_service
from app.modules.dashboard.schemas import (
    CoverageStats,
    DashboardRead,
    DayCount,
    MissedStats,
    MonthStats,
    NextUpItem,
    SetupStats,
    TeamStats,
    TodayStats,
)
from app.modules.planning import service as planning_service
from app.modules.rbac.catalog import Perm, PermissionScope
from app.modules.rbac.principal import Principal
from app.modules.users import service as users_service
from app.modules.visits import service as visits_service

DAILY_WINDOW_DAYS = 14
NEXT_UP_DAYS = 7


def get_dashboard(db: Session, principal: Principal) -> DashboardRead:
    """Builds the home dashboard from the sections the caller may see. Visit figures follow the caller's visit scope:
    an admin with `all` sees the team; anyone else sees their own. Plans and missed days are always the caller's own."""
    today = visits_service.business_today()
    month_start = today.replace(day=1)
    visits_allowed = _has(principal, Perm.VISITS_READ)
    plans_allowed = _has(principal, Perm.PLANS_READ)
    personal = _reports_personally(principal)
    month_visits = visits_service.list_visits(db, principal, month_start, today) if visits_allowed else []

    return DashboardRead(
        today=_today(db, principal, today, plans_allowed) if visits_allowed and personal else None,
        month=_month(db, principal, month_start, today, month_visits) if visits_allowed else None,
        coverage=_coverage(db, principal, month_visits) if _has(principal, Perm.CONTACTS_READ) else None,
        missed=_missed(db, principal, month_visits) if _has(principal, Perm.CONTACTS_READ) and personal else None,
        next_up=_next_up(db, principal, today) if plans_allowed and personal else None,
        daily_calls=_daily(db, principal, today) if visits_allowed else None,
        joint_waiting=_joint_waiting(db, principal) if visits_allowed and personal else None,
        team=TeamStats(active_users=users_service.count_active(db)) if _has(principal, Perm.USERS_READ) else None,
        setup=_setup(db, principal) if _has(principal, Perm.TERRITORIES_READ) and not personal else None,
    )



def _setup(db: Session, principal: Principal) -> SetupStats:
    """What the organisation has set up: zones, subzones, contacts and products. Each count needs its own permission."""
    return SetupStats(
        zones=territories_service.count_active(db, "zone"),
        subzones=territories_service.count_active(db, "subzone"),
        contacts=contacts_service.count_all_active(db, principal) if _has(principal, Perm.CONTACTS_READ) else None,
        products=products_service.count_active(db) if _has(principal, Perm.PRODUCTS_READ) else None,
    )


def _reports_personally(principal: Principal) -> bool:
    """Whether the caller works in the field, reporting their own calls. A grant of `all` is oversight, not reporting,
    so an admin's home shows the team instead of personal days, plans and joint calls."""
    scope = principal.permissions.get(Perm.VISITS_MANAGE.value)
    return scope is not None and scope != PermissionScope.ALL


def _has(principal: Principal, code: Perm) -> bool:
    return code.value in principal.permissions


def _today(db: Session, principal: Principal, today, plans_allowed: bool) -> TodayStats:
    calls = visits_service.list_visits(db, principal, today, today)
    status = visits_service.own_day_statuses(db, principal.user_id, today, today).get(today)
    planned = None
    is_leave = None
    if plans_allowed:
        day = next(iter(planning_service.list_plans(db, principal, today, today)), None)
        planned = len(day.items) if day else 0
        is_leave = day.is_leave if day else False
    return TodayStats(date=today, calls=len(calls), day_status=status, planned=planned, is_leave=is_leave)


def _month(db: Session, principal: Principal, month_start, today, month_visits) -> MonthStats:
    days = visits_service.list_days(db, principal, month_start, today)
    return MonthStats(
        calls=len(month_visits),
        contacts_visited=len({visit.contact_id for visit in month_visits}),
        days_reported=sum(1 for day in days if day.status == "ended"),
    )


def _coverage(db: Session, principal: Principal, month_visits) -> CoverageStats:
    total = contacts_service.count_reachable_active(db, principal)
    visited = min(len({visit.contact_id for visit in month_visits}), total)
    return CoverageStats(visited=visited, total=total, percent=visited / total if total else 0.0)


def _missed(db: Session, principal: Principal, month_visits) -> MissedStats:
    """The contacts that were not visited this month, out of the ones the caller can visit."""
    total = contacts_service.count_reachable_active(db, principal)
    visited = min(len({visit.contact_id for visit in month_visits}), total)
    return MissedStats(missed_contacts=total - visited)


def _next_up(db: Session, principal: Principal, today) -> list[NextUpItem]:
    plans = planning_service.list_plans(db, principal, today + timedelta(days=1), today + timedelta(days=NEXT_UP_DAYS))
    return [
        NextUpItem(
            plan_date=plan_day.plan_date,
            contact_name=item.contact_name,
            category_name=item.category_name,
            subzone_name=item.subzone_name,
        )
        for plan_day in plans
        for item in plan_day.items
    ]


def _daily(db: Session, principal: Principal, today) -> list[DayCount]:
    start = today - timedelta(days=DAILY_WINDOW_DAYS - 1)
    counts: dict = {}
    for visit in visits_service.list_visits(db, principal, start, today):
        counts[visit.visit_date] = counts.get(visit.visit_date, 0) + 1
    return [DayCount(date=start + timedelta(days=offset), count=counts.get(start + timedelta(days=offset), 0)) for offset in range(DAILY_WINDOW_DAYS)]


def _joint_waiting(db: Session, principal: Principal) -> int:
    return sum(1 for request in visits_service.list_joint_requests(db, principal) if request.can_respond)
