from datetime import date

from pydantic import BaseModel, Field


class PlanItemCreate(BaseModel):
    contact_id: int = Field(gt=0)


class PlanItemRead(BaseModel):
    id: int
    plan_date: date
    contact_id: int
    contact_name: str
    category_name: str
    zone_name: str
    subzone_name: str
    status: str


class PlanDayRead(BaseModel):
    """One day the rep planned or marked as leave. Days with neither are not returned."""

    plan_date: date
    is_leave: bool
    items: list[PlanItemRead]
