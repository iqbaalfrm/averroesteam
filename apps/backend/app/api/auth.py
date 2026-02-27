from datetime import datetime, timedelta
import random

from flask import Blueprint, current_app, request
from flask_jwt_extended import create_access_token, jwt_required
from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import db
from app.models import PasswordResetOTP, User

from .common import response_error, response_success

auth_bp = Blueprint("auth_api", __name__, url_prefix="/api/auth")


def _legacy_success(message: str, data=None, code: int = 200):
    # Backward-compatible shape for older mobile screens (`status` bool + `pesan`).
    payload = {"status": True, "pesan": message, "message": message, "data": data}
    return payload, code


def _legacy_error(message: str, code: int = 400, data=None):
    payload = {"status": False, "pesan": message, "message": message, "data": data}
    return payload, code


def _generate_otp_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def _find_active_otp(email: str, kode: str) -> PasswordResetOTP | None:
    return (
        PasswordResetOTP.query.filter_by(email=email, kode=kode, is_used=False)
        .order_by(PasswordResetOTP.created_at.desc(), PasswordResetOTP.id.desc())
        .first()
    )


@auth_bp.post("/register")
def register():
    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""

    if not nama or not email or not password:
        return response_error("Data register tidak lengkap", 400)

    if User.query.filter_by(email=email).first():
        return response_error("Email sudah terdaftar", 400)

    user = User(
        nama=nama,
        email=email,
        password_hash=generate_password_hash(password),
        role="user",
    )
    db.session.add(user)
    db.session.commit()

    token = create_access_token(identity=str(user.id), additional_claims={"role": user.role})
    return response_success("Registrasi berhasil", {"token": token, "user": user.to_dict()}, 201)


@auth_bp.post("/login")
def login():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""

    user = User.query.filter_by(email=email).first()
    if not user or not user.password_hash:
        return response_error("Email atau password salah", 401)

    if not check_password_hash(user.password_hash, password):
        return response_error("Email atau password salah", 401)

    token = create_access_token(identity=str(user.id), additional_claims={"role": user.role})
    return response_success("Login berhasil", {"token": token, "user": user.to_dict()})


@auth_bp.post("/guest")
def guest_login():
    guest = User(nama="Pengguna Tamu", role="user")
    db.session.add(guest)
    db.session.commit()

    token = create_access_token(identity=str(guest.id), additional_claims={"role": guest.role})
    return response_success("Login tamu berhasil", {"token": token, "user": guest.to_dict()})


@auth_bp.post("/google")
def google_login_stub():
    # Phase 1 decision: stub endpoint to avoid 404 in mobile while real Google auth is deferred.
    payload, code = _legacy_error(
        "Login Google belum aktif di backend saat ini. Gunakan login email/password atau tamu.",
        501,
    )
    return payload, code


@auth_bp.get("/me")
@jwt_required()
def me():
    from flask_jwt_extended import get_jwt_identity

    user_id = get_jwt_identity()
    if user_id is None:
        return response_error("Unauthorized", 401)
    user = User.query.get(int(user_id))
    if not user:
        return response_error("User tidak ditemukan", 404)
    return response_success("Profil berhasil diambil", {"user": user.to_dict()})


@auth_bp.put("/me")
@jwt_required()
def update_me():
    from flask_jwt_extended import get_jwt_identity

    user_id = get_jwt_identity()
    if user_id is None:
        return response_error("Unauthorized", 401)
    user = User.query.get(int(user_id))
    if not user:
        return response_error("User tidak ditemukan", 404)

    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    email = (payload.get("email") or "").strip().lower()

    if not nama:
        return response_error("Nama wajib diisi", 400)

    if email:
        exists = User.query.filter(User.email == email, User.id != user.id).first()
        if exists:
            return response_error("Email sudah digunakan user lain", 400)
        user.email = email
    else:
        user.email = None

    user.nama = nama
    db.session.commit()
    return response_success("Profil berhasil diperbarui", {"user": user.to_dict()})


@auth_bp.post("/lupa-password")
def lupa_password():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    if not email:
        data, code = _legacy_error("Email wajib diisi", 400)
        return data, code

    user = User.query.filter_by(email=email).first()
    if not user:
        data, code = _legacy_error("Email tidak terdaftar", 404)
        return data, code

    now = datetime.utcnow()
    (
        PasswordResetOTP.query.filter_by(email=email, is_used=False)
        .update({"is_used": True, "used_at": now, "updated_at": now}, synchronize_session=False)
    )

    expires_seconds = int(current_app.config.get("PASSWORD_RESET_OTP_EXPIRES_SECONDS", 300))
    debug_otp = bool(current_app.config.get("PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE", False))

    kode = _generate_otp_code()
    otp = PasswordResetOTP(
        email=email,
        kode=kode,
        expired_at=now + timedelta(seconds=expires_seconds),
    )
    db.session.add(otp)
    db.session.commit()

    data_payload = {"email": email, "expires_in_seconds": expires_seconds}
    if debug_otp:
        data_payload["otp_debug"] = kode

    data, code = _legacy_success("OTP berhasil dikirim", data_payload)
    return data, code


@auth_bp.post("/verifikasi-otp")
def verifikasi_otp():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    kode = (payload.get("kode") or payload.get("otp") or "").strip()

    if not email or not kode:
        data, code = _legacy_error("Email dan kode OTP wajib diisi", 400)
        return data, code

    otp = _find_active_otp(email, kode)
    if not otp:
        data, code = _legacy_error("Kode OTP tidak valid", 400)
        return data, code

    now = datetime.utcnow()
    otp.attempt_count = (otp.attempt_count or 0) + 1
    if otp.is_expired(now):
        db.session.commit()
        data, code = _legacy_error("Kode OTP sudah kedaluwarsa", 400)
        return data, code

    otp.verified_at = now
    otp.updated_at = now
    db.session.commit()

    data, code = _legacy_success("Kode OTP valid", {"email": email, "verified": True})
    return data, code


@auth_bp.post("/reset-password")
def reset_password():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    kode = (payload.get("kode") or payload.get("otp") or "").strip()
    password_baru = payload.get("password_baru") or payload.get("new_password") or ""

    if not email or not kode or not password_baru:
        data, code = _legacy_error("Email, kode OTP, dan password baru wajib diisi", 400)
        return data, code
    if len(password_baru) < 8:
        data, code = _legacy_error("Password baru minimal 8 karakter", 400)
        return data, code

    user = User.query.filter_by(email=email).first()
    if not user:
        data, code = _legacy_error("Email tidak terdaftar", 404)
        return data, code

    otp = _find_active_otp(email, kode)
    if not otp:
        data, code = _legacy_error("Kode OTP tidak valid", 400)
        return data, code

    now = datetime.utcnow()
    if otp.is_expired(now):
        data, code = _legacy_error("Kode OTP sudah kedaluwarsa", 400)
        return data, code
    if not otp.verified_at:
        data, code = _legacy_error("Kode OTP belum diverifikasi", 400)
        return data, code

    user.password_hash = generate_password_hash(password_baru)
    otp.is_used = True
    otp.used_at = now
    otp.updated_at = now
    db.session.commit()

    data, code = _legacy_success("Password berhasil diubah", None)
    return data, code
