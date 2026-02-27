from app.extensions import db


class Sertifikat(db.Model):
    __tablename__ = "sertifikat"

    id = db.Column(db.Integer, primary_key=True)
    kelas_id = db.Column(db.Integer, db.ForeignKey("kelas.id"), nullable=False)
    nama_template = db.Column(db.String(200), nullable=False)
    deskripsi = db.Column(db.Text, nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "kelas_id": self.kelas_id,
            "nama_template": self.nama_template,
            "deskripsi": self.deskripsi,
        }
