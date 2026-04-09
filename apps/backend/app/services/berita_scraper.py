import logging
import re
import threading
import time
import uuid
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from html import unescape
from typing import Iterable
from urllib.error import URLError
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET

import requests
from app.extensions import mongo
from pymongo.errors import DuplicateKeyError


logger = logging.getLogger(__name__)
_PAGE_IMAGE_CACHE: dict[str, str] = {}

_NOISE_PATTERNS = [
    r"about help center",
    r"dark mode",
    r"\bhelp center\b",
    r"\bpowered by\b",
    r"\b(iklan|advert|komentar|copyright)\b",
    r"(?:\b[A-Z]{2,12}USDT\b.*?){2,}",
    r"\b\d+(?:[.,]\d+)?%\b",
    r"enter your email and we.?ll send you link to get back into your account",
]


def _slugify(text: str | None) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (text or "").strip().lower()).strip("-")
    return slug or "berita"


def _ensure_unique_berita_slug(base_text: str, source_url: str) -> str:
    base = _slugify(base_text)
    url_hint = _slugify(source_url)[:24]
    if url_hint:
        base = f"{base}-{url_hint}".strip("-")
    slug = base
    i = 2
    while mongo.db.berita.find_one({"slug": slug}) is not None:
        slug = f"{base}-{i}"
        i += 1
    return slug


def _supabase_news_slug(title: str, source_url: str) -> str:
    base = _slugify(title)[:80]
    digest = uuid.uuid5(uuid.NAMESPACE_URL, source_url).hex[:10]
    return f"{base}-{digest}".strip("-")


def _parse_datetime(value: str | None) -> datetime:
    if not value:
        return datetime.now(UTC).replace(tzinfo=None)
    try:
        dt = parsedate_to_datetime(value)
        if dt.tzinfo is not None:
            dt = dt.astimezone(UTC).replace(tzinfo=None)
        return dt
    except Exception:
        try:
            iso = value.replace("Z", "+00:00")
            dt = datetime.fromisoformat(iso)
            if dt.tzinfo is not None:
                dt = dt.astimezone(UTC).replace(tzinfo=None)
            return dt
        except Exception:
            return datetime.now(UTC).replace(tzinfo=None)


def _clean_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _is_noise_text(value: str) -> bool:
    text = (value or "").strip()
    if not text:
        return True
    for pattern in _NOISE_PATTERNS:
        if re.search(pattern, text, flags=re.IGNORECASE):
            return True
    return False


def _sanitize_text(value: str, fallback: str = "") -> str:
    text = _clean_text(value)
    return fallback if _is_noise_text(text) else text


def _normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip().lower())


def _get_text(node: ET.Element | None, tags: Iterable[str]) -> str:
    if node is None:
        return ""
    for tag in tags:
        found = node.find(tag)
        if found is not None and found.text:
            return found.text.strip()
    return ""


def _local_tag(tag: str) -> str:
    return tag.split("}", 1)[-1].lower()


def _find_first_text_by_local_tag(node: ET.Element | None, local_name: str) -> str:
    if node is None:
        return ""
    target = local_name.strip().lower()
    for child in node.iter():
        if _local_tag(child.tag) != target:
            continue
        if child.text and child.text.strip():
            return child.text.strip()
    return ""


def _extract_feed_image(node: ET.Element | None) -> str:
    if node is None:
        return ""

    for child in node.iter():
        tag = _local_tag(child.tag)
        attrs = {str(k).lower(): str(v).strip() for k, v in child.attrib.items()}
        if tag in {"thumbnail", "image"}:
            url = attrs.get("url") or attrs.get("href")
            if url:
                return url
        if tag in {"content", "enclosure"}:
            media_type = (attrs.get("type") or "").lower()
            if media_type.startswith("image/"):
                url = attrs.get("url") or attrs.get("href")
                if url:
                    return url
    return ""


def _extract_page_image(url: str, timeout_seconds: int = 20) -> str:
    normalized_url = (url or "").strip()
    if not normalized_url:
        return ""
    cached = _PAGE_IMAGE_CACHE.get(normalized_url)
    if cached is not None:
        return cached

    try:
        response = requests.get(
            normalized_url,
            timeout=timeout_seconds,
            headers={"User-Agent": "Mozilla/5.0 (compatible; AverroesBot/1.0)"},
        )
        response.raise_for_status()
        html = response.text or ""
        patterns = [
            r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']',
            r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']',
            r'<meta[^>]+name=["\']twitter:image["\'][^>]+content=["\']([^"\']+)["\']',
            r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']twitter:image["\']',
        ]
        for pattern in patterns:
            match = re.search(pattern, html, flags=re.IGNORECASE)
            if not match:
                continue
            image_url = unescape(match.group(1).strip())
            if image_url.startswith("http://") or image_url.startswith("https://"):
                _PAGE_IMAGE_CACHE[normalized_url] = image_url[:1024]
                return _PAGE_IMAGE_CACHE[normalized_url]
    except Exception as err:
        logger.debug("Gagal ambil og:image %s: %s", normalized_url, err)

    _PAGE_IMAGE_CACHE[normalized_url] = ""
    return ""


def _extract_summary(description: str, title: str, source_name: str) -> str:
    summary = _sanitize_text(description)
    if not summary:
        return ""

    normalized_summary = _normalize_text(summary)
    normalized_title = _normalize_text(title)
    normalized_source = _normalize_text(source_name)

    if normalized_summary == normalized_title:
        return ""
    if normalized_source and normalized_summary == normalized_source:
        return ""
    if normalized_title and normalized_summary.startswith(normalized_title):
        return ""
    return summary[:400]


def _iter_entries(root: ET.Element) -> list[dict]:
    entries: list[dict] = []
    items = root.findall(".//item")
    if items:
        for item in items:
            title = _sanitize_text(_get_text(item, ("title",)))
            link = _get_text(item, ("link",)).strip()
            description = _get_text(item, ("description", "summary", "content"))
            published = _get_text(item, ("pubDate", "published", "updated"))
            source_name = _sanitize_text(_find_first_text_by_local_tag(item, "source"))
            image_url = _extract_feed_image(item) or _extract_page_image(link)

            if not title or not link:
                continue

            summary = _extract_summary(description, title=title, source_name=source_name)
            entries.append(
                {
                    "judul": title[:255],
                    "sumber_url": link[:1024],
                    "sumber_nama": source_name[:255] if source_name else None,
                    "gambar_url": image_url[:1024] if image_url else None,
                    "ringkasan": summary,
                    "published_at": _parse_datetime(published),
                    "provider": "google_news" if "news.google.com" in link else "rss",
                    "updated_at": datetime.utcnow(),
                }
            )
        return entries

    atom_entries = root.findall(".//{http://www.w3.org/2005/Atom}entry")
    for item in atom_entries:
        title = _sanitize_text(_get_text(item, ("{http://www.w3.org/2005/Atom}title",)))
        link_node = item.find("{http://www.w3.org/2005/Atom}link")
        link = link_node.attrib.get("href", "").strip() if link_node is not None else ""
        summary_raw = _get_text(
            item,
            ("{http://www.w3.org/2005/Atom}summary", "{http://www.w3.org/2005/Atom}content"),
        )
        published = _get_text(
            item,
            ("{http://www.w3.org/2005/Atom}published", "{http://www.w3.org/2005/Atom}updated"),
        )
        source_name = _sanitize_text(_find_first_text_by_local_tag(item, "source"))
        image_url = _extract_feed_image(item) or _extract_page_image(link)

        if not title or not link:
            continue

        summary = _extract_summary(summary_raw, title=title, source_name=source_name)
        entries.append(
            {
                "judul": title[:255],
                "sumber_url": link[:1024],
                "sumber_nama": source_name[:255] if source_name else None,
                "gambar_url": image_url[:1024] if image_url else None,
                "ringkasan": summary,
                "published_at": _parse_datetime(published),
                "provider": "google_news" if "news.google.com" in link else "rss",
                "updated_at": datetime.utcnow(),
            }
        )
    return entries


def _fetch_feed(url: str, timeout_seconds: int = 20) -> list[dict]:
    req = Request(url, headers={"User-Agent": "AverroesBot/1.0 (+https://averroes.local)"})
    with urlopen(req, timeout=timeout_seconds) as resp:
        data = resp.read()
    root = ET.fromstring(data)
    return _iter_entries(root)


def _sync_news_items_to_supabase(items: list[dict]) -> int:
    from flask import current_app

    supabase_url = str(current_app.config.get("SUPABASE_URL") or "").strip().rstrip("/")
    service_role_key = str(current_app.config.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    if not supabase_url or not service_role_key or not items:
        return 0

    payload: list[dict] = []
    for item in items:
        source_url = str(item.get("sumber_url") or "").strip()
        title = str(item.get("judul") or "").strip()
        if not source_url or not title:
            continue
        payload.append(
            {
                "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"news:{source_url}")),
                "legacy_mongo_id": f"news:{uuid.uuid5(uuid.NAMESPACE_URL, source_url)}",
                "title": title[:255],
                "slug": _supabase_news_slug(title, source_url),
                "summary": str(item.get("ringkasan") or "").strip()[:400],
                "content": "",
                "source_url": source_url[:1024],
                "source_name": (str(item.get("sumber_nama") or "").strip() or None),
                "image_url": (str(item.get("gambar_url") or "").strip() or None),
                "provider": (str(item.get("provider") or "").strip() or "rss")[:64],
                "published_at": item.get("published_at").isoformat()
                if isinstance(item.get("published_at"), datetime)
                else None,
            }
        )

    if not payload:
        return 0

    response = requests.post(
        f"{supabase_url}/rest/v1/news_items",
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
        params={"on_conflict": "source_url"},
        json=payload,
        timeout=30,
    )
    response.raise_for_status()
    return len(payload)


def sync_berita_crypto(feeds: list[str], keep_latest: int = 20) -> dict:
    collected: list[dict] = []
    for feed_url in feeds:
        try:
            collected.extend(_fetch_feed(feed_url))
        except (URLError, ET.ParseError, TimeoutError) as err:
            logger.warning("Gagal fetch feed %s: %s", feed_url, err)
        except Exception as err:
            logger.exception("Error tidak terduga saat fetch feed %s: %s", feed_url, err)

    by_url: dict[str, dict] = {}
    for item in collected:
        url = str(item.get("sumber_url") or "").strip()
        if url and url not in by_url:
            by_url[url] = item

    unique_items = [item for item in by_url.values() if str(item.get("judul") or "").strip()]
    unique_items.sort(key=lambda x: x["published_at"], reverse=True)
    selected = unique_items[:keep_latest]
    supabase_synced = 0

    inserted = 0
    updated = 0
    for item in selected:
        exists = mongo.db.berita.find_one({"sumber_url": item["sumber_url"]})
        if exists:
            updates = {}
            for field in ("judul", "sumber_nama", "gambar_url", "ringkasan", "published_at", "provider", "updated_at"):
                new_value = item.get(field)
                old_value = exists.get(field)
                if new_value and new_value != old_value:
                    updates[field] = new_value

            unset_fields = {}
            if exists.get("konten") is not None:
                unset_fields["konten"] = ""
            if exists.get("konten_blocks") is not None:
                unset_fields["konten_blocks"] = ""

            if updates or unset_fields:
                update_doc: dict[str, dict] = {}
                if updates:
                    update_doc["$set"] = updates
                if unset_fields:
                    update_doc["$unset"] = unset_fields
                mongo.db.berita.update_one({"_id": exists["_id"]}, update_doc)
                updated += 1
            continue

        doc = {k: v for k, v in item.items() if v not in (None, "")}
        doc["slug"] = _ensure_unique_berita_slug(
            base_text=str(doc.get("judul") or "berita"),
            source_url=str(doc.get("sumber_url") or ""),
        )
        try:
            mongo.db.berita.insert_one(doc)
            inserted += 1
        except DuplicateKeyError:
            doc["slug"] = _ensure_unique_berita_slug(
                base_text=str(doc.get("judul") or "berita"),
                source_url=f"{doc.get('sumber_url')}-{time.time_ns()}",
            )
            mongo.db.berita.insert_one(doc)
            inserted += 1

    all_berita = list(mongo.db.berita.find().sort("published_at", -1))
    if len(all_berita) > keep_latest:
        ids_to_delete = [doc["_id"] for doc in all_berita[keep_latest:]]
        mongo.db.berita.delete_many({"_id": {"$in": ids_to_delete}})

    try:
        supabase_synced = _sync_news_items_to_supabase(selected)
    except Exception as err:
        logger.exception("Sinkronisasi news_items ke Supabase gagal: %s", err)

    return {
        "fetched": len(unique_items),
        "inserted": inserted,
        "updated": updated,
        "kept": min(len(all_berita), keep_latest),
        "supabase_synced": supabase_synced,
    }


def start_berita_scheduler(app) -> None:
    if not app.config.get("NEWS_SCRAPER_ENABLED", False):
        return

    feeds = app.config.get("NEWS_SCRAPER_FEEDS", [])
    interval = int(app.config.get("NEWS_SCRAPER_INTERVAL_SECONDS", 21600))
    limit = int(app.config.get("NEWS_SCRAPER_LIMIT", 20))
    run_on_startup = bool(app.config.get("NEWS_SCRAPER_RUN_ON_STARTUP", True))

    def _run_once():
        with app.app_context():
            try:
                result = sync_berita_crypto(feeds=feeds, keep_latest=limit)
                logger.info(
                    "Berita sync selesai. fetched=%s inserted=%s updated=%s kept=%s",
                    result["fetched"],
                    result["inserted"],
                    result.get("updated", 0),
                    result["kept"],
                )
            except Exception as err:
                logger.exception("Berita sync gagal: %s", err)

    def _loop():
        if run_on_startup:
            _run_once()
        while True:
            time.sleep(interval)
            _run_once()

    thread = threading.Thread(target=_loop, daemon=True, name="berita-scheduler")
    thread.start()
    logger.info("Scheduler berita aktif. interval=%ss limit=%s", interval, limit)
