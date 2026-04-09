from __future__ import annotations

from functools import wraps

from bson import ObjectId
from flask import current_app, g, jsonify, request
from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request

from app.services.supabase_auth import (
    SupabaseAuthError,
    resolve_local_user_by_identity,
    sync_supabase_user,
    verify_supabase_access_token,
)


def _json_safe(value):
    if isinstance(value, ObjectId):
        return str(value)
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_json_safe(v) for v in value]
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return value


def response_success(message, data=None, code=200):
    return jsonify({"status": "success", "message": message, "data": _json_safe(data)}), code


def response_error(message, code=400, data=None):
    return jsonify({"status": "error", "message": message, "data": _json_safe(data)}), code


def _empty_auth_context() -> dict:
    return {
        "authenticated": False,
        "source": None,
        "user_id": None,
        "supabase_user_id": None,
        "role": None,
        "claims": {},
        "user_doc": None,
        "email": None,
    }


def _set_auth_context(**kwargs) -> dict:
    context = _empty_auth_context()
    context.update(kwargs)
    g.auth_context = context
    return context


def _get_auth_context() -> dict:
    return getattr(g, "auth_context", _empty_auth_context())


def _extract_bearer_token() -> str | None:
    raw = request.headers.get("Authorization") or ""
    if not raw.lower().startswith("bearer "):
        return None
    token = raw[7:].strip()
    return token or None


def _supabase_role(claims: dict, user_doc: dict | None) -> str | None:
    if user_doc and user_doc.get("role"):
        return str(user_doc.get("role")).strip().lower()
    app_metadata = claims.get("app_metadata") or {}
    user_metadata = claims.get("user_metadata") or {}
    for candidate in (
        user_metadata.get("role"),
        app_metadata.get("role"),
        claims.get("role"),
    ):
        value = str(candidate or "").strip().lower()
        if value:
            return value
    if claims.get("is_anonymous"):
        return "guest"
    return "user"


def _authenticate_with_supabase() -> bool:
    token = _extract_bearer_token()
    if not token or not bool(current_app.config.get("SUPABASE_AUTH_ENABLED", False)):
        return False

    claims = verify_supabase_access_token(token)
    user_doc = sync_supabase_user(claims)
    subject = str(claims.get("sub") or "").strip() or None
    user_id = str(user_doc.get("_id")) if user_doc and user_doc.get("_id") is not None else subject
    _set_auth_context(
        authenticated=True,
        source="supabase",
        user_id=user_id,
        supabase_user_id=subject,
        role=_supabase_role(claims, user_doc),
        claims=claims,
        user_doc=user_doc,
        email=(user_doc or {}).get("email") or claims.get("email"),
    )
    return True


def _authenticate_with_legacy(optional: bool) -> bool:
    verify_jwt_in_request(optional=optional)
    identity = get_jwt_identity()
    if identity is None:
        return False
    user_id = str(identity)
    claims = get_jwt() or {}
    user_doc = resolve_local_user_by_identity(user_id, "legacy")
    _set_auth_context(
        authenticated=True,
        source="legacy",
        user_id=user_id,
        supabase_user_id=(user_doc or {}).get("supabase_user_id"),
        role=((user_doc or {}).get("role") or claims.get("role")),
        claims=claims,
        user_doc=user_doc,
        email=(user_doc or {}).get("email"),
    )
    return True


def authenticate_request(optional: bool = False, allow_legacy: bool | None = None):
    allow_legacy = (
        bool(current_app.config.get("AUTH_TRANSITION_ALLOW_LEGACY", True))
        if allow_legacy is None
        else allow_legacy
    )
    _set_auth_context()

    supabase_error: SupabaseAuthError | None = None
    try:
        if _authenticate_with_supabase():
            return True, None
    except SupabaseAuthError as exc:
        supabase_error = exc

    if allow_legacy and bool(current_app.config.get("LEGACY_JWT_ENABLED", True)):
        try:
            if _authenticate_with_legacy(optional=optional):
                return True, None
        except Exception:
            if optional:
                _set_auth_context()
                return False, None
            if supabase_error is not None:
                return False, supabase_error
            return False, SupabaseAuthError("Token tidak valid", 401)

    if optional:
        _set_auth_context()
        return False, None
    if supabase_error is not None:
        return False, supabase_error
    return False, SupabaseAuthError("Unauthorized", 401)


def auth_required(optional: bool = False, allow_legacy: bool | None = None):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            _, error = authenticate_request(optional=optional, allow_legacy=allow_legacy)
            if error is not None:
                return response_error(error.message, error.status_code)
            return fn(*args, **kwargs)

        return wrapper

    return decorator


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        _, error = authenticate_request(optional=False)
        if error is not None:
            return response_error(error.message, error.status_code)
        if current_user_role() != "admin":
            return response_error("Akses admin ditolak", 403)
        return fn(*args, **kwargs)

    return wrapper


def format_doc(doc, *exclude):
    if not doc:
        return None
    d = dict(doc)
    if "_id" in d:
        d["id"] = str(d.pop("_id"))
    for k, v in d.items():
        d[k] = _json_safe(v)
    for ex in exclude:
        d.pop(ex, None)
    return d


def current_user_id():
    identity = _get_auth_context().get("user_id")
    return identity if identity is not None else None


def current_user_supabase_id():
    identity = _get_auth_context().get("supabase_user_id")
    return identity if identity is not None else None


def current_user_email():
    email = _get_auth_context().get("email")
    return email if email is not None else None


def current_user_role():
    role = _get_auth_context().get("role")
    if role is not None:
        return str(role).strip().lower()
    claims = _get_auth_context().get("claims") or {}
    raw = claims.get("role")
    return str(raw).strip().lower() if raw else None


def current_auth_source():
    return _get_auth_context().get("source")


def current_user_doc():
    return _get_auth_context().get("user_doc")
