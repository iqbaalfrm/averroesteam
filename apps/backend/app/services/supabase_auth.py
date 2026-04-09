from __future__ import annotations

from datetime import datetime
from threading import Lock
from typing import Any

import jwt
from bson import ObjectId
from flask import current_app

from app.extensions import mongo

_jwk_client_cache: dict[str, jwt.PyJWKClient] = {}
_jwk_client_lock = Lock()


class SupabaseAuthError(Exception):
    def __init__(self, message: str, status_code: int = 401):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def is_supabase_auth_enabled() -> bool:
    if not bool(current_app.config.get("SUPABASE_AUTH_ENABLED", False)):
        return False
    return bool(
        current_app.config.get("SUPABASE_JWT_SECRET")
        or current_app.config.get("SUPABASE_JWKS_URL")
        or current_app.config.get("SUPABASE_URL")
    )


def _issuer() -> str | None:
    raw = (current_app.config.get("SUPABASE_JWT_ISSUER") or "").strip()
    if raw:
        return raw
    url = (current_app.config.get("SUPABASE_URL") or "").strip().rstrip("/")
    if not url:
        return None
    return f"{url}/auth/v1"


def _jwks_url() -> str | None:
    raw = (current_app.config.get("SUPABASE_JWKS_URL") or "").strip()
    if raw:
        return raw
    issuer = _issuer()
    if not issuer:
        return None
    return f"{issuer}/.well-known/jwks.json"


def _audience() -> str | None:
    raw = (current_app.config.get("SUPABASE_JWT_AUDIENCE") or "").strip()
    return raw or None


def _jwk_client(url: str) -> jwt.PyJWKClient:
    with _jwk_client_lock:
        client = _jwk_client_cache.get(url)
        if client is None:
            client = jwt.PyJWKClient(url)
            _jwk_client_cache[url] = client
        return client


def verify_supabase_access_token(token: str) -> dict[str, Any]:
    if not token:
        raise SupabaseAuthError("Token Supabase tidak ditemukan", 401)
    if not is_supabase_auth_enabled():
        raise SupabaseAuthError("Supabase Auth belum dikonfigurasi di backend", 501)

    issuer = _issuer()
    audience = _audience()
    decode_kwargs: dict[str, Any] = {
        "algorithms": ["RS256", "HS256"],
        "options": {
            "verify_signature": True,
            "verify_aud": bool(audience),
            "verify_iss": bool(issuer),
        },
    }
    if audience:
        decode_kwargs["audience"] = audience
    if issuer:
        decode_kwargs["issuer"] = issuer

    secret = (current_app.config.get("SUPABASE_JWT_SECRET") or "").strip()
    try:
        if secret:
            claims = jwt.decode(token, secret, **decode_kwargs)
        else:
            jwks_url = _jwks_url()
            if not jwks_url:
                raise SupabaseAuthError("JWKS URL Supabase belum dikonfigurasi", 500)
            signing_key = _jwk_client(jwks_url).get_signing_key_from_jwt(token)
            claims = jwt.decode(token, signing_key.key, **decode_kwargs)
    except SupabaseAuthError:
        raise
    except jwt.ExpiredSignatureError as exc:
        raise SupabaseAuthError("Session Supabase sudah kedaluwarsa", 401) from exc
    except jwt.InvalidTokenError as exc:
        raise SupabaseAuthError("Token Supabase tidak valid", 401) from exc
    except Exception as exc:
        current_app.logger.exception("Supabase token verification failed")
        raise SupabaseAuthError("Gagal memverifikasi token Supabase", 500) from exc

    subject = str(claims.get("sub") or "").strip()
    if not subject:
        raise SupabaseAuthError("Token Supabase tidak memiliki subject user", 401)
    return claims


def _to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def _extract_role(claims: dict[str, Any]) -> str:
    app_metadata = claims.get("app_metadata") or {}
    user_metadata = claims.get("user_metadata") or {}
    role = (
        user_metadata.get("role")
        or app_metadata.get("role")
        or claims.get("role")
        or ("guest" if _to_bool(claims.get("is_anonymous")) else "user")
    )
    return str(role).strip().lower() or "user"


def _extract_name(claims: dict[str, Any]) -> str:
    user_metadata = claims.get("user_metadata") or {}
    candidates = [
        user_metadata.get("full_name"),
        user_metadata.get("name"),
        user_metadata.get("nama"),
        claims.get("name"),
    ]
    for candidate in candidates:
        value = str(candidate or "").strip()
        if value:
            return value
    if _to_bool(claims.get("is_anonymous")):
        return "Pengguna Tamu"
    return "Pengguna"


def sync_supabase_user(claims: dict[str, Any]) -> dict[str, Any] | None:
    subject = str(claims.get("sub") or "").strip()
    if not subject:
        raise SupabaseAuthError("User Supabase tidak valid", 401)

    email = str(claims.get("email") or "").strip().lower()
    role = _extract_role(claims)
    now = datetime.utcnow()
    user_metadata = claims.get("user_metadata") or {}
    app_metadata = claims.get("app_metadata") or {}
    provider = str(app_metadata.get("provider") or "supabase").strip() or "supabase"
    email_verified = (
        _to_bool(claims.get("email_verified"))
        or bool(claims.get("email_confirmed_at"))
        or _to_bool(user_metadata.get("email_verified"))
    )

    user = mongo.db.users.find_one({"supabase_user_id": subject})
    if not user and email:
        user = mongo.db.users.find_one({"email": email})

    update_data = {
        "supabase_user_id": subject,
        "auth_provider": provider,
        "role": role,
        "email_verified": email_verified,
        "updated_at": now,
        "last_login_at": now,
    }
    if email:
        update_data["email"] = email

    display_name = _extract_name(claims)
    if display_name:
        update_data["nama"] = display_name
    if user_metadata.get("avatar_url"):
        update_data["foto_url"] = str(user_metadata.get("avatar_url"))
    if app_metadata:
        update_data["supabase_app_metadata"] = app_metadata
    if user_metadata:
        update_data["supabase_user_metadata"] = user_metadata

    if user:
        if user.get("role") in {"admin", "superadmin"} and role != "admin":
            update_data["role"] = user.get("role")
        mongo.db.users.update_one({"_id": user["_id"]}, {"$set": update_data})
        return mongo.db.users.find_one({"_id": user["_id"]})

    if not bool(current_app.config.get("SUPABASE_AUTO_SYNC_USERS", True)):
        return None

    new_user = {
        "nama": display_name,
        "email": email or None,
        "role": role,
        "auth_provider": provider,
        "email_verified": email_verified,
        "supabase_user_id": subject,
        "supabase_app_metadata": app_metadata,
        "supabase_user_metadata": user_metadata,
        "created_at": now,
        "updated_at": now,
        "last_login_at": now,
    }
    result = mongo.db.users.insert_one(new_user)
    return mongo.db.users.find_one({"_id": result.inserted_id})


def resolve_local_user_by_identity(user_id: str | None, auth_source: str | None) -> dict[str, Any] | None:
    if not user_id:
        return None
    if auth_source == "supabase":
        return mongo.db.users.find_one({"supabase_user_id": user_id})
    if ObjectId.is_valid(user_id):
        return mongo.db.users.find_one({"_id": ObjectId(user_id)})
    return mongo.db.users.find_one({"_id": user_id})
