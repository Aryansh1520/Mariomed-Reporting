"""Six-digit reset codes: per-account lookup and a failed-attempt counter.

Revision ID: b8c2d4e6f1a3
Revises: a0c26fbcc8fb
Create Date: 2026-10-31 16:00:00
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b8c2d4e6f1a3"
down_revision: Union[str, None] = "a0c26fbcc8fb"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "password_reset_tokens",
        sa.Column("failed_attempts", sa.Integer(), server_default="0", nullable=False),
    )
    op.drop_constraint(
        "password_reset_tokens_token_hash_key", "password_reset_tokens", type_="unique"
    )


def downgrade() -> None:
    op.create_unique_constraint(
        "password_reset_tokens_token_hash_key", "password_reset_tokens", ["token_hash"]
    )
    op.drop_column("password_reset_tokens", "failed_attempts")
