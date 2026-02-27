from app.extensions import db


class Modul(db.Model):
    __tablename__ = "modul"

    id = db.Column(db.Integer, primary_key=True)
    kelas_id = db.Column(db.Integer, db.ForeignKey("kelas.id"), nullable=False)
    judul = db.Column(db.String(200), nullable=False)
    deskripsi = db.Column(db.Text, nullable=False)
    urutan = db.Column(db.Integer, nullable=False, default=1)

    materi = db.relationship("Materi", backref="modul", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "kelas_id": self.kelas_id,
            "judul": self.judul,
            "deskripsi": self.deskripsi,
            "urutan": self.urutan,
        }
