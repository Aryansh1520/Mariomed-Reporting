from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.validators import normalize_email, normalize_full_name, normalize_mobile


class UserCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    email: str = Field(min_length=3, max_length=254)
    mobile: str
    password: str = Field(min_length=8, max_length=256)

    @field_validator("full_name")
    @classmethod
    def _check_full_name(cls, value: str) -> str:
        return normalize_full_name(value)

    @field_validator("email")
    @classmethod
    def _check_email(cls, value: str) -> str:
        return normalize_email(value)

    @field_validator("mobile")
    @classmethod
    def _check_mobile(cls, value: str) -> str:
        return normalize_mobile(value)


class TeamUserCreate(UserCreate):
    """What an admin sends to add someone to the team."""

    role_code: str = Field(min_length=1, max_length=60)


class TeamUserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    email: str | None = Field(default=None, min_length=3, max_length=254)
    mobile: str | None = None
    role_code: str | None = Field(default=None, min_length=1, max_length=60)
    password: str | None = Field(default=None, min_length=8, max_length=256)

    @field_validator("full_name")
    @classmethod
    def _check_full_name(cls, value: str | None) -> str | None:
        return None if value is None else normalize_full_name(value)

    @field_validator("email")
    @classmethod
    def _check_email(cls, value: str | None) -> str | None:
        return None if value is None else normalize_email(value)

    @field_validator("mobile")
    @classmethod
    def _check_mobile(cls, value: str | None) -> str | None:
        return None if value is None else normalize_mobile(value)


class TeamUserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    email: str
    mobile: str
    role_code: str
    role_name: str
    is_active: bool
    last_login_at: datetime | None


class ActivationRequest(BaseModel):
    is_active: bool
