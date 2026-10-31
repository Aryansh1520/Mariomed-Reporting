import re

from sqlalchemy.orm import Session

from app.core.exceptions import BadRequest, Conflict, Forbidden, NotFound
from app.modules.audit import service as audit
from app.modules.rbac import repository
from app.modules.rbac.catalog import (
    ADMIN_ROLE,
    PERMISSIONS,
    SCOPE_WIDTH,
    Perm,
    PermissionScope,
    admin_grants,
    definition_of,
    with_dependencies,
)
from app.modules.rbac.models import Permission, Role, RolePermission
from app.modules.rbac.principal import AccessFilter, Principal, RoleAccess

ROLE_LOCKED = "The administrator role cannot be changed."
ROLE_IN_USE = "This role still has users. Move them to another role first."
ROLE_NOT_FOUND = "This role does not exist."
UNKNOWN_PERMISSION = "This permission does not exist."
ESCALATION = "You can only give permissions you hold, at the same or a wider scope."


def sync_catalog(db: Session) -> None:
    """Makes the permission rows match catalog.py. Run on every deploy."""
    existing = {permission.code: permission for permission in repository.list_permissions(db)}
    for definition in PERMISSIONS:
        code = definition.code.value
        permission = existing.get(code)
        if permission is None:
            repository.add_permission(
                db,
                Permission(code=code, description=definition.description, module=definition.module),
            )
        else:
            permission.description = definition.description
            permission.module = definition.module
    db.flush()


def ensure_admin_role(db: Session) -> Role:
    """The one locked role. Recreated and restored to full access whenever it is checked."""
    role = repository.get_role_by_code(db, ADMIN_ROLE.code)
    if role is None:
        role = repository.add_role(
            db,
            Role(code=ADMIN_ROLE.code, name=ADMIN_ROLE.name, is_system=True, is_locked=True),
        )
    _replace_grants(db, role, admin_grants())
    return role


def list_roles(db: Session, principal: Principal) -> list[Role]:
    require_scope(principal, Perm.ROLES_MANAGE)
    return repository.list_roles(db)


def roles_by_id(db: Session) -> dict[int, Role]:
    return repository.roles_by_id(db)


def get_role(db: Session, role_id: int) -> Role:
    role = repository.get_role(db, role_id)
    if role is None:
        raise NotFound(ROLE_NOT_FOUND)
    return role


def create_role(
    db: Session, principal: Principal, name: str, grants: dict[str, PermissionScope | None]
) -> Role:
    require_scope(principal, Perm.ROLES_MANAGE)
    expanded = _validated_grants(principal, grants)
    role = repository.add_role(db, Role(code=_unique_code(db, name), name=name.strip()))
    _replace_grants(db, role, expanded)
    audit.record(db, principal.user_id, "role.create", "role", role.id)
    db.commit()
    return role


def update_role(
    db: Session,
    principal: Principal,
    role_id: int,
    name: str | None,
    grants: dict[str, PermissionScope | None] | None,
) -> Role:
    require_scope(principal, Perm.ROLES_MANAGE)
    role = get_role(db, role_id)
    if role.is_locked:
        raise Forbidden(ROLE_LOCKED)
    if name is not None:
        role.name = name.strip()
    if grants is not None:
        _replace_grants(db, role, _validated_grants(principal, grants))
    audit.record(db, principal.user_id, "role.update", "role", role.id)
    db.commit()
    return role


def delete_role(db: Session, principal: Principal, role_id: int) -> None:
    require_scope(principal, Perm.ROLES_MANAGE)
    role = get_role(db, role_id)
    if role.is_locked:
        raise Forbidden(ROLE_LOCKED)
    if repository.users_on_role(db, role.id) > 0:
        raise Conflict(ROLE_IN_USE)
    audit.record(db, principal.user_id, "role.delete", "role", role.id)
    repository.delete_role(db, role)
    db.commit()


def seed_role(db: Session, name: str, grants: dict[str, PermissionScope | None]) -> Role:
    """The same rules as create_role, for seeds and setup scripts, which act without a signed-in user."""
    role = repository.add_role(db, Role(code=_unique_code(db, name), name=name.strip()))
    _replace_grants(db, role, with_dependencies(grants))
    return role


def sync_seed_grants(db: Session, role: Role, grants: dict[str, PermissionScope | None]) -> None:
    """Brings a seeded role up to the seed's grants. Used when the seed runs again after the grants changed."""
    _replace_grants(db, role, with_dependencies(grants))


def load_role_access(db: Session, role_id: int) -> RoleAccess:
    role = repository.roles_by_id(db).get(role_id)
    if role is None:
        raise Forbidden("Your role no longer exists. Contact your admin.")
    if role.is_locked:
        permissions = admin_grants()
    else:
        # Create-type grants carry no scope but still allow the action, so they load at the widest scope.
        permissions = {
            code: PermissionScope(scope) if scope is not None else PermissionScope.ALL
            for code, scope in repository.list_grants(db, role_id)
        }
    return RoleAccess(role_code=role.code, role_name=role.name, permissions=permissions)


def require_scope(principal: Principal, code: Perm) -> PermissionScope:
    if code.value not in principal.permissions:
        raise Forbidden("You do not have permission to do this.")
    return principal.permissions[code.value]


def access_filter(principal: Principal, code: Perm) -> AccessFilter:
    """Which records the caller may reach for this permission, as filters for the query."""
    scope = require_scope(principal, code)
    if scope == PermissionScope.ALL:
        return AccessFilter(owner_id=None, assignee_id=None)
    if scope == PermissionScope.SELF:
        return AccessFilter(owner_id=principal.user_id, assignee_id=None)
    return AccessFilter(owner_id=None, assignee_id=principal.user_id)


def owner_filter(principal: Principal, code: Perm) -> int | None:
    return access_filter(principal, code).owner_id


def _validated_grants(
    principal: Principal, grants: dict[str, PermissionScope | None]
) -> dict[str, PermissionScope | None]:
    known = {definition.code.value for definition in PERMISSIONS}
    for code in grants:
        if code not in known:
            raise BadRequest(UNKNOWN_PERMISSION)
    expanded = with_dependencies(grants)
    for code, scope in expanded.items():
        _check_no_escalation(principal, definition_of(code).scoped, code, scope)
    return expanded


def _check_no_escalation(
    principal: Principal, scoped: bool, code: str, requested: PermissionScope | None
) -> None:
    held = principal.permissions.get(code)
    if held is None:
        raise Forbidden(ESCALATION)
    if scoped and requested is not None and SCOPE_WIDTH[held] < SCOPE_WIDTH[requested]:
        raise Forbidden(ESCALATION)


def _replace_grants(db: Session, role: Role, grants: dict[str, PermissionScope | None]) -> None:
    db.flush()
    permissions = {p.code: p for p in repository.list_permissions(db)}
    for row in repository.list_grant_rows(db, role.id):
        db.delete(row)
    db.flush()
    for code, scope in grants.items():
        repository.add_grant(
            db,
            RolePermission(
                role_id=role.id,
                permission_id=permissions[code].id,
                scope=scope.value if scope is not None else None,
            ),
        )
    db.flush()


def _unique_code(db: Session, name: str) -> str:
    base = re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")[:50] or "role"
    code, suffix = base, 1
    while repository.get_role_by_code(db, code) is not None:
        suffix += 1
        code = f"{base}_{suffix}"
    return code
