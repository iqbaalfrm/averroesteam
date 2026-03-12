import json
import urllib.parse
import urllib.request
from datetime import datetime
from bson import ObjectId

from flask import Blueprint, request
from flask_jwt_extended import jwt_required

from app.extensions import mongo
from .common import current_user_id, response_error, response_success, format_doc

portofolio_bp = Blueprint("portofolio_api", __name__, url_prefix="/api/portofolio")


def _log_riwayat(*, user_id: str, aksi: str, row: dict):
    now = datetime.utcnow()
    entry = {
        "user_id": user_id,
        "portofolio_id": row["_id"],
        "aksi": aksi,
        "nama_aset": row["nama_aset"],
        "simbol": row["simbol"],
        "jumlah": float(row["jumlah"]),
        "harga_beli": float(row["harga_beli"]),
        "nilai": round(float(row["jumlah"]) * float(row["harga_beli"]), 2),
        "created_at": now,
    }
    mongo.db.portofolio_riwayat.insert_one(entry)


@portofolio_bp.get("")
@jwt_required()
def list_portofolio():
    user_id = current_user_id()
    rows = list(mongo.db.portofolio.find({"user_id": user_id}).sort("_id", -1))
    
    data = []
    total = 0.0
    for row in rows:
        d = format_doc(row)
        d["nilai"] = round(d["jumlah"] * d["harga_beli"], 2)
        total += d["nilai"]
        data.append(d)
        
    return response_success("Berhasil mengambil portofolio", {"items": data, "total_nilai": round(total, 2)})


@portofolio_bp.get("/riwayat")
@jwt_required()
def list_riwayat_portofolio():
    user_id = current_user_id()
    rows = list(mongo.db.portofolio_riwayat.find({"user_id": user_id}).sort([("created_at", -1), ("_id", -1)]).limit(100))
    return response_success("Berhasil mengambil riwayat portofolio", [format_doc(row) for row in rows])


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

    now = datetime.utcnow()
    row = {
        "user_id": user_id,
        "nama_aset": payload["nama_aset"],
        "simbol": payload["simbol"],
        "jumlah": float(payload["jumlah"]),
        "harga_beli": float(payload["harga_beli"]),
        "created_at": now,
        "updated_at": now
    }
    result = mongo.db.portofolio.insert_one(row)
    row["_id"] = result.inserted_id
    
    _log_riwayat(user_id=user_id, aksi="create", row=row)
    
    response_item = format_doc(row)
    response_item["nilai"] = round(row["jumlah"] * row["harga_beli"], 2)
    return response_success("Aset berhasil ditambahkan", response_item, 201)


@portofolio_bp.put("/<string:item_id>")
@jwt_required()
def update_portofolio(item_id):
    user_id = current_user_id()
    try:
        row = mongo.db.portofolio.find_one({"_id": ObjectId(item_id), "user_id": user_id})
    except Exception:
        return response_error("Data aset tidak valid", 400)
        
    if not row:
        return response_error("Data aset tidak ditemukan", 404)

    payload = request.get_json() or {}
    
    update_data = {
        "nama_aset": payload.get("nama_aset", row.get("nama_aset")),
        "simbol": payload.get("simbol", row.get("simbol")),
        "jumlah": float(payload.get("jumlah", row.get("jumlah", 0))),
        "harga_beli": float(payload.get("harga_beli", row.get("harga_beli", 0))),
        "updated_at": datetime.utcnow()
    }
    
    mongo.db.portofolio.update_one({"_id": row["_id"]}, {"$set": update_data})
    row.update(update_data)
    
    _log_riwayat(user_id=user_id, aksi="update", row=row)

    response_item = format_doc(row)
    response_item["nilai"] = round(row["jumlah"] * row["harga_beli"], 2)
    return response_success("Aset berhasil diubah", response_item)


@portofolio_bp.delete("/<string:item_id>")
@jwt_required()
def delete_portofolio(item_id):
    user_id = current_user_id()
    try:
        row = mongo.db.portofolio.find_one({"_id": ObjectId(item_id), "user_id": user_id})
    except Exception:
         return response_error("Data aset tidak valid", 400)

    if not row:
        return response_error("Data aset tidak ditemukan", 404)

    _log_riwayat(user_id=user_id, aksi="delete", row=row)
    mongo.db.portofolio.delete_one({"_id": row["_id"]})
    
    return response_success("Aset berhasil dihapus", {"id": item_id})
