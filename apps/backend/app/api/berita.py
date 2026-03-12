import math
import re
from html import unescape
from urllib.parse import urljoin
from urllib.request import Request, urlopen

from flask import Blueprint, request
from bson import ObjectId

from app.extensions import mongo
from .common import response_success, format_doc, response_error

berita_bp = Blueprint("berita_api", __name__, url_prefix="/api/berita")


def _clean_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _fetch_html(url: str, timeout_seconds: int = 20) -> str:
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (AverroesMobile/1.0)"})
    with urlopen(req, timeout=timeout_seconds) as resp:
        return resp.read().decode("utf-8", "ignore")


def _extract_full_article_text(html: str) -> str:
    blocks = _extract_full_article_blocks(html, "")
    paras = [b.get("text", "").strip() for b in blocks if b.get("type") == "p"]
    return "\n\n".join([p for p in paras if p])[:14000]


def _extract_img_url(tag: str, base_url: str) -> str:
    for attr in ("data-src", "src"):
        m = re.search(rf'{attr}=["\']([^"\']+)["\']', tag, flags=re.IGNORECASE)
        if m:
            url = m.group(1).strip()
            if url and not url.startswith("data:"):
                return urljoin(base_url, url) if base_url else url
    mset = re.search(r'srcset=["\']([^"\']+)["\']', tag, flags=re.IGNORECASE)
    if mset:
        first = mset.group(1).split(",")[0].strip().split(" ")[0].strip()
        if first and not first.startswith("data:"):
            return urljoin(base_url, first) if base_url else first
    return ""


def _is_noise_paragraph(text: str) -> bool:
    t = (text or "").strip()
    if len(t) < 30:
        return True
    patterns = [
        r"about help center",
        r"powered by news",
        r"\b[A-Z]{2,10}USDT\b",
        r"(?:\b[A-Z]{2,12}USDT\b.*?){2,}",
        r"dark mode",
        r"\bhelp center\b",
        r"\b(iklan|advert|copyright|komentar)\b",
        r"enter your email and we.?ll send you link to get back into your account",
    ]
    for p in patterns:
        if re.search(p, t, flags=re.IGNORECASE):
            return True
    return False


def _sanitize_text_output(text: str) -> str:
    t = _clean_text(text or "")
    return "" if _is_noise_paragraph(t) else t


def _sanitize_content_output(content: str) -> str:
    parts = [p.strip() for p in re.split(r"\n\s*\n+", content or "") if p.strip()]
    clean_parts = [p for p in parts if not _is_noise_paragraph(p)]
    deduped: list[str] = []
    seen: set[str] = set()
    for part in clean_parts:
        normalized = re.sub(r"\s+", " ", part.strip().lower())
        if normalized in seen:
            continue
        seen.add(normalized)
        deduped.append(part)
    if not deduped:
        return ""
    return "\n\n".join(deduped)[:14000]


def _extract_full_article_blocks(html: str, base_url: str) -> list[dict]:
    scopes: list[str] = []
    article_match = re.search(r"<article[^>]*>(.*?)</article>", html, flags=re.IGNORECASE | re.DOTALL)
    if article_match:
        scopes.append(article_match.group(1))
    main_match = re.search(r"<main[^>]*>(.*?)</main>", html, flags=re.IGNORECASE | re.DOTALL)
    if main_match:
        scopes.append(main_match.group(1))
    scopes.append(html)

    for scope in scopes:
        blocks: list[dict] = []
        seen_paras: set[str] = set()
        for m in re.finditer(r"(<img[^>]*>)|(<p[^>]*>.*?</p>)", scope, flags=re.IGNORECASE | re.DOTALL):
            img_tag = m.group(1)
            p_tag = m.group(2)
            if img_tag:
                img = _extract_img_url(img_tag, base_url)
                if img:
                    blocks.append({"type": "img", "url": img})
                continue
            if p_tag:
                text = _clean_text(p_tag)
                if _is_noise_paragraph(text):
                    continue
                low = text.lower()
                if low in seen_paras:
                    continue
                seen_paras.add(low)
                blocks.append({"type": "p", "text": text})
        para_count = sum(1 for b in blocks if b.get("type") == "p")
        if para_count >= 2:
            return blocks[:60]
    return []


@berita_bp.get("/terbaru")
def berita_terbaru():
    rows = list(mongo.db.berita.find().sort("published_at", -1).limit(5))
    return response_success("Berhasil mengambil berita terbaru", [format_doc(row) for row in rows])


@berita_bp.get("")
def berita_semua():
    page = request.args.get("page", 1, type=int)
    per_page = request.args.get("per_page", 20, type=int)
    per_page = max(1, min(per_page, 50))
    
    skip = (page - 1) * per_page
    cursor = mongo.db.berita.find().sort("published_at", -1)
    
    total = mongo.db.berita.count_documents({})
    rows = list(cursor.skip(skip).limit(per_page))
    pages = math.ceil(total / per_page) if total > 0 else 0

    items = [format_doc(row) for row in rows]
    for item in items:
        judul = str(item.get("judul") or "").strip()
        ringkasan = _sanitize_text_output(str(item.get("ringkasan") or ""))
        konten = _sanitize_content_output(str(item.get("konten") or ""))
        if ringkasan:
            item["ringkasan"] = ringkasan
        elif judul:
            item["ringkasan"] = judul[:240]
        if konten:
            item["konten"] = konten

    data = {
        "items": items,
        "page": page,
        "per_page": per_page,
        "total": total,
        "pages": pages,
    }
    return response_success("Berhasil mengambil semua berita", data)


@berita_bp.get("/<string:berita_id>")
def detail_berita(berita_id: str):
    try:
        row = mongo.db.berita.find_one({"_id": ObjectId(berita_id)})
    except Exception:
        return response_error("ID berita tidak valid", 400)
    if not row:
        return response_error("Berita tidak ditemukan", 404)
    payload = format_doc(row)
    judul = str(payload.get("judul") or "").strip()
    ringkasan = _sanitize_text_output(str(payload.get("ringkasan") or ""))
    konten = _sanitize_content_output(str(payload.get("konten") or ""))
    if ringkasan:
        payload["ringkasan"] = ringkasan
    elif judul:
        payload["ringkasan"] = judul[:240]
    if konten:
        payload["konten"] = konten
    return response_success("Berhasil mengambil detail berita", payload)


@berita_bp.get("/<string:berita_id>/full")
def detail_berita_full(berita_id: str):
    try:
        row = mongo.db.berita.find_one({"_id": ObjectId(berita_id)})
    except Exception:
        return response_error("ID berita tidak valid", 400)
    if not row:
        return response_error("Berita tidak ditemukan", 404)

    current_content = str(row.get("konten") or "").strip()
    current_blocks = row.get("konten_blocks") if isinstance(row.get("konten_blocks"), list) else []
    source_url = str(row.get("sumber_url") or "").strip()
    content = current_content
    blocks = current_blocks if isinstance(current_blocks, list) else []

    needs_scrape = (len(current_content) < 700 or len(blocks) < 3) and bool(source_url)
    if needs_scrape:
        try:
            html = _fetch_html(source_url, timeout_seconds=20)
            scraped_blocks = _extract_full_article_blocks(html, source_url)
            scraped_paras = [b.get("text", "").strip() for b in scraped_blocks if b.get("type") == "p"]
            scraped = "\n\n".join([p for p in scraped_paras if p])[:14000]
            if len(scraped) > len(current_content):
                content = scraped
                blocks = scraped_blocks
                updates = {"konten": scraped, "konten_blocks": scraped_blocks}
                summary = str(row.get("ringkasan") or "").strip()
                if not summary:
                    updates["ringkasan"] = scraped[:240]
                mongo.db.berita.update_one({"_id": row["_id"]}, {"$set": updates})
                row.update(updates)
        except Exception:
            pass

    if not blocks and content:
        # fallback blocks from existing text
        pars = [p.strip() for p in re.split(r"\n\s*\n+", content) if p.strip()]
        blocks = [{"type": "p", "text": p} for p in pars[:40]]

    payload = format_doc(row)
    cleaned_content = _sanitize_content_output(content)
    payload["konten"] = cleaned_content or content
    payload["konten_blocks"] = blocks
    return response_success("Berhasil mengambil detail berita lengkap", payload)
