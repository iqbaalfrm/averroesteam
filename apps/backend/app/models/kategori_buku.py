from datetime import datetime

from app.extensions import db


class KategoriBuku(db.Model):
    __tablename__ = "kategori_buku"

    id = db.Column(db.Integer, primary_key=True)
    nama = db.Column(db.String(100), nullable=False, unique=True)
    slug = db.Column(db.String(120), nullable=False, unique=True, index=True)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    urutan = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    buku = db.relationship("Buku", back_populates="kategori", lazy="dynamic")

    def to_dict(self):
        return {
            "id": self.id,
            "nama": self.nama,
            "slug": self.slug,
            "is_active": bool(self.is_active),
            "urutan": int(self.urutan or 0),
        }
