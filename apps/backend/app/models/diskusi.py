from datetime import datetime

from app.extensions import db


class Diskusi(db.Model):
    __tablename__ = "diskusi"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    parent_id = db.Column(db.Integer, db.ForeignKey("diskusi.id"), nullable=True)
    judul = db.Column(db.String(200), nullable=True)
    isi = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship("User")
    parent = db.relationship("Diskusi", remote_side=[id], backref="balasan")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "parent_id": self.parent_id,
            "judul": self.judul,
            "isi": self.isi,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "user": self.user.to_dict() if self.user else None,
        }
