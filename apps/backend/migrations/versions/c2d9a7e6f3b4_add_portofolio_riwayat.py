"""add portofolio riwayat

Revision ID: c2d9a7e6f3b4
Revises: b4a8f2c9d0e1
Create Date: 2026-02-27 01:35:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = "c2d9a7e6f3b4"
down_revision = "b4a8f2c9d0e1"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "portofolio_riwayat",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("portofolio_id", sa.Integer(), nullable=True),
        sa.Column("aksi", sa.String(length=20), nullable=False),
        sa.Column("nama_aset", sa.String(length=120), nullable=False),
        sa.Column("simbol", sa.String(length=20), nullable=False),
        sa.Column("jumlah", sa.Float(), nullable=False),
        sa.Column("harga_beli", sa.Float(), nullable=False),
        sa.Column("nilai", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_portofolio_riwayat_user_id"), "portofolio_riwayat", ["user_id"], unique=False)
    op.create_index(op.f("ix_portofolio_riwayat_created_at"), "portofolio_riwayat", ["created_at"], unique=False)


def downgrade():
    op.drop_index(op.f("ix_portofolio_riwayat_created_at"), table_name="portofolio_riwayat")
    op.drop_index(op.f("ix_portofolio_riwayat_user_id"), table_name="portofolio_riwayat")
    op.drop_table("portofolio_riwayat")
