"""call part of the day alongside the clock time; time becomes optional

Revision ID: f2a4c6e8b0d1
Revises: e5f7a9b1c3d6
Create Date: 2026-11-21 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2a4c6e8b0d1'
down_revision: Union[str, None] = 'e5f7a9b1c3d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('visits', sa.Column('day_part', sa.String(length=10), nullable=True))
    op.execute(
        """
        UPDATE visits SET day_part = CASE
            WHEN visit_time < '12:00:00' THEN 'morning'
            WHEN visit_time < '17:00:00' THEN 'afternoon'
            ELSE 'evening'
        END
        """
    )
    op.alter_column('visits', 'day_part', nullable=False)
    op.alter_column('visits', 'visit_time', existing_type=sa.Time(), nullable=True)
    op.create_check_constraint(
        'ck_visits_day_part', 'visits', "day_part IN ('morning', 'afternoon', 'evening')"
    )


def downgrade() -> None:
    # Calls logged only by part of the day get the start of that part as their time, so the old app can read them.
    op.execute(
        """
        UPDATE visits SET visit_time = CAST(CASE day_part
            WHEN 'morning' THEN '09:00:00'
            WHEN 'afternoon' THEN '12:00:00'
            ELSE '17:00:00'
        END AS time)
        WHERE visit_time IS NULL
        """
    )
    op.alter_column('visits', 'visit_time', existing_type=sa.Time(), nullable=False)
    op.drop_constraint('ck_visits_day_part', 'visits', type_='check')
    op.drop_column('visits', 'day_part')
