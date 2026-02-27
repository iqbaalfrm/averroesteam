"""expand buku schema for pustaka

Revision ID: a1c4e8d2f7b1
Revises: 9f2c6d31a4b0
Create Date: 2026-02-26 23:55:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "a1c4e8d2f7b1"
down_revision = "9f2c6d31a4b0"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "kategori_buku",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("nama", sa.String(length=100), nullable=False),
        sa.Column("slug", sa.String(length=120), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("urutan", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("nama"),
        sa.UniqueConstraint("slug"),
    )
    op.create_index(op.f("ix_kategori_buku_slug"), "kategori_buku", ["slug"], unique=True)

    with op.batch_alter_table("buku") as batch_op:
        batch_op.add_column(sa.Column("slug", sa.String(length=240), nullable=True))
        batch_op.add_column(sa.Column("kategori_id", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("status", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("akses", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("bahasa", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("is_featured", sa.Boolean(), nullable=True))
        batch_op.add_column(sa.Column("format_file", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("storage_provider", sa.String(length=20), nullable=True))
        batch_op.add_column(sa.Column("file_key", sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column("file_nama", sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column("ukuran_file_bytes", sa.BigInteger(), nullable=True))
        batch_op.add_column(sa.Column("cover_key", sa.String(length=255), nullable=True))
        batch_op.add_column(sa.Column("published_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("updated_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("created_by", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("updated_by", sa.Integer(), nullable=True))
        batch_op.create_index(op.f("ix_buku_slug"), ["slug"], unique=True)
        batch_op.create_index(op.f("ix_buku_kategori_id"), ["kategori_id"], unique=False)
        batch_op.create_index(op.f("ix_buku_status"), ["status"], unique=False)
        batch_op.create_index(op.f("ix_buku_akses"), ["akses"], unique=False)
        batch_op.create_index(op.f("ix_buku_is_featured"), ["is_featured"], unique=False)
        batch_op.create_foreign_key("fk_buku_kategori_id", "kategori_buku", ["kategori_id"], ["id"])
        batch_op.create_foreign_key("fk_buku_created_by", "users", ["created_by"], ["id"])
        batch_op.create_foreign_key("fk_buku_updated_by", "users", ["updated_by"], ["id"])

    op.execute(
        sa.text(
            """
            UPDATE buku
            SET
              slug = COALESCE(slug, 'buku-' || id),
              status = COALESCE(status, 'published'),
              akses = COALESCE(akses, 'gratis'),
              bahasa = COALESCE(bahasa, 'id'),
              is_featured = COALESCE(is_featured, 0),
              storage_provider = COALESCE(storage_provider, 'local'),
              file_key = COALESCE(file_key, file_pdf),
              file_nama = COALESCE(file_nama, file_pdf),
              format_file = COALESCE(format_file, CASE WHEN file_pdf IS NOT NULL THEN 'pdf' ELSE NULL END),
              published_at = COALESCE(published_at, created_at),
              updated_at = COALESCE(updated_at, created_at)
            """
        )
    )


def downgrade():
    with op.batch_alter_table("buku") as batch_op:
        batch_op.drop_constraint("fk_buku_updated_by", type_="foreignkey")
        batch_op.drop_constraint("fk_buku_created_by", type_="foreignkey")
        batch_op.drop_constraint("fk_buku_kategori_id", type_="foreignkey")
        batch_op.drop_index(op.f("ix_buku_is_featured"))
        batch_op.drop_index(op.f("ix_buku_akses"))
        batch_op.drop_index(op.f("ix_buku_status"))
        batch_op.drop_index(op.f("ix_buku_kategori_id"))
        batch_op.drop_index(op.f("ix_buku_slug"))
        for col in [
            "updated_by",
            "created_by",
            "updated_at",
            "published_at",
            "cover_key",
            "ukuran_file_bytes",
            "file_nama",
            "file_key",
            "storage_provider",
            "format_file",
            "is_featured",
            "bahasa",
            "akses",
            "status",
            "kategori_id",
            "slug",
        ]:
            batch_op.drop_column(col)

    op.drop_index(op.f("ix_kategori_buku_slug"), table_name="kategori_buku")
    op.drop_table("kategori_buku")
