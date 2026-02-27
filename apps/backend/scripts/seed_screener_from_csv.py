#!/usr/bin/env python3
import argparse
import csv
import re
import sys
from pathlib import Path

# Ensure `app` package can be imported regardless of current working directory.
BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app import create_app
from app.extensions import db
from app.models import Screener


def normalize_status(raw_value: str) -> str:
    value = (raw_value or "").strip().lower()
    if value.startswith("yes"):
        return "halal"
    if value.startswith("no"):
        return "haram"
    return "proses"


def extract_symbol(asset_name: str) -> str:
    text = (asset_name or "").strip()
    match = re.search(r"\(([^)]+)\)", text)
    if match:
        symbol = re.sub(r"[^A-Za-z0-9]", "", match.group(1)).upper()
        if symbol:
            return symbol

    candidates = re.findall(r"[A-Za-z0-9]{2,10}", text)
    if candidates:
        return candidates[-1].upper()
    return "N/A"


def clean_name(asset_name: str) -> str:
    text = (asset_name or "").strip()
    text = re.sub(r"\([^)]*\)", "", text).strip()
    return text or "Tanpa Nama"


def build_alasan(row: dict[str, str]) -> str:
    underlying = (row.get("Underlying") or "").strip()
    nilai_jelas = (row.get("Nilai yang Jelas") or "").strip()
    serah_terima = (row.get("Bisakah Diserah-terimakan") or "").strip()
    sharia_raw = (row.get("Yes/No Sharia") or "").strip()

    sections = []
    if underlying:
        sections.append(f"Underlying: {underlying}")
    if nilai_jelas:
        sections.append(f"Nilai yang Jelas: {nilai_jelas}")
    if serah_terima:
        sections.append(f"Bisa Diserah-terimakan: {serah_terima}")
    if sharia_raw:
        sections.append(f"Catatan Sharia CSV: {sharia_raw}")
    return "\n".join(sections) or "Tidak ada keterangan."


def read_csv_rows(csv_path: Path) -> list[dict[str, str]]:
    rows = []
    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            if not row:
                continue
            if not any((value or "").strip() for value in row.values()):
                continue
            rows.append({k: (v or "").strip() for k, v in row.items()})
    return rows


def seed_screener(csv_path: Path, replace: bool = True) -> tuple[int, int]:
    raw_rows = read_csv_rows(csv_path)
    prepared = []
    for row in raw_rows:
        asset_name = row.get("Aset Kripto", "").strip()
        if not asset_name:
            continue

        prepared.append(
            {
                "nama_koin": clean_name(asset_name),
                "simbol": extract_symbol(asset_name),
                "status": normalize_status(row.get("Yes/No Sharia", "")),
                "alasan": build_alasan(row),
            }
        )

    if replace:
        Screener.query.delete()

    for item in prepared:
        db.session.add(Screener(**item))
    db.session.commit()
    return len(prepared), len(raw_rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed tabel screener dari file CSV.")
    parser.add_argument("csv_path", type=Path, help="Path file CSV (delimiter ';').")
    parser.add_argument(
        "--append",
        action="store_true",
        help="Append data tanpa menghapus data screener lama.",
    )
    args = parser.parse_args()

    csv_path = args.csv_path.expanduser().resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV tidak ditemukan: {csv_path}")

    app = create_app()
    with app.app_context():
        inserted_count, raw_count = seed_screener(csv_path, replace=not args.append)
        print(
            f"Selesai seed screener. Dibaca {raw_count} baris, dimasukkan {inserted_count} baris. "
            f"Mode: {'append' if args.append else 'replace'}."
        )


if __name__ == "__main__":
    main()
