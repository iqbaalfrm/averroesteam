"""add gambar_url to berita

Revision ID: 9f2c6d31a4b0
Revises: 2b9d2b49b8d1
Create Date: 2026-02-26 14:10:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "9f2c6d31a4b0"
down_revision = "2b9d2b49b8d1"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("berita", sa.Column("gambar_url", sa.String(length=1024), nullable=True))


def downgrade():
    op.drop_column("berita", "gambar_url")

