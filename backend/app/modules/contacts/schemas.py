from pydantic import BaseModel, ConfigDict, Field, field_validator


def _clean(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("Enter a name.")
    return stripped


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str) -> str:
        return _clean(value)


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str | None) -> str | None:
        return None if value is None else _clean(value)


class CategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    is_active: bool


class ContactCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    category_id: int
    subzone_id: int

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str) -> str:
        return _clean(value)


class ContactUpdate(BaseModel):
    """Changes the fields that are sent. A contact moved to another subzone keeps its history."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    category_id: int | None = None
    subzone_id: int | None = None
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str | None) -> str | None:
        return None if value is None else _clean(value)


class ContactRead(BaseModel):
    id: int
    name: str
    category_id: int
    category_name: str
    subzone_id: int
    subzone_name: str
    zone_id: int
    zone_name: str
    is_active: bool


class ContactRef(BaseModel):
    """The short form of a contact, used inside visit records."""

    id: int
    name: str
    category_name: str
    subzone_id: int
    is_active: bool


class ContactListQuery(BaseModel):
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)
    zone_id: int | None = None
    subzone_id: int | None = None
    category_id: int | None = None

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size
