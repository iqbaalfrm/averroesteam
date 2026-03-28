from flask import Blueprint, request

from app.extensions import mongo
from .common import format_doc, response_error, response_success

kajian_bp = Blueprint("kajian_api", __name__, url_prefix="/api/kajian")


_DEFAULT_KAJIAN = [
    {
        "id": "default-kajian-1",
        "judul": "BITCOIN DIHARAMKAN? Ustadz Devin: Banyak yang Salah Paham, Ini Alasan Crypto Tidak Haram dalam Islam",
        "deskripsi": (
            "Kajian sementara untuk membahas miskonsepsi umum seputar hukum Bitcoin "
            "dan aset kripto dalam perspektif syariah."
        ),
        "youtube_url": "https://youtu.be/ciamJjQ2ruU?si=XQI5CoGM2w7DZXjv",
        "channel": "kasisolusi",
        "kategori": "Kajian Crypto Syariah",
        "durasi_label": "Kajian",
        "urutan": 1,
        "is_active": True,
    },
    {
        "id": "default-kajian-2",
        "judul": "Bitcoin Zero Sum Game Jadi Haram?",
        "deskripsi": (
            "Kajian sementara untuk mengulas apakah Bitcoin termasuk zero sum game "
            "dan bagaimana cara memahami isu ini dengan lebih hati-hati."
        ),
        "youtube_url": "https://youtu.be/rU56XmYmKcg?si=p2cC1qxRj108DvNH",
        "channel": "Mudacumasekali",
        "kategori": "Kajian Crypto Syariah",
        "durasi_label": "Kajian",
        "urutan": 2,
        "is_active": True,
    },
    {
        "id": "default-kajian-3",
        "judul": "Bedah Halal Haram Crypto Aset bersama Ustadz Devin Halim Wijaya",
        "deskripsi": (
            "Kajian sementara yang berfokus pada pembahasan halal-haram crypto aset "
            "sebagai referensi awal sebelum user mendalami materi lebih lanjut."
        ),
        "youtube_url": "https://youtu.be/P4R19e7bowg?si=5lmtv3LFvDTt6MGA",
        "channel": "Wakaf Ilmu",
        "kategori": "Kajian Crypto Syariah",
        "durasi_label": "Kajian",
        "urutan": 3,
        "is_active": True,
    },
]


@kajian_bp.get("")
def list_kajian():
    limit = 20
    try:
        limit = min(max(int(request.args.get("limit") or 20), 1), 100)
    except (TypeError, ValueError):
        limit = 20

    filters = {"is_active": True}
    kategori = (request.args.get("kategori") or "").strip()
    if kategori:
        filters["kategori"] = kategori

    rows = list(
        mongo.db.kajian.find(filters).sort([("urutan", 1), ("created_at", -1)]).limit(limit)
    )
    data = [format_doc(row) for row in rows]
    if not data:
        data = _DEFAULT_KAJIAN[:limit]
    return response_success("Berhasil mengambil daftar kajian", data)


@kajian_bp.get("/<string:kajian_id>")
def detail_kajian(kajian_id: str):
    from bson import ObjectId

    try:
        row = mongo.db.kajian.find_one({"_id": ObjectId(kajian_id), "is_active": True})
    except Exception:
        row = None

    if not row:
        return response_error("Kajian tidak ditemukan", 404)

    return response_success("Berhasil mengambil detail kajian", format_doc(row))
