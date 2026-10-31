from datetime import date

from sqlalchemy import Date, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.audit import AuditFieldsMixin
from app.db.base import Base


class DayPlanItem(AuditFieldsMixin, Base):
    """A call a rep plans for a day, as a personal goal. Only the rep who made it sees it."""

    __tablename__ = "day_plan_items"
    __table_args__ = (
        UniqueConstraint("user_id", "plan_date", "contact_id", name="uq_day_plan_items_user_date_contact"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_date: Mapped[date] = mapped_column(Date, index=True)
    contact_id: Mapped[int] = mapped_column(ForeignKey("contacts.id", ondelete="RESTRICT"), index=True)
