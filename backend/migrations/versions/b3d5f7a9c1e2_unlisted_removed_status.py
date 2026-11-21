"""unlisted contacts can be removed (soft delete) and restored

Revision ID: b3d5f7a9c1e2
Revises: a7c9e1b3d5f8
Create Date: 2026-11-21 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'b3d5f7a9c1e2'
down_revision: Union[str, None] = 'a7c9e1b3d5f8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint('ck_unlisted_contacts_status', 'unlisted_contacts', type_='check')
    op.create_check_constraint(
        'ck_unlisted_contacts_status',
        'unlisted_contacts',
        "status IN ('unlisted', 'converted', 'removed')",
    )


def downgrade() -> None:
    # Fails while any unlisted contact is removed: restore those first.
    op.drop_constraint('ck_unlisted_contacts_status', 'unlisted_contacts', type_='check')
    op.create_check_constraint(
        'ck_unlisted_contacts_status',
        'unlisted_contacts',
        "status IN ('unlisted', 'converted')",
    )
