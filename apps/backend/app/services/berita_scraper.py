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

from app.extensions import db
from app.models import Berita


logger = logging.getLogger(__name__)


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
            title = _get_text(item, ("title",))
            link = _get_text(item, ("link",))
            summary = _get_text(item, ("description", "summary", "content"))
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
        title = _get_text(item, ("{http://www.w3.org/2005/Atom}title",))
        link_node = item.find("{http://www.w3.org/2005/Atom}link")
        link = link_node.attrib.get("href", "").strip() if link_node is not None else ""
        summary = _get_text(
            item,
            ("{http://www.w3.org/2005/Atom}summary", "{http://www.w3.org/2005/Atom}content"),
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

    title = _find_meta(html, "og:title")
    if not title:
        m = re.search(r"<title>(.*?)</title>", html, flags=re.IGNORECASE | re.DOTALL)
        title = _clean_text(m.group(1)) if m else ""
    summary = _find_meta(html, "description") or _find_meta(html, "og:description") or title
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
        "konten": summary[:4000] or title[:255],
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

    unique_items = list(by_url.values())
    unique_items.sort(key=lambda x: x["published_at"], reverse=True)
    selected = unique_items[:keep_latest]

    inserted = 0
    updated = 0
    for item in selected:
        exists = Berita.query.filter_by(sumber_url=item["sumber_url"]).first()
        if exists:
            new_image = item.get("gambar_url")
            if new_image and not getattr(exists, "gambar_url", None):
                exists.gambar_url = new_image
                updated += 1
            continue
        db.session.add(Berita(**item))
        inserted += 1

    db.session.commit()

    # Keep only latest N rows.
    rows = Berita.query.order_by(Berita.published_at.desc(), Berita.id.desc()).all()
    for row in rows[keep_latest:]:
        db.session.delete(row)
    db.session.commit()

    return {
        "fetched": len(unique_items),
        "inserted": inserted,
        "updated": updated,
        "kept": min(len(rows), keep_latest),
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
            result = sync_berita_crypto(feeds=feeds, keep_latest=limit)
            logger.info(
                "Berita sync selesai. fetched=%s inserted=%s updated=%s kept=%s",
                result["fetched"],
                result["inserted"],
                result.get("updated", 0),
                result["kept"],
            )

    def _loop():
        if run_on_startup:
            _run_once()
        while True:
            time.sleep(interval)
            _run_once()

    thread = threading.Thread(target=_loop, daemon=True, name="berita-scheduler")
    thread.start()
    logger.info("Scheduler berita aktif. interval=%ss limit=%s", interval, limit)
