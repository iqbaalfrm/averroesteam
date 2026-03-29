import json
import re
import time
import urllib.parse
import urllib.request
from flask import Blueprint, request

from app.extensions import mongo
from .common import response_success, response_error, format_doc

screener_bp = Blueprint("screener_api", __name__, url_prefix="/api/screener")

_DEFAULT_SCREENER_ROWS: list[dict] = [
    {
        "id": "default-screener-btc",
        "nama_koin": "Bitcoin",
        "simbol": "BTC",
        "status": "halal",
        "status_syariah": "halal",
        "penjelasan_fiqh": (
            "Underlying: Jaringan pembayaran dan penyimpan nilai digital | "
            "Nilai: Nilai pasar terbentuk terbuka di market global | "
            "Serah-terima: Dapat dimiliki, dipindahkan, dan disimpan langsung oleh pemilik"
        ),
        "referensi_ulama": "Kajian internal tim Averroes untuk kebutuhan edukasi, bukan fatwa resmi.",
    },
    {
        "id": "default-screener-eth",
        "nama_koin": "Ethereum",
        "simbol": "ETH",
        "status": "proses",
        "status_syariah": "proses",
        "penjelasan_fiqh": (
            "Underlying: Infrastruktur smart contract dan gas fee jaringan | "
            "Nilai: Memiliki utilitas jaringan yang jelas namun butuh telaah lanjutan | "
            "Serah-terima: Dapat dimiliki dan dipindahkan antar wallet"
        ),
        "referensi_ulama": "Kajian internal tim Averroes untuk kebutuhan edukasi, bukan fatwa resmi.",
    },
    {
        "id": "default-screener-bnb",
        "nama_koin": "BNB",
        "simbol": "BNB",
        "status": "proses",
        "status_syariah": "proses",
        "penjelasan_fiqh": (
            "Underlying: Token utilitas ekosistem exchange dan chain | "
            "Nilai: Ada utilitas, tetapi perlu penelaahan struktur dan penggunaan lebih detail | "
            "Serah-terima: Dapat dipindahkan dan disimpan oleh pemilik"
        ),
        "referensi_ulama": "Kajian internal tim Averroes untuk kebutuhan edukasi, bukan fatwa resmi.",
    },
    {
        "id": "default-screener-sol",
        "nama_koin": "Solana",
        "simbol": "SOL",
        "status": "proses",
        "status_syariah": "proses",
        "penjelasan_fiqh": (
            "Underlying: Infrastruktur blockchain untuk aplikasi dan pembayaran fee | "
            "Nilai: Utilitas jaringan ada, tetapi screening syariah memerlukan review berkala | "
            "Serah-terima: Dapat dipindahkan dan dimiliki secara langsung"
        ),
        "referensi_ulama": "Kajian internal tim Averroes untuk kebutuhan edukasi, bukan fatwa resmi.",
    },
]

# ─── CoinGecko Top-N Cache ──────────────────────────────────────────
# Simpan hasil fetch CoinGecko agar tidak memanggil API terlalu sering.
# Cache berlaku selama _CG_TTL detik (default 5 menit).
_CG_TTL = 300  # detik
_cg_cache: dict = {"data": [], "ts": 0.0}


def _fetch_coingecko_top(n: int = 100) -> list[dict]:
    """
    Ambil top-N koin berdasarkan market cap dari CoinGecko API (gratis, tanpa key).
    Mengembalikan list dict dengan field: id, symbol, name, image,
    current_price, market_cap, market_cap_rank, price_change_percentage_24h.
    Hasil di-cache selama _CG_TTL detik.
    """
    now = time.time()
    if _cg_cache["data"] and (now - _cg_cache["ts"]) < _CG_TTL:
        return _cg_cache["data"]

    all_coins: list[dict] = []
    per_page = 100
    pages_needed = max(1, (n + per_page - 1) // per_page)

    for page in range(1, pages_needed + 1):
        params = urllib.parse.urlencode({
            "vs_currency": "usd",
            "order": "market_cap_desc",
            "per_page": per_page,
            "page": page,
            "sparkline": "false",
            "locale": "id",
        })
        url = f"https://api.coingecko.com/api/v3/coins/markets?{params}"
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                body = json.loads(resp.read().decode("utf-8"))
            if isinstance(body, list):
                all_coins.extend(body)
        except Exception:
            break  # Gagal fetch, pakai cache lama kalau ada

    if all_coins:
        _cg_cache["data"] = all_coins[:n]
        _cg_cache["ts"] = now

    return _cg_cache["data"]


def _build_symbol_map(top_coins: list[dict]) -> dict:
    """
    Buat mapping SYMBOL (uppercase) -> data CoinGecko.
    Jika ada duplikat simbol, prioritas diberikan ke market_cap_rank terkecil.
    """
    sym_map: dict = {}
    for coin in top_coins:
        sym = (coin.get("symbol") or "").strip().upper()
        if not sym:
            continue
        existing = sym_map.get(sym)
        if existing is None:
            sym_map[sym] = coin
        else:
            # Pilih yang rank-nya lebih tinggi (angka lebih kecil)
            existing_rank = existing.get("market_cap_rank") or 9999
            new_rank = coin.get("market_cap_rank") or 9999
            if new_rank < existing_rank:
                sym_map[sym] = coin
    return sym_map


def _enrich_doc(doc: dict, cg_coin: dict | None) -> dict:
    """Gabungkan data DB screener dengan data market CoinGecko."""
    d = format_doc(doc)
    d["status_syariah"] = (
        str(d.get("status_syariah") or d.get("status") or "proses").strip().lower()
    )
    d["penjelasan_fiqh"] = (
        str(d.get("penjelasan_fiqh") or d.get("alasan") or "Belum ada penjelasan fiqh.")
        .strip()
    )
    d["referensi_ulama"] = (
        str(
            d.get("referensi_ulama")
            or "Kajian internal tim Averroes untuk kebutuhan edukasi, bukan fatwa resmi."
        ).strip()
    )
    if cg_coin:
        d["harga_usd"] = cg_coin.get("current_price")
        d["market_cap"] = cg_coin.get("market_cap")
        d["perubahan_24j"] = cg_coin.get("price_change_percentage_24h")
        d["logo_url"] = cg_coin.get("image") or ""
        d["peringkat_market_cap"] = cg_coin.get("market_cap_rank")
        d["coingecko_id"] = cg_coin.get("id") or ""
    else:
        d["harga_usd"] = None
        d["market_cap"] = None
        d["perubahan_24j"] = None
        d["logo_url"] = ""
        d["peringkat_market_cap"] = None
        d["coingecko_id"] = ""
    return d


def _fallback_rows(q: str, status: str) -> list[dict]:
    rows = list(_DEFAULT_SCREENER_ROWS)
    if q:
        needle = q.lower()
        rows = [
            row
            for row in rows
            if needle in (row.get("nama_koin") or "").lower()
            or needle in (row.get("simbol") or "").lower()
        ]
    if status in {"halal", "proses", "haram"}:
        rows = [row for row in rows if (row.get("status_syariah") or row.get("status")) == status]
    return rows


@screener_bp.get("")
def list_screener():
    """
    GET /api/screener
    Query params:
      - q         : keyword pencarian (nama / simbol)
      - status    : halal | proses | haram
      - top       : jumlah top market cap (default 100, max 250)
      - all       : jika "true", tampilkan semua tanpa filter top market cap
    """
    filters: dict = {}

    q = (request.args.get("q") or "").strip()
    if q:
        regex = re.compile(re.escape(q), re.IGNORECASE)
        filters["$or"] = [
            {"nama_koin": regex},
            {"simbol": regex}
        ]

    status = (request.args.get("status") or "").strip().lower()
    if status in {"halal", "proses", "haram"}:
        filters["status"] = status

    show_all = (request.args.get("all") or "").strip().lower() == "true"
    top_n = 100
    try:
        top_n = min(int(request.args.get("top") or 100), 250)
    except (ValueError, TypeError):
        pass

    # Ambil semua data screener dari DB
    rows = list(mongo.db.screener.find(filters).sort("nama_koin", 1))
    if not rows and mongo.db.screener.count_documents({}) == 0:
        rows = _fallback_rows(q, status)

    if show_all:
        # Tanpa filter top market cap – tetap enrichkan dengan data CoinGecko
        try:
            top_coins = _fetch_coingecko_top(250)
            sym_map = _build_symbol_map(top_coins)
        except Exception:
            sym_map = {}

        enriched = []
        for row in rows:
            sym = (row.get("simbol") or "").strip().upper()
            enriched.append(_enrich_doc(row, sym_map.get(sym)))
        return response_success("Berhasil mengambil semua data screener", enriched)

    # ─── Filter Top-N Market Cap ────────────────────────────────────
    try:
        top_coins = _fetch_coingecko_top(top_n)
    except Exception:
        # Fallback: tampilkan data DB tanpa enrichment
        return response_success(
            "Berhasil mengambil data screener (tanpa data market)",
            [_enrich_doc(row, None) for row in rows],
        )

    sym_map = _build_symbol_map(top_coins)
    top_symbols = set(sym_map.keys())

    enriched = []
    for row in rows:
        sym = (row.get("simbol") or "").strip().upper()
        if sym in top_symbols:
            enriched.append(_enrich_doc(row, sym_map[sym]))

    # Urutkan berdasarkan peringkat market cap (rank terkecil duluan)
    enriched.sort(key=lambda x: x.get("peringkat_market_cap") or 9999)

    return response_success(
        f"Berhasil mengambil data screener (Top {top_n} Market Cap)",
        enriched,
    )


@screener_bp.get("/market-info")
def market_info():
    """
    GET /api/screener/market-info?symbol=BTC,ETH
    Mengambil data market CoinGecko untuk simbol-simbol tertentu.
    """
    symbols_raw = (request.args.get("symbol") or "").strip()
    if not symbols_raw:
        return response_error("Parameter 'symbol' wajib diisi", 400)

    requested = {s.strip().upper() for s in symbols_raw.split(",") if s.strip()}
    if not requested:
        return response_error("Parameter 'symbol' tidak valid", 400)

    try:
        top_coins = _fetch_coingecko_top(250)
    except Exception:
        return response_error("Gagal mengambil data market dari CoinGecko", 502)

    sym_map = _build_symbol_map(top_coins)
    results = []
    for sym in requested:
        cg = sym_map.get(sym)
        if cg:
            results.append({
                "simbol": sym,
                "harga_usd": cg.get("current_price"),
                "market_cap": cg.get("market_cap"),
                "perubahan_24j": cg.get("price_change_percentage_24h"),
                "logo_url": cg.get("image") or "",
                "peringkat_market_cap": cg.get("market_cap_rank"),
                "coingecko_id": cg.get("id") or "",
            })

    return response_success("Berhasil mengambil data market", results)


@screener_bp.get("/metodologi")
def metodologi():
    return response_success(
        "Berhasil mengambil metodologi screener",
        {
            "notice": "Status syariah bersifat edukatif berdasarkan kajian internal tim Averroes, bukan fatwa resmi.",
        },
    )
