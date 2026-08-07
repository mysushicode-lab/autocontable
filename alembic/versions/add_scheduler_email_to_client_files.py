"""add scheduler_email to client_files

Revision ID: add_scheduler_email
Revises:
Create Date: 2026-08-07

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_scheduler_email'
down_revision = None  # Update this with the previous migration ID if exists
branch_labels = None
depends_on = None


def upgrade():
    # Add scheduler_email column to client_files table
    op.add_column('client_files', sa.Column('scheduler_email', sa.String(200), nullable=True))


def downgrade():
    # Remove scheduler_email column
    op.drop_column('client_files', 'scheduler_email')
