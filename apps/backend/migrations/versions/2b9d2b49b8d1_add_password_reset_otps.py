"""add password reset otps

Revision ID: 2b9d2b49b8d1
Revises: f545b7a1e489
Create Date: 2026-02-25 14:20:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "2b9d2b49b8d1"
down_revision = "f545b7a1e489"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "password_reset_otps",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(length=120), nullable=False),
        sa.Column("kode", sa.String(length=6), nullable=False),
        sa.Column("expired_at", sa.DateTime(), nullable=False),
        sa.Column("verified_at", sa.DateTime(), nullable=True),
        sa.Column("is_used", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("used_at", sa.DateTime(), nullable=True),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_password_reset_otps_email"), "password_reset_otps", ["email"], unique=False)
    op.create_index(op.f("ix_password_reset_otps_expired_at"), "password_reset_otps", ["expired_at"], unique=False)


def downgrade():
    op.drop_index(op.f("ix_password_reset_otps_expired_at"), table_name="password_reset_otps")
    op.drop_index(op.f("ix_password_reset_otps_email"), table_name="password_reset_otps")
    op.drop_table("password_reset_otps")

