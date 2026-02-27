from datetime import datetime

from app.extensions import db


class Berita(db.Model):
    __tablename__ = "berita"

    id = db.Column(db.Integer, primary_key=True)
    judul = db.Column(db.String(255), nullable=False)
    ringkasan = db.Column(db.Text, nullable=False)
    konten = db.Column(db.Text, nullable=False)
    sumber_url = db.Column(db.String(255), nullable=True)
    gambar_url = db.Column(db.String(1024), nullable=True)
    published_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "judul": self.judul,
            "ringkasan": self.ringkasan,
            "konten": self.konten,
            "sumber_url": self.sumber_url,
            "gambar_url": self.gambar_url,
            "published_at": self.published_at.isoformat() if self.published_at else None,
        }
