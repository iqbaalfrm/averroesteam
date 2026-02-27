from app.extensions import db


class Kelas(db.Model):
    __tablename__ = "kelas"

    id = db.Column(db.Integer, primary_key=True)
    judul = db.Column(db.String(200), nullable=False)
    deskripsi = db.Column(db.Text, nullable=False)
    tingkat = db.Column(db.String(50), nullable=False, default="Pemula")

    modul = db.relationship("Modul", backref="kelas", cascade="all, delete-orphan")
    quiz = db.relationship("Quiz", backref="kelas", cascade="all, delete-orphan")
    sertifikat = db.relationship("Sertifikat", backref="kelas", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "judul": self.judul,
            "deskripsi": self.deskripsi,
            "tingkat": self.tingkat,
        }
