from sqlalchemy.orm import Session

from app.core.exceptions import BadRequest, Conflict, Forbidden, NotFound
from app.core.pagination import Page
from app.modules.audit import service as audit
from app.modules.contacts import repository
from app.modules.contacts.models import Contact, ContactCategory
from app.modules.contacts.schemas import (
    CategoryCreate,
    CategoryRead,
    CategoryUpdate,
    ContactCreate,
    ContactListQuery,
    ContactRead,
    ContactRef,
    ContactUpdate,
)
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm
from app.modules.rbac.principal import Principal
from app.modules.territories import service as territories_service

CATEGORY_NOT_FOUND = "This category does not exist."
CATEGORY_TAKEN = "A category with this name already exists."
CATEGORY_INACTIVE = "This category is switched off. Choose an active category."
CONTACT_NOT_FOUND = "This contact does not exist."
CONTACT_INACTIVE = "This contact is switched off and cannot be visited."
SUBZONE_NOT_FOUND = "Choose a subzone for this contact."
SUBZONE_NOT_YOURS = "This subzone is not one of your territories."


def list_categories(db: Session, principal: Principal) -> list[CategoryRead]:
    rbac_service.require_scope(principal, Perm.CONTACTS_READ)
    return [CategoryRead.model_validate(category) for category in repository.list_categories(db)]


def create_category(db: Session, principal: Principal, data: CategoryCreate) -> CategoryRead:
    rbac_service.require_scope(principal, Perm.SETTINGS_MANAGE)
    if repository.get_category_by_name(db, data.name) is not None:
        raise Conflict(CATEGORY_TAKEN)
    category = repository.add(
        db,
        ContactCategory(name=data.name, is_active=True, created_by=principal.user_id, updated_by=principal.user_id),
    )
    audit.record(db, principal.user_id, "contact_category.create", "contact_category", category.id)
    db.commit()
    return CategoryRead.model_validate(category)


def update_category(db: Session, principal: Principal, category_id: int, data: CategoryUpdate) -> CategoryRead:
    rbac_service.require_scope(principal, Perm.SETTINGS_MANAGE)
    category = repository.get_category(db, category_id)
    if category is None:
        raise NotFound(CATEGORY_NOT_FOUND)
    if data.name is not None:
        existing = repository.get_category_by_name(db, data.name)
        if existing is not None and existing.id != category.id:
            raise Conflict(CATEGORY_TAKEN)
        category.name = data.name
    if data.is_active is not None:
        category.is_active = data.is_active
    category.updated_by = principal.user_id
    audit.record(db, principal.user_id, "contact_category.update", "contact_category", category.id)
    db.commit()
    return CategoryRead.model_validate(category)


def list_contacts(db: Session, principal: Principal, query: ContactListQuery) -> Page[ContactRead]:
    rbac_service.require_scope(principal, Perm.CONTACTS_READ)
    visible = territories_service.visible_territory_ids(db, principal, Perm.CONTACTS_READ)
    rows, total = repository.list_page(db, query, _subzone_scope(db, visible, query))
    return Page[ContactRead](
        items=_to_reads(db, rows),
        total=total,
        page=query.page,
        page_size=query.page_size,
    )


def create_contact(db: Session, principal: Principal, data: ContactCreate) -> ContactRead:
    rbac_service.require_scope(principal, Perm.CONTACTS_MANAGE)
    _ensure_category_active(db, data.category_id)
    _ensure_subzone_visible(db, principal, data.subzone_id, Perm.CONTACTS_MANAGE)
    contact = repository.add(
        db,
        Contact(
            name=data.name,
            category_id=data.category_id,
            subzone_id=data.subzone_id,
            is_active=True,
            created_by=principal.user_id,
            updated_by=principal.user_id,
        ),
    )
    audit.record(db, principal.user_id, "contact.create", "contact", contact.id)
    db.commit()
    return _to_reads(db, [(contact, _category_name(db, contact.category_id))])[0]


def update_contact(db: Session, principal: Principal, contact_id: int, data: ContactUpdate) -> ContactRead:
    rbac_service.require_scope(principal, Perm.CONTACTS_MANAGE)
    contact = _manageable_contact(db, principal, contact_id)
    if data.category_id is not None:
        _ensure_category_active(db, data.category_id)
        contact.category_id = data.category_id
    if data.subzone_id is not None:
        _ensure_subzone_visible(db, principal, data.subzone_id, Perm.CONTACTS_MANAGE)
        contact.subzone_id = data.subzone_id
    if data.name is not None:
        contact.name = data.name
    if data.is_active is not None:
        contact.is_active = data.is_active
    contact.updated_by = principal.user_id
    audit.record(db, principal.user_id, "contact.update", "contact", contact.id)
    db.commit()
    return _to_reads(db, [(contact, _category_name(db, contact.category_id))])[0]


def reachable_contact(db: Session, principal: Principal, contact_id: int) -> Contact:
    """A contact the caller may visit. A contact outside the caller's territories looks like it does not exist."""
    contact = repository.get_contact(db, contact_id)
    visible = territories_service.visible_territory_ids(db, principal, Perm.CONTACTS_READ)
    active = territories_service.active_subzone_ids(db)
    if contact is None or contact.subzone_id not in active or (visible is not None and contact.subzone_id not in visible):
        raise NotFound(CONTACT_NOT_FOUND)
    if not contact.is_active:
        raise BadRequest(CONTACT_INACTIVE)
    return contact


def count_reachable_active(db: Session, principal: Principal) -> int:
    """Active contacts the caller can visit: in their territories, in active areas."""
    rbac_service.require_scope(principal, Perm.CONTACTS_READ)
    visible = territories_service.visible_territory_ids(db, principal, Perm.CONTACTS_READ)
    return repository.count_active_in(db, _subzone_scope(db, visible, ContactListQuery()))


def count_active_in_subzones(db: Session, subzone_ids: set[int]) -> int:
    """Active contacts in the given subzones, for a report on one person's area. Inactive areas are not counted."""
    active = territories_service.active_subzone_ids(db)
    return repository.count_active_in(db, subzone_ids & active)


def count_all_active(db: Session, principal: Principal) -> int:
    """Active contacts in every active area the caller can see."""
    rbac_service.require_scope(principal, Perm.CONTACTS_READ)
    visible = territories_service.visible_territory_ids(db, principal, Perm.CONTACTS_READ)
    return repository.count_active_in(db, _subzone_scope(db, visible, ContactListQuery()))


def active_contacts_in_subzones(db: Session, subzone_ids: set[int]) -> list[ContactRef]:
    """Active contacts in the given subzones, for the team's reports. Inactive areas are not counted."""
    return [
        ContactRef(
            id=contact.id,
            name=contact.name,
            category_name=category_name,
            subzone_id=contact.subzone_id,
            is_active=contact.is_active,
        )
        for contact, category_name in repository.active_in_subzones(db, subzone_ids & territories_service.active_subzone_ids(db))
    ]


def contact_summaries(db: Session, contact_ids: set[int]) -> dict[int, ContactRef]:
    return {
        contact.id: ContactRef(
            id=contact.id,
            name=contact.name,
            category_name=category_name,
            subzone_id=contact.subzone_id,
            is_active=contact.is_active,
        )
        for contact, category_name in repository.contacts_with_category(db, contact_ids)
    }


def _manageable_contact(db: Session, principal: Principal, contact_id: int) -> Contact:
    contact = repository.get_contact(db, contact_id)
    visible = territories_service.visible_territory_ids(db, principal, Perm.CONTACTS_MANAGE)
    if contact is None or (visible is not None and contact.subzone_id not in visible):
        raise NotFound(CONTACT_NOT_FOUND)
    return contact


def _ensure_category_active(db: Session, category_id: int) -> None:
    category = repository.get_category(db, category_id)
    if category is None:
        raise BadRequest(CATEGORY_NOT_FOUND)
    if not category.is_active:
        raise BadRequest(CATEGORY_INACTIVE)


def _ensure_subzone_visible(db: Session, principal: Principal, subzone_id: int, code: Perm) -> None:
    if not territories_service.subzone_locations(db, {subzone_id}):
        raise BadRequest(SUBZONE_NOT_FOUND)
    visible = territories_service.visible_territory_ids(db, principal, code)
    if visible is not None and subzone_id not in visible:
        raise Forbidden(SUBZONE_NOT_YOURS)


def _subzone_scope(db: Session, visible: set[int] | None, query: ContactListQuery) -> set[int]:
    """The subzones a listing may show: the caller's territories, and only active ones, narrowed to what was asked for."""
    active = territories_service.active_subzone_ids(db)
    scope = active if visible is None else visible & active
    if query.subzone_id is not None:
        scope = scope & {query.subzone_id}
    if query.zone_id is not None:
        zone_subzones = territories_service.subzone_ids_of_zone(db, query.zone_id)
        scope = scope & zone_subzones
    return scope


def _category_name(db: Session, category_id: int) -> str:
    category = repository.get_category(db, category_id)
    return category.name if category is not None else ""


def _to_reads(db: Session, rows: list[tuple[Contact, str]]) -> list[ContactRead]:
    locations = territories_service.subzone_locations(db, {contact.subzone_id for contact, _ in rows})
    return [
        ContactRead(
            id=contact.id,
            name=contact.name,
            category_id=contact.category_id,
            category_name=category_name,
            subzone_id=contact.subzone_id,
            subzone_name=locations[contact.subzone_id].name,
            zone_id=locations[contact.subzone_id].zone_id,
            zone_name=locations[contact.subzone_id].zone_name,
            is_active=contact.is_active,
        )
        for contact, category_name in rows
    ]
