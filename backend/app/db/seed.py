"""Creates the permission catalogue, the admin role, an example sales representative role and demo accounts. Safe to run again.

Run from the backend folder: python -m app.db.seed
Roles go through the same role service the admin uses. Only the admin role is locked.
"""

import json
from pathlib import Path

from sqlalchemy import func, select

from app.core.config import settings
from app.db.session import SessionLocal
from app.modules.contacts import service as contacts_service
from app.modules.rbac import repository as rbac_repository
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm, PermissionScope
from app.modules.rbac.models import Role
from app.modules.territories.models import MapRegion
from app.modules.users import service as users_service
from app.modules.users.schemas import UserCreate

SALES_REP_ROLE_NAME = "Sales Representative"
SALES_REP_ROLE_CODE = "sales_representative"

TEAM_ADMIN_ROLE_NAME = "Team administrator"
TEAM_ADMIN_ROLE_CODE = "team_administrator"

CONTACT_CATEGORY_NAMES = ("Doctor", "Chemist")

# Example grants for someone who runs the team without reporting calls: people, roles, zones, contacts,
# products and the setup. They read every visit to see coverage, but they cannot record one.
DEMO_TEAM_ADMIN_GRANTS: dict[str, PermissionScope | None] = {
    Perm.TERRITORIES_READ.value: PermissionScope.ALL,
    Perm.TERRITORIES_MANAGE.value: PermissionScope.ALL,
    Perm.CONTACTS_READ.value: PermissionScope.ALL,
    Perm.CONTACTS_MANAGE.value: PermissionScope.ALL,
    Perm.PRODUCTS_READ.value: None,
    Perm.PRODUCTS_MANAGE.value: None,
    Perm.USERS_READ.value: PermissionScope.ALL,
    Perm.USERS_MANAGE.value: PermissionScope.ALL,
    Perm.ROLES_MANAGE.value: None,
    Perm.SETTINGS_MANAGE.value: None,
    Perm.VISITS_READ.value: PermissionScope.ALL,
    Perm.VISITS_REVIEW.value: PermissionScope.ALL,
    Perm.ANALYTICS_READ.value: PermissionScope.ALL,
    Perm.ADMIN_DASHBOARD.value: None,
}

# Example grants for a sales representative. Admins build their own roles the same way.
DEMO_SALES_REP_GRANTS: dict[str, PermissionScope | None] = {
    Perm.TERRITORIES_READ.value: PermissionScope.ASSIGNED,
    Perm.PRODUCTS_READ.value: None,
    Perm.CONTACTS_READ.value: PermissionScope.ASSIGNED,
    Perm.PLANS_READ.value: PermissionScope.SELF,
    Perm.PLANS_MANAGE.value: PermissionScope.SELF,
    Perm.VISITS_READ.value: PermissionScope.SELF,
    Perm.VISITS_MANAGE.value: PermissionScope.SELF,
    Perm.TASKS_READ.value: PermissionScope.ASSIGNED,
    Perm.TASKS_MANAGE.value: PermissionScope.ASSIGNED,
    Perm.DAILY_REPORTS_READ.value: PermissionScope.SELF,
    Perm.DAILY_REPORTS_MANAGE.value: PermissionScope.SELF,
    Perm.TARGETS_READ.value: PermissionScope.SELF,
}


def run_seed() -> None:
    with SessionLocal() as db:
        rbac_service.sync_catalog(db)
        admin_role = rbac_service.ensure_admin_role(db)
        sales_rep_role = _sales_rep_role(db)
        team_admin_role = _team_admin_role(db)
        _ensure_user(db, admin_role.id, _admin_user())
        _ensure_user(db, sales_rep_role.id, _sales_rep_user())
        _ensure_user(db, team_admin_role.id, _team_admin_user())
        _ensure_map_regions(db)
        for name in CONTACT_CATEGORY_NAMES:
            contacts_service.ensure_category(db, name)
        db.commit()


def _ensure_map_regions(db) -> None:
    """Loads the service-area outlines from the bundled map file. Existing outlines are left as they are."""
    document = json.loads((Path(__file__).parent.parent / "data" / "mumbai_region.json").read_text())
    for feature in document["features"]:
        if db.scalar(select(MapRegion.id).where(MapRegion.name == feature["name"])) is not None:
            continue
        multipolygon = {"type": "MultiPolygon", "coordinates": [[ring] for ring in feature["rings"]]}
        db.add(
            MapRegion(
                name=feature["name"],
                kind=feature["kind"],
                geom=func.ST_Multi(func.ST_MakeValid(func.ST_SetSRID(func.ST_GeomFromGeoJSON(json.dumps(multipolygon)), 4326))),
            )
        )
    db.flush()


def _sales_rep_role(db) -> Role:
    role = rbac_repository.get_role_by_code(db, SALES_REP_ROLE_CODE)
    if role is None:
        return rbac_service.seed_role(db, SALES_REP_ROLE_NAME, DEMO_SALES_REP_GRANTS)
    rbac_service.sync_seed_grants(db, role, DEMO_SALES_REP_GRANTS)
    return role


def _team_admin_role(db) -> Role:
    role = rbac_repository.get_role_by_code(db, TEAM_ADMIN_ROLE_CODE)
    if role is None:
        return rbac_service.seed_role(db, TEAM_ADMIN_ROLE_NAME, DEMO_TEAM_ADMIN_GRANTS)
    rbac_service.sync_seed_grants(db, role, DEMO_TEAM_ADMIN_GRANTS)
    return role


def _team_admin_user() -> UserCreate:
    return UserCreate(
        full_name="Demo Team Administrator",
        email="team.admin@demo.in",
        mobile="9800000004",
        password=settings.seed_password,
    )


def _admin_user() -> UserCreate:
    return UserCreate(
        full_name="Demo Admin",
        email="admin@demo.in",
        mobile="9800000001",
        password=settings.seed_password,
    )


def _sales_rep_user() -> UserCreate:
    return UserCreate(
        full_name="Demo Representative",
        email="rep@demo.in",
        mobile="9800000002",
        password=settings.seed_password,
    )


def _ensure_user(db, role_id: int, data: UserCreate) -> None:
    if users_service.find_by_mobile(db, data.mobile) is not None:
        return
    users_service.create_user(db, role_id, data, created_by=None)


if __name__ == "__main__":
    run_seed()
