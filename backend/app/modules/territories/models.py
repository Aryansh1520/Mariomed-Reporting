from geoalchemy2 import Geometry, WKBElement
from sqlalchemy import CheckConstraint, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.audit import AuditFieldsMixin
from app.db.base import Base


class MapRegion(Base):
    """An outline of the service area: the city, a suburb, or a district. Loaded from the map data file by the seed."""

    __tablename__ = "map_regions"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True)
    kind: Mapped[str] = mapped_column(String(20))
    geom: Mapped[WKBElement] = mapped_column(Geometry("MULTIPOLYGON", srid=4326, spatial_index=True))


class Territory(AuditFieldsMixin, Base):
    """A zone or a subzone drawn by a user. Its shape is already cut to the map. A subzone names its zone."""

    __tablename__ = "territories"
    __table_args__ = (
        CheckConstraint("kind IN ('zone', 'subzone')", name="ck_territories_kind"),
        CheckConstraint(
            "(kind = 'zone' AND parent_id IS NULL) OR (kind = 'subzone' AND parent_id IS NOT NULL)",
            name="ck_territories_parent",
        ),
        CheckConstraint("length(btrim(name)) > 0", name="ck_territories_name_not_blank"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    kind: Mapped[str] = mapped_column(String(20))
    parent_id: Mapped[int | None] = mapped_column(
        ForeignKey("territories.id", ondelete="CASCADE"), index=True, nullable=True
    )
    color_index: Mapped[int] = mapped_column()
    # Null for a zone or subzone made by name only, without drawing it on the map.
    geom: Mapped[WKBElement | None] = mapped_column(Geometry("MULTIPOLYGON", srid=4326, spatial_index=True), nullable=True)
    # Deleting a zone or subzone deactivates it. Inactive areas drop out of every list and cannot be visited.
    is_active: Mapped[bool] = mapped_column(default=True, server_default="true")


class UserTerritory(Base):
    """A zone or subzone a user reports in. A zone reaches every subzone inside it."""

    __tablename__ = "user_territories"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    territory_id: Mapped[int] = mapped_column(ForeignKey("territories.id", ondelete="CASCADE"), primary_key=True)
