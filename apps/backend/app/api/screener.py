from flask import Blueprint

from app.models import Screener

from .common import response_success

screener_bp = Blueprint("screener_api", __name__, url_prefix="/api/screener")


@screener_bp.get("")
def list_screener():
    rows = Screener.query.order_by(Screener.nama_koin.asc()).all()
    return response_success("Berhasil mengambil data screener", [row.to_dict() for row in rows])


@screener_bp.get("/metodologi")
def metodologi():
    return response_success(
        "Berhasil mengambil metodologi screener",
        {
            "notice": "Status syariah bersifat edukatif berdasarkan kajian internal tim Averroes, bukan fatwa resmi.",
        },
    )
