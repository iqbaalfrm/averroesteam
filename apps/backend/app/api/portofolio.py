import json
import urllib.parse
import urllib.request

from flask import Blueprint, request
from flask_jwt_extended import jwt_required

from app.extensions import db
from app.models import Portofolio, PortofolioRiwayat

from .common import current_user_id, response_error, response_success

portofolio_bp = Blueprint("portofolio_api", __name__, url_prefix="/api/portofolio")


def _log_riwayat(*, user_id: int, aksi: str, row: Portofolio):
    entry = PortofolioRiwayat(
        user_id=user_id,
        portofolio_id=row.id,
        aksi=aksi,
        nama_aset=row.nama_aset,
        simbol=row.simbol,
        jumlah=float(row.jumlah),
        harga_beli=float(row.harga_beli),
        nilai=round(float(row.jumlah) * float(row.harga_beli), 2),
    )
    db.session.add(entry)


@portofolio_bp.get("")
@jwt_required()
def list_portofolio():
    user_id = current_user_id()
    rows = Portofolio.query.filter_by(user_id=user_id).order_by(Portofolio.id.desc()).all()
    data = [row.to_dict() for row in rows]
    total = round(sum(item["nilai"] for item in data), 2)
    return response_success("Berhasil mengambil portofolio", {"items": data, "total_nilai": total})


@portofolio_bp.get("/riwayat")
@jwt_required()
def list_riwayat_portofolio():
    user_id = current_user_id()
    rows = (
        PortofolioRiwayat.query.filter_by(user_id=user_id)
        .order_by(PortofolioRiwayat.created_at.desc(), PortofolioRiwayat.id.desc())
        .limit(100)
        .all()
    )
    return response_success("Berhasil mengambil riwayat portofolio", [row.to_dict() for row in rows])


@portofolio_bp.get("/crypto/search")
@jwt_required()
def search_crypto_coingecko():
    q = (request.args.get("q") or "").strip()
    if len(q) < 2:
        return response_success("Keyword terlalu pendek", [])

    try:
        search_url = (
            "https://api.coingecko.com/api/v3/search?"
            + urllib.parse.urlencode({"query": q})
        )
        with urllib.request.urlopen(search_url, timeout=10) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        coins = (payload or {}).get("coins") or []
        items = []
        for coin in coins[:10]:
            if not isinstance(coin, dict):
                continue
            items.append(
                {
                    "id": str(coin.get("id") or ""),
                    "nama": str(coin.get("name") or ""),
                    "simbol": str(coin.get("symbol") or "").upper(),
                    "thumb": str(coin.get("thumb") or ""),
                    "market_cap_rank": coin.get("market_cap_rank"),
                }
            )
        return response_success("Berhasil mencari koin", items)
    except Exception:
        return response_error("Gagal mencari koin dari CoinGecko", 502)


@portofolio_bp.post("")
@jwt_required()
def create_portofolio():
    user_id = current_user_id()
    payload = request.get_json() or {}

    required = ["nama_aset", "simbol", "jumlah", "harga_beli"]
    if any(payload.get(field) in [None, ""] for field in required):
        return response_error("Data aset belum lengkap", 400)

    row = Portofolio(
        user_id=user_id,
        nama_aset=payload["nama_aset"],
        simbol=payload["simbol"],
        jumlah=float(payload["jumlah"]),
        harga_beli=float(payload["harga_beli"]),
    )
    db.session.add(row)
    db.session.flush()
    _log_riwayat(user_id=user_id, aksi="create", row=row)
    db.session.commit()
    return response_success("Aset berhasil ditambahkan", row.to_dict(), 201)


@portofolio_bp.put("/<int:item_id>")
@jwt_required()
def update_portofolio(item_id):
    user_id = current_user_id()
    row = Portofolio.query.filter_by(id=item_id, user_id=user_id).first()
    if not row:
        return response_error("Data aset tidak ditemukan", 404)

    payload = request.get_json() or {}
    row.nama_aset = payload.get("nama_aset", row.nama_aset)
    row.simbol = payload.get("simbol", row.simbol)
    row.jumlah = float(payload.get("jumlah", row.jumlah))
    row.harga_beli = float(payload.get("harga_beli", row.harga_beli))
    _log_riwayat(user_id=user_id, aksi="update", row=row)

    db.session.commit()
    return response_success("Aset berhasil diubah", row.to_dict())


@portofolio_bp.delete("/<int:item_id>")
@jwt_required()
def delete_portofolio(item_id):
    user_id = current_user_id()
    row = Portofolio.query.filter_by(id=item_id, user_id=user_id).first()
    if not row:
        return response_error("Data aset tidak ditemukan", 404)

    _log_riwayat(user_id=user_id, aksi="delete", row=row)
    db.session.delete(row)
    db.session.commit()
    return response_success("Aset berhasil dihapus", {"id": item_id})
