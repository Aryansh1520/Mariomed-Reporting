from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.contacts.models import Contact, ContactCategory, ContactType
from app.modules.contacts.schemas import ContactListQuery, TypeListQuery


def list_categories(db: Session) -> list[ContactCategory]:
    return list(db.scalars(select(ContactCategory).order_by(ContactCategory.name)))


def get_category(db: Session, category_id: int) -> ContactCategory | None:
    return db.get(ContactCategory, category_id)


def get_category_by_name(db: Session, name: str) -> ContactCategory | None:
    return db.scalar(select(ContactCategory).where(ContactCategory.name == name))


def get_type(db: Session, type_id: int) -> ContactType | None:
    return db.get(ContactType, type_id)


def get_type_by_name(db: Session, category_id: int, name: str) -> ContactType | None:
    return db.scalar(select(ContactType).where(ContactType.category_id == category_id, ContactType.name == name))


def list_types_page(db: Session, query: TypeListQuery) -> tuple[list[ContactType], int]:
    filtered = select(ContactType)
    if query.category_id is not None:
        filtered = filtered.where(ContactType.category_id == query.category_id)
    total = db.scalar(select(func.count()).select_from(filtered.subquery())) or 0
    page = filtered.order_by(ContactType.name, ContactType.id).offset(query.offset).limit(query.page_size)
    return list(db.scalars(page)), total


def type_names(db: Session, type_ids: set[int]) -> dict[int, str]:
    if not type_ids:
        return {}
    rows = db.execute(select(ContactType.id, ContactType.name).where(ContactType.id.in_(type_ids)))
    return {type_id: name for type_id, name in rows}


def get_contact(db: Session, contact_id: int) -> Contact | None:
    return db.get(Contact, contact_id)


def contacts_with_category(db: Session, contact_ids: set[int]) -> list[tuple[Contact, str]]:
    query = (
        select(Contact, ContactCategory.name)
        .join(ContactCategory, ContactCategory.id == Contact.category_id)
        .where(Contact.id.in_(contact_ids))
    )
    return [(contact, category_name) for contact, category_name in db.execute(query)]


def active_in_subzones(db: Session, subzone_ids: set[int]) -> list[tuple[Contact, str]]:
    query = (
        select(Contact, ContactCategory.name)
        .join(ContactCategory, ContactCategory.id == Contact.category_id)
        .where(Contact.subzone_id.in_(subzone_ids), Contact.is_active.is_(True))
        .order_by(Contact.name, Contact.id)
    )
    return [(contact, category_name) for contact, category_name in db.execute(query)]


def list_page(db: Session, query: ContactListQuery, subzone_ids: set[int] | None) -> tuple[list[tuple[Contact, str]], int]:
    """A page of contacts. subzone_ids limits the rows when it is not None."""
    filtered = select(Contact.id)
    if subzone_ids is not None:
        filtered = filtered.where(Contact.subzone_id.in_(subzone_ids))
    if query.category_id is not None:
        filtered = filtered.where(Contact.category_id == query.category_id)
    total = db.scalar(select(func.count()).select_from(filtered.subquery())) or 0
    page = (
        select(Contact, ContactCategory.name)
        .join(ContactCategory, ContactCategory.id == Contact.category_id)
        .where(Contact.id.in_(filtered))
        .order_by(Contact.name, Contact.id)
        .offset(query.offset)
        .limit(query.page_size)
    )
    return [(contact, category_name) for contact, category_name in db.execute(page)], total


def count_active_in(db: Session, subzone_ids: set[int]) -> int:
    return db.scalar(
        select(func.count()).select_from(Contact).where(Contact.subzone_id.in_(subzone_ids), Contact.is_active.is_(True))
    ) or 0


def add(db: Session, obj: Contact | ContactCategory) -> Contact | ContactCategory:
    db.add(obj)
    db.flush()
    return obj
