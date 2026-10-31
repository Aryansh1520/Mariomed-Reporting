from typing import Literal

from datetime import date, datetime, time

from pydantic import BaseModel, Field, field_validator


def _clean(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("Enter the remarks for this call.")
    return stripped


class VisitCreate(BaseModel):
    contact_id: int
    visit_date: date
    visit_time: time
    remarks: str = Field(min_length=1, max_length=2000)
    product_ids: list[int] = Field(min_length=1, max_length=50)
    partner_user_id: int | None = None

    @field_validator("remarks")
    @classmethod
    def _check_remarks(cls, value: str) -> str:
        return _clean(value)


class VisitUpdate(BaseModel):
    """Changes the fields that are sent. Sending partner_user_id as null removes the joint partner."""

    contact_id: int | None = None
    visit_time: time | None = None
    remarks: str | None = Field(default=None, min_length=1, max_length=2000)
    product_ids: list[int] | None = Field(default=None, min_length=1, max_length=50)
    partner_user_id: int | None = None

    @field_validator("remarks")
    @classmethod
    def _check_remarks(cls, value: str | None) -> str | None:
        return None if value is None else _clean(value)


class ProductRef(BaseModel):
    id: int
    name: str


class VisitRead(BaseModel):
    id: int
    user_id: int
    rep_name: str
    visit_date: date
    visit_time: time
    status: str
    remarks: str
    contact_id: int
    contact_name: str
    category_name: str
    zone_id: int
    zone_name: str
    subzone_id: int
    subzone_name: str
    products: list[ProductRef]
    partner_user_id: int | None
    partner_status: str | None
    is_editable: bool


class VisitDayRead(BaseModel):
    id: int
    user_id: int
    visit_date: date
    status: str
    ended_at: datetime | None


class JointPartnerRead(BaseModel):
    user_id: int
    full_name: str


class JointRequestRead(BaseModel):
    """A joint call another rep recorded with the caller. The caller accepts or disputes it."""

    visit_id: int
    initiator_user_id: int
    visit_date: date
    visit_time: time
    contact_name: str
    category_name: str
    zone_name: str
    subzone_name: str
    remarks: str
    products: list[ProductRef]
    status: str
    can_respond: bool


class DisputeDecision(BaseModel):
    """What the admin decides for a disputed joint call: credit both reps, the recorder only, or nobody."""

    decision: Literal["both", "them", "none"]
