from functools import wraps

from flask import jsonify
from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request


def response_success(message, data=None, code=200):
    return jsonify({"status": "success", "message": message, "data": data}), code


def response_error(message, code=400, data=None):
    return jsonify({"status": "error", "message": message, "data": data}), code


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        if current_user_role() != "admin":
            return response_error("Akses admin ditolak", 403)
        return fn(*args, **kwargs)

    return wrapper


def current_user_id():
    identity = get_jwt_identity()
    return int(identity) if identity is not None else None


def current_user_role():
    return (get_jwt() or {}).get("role")
