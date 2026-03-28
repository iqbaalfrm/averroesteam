from datetime import datetime, timedelta
from threading import Lock

import requests
from flask import Blueprint, current_app
from flask_jwt_extended import jwt_required

from app.extensions import mongo
from .common import current_user_id, response_success

zakat_bp = Blueprint("zakat_api", __name__, url_prefix="/api/zakat")

_TROY_OUNCE_TO_GRAMS = 31.1034768
_zakat_price_cache_lock = Lock()
_zakat_price_cache = {
    "expires_at": None,
    "payload": None,
}


def _fetch_json(url: str) -> dict:
    response = requests.get(
        url,
        timeout=12,
        headers={"Accept": "application/json", "User-Agent": "Averroes/1.0"},
    )
    response.raise_for_status()
    data = response.json()
    if not isinstance(data, dict):
        raise ValueError("Respons API tidak valid")
    return data


def _fallback_gold_payload() -> dict:
    grams = float(current_app.config.get("ZAKAT_GOLD_GRAMS_NISHAB", 85))
    dummy_nishab = float(current_app.config.get("NISHAB_DUMMY", 0))
    per_gram = (dummy_nishab / grams) if grams > 0 else 0.0
    return {
        "price_per_gram_idr": round(per_gram, 2),
        "source": "fallback",
        "gold_updated_at": None,
        "fx_updated_at": None,
        "usd_idr_rate": None,
        "xau_usd_per_ounce": None,
    }


def _fetch_live_gold_payload() -> dict:
    gold_data = _fetch_json(current_app.config["GOLD_PRICE_API_URL"])
    xau_usd_per_ounce = float(gold_data["price"])

    fx_data = _fetch_json(current_app.config["USD_IDR_RATE_API_URL"])
    if fx_data.get("result") != "success":
        raise ValueError("Gagal mengambil kurs USD ke IDR")
    fx_rates = fx_data.get("rates") or {}
    usd_idr_rate = float(fx_rates["IDR"])

    price_per_gram_idr = (xau_usd_per_ounce * usd_idr_rate) / _TROY_OUNCE_TO_GRAMS
    return {
        "price_per_gram_idr": round(price_per_gram_idr, 2),
        "source": "live",
        "gold_updated_at": gold_data.get("updatedAt"),
        "fx_updated_at": fx_data.get("time_last_update_utc"),
        "usd_idr_rate": round(usd_idr_rate, 4),
        "xau_usd_per_ounce": round(xau_usd_per_ounce, 4),
    }


def _get_gold_price_payload() -> dict:
    now = datetime.utcnow()
    with _zakat_price_cache_lock:
        expires_at = _zakat_price_cache.get("expires_at")
        cached = _zakat_price_cache.get("payload")
        if cached and isinstance(expires_at, datetime) and now < expires_at:
            return cached

    cache_seconds = int(current_app.config.get("ZAKAT_PRICE_CACHE_SECONDS", 3600))
    try:
        payload = _fetch_live_gold_payload()
    except Exception as exc:
        current_app.logger.warning("Live zakat gold price fetch failed: %s", exc)
        payload = _fallback_gold_payload()

    with _zakat_price_cache_lock:
        _zakat_price_cache["payload"] = payload
        _zakat_price_cache["expires_at"] = now + timedelta(seconds=max(cache_seconds, 60))
    return payload


@zakat_bp.get("/hitung")
@jwt_required()
def hitung_zakat():
    user_id = current_user_id()
    rows = list(mongo.db.portofolio.find({"user_id": user_id}))

    total_aset = sum(row.get("jumlah", 0) * row.get("harga_beli", 0) for row in rows)
    gold = _get_gold_price_payload()
    nishab_grams = float(current_app.config.get("ZAKAT_GOLD_GRAMS_NISHAB", 85))
    nishab = round(gold["price_per_gram_idr"] * nishab_grams, 2)
    wajib_zakat = total_aset >= nishab if nishab > 0 else False
    nilai_zakat = round(total_aset * 0.025, 2) if wajib_zakat else 0.0

    return response_success(
        "Berhasil menghitung zakat",
        {
            "total_aset": round(total_aset, 2),
            "nishab": nishab,
            "nishab_grams": nishab_grams,
            "harga_emas_per_gram": gold["price_per_gram_idr"],
            "wajib_zakat": wajib_zakat,
            "nilai_zakat": nilai_zakat,
            "gold_price_source": gold["source"],
            "gold_price_updated_at": gold["gold_updated_at"],
            "fx_rate_updated_at": gold["fx_updated_at"],
            "baznas_url": current_app.config.get("ZAKAT_BAZNAS_URL"),
        },
    )


@zakat_bp.get("/nishab")
def get_nishab():
    gold = _get_gold_price_payload()
    nishab_grams = float(current_app.config.get("ZAKAT_GOLD_GRAMS_NISHAB", 85))
    nishab = round(gold["price_per_gram_idr"] * nishab_grams, 2)
    return response_success(
        "Berhasil mengambil nilai nishab",
        {
            "nishab": nishab,
            "nishab_grams": nishab_grams,
            "harga_emas_per_gram": gold["price_per_gram_idr"],
            "gold_price_source": gold["source"],
            "gold_price_updated_at": gold["gold_updated_at"],
            "fx_rate_updated_at": gold["fx_updated_at"],
            "baznas_url": current_app.config.get("ZAKAT_BAZNAS_URL"),
        },
    )
