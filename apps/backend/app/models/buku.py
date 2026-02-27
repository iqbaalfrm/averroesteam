from datetime import datetime

from app.extensions import db


class Buku(db.Model):
    __tablename__ = "buku"

    id = db.Column(db.Integer, primary_key=True)
    judul = db.Column(db.String(200), nullable=False)
    slug = db.Column(db.String(240), nullable=True, unique=True, index=True)
    penulis = db.Column(db.String(120), nullable=False)
    deskripsi = db.Column(db.Text, nullable=False)
    kategori_id = db.Column(db.Integer, db.ForeignKey("kategori_buku.id"), nullable=True, index=True)
    status = db.Column(db.String(20), nullable=False, default="draft", index=True)
    akses = db.Column(db.String(20), nullable=False, default="gratis", index=True)
    bahasa = db.Column(db.String(20), nullable=False, default="id")
    is_featured = db.Column(db.Boolean, nullable=False, default=False, index=True)
    format_file = db.Column(db.String(20), nullable=True)
    storage_provider = db.Column(db.String(20), nullable=True, default="local")
    file_key = db.Column(db.String(255), nullable=True)
    file_nama = db.Column(db.String(255), nullable=True)
    ukuran_file_bytes = db.Column(db.BigInteger, nullable=True)
    cover_key = db.Column(db.String(255), nullable=True)
    drive_file_id = db.Column(db.String(255), nullable=True)
    file_pdf = db.Column(db.String(255), nullable=True)
    published_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    updated_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)

    kategori = db.relationship("KategoriBuku", back_populates="buku")

    def active_file_key(self) -> str | None:
        return (self.file_key or self.file_pdf or None) and (self.file_key or self.file_pdf)

    def has_drive_file(self) -> bool:
        return bool((self.drive_file_id or "").strip())

    def is_published(self) -> bool:
        return (self.status or "").lower() == "published"

    def to_dict(self):
        kategori = self.kategori.to_dict() if self.kategori else None
        return {
            "id": self.id,
            "judul": self.judul,
            "slug": self.slug,
            "penulis": self.penulis,
            "deskripsi": self.deskripsi,
            "kategori_id": self.kategori_id,
            "kategori": kategori,
            "status": self.status,
            "akses": self.akses,
            "bahasa": self.bahasa,
            "is_featured": bool(self.is_featured),
            "format_file": self.format_file,
            "storage_provider": self.storage_provider,
            "file_key": self.file_key,
            "file_nama": self.file_nama,
            "ukuran_file_bytes": int(self.ukuran_file_bytes) if self.ukuran_file_bytes is not None else None,
            "cover_key": self.cover_key,
            "drive_file_id": self.drive_file_id,
            "file_pdf": self.file_pdf,
            "published_at": self.published_at.isoformat() if self.published_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "created_by": self.created_by,
            "updated_by": self.updated_by,
        }

    def to_public_dict(self):
        return {
            "id": self.id,
            "slug": self.slug,
            "judul": self.judul,
            "penulis": self.penulis,
            "deskripsi": self.deskripsi,
            "kategori": self.kategori.to_dict() if self.kategori else None,
            "akses": self.akses,
            "bahasa": self.bahasa,
            "is_featured": bool(self.is_featured),
            "format_file": self.format_file,
            "ukuran_file_bytes": int(self.ukuran_file_bytes) if self.ukuran_file_bytes is not None else None,
            "cover_url": self.cover_key,
            "drive_file_id": self.drive_file_id,
            "has_file": bool(self.active_file_key() or self.has_drive_file()),
            "published_at": self.published_at.isoformat() if self.published_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
