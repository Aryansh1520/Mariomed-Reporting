from datetime import date

from pydantic import BaseModel


class TodayStats(BaseModel):
    date: date
    calls: int
    day_status: str | None
    planned: int | None
    is_leave: bool | None


class MonthStats(BaseModel):
    calls: int
    contacts_visited: int
    days_reported: int


class CoverageStats(BaseModel):
    visited: int
    total: int
    percent: float


class MissedStats(BaseModel):
    """Active contacts the caller can visit that were not visited this month."""

    missed_contacts: int


class NextUpItem(BaseModel):
    plan_date: date
    contact_name: str
    category_name: str
    subzone_name: str


class DayCount(BaseModel):
    date: date
    count: int


class TeamStats(BaseModel):
    active_users: int


class SetupStats(BaseModel):
    zones: int
    subzones: int
    contacts: int | None
    products: int | None


class DashboardRead(BaseModel):
    """Each section is present only when the caller's permissions allow it. Absent sections are null."""

    today: TodayStats | None
    month: MonthStats | None
    coverage: CoverageStats | None
    missed: MissedStats | None
    next_up: list[NextUpItem] | None
    daily_calls: list[DayCount] | None
    joint_waiting: int | None
    team: TeamStats | None
    setup: SetupStats | None = None
