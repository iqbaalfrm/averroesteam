import json
import time
import urllib.parse
import urllib.request
from typing import Any

from flask import Blueprint, request

from .common import response_error, response_success

pasar_bp = Blueprint("pasar_api", __name__, url_prefix="/api/pasar")

_BINANCE_BASE = "https://api.binance.com"
_CACHE: dict[str, dict] = {}
_FRESH_TTL_SECONDS = 180


def _cache_get(key: str):
    row = _CACHE.get(key)
    if not row:
        return None, False
    age = time.time() - float(row.get("ts") or 0)
    is_fresh = age <= _FRESH_TTL_SECONDS
    return row.get("data"), is_fresh


def _cache_set(key: str, data):
    _CACHE[key] = {"data": data, "ts": time.time()}


def _fetch_json(path: str, *, params: dict | None = None, timeout: int = 12):
    url = _BINANCE_BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        body = resp.read().decode("utf-8")
    return json.loads(body)


def _to_float(v: Any, default: float = 0.0) -> float:
    try:
        return float(v)
    except Exception:
        return default


def _usdt_to_idr_rate() -> float:
    key = "fx:usdtidr"
    cached, is_fresh = _cache_get(key)
    if cached is not None and is_fresh:
        return _to_float(cached, 16000.0)
    try:
        row = _fetch_json("/api/v3/ticker/price", params={"symbol": "USDTIDR"}, timeout=10)
        rate = _to_float((row or {}).get("price"), 16000.0)
        if rate <= 0:
            rate = 16000.0
        _cache_set(key, rate)
        return rate
    except Exception:
        return _to_float(cached, 16000.0) if cached is not None else 16000.0


def _logo_url(symbol: str) -> str:
    s = (symbol or "").strip().lower()
    if not s:
        return ""
    return f"https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/{s}.png"


def _normalize_row_24h(row: dict, usdt_idr: float) -> dict:
    pair = (row.get("symbol") or "").strip().upper()
    if not pair.endswith("USDT"):
        return {}
    base = pair[:-4]
    if not base or any(x in base for x in ("UP", "DOWN", "BULL", "BEAR")):
        return {}

    last = _to_float(row.get("lastPrice"))
    high = _to_float(row.get("highPrice"))
    low = _to_float(row.get("lowPrice"))
    chg = _to_float(row.get("priceChangePercent"))
    quote_vol = _to_float(row.get("quoteVolume"))
    vol_base = _to_float(row.get("volume"))

    return {
        "id": base.lower(),
        "name": base,
        "symbol": base.lower(),
        "image": _logo_url(base),
        "current_price": last * usdt_idr,
        "price_change_percentage_24h": chg,
        "market_cap_rank": None,
        "market_cap": quote_vol * usdt_idr,  # proxy likuiditas 24h dalam IDR
        "total_volume": vol_base,
        "high_24h": high * usdt_idr,
        "low_24h": low * usdt_idr,
    }


@pasar_bp.get("/global")
def global_market():
    key = "global"
    cached, is_fresh = _cache_get(key)
    if cached is not None and is_fresh:
        return response_success("Berhasil mengambil data global pasar (cache)", cached)

    try:
        rows = _fetch_json("/api/v3/ticker/24hr", timeout=18)
        if not isinstance(rows, list):
            rows = []
        usdt_idr = _usdt_to_idr_rate()
        norm = [
            _normalize_row_24h(r, usdt_idr)
            for r in rows
            if isinstance(r, dict)
        ]
        norm = [x for x in norm if x]
        norm.sort(key=lambda x: _to_float(x.get("market_cap")), reverse=True)
        sample = norm[:120]
        if sample:
            avg_change = sum(_to_float(x.get("price_change_percentage_24h")) for x in sample) / len(sample)
        else:
            avg_change = 0.0
        data = {
            "market_cap_change_percentage_24h_usd": round(avg_change, 2),
        }
        _cache_set(key, data)
        return response_success("Berhasil mengambil data global pasar", data)
    except Exception:
        if cached is not None:
            return response_success("Berhasil mengambil data global pasar (stale cache)", cached)
        return response_error("Gagal mengambil data global pasar", 502)


@pasar_bp.get("/markets")
def markets():
    order = (request.args.get("order") or "market_cap_desc").strip().lower()
    try:
        per_page = int(request.args.get("per_page", 100))
    except Exception:
        per_page = 100
    try:
        page = int(request.args.get("page", 1))
    except Exception:
        page = 1
    per_page = min(max(per_page, 1), 250)
    page = max(page, 1)

    key = f"markets:binance:{order}:{per_page}:{page}"
    cached, is_fresh = _cache_get(key)
    if cached is not None and is_fresh:
        return response_success("Berhasil mengambil data pasar (cache)", cached)

    try:
        rows = _fetch_json("/api/v3/ticker/24hr", timeout=18)
        if not isinstance(rows, list):
            rows = []
        usdt_idr = _usdt_to_idr_rate()
        items = [
            _normalize_row_24h(r, usdt_idr)
            for r in rows
            if isinstance(r, dict)
        ]
        items = [x for x in items if x]
        if order == "price_change_percentage_24h_desc":
            items.sort(key=lambda x: _to_float(x.get("price_change_percentage_24h")), reverse=True)
        else:
            items.sort(key=lambda x: _to_float(x.get("market_cap")), reverse=True)
        start = (page - 1) * per_page
        end = start + per_page
        page_items = items[start:end]
        _cache_set(key, page_items)
        return response_success("Berhasil mengambil data pasar", page_items)
    except Exception:
        if cached is not None:
            return response_success("Berhasil mengambil data pasar (stale cache)", cached)
        return response_error("Gagal mengambil data pasar", 502)


@pasar_bp.get("/detail")
def market_detail():
    symbol = (request.args.get("symbol") or "").strip().upper()
    if not symbol:
        return response_error("symbol wajib diisi", 400)
    pair = f"{symbol}USDT"
    key = f"detail:{pair}"
    cached, is_fresh = _cache_get(key)
    if cached is not None and is_fresh:
        return response_success("Berhasil mengambil detail pasar (cache)", cached)

    try:
        t24 = _fetch_json("/api/v3/ticker/24hr", params={"symbol": pair}, timeout=12)
        if not isinstance(t24, dict):
            raise ValueError("invalid ticker response")
        usdt_idr = _usdt_to_idr_rate()
        last = _to_float(t24.get("lastPrice")) * usdt_idr
        high = _to_float(t24.get("highPrice")) * usdt_idr
        low = _to_float(t24.get("lowPrice")) * usdt_idr
        quote_vol = _to_float(t24.get("quoteVolume")) * usdt_idr
        change = _to_float(t24.get("priceChangePercent"))
        # Binance tidak punya ATH/ATL via endpoint ini; pakai fallback high/low 24h.
        data = {
            "price": last,
            "chg24": change,
            "cap": quote_vol,
            "vol": quote_vol,
            "h24": high,
            "l24": low,
            "ath": high,
            "atl": low,
            "desc": f"{symbol} diperdagangkan di Binance spot pair {pair}.",
            "home": "https://www.binance.com/en/markets",
        }
        _cache_set(key, data)
        return response_success("Berhasil mengambil detail pasar", data)
    except Exception:
        if cached is not None:
            return response_success("Berhasil mengambil detail pasar (stale cache)", cached)
        return response_error("Gagal mengambil detail pasar", 502)


@pasar_bp.get("/chart")
def market_chart():
    symbol = (request.args.get("symbol") or "").strip().upper()
    days = (request.args.get("days") or "7").strip()
    if not symbol:
        return response_error("symbol wajib diisi", 400)
    try:
        d = int(days)
    except Exception:
        d = 7
    d = max(1, min(d, 365))

    if d <= 1:
        interval, limit = "5m", 288
    elif d <= 7:
        interval, limit = "1h", min(24 * d, 1000)
    elif d <= 31:
        interval, limit = "4h", min(6 * d, 1000)
    else:
        interval, limit = "1d", min(d, 1000)

    pair = f"{symbol}USDT"
    key = f"chart:{pair}:{interval}:{limit}"
    cached, is_fresh = _cache_get(key)
    if cached is not None and is_fresh:
        return response_success("Berhasil mengambil chart pasar (cache)", cached)

    try:
        rows = _fetch_json(
            "/api/v3/klines",
            params={"symbol": pair, "interval": interval, "limit": limit},
            timeout=15,
        )
        if not isinstance(rows, list):
            rows = []
        usdt_idr = _usdt_to_idr_rate()
        prices: list[float] = []
        for r in rows:
            if not isinstance(r, list) or len(r) < 5:
                continue
            close_price = _to_float(r[4]) * usdt_idr
            if close_price > 0:
                prices.append(close_price)
        _cache_set(key, prices)
        return response_success("Berhasil mengambil chart pasar", prices)
    except Exception:
        if cached is not None:
            return response_success("Berhasil mengambil chart pasar (stale cache)", cached)
        return response_error("Gagal mengambil chart pasar", 502)
