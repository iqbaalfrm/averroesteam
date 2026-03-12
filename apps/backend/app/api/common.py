from functools import wraps

from flask import jsonify
from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request
from bson import ObjectId


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


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
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
    identity = get_jwt_identity()
    return identity if identity is not None else None


def current_user_role():
    return (get_jwt() or {}).get("role")
