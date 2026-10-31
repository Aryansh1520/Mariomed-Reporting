"""Every user has a full name: blank names are refused by the database too."""

from alembic import op

revision = "a1f3c5e7d9b2"
down_revision = "47658482acbf"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_check_constraint(
        "ck_users_full_name_not_blank", "users", "length(btrim(full_name)) > 0"
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_full_name_not_blank", "users", type_="check")
