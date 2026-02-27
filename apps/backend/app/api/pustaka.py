from __future__ import annotations

import math
import os
import re
from datetime import datetime

from flask import Blueprint, current_app, request, url_for
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
from sqlalchemy import or_

from app.extensions import db
from app.models import Buku, KategoriBuku
from app.services.storage import (
    make_signed_file_token,
    parse_signed_file_token,
    save_upload,
    send_local_object,
)

from .common import admin_required, response_error, response_success

pustaka_bp = Blueprint("pustaka_api", __name__, url_prefix="/api/buku")
pustaka_admin_bp = Blueprint("pustaka_admin_api", __name__, url_prefix="/api/admin/buku")


def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (text or "").strip().lower()).strip("-")
    return slug or "buku"


def _ensure_unique_book_slug(base_text: str, ignore_id: int | None = None) -> str:
    base = _slugify(base_text)
    slug = base
    i = 2
    while True:
        q = Buku.query.filter(Buku.slug == slug)
        if ignore_id is not None:
            q = q.filter(Buku.id != ignore_id)
        if q.first() is None:
            return slug
        slug = f"{base}-{i}"
        i += 1


def _ensure_unique_category_slug(base_text: str, ignore_id: int | None = None) -> str:
    base = _slugify(base_text)
    slug = base
    i = 2
    while True:
        q = KategoriBuku.query.filter(KategoriBuku.slug == slug)
        if ignore_id is not None:
            q = q.filter(KategoriBuku.id != ignore_id)
        if q.first() is None:
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


def _cover_url_for_book(b: Buku) -> str | None:
    if not b.cover_key:
        return None
    return url_for("pustaka_api.cover_buku", buku_id=b.id, _external=True)


def _serialize_public_book(b: Buku) -> dict:
    payload = b.to_public_dict()
    payload["cover_url"] = _cover_url_for_book(b)
    payload["can_download"] = bool(b.active_file_key())
    return payload


def _serialize_admin_book(b: Buku) -> dict:
    payload = b.to_dict()
    payload["cover_url"] = _cover_url_for_book(b)
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
                data["kategori_id"] = int(kategori_id)
            except (TypeError, ValueError):
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


def _apply_publish_state(buku: Buku) -> tuple[bool, str | None]:
    if (buku.status or "").lower() != "published":
        return True, None
    if not (buku.active_file_key() or buku.has_drive_file()):
        return False, "Buku belum memiliki file ebook atau Drive file ID"
    if not buku.slug:
        buku.slug = _ensure_unique_book_slug(buku.judul or "buku", ignore_id=buku.id)
    if not buku.published_at:
        buku.published_at = _now_utc()
    return True, None


def _book_query_public():
    return Buku.query.filter(Buku.status == "published")


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
    kategori_id = request.args.get("kategori_id", type=int)
    kategori_slug = (request.args.get("kategori_slug") or "").strip().lower()
    format_file = (request.args.get("format") or "").strip().lower()
    featured = _to_bool(request.args.get("featured"))
    sort = (request.args.get("sort") or "terbaru").strip().lower()

    query = _book_query_public().outerjoin(KategoriBuku)
    if q:
        like = f"%{q}%"
        query = query.filter(or_(Buku.judul.ilike(like), Buku.penulis.ilike(like), Buku.deskripsi.ilike(like)))
    if kategori_id:
        query = query.filter(Buku.kategori_id == kategori_id)
    if kategori_slug:
        query = query.filter(KategoriBuku.slug == kategori_slug)
    if format_file in {"pdf", "epub"}:
        query = query.filter(Buku.format_file == format_file)
    if featured is not None:
        query = query.filter(Buku.is_featured.is_(featured))

    if sort == "judul":
        query = query.order_by(Buku.judul.asc(), Buku.id.desc())
    else:
        query = query.order_by(Buku.published_at.desc().nullslast(), Buku.created_at.desc(), Buku.id.desc())

    total = query.count()
    rows = query.offset((page - 1) * per_page).limit(per_page).all()
    data = {
        "items": [_serialize_public_book(row) for row in rows],
        "pagination": _build_pagination_payload(page=page, per_page=per_page, total=total),
        "filters": {
            "q": q,
            "kategori_id": kategori_id,
            "kategori_slug": kategori_slug or None,
            "format": format_file or None,
            "featured": featured,
            "sort": sort,
        },
    }
    return response_success("Berhasil mengambil data buku", data)


@pustaka_bp.get("/kategori")
def list_kategori_buku():
    rows = (
        KategoriBuku.query.filter(KategoriBuku.is_active.is_(True))
        .order_by(KategoriBuku.urutan.asc(), KategoriBuku.nama.asc())
        .all()
    )
    return response_success("Berhasil mengambil kategori buku", [row.to_dict() for row in rows])


@pustaka_bp.get("/slug/<string:slug>")
def detail_buku_slug(slug: str):
    row = _book_query_public().filter(Buku.slug == slug).first()
    if not row:
        return response_error("Buku tidak ditemukan", 404)
    return response_success("Berhasil mengambil detail buku", _serialize_public_book(row))


@pustaka_bp.get("/<int:buku_id>")
def detail_buku(buku_id: int):
    row = _book_query_public().filter(Buku.id == buku_id).first()
    if not row:
        return response_error("Buku tidak ditemukan", 404)
    return response_success("Berhasil mengambil detail buku", _serialize_public_book(row))


@pustaka_bp.get("/<int:buku_id>/cover")
def cover_buku(buku_id: int):
    row = _book_query_public().filter(Buku.id == buku_id).first()
    if not row or not row.cover_key:
        return response_error("Cover tidak ditemukan", 404)
    try:
        return send_local_object(
            row.cover_key,
            download_name=os.path.basename(row.cover_key),
            as_attachment=False,
        )
    except FileNotFoundError:
        return response_error("Cover tidak ditemukan", 404)


@pustaka_bp.post("/<int:buku_id>/access")
def access_buku(buku_id: int):
    row = _book_query_public().filter(Buku.id == buku_id).first()
    if not row:
        return response_error("Buku tidak ditemukan", 404)
    action = (request.get_json(silent=True) or {}).get("action") or "read"
    action = str(action).strip().lower()
    if action not in {"read", "download"}:
        action = "read"

    if row.has_drive_file():
        drive_id = (row.drive_file_id or "").strip()
        # Preview for in-app reading, direct download for external save.
        if action == "read":
            url = f"https://drive.google.com/file/d/{drive_id}/preview"
        else:
            url = f"https://drive.google.com/uc?export=download&id={drive_id}"
        expires = int(current_app.config.get("PUSTAKA_SIGNED_URL_EXPIRES_SECONDS", 600))
        return response_success(
            "URL akses buku berhasil dibuat",
            {"url": url, "expires_in": expires, "filename": row.file_nama or row.judul},
        )

    file_key = row.active_file_key()
    if not file_key:
        return response_error("File buku tidak tersedia", 400)

    verify_jwt_in_request(optional=True)
    user_id = get_jwt_identity()
    if row.akses in {"premium", "internal"} and not user_id:
        return response_error("Login diperlukan untuk mengakses buku ini", 401)

    token = make_signed_file_token(
        buku_id=row.id,
        file_key=file_key,
        filename=row.file_nama or os.path.basename(file_key),
    )
    signed_url = url_for("pustaka_api.download_signed_file", token=token, _external=True)
    expires = int(current_app.config.get("PUSTAKA_SIGNED_URL_EXPIRES_SECONDS", 600))
    return response_success(
        "URL akses buku berhasil dibuat",
        {"url": signed_url, "expires_in": expires, "filename": row.file_nama or os.path.basename(file_key)},
    )


@pustaka_bp.get("/file/<string:token>")
def download_signed_file(token: str):
    try:
        payload = parse_signed_file_token(token)
    except PermissionError as exc:
        return response_error(str(exc), 403)
    buku_id = int(payload.get("buku_id") or 0)
    file_key = (payload.get("file_key") or "").strip()
    filename = (payload.get("filename") or "").strip()
    row = _book_query_public().filter(Buku.id == buku_id).first()
    if not row or row.active_file_key() != file_key:
        return response_error("Akses file tidak valid", 403)
    try:
        return send_local_object(file_key, download_name=filename or row.file_nama or os.path.basename(file_key))
    except FileNotFoundError:
        return response_error("File tidak ditemukan", 404)


@pustaka_admin_bp.get("")
@admin_required
def admin_list_buku():
    page = _to_int(request.args.get("page"), 1, min_value=1)
    per_page = _to_int(request.args.get("per_page"), 20, min_value=1, max_value=100)
    q = (request.args.get("q") or "").strip()
    status = (request.args.get("status") or "").strip().lower()
    kategori_id = request.args.get("kategori_id", type=int)

    query = Buku.query.outerjoin(KategoriBuku)
    if q:
        like = f"%{q}%"
        query = query.filter(or_(Buku.judul.ilike(like), Buku.penulis.ilike(like), Buku.deskripsi.ilike(like)))
    if status in {"draft", "published", "archived"}:
        query = query.filter(Buku.status == status)
    if kategori_id:
        query = query.filter(Buku.kategori_id == kategori_id)

    query = query.order_by(Buku.updated_at.desc().nullslast(), Buku.id.desc())
    total = query.count()
    rows = query.offset((page - 1) * per_page).limit(per_page).all()
    return response_success(
        "Berhasil mengambil data buku admin",
        {"items": [_serialize_admin_book(row) for row in rows], "pagination": _build_pagination_payload(page=page, per_page=per_page, total=total)},
    )


@pustaka_admin_bp.post("")
@admin_required
def admin_create_buku():
    payload = request.get_json() or {}
    data, err = _validate_book_payload(payload, is_update=False)
    if err:
        return response_error(err, 400)
    if data.get("kategori_id") and not KategoriBuku.query.get(data["kategori_id"]):
        return response_error("Kategori tidak ditemukan", 404)

    now = _now_utc()
    user_id = get_jwt_identity()
    buku = Buku(
        judul=data["judul"],
        penulis=data["penulis"],
        deskripsi=data["deskripsi"],
        slug=data.get("slug") or _ensure_unique_book_slug(data["judul"]),
        kategori_id=data.get("kategori_id"),
        status=data.get("status") or "draft",
        akses=data.get("akses") or "gratis",
        bahasa=data.get("bahasa") or "id",
        is_featured=bool(data.get("is_featured", False)),
        format_file=data.get("format_file") or None,
        created_at=now,
        updated_at=now,
        created_by=int(user_id) if user_id else None,
        updated_by=int(user_id) if user_id else None,
    )
    ok, publish_err = _apply_publish_state(buku)
    if not ok:
        return response_error(publish_err or "Data buku tidak valid", 400)

    db.session.add(buku)
    db.session.commit()
    return response_success("Buku berhasil dibuat", _serialize_admin_book(buku), 201)


@pustaka_admin_bp.get("/<int:buku_id>")
@admin_required
def admin_detail_buku(buku_id: int):
    row = Buku.query.get_or_404(buku_id)
    return response_success("Berhasil mengambil detail buku", _serialize_admin_book(row))


@pustaka_admin_bp.put("/<int:buku_id>")
@admin_required
def admin_update_buku(buku_id: int):
    row = Buku.query.get_or_404(buku_id)
    payload = request.get_json() or {}
    data, err = _validate_book_payload(payload, is_update=True)
    if err:
        return response_error(err, 400)
    if "kategori_id" in data and data["kategori_id"] and not KategoriBuku.query.get(data["kategori_id"]):
        return response_error("Kategori tidak ditemukan", 404)

    for key, value in data.items():
        if key == "slug":
            setattr(row, key, value or _ensure_unique_book_slug(row.judul, ignore_id=row.id))
            continue
        setattr(row, key, value)

    if "judul" in data and ("slug" not in data or not data.get("slug")) and not row.slug:
        row.slug = _ensure_unique_book_slug(row.judul, ignore_id=row.id)
    user_id = get_jwt_identity()
    row.updated_by = int(user_id) if user_id else row.updated_by
    row.updated_at = _now_utc()
    ok, publish_err = _apply_publish_state(row)
    if not ok:
        db.session.rollback()
        return response_error(publish_err or "Data buku tidak valid", 400)

    db.session.commit()
    return response_success("Buku berhasil diubah", _serialize_admin_book(row))


@pustaka_admin_bp.patch("/<int:buku_id>/status")
@admin_required
def admin_update_status_buku(buku_id: int):
    row = Buku.query.get_or_404(buku_id)
    payload = request.get_json() or {}
    status = (payload.get("status") or "").strip().lower()
    if status not in {"draft", "published", "archived"}:
        return response_error("Status tidak valid", 400)
    row.status = status
    user_id = get_jwt_identity()
    row.updated_by = int(user_id) if user_id else row.updated_by
    row.updated_at = _now_utc()
    if status != "published":
        if status == "draft":
            row.published_at = None
    ok, publish_err = _apply_publish_state(row)
    if not ok:
        db.session.rollback()
        return response_error(publish_err or "Data buku tidak valid", 400)
    db.session.commit()
    return response_success("Status buku berhasil diubah", _serialize_admin_book(row))


@pustaka_admin_bp.delete("/<int:buku_id>")
@admin_required
def admin_delete_buku(buku_id: int):
    row = Buku.query.get_or_404(buku_id)
    hard = _to_bool(request.args.get("hard")) is True
    if hard:
        db.session.delete(row)
        db.session.commit()
        return response_success("Buku berhasil dihapus permanen", None)
    row.status = "archived"
    row.updated_at = _now_utc()
    user_id = get_jwt_identity()
    row.updated_by = int(user_id) if user_id else row.updated_by
    db.session.commit()
    return response_success("Buku berhasil diarsipkan", _serialize_admin_book(row))


@pustaka_admin_bp.post("/<int:buku_id>/upload-file")
@admin_required
def admin_upload_buku_file(buku_id: int):
    row = Buku.query.get_or_404(buku_id)
    file_obj = request.files.get("file")
    if not file_obj or not file_obj.filename:
        return response_error("File ebook wajib diunggah", 400)
    try:
        stored = save_upload(file_obj, subdir="pustaka/ebook", allowed_exts={".pdf", ".epub"})
    except ValueError as exc:
        return response_error(str(exc), 400)

    ext = os.path.splitext(stored.filename)[1].lower()
    row.file_key = stored.key
    row.file_nama = stored.filename
    row.ukuran_file_bytes = stored.size_bytes
    row.storage_provider = "local"
    row.format_file = "epub" if ext == ".epub" else "pdf"
    if row.format_file == "pdf":
        row.file_pdf = stored.key
    row.updated_at = _now_utc()
    user_id = get_jwt_identity()
    row.updated_by = int(user_id) if user_id else row.updated_by
    ok, publish_err = _apply_publish_state(row)
    if not ok:
        db.session.rollback()
        return response_error(publish_err or "File berhasil diunggah tetapi status buku tidak valid", 400)
    db.session.commit()
    return response_success("File buku berhasil diunggah", _serialize_admin_book(row))


@pustaka_admin_bp.post("/<int:buku_id>/upload-cover")
@admin_required
def admin_upload_buku_cover(buku_id: int):
    row = Buku.query.get_or_404(buku_id)
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

    row.cover_key = stored.key
    row.updated_at = _now_utc()
    user_id = get_jwt_identity()
    row.updated_by = int(user_id) if user_id else row.updated_by
    db.session.commit()
    return response_success("Cover buku berhasil diunggah", _serialize_admin_book(row))


@pustaka_admin_bp.get("/kategori")
@admin_required
def admin_list_kategori():
    rows = KategoriBuku.query.order_by(KategoriBuku.urutan.asc(), KategoriBuku.nama.asc()).all()
    return response_success("Berhasil mengambil kategori buku", [row.to_dict() for row in rows])


@pustaka_admin_bp.post("/kategori")
@admin_required
def admin_create_kategori():
    payload = request.get_json() or {}
    nama = (payload.get("nama") or "").strip()
    if not nama:
        return response_error("Nama kategori wajib diisi", 400)
    slug = (payload.get("slug") or "").strip()
    kategori = KategoriBuku(
        nama=nama,
        slug=_ensure_unique_category_slug(slug or nama),
        urutan=_to_int(payload.get("urutan"), 0, min_value=0, max_value=9999),
        is_active=_to_bool(payload.get("is_active")) if _to_bool(payload.get("is_active")) is not None else True,
    )
    db.session.add(kategori)
    db.session.commit()
    return response_success("Kategori buku berhasil dibuat", kategori.to_dict(), 201)


@pustaka_admin_bp.put("/kategori/<int:kategori_id>")
@admin_required
def admin_update_kategori(kategori_id: int):
    kategori = KategoriBuku.query.get_or_404(kategori_id)
    payload = request.get_json() or {}
    if "nama" in payload:
        nama = (payload.get("nama") or "").strip()
        if not nama:
            return response_error("Nama kategori wajib diisi", 400)
        kategori.nama = nama
    if "slug" in payload or "nama" in payload:
        raw_slug = (payload.get("slug") or kategori.nama or "").strip()
        kategori.slug = _ensure_unique_category_slug(raw_slug, ignore_id=kategori.id)
    if "urutan" in payload:
        kategori.urutan = _to_int(payload.get("urutan"), kategori.urutan or 0, min_value=0, max_value=9999)
    if "is_active" in payload:
        parsed = _to_bool(payload.get("is_active"))
        if parsed is None:
            return response_error("is_active tidak valid", 400)
        kategori.is_active = parsed
    kategori.updated_at = _now_utc()
    db.session.commit()
    return response_success("Kategori buku berhasil diubah", kategori.to_dict())


@pustaka_admin_bp.delete("/kategori/<int:kategori_id>")
@admin_required
def admin_delete_kategori(kategori_id: int):
    kategori = KategoriBuku.query.get_or_404(kategori_id)
    hard = _to_bool(request.args.get("hard")) is True
    if kategori.buku.count() > 0 and hard:
        return response_error("Kategori masih dipakai buku", 400)
    if hard:
        db.session.delete(kategori)
    else:
        kategori.is_active = False
        kategori.updated_at = _now_utc()
    db.session.commit()
    return response_success("Kategori buku berhasil dihapus", None)
