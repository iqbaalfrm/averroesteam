from datetime import datetime

from app.extensions import db


class Quiz(db.Model):
    __tablename__ = "quiz"

    id = db.Column(db.Integer, primary_key=True)
    kelas_id = db.Column(db.Integer, db.ForeignKey("kelas.id"), nullable=False)
    pertanyaan = db.Column(db.Text, nullable=False)
    pilihan_a = db.Column(db.String(255), nullable=False)
    pilihan_b = db.Column(db.String(255), nullable=False)
    pilihan_c = db.Column(db.String(255), nullable=False)
    pilihan_d = db.Column(db.String(255), nullable=False)
    jawaban_benar = db.Column(db.String(1), nullable=False)

    def to_dict(self):
        return {
            "id": self.id,
            "kelas_id": self.kelas_id,
            "pertanyaan": self.pertanyaan,
            "pilihan": {
                "A": self.pilihan_a,
                "B": self.pilihan_b,
                "C": self.pilihan_c,
                "D": self.pilihan_d,
            },
        }


class QuizSubmission(db.Model):
    __tablename__ = "quiz_submission"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    quiz_id = db.Column(db.Integer, db.ForeignKey("quiz.id"), nullable=False)
    jawaban = db.Column(db.String(1), nullable=False)
    benar = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship("User")
    quiz = db.relationship("Quiz")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "quiz_id": self.quiz_id,
            "jawaban": self.jawaban,
            "benar": self.benar,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
