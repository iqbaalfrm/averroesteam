from __future__ import annotations

import json
import re
import time
from collections.abc import Iterable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def supabase_request(
    *,
    base_url: str,
    service_role_key: str,
    method: str,
    path: str,
    payload: Any | None = None,
    headers: dict[str, str] | None = None,
) -> Any:
    request_headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
    if headers:
        request_headers.update(headers)

    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        f"{base_url.rstrip('/')}{path}",
        data=body,
        headers=request_headers,
        method=method,
    )
    try:
        with urlopen(request, timeout=90) as response:
            raw = response.read()
            if not raw:
                return None
            return json.loads(raw)
    except HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase request failed ({exc.code} {method} {path}): {details}") from exc


def get_screeners(base_url: str, service_role_key: str) -> list[dict[str, Any]]:
    path = (
        "/rest/v1/screeners"
        "?select=id,legacy_mongo_id,coin_name,symbol,status,sharia_status,"
        "fiqh_explanation,scholar_reference,extra_data"
        "&order=coin_name.asc"
        "&limit=1000"
    )
    rows = supabase_request(
        base_url=base_url,
        service_role_key=service_role_key,
        method="GET",
        path=path,
    )
    return rows if isinstance(rows, list) else []


def coin_gecko_request(path: str, query: dict[str, Any]) -> Any:
    url = f"https://api.coingecko.com/api/v3{path}?{urlencode(query)}"
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "AverroesTeam/1.0"})
    with urlopen(request, timeout=90) as response:
        return json.loads(response.read())


def fetch_market_rows(pages: int = 6, per_page: int = 250) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for page in range(1, pages + 1):
        payload = coin_gecko_request(
            "/coins/markets",
            {
                "vs_currency": "usd",
                "order": "market_cap_desc",
                "per_page": per_page,
                "page": page,
                "sparkline": "false",
                "locale": "id",
            },
        )
        if not isinstance(payload, list) or not payload:
            break
        rows.extend(item for item in payload if isinstance(item, dict))
        time.sleep(1.2)
    return rows


def normalize_text(value: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "", (value or "").strip().lower())
    return cleaned


def build_market_indexes(rows: list[dict[str, Any]]) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    symbol_index: dict[str, dict[str, Any]] = {}
    name_index: dict[str, dict[str, Any]] = {}
    for item in rows:
        symbol = (item.get("symbol") or "").strip().upper()
        name_key = normalize_text(str(item.get("name") or ""))
        existing_symbol = symbol_index.get(symbol)
        current_rank = int(item.get("market_cap_rank") or 999999)
        existing_rank = int(existing_symbol.get("market_cap_rank") or 999999) if existing_symbol else 999999
        if symbol and current_rank < existing_rank:
            symbol_index[symbol] = item

        existing_name = name_index.get(name_key)
        existing_name_rank = int(existing_name.get("market_cap_rank") or 999999) if existing_name else 999999
        if name_key and current_rank < existing_name_rank:
            name_index[name_key] = item
    return symbol_index, name_index


def logo_fallback(symbol: str) -> str:
    clean = re.sub(r"[^A-Z0-9]", "", (symbol or "").strip().upper())
    if not clean:
        return ""
    return f"https://bin.bnbstatic.com/static/assets/logos/{clean}.png"


def merge_market_data(
    row: dict[str, Any],
    *,
    symbol_index: dict[str, dict[str, Any]],
    name_index: dict[str, dict[str, Any]],
    synced_at: str,
) -> dict[str, Any]:
    symbol = (row.get("symbol") or "").strip().upper()
    name_key = normalize_text(str(row.get("coin_name") or ""))
    market = name_index.get(name_key) or symbol_index.get(symbol)
    extra_data = dict(row.get("extra_data") or {})

    if market:
        extra_data.update(
            {
                "harga_usd": market.get("current_price"),
                "market_cap": market.get("market_cap"),
                "perubahan_24j": market.get("price_change_percentage_24h"),
                "logo_url": (market.get("image") or "").strip(),
                "peringkat_market_cap": market.get("market_cap_rank"),
                "coingecko_id": (market.get("id") or "").strip(),
                "market_data_source": "coingecko",
                "market_data_synced_at": synced_at,
            }
        )
    else:
        fallback_logo = logo_fallback(symbol)
        if fallback_logo:
            extra_data["logo_url"] = fallback_logo
            extra_data["market_data_source"] = "binance-fallback"
            extra_data["market_data_synced_at"] = synced_at

    row["extra_data"] = extra_data
    row["updated_at"] = synced_at
    return row


def chunked(values: list[dict[str, Any]], chunk_size: int) -> Iterable[list[dict[str, Any]]]:
    for start in range(0, len(values), chunk_size):
        yield values[start : start + chunk_size]


def upsert_screeners(base_url: str, service_role_key: str, rows: list[dict[str, Any]]) -> None:
    for batch in chunked(rows, 200):
        supabase_request(
            base_url=base_url,
            service_role_key=service_role_key,
            method="POST",
            path="/rest/v1/screeners?on_conflict=id",
            payload=batch,
            headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
        )


def main() -> None:
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        raise SystemExit(f"Env file tidak ditemukan: {env_path}")
    env = load_env_file(env_path)
    base_url = env.get("SUPABASE_URL", "").strip()
    service_role_key = env.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not base_url or not service_role_key:
        raise SystemExit("SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY tidak ditemukan.")

    screeners = get_screeners(base_url, service_role_key)
    if not screeners:
        raise SystemExit("Tabel screeners kosong, tidak ada yang bisa diperkaya.")

    market_rows = fetch_market_rows()
    if not market_rows:
        raise SystemExit("CoinGecko tidak mengembalikan market data.")

    symbol_index, name_index = build_market_indexes(market_rows)
    synced_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    enriched = [
        merge_market_data(
            row,
            symbol_index=symbol_index,
            name_index=name_index,
            synced_at=synced_at,
        )
        for row in screeners
    ]
    upsert_screeners(base_url, service_role_key, enriched)

    matched = sum(
        1
        for row in enriched
        if (row.get("extra_data") or {}).get("market_data_source") == "coingecko"
    )
    fallback = sum(
        1
        for row in enriched
        if (row.get("extra_data") or {}).get("market_data_source") == "binance-fallback"
    )
    print(
        f"Enrichment screener selesai: {len(enriched)} row, "
        f"CoinGecko={matched}, fallback={fallback}"
    )


if __name__ == "__main__":
    main()
