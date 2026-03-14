from datetime import datetime, timedelta
import random
from bson import ObjectId

from flask import Blueprint, current_app, request
from flask_jwt_extended import create_access_token, jwt_required
from flask_mail import Message
from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import mongo, mail

from .common import response_error, response_success, format_doc

auth_bp = Blueprint("auth_api", __name__, url_prefix="/api/auth")


def _legacy_success(message: str, data=None, code: int = 200):
    payload = {"status": True, "pesan": message, "message": message, "data": data}
    return payload, code


def _legacy_error(message: str, code: int = 400, data=None):
    payload = {"status": False, "pesan": message, "message": message, "data": data}
    return payload, code


def _generate_otp_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def _find_active_otp(email: str, kode: str):
    return mongo.db.password_reset_otp.find_one(
        {"email": email, "kode": kode, "is_used": False},
        sort=[("created_at", -1), ("_id", -1)]
    )


def is_otp_expired(otp, now):
    expired = otp.get("expired_at")
    if getattr(expired, "isoformat", None):
        return now > expired
    return False


def _get_google_client_ids():
    raw = current_app.config.get("GOOGLE_OAUTH_CLIENT_IDS", "")
    return [value.strip() for value in raw.split(",") if value.strip()]


def _verify_google_id_token(token: str):
    if not token:
        return None, "id_token wajib diisi"
    client_ids = _get_google_client_ids()
    if not client_ids:
        return None, "Login Google belum dikonfigurasi di backend."
    try:
        from google.oauth2 import id_token as google_id_token
        from google.auth.transport import requests as google_requests
    except Exception as exc:
        current_app.logger.error("Google auth library missing: %s", exc)
        return None, "Login Google belum siap di backend."

    request_adapter = google_requests.Request()
    last_error = None
    for client_id in client_ids:
        try:
            payload = google_id_token.verify_oauth2_token(
                token,
                request_adapter,
                audience=client_id,
            )
            return payload, None
        except ValueError as exc:
            last_error = exc
            continue

    current_app.logger.warning("Google token verification failed: %s", last_error)
    return None, "Token Google tidak valid"


@auth_bp.post("/register")
def register():
    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""

    if not nama or not email or not password:
        return response_error("Data register tidak lengkap", 400)

    if mongo.db.users.find_one({"email": email}):
        return response_error("Email sudah terdaftar", 400)

    user = {
        "nama": nama,
        "email": email,
        "password_hash": generate_password_hash(password),
        "role": "user",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    result = mongo.db.users.insert_one(user)
    user["_id"] = result.inserted_id

    token = create_access_token(identity=str(user["_id"]), additional_claims={"role": user["role"]})
    return response_success("Registrasi berhasil", {"token": token, "user": format_doc(user, "password_hash")}, 201)


@auth_bp.post("/login")
def login():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    password = payload.get("password") or ""

    user = mongo.db.users.find_one({"email": email})
    if not user or not user.get("password_hash"):
        return response_error("Email atau password salah", 401)

    if not check_password_hash(user["password_hash"], password):
        return response_error("Email atau password salah", 401)

    token = create_access_token(identity=str(user["_id"]), additional_claims={"role": user.get("role")})
    return response_success("Login berhasil", {"token": token, "user": format_doc(user, "password_hash")})


@auth_bp.post("/guest")
def guest_login():
    guest = {
        "nama": "Pengguna Tamu",
        "role": "guest",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    result = mongo.db.users.insert_one(guest)
    guest["_id"] = result.inserted_id

    token = create_access_token(identity=str(guest["_id"]), additional_claims={"role": guest["role"]})
    return response_success("Login tamu berhasil", {"token": token, "user": format_doc(guest, "password_hash")})


@auth_bp.post("/google")
def google_login():
    payload = request.get_json() or {}
    token = (payload.get("id_token") or payload.get("token") or "").strip()
    if not token:
        return response_error("id_token wajib diisi", 400)

    idinfo, error_message = _verify_google_id_token(token)
    if error_message:
        status_code = 501 if "konfigurasi" in error_message.lower() else 401
        return response_error(error_message, status_code)

    email = (idinfo.get("email") or "").strip().lower()
    if not email:
        return response_error("Email Google tidak ditemukan", 400)
    email_verified = idinfo.get("email_verified", False)
    if isinstance(email_verified, str):
        email_verified = email_verified.strip().lower() == "true"
    if not email_verified:
        return response_error("Email Google belum terverifikasi", 401)

    now = datetime.utcnow()
    sub = idinfo.get("sub")
    name = idinfo.get("name") or idinfo.get("given_name") or "Pengguna"
    picture = idinfo.get("picture")

    user = mongo.db.users.find_one({"email": email})
    if user:
        if user.get("google_sub") and sub and user.get("google_sub") != sub:
            return response_error("Akun Google tidak cocok dengan email ini", 409)
        update_data = {"updated_at": now}
        if sub:
            update_data["google_sub"] = sub
        if name and not user.get("nama"):
            update_data["nama"] = name
        if picture:
            update_data["foto_url"] = picture
        if "auth_provider" not in user:
            update_data["auth_provider"] = "google"
        if "email_verified" not in user:
            update_data["email_verified"] = bool(email_verified)
        if update_data:
            mongo.db.users.update_one({"_id": user["_id"]}, {"$set": update_data})
            user.update(update_data)
    else:
        user = {
            "nama": name,
            "email": email,
            "role": "user",
            "google_sub": sub,
            "auth_provider": "google",
            "foto_url": picture,
            "email_verified": bool(email_verified),
            "created_at": now,
            "updated_at": now,
        }
        result = mongo.db.users.insert_one(user)
        user["_id"] = result.inserted_id

    access_token = create_access_token(
        identity=str(user["_id"]),
        additional_claims={"role": user.get("role")},
    )
    return response_success(
        "Login Google berhasil",
        {"token": access_token, "user": format_doc(user, "password_hash")},
    )


@auth_bp.get("/me")
@jwt_required()
def me():
    from flask_jwt_extended import get_jwt_identity

    user_id = get_jwt_identity()
    if user_id is None:
        return response_error("Unauthorized", 401)
    
    user = mongo.db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        return response_error("User tidak ditemukan", 404)
    return response_success("Profil berhasil diambil", {"user": format_doc(user, "password_hash")})


@auth_bp.put("/me")
@jwt_required()
def update_me():
    from flask_jwt_extended import get_jwt_identity

    user_id = get_jwt_identity()
    if user_id is None:
        return response_error("Unauthorized", 401)
    user = mongo.db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        return response_error("User tidak ditemukan", 404)

    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    email = (payload.get("email") or "").strip().lower()

    if not nama:
        return response_error("Nama wajib diisi", 400)

    if email:
        exists = mongo.db.users.find_one({"email": email, "_id": {"$ne": ObjectId(user_id)}})
        if exists:
            return response_error("Email sudah digunakan user lain", 400)
    else:
        email = None

    update_data = {
        "nama": nama,
        "email": email,
        "updated_at": datetime.utcnow()
    }
    mongo.db.users.update_one({"_id": ObjectId(user_id)}, {"$set": update_data})
    
    user.update(update_data)
    return response_success("Profil berhasil diperbarui", {"user": format_doc(user, "password_hash")})


@auth_bp.post("/lupa-password")
def lupa_password():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    if not email:
        data, code = _legacy_error("Email wajib diisi", 400)
        return data, code

    user = mongo.db.users.find_one({"email": email})
    if not user:
        data, code = _legacy_error("Email tidak terdaftar", 404)
        return data, code

    now = datetime.utcnow()
    mongo.db.password_reset_otp.update_many(
        {"email": email, "is_used": False},
        {"$set": {"is_used": True, "used_at": now, "updated_at": now}}
    )

    expires_seconds = int(current_app.config.get("PASSWORD_RESET_OTP_EXPIRES_SECONDS", 300))
    debug_otp = bool(current_app.config.get("PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE", False))

    kode = _generate_otp_code()
    otp = {
        "email": email,
        "kode": kode,
        "expired_at": now + timedelta(seconds=expires_seconds),
        "is_used": False,
        "attempt_count": 0,
        "created_at": now,
        "updated_at": now
    }
    mongo.db.password_reset_otp.insert_one(otp)

    # Kirim email asli (Ikhtiar Nyata)
    try:
        msg = Message(
            subject="Kode OTP Lupa Password - Averroes",
            recipients=[email],
            body=f"Assalamu'alaikum,\n\nKode OTP Anda untuk reset password adalah: {kode}\n\nKode ini berlaku selama {expires_seconds // 60} menit. Jangan berikan kode ini kepada siapapun.\n\nSalam,\nTim Averroes"
        )
        mail.send(msg)
    except Exception as e:
        current_app.logger.error(f"Gagal mengirim email ke {email}: {str(e)}")
        # Jika dalam mode debug, kita tetap biarkan proses lanjut agar bisa dites
        if not debug_otp:
            data, code = _legacy_error("Gagal mengirim email OTP, silakan coba lagi nanti", 500)
            return data, code

    data_payload = {"email": email, "expires_in_seconds": expires_seconds}
    if debug_otp:
        data_payload["otp_debug"] = kode

    data, code = _legacy_success("OTP berhasil dikirim ke email Anda", data_payload)
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
    attempt_count = otp.get("attempt_count", 0) + 1
    
    if is_otp_expired(otp, now):
        mongo.db.password_reset_otp.update_one({"_id": otp["_id"]}, {"$set": {"attempt_count": attempt_count}})
        data, code = _legacy_error("Kode OTP sudah kedaluwarsa", 400)
        return data, code

    mongo.db.password_reset_otp.update_one(
        {"_id": otp["_id"]}, 
        {"$set": {"attempt_count": attempt_count, "verified_at": now, "updated_at": now}}
    )

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

    user = mongo.db.users.find_one({"email": email})
    if not user:
        data, code = _legacy_error("Email tidak terdaftar", 404)
        return data, code

    otp = _find_active_otp(email, kode)
    if not otp:
        data, code = _legacy_error("Kode OTP tidak valid", 400)
        return data, code

    now = datetime.utcnow()
    if is_otp_expired(otp, now):
        data, code = _legacy_error("Kode OTP sudah kedaluwarsa", 400)
        return data, code
    
    if not otp.get("verified_at"):
        data, code = _legacy_error("Kode OTP belum diverifikasi", 400)
        return data, code

    mongo.db.users.update_one(
        {"_id": user["_id"]}, 
        {"$set": {"password_hash": generate_password_hash(password_baru), "updated_at": now}}
    )
    
    mongo.db.password_reset_otp.update_one(
        {"_id": otp["_id"]},
        {"$set": {"is_used": True, "used_at": now, "updated_at": now}}
    )

    data, code = _legacy_success("Password berhasil diubah", None)
    return data, code
