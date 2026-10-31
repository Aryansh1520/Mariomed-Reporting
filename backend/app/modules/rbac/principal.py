from collections.abc import Mapping
from dataclasses import dataclass

from app.modules.rbac.catalog import PermissionScope


@dataclass(frozen=True)
class RoleAccess:
    role_code: str
    role_name: str
    permissions: Mapping[str, PermissionScope]


@dataclass(frozen=True)
class Principal:
    """The signed-in caller, built once per request from the session and the role's current grants."""

    user_id: int
    session_id: int
    role_id: int
    role_code: str
    role_name: str
    permissions: Mapping[str, PermissionScope]


@dataclass(frozen=True)
class AccessFilter:
    """Filters a query by what the caller may reach. None means no restriction on that field."""

    owner_id: int | None
    assignee_id: int | None
