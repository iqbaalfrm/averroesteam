from datetime import datetime

from app.extensions import db


class PasswordResetOTP(db.Model):
    __tablename__ = "password_reset_otps"

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), nullable=False, index=True)
    kode = db.Column(db.String(6), nullable=False)
    expired_at = db.Column(db.DateTime, nullable=False, index=True)
    verified_at = db.Column(db.DateTime, nullable=True)
    is_used = db.Column(db.Boolean, nullable=False, default=False)
    used_at = db.Column(db.DateTime, nullable=True)
    attempt_count = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def is_expired(self, now: datetime | None = None) -> bool:
        current = now or datetime.utcnow()
        return self.expired_at <= current

