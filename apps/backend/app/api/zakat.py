from flask import Blueprint, current_app
from flask_jwt_extended import jwt_required

from app.models import Portofolio

from .common import current_user_id, response_success

zakat_bp = Blueprint("zakat_api", __name__, url_prefix="/api/zakat")


@zakat_bp.get("/hitung")
@jwt_required()
def hitung_zakat():
    user_id = current_user_id()
    rows = Portofolio.query.filter_by(user_id=user_id).all()

    total_aset = sum(row.jumlah * row.harga_beli for row in rows)
    nilai_zakat = total_aset * 0.025
    nishab = current_app.config["NISHAB_DUMMY"]

    return response_success(
        "Berhasil menghitung zakat",
        {
            "total_aset": round(total_aset, 2),
            "nishab": nishab,
            "wajib_zakat": total_aset >= nishab,
            "nilai_zakat": round(nilai_zakat, 2),
        },
    )


@zakat_bp.get("/nishab")
@jwt_required()
def get_nishab():
    return response_success(
        "Berhasil mengambil nilai nishab",
        {"nishab": current_app.config["NISHAB_DUMMY"]},
    )
