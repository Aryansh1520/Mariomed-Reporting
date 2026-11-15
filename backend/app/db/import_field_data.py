"""Loads the headquarters, patches, doctors and chemists from the reviewed data file, through the same services the app uses.

Run from the backend folder: python -m app.db.import_field_data --admin-mobile <admin mobile>
Safe to run again: rows that already exist are skipped. Each new row is recorded in the audit log under the admin account.
"""

import argparse
import json
import logging
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.modules.contacts import repository as contacts_repository
from app.modules.contacts import service as contacts_service
from app.modules.contacts.models import Contact
from app.modules.contacts.schemas import ContactCreate, TypeCreate
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import ADMIN_ROLE
from app.modules.rbac.principal import Principal
from app.modules.territories import service as territories_service
from app.modules.territories.models import Territory
from app.modules.territories.schemas import TerritoryCreate
from app.modules.users import service as users_service

logger = logging.getLogger(__name__)

DATA_FILE = Path(__file__).parent.parent / "data" / "hq_contacts.json"
DOCTOR = "Doctor"
CHEMIST = "Chemist"


def _admin_principal(db: Session, mobile: str) -> Principal:
    user = users_service.find_by_mobile(db, mobile)
    if user is None:
        raise SystemExit(f"No user has the mobile number {mobile}.")
    access = rbac_service.load_role_access(db, user.role_id)
    if access.role_code != ADMIN_ROLE.code:
        raise SystemExit("The import must run as the admin account.")
    # No sign-in session exists for a command-line run. The services use only the user id and the grants.
    return Principal(
        user_id=user.id,
        session_id=0,
        role_id=user.role_id,
        role_code=access.role_code,
        role_name=access.role_name,
        permissions=access.permissions,
    )


def _ensure_zone(db: Session, principal: Principal, name: str) -> int:
    existing = db.scalar(select(Territory.id).where(Territory.kind == "zone", Territory.name == name))
    if existing is not None:
        return existing
    return territories_service.create_territory(db, principal, TerritoryCreate(name=name, kind="zone")).id


def _ensure_subzone(db: Session, principal: Principal, zone_id: int, name: str) -> int:
    existing = db.scalar(
        select(Territory.id).where(Territory.kind == "subzone", Territory.parent_id == zone_id, Territory.name == name)
    )
    if existing is not None:
        return existing
    data = TerritoryCreate(name=name, kind="subzone", parent_id=zone_id)
    return territories_service.create_territory(db, principal, data).id


def _ensure_category(db: Session, name: str) -> int:
    contacts_service.ensure_category(db, name)
    db.commit()
    category = contacts_repository.get_category_by_name(db, name)
    return category.id


def _ensure_type(db: Session, principal: Principal, category_id: int, name: str | None) -> int | None:
    if name is None:
        return None
    existing = contacts_repository.get_type_by_name(db, category_id, name)
    if existing is not None:
        return existing.id
    return contacts_service.create_type(db, principal, TypeCreate(category_id=category_id, name=name)).id


def _contact_exists(db: Session, name: str, category_id: int, subzone_id: int) -> bool:
    found = db.scalar(
        select(Contact.id).where(
            Contact.name == name,
            Contact.category_id == category_id,
            Contact.subzone_id == subzone_id,
        )
    )
    return found is not None


def _ensure_contact(
    db: Session,
    principal: Principal,
    name: str,
    category_id: int,
    type_id: int | None,
    subzone_id: int,
) -> bool:
    if _contact_exists(db, name, category_id, subzone_id):
        return False
    data = ContactCreate(name=name, category_id=category_id, type_id=type_id, subzone_id=subzone_id)
    contacts_service.create_contact(db, principal, data)
    return True


def _import_zones_and_patches(db: Session, principal: Principal, data: dict) -> dict[tuple[str, str], int]:
    zone_ids = {zone: _ensure_zone(db, principal, zone) for zone in data["zones"]}
    return {
        (row["zone"], row["name"]): _ensure_subzone(db, principal, zone_ids[row["zone"]], row["name"])
        for row in data["subzones"]
    }


def _import_people(
    db: Session,
    principal: Principal,
    rows: list[dict],
    category_id: int,
    subzone_ids: dict[tuple[str, str], int],
    with_specialty: bool,
) -> tuple[int, int]:
    created = skipped = 0
    for row in rows:
        type_name = row.get("specialty") if with_specialty else None
        type_id = _ensure_type(db, principal, category_id, type_name)
        subzone_id = subzone_ids[(row["zone"], row["subzone"])]
        if _ensure_contact(db, principal, row["name"], category_id, type_id, subzone_id):
            created += 1
        else:
            skipped += 1
    return created, skipped


def run_import(db: Session, principal: Principal) -> None:
    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    subzone_ids = _import_zones_and_patches(db, principal, data)
    logger.info("Zones and patches ready: %d zones, %d patches.", len(data["zones"]), len(subzone_ids))
    doctor_id = _ensure_category(db, DOCTOR)
    chemist_id = _ensure_category(db, CHEMIST)
    created, skipped = _import_people(db, principal, data["doctors"], doctor_id, subzone_ids, with_specialty=True)
    logger.info("Doctors: %d added, %d already there.", created, skipped)
    created, skipped = _import_people(db, principal, data["chemists"], chemist_id, subzone_ids, with_specialty=False)
    logger.info("Chemists: %d added, %d already there.", created, skipped)


def main() -> None:
    parser = argparse.ArgumentParser(description="Load zones, patches, doctors and chemists.")
    parser.add_argument("--admin-mobile", required=True, help="Mobile number of the admin account the import runs as.")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    with SessionLocal() as db:
        principal = _admin_principal(db, args.admin_mobile)
        run_import(db, principal)


if __name__ == "__main__":
    main()
