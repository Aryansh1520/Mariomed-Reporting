from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_principal
from app.modules.rbac import repository, service
from app.modules.rbac.catalog import PERMISSIONS, PermissionScope
from app.modules.rbac.principal import Principal
from app.modules.rbac.schemas import GrantIn, PermissionRead, RoleCreate, RoleRead, RoleUpdate

router = APIRouter()


@router.get("/permissions", response_model=list[PermissionRead])
def list_permissions(
    principal: Principal = Depends(get_principal),
) -> list[PermissionRead]:
    service.require_scope(principal, _roles_access())
    return [
        PermissionRead(
            code=d.code.value,
            description=d.description,
            module=d.module,
            scoped=d.scoped,
            requires=d.requires.value if d.requires else None,
        )
        for d in PERMISSIONS
    ]


@router.get("", response_model=list[RoleRead])
def list_roles(
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> list[RoleRead]:
    return [_read(db, role) for role in service.list_roles(db, principal)]


@router.post("", response_model=RoleRead)
def create_role(
    body: RoleCreate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> RoleRead:
    role = service.create_role(db, principal, body.name, _grants(body.grants))
    return _read(db, role)


@router.patch("/{role_id}", response_model=RoleRead)
def update_role(
    role_id: int,
    body: RoleUpdate,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> RoleRead:
    grants = _grants(body.grants) if body.grants is not None else None
    role = service.update_role(db, principal, role_id, body.name, grants)
    return _read(db, role)


@router.delete("/{role_id}", response_model=None)
def delete_role(
    role_id: int,
    principal: Principal = Depends(get_principal),
    db: Session = Depends(get_db),
) -> None:
    service.delete_role(db, principal, role_id)


def _grants(items: list[GrantIn]) -> dict[str, PermissionScope | None]:
    return {item.code: item.scope for item in items}


def _read(db: Session, role) -> RoleRead:
    return RoleRead(
        id=role.id,
        code=role.code,
        name=role.name,
        is_locked=role.is_locked,
        grants=[GrantIn(code=code, scope=scope) for code, scope in repository.list_grants(db, role.id)],
    )


def _roles_access():
    from app.modules.rbac.catalog import Perm

    return Perm.ROLES_MANAGE
