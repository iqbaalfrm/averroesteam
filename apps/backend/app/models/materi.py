from app.extensions import db


class Materi(db.Model):
    __tablename__ = "materi"

    id = db.Column(db.Integer, primary_key=True)
    modul_id = db.Column(db.Integer, db.ForeignKey("modul.id"), nullable=False)
    judul = db.Column(db.String(200), nullable=False)
    konten = db.Column(db.Text, nullable=False)
    url_video = db.Column(db.String(255), nullable=True)
    urutan = db.Column(db.Integer, nullable=False, default=1)

    def to_dict(self):
        return {
            "id": self.id,
            "modul_id": self.modul_id,
            "judul": self.judul,
            "konten": self.konten,
            "url_video": self.url_video,
            "urutan": self.urutan,
        }
