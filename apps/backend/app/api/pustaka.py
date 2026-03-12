from __future__ import annotations

import math
import os
import re
from datetime import datetime
from bson import ObjectId

from flask import Blueprint, current_app, request, url_for
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

from app.extensions import mongo
from app.services.storage import (
    make_signed_file_token,
    parse_signed_file_token,
    save_upload,
    send_local_object,
)

from .common import admin_required, response_error, response_success, format_doc

pustaka_bp = Blueprint("pustaka_api", __name__, url_prefix="/api/buku")
pustaka_admin_bp = Blueprint("pustaka_admin_api", __name__, url_prefix="/api/admin/buku")


def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (text or "").strip().lower()).strip("-")
    return slug or "buku"


def _ensure_unique_book_slug(base_text: str, ignore_id: str | None = None) -> str:
    base = _slugify(base_text)
    slug = base
    i = 2
    while True:
        query = {"slug": slug}
        if ignore_id:
            query["_id"] = {"$ne": ObjectId(ignore_id)}
        if mongo.db.buku.find_one(query) is None:
            return slug
        slug = f"{base}-{i}"
        i += 1


def _ensure_unique_category_slug(base_text: str, ignore_id: str | None = None) -> str:
    base = _slugify(base_text)
    slug = base
    i = 2
    while True:
        query = {"slug": slug}
        if ignore_id:
            query["_id"] = {"$ne": ObjectId(ignore_id)}
        if mongo.db.kategori_buku.find_one(query) is None:
            return slug
        slug = f"{base}-{i}"
        i += 1


def _now_utc() -> datetime:
    return datetime.utcnow()


def _to_bool(v) -> bool | None:
    if v is None:
        return None
    if isinstance(v, bool):
        return v
    s = str(v).strip().lower()
    if s in {"1", "true", "yes", "on"}:
        return True
    if s in {"0", "false", "no", "off"}:
        return False
    return None


def _to_int(v, default: int, min_value: int = 1, max_value: int | None = None) -> int:
    try:
        out = int(v)
    except (TypeError, ValueError):
        out = default
    if out < min_value:
        out = min_value
    if max_value is not None and out > max_value:
        out = max_value
    return out


def _cover_url_for_book(b: dict) -> str | None:
    if not b.get("cover_key"):
        return None
    return url_for("pustaka_api.cover_buku", buku_id=str(b["_id"]), _external=True)


def active_file_key(b):
    if b.get("format_file") == "pdf":
         return b.get("file_pdf")
    return b.get("file_key")


def _serialize_public_book(b: dict) -> dict:
    payload = format_doc(b)
    payload["cover_url"] = _cover_url_for_book(b)
    can_access = bool(active_file_key(b) or b.get("drive_file_id"))
    payload["can_download"] = can_access
    payload["has_file"] = can_access
    
    # Hide internal data
    for k in ["created_by", "updated_by", "file_key", "file_pdf"]:
         payload.pop(k, None)
    return payload


def _serialize_admin_book(b: dict) -> dict:
    payload = format_doc(b)
    payload["cover_url"] = _cover_url_for_book(b)
    payload["can_download"] = bool(active_file_key(b) or b.get("drive_file_id"))
    
    cat_id = b.get("kategori_id")
    if cat_id:
        cat = mongo.db.kategori_buku.find_one({"_id": cat_id})
        payload["kategori"] = format_doc(cat) if cat else None
    else:
        payload["kategori"] = None
        
    return payload


def _validate_book_payload(payload: dict, *, is_update: bool = False) -> tuple[dict, str | None]:
    data: dict = {}
    for key in ("judul", "penulis", "deskripsi", "status", "akses", "bahasa", "format_file", "drive_file_id"):
        if key in payload:
            data[key] = (payload.get(key) or "").strip()

    if "judul" in data and not data["judul"]:
        return {}, "Judul wajib diisi"
    if "penulis" in data and not data["penulis"]:
        return {}, "Penulis wajib diisi"
    if "deskripsi" in data and not data["deskripsi"]:
         return {}, "Deskripsi wajib diisi"

    if not is_update:
        for required in ("judul", "penulis", "deskripsi"):
            if not (data.get(required) or "").strip():
                return {}, f"{required.replace('_', ' ').title()} wajib diisi"

    if "status" in data and data["status"] not in {"draft", "published", "archived"}:
        return {}, "Status tidak valid"
    if "akses" in data and data["akses"] not in {"gratis", "premium", "internal"}:
        return {}, "Akses tidak valid"
    if "format_file" in data and data["format_file"] and data["format_file"] not in {"pdf", "epub"}:
        return {}, "Format file tidak valid"

    if "kategori_id" in payload:
        kategori_id = payload.get("kategori_id")
        if kategori_id in (None, ""):
             data["kategori_id"] = None
        else:
             try:
                 data["kategori_id"] = ObjectId(kategori_id)
             except Exception:
                 return {}, "Kategori tidak valid"

    if "is_featured" in payload:
        parsed_bool = _to_bool(payload.get("is_featured"))
        if parsed_bool is None:
            return {}, "is_featured tidak valid"
        data["is_featured"] = parsed_bool

    if "slug" in payload:
        raw_slug = (payload.get("slug") or "").strip()
        data["slug"] = _slugify(raw_slug) if raw_slug else ""

    return data, None


def _apply_publish_state(buku: dict) -> tuple[bool, str | None]:
    if (buku.get("status") or "").lower() != "published":
        return True, None
    if not (active_file_key(buku) or buku.get("drive_file_id")):
        return False, "Buku belum memiliki file ebook atau Drive file ID"
    if not buku.get("slug"):
        buku["slug"] = _ensure_unique_book_slug(buku.get("judul", "buku"), ignore_id=buku.get("_id"))
    if not buku.get("published_at"):
        buku["published_at"] = _now_utc()
    return True, None


def _build_pagination_payload(*, page: int, per_page: int, total: int) -> dict:
    total_pages = max(1, math.ceil(total / per_page)) if per_page else 1
    return {
        "page": page,
        "per_page": per_page,
        "total": total,
        "total_pages": total_pages,
    }


@pustaka_bp.get("")
def list_buku():
    page = _to_int(request.args.get("page"), 1, min_value=1)
    per_page = _to_int(request.args.get("per_page"), 10, min_value=1, max_value=50)
    q = (request.args.get("q") or "").strip()
    kategori_id = request.args.get("kategori_id")
    kategori_slug = (request.args.get("kategori_slug") or "").strip().lower()
    format_file = (request.args.get("format") or "").strip().lower()
    featured = _to_bool(request.args.get("featured"))
    sort = (request.args.get("sort") or "terbaru").strip().lower()

    filters = {"status": "published"}
    
    if q:
        regex = re.compile(re.escape(q), re.IGNORECASE)
        filters["$or"] = [
            {"judul": regex},
            {"penulis": regex},
            {"deskripsi": regex}
        ]
        
    if kategori_id:
        try:
             filters["kategori_id"] = ObjectId(kategori_id)
        except Exception:
             pass
             
    if kategori_slug:
        cat = mongo.db.kategori_buku.find_one({"slug": kategori_slug})
        if cat:
            filters["kategori_id"] = cat["_id"]
        else:
            # force empty result
            filters["kategori_id"] = "invalid"
            
    if format_file in {"pdf", "epub"}:
        filters["format_file"] = format_file
        
    if featured is not None:
        filters["is_featured"] = featured

    cursor = mongo.db.buku.find(filters)
    
    if sort == "judul":
        cursor = cursor.sort("judul", 1)
    else:
        cursor = cursor.sort([("published_at", -1), ("_id", -1)])

    total = mongo.db.buku.count_documents(filters)
    rows = list(cursor.skip((page - 1) * per_page).limit(per_page))

    data = {
        "items": [_serialize_public_book(row) for row in rows],
        "pagination": _build_pagination_payload(page=page, per_page=per_page, total=total),
        "filters": {
            "q": q,
            "kategori_id": str(kategori_id) if kategori_id else None,
            "kategori_slug": kategori_slug or None,
            "format": format_file or None,
            "featured": featured,
            "sort": sort,
        },
    }
    return response_success("Berhasil mengambil data buku", data)


@pustaka_bp.get("/kategori")
def list_kategori_buku():
    rows = list(mongo.db.kategori_buku.find({"is_active": True}).sort([("urutan", 1), ("nama", 1)]))
    return response_success("Berhasil mengambil kategori buku", [format_doc(row) for row in rows])


@pustaka_bp.get("/slug/<string:slug>")
def detail_buku_slug(slug: str):
    row = mongo.db.buku.find_one({"slug": slug, "status": "published"})
    if not row:
        return response_error("Buku tidak ditemukan", 404)
    return response_success("Berhasil mengambil detail buku", _serialize_public_book(row))


@pustaka_bp.get("/<string:buku_id>")
def detail_buku(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id), "status": "published"})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
        return response_error("Buku tidak ditemukan", 404)
    return response_success("Berhasil mengambil detail buku", _serialize_public_book(row))


@pustaka_bp.get("/<string:buku_id>/cover")
def cover_buku(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id), "status": "published"})
    except Exception:
        return response_error("Buku tidak valid", 400)
        
    if not row or not row.get("cover_key"):
        return response_error("Cover tidak ditemukan", 404)
    try:
        return send_local_object(
            row["cover_key"],
            download_name=os.path.basename(row["cover_key"]),
            as_attachment=False,
        )
    except FileNotFoundError:
        return response_error("Cover tidak ditemukan", 404)


@pustaka_bp.post("/<string:buku_id>/access")
def access_buku(buku_id: str):
    try:
         row = mongo.db.buku.find_one({"_id": ObjectId(buku_id), "status": "published"})
    except Exception:
         return response_error("Buku tidak valid", 400)
         
    if not row:
        return response_error("Buku tidak ditemukan", 404)
        
    action = (request.get_json(silent=True) or {}).get("action") or "read"
    action = str(action).strip().lower()
    if action not in {"read", "download"}:
        action = "read"

    if row.get("drive_file_id"):
        drive_id = (row["drive_file_id"]).strip()
        if action == "read":
             url = f"https://drive.google.com/file/d/{drive_id}/preview"
        else:
             url = f"https://drive.google.com/uc?export=download&id={drive_id}"
        expires = int(current_app.config.get("PUSTAKA_SIGNED_URL_EXPIRES_SECONDS", 600))
        return response_success(
            "URL akses buku berhasil dibuat",
            {"url": url, "expires_in": expires, "filename": row.get("file_nama") or row.get("judul")},
        )

    file_key = active_file_key(row)
    if not file_key:
        return response_error("File buku tidak tersedia", 400)

    verify_jwt_in_request(optional=True)
    user_id = get_jwt_identity()
    if row.get("akses") in {"premium", "internal"} and not user_id:
        return response_error("Login diperlukan untuk mengakses buku ini", 401)

    token = make_signed_file_token(
        buku_id=str(row["_id"]),
        file_key=file_key,
        filename=row.get("file_nama") or os.path.basename(file_key),
    )
    signed_url = url_for("pustaka_api.download_signed_file", token=token, _external=True)
    expires = int(current_app.config.get("PUSTAKA_SIGNED_URL_EXPIRES_SECONDS", 600))
    return response_success(
        "URL akses buku berhasil dibuat",
        {"url": signed_url, "expires_in": expires, "filename": row.get("file_nama") or os.path.basename(file_key)},
    )


@pustaka_bp.get("/file/<string:token>")
def download_signed_file(token: str):
    try:
        payload = parse_signed_file_token(token)
    except PermissionError as exc:
        return response_error(str(exc), 403)
        
    buku_id = (payload.get("buku_id") or "")
    file_key = (payload.get("file_key") or "").strip()
    filename = (payload.get("filename") or "").strip()
    
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id), "status": "published"})
    except Exception:
        row = None
        
    if not row or active_file_key(row) != file_key:
        return response_error("Akses file tidak valid", 403)
    try:
        return send_local_object(file_key, download_name=filename or row.get("file_nama") or os.path.basename(file_key))
    except FileNotFoundError:
        return response_error("File tidak ditemukan", 404)


@pustaka_admin_bp.get("")
@admin_required
def admin_list_buku():
    page = _to_int(request.args.get("page"), 1, min_value=1)
    per_page = _to_int(request.args.get("per_page"), 20, min_value=1, max_value=100)
    q = (request.args.get("q") or "").strip()
    status = (request.args.get("status") or "").strip().lower()
    kategori_id = request.args.get("kategori_id")

    filters = {}
    if q:
        regex = re.compile(re.escape(q), re.IGNORECASE)
        filters["$or"] = [
            {"judul": regex},
            {"penulis": regex},
            {"deskripsi": regex}
        ]
    if status in {"draft", "published", "archived"}:
        filters["status"] = status
    if kategori_id:
        try:
             filters["kategori_id"] = ObjectId(kategori_id)
        except Exception:
             pass

    cursor = mongo.db.buku.find(filters).sort([("updated_at", -1), ("_id", -1)])
    total = mongo.db.buku.count_documents(filters)
    rows = list(cursor.skip((page - 1) * per_page).limit(per_page))
    
    return response_success(
        "Berhasil mengambil data buku admin",
        {
             "items": [_serialize_admin_book(row) for row in rows], 
             "pagination": _build_pagination_payload(page=page, per_page=per_page, total=total)
        },
    )


@pustaka_admin_bp.post("")
@admin_required
def admin_create_buku():
    payload = request.get_json() or {}
    data, err = _validate_book_payload(payload, is_update=False)
    if err:
        return response_error(err, 400)
        
    if data.get("kategori_id") and not mongo.db.kategori_buku.find_one({"_id": data["kategori_id"]}):
        return response_error("Kategori tidak ditemukan", 404)

    now = _now_utc()
    user_id = get_jwt_identity()
    
    buku = {
        "judul": data["judul"],
        "penulis": data["penulis"],
        "deskripsi": data["deskripsi"],
        "slug": data.get("slug") or _ensure_unique_book_slug(data["judul"]),
        "kategori_id": data.get("kategori_id"),
        "status": data.get("status") or "draft",
        "akses": data.get("akses") or "gratis",
        "bahasa": data.get("bahasa") or "id",
        "is_featured": bool(data.get("is_featured", False)),
        "format_file": data.get("format_file") or None,
        "created_at": now,
        "updated_at": now,
        "created_by": str(user_id) if user_id else None,
        "updated_by": str(user_id) if user_id else None,
    }
    
    ok, publish_err = _apply_publish_state(buku)
    if not ok:
        return response_error(publish_err or "Data buku tidak valid", 400)

    res = mongo.db.buku.insert_one(buku)
    buku["_id"] = res.inserted_id
    
    return response_success("Buku berhasil dibuat", _serialize_admin_book(buku), 201)


@pustaka_admin_bp.get("/<string:buku_id>")
@admin_required
def admin_detail_buku(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id)})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
         return response_error("Buku tidak ditemukan", 404)
    return response_success("Berhasil mengambil detail buku", _serialize_admin_book(row))


@pustaka_admin_bp.put("/<string:buku_id>")
@admin_required
def admin_update_buku(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id)})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
         return response_error("Buku tidak ditemukan", 404)

    payload = request.get_json() or {}
    data, err = _validate_book_payload(payload, is_update=True)
    if err:
        return response_error(err, 400)
    if data.get("kategori_id") and not mongo.db.kategori_buku.find_one({"_id": data["kategori_id"]}):
        return response_error("Kategori tidak ditemukan", 404)

    for key, value in data.items():
        if key == "slug":
            row[key] = value or _ensure_unique_book_slug(row.get("judul"), ignore_id=str(row["_id"]))
            continue
        row[key] = value

    if "judul" in data and ("slug" not in data or not data.get("slug")) and not row.get("slug"):
        row["slug"] = _ensure_unique_book_slug(row["judul"], ignore_id=str(row["_id"]))
        
    user_id = get_jwt_identity()
    row["updated_by"] = str(user_id) if user_id else row.get("updated_by")
    row["updated_at"] = _now_utc()
    
    ok, publish_err = _apply_publish_state(row)
    if not ok:
        return response_error(publish_err or "Data buku tidak valid", 400)

    mongo.db.buku.update_one({"_id": row["_id"]}, {"$set": row})
    return response_success("Buku berhasil diubah", _serialize_admin_book(row))


@pustaka_admin_bp.patch("/<string:buku_id>/status")
@admin_required
def admin_update_status_buku(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id)})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
         return response_error("Buku tidak ditemukan", 404)

    payload = request.get_json() or {}
    status = (payload.get("status") or "").strip().lower()
    if status not in {"draft", "published", "archived"}:
        return response_error("Status tidak valid", 400)
        
    row["status"] = status
    user_id = get_jwt_identity()
    row["updated_by"] = str(user_id) if user_id else row.get("updated_by")
    row["updated_at"] = _now_utc()
    
    if status != "published":
        if status == "draft":
             row["published_at"] = None
             
    ok, publish_err = _apply_publish_state(row)
    if not ok:
        return response_error(publish_err or "Data buku tidak valid", 400)
        
    mongo.db.buku.update_one({"_id": row["_id"]}, {"$set": row})
    return response_success("Status buku berhasil diubah", _serialize_admin_book(row))


@pustaka_admin_bp.delete("/<string:buku_id>")
@admin_required
def admin_delete_buku(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id)})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
         return response_error("Buku tidak ditemukan", 404)

    hard = _to_bool(request.args.get("hard")) is True
    if hard:
        mongo.db.buku.delete_one({"_id": row["_id"]})
        return response_success("Buku berhasil dihapus permanen", None)
        
    row["status"] = "archived"
    row["updated_at"] = _now_utc()
    user_id = get_jwt_identity()
    row["updated_by"] = str(user_id) if user_id else row.get("updated_by")
    
    mongo.db.buku.update_one({"_id": row["_id"]}, {"$set": row})
    return response_success("Buku berhasil diarsipkan", _serialize_admin_book(row))


@pustaka_admin_bp.post("/<string:buku_id>/upload-file")
@admin_required
def admin_upload_buku_file(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id)})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
         return response_error("Buku tidak ditemukan", 404)

    file_obj = request.files.get("file")
    if not file_obj or not file_obj.filename:
        return response_error("File ebook wajib diunggah", 400)
    try:
        stored = save_upload(file_obj, subdir="pustaka/ebook", allowed_exts={".pdf", ".epub"})
    except ValueError as exc:
        return response_error(str(exc), 400)

    ext = os.path.splitext(stored.filename)[1].lower()
    row["file_key"] = stored.key
    row["file_nama"] = stored.filename
    row["ukuran_file_bytes"] = stored.size_bytes
    row["storage_provider"] = "local"
    row["format_file"] = "epub" if ext == ".epub" else "pdf"
    if row["format_file"] == "pdf":
        row["file_pdf"] = stored.key
        
    row["updated_at"] = _now_utc()
    user_id = get_jwt_identity()
    row["updated_by"] = str(user_id) if user_id else row.get("updated_by")
    
    ok, publish_err = _apply_publish_state(row)
    if not ok:
        return response_error(publish_err or "File berhasil diunggah tetapi status buku tidak valid", 400)
        
    mongo.db.buku.update_one({"_id": row["_id"]}, {"$set": row})
    return response_success("File buku berhasil diunggah", _serialize_admin_book(row))


@pustaka_admin_bp.post("/<string:buku_id>/upload-cover")
@admin_required
def admin_upload_buku_cover(buku_id: str):
    try:
        row = mongo.db.buku.find_one({"_id": ObjectId(buku_id)})
    except Exception:
        return response_error("Buku tidak valid", 400)
    if not row:
         return response_error("Buku tidak ditemukan", 404)

    file_obj = request.files.get("file")
    if not file_obj or not file_obj.filename:
        return response_error("File cover wajib diunggah", 400)
    try:
        stored = save_upload(
            file_obj,
            subdir="pustaka/cover",
            allowed_exts={".jpg", ".jpeg", ".png", ".webp"},
        )
    except ValueError as exc:
        return response_error(str(exc), 400)

    row["cover_key"] = stored.key
    row["updated_at"] = _now_utc()
    user_id = get_jwt_identity()
    row["updated_by"] = str(user_id) if user_id else row.get("updated_by")
    
    mongo.db.buku.update_one({"_id": row["_id"]}, {"$set": row})
    return response_success("Cover buku berhasil diunggah", _serialize_admin_book(row))


@pustaka_admin_bp.get("/kategori")
@admin_required
def admin_list_kategori():
    rows = list(mongo.db.kategori_buku.find().sort([("urutan", 1), ("nama", 1)]))
    return response_success("Berhasil mengambil kategori buku", [format_doc(row) for row in rows])


@pustaka_admin_bp.post("/kategori")
@admin_required
def admin_create_kategori():
    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    if not nama:
        return response_error("Nama kategori wajib diisi", 400)
    slug = (payload.get("slug") or "").strip()
    
    kategori = {
        "nama": nama,
        "slug": _ensure_unique_category_slug(slug or nama),
        "urutan": _to_int(payload.get("urutan"), 0, min_value=0, max_value=9999),
        "is_active": _to_bool(payload.get("is_active")) if _to_bool(payload.get("is_active")) is not None else True,
    }
    res = mongo.db.kategori_buku.insert_one(kategori)
    kategori["_id"] = res.inserted_id
    
    return response_success("Kategori buku berhasil dibuat", format_doc(kategori), 201)


@pustaka_admin_bp.put("/kategori/<string:kategori_id>")
@admin_required
def admin_update_kategori(kategori_id: str):
    try:
        kategori = mongo.db.kategori_buku.find_one({"_id": ObjectId(kategori_id)})
    except Exception:
        return response_error("Kategori tidak valid", 400)
    if not kategori:
        return response_error("Kategori tidak ditemukan", 404)

    payload = request.get_json() or {}
    if "nama" in payload:
        nama = (payload.get("nama") or "").strip()
        if not nama:
            return response_error("Nama kategori wajib diisi", 400)
        kategori["nama"] = nama
        
    if "slug" in payload or "nama" in payload:
        raw_slug = (payload.get("slug") or kategori.get("nama") or "").strip()
        kategori["slug"] = _ensure_unique_category_slug(raw_slug, ignore_id=str(kategori["_id"]))
        
    if "urutan" in payload:
        kategori["urutan"] = _to_int(payload.get("urutan"), kategori.get("urutan") or 0, min_value=0, max_value=9999)
        
    if "is_active" in payload:
        parsed = _to_bool(payload.get("is_active"))
        if parsed is None:
            return response_error("is_active tidak valid", 400)
        kategori["is_active"] = parsed
        
    kategori["updated_at"] = _now_utc()
    mongo.db.kategori_buku.update_one({"_id": kategori["_id"]}, {"$set": kategori})
    
    return response_success("Kategori buku berhasil diubah", format_doc(kategori))


@pustaka_admin_bp.delete("/kategori/<string:kategori_id>")
@admin_required
def admin_delete_kategori(kategori_id: str):
    try:
        kategori = mongo.db.kategori_buku.find_one({"_id": ObjectId(kategori_id)})
    except Exception:
        return response_error("Kategori tidak valid", 400)
    if not kategori:
        return response_error("Kategori tidak ditemukan", 404)

    hard = _to_bool(request.args.get("hard")) is True
    
    if hard:
         if mongo.db.buku.count_documents({"kategori_id": kategori["_id"]}) > 0:
              return response_error("Kategori masih dipakai buku", 400)
         mongo.db.kategori_buku.delete_one({"_id": kategori["_id"]})
    else:
         kategori["is_active"] = False
         kategori["updated_at"] = _now_utc()
         mongo.db.kategori_buku.update_one({"_id": kategori["_id"]}, {"$set": kategori})
         
    return response_success("Kategori buku berhasil dihapus", None)
