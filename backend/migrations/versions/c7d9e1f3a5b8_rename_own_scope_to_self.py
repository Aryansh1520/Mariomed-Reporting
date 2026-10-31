"""The own scope is renamed self: it means only the person themselves."""

from alembic import op

revision = "c7d9e1f3a5b8"
down_revision = "5e242c51aeb0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint("ck_role_permissions_scope", "role_permissions", type_="check")
    op.execute("UPDATE role_permissions SET scope = 'self' WHERE scope = 'own'")
    op.create_check_constraint(
        "ck_role_permissions_scope", "role_permissions", "scope IN ('all', 'self', 'assigned')"
    )


def downgrade() -> None:
    op.drop_constraint("ck_role_permissions_scope", "role_permissions", type_="check")
    op.execute("UPDATE role_permissions SET scope = 'own' WHERE scope = 'self'")
    op.create_check_constraint(
        "ck_role_permissions_scope", "role_permissions", "scope IN ('all', 'own', 'assigned')"
    )
