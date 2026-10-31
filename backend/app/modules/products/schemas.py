from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _clean(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("This field cannot be blank.")
    return stripped


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    code: str = Field(min_length=1, max_length=40)
    description: str | None = Field(default=None, max_length=2000)

    @field_validator("name", "code")
    @classmethod
    def _check_required(cls, value: str) -> str:
        return _clean(value)


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    code: str | None = Field(default=None, min_length=1, max_length=40)
    description: str | None = Field(default=None, max_length=2000)
    is_active: bool | None = None

    @field_validator("name", "code")
    @classmethod
    def _check_required(cls, value: str | None) -> str | None:
        return None if value is None else _clean(value)


class ProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    code: str
    description: str | None
    is_active: bool
    updated_at: datetime
