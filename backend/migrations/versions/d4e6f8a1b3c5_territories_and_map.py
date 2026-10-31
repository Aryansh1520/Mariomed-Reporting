"""Territories, and the map outline they are cut to. PostGIS stores the shapes."""

import geoalchemy2
import sqlalchemy as sa
from alembic import op

revision = "d4e6f8a1b3c5"
down_revision = "c7d9e1f3a5b8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.create_table(
        "map_regions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("geom", geoalchemy2.types.Geometry(geometry_type="MULTIPOLYGON", srid=4326, spatial_index=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    op.create_index("idx_map_regions_geom", "map_regions", ["geom"], postgresql_using="gist")
    op.create_table(
        "territories",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("parent_id", sa.Integer(), nullable=True),
        sa.Column("color_index", sa.Integer(), nullable=False),
        sa.Column("geom", geoalchemy2.types.Geometry(geometry_type="MULTIPOLYGON", srid=4326, spatial_index=False), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("created_by", sa.Integer(), nullable=True),
        sa.Column("updated_by", sa.Integer(), nullable=True),
        sa.CheckConstraint("kind IN ('zone', 'subzone')", name="ck_territories_kind"),
        sa.CheckConstraint(
            "(kind = 'zone' AND parent_id IS NULL) OR (kind = 'subzone' AND parent_id IS NOT NULL)",
            name="ck_territories_parent",
        ),
        sa.CheckConstraint("length(btrim(name)) > 0", name="ck_territories_name_not_blank"),
        sa.ForeignKeyConstraint(["parent_id"], ["territories.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["updated_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_territories_parent_id", "territories", ["parent_id"], unique=False)
    op.create_index("idx_territories_geom", "territories", ["geom"], postgresql_using="gist")


def downgrade() -> None:
    op.drop_table("territories")
    op.drop_table("map_regions")
