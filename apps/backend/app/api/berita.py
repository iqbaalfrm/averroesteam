import math
import re
from html import unescape

from flask import Blueprint, request
from bson import ObjectId

from app.extensions import mongo
from .common import response_success, format_doc, response_error

berita_bp = Blueprint("berita_api", __name__, url_prefix="/api/berita")


def _clean_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _is_noise_paragraph(text: str) -> bool:
    t = (text or "").strip()
    if len(t) < 30:
        return True
    patterns = [
        r"about help center",
        r"powered by news",
        r"\b[A-Z]{2,10}USDT\b",
        r"(?:\b[A-Z]{2,12}USDT\b.*?){2,}",
        r"dark mode",
        r"\bhelp center\b",
        r"\b(iklan|advert|copyright|komentar)\b",
        r"enter your email and we.?ll send you link to get back into your account",
    ]
    for p in patterns:
        if re.search(p, t, flags=re.IGNORECASE):
            return True
    return False


def _sanitize_text_output(text: str) -> str:
    t = _clean_text(text or "")
    return "" if _is_noise_paragraph(t) else t


def _normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", (text or "").strip().lower())


def _apply_news_preview(item: dict) -> dict:
    judul = str(item.get("judul") or "").strip()
    ringkasan = _sanitize_text_output(str(item.get("ringkasan") or ""))
    if ringkasan and _normalize_text(ringkasan) == _normalize_text(judul):
        ringkasan = ""
    item["ringkasan"] = ringkasan
    item.pop("konten", None)
    item.pop("konten_blocks", None)
    return item


@berita_bp.get("/terbaru")
def berita_terbaru():
    rows = list(mongo.db.berita.find().sort("published_at", -1).limit(5))
    items = [_apply_news_preview(format_doc(row)) for row in rows]
    return response_success("Berhasil mengambil berita terbaru", items)


@berita_bp.get("")
def berita_semua():
    page = request.args.get("page", 1, type=int)
    per_page = request.args.get("per_page", type=int)
    limit = request.args.get("limit", type=int)
    if per_page is None and limit is not None:
        per_page = limit
    if per_page is None:
        per_page = 20
    per_page = max(1, min(per_page, 50))
    
    skip = (page - 1) * per_page
    cursor = mongo.db.berita.find().sort("published_at", -1)
    
    total = mongo.db.berita.count_documents({})
    rows = list(cursor.skip(skip).limit(per_page))
    pages = math.ceil(total / per_page) if total > 0 else 0

    items = [format_doc(row) for row in rows]
    for item in items:
        _apply_news_preview(item)

    data = {
        "items": items,
        "page": page,
        "per_page": per_page,
        "total": total,
        "pages": pages,
    }
    return response_success("Berhasil mengambil semua berita", data)


@berita_bp.get("/<string:berita_id>")
def detail_berita(berita_id: str):
    try:
        row = mongo.db.berita.find_one({"_id": ObjectId(berita_id)})
    except Exception:
        return response_error("ID berita tidak valid", 400)
    if not row:
        return response_error("Berita tidak ditemukan", 404)
    payload = format_doc(row)
    _apply_news_preview(payload)
    return response_success("Berhasil mengambil detail berita", payload)
