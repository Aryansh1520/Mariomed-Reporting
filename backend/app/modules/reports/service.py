from collections import Counter, defaultdict
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, time, timedelta

from sqlalchemy.orm import Session

from app.core.exceptions import BadRequest, NotFound
from app.core.pagination import PageQuery
from app.modules.contacts import service as contacts_service
from app.modules.holidays.service import holiday_dates
from app.modules.planning import service as planning_service
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm, PermissionScope
from app.modules.rbac.principal import Principal
from app.modules.reports.schemas import (
    CallLine,
    MissedContactLine,
    CategoryLine,
    DayLine,
    DayPoint,
    EmployeeLine,
    MemberDetail,
    MemberRow,
    ProductLine,
    TeamCallLine,
    TeamDashboard,
    TeamSummary,
    UnlistedCategoryLine,
    UnlistedContactLine,
    UnlistedPatchLine,
    ZoneLine,
)
from app.modules.territories import service as territories_service
from app.modules.users import service as users_service
from app.modules.visits import service as visits_service
from app.modules.visits.schemas import DAY_PART_ORDER, UnlistedRead, VisitRead

MAX_RANGE_DAYS = 366
SUNDAY = 6
RANGE_TOO_LONG = "A report can cover at most one year. Choose a shorter period."
RANGE_BACKWARDS = "The end date must be on or after the start date."
MEMBER_NOT_FOUND = "This person is not in the team report."


def member_report(db: Session, principal: Principal, start: date, end: date) -> list[MemberRow]:
    """Each team member's performance for the period. What each person sees follows the caller's grants."""
    _check_range(start, end)
    rbac_service.require_scope(principal, Perm.USERS_READ)
    team = users_service.list_team(db, principal, PageQuery(page=1, page_size=100)).items
    visits = visits_service.list_visits(db, principal, start, end)
    days = visits_service.list_days(db, principal, start, end)
    return [_row(db, member, start, end, visits, days) for member in team]


def member_detail(db: Session, principal: Principal, user_id: int, start: date, end: date) -> MemberDetail:
    _check_range(start, end)
    rbac_service.require_scope(principal, Perm.USERS_READ)
    team = {member.id: member for member in users_service.list_team(db, principal, PageQuery(page=1, page_size=100)).items}
    member = team.get(user_id)
    if member is None:
        raise NotFound(MEMBER_NOT_FOUND)
    visits = [visit for visit in visits_service.list_visits(db, principal, start, end) if visit.user_id == user_id]
    days = [day for day in visits_service.list_days(db, principal, start, end) if day.user_id == user_id]
    row = _row(db, member, start, end, visits, days)
    statuses = {day.visit_date: day.status for day in days}
    calls_by_day: dict[date, int] = {}
    for visit in visits:
        calls_by_day[visit.visit_date] = calls_by_day.get(visit.visit_date, 0) + 1
    day_lines = [
        DayLine(day=day, status=statuses.get(day), calls=calls_by_day.get(day, 0))
        for day in _days_between(start, end)
        if day in statuses or day in calls_by_day
    ]
    call_lines = [
        CallLine(
            visit_id=visit.id,
            visit_date=visit.visit_date,
            visit_time=visit.visit_time,
            day_part=visit.day_part,
            contact_name=visit.contact_name,
            category_name=visit.category_name,
            type_name=visit.type_name,
            products=[product.name for product in visit.products],
            remarks=visit.remarks,
            status=visit.status,
        )
        for visit in sorted(visits, key=_call_order)
    ]
    return MemberDetail(member=row, days=day_lines, calls=call_lines)


@dataclass(frozen=True)
class _Reporter:
    user_id: int
    full_name: str


def _call_order(visit: VisitRead) -> tuple[date, int, time]:
    """By day, then part of the day, then clock time for calls an older app logged with one."""
    return visit.visit_date, DAY_PART_ORDER[visit.day_part], visit.visit_time or time.min


def team_dashboard(db: Session, principal: Principal, start: date, end: date) -> TeamDashboard:
    """Team-wide figures for the admin dashboard. Not narrowed to the caller's own records: the grant is the scope."""
    _check_range(start, end)
    rbac_service.require_scope(principal, Perm.ADMIN_DASHBOARD)
    visits = visits_service.team_visits(db, principal.user_id, start, end)
    month_visits = visits_service.team_visits(db, principal.user_id, visits_service.business_today().replace(day=1), visits_service.business_today())
    days = visits_service.team_days(db, start, end)
    reporters = _reporting_members(db)
    reporter_ids = {reporter.user_id for reporter in reporters}
    ended = [day for day in days if day.status == "ended" and day.user_id in reporter_ids]
    today = visits_service.business_today()
    done = {(visit.user_id, visit.visit_date, visit.contact_id) for visit in visits}
    due = [item for item in planning_service.team_plan_items(db, start, end) if item[1] <= today]
    missed = [item for item in due if item not in done]
    coverage_total = contacts_service.count_active_in_subzones(db, territories_service.active_subzone_ids(db))
    working = _working_days_by_user(db, days, reporter_ids, start, min(end, today))
    period_days = _working_days_in(db, start, min(end, today))
    coverage_by_user = {
        reporter.user_id: contacts_service.count_active_in_subzones(
            db, _subzones_of(db, territories_service.user_territory_ids(db, reporter.user_id))
        )
        for reporter in reporters
    }
    leave_by_user = Counter(day.user_id for day in days if day.status == "leave")
    return TeamDashboard(
        summary=_summary(visits, month_visits, ended, len(reporters), due, missed, coverage_total, working, period_days),
        daily=_daily(visits, month_visits, coverage_total, start, min(end, today)),
        employees=[
            _employee(reporter, visits, month_visits, ended, coverage_by_user[reporter.user_id], working, leave_by_user)
            for reporter in reporters
        ],
        zones=_zones(db, visits, month_visits),
        products=_products(visits),
        categories=_categories(visits),
    )


def team_missed(
    db: Session,
    principal: Principal,
    day: date,
    zone_id: int | None,
    category_name: str | None = None,
) -> list[MissedContactLine]:
    """Active contacts in scope that the team had not visited from the 1st of the month up to and including the day.
    A product narrows it to contacts not given that product: the contacts that missed out on it."""
    rbac_service.require_scope(principal, Perm.ADMIN_DASHBOARD)
    month_visits = visits_service.team_visits(db, principal.user_id, day.replace(day=1), day)
    visited = visits_service.listed_contact_ids(month_visits)
    contacts = contacts_service.active_contacts_in_subzones(db, territories_service.active_subzone_ids(db))
    places = territories_service.subzone_locations(db, {contact.subzone_id for contact in contacts})
    lines = [
        MissedContactLine(
            contact_name=contact.name,
            category_name=contact.category_name,
            type_name=contact.type_name,
            zone_name=places[contact.subzone_id].zone_name,
        )
        for contact in contacts
        if contact.id not in visited
        and (zone_id is None or places[contact.subzone_id].zone_id == zone_id)
        and (category_name is None or contact.category_name == category_name)
    ]
    return sorted(lines, key=lambda line: (line.zone_name, line.contact_name))


def team_calls(
    db: Session,
    principal: Principal,
    start: date,
    end: date,
    zone_id: int | None,
    product_id: int | None,
    category_name: str | None,
) -> list[TeamCallLine]:
    """The team's calls in one zone, product or category for the period, in the order they were made."""
    _check_range(start, end)
    rbac_service.require_scope(principal, Perm.ADMIN_DASHBOARD)
    visits = visits_service.team_visits(db, principal.user_id, start, end)
    selected = [
        visit
        for visit in visits
        if (zone_id is None or visit.zone_id == zone_id)
        and (category_name is None or visit.category_name == category_name)
        and (product_id is None or any(product.id == product_id for product in visit.products))
    ]
    names: dict[int, str] = {}
    lines: list[TeamCallLine] = []
    for visit in sorted(selected, key=_call_order):
        if visit.user_id not in names:
            member = users_service.get_by_id(db, visit.user_id)
            names[visit.user_id] = member.full_name if member else "Unknown"
        lines.append(
            TeamCallLine(
                visit_date=visit.visit_date,
                visit_time=visit.visit_time,
                day_part=visit.day_part,
                rep_name=names[visit.user_id],
                contact_name=visit.contact_name,
                category_name=visit.category_name,
                type_name=visit.type_name,
                zone_name=visit.zone_name,
                products=[product.name for product in visit.products],
                status=visit.status,
            )
        )
    return lines


def _daily(
    visits: list[VisitRead], month_visits: list[VisitRead], coverage_total: int, start: date, end: date
) -> list[DayPoint]:
    """Calls made each day in the period, and the contacts in scope still unvisited by the end of that day this month."""
    calls = Counter(visit.visit_date for visit in visits)
    contacts_by_day: dict[date, set[int]] = defaultdict(set)
    for visit in month_visits:
        if visit.contact_id is not None:
            contacts_by_day[visit.visit_date].add(visit.contact_id)
    seen = {contact for day, contacts in contacts_by_day.items() if day < start for contact in contacts}
    points: list[DayPoint] = []
    for day in _days_between(start, end):
        seen |= contacts_by_day.get(day, set())
        points.append(
            DayPoint(day=day, calls=calls.get(day, 0), missed_calls=max(0, coverage_total - len(seen)))
        )
    return points


def _reporting_members(db: Session) -> list[_Reporter]:
    """Active people whose role has them report their own calls. Oversight roles are left out."""
    reports_by_role: dict[int, bool] = {}
    reporters: list[_Reporter] = []
    for member in users_service.list_active(db):
        if member.role_id not in reports_by_role:
            scope = rbac_service.load_role_access(db, member.role_id).permissions.get(Perm.VISITS_MANAGE.value)
            reports_by_role[member.role_id] = scope is not None and scope != PermissionScope.ALL
        if reports_by_role[member.role_id]:
            reporters.append(_Reporter(user_id=member.id, full_name=member.full_name))
    return reporters


def _working_days_by_user(db: Session, days, reporter_ids: set[int], start: date, end: date) -> dict[int, int]:
    """Working days per reporter: the days up to today, minus Sundays, holidays and that person's leave."""
    holidays = holiday_dates(db, start, end)
    leave: dict[int, set[date]] = defaultdict(set)
    for day in days:
        if day.status == "leave":
            leave[day.user_id].add(day.visit_date)
    return {
        user_id: sum(
            1
            for day in _days_between(start, end)
            if day.weekday() != SUNDAY and day not in holidays and day not in leave[user_id]
        )
        for user_id in reporter_ids
    }


def _working_days_in(db: Session, start: date, end: date) -> int:
    """Working days in the period for one person on a full schedule: no Sundays, no holidays."""
    holidays = holiday_dates(db, start, end)
    return sum(1 for day in _days_between(start, end) if day.weekday() != SUNDAY and day not in holidays)


def _summary(
    visits: list[VisitRead],
    month_visits: list[VisitRead],
    ended,
    reporter_count: int,
    due,
    missed,
    coverage_total: int,
    working: dict[int, int],
    period_days: int,
) -> TeamSummary:
    contacts = len(visits_service.listed_contact_ids(month_visits))
    rep_days = sum(working.values())
    return TeamSummary(
        calls=len(visits),
        contacts_visited=contacts,
        coverage_total=coverage_total,
        coverage_percent=_percent(contacts, coverage_total),
        reporting_reps=reporter_count,
        days_reported=len(ended),
        working_days=period_days,
        avg_calls_per_day=_average(len(visits), rep_days),
        planned_due=len(due),
        planned_achieved=len(due) - len(missed),
        missed_calls=max(0, coverage_total - contacts),
    )


def _employee(
    reporter: _Reporter,
    visits: list[VisitRead],
    month_visits: list[VisitRead],
    ended,
    coverage_total: int,
    working: dict[int, int],
    leave_by_user: Counter,
) -> EmployeeLine:
    mine = [visit for visit in visits if visit.user_id == reporter.user_id]
    days = sum(1 for day in ended if day.user_id == reporter.user_id)
    working_days = working.get(reporter.user_id, 0)
    contacts = len(visits_service.listed_contact_ids([visit for visit in month_visits if visit.user_id == reporter.user_id]))
    return EmployeeLine(
        user_id=reporter.user_id,
        full_name=reporter.full_name,
        calls=len(mine),
        contacts_visited=contacts,
        days_reported=days,
        days_leave=leave_by_user[reporter.user_id],
        working_days=working_days,
        avg_calls_per_day=_average(len(mine), working_days),
        missed_calls=max(0, coverage_total - contacts),
    )


def _zones(db: Session, visits: list[VisitRead], month_visits: list[VisitRead]) -> list[ZoneLine]:
    places = territories_service.subzone_locations(db, territories_service.active_subzone_ids(db)).values()
    subzones_by_zone: dict[int, set[int]] = defaultdict(set)
    names: dict[int, str] = {}
    for place in places:
        subzones_by_zone[place.zone_id].add(place.id)
        names[place.zone_id] = place.zone_name
    lines = []
    for zone_id, name in names.items():
        zone_visits = [visit for visit in visits if visit.zone_id == zone_id]
        contacts = len(visits_service.listed_contact_ids([visit for visit in month_visits if visit.zone_id == zone_id]))
        total = contacts_service.count_active_in_subzones(db, subzones_by_zone[zone_id])
        lines.append(
            ZoneLine(
                zone_id=zone_id,
                zone_name=name,
                calls=len(zone_visits),
                contacts_visited=contacts,
                coverage_total=total,
                coverage_percent=_percent(contacts, total),
                missed_calls=max(0, total - contacts),
            )
        )
    return sorted(lines, key=lambda line: line.zone_name)


def _products(visits: list[VisitRead]) -> list[ProductLine]:
    by_product: dict[int, list[VisitRead]] = defaultdict(list)
    names: dict[int, str] = {}
    for visit in visits:
        for product in visit.products:
            names[product.id] = product.name
            by_product[product.id].append(visit)
    return sorted(
        (
            ProductLine(
                product_id=product_id,
                name=names[product_id],
                calls=len(product_visits),
                contacts_visited=len(visits_service.listed_contact_ids(product_visits)),
                reps=len({visit.user_id for visit in product_visits}),
            )
            for product_id, product_visits in by_product.items()
        ),
        key=lambda line: line.name,
    )


def _categories(visits: list[VisitRead]) -> list[CategoryLine]:
    by_category: dict[str, list[VisitRead]] = defaultdict(list)
    for visit in visits:
        by_category[visit.category_name].append(visit)
    return [
        CategoryLine(
            category_name=name,
            calls=len(category_visits),
            contacts_visited=len(visits_service.listed_contact_ids(category_visits)),
        )
        for name, category_visits in sorted(by_category.items())
    ]


def _percent(part: int, whole: int) -> float:
    return round(100 * part / whole, 1) if whole else 0.0


def _average(calls: int, days: int) -> float:
    return round(calls / days, 1) if days else 0.0


def _row(db: Session, member, start: date, end: date, visits, days) -> MemberRow:
    mine = [visit for visit in visits if visit.user_id == member.id]
    my_days = [day for day in days if day.user_id == member.id]
    reported = {day.visit_date for day in my_days}
    leave = sum(1 for day in my_days if day.status == "leave")
    ended = sum(1 for day in my_days if day.status == "ended")
    subzones = territories_service.user_territory_ids(db, member.id)
    coverage_total = contacts_service.count_active_in_subzones(db, _subzones_of(db, subzones))
    plans_due, plans_achieved = planning_service.plan_outcomes(db, member.id, start, end)
    return MemberRow(
        user_id=member.id,
        full_name=member.full_name,
        role_name=member.role_name,
        is_active=member.is_active,
        calls=len(mine),
        contacts_visited=len(visits_service.listed_contact_ids(mine)),
        coverage_total=coverage_total,
        days_reported=ended,
        days_leave=leave,
        days_never_reported=_never_reported(start, end, reported) if _reports_personally(db, member.id) else 0,
        plans_due=plans_due,
        plans_achieved=plans_achieved,
    )


def _reports_personally(db: Session, user_id: int) -> bool:
    """Whether this person reports their own calls, from their role's grant. Oversight roles do not report."""
    user = users_service.get_by_id(db, user_id)
    if user is None:
        return False
    scope = rbac_service.load_role_access(db, user.role_id).permissions.get(Perm.VISITS_MANAGE.value)
    return scope is not None and scope != PermissionScope.ALL


def _never_reported(start: date, end: date, reported: set[date]) -> int:
    """Past weekdays in the period with no report and no leave, not counting today. Sundays are leave for everyone."""
    today = visits_service.business_today()
    last = min(end, today - timedelta(days=1))
    return sum(
        1
        for day in _days_between(start, last)
        if day.weekday() != 6 and day not in reported
    )


def _subzones_of(db: Session, territory_ids: set[int]) -> set[int]:
    return territories_service.active_subzone_ids(db) & territory_ids


def _days_between(start: date, end: date) -> list[date]:
    return [start + timedelta(days=offset) for offset in range((end - start).days + 1)]


def unlisted_patches(db: Session, principal: Principal, start: date, end: date) -> list[UnlistedPatchLine]:
    """Per patch: unlisted doctors and chemists still open, converted ones, and the calls made on them in the period."""
    _check_range(start, end)
    rbac_service.require_scope(principal, Perm.ADMIN_DASHBOARD)
    items_by_patch: dict[int, list[UnlistedRead]] = defaultdict(list)
    for item in visits_service.team_unlisted(db):
        items_by_patch[item.subzone_id].append(item)
    calls_by_patch = _unlisted_calls_by(_unlisted_visits(db, principal, start, end), lambda visit: visit.subzone_id)
    lines = [
        _patch_line(items, calls_by_patch.get(subzone_id, []))
        for subzone_id, items in items_by_patch.items()
    ]
    return sorted(lines, key=lambda line: (line.zone_name, line.subzone_name))


def unlisted_patch_contacts(
    db: Session, principal: Principal, subzone_id: int, start: date, end: date
) -> list[UnlistedContactLine]:
    """Each unlisted doctor or chemist in one patch, with the calls made on them in the period."""
    _check_range(start, end)
    rbac_service.require_scope(principal, Perm.ADMIN_DASHBOARD)
    items = [item for item in visits_service.team_unlisted(db) if item.subzone_id == subzone_id]
    calls_by_contact = _unlisted_calls_by(_unlisted_visits(db, principal, start, end), lambda visit: visit.unlisted_contact_id)
    return [_contact_line(item, calls_by_contact.get(item.id, [])) for item in sorted(items, key=lambda item: item.name)]


def _unlisted_visits(db: Session, principal: Principal, start: date, end: date) -> list[VisitRead]:
    return [
        visit
        for visit in visits_service.team_visits(db, principal.user_id, start, end)
        if visit.unlisted_contact_id is not None
    ]


def _unlisted_calls_by(visits: list[VisitRead], key: Callable[[VisitRead], int]) -> dict[int, list[VisitRead]]:
    grouped: dict[int, list[VisitRead]] = defaultdict(list)
    for visit in visits:
        grouped[key(visit)].append(visit)
    return grouped


def _patch_line(items: list[UnlistedRead], calls: list[VisitRead]) -> UnlistedPatchLine:
    first = items[0]
    return UnlistedPatchLine(
        subzone_id=first.subzone_id,
        subzone_name=first.subzone_name,
        zone_name=first.zone_name,
        unlisted=sum(1 for item in items if item.status == "unlisted"),
        converted=sum(1 for item in items if item.status == "converted"),
        calls=len(calls),
        reps=len({visit.user_id for visit in calls}),
        categories=_unlisted_categories(calls),
    )


def _unlisted_categories(calls: list[VisitRead]) -> list[UnlistedCategoryLine]:
    by_category: dict[str, list[VisitRead]] = defaultdict(list)
    for visit in calls:
        by_category[visit.category_name].append(visit)
    return [
        UnlistedCategoryLine(
            category_name=name,
            calls=len(category_calls),
            contacts=len({visit.unlisted_contact_id for visit in category_calls}),
        )
        for name, category_calls in sorted(by_category.items())
    ]


def _contact_line(item: UnlistedRead, calls: list[VisitRead]) -> UnlistedContactLine:
    return UnlistedContactLine(
        unlisted_id=item.id,
        name=item.name,
        category_name=item.category_name,
        status=item.status,
        calls=len(calls),
        reps=len({visit.user_id for visit in calls}),
        last_visit=max((visit.visit_date for visit in calls), default=None),
    )


def _check_range(start: date, end: date) -> None:
    if end < start:
        raise BadRequest(RANGE_BACKWARDS)
    if (end - start).days + 1 > MAX_RANGE_DAYS:
        raise BadRequest(RANGE_TOO_LONG)
