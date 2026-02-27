from flask import Blueprint, request
from flask_jwt_extended import jwt_required
from sqlalchemy import func

from app.extensions import db
from app.models import Diskusi

from .common import current_user_id, response_error, response_success


diskusi_bp = Blueprint("diskusi_api", __name__, url_prefix="/api/diskusi")


def _serialize_thread(row: Diskusi, *, include_replies: bool = False):
    item = row.to_dict()
    replies = sorted(list(row.balasan), key=lambda x: (x.created_at or 0, x.id or 0))
    item["reply_count"] = len(replies)
    if include_replies:
        item["balasan"] = [balas.to_dict() for balas in replies]
    return item


@diskusi_bp.get("")
@jwt_required()
def list_diskusi():
    q = (request.args.get("q") or "").strip()
    sort = (request.args.get("sort") or "terbaru").strip().lower()
    page = max(int(request.args.get("page", 1) or 1), 1)
    per_page = min(max(int(request.args.get("per_page", 20) or 20), 1), 50)

    replies_count_subq = (
        db.session.query(
            Diskusi.parent_id.label("thread_id"),
            func.count(Diskusi.id).label("reply_count"),
        )
        .filter(Diskusi.parent_id.is_not(None))
        .group_by(Diskusi.parent_id)
        .subquery()
    )

    query = (
        Diskusi.query.filter(Diskusi.parent_id.is_(None))
        .outerjoin(replies_count_subq, replies_count_subq.c.thread_id == Diskusi.id)
    )
    if q:
        like = f"%{q}%"
        query = query.filter((Diskusi.judul.ilike(like)) | (Diskusi.isi.ilike(like)))

    if sort == "terpopuler":
        query = query.order_by(
            func.coalesce(replies_count_subq.c.reply_count, 0).desc(),
            Diskusi.created_at.desc(),
        )
    else:
        query = query.order_by(Diskusi.created_at.desc())

    pagination = query.paginate(page=page, per_page=per_page, error_out=False)
    items = [_serialize_thread(row) for row in pagination.items]
    return response_success(
        "Berhasil mengambil data diskusi",
        {
            "items": items,
            "pagination": {
                "page": pagination.page,
                "per_page": pagination.per_page,
                "total": pagination.total,
                "total_pages": pagination.pages,
            },
        },
    )


@diskusi_bp.get("/<int:diskusi_id>")
@jwt_required()
def detail_diskusi(diskusi_id):
    row = Diskusi.query.get(diskusi_id)
    if not row or row.parent_id is not None:
        return response_error("Thread diskusi tidak ditemukan", 404)
    return response_success("Berhasil mengambil detail diskusi", _serialize_thread(row, include_replies=True))


@diskusi_bp.post("")
@jwt_required()
def post_diskusi():
    user_id = current_user_id()
    payload = request.get_json() or {}
    isi = (payload.get("isi") or "").strip()

    if not isi:
        return response_error("Isi diskusi wajib diisi", 400)
    if len(isi) < 3:
        return response_error("Isi diskusi terlalu pendek", 400)

    row = Diskusi(
        user_id=user_id,
        judul=(payload.get("judul") or "Diskusi Baru").strip(),
        isi=isi,
    )
    db.session.add(row)
    db.session.commit()
    return response_success("Diskusi berhasil dibuat", _serialize_thread(row), 201)


@diskusi_bp.post("/<int:diskusi_id>/balas")
@jwt_required()
def balas_diskusi(diskusi_id):
    user_id = current_user_id()
    payload = request.get_json() or {}
    isi = (payload.get("isi") or "").strip()

    parent = Diskusi.query.get(diskusi_id)
    if not parent:
        return response_error("Diskusi induk tidak ditemukan", 404)
    if parent.parent_id is not None:
        return response_error("Balasan hanya bisa ke thread utama", 400)
    if not isi:
        return response_error("Isi balasan wajib diisi", 400)
    if len(isi) < 2:
        return response_error("Isi balasan terlalu pendek", 400)

    row = Diskusi(user_id=user_id, parent_id=parent.id, isi=isi)
    db.session.add(row)
    db.session.commit()
    return response_success("Balasan berhasil dikirim", row.to_dict(), 201)
