"""contact types under categories; optional type on contacts

Revision ID: e5f7a9b1c3d6
Revises: b8c2d4e6f1a3
Create Date: 2026-11-01 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e5f7a9b1c3d6'
down_revision: Union[str, None] = 'b8c2d4e6f1a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('contact_types',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('category_id', sa.Integer(), nullable=False),
    sa.Column('name', sa.String(length=80), nullable=False),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('created_by', sa.Integer(), nullable=True),
    sa.Column('updated_by', sa.Integer(), nullable=True),
    sa.CheckConstraint('length(btrim(name)) > 0', name='ck_contact_types_name_not_blank'),
    sa.ForeignKeyConstraint(['category_id'], ['contact_categories.id'], ondelete='RESTRICT'),
    sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['updated_by'], ['users.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('category_id', 'name', name='uq_contact_types_category_name')
    )
    op.create_index(op.f('ix_contact_types_category_id'), 'contact_types', ['category_id'], unique=False)
    op.add_column('contacts', sa.Column('type_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_contacts_type_id_contact_types', 'contacts', 'contact_types', ['type_id'], ['id'], ondelete='RESTRICT')
    op.create_index(op.f('ix_contacts_type_id'), 'contacts', ['type_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_contacts_type_id'), table_name='contacts')
    op.drop_constraint('fk_contacts_type_id_contact_types', 'contacts', type_='foreignkey')
    op.drop_column('contacts', 'type_id')
    op.drop_index(op.f('ix_contact_types_category_id'), table_name='contact_types')
    op.drop_table('contact_types')
