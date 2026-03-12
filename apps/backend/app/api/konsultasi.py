from flask import Blueprint, request, jsonify
from app.extensions import mongo
from bson import ObjectId
from datetime import datetime

konsultasi_bp = Blueprint("konsultasi", __name__, url_prefix="/api/konsultasi")

def _format_ahli(doc):
    doc["_id"] = str(doc["_id"])
    return doc

@konsultasi_bp.get("/ahli")
def get_ahli():
    kategori_id = request.args.get("kategori_id")
    query = {}
    if kategori_id and kategori_id != "Semua Ahli":
        # Cocokkan nama atau ID kategori
        query["$or"] = [
            {"kategori_id": kategori_id},
            {"spesialis": {"$regex": kategori_id, "$options": "i"}}
        ]
    
    ahli = list(mongo.db.ahli_syariah.find(query))
    return jsonify({
        "status": True,
        "data": [_format_ahli(a) for a in ahli]
    })

@konsultasi_bp.get("/kategori")
def get_kategori():
    kategori = list(mongo.db.kategori_ahli.find())
    for k in kategori:
        k["_id"] = str(k["_id"])
    return jsonify({
        "status": True,
        "data": kategori
    })

@konsultasi_bp.post("/book")
def book_konsultasi():
    # Placeholder untuk sistem booking & pembayaran
    # Di masa depan terintegrasi dengan Payment Gateway
    data = request.json
    ahli_id = data.get("ahli_id")
    user_id = data.get("user_id") # Harusnya dari JWT
    
    # Simulasi pembuatan sesi
    sesi = {
        "user_id": user_id,
        "ahli_id": ahli_id,
        "status": "pending_payment",
        "harga": 50000,
        "created_at": datetime.utcnow()
    }
    res = mongo.db.sessions.insert_one(sesi)
    
    return jsonify({
        "status": True,
        "message": "Permintaan konsultasi dibuat, silakan selesaikan pembayaran",
        "session_id": str(res.inserted_id)
    }), 201
