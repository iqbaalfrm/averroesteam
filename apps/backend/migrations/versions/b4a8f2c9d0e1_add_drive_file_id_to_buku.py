"""add drive_file_id to buku

Revision ID: b4a8f2c9d0e1
Revises: a1c4e8d2f7b1
Create Date: 2026-02-27 01:10:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = "b4a8f2c9d0e1"
down_revision = "a1c4e8d2f7b1"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("buku") as batch_op:
        batch_op.add_column(sa.Column("drive_file_id", sa.String(length=255), nullable=True))


def downgrade():
    with op.batch_alter_table("buku") as batch_op:
        batch_op.drop_column("drive_file_id")
