from flask import Blueprint, request

from app.models import Screener

from .common import response_success

screener_bp = Blueprint("screener_api", __name__, url_prefix="/api/screener")


@screener_bp.get("")
def list_screener():
    query = Screener.query

    q = (request.args.get("q") or "").strip()
    if q:
        keyword = f"%{q}%"
        query = query.filter(
            (Screener.nama_koin.ilike(keyword)) | (Screener.simbol.ilike(keyword))
        )

    status = (request.args.get("status") or "").strip().lower()
    if status in {"halal", "proses", "haram"}:
        query = query.filter(Screener.status == status)

    rows = query.order_by(Screener.nama_koin.asc()).all()
    return response_success("Berhasil mengambil data screener", [row.to_dict() for row in rows])


@screener_bp.get("/metodologi")
def metodologi():
    return response_success(
        "Berhasil mengambil metodologi screener",
        {
            "notice": "Status syariah bersifat edukatif berdasarkan kajian internal tim Averroes, bukan fatwa resmi.",
        },
    )
