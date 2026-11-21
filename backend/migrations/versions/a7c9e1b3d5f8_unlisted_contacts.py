"""unlisted doctors and chemists per patch; a call is on a listed contact or an unlisted one

Revision ID: a7c9e1b3d5f8
Revises: f2a4c6e8b0d1
Create Date: 2026-11-21 11:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a7c9e1b3d5f8'
down_revision: Union[str, None] = 'f2a4c6e8b0d1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('unlisted_contacts',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('name', sa.String(length=120), nullable=False),
    sa.Column('category_id', sa.Integer(), nullable=False),
    sa.Column('subzone_id', sa.Integer(), nullable=False),
    sa.Column('status', sa.String(length=20), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('created_by', sa.Integer(), nullable=True),
    sa.Column('updated_by', sa.Integer(), nullable=True),
    sa.CheckConstraint('length(btrim(name)) > 0', name='ck_unlisted_contacts_name_not_blank'),
    sa.CheckConstraint("status IN ('unlisted', 'converted')", name='ck_unlisted_contacts_status'),
    sa.ForeignKeyConstraint(['category_id'], ['contact_categories.id'], ondelete='RESTRICT'),
    sa.ForeignKeyConstraint(['subzone_id'], ['territories.id'], ondelete='RESTRICT'),
    sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['updated_by'], ['users.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_unlisted_contacts_category_id'), 'unlisted_contacts', ['category_id'], unique=False)
    op.create_index(op.f('ix_unlisted_contacts_subzone_id'), 'unlisted_contacts', ['subzone_id'], unique=False)
    op.alter_column('visits', 'contact_id', existing_type=sa.Integer(), nullable=True)
    op.add_column('visits', sa.Column('unlisted_contact_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_visits_unlisted_contact_id', 'visits', 'unlisted_contacts', ['unlisted_contact_id'], ['id'], ondelete='RESTRICT')
    op.create_index(op.f('ix_visits_unlisted_contact_id'), 'visits', ['unlisted_contact_id'], unique=False)
    op.create_check_constraint(
        'ck_visits_one_subject', 'visits', '(contact_id IS NULL) <> (unlisted_contact_id IS NULL)'
    )


def downgrade() -> None:
    # Fails while any call is recorded on an unlisted contact: those calls have no listed contact to fall back to.
    op.drop_constraint('ck_visits_one_subject', 'visits', type_='check')
    op.drop_index(op.f('ix_visits_unlisted_contact_id'), table_name='visits')
    op.drop_constraint('fk_visits_unlisted_contact_id', 'visits', type_='foreignkey')
    op.drop_column('visits', 'unlisted_contact_id')
    op.alter_column('visits', 'contact_id', existing_type=sa.Integer(), nullable=False)
    op.drop_index(op.f('ix_unlisted_contacts_subzone_id'), table_name='unlisted_contacts')
    op.drop_index(op.f('ix_unlisted_contacts_category_id'), table_name='unlisted_contacts')
    op.drop_table('unlisted_contacts')
