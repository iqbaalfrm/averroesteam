from datetime import datetime

from app.extensions import db


class Portofolio(db.Model):
    __tablename__ = "portofolio"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    nama_aset = db.Column(db.String(120), nullable=False)
    simbol = db.Column(db.String(20), nullable=False)
    jumlah = db.Column(db.Float, nullable=False)
    harga_beli = db.Column(db.Float, nullable=False)

    user = db.relationship("User")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "nama_aset": self.nama_aset,
            "simbol": self.simbol,
            "jumlah": self.jumlah,
            "harga_beli": self.harga_beli,
            "nilai": round(self.jumlah * self.harga_beli, 2),
        }


class PortofolioRiwayat(db.Model):
    __tablename__ = "portofolio_riwayat"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    portofolio_id = db.Column(db.Integer, nullable=True)
    aksi = db.Column(db.String(20), nullable=False)  # create/update/delete
    nama_aset = db.Column(db.String(120), nullable=False)
    simbol = db.Column(db.String(20), nullable=False)
    jumlah = db.Column(db.Float, nullable=False)
    harga_beli = db.Column(db.Float, nullable=False)
    nilai = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False, index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "portofolio_id": self.portofolio_id,
            "aksi": self.aksi,
            "nama_aset": self.nama_aset,
            "simbol": self.simbol,
            "jumlah": self.jumlah,
            "harga_beli": self.harga_beli,
            "nilai": self.nilai,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
