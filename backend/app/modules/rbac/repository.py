from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.rbac.models import Permission, Role, RolePermission


def list_permissions(db: Session) -> list[Permission]:
    return list(db.scalars(select(Permission)))


def add_permission(db: Session, permission: Permission) -> Permission:
    db.add(permission)
    db.flush()
    return permission


def get_role(db: Session, role_id: int) -> Role | None:
    return db.get(Role, role_id)


def get_role_by_code(db: Session, code: str) -> Role | None:
    return db.scalar(select(Role).where(Role.code == code))


def list_roles(db: Session) -> list[Role]:
    return list(db.scalars(select(Role).order_by(Role.name)))


def roles_by_id(db: Session) -> dict[int, Role]:
    return {role.id: role for role in db.scalars(select(Role))}


def users_on_role(db: Session, role_id: int) -> int:
    from app.modules.users.models import User

    return db.scalar(select(func.count()).select_from(User).where(User.role_id == role_id)) or 0


def add_role(db: Session, role: Role) -> Role:
    db.add(role)
    db.flush()
    return role


def delete_role(db: Session, role: Role) -> None:
    db.delete(role)


def list_grants(db: Session, role_id: int) -> list[tuple[str, str | None]]:
    rows = db.execute(
        select(Permission.code, RolePermission.scope)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .where(RolePermission.role_id == role_id)
    )
    return [(code, scope) for code, scope in rows]


def list_grant_rows(db: Session, role_id: int) -> list[RolePermission]:
    return list(db.scalars(select(RolePermission).where(RolePermission.role_id == role_id)))


def add_grant(db: Session, grant: RolePermission) -> None:
    db.add(grant)
