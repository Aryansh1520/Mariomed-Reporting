from pydantic import BaseModel, Field

from app.modules.rbac.catalog import PermissionScope


class GrantIn(BaseModel):
    code: str = Field(min_length=1, max_length=120)
    # Null for permissions that are not scoped, such as create.
    scope: PermissionScope | None = None


class RoleCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    grants: list[GrantIn] = Field(default_factory=list, max_length=200)


class RoleUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    grants: list[GrantIn] | None = Field(default=None, max_length=200)


class RoleRead(BaseModel):
    id: int
    code: str
    name: str
    is_locked: bool
    grants: list[GrantIn]


class PermissionRead(BaseModel):
    code: str
    description: str
    module: str
    scoped: bool
    requires: str | None
