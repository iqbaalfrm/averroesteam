from datetime import datetime

from app.extensions import db


class MateriProgress(db.Model):
    __tablename__ = "materi_progress"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    materi_id = db.Column(db.Integer, db.ForeignKey("materi.id"), nullable=False, index=True)
    completed_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    user = db.relationship("User")
    materi = db.relationship("Materi")

    __table_args__ = (
        db.UniqueConstraint("user_id", "materi_id", name="uq_materi_progress_user_materi"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "materi_id": self.materi_id,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }

