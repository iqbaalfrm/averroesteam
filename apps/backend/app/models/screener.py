from app.extensions import db


class Screener(db.Model):
    __tablename__ = "screener"

    id = db.Column(db.Integer, primary_key=True)
    nama_koin = db.Column(db.String(120), nullable=False)
    simbol = db.Column(db.String(20), nullable=False)
    status = db.Column(db.String(20), nullable=False, default="proses")
    alasan = db.Column(db.Text, nullable=False)

    def to_dict(self):
        return {
            "id": self.id,
            "nama_koin": self.nama_koin,
            "simbol": self.simbol,
            "status": self.status,
            "alasan": self.alasan,
        }
