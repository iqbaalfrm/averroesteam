import logging
import re
import threading
import time
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from html import unescape
from urllib.parse import urljoin, urlparse
from typing import Iterable
from urllib.error import URLError
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET

from app.extensions import mongo
from pymongo.errors import DuplicateKeyError


logger = logging.getLogger(__name__)

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
    # Stabilizer so same title from different URL still gets deterministic unique slug.
    url_hint = _slugify(urlparse(source_url).path)[:24]
    if url_hint:
        base = f"{base}-{url_hint}".strip("-")
    slug = base
    i = 2
    while mongo.db.berita.find_one({"slug": slug}) is not None:
        slug = f"{base}-{i}"
        i += 1
    return slug


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


def _iter_entries(root: ET.Element) -> list[dict]:
    entries: list[dict] = []
    items = root.findall(".//item")
    if items:
        for item in items:
            title = _sanitize_text(_get_text(item, ("title",)))
            link = _get_text(item, ("link",))
            summary = _sanitize_text(_get_text(item, ("description", "summary", "content")))
            published = _get_text(item, ("pubDate", "published", "updated"))
            if title and link:
                entries.append(
                    {
                        "judul": title,
                        "sumber_url": link,
                        "gambar_url": _extract_feed_image(item),
                        "ringkasan": summary or title,
                        "konten": summary or title,
                        "published_at": _parse_datetime(published),
                    }
                )
        return entries

    # Atom fallback
    atom_entries = root.findall(".//{http://www.w3.org/2005/Atom}entry")
    for item in atom_entries:
        title = _sanitize_text(_get_text(item, ("{http://www.w3.org/2005/Atom}title",)))
        link_node = item.find("{http://www.w3.org/2005/Atom}link")
        link = link_node.attrib.get("href", "").strip() if link_node is not None else ""
        summary = _sanitize_text(
            _get_text(
                item,
                ("{http://www.w3.org/2005/Atom}summary", "{http://www.w3.org/2005/Atom}content"),
            )
        )
        published = _get_text(
            item,
            ("{http://www.w3.org/2005/Atom}published", "{http://www.w3.org/2005/Atom}updated"),
        )
        if title and link:
            entries.append(
                {
                    "judul": title,
                    "sumber_url": link,
                    "gambar_url": _extract_feed_image(item),
                    "ringkasan": summary or title,
                    "konten": summary or title,
                    "published_at": _parse_datetime(published),
                }
            )
    return entries


def _fetch_feed(url: str, timeout_seconds: int = 20) -> list[dict]:
    req = Request(url, headers={"User-Agent": "AverroesBot/1.0 (+https://averroes.local)"})
    with urlopen(req, timeout=timeout_seconds) as resp:
        data = resp.read()
    root = ET.fromstring(data)
    return _iter_entries(root)


def _fetch_html(url: str, timeout_seconds: int = 20) -> str:
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (AverroesBot/1.0)"})
    with urlopen(req, timeout=timeout_seconds) as resp:
        return resp.read().decode("utf-8", "ignore")


def _clean_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _is_noise_text(value: str) -> bool:
    text = (value or "").strip()
    if not text:
        return True
    for p in _NOISE_PATTERNS:
        if re.search(p, text, flags=re.IGNORECASE):
            return True
    return False


def _sanitize_text(value: str, fallback: str = "") -> str:
    text = _clean_text(value)
    return fallback if _is_noise_text(text) else text


def _find_meta(html: str, name_or_prop: str) -> str:
    # Matches: <meta property="og:title" content="..."> / <meta name="description" content="...">
    patterns = [
        rf'<meta[^>]+property=["\']{re.escape(name_or_prop)}["\'][^>]+content=["\']([^"\']+)["\']',
        rf'<meta[^>]+name=["\']{re.escape(name_or_prop)}["\'][^>]+content=["\']([^"\']+)["\']',
        rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']{re.escape(name_or_prop)}["\']',
        rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']{re.escape(name_or_prop)}["\']',
    ]
    for p in patterns:
        m = re.search(p, html, flags=re.IGNORECASE)
        if m:
            return _clean_text(m.group(1))
    return ""


def _extract_cryptowave_body_text(html: str) -> str:
    scopes: list[str] = []
    article_match = re.search(r"<article[^>]*>(.*?)</article>", html, flags=re.IGNORECASE | re.DOTALL)
    if article_match:
        scopes.append(article_match.group(1))
    main_match = re.search(r"<main[^>]*>(.*?)</main>", html, flags=re.IGNORECASE | re.DOTALL)
    if main_match:
        scopes.append(main_match.group(1))
    scopes.append(html)

    for scope in scopes:
        paras = re.findall(r"<p[^>]*>(.*?)</p>", scope, flags=re.IGNORECASE | re.DOTALL)
        clean_paras: list[str] = []
        for p in paras:
            t = _clean_text(p)
            if len(t) < 40:
                continue
            # Buang noise umum tombol/share/nav.
            if re.search(r"(baca juga|share|komentar|tags?|iklan)", t, flags=re.IGNORECASE):
                continue
            if _is_noise_text(t):
                continue
            clean_paras.append(t)
        if len(clean_paras) >= 2:
            return "\n\n".join(clean_paras[:24])[:12000]
    return ""


def _extract_cryptowave_links(html: str, base_url: str) -> list[str]:
    links = re.findall(r'href=["\']([^"\']+)["\']', html, flags=re.IGNORECASE)
    out: list[str] = []
    seen: set[str] = set()
    for link in links:
        if "${" in link or "`" in link:
            continue
        abs_url = urljoin(base_url, link)
        parsed = urlparse(abs_url)
        if parsed.netloc not in {"cryptowave.co.id", "www.cryptowave.co.id"}:
            continue
        if "/articles/" not in parsed.path:
            continue
        normalized = f"{parsed.scheme}://{parsed.netloc}{parsed.path}".rstrip("/")
        if normalized in seen:
            continue
        seen.add(normalized)
        out.append(normalized)
    return out


def _fetch_cryptowave_article(url: str) -> dict | None:
    try:
        html = _fetch_html(url)
    except Exception as err:
        logger.warning("Gagal fetch artikel cryptowave %s: %s", url, err)
        return None

    title = _sanitize_text(_find_meta(html, "og:title"))
    if not title:
        m = re.search(r"<title>(.*?)</title>", html, flags=re.IGNORECASE | re.DOTALL)
        title = _sanitize_text(_clean_text(m.group(1)) if m else "")
    summary = (
        _sanitize_text(_find_meta(html, "description"))
        or _sanitize_text(_find_meta(html, "og:description"))
        or title
    )
    body = _extract_cryptowave_body_text(html)
    published_raw = _find_meta(html, "article:published_time")
    image_url = (
        _find_meta(html, "og:image")
        or _find_meta(html, "twitter:image")
        or _find_meta(html, "twitter:image:src")
    )
    if image_url:
        image_url = urljoin(url, image_url)

    if not title:
        return None

    return {
        "judul": title[:255],
        "sumber_url": url,
        "gambar_url": image_url[:1024] if image_url else None,
        "ringkasan": summary[:2000] or title[:255],
        "konten": (body[:12000] if body else summary[:4000]) or title[:255],
        "published_at": _parse_datetime(published_raw),
    }


def _fetch_cryptowave_items(base_url: str, limit: int = 20, max_pages: int = 4) -> list[dict]:
    article_urls: list[str] = []
    seen: set[str] = set()

    for page in range(1, max_pages + 1):
        page_url = base_url if page == 1 else f"{base_url.rstrip('/')}/?page={page}"
        try:
            html = _fetch_html(page_url)
        except Exception as err:
            logger.warning("Gagal fetch halaman cryptowave %s: %s", page_url, err)
            continue

        for link in _extract_cryptowave_links(html, base_url):
            if link in seen:
                continue
            seen.add(link)
            article_urls.append(link)
            if len(article_urls) >= limit:
                break
        if len(article_urls) >= limit:
            break

    items: list[dict] = []
    for article_url in article_urls[:limit]:
        item = _fetch_cryptowave_article(article_url)
        if item:
            items.append(item)
    items.sort(key=lambda x: x["published_at"], reverse=True)
    return items


def sync_berita_crypto(feeds: list[str], keep_latest: int = 20) -> dict:
    collected: list[dict] = []
    provider = ""
    if feeds and "cryptowave.co.id" in feeds[0]:
        provider = "cryptowave"

    if provider == "cryptowave":
        collected.extend(_fetch_cryptowave_items(base_url=feeds[0], limit=keep_latest))
    else:
        for feed_url in feeds:
            try:
                collected.extend(_fetch_feed(feed_url))
            except (URLError, ET.ParseError, TimeoutError) as err:
                logger.warning("Gagal fetch feed %s: %s", feed_url, err)
            except Exception as err:
                logger.exception("Error tidak terduga saat fetch feed %s: %s", feed_url, err)

    by_url: dict[str, dict] = {}
    for item in collected:
        if item["sumber_url"] not in by_url:
            by_url[item["sumber_url"]] = item

    unique_items = [item for item in by_url.values() if str(item.get("judul") or "").strip()]
    unique_items.sort(key=lambda x: x["published_at"], reverse=True)
    selected = unique_items[:keep_latest]

    inserted = 0
    updated = 0
    for item in selected:
        exists = mongo.db.berita.find_one({"sumber_url": item["sumber_url"]})
        if exists:
            updates = {}
            new_image = item.get("gambar_url")
            if new_image and not exists.get("gambar_url"):
                updates["gambar_url"] = new_image
            new_summary = (item.get("ringkasan") or "").strip()
            old_summary = (exists.get("ringkasan") or "").strip()
            if new_summary and (
                len(new_summary) > len(old_summary) or _is_noise_text(old_summary)
            ):
                updates["ringkasan"] = new_summary
            new_content = (item.get("konten") or "").strip()
            old_content = (exists.get("konten") or "").strip()
            if new_content and (
                len(new_content) > len(old_content) or _is_noise_text(old_content)
            ):
                updates["konten"] = new_content
            new_published = item.get("published_at")
            if new_published and not exists.get("published_at"):
                updates["published_at"] = new_published
            if updates:
                mongo.db.berita.update_one({"_id": exists["_id"]}, {"$set": updates})
                updated += 1
            continue
        if not item.get("slug"):
            item["slug"] = _ensure_unique_berita_slug(
                base_text=str(item.get("judul") or "berita"),
                source_url=str(item.get("sumber_url") or ""),
            )
        try:
            mongo.db.berita.insert_one(item)
            inserted += 1
        except DuplicateKeyError:
            # Race-safe fallback if slug was taken between find and insert.
            item["slug"] = _ensure_unique_berita_slug(
                base_text=str(item.get("judul") or "berita"),
                source_url=f"{item.get('sumber_url')}-{time.time_ns()}",
            )
            mongo.db.berita.insert_one(item)
            inserted += 1

    # Keep only latest N rows.
    all_berita = list(mongo.db.berita.find().sort("published_at", -1))
    if len(all_berita) > keep_latest:
        ids_to_delete = [doc["_id"] for doc in all_berita[keep_latest:]]
        mongo.db.berita.delete_many({"_id": {"$in": ids_to_delete}})

    return {
        "fetched": len(unique_items),
        "inserted": inserted,
        "updated": updated,
        "kept": min(len(all_berita), keep_latest),
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
