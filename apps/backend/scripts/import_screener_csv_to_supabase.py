from __future__ import annotations

import argparse
import csv
import json
import re
import uuid
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


def normalize_screener_status(raw_value: str) -> str:
    value = (raw_value or "").strip().lower()
    if value.startswith("yes"):
        return "halal"
    if value.startswith("no"):
        return "haram"
    return "proses"


def extract_screener_symbol(asset_name: str) -> str:
    text = (asset_name or "").strip()
    match = re.search(r"\(([^)]+)\)", text)
    if match:
        symbol = re.sub(r"[^A-Za-z0-9]", "", match.group(1)).upper()
        if symbol:
            return symbol

    candidates = re.findall(r"[A-Za-z0-9]{2,10}", text)
    if candidates:
        return candidates[-1].upper()
    return "NA"


def clean_screener_name(asset_name: str) -> str:
    text = (asset_name or "").strip()
    text = re.sub(r"\([^)]*\)", "", text).strip()
    return text or "Tanpa Nama"


def build_screener_explanation(row: dict[str, str]) -> str:
    underlying = (row.get("Underlying") or "").strip()
    nilai_jelas = (row.get("Nilai yang Jelas") or "").strip()
    serah_terima = (row.get("Bisakah Diserah-terimakan") or "").strip()
    sharia_raw = (row.get("Yes/No Sharia") or "").strip()

    sections: list[str] = []
    if underlying:
        sections.append(f"Underlying: {underlying}")
    if nilai_jelas:
        sections.append(f"Nilai: {nilai_jelas}")
    if serah_terima:
        sections.append(f"Serah-terima: {serah_terima}")
    if sharia_raw:
        sections.append(f"Sharia CSV: {sharia_raw}")
    return " | ".join(sections) or "Tidak ada keterangan."


def prepare_rows(csv_path: Path) -> list[dict[str, Any]]:
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    prepared: list[dict[str, Any]] = []
    used_symbols: set[str] = set()

    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        for index, raw_row in enumerate(reader, start=1):
            if not raw_row:
                continue

            row = {key: (value or "").strip() for key, value in raw_row.items()}
            asset_name = row.get("Aset Kripto", "")
            if not asset_name:
                continue

            base_symbol = extract_screener_symbol(asset_name)
            symbol = base_symbol
            suffix = 2
            while symbol in used_symbols:
                symbol = f"{base_symbol}{suffix}"
                suffix += 1
            used_symbols.add(symbol)

            sharia_status = normalize_screener_status(row.get("Yes/No Sharia", ""))
            legacy_mongo_id = f"csv-screener:{symbol}"
            prepared.append(
                {
                    "id": str(uuid.uuid5(uuid.NAMESPACE_URL, legacy_mongo_id)),
                    "legacy_mongo_id": legacy_mongo_id,
                    "coin_name": clean_screener_name(asset_name),
                    "symbol": symbol,
                    "status": sharia_status,
                    "sharia_status": sharia_status,
                    "fiqh_explanation": build_screener_explanation(row),
                    "scholar_reference": (
                        "Sumber: CSV Screener Averroes "
                        "(kajian internal, bukan fatwa resmi)."
                    ),
                    "extra_data": {
                        "source": "screener.csv",
                        "row_number": index,
                        "csv_row": row,
                        "penjelasan_fiqh": build_screener_explanation(row),
                    },
                    "created_at": now,
                    "updated_at": now,
                }
            )

    return prepared


def chunked(values: list[dict[str, Any]], chunk_size: int) -> Iterable[list[dict[str, Any]]]:
    for start in range(0, len(values), chunk_size):
        yield values[start : start + chunk_size]


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
        with urlopen(request, timeout=60) as response:
            raw = response.read()
            if not raw:
                return None
            return json.loads(raw)
    except HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase request failed ({exc.code} {method} {path}): {details}") from exc


def sync_screeners(
    *,
    base_url: str,
    service_role_key: str,
    rows: list[dict[str, Any]],
    replace_existing: bool,
) -> None:
    if replace_existing:
        supabase_request(
            base_url=base_url,
            service_role_key=service_role_key,
            method="DELETE",
            path="/rest/v1/screeners?id=not.is.null",
            headers={"Prefer": "return=minimal"},
        )

    for batch in chunked(rows, chunk_size=200):
        query = urlencode({"on_conflict": "symbol"})
        supabase_request(
            base_url=base_url,
            service_role_key=service_role_key,
            method="POST",
            path=f"/rest/v1/screeners?{query}",
            payload=batch,
            headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import screener.csv into Supabase public.screeners."
    )
    parser.add_argument(
        "--csv",
        default=str(Path(__file__).resolve().parents[3] / "screener.csv"),
        help="Path ke file screener CSV.",
    )
    parser.add_argument(
        "--env-file",
        default=str(Path(__file__).resolve().parents[1] / ".env"),
        help="Path ke file .env backend yang berisi kredensial Supabase.",
    )
    parser.add_argument(
        "--keep-existing",
        action="store_true",
        help="Jangan hapus data screener lama sebelum import.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv).resolve()
    env_path = Path(args.env_file).resolve()
    if not csv_path.exists():
        raise SystemExit(f"CSV tidak ditemukan: {csv_path}")
    if not env_path.exists():
        raise SystemExit(f"Env file tidak ditemukan: {env_path}")

    env = load_env_file(env_path)
    base_url = env.get("SUPABASE_URL", "").strip()
    service_role_key = env.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not base_url or not service_role_key:
        raise SystemExit("SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY tidak ditemukan.")

    rows = prepare_rows(csv_path)
    if not rows:
        raise SystemExit("Tidak ada data screener yang bisa diimport.")

    sync_screeners(
        base_url=base_url,
        service_role_key=service_role_key,
        rows=rows,
        replace_existing=not args.keep_existing,
    )
    print(f"Import screener selesai: {len(rows)} row dari {csv_path}")


if __name__ == "__main__":
    main()
