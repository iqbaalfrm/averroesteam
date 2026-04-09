from datetime import datetime
from bson import ObjectId
from flask import Blueprint, request

from app.extensions import mongo
from .common import auth_required, current_user_id, response_error, response_success, format_doc

diskusi_bp = Blueprint("diskusi_api", __name__, url_prefix="/api/diskusi")


def _get_thread_replies(thread_id):
    rows = list(mongo.db.diskusi.find({"parent_id": thread_id}).sort("created_at", 1))
    return rows


def _serialize_thread(row, include_replies=False):
    item = format_doc(row, "parent_id")
    if include_replies:
        replies = _get_thread_replies(row["_id"])
        item["balasan"] = [format_doc(r, "parent_id") for r in replies]
        item["reply_count"] = len(replies)
    else:
        # Optimalkan: gunakan aggregate jika perlu 1 query besar, atau $lookup.
        # Untuk mockup count:
        item["reply_count"] = mongo.db.diskusi.count_documents({"parent_id": row["_id"]})
    return item


@diskusi_bp.get("")
@auth_required(optional=True)
def list_diskusi():
    q = (request.args.get("q") or "").strip()
    sort = (request.args.get("sort") or "terbaru").strip().lower()
    page = max(int(request.args.get("page", 1) or 1), 1)
    per_page = min(max(int(request.args.get("per_page", 20) or 20), 1), 50)
    skip = (page - 1) * per_page

    pipeline = [
        {"$match": {"parent_id": None}}
    ]

    if q:
        import re
        regex = re.compile(re.escape(q), re.IGNORECASE)
        pipeline[0]["$match"]["$or"] = [
            {"judul": regex},
            {"isi": regex}
        ]

    # Join replies count
    pipeline.extend([
        {
            "$lookup": {
                "from": "diskusi",
                "localField": "_id",
                "foreignField": "parent_id",
                "as": "replies"
            }
        },
        {
            "$addFields": {
                "reply_count": {"$size": "$replies"}
            }
        }
    ])

    if sort == "terpopuler":
        pipeline.append({"$sort": {"reply_count": -1, "created_at": -1}})
    else:
        pipeline.append({"$sort": {"created_at": -1}})

    # Pagination metadata
    count_pipeline = pipeline.copy()
    count_pipeline.append({"$count": "total"})
    
    total_res = list(mongo.db.diskusi.aggregate(count_pipeline))
    total = total_res[0]["total"] if total_res else 0

    pipeline.append({"$skip": skip})
    pipeline.append({"$limit": per_page})
    
    rows = list(mongo.db.diskusi.aggregate(pipeline))
    
    items = []
    for r in rows:
        r.pop("replies", None)
        item_dict = format_doc(r)
        items.append(item_dict)

    import math
    return response_success(
        "Berhasil mengambil data diskusi",
        {
            "items": items,
            "pagination": {
                "page": page,
                "per_page": per_page,
                "total": total,
                "total_pages": math.ceil(total / per_page) if total > 0 else 0,
            },
        },
    )


@diskusi_bp.get("/<string:diskusi_id>")
@auth_required(optional=True)
def detail_diskusi(diskusi_id):
    try:
        row = mongo.db.diskusi.find_one({"_id": ObjectId(diskusi_id), "parent_id": None})
    except Exception:
        return response_error("Thread diskusi tidak valid", 400)
        
    if not row:
        return response_error("Thread diskusi tidak ditemukan", 404)
        
    return response_success("Berhasil mengambil detail diskusi", _serialize_thread(row, include_replies=True))


@diskusi_bp.post("")
@auth_required()
def post_diskusi():
    user_id = current_user_id()
    payload = request.get_json() or {}
    isi = (payload.get("isi") or "").strip()

    if not isi:
        return response_error("Isi diskusi wajib diisi", 400)
    if len(isi) < 3:
        return response_error("Isi diskusi terlalu pendek", 400)

    now = datetime.utcnow()
    row = {
        "user_id": user_id,
        "judul": (payload.get("judul") or "Diskusi Baru").strip(),
        "isi": isi,
        "parent_id": None,
        "created_at": now,
        "updated_at": now
    }
    result = mongo.db.diskusi.insert_one(row)
    row["_id"] = result.inserted_id
    
    return response_success("Diskusi berhasil dibuat", _serialize_thread(row), 201)


@diskusi_bp.post("/<string:diskusi_id>/balas")
@auth_required()
def balas_diskusi(diskusi_id):
    user_id = current_user_id()
    payload = request.get_json() or {}
    isi = (payload.get("isi") or "").strip()

    try:
        parent = mongo.db.diskusi.find_one({"_id": ObjectId(diskusi_id)})
    except Exception:
        return response_error("Diskusi induk tidak valid", 400)
        
    if not parent:
        return response_error("Diskusi induk tidak ditemukan", 404)
    if parent.get("parent_id") is not None:
        return response_error("Balasan hanya bisa ke thread utama", 400)
    if not isi:
        return response_error("Isi balasan wajib diisi", 400)
    if len(isi) < 2:
        return response_error("Isi balasan terlalu pendek", 400)

    now = datetime.utcnow()
    row = {
        "user_id": user_id,
        "parent_id": parent["_id"],
        "isi": isi,
        "created_at": now,
        "updated_at": now
    }
    result = mongo.db.diskusi.insert_one(row)
    row["_id"] = result.inserted_id
    
    return response_success("Balasan berhasil dikirim", format_doc(row), 201)
