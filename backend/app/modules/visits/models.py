from datetime import date, datetime, time

from sqlalchemy import CheckConstraint, Column, Date, DateTime, ForeignKey, String, Table, Text, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.audit import AuditFieldsMixin
from app.db.base import Base


class VisitDay(AuditFieldsMixin, Base):
    """One rep's report for one calendar day. Once ended, the day and its visits are locked for good."""

    __tablename__ = "visit_days"
    __table_args__ = (
        UniqueConstraint("user_id", "visit_date", name="uq_visit_days_user_date"),
        CheckConstraint("status IN ('open', 'ended', 'leave')", name="ck_visit_days_status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    visit_date: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="open")
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Visit(AuditFieldsMixin, Base):
    """A call on a contact. Stays open until its day ends, then becomes completed (or disputed, for a joint call)."""

    __tablename__ = "visits"
    __table_args__ = (
        CheckConstraint("status IN ('open', 'completed', 'disputed')", name="ck_visits_status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    day_id: Mapped[int] = mapped_column(ForeignKey("visit_days.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    visit_date: Mapped[date] = mapped_column(Date)
    visit_time: Mapped[time] = mapped_column(Time)
    contact_id: Mapped[int] = mapped_column(ForeignKey("contacts.id", ondelete="RESTRICT"), index=True)
    zone_id: Mapped[int] = mapped_column(ForeignKey("territories.id", ondelete="RESTRICT"))
    subzone_id: Mapped[int] = mapped_column(ForeignKey("territories.id", ondelete="RESTRICT"))
    remarks: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="open")
    partner_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), index=True, nullable=True
    )


visit_products = Table(
    "visit_products",
    Base.metadata,
    Column("visit_id", ForeignKey("visits.id", ondelete="CASCADE"), primary_key=True),
    Column("product_id", ForeignKey("products.id", ondelete="RESTRICT"), primary_key=True),
)


class VisitParticipation(AuditFieldsMixin, Base):
    """The other rep on a joint call. Pending until they accept it, or disputed when they decline or the grace period ends."""

    __tablename__ = "visit_participations"
    __table_args__ = (
        CheckConstraint("status IN ('pending', 'accepted', 'disputed')", name="ck_visit_participations_status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    visit_id: Mapped[int] = mapped_column(ForeignKey("visits.id", ondelete="CASCADE"), unique=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
