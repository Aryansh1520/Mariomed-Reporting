from datetime import date, time
from typing import Literal

from pydantic import BaseModel

from app.modules.visits.schemas import DayPart


class MemberRow(BaseModel):
    """One person's performance over the chosen period."""

    user_id: int
    full_name: str
    role_name: str
    is_active: bool
    calls: int
    contacts_visited: int
    coverage_total: int
    days_reported: int
    days_leave: int
    days_never_reported: int
    plans_due: int
    plans_achieved: int


class DayLine(BaseModel):
    day: date
    status: str | None
    calls: int


class CallLine(BaseModel):
    visit_id: int
    visit_date: date
    visit_time: time | None
    day_part: DayPart
    contact_name: str
    category_name: str
    type_name: str | None
    products: list[str]
    remarks: str
    status: str
    is_unlisted: bool


class MemberDetail(BaseModel):
    member: MemberRow
    days: list[DayLine]
    calls: list[CallLine]


class TeamSummary(BaseModel):
    """Team-wide figures for the period. Averages are per reported day; missed calls are planned calls due and not made."""

    calls: int
    contacts_visited: int
    coverage_total: int
    coverage_percent: float
    reporting_reps: int
    days_reported: int
    working_days: int
    avg_calls_per_day: float
    planned_due: int
    planned_achieved: int
    missed_calls: int


class EmployeeLine(BaseModel):
    user_id: int
    full_name: str
    calls: int
    contacts_visited: int
    days_reported: int
    days_leave: int
    working_days: int
    avg_calls_per_day: float
    missed_calls: int


class ZoneLine(BaseModel):
    zone_id: int
    zone_name: str
    calls: int
    contacts_visited: int
    coverage_total: int
    coverage_percent: float
    missed_calls: int


class ProductLine(BaseModel):
    product_id: int
    name: str
    calls: int
    contacts_visited: int
    reps: int


class CategoryLine(BaseModel):
    category_name: str
    calls: int
    contacts_visited: int


class UnlistedCategoryLine(BaseModel):
    category_name: str
    calls: int
    contacts: int


class UnlistedPatchLine(BaseModel):
    """Unlisted doctors and chemists in one patch: how many are open, how many were converted, and the calls on them."""

    subzone_id: int
    subzone_name: str
    zone_name: str
    unlisted: int
    converted: int
    calls: int
    reps: int
    categories: list[UnlistedCategoryLine]


class UnlistedContactLine(BaseModel):
    unlisted_id: int
    name: str
    category_name: str
    status: str
    calls: int
    reps: int
    last_visit: date | None


class DayPoint(BaseModel):
    """Calls made that day, and contacts in scope still unvisited at the end of it."""

    day: date
    calls: int
    missed_calls: int


class TeamCallLine(BaseModel):
    visit_date: date
    visit_time: time | None
    day_part: DayPart
    rep_name: str
    contact_name: str
    category_name: str
    type_name: str | None
    zone_name: str
    products: list[str]
    status: str
    is_unlisted: bool
    remarks: str


class DayEmployeeLine(BaseModel):
    """One employee's standing on a day: whether they reported it, and how many calls they made."""

    user_id: int
    full_name: str
    calls: int
    status: Literal["reported", "not_reported", "leave"]


class TeamDayRoster(BaseModel):
    """Who reported the day and who did not. A holiday or Sunday has no roster."""

    day: date
    is_holiday: bool
    holiday_name: str | None
    reported: list[DayEmployeeLine]
    not_reported: list[DayEmployeeLine]


class MissedContactLine(BaseModel):
    contact_name: str
    category_name: str
    type_name: str | None
    zone_name: str
    is_unlisted: bool


class TeamDashboard(BaseModel):
    summary: TeamSummary
    daily: list[DayPoint]
    employees: list[EmployeeLine]
    zones: list[ZoneLine]
    products: list[ProductLine]
    categories: list[CategoryLine]
