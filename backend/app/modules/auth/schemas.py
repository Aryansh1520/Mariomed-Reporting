from datetime import datetime

from pydantic import BaseModel, Field

from app.modules.rbac.catalog import PermissionScope


class LoginRequest(BaseModel):
    identifier: str = Field(min_length=3, max_length=254, description="Mobile number or email")
    password: str = Field(min_length=1, max_length=256)


class PermissionRead(BaseModel):
    code: str
    scope: PermissionScope


class CurrentUserRead(BaseModel):
    id: int
    full_name: str
    email: str
    mobile: str
    role_code: str
    role_name: str
    permissions: list[PermissionRead]


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: CurrentUserRead


class PasswordResetRequest(BaseModel):
    identifier: str = Field(min_length=3, max_length=254, description="Mobile number or email")


class PasswordResetConfirm(BaseModel):
    identifier: str = Field(min_length=3, max_length=254, description="Mobile number or email")
    code: str = Field(pattern=r"^\d{6}$", description="Six-digit code from the reset email")
    new_password: str = Field(min_length=8, max_length=256)
