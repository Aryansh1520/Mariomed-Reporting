from typing import Literal, get_args

from datetime import date, datetime, time

from pydantic import BaseModel, Field, field_validator, model_validator

DayPart = Literal["morning", "afternoon", "evening"]
DAY_PART_ORDER: dict[str, int] = {part: rank for rank, part in enumerate(get_args(DayPart))}
ONE_WHEN_ONLY = "Send either the time or the part of the day for this call, not both."
ONE_SUBJECT_ONLY = "Record the call on a contact or on an unlisted doctor or chemist, not both."


def _clean(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("Enter the remarks for this call.")
    return stripped


class VisitCreate(BaseModel):
    """A call is placed by its part of the day. Older app versions send a clock time instead.
    It is placed on a listed contact, or on an unlisted doctor or chemist of the patch, never both."""

    contact_id: int | None = None
    unlisted_contact_id: int | None = None
    visit_date: date
    visit_time: time | None = None
    day_part: DayPart | None = None
    remarks: str = Field(min_length=1, max_length=2000)
    product_ids: list[int] = Field(min_length=1, max_length=50)
    partner_user_id: int | None = None

    @model_validator(mode="after")
    def _check_when(self) -> "VisitCreate":
        if (self.visit_time is None) == (self.day_part is None):
            raise ValueError("Choose the part of the day for this call." if self.day_part is None else ONE_WHEN_ONLY)
        return self

    @model_validator(mode="after")
    def _check_subject(self) -> "VisitCreate":
        if (self.contact_id is None) == (self.unlisted_contact_id is None):
            raise ValueError(ONE_SUBJECT_ONLY)
        return self

    @field_validator("remarks")
    @classmethod
    def _check_remarks(cls, value: str) -> str:
        return _clean(value)


class VisitUpdate(BaseModel):
    """Changes the fields that are sent. Sending partner_user_id as null removes the joint partner."""

    contact_id: int | None = None
    visit_time: time | None = None
    day_part: DayPart | None = None
    remarks: str | None = Field(default=None, min_length=1, max_length=2000)
    product_ids: list[int] | None = Field(default=None, min_length=1, max_length=50)
    partner_user_id: int | None = None

    @model_validator(mode="after")
    def _check_when(self) -> "VisitUpdate":
        if self.visit_time is not None and self.day_part is not None:
            raise ValueError(ONE_WHEN_ONLY)
        return self

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
    visit_time: time | None
    day_part: DayPart
    status: str
    remarks: str
    contact_id: int | None
    unlisted_contact_id: int | None
    contact_name: str
    category_name: str
    type_name: str | None
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
    visit_time: time | None
    day_part: DayPart
    contact_name: str
    category_name: str
    type_name: str | None
    zone_name: str
    subzone_name: str
    remarks: str
    products: list[ProductRef]
    status: str
    can_respond: bool


def _clean_name(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("Enter the name of the doctor or chemist.")
    return stripped


class UnlistedCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    category_id: int
    subzone_id: int

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str) -> str:
        return _clean_name(value)


class UnlistedRead(BaseModel):
    id: int
    name: str
    category_id: int
    category_name: str
    subzone_id: int
    subzone_name: str
    zone_id: int
    zone_name: str
    status: str
    added_by: str | None
    added_at: datetime
    converted_by: str | None
    converted_at: datetime | None


class UnlistedCall(BaseModel):
    visit_id: int
    visit_date: date
    visit_time: time | None
    day_part: DayPart
    rep_name: str
    status: str
    products: list[str]
    remarks: str


class UnlistedDetailRead(BaseModel):
    """One unlisted contact in full: who added it and when, its conversion, and the calls made on it."""

    unlisted: UnlistedRead
    calls_total: int
    reps: int
    last_visit: date | None
    calls: list[UnlistedCall]


class UnlistedListQuery(BaseModel):
    subzone_id: int
    include_converted: bool = False
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=100, ge=1, le=100)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


class UnlistedSimilarQuery(BaseModel):
    """Unlisted contacts in the patch with the same name, so a rep can pick one instead of adding a duplicate."""

    subzone_id: int
    name: str = Field(min_length=1, max_length=120)

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str) -> str:
        return _clean_name(value)


class DisputeDecision(BaseModel):
    """What the admin decides for a disputed joint call: credit both reps, the recorder only, or nobody."""

    decision: Literal["both", "them", "none"]
