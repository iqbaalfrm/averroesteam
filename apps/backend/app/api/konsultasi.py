import midtransclient
from flask import Blueprint, request, jsonify, current_app
from app.extensions import mongo, csrf
from bson import ObjectId
from datetime import datetime
import uuid

from .common import auth_required, current_user_doc, current_user_id

konsultasi_bp = Blueprint("konsultasi", __name__, url_prefix="/api/konsultasi")

def _format_ahli(doc):
    doc["_id"] = str(doc["_id"])
    return doc

@konsultasi_bp.get("/ahli")
def get_ahli():
    kategori_id = request.args.get("kategori_id")
    query = {}
    if kategori_id and kategori_id != "Semua Ahli":
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
@auth_required()
def book_konsultasi():
    data = request.json
    ahli_id = data.get("ahli_id")
    user_id = current_user_id()
    user = current_user_doc()

    if not user:
        return jsonify({"status": False, "message": "User tidak ditemukan"}), 404

    ahli = mongo.db.ahli_syariah.find_one({"_id": ObjectId(ahli_id)})
    if not ahli:
        return jsonify({"status": False, "message": "Ahli tidak ditemukan"}), 404

    order_id = f"CONS-{uuid.uuid4().hex[:8].upper()}"
    harga = ahli.get("harga_per_sesi", 50000)

    # 1. Simpan sesi ke DB dengan status pending
    sesi = {
        "order_id": order_id,
        "user_id": user_id,
        "ahli_id": ahli_id,
        "status": "pending",
        "harga": harga,
        "created_at": datetime.utcnow()
    }
    mongo.db.sessions.insert_one(sesi)

    # 2. Inisiasi Midtrans Snap
    snap = midtransclient.Snap(
        is_production=current_app.config["MIDTRANS_IS_PRODUCTION"],
        server_key=current_app.config["MIDTRANS_SERVER_KEY"]
    )

    param = {
        "transaction_details": {
            "order_id": order_id,
            "gross_amount": harga
        },
        "item_details": [{
            "id": str(ahli["_id"]),
            "price": harga,
            "quantity": 1,
            "name": f"Konsultasi Syariah - {ahli['nama']}"
        }],
        "customer_details": {
            "first_name": user.get("nama", "User Averroes"),
            "email": user.get("email", "user@averroes.id")
        }
    }

    try:
        transaction = snap.create_transaction(param)
        return jsonify({
            "status": True,
            "message": "Sesi konsultasi diinisiasi",
            "data": {
                "order_id": order_id,
                "snap_token": transaction['token'],
                "redirect_url": transaction['redirect_url']
            }
        }), 201
    except Exception as e:
        return jsonify({"status": False, "message": str(e)}), 500

@konsultasi_bp.post("/notification")
@csrf.exempt
def handle_notification():
    data = request.json
    order_id = data.get("order_id")
    transaction_status = data.get("transaction_status")
    fraud_status = data.get("fraud_status")

    if not order_id:
        return jsonify({"status": False, "message": "Invalid notification"}), 400

    new_status = "pending"
    if transaction_status == 'capture':
        if fraud_status == 'challenge':
            new_status = 'challenge'
        elif fraud_status == 'accept':
            new_status = 'success'
    elif transaction_status == 'settlement':
        new_status = 'success'
    elif transaction_status == 'cancel' or transaction_status == 'deny' or transaction_status == 'expire':
        new_status = 'failed'
    elif transaction_status == 'pending':
        new_status = 'pending'

    mongo.db.sessions.update_one(
        {"order_id": order_id},
        {"$set": {"status": new_status, "updated_at": datetime.utcnow()}}
    )

    return jsonify({"status": True, "message": "Notification handled"})
