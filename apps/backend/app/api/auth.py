from datetime import datetime, timedelta
import random

from bson import ObjectId
from flask import Blueprint, current_app, request
from flask_jwt_extended import create_access_token, jwt_required
from flask_mail import Message
from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import mongo, mail

from .common import (
    auth_required,
    current_auth_source,
    current_user_doc,
    current_user_id,
    current_user_supabase_id,
    format_doc,
    response_error,
    response_success,
)

auth_bp = Blueprint("auth_api", __name__, url_prefix="/api/auth")

OTP_PURPOSE_PASSWORD_RESET = "password_reset"
OTP_PURPOSE_REGISTER = "register"


def _legacy_success(message: str, data=None, code: int = 200):
    payload = {"status": True, "pesan": message, "message": message, "data": data}
    return payload, code


def _legacy_error(message: str, code: int = 400, data=None):
    payload = {"status": False, "pesan": message, "message": message, "data": data}
    return payload, code


def _generate_otp_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def _otp_purpose_query(purpose: str) -> dict:
    if purpose == OTP_PURPOSE_PASSWORD_RESET:
        return {
            "$or": [
                {"purpose": OTP_PURPOSE_PASSWORD_RESET},
                {"purpose": {"$exists": False}},
            ]
        }
    return {"purpose": purpose}


def _find_active_otp(email: str, kode: str, purpose: str):
    query = {
        "email": email,
        "kode": kode,
        "is_used": False,
    }
    query.update(_otp_purpose_query(purpose))
    return mongo.db.password_reset_otp.find_one(
        query,
        sort=[("created_at", -1), ("_id", -1)],
    )


def _invalidate_active_otps(email: str, purpose: str, now: datetime) -> None:
    query = {
        "email": email,
        "is_used": False,
    }
    query.update(_otp_purpose_query(purpose))
    mongo.db.password_reset_otp.update_many(
        query,
        {"$set": {"is_used": True, "used_at": now, "updated_at": now}},
    )


def is_otp_expired(otp, now):
    expired = otp.get("expired_at")
    if getattr(expired, "isoformat", None):
        return now > expired
    return False


def _otp_email_content(purpose: str, kode: str, expires_seconds: int) -> tuple[str, str]:
    expires_minutes = max(1, expires_seconds // 60)
    if purpose == OTP_PURPOSE_REGISTER:
        return (
            "Kode OTP Verifikasi Email - Averroes",
            (
                "Assalamu'alaikum,\n\n"
                f"Kode OTP Anda untuk verifikasi email pendaftaran adalah: {kode}\n\n"
                f"Kode ini berlaku selama {expires_minutes} menit. "
                "Jangan berikan kode ini kepada siapapun.\n\n"
                "Salam,\nTim Averroes"
            ),
        )

    return (
        "Kode OTP Lupa Password - Averroes",
        (
            "Assalamu'alaikum,\n\n"
            f"Kode OTP Anda untuk reset password adalah: {kode}\n\n"
            f"Kode ini berlaku selama {expires_minutes} menit. "
            "Jangan berikan kode ini kepada siapapun.\n\n"
            "Salam,\nTim Averroes"
        ),
    )


def _create_otp_and_send(email: str, purpose: str):
    now = datetime.utcnow()
    expires_seconds = int(
        current_app.config.get("PASSWORD_RESET_OTP_EXPIRES_SECONDS", 300)
    )
    debug_otp = bool(
        current_app.config.get("PASSWORD_RESET_DEBUG_OTP_IN_RESPONSE", False)
    )

    _invalidate_active_otps(email=email, purpose=purpose, now=now)

    kode = _generate_otp_code()
    otp = {
        "email": email,
        "kode": kode,
        "purpose": purpose,
        "expired_at": now + timedelta(seconds=expires_seconds),
        "is_used": False,
        "attempt_count": 0,
        "created_at": now,
        "updated_at": now,
    }
    mongo.db.password_reset_otp.insert_one(otp)

    subject, body = _otp_email_content(
        purpose=purpose,
        kode=kode,
        expires_seconds=expires_seconds,
    )
    try:
        msg = Message(
            subject=subject,
            recipients=[email],
            body=body,
        )
        mail.send(msg)
    except Exception as exc:
        current_app.logger.error("Gagal mengirim email ke %s: %s", email, str(exc))
        if not debug_otp:
            return None, (
                "Gagal mengirim email OTP, silakan coba lagi nanti",
                500,
            )

    data_payload = {
        "email": email,
        "purpose": purpose,
        "expires_in_seconds": expires_seconds,
    }
    if debug_otp:
        data_payload["otp_debug"] = kode
    return data_payload, None


def _auth_payload(user: dict) -> dict:
    token = create_access_token(
        identity=str(user["_id"]),
        additional_claims={"role": user.get("role")},
    )
    return {
        "token": token,
        "user": format_doc(user, "password_hash"),
    }


def _serialize_wallet(wallet: dict) -> dict:
    payload = format_doc(wallet)
    payload.pop("user_id", None)
    return payload


def _wallets_for_user(user_id: str) -> list[dict]:
    rows = list(
        mongo.db.user_wallets.find({"user_id": user_id}).sort(
            [("is_primary", -1), ("created_at", -1), ("_id", -1)]
        )
    )
    return [_serialize_wallet(row) for row in rows]


def _auth_me_payload(user: dict) -> dict:
    local_user_id = str(user["_id"])
    payload = {
        "user": format_doc(user, "password_hash"),
        "auth_source": current_auth_source(),
        "supabase_user_id": current_user_supabase_id() or user.get("supabase_user_id"),
        "wallets": _wallets_for_user(local_user_id),
    }
    return payload


def _user_identity_variants(user_id: str) -> list:
    variants = [user_id]
    if ObjectId.is_valid(user_id):
        try:
            variants.append(ObjectId(user_id))
        except Exception:
            pass
    return variants


def _purge_legacy_user_account(user: dict, user_id: str) -> None:
    user_variants = _user_identity_variants(user_id)
    now = datetime.utcnow()

    mongo.db.user_wallets.delete_many({"user_id": {"$in": user_variants}})
    mongo.db.portofolio.delete_many({"user_id": {"$in": user_variants}})
    mongo.db.portofolio_riwayat.delete_many({"user_id": {"$in": user_variants}})
    mongo.db.materi_progress.delete_many({"user_id": {"$in": user_variants}})
    mongo.db.quiz_submissions.delete_many({"user_id": {"$in": user_variants}})
    mongo.db.sertifikat_user.delete_many({"user_id": {"$in": user_variants}})

    mongo.db.diskusi.update_many(
        {"user_id": {"$in": user_variants}},
        {"$set": {"user_id": None, "updated_at": now}},
    )
    mongo.db.sessions.update_many(
        {"user_id": {"$in": user_variants}},
        {"$set": {"user_id": None, "updated_at": now}},
    )

    email = str(user.get("email") or "").strip().lower()
    if email:
        mongo.db.password_reset_otp.delete_many({"email": email})

    mongo.db.users.delete_one({"_id": user["_id"]})


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
    if len(password) < 8:
        return response_error("Password minimal 8 karakter", 400)

    now = datetime.utcnow()
    existing = mongo.db.users.find_one({"email": email})
    if existing and existing.get("email_verified") is not False:
        return response_error("Email sudah terdaftar", 400)

    user_data = {
        "nama": nama,
        "email": email,
        "password_hash": generate_password_hash(password),
        "role": "user",
        "auth_provider": "local",
        "email_verified": False,
        "updated_at": now,
    }

    if existing:
        mongo.db.users.update_one({"_id": existing["_id"]}, {"$set": user_data})
        user = mongo.db.users.find_one({"_id": existing["_id"]})
    else:
        user_data["created_at"] = now
        result = mongo.db.users.insert_one(user_data)
        user = mongo.db.users.find_one({"_id": result.inserted_id})

    otp_payload, otp_error = _create_otp_and_send(
        email=email,
        purpose=OTP_PURPOSE_REGISTER,
    )
    if otp_error is not None:
        message, status_code = otp_error
        return response_error(message, status_code)

    response_payload = {
        "email": email,
        "requires_verification": True,
        "user": format_doc(user, "password_hash"),
        **(otp_payload or {}),
    }
    return response_success(
        "Registrasi berhasil. Kode OTP telah dikirim ke email Anda",
        response_payload,
        201,
    )


@auth_bp.post("/verifikasi-otp-register")
def verifikasi_otp_register():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    kode = (payload.get("kode") or payload.get("otp") or "").strip()

    if not email or not kode:
        data, code = _legacy_error("Email dan kode OTP wajib diisi", 400)
        return data, code

    user = mongo.db.users.find_one({"email": email})
    if not user:
        data, code = _legacy_error("Email tidak terdaftar", 404)
        return data, code
    if user.get("email_verified") is True:
        data, code = _legacy_error("Email sudah diverifikasi. Silakan login", 400)
        return data, code

    otp = _find_active_otp(email, kode, OTP_PURPOSE_REGISTER)
    if not otp:
        data, code = _legacy_error("Kode OTP tidak valid", 400)
        return data, code

    now = datetime.utcnow()
    attempt_count = otp.get("attempt_count", 0) + 1
    if is_otp_expired(otp, now):
        mongo.db.password_reset_otp.update_one(
            {"_id": otp["_id"]},
            {"$set": {"attempt_count": attempt_count}},
        )
        data, code = _legacy_error("Kode OTP sudah kedaluwarsa", 400)
        return data, code

    mongo.db.password_reset_otp.update_one(
        {"_id": otp["_id"]},
        {
            "$set": {
                "attempt_count": attempt_count,
                "verified_at": now,
                "is_used": True,
                "used_at": now,
                "updated_at": now,
            }
        },
    )
    mongo.db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"email_verified": True, "updated_at": now}},
    )
    user["email_verified"] = True
    user["updated_at"] = now

    data, code = _legacy_success(
        "Email berhasil diverifikasi",
        {
            "email": email,
            "verified": True,
            **_auth_payload(user),
        },
    )
    return data, code


@auth_bp.post("/resend-otp-register")
def resend_otp_register():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    if not email:
        data, code = _legacy_error("Email wajib diisi", 400)
        return data, code

    user = mongo.db.users.find_one({"email": email})
    if not user:
        data, code = _legacy_error("Email tidak terdaftar", 404)
        return data, code
    if user.get("email_verified") is not False:
        data, code = _legacy_error("Email sudah diverifikasi. Silakan login", 400)
        return data, code

    otp_payload, otp_error = _create_otp_and_send(
        email=email,
        purpose=OTP_PURPOSE_REGISTER,
    )
    if otp_error is not None:
        message, status_code = otp_error
        data, code = _legacy_error(message, status_code)
        return data, code

    data, code = _legacy_success(
        "OTP registrasi berhasil dikirim ke email Anda",
        otp_payload,
    )
    return data, code


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

    if user.get("email_verified") is False:
        return response_error(
            "Email belum diverifikasi. Silakan cek kode OTP yang sudah dikirim",
            403,
            {"email": email, "requires_verification": True},
        )

    return response_success("Login berhasil", _auth_payload(user))


@auth_bp.post("/guest")
def guest_login():
    guest = {
        "nama": "Pengguna Tamu",
        "role": "guest",
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    result = mongo.db.users.insert_one(guest)
    guest["_id"] = result.inserted_id

    token = create_access_token(
        identity=str(guest["_id"]),
        additional_claims={"role": guest["role"]},
    )
    return response_success(
        "Login tamu berhasil",
        {"token": token, "user": format_doc(guest, "password_hash")},
    )


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
        if user.get("email_verified") is not True:
            update_data["email_verified"] = True
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
            "email_verified": True,
            "created_at": now,
            "updated_at": now,
        }
        result = mongo.db.users.insert_one(user)
        user["_id"] = result.inserted_id

    return response_success("Login Google berhasil", _auth_payload(user))


@auth_bp.get("/sync")
@auth_required()
def sync_me():
    user = current_user_doc()
    if not user:
        return response_error("User tidak ditemukan", 404)
    return response_success(
        "Session berhasil disinkronkan",
        _auth_me_payload(user),
    )


@auth_bp.get("/me")
@auth_required()
def me():
    user = current_user_doc()
    if not user:
        return response_error("User tidak ditemukan", 404)
    return response_success(
        "Profil berhasil diambil",
        _auth_me_payload(user),
    )


@auth_bp.put("/me")
@auth_required()
def update_me():
    user_id = current_user_id()
    user = current_user_doc()
    if not user:
        return response_error("User tidak ditemukan", 404)

    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    email = (payload.get("email") or "").strip().lower()

    if not nama:
        return response_error("Nama wajib diisi", 400)

    if email:
        exists = mongo.db.users.find_one(
            {"email": email, "_id": {"$ne": user["_id"]}}
        )
        if exists:
            return response_error("Email sudah digunakan user lain", 400)
    else:
        email = None

    update_data = {
        "nama": nama,
        "email": email,
        "updated_at": datetime.utcnow(),
    }
    mongo.db.users.update_one({"_id": user["_id"]}, {"$set": update_data})

    user.update(update_data)
    return response_success(
        "Profil berhasil diperbarui",
        _auth_me_payload(user),
    )


@auth_bp.delete("/me")
@auth_required()
def delete_me():
    user_id = current_user_id()
    user = current_user_doc()
    if not user_id or not user:
        return response_error("User tidak ditemukan", 404)

    role = str(user.get("role") or "").strip().lower()
    if role == "admin":
        return response_error("Akun admin tidak bisa dihapus lewat aplikasi", 403)

    _purge_legacy_user_account(user, user_id)
    return response_success(
        "Akun berhasil dihapus",
        {"deleted": True, "user_id": user_id},
    )


@auth_bp.get("/wallets")
@auth_required()
def list_wallets():
    user_id = current_user_id()
    if user_id is None:
        return response_error("Unauthorized", 401)
    return response_success("Berhasil mengambil wallet user", _wallets_for_user(user_id))


@auth_bp.post("/wallets/link")
@auth_required()
def link_wallet():
    user = current_user_doc()
    user_id = current_user_id()
    if not user or user_id is None:
        return response_error("User tidak ditemukan", 404)

    payload = request.get_json() or {}
    wallet_address = str(payload.get("wallet_address") or "").strip()
    privy_user_id = str(payload.get("privy_user_id") or "").strip()
    wallet_type = str(payload.get("wallet_type") or "embedded").strip().lower()
    wallet_client = str(payload.get("wallet_client") or "privy").strip().lower()
    chain_type = str(payload.get("chain_type") or "evm").strip().lower()
    is_primary = bool(payload.get("is_primary", True))

    if not wallet_address:
        return response_error("wallet_address wajib diisi", 400)

    now = datetime.utcnow()
    if is_primary:
        mongo.db.user_wallets.update_many(
            {"user_id": user_id},
            {"$set": {"is_primary": False, "updated_at": now}},
        )

    query = {"user_id": user_id, "wallet_address": wallet_address.lower()}
    update_data = {
        "user_id": user_id,
        "supabase_user_id": current_user_supabase_id() or user.get("supabase_user_id"),
        "privy_user_id": privy_user_id or None,
        "wallet_address": wallet_address.lower(),
        "wallet_type": wallet_type,
        "wallet_client": wallet_client,
        "chain_type": chain_type,
        "is_primary": is_primary,
        "updated_at": now,
    }

    existing = mongo.db.user_wallets.find_one(query)
    if existing:
        mongo.db.user_wallets.update_one({"_id": existing["_id"]}, {"$set": update_data})
        wallet = mongo.db.user_wallets.find_one({"_id": existing["_id"]})
    else:
        update_data["created_at"] = now
        result = mongo.db.user_wallets.insert_one(update_data)
        wallet = mongo.db.user_wallets.find_one({"_id": result.inserted_id})

    mongo.db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "privy_user_id": privy_user_id or user.get("privy_user_id"),
                "wallet_address": wallet_address.lower(),
                "updated_at": now,
            }
        },
    )

    return response_success(
        "Wallet berhasil ditautkan",
        {
            "wallet": _serialize_wallet(wallet or update_data),
            "wallets": _wallets_for_user(user_id),
        },
        201,
    )


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

    otp_payload, otp_error = _create_otp_and_send(
        email=email,
        purpose=OTP_PURPOSE_PASSWORD_RESET,
    )
    if otp_error is not None:
        message, status_code = otp_error
        data, code = _legacy_error(message, status_code)
        return data, code

    data, code = _legacy_success(
        "OTP berhasil dikirim ke email Anda",
        otp_payload,
    )
    return data, code


@auth_bp.post("/verifikasi-otp")
def verifikasi_otp():
    payload = request.get_json() or {}
    email = (payload.get("email") or "").strip().lower()
    kode = (payload.get("kode") or payload.get("otp") or "").strip()

    if not email or not kode:
        data, code = _legacy_error("Email dan kode OTP wajib diisi", 400)
        return data, code

    otp = _find_active_otp(email, kode, OTP_PURPOSE_PASSWORD_RESET)
    if not otp:
        data, code = _legacy_error("Kode OTP tidak valid", 400)
        return data, code

    now = datetime.utcnow()
    attempt_count = otp.get("attempt_count", 0) + 1

    if is_otp_expired(otp, now):
        mongo.db.password_reset_otp.update_one(
            {"_id": otp["_id"]},
            {"$set": {"attempt_count": attempt_count}},
        )
        data, code = _legacy_error("Kode OTP sudah kedaluwarsa", 400)
        return data, code

    mongo.db.password_reset_otp.update_one(
        {"_id": otp["_id"]},
        {"$set": {"attempt_count": attempt_count, "verified_at": now, "updated_at": now}},
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

    otp = _find_active_otp(email, kode, OTP_PURPOSE_PASSWORD_RESET)
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
        {"$set": {"password_hash": generate_password_hash(password_baru), "updated_at": now}},
    )

    mongo.db.password_reset_otp.update_one(
        {"_id": otp["_id"]},
        {"$set": {"is_used": True, "used_at": now, "updated_at": now}},
    )

    data, code = _legacy_success("Password berhasil diubah", None)
    return data, code
