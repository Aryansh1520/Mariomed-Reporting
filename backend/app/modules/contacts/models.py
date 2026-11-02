from sqlalchemy import Boolean, CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.audit import AuditFieldsMixin
from app.db.base import Base


class ContactCategory(AuditFieldsMixin, Base):
    """A kind of person the field team visits, such as doctors, chemists or stockists. The admin sets these up."""

    __tablename__ = "contact_categories"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) > 0", name="ck_contact_categories_name_not_blank"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ContactType(AuditFieldsMixin, Base):
    """A sub-kind of one category, such as ortho or physician under doctors. The admin sets these up."""

    __tablename__ = "contact_types"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) > 0", name="ck_contact_types_name_not_blank"),
        UniqueConstraint("category_id", "name", name="uq_contact_types_category_name"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("contact_categories.id", ondelete="RESTRICT"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Contact(AuditFieldsMixin, Base):
    """A person a rep visits. Sits in a subzone, which places it inside a zone."""

    __tablename__ = "contacts"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) > 0", name="ck_contacts_name_not_blank"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    category_id: Mapped[int] = mapped_column(ForeignKey("contact_categories.id", ondelete="RESTRICT"), index=True)
    type_id: Mapped[int | None] = mapped_column(ForeignKey("contact_types.id", ondelete="RESTRICT"), index=True)
    subzone_id: Mapped[int] = mapped_column(ForeignKey("territories.id", ondelete="RESTRICT"), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
