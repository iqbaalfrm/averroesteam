from __future__ import annotations

import argparse
import json
import logging
import re
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from html import unescape
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlparse
from xml.etree import ElementTree as ET

import requests


LOGGER = logging.getLogger("averroes.vps_news_sync")
IMAGE_CACHE: dict[str, str] = {}
GOOGLE_NEWS_HOST = "news.google.com"
USER_AGENT = "Mozilla/5.0 (compatible; AverroesNewsSync/1.0)"


@dataclass(slots=True)
class NewsItem:
    title: str
    source_url: str
    original_feed_url: str
    source_name: str | None
    summary: str
    image_url: str | None
    provider: str
    published_at: datetime


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def parse_datetime(value: str | None) -> datetime:
    if not value:
        return datetime.now(UTC)
    try:
        dt = parsedate_to_datetime(value)
        if dt.tzinfo is None:
            return dt.replace(tzinfo=UTC)
        return dt.astimezone(UTC)
    except Exception:
        try:
            iso = value.replace("Z", "+00:00")
            dt = datetime.fromisoformat(iso)
            if dt.tzinfo is None:
                return dt.replace(tzinfo=UTC)
            return dt.astimezone(UTC)
        except Exception:
            return datetime.now(UTC)


def clean_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def slugify(text: str | None) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", (text or "").strip().lower()).strip("-")
    return value or "berita"


def supabase_news_slug(title: str, source_url: str) -> str:
    digest = uuid.uuid5(uuid.NAMESPACE_URL, source_url).hex[:10]
    return f"{slugify(title)[:80]}-{digest}".strip("-")


def get_text(node: ET.Element | None, tags: tuple[str, ...]) -> str:
    if node is None:
        return ""
    for tag in tags:
        found = node.find(tag)
        if found is not None and found.text:
            return found.text.strip()
    return ""


def local_tag(tag: str) -> str:
    return tag.split("}", 1)[-1].lower()


def find_first_text_by_local_tag(node: ET.Element | None, local_name: str) -> str:
    if node is None:
        return ""
    target = local_name.strip().lower()
    for child in node.iter():
        if local_tag(child.tag) == target and child.text and child.text.strip():
            return child.text.strip()
    return ""


def fetch_url(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    data: str | bytes | None = None,
    timeout_seconds: int = 30,
    attempts: int = 2,
) -> requests.Response:
    last_error: Exception | None = None
    for attempt in range(1, max(attempts, 1) + 1):
        try:
            response = requests.request(
                method,
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "*/*",
                    **(headers or {}),
                },
                data=data,
                timeout=timeout_seconds,
            )
            response.raise_for_status()
            return response
        except Exception as error:
            last_error = error
            if attempt >= max(attempts, 1):
                break
            time.sleep(1.0 * attempt)
    if last_error is not None:
        raise last_error
    raise RuntimeError(f"Gagal mengakses URL: {url}")


def extract_google_article_id(url: str) -> str | None:
    parsed = urlparse(url)
    if GOOGLE_NEWS_HOST not in parsed.netloc:
        return None
    parts = [part for part in parsed.path.split("/") if part]
    if len(parts) < 3:
        return None
    if parts[-2] != "articles":
        return None
    return parts[-1]


def extract_google_decode_params(article_id: str) -> tuple[str, str] | None:
    article_url = f"https://news.google.com/rss/articles/{article_id}"
    html = fetch_url(article_url, timeout_seconds=20).text
    timestamp_match = re.search(r'data-n-a-ts="([^"]+)"', html)
    signature_match = re.search(r'data-n-a-sg="([^"]+)"', html)
    if not timestamp_match or not signature_match:
        return None
    return timestamp_match.group(1), signature_match.group(1)


def decode_google_news_url(url: str) -> str:
    article_id = extract_google_article_id(url)
    if not article_id:
        return url

    params = extract_google_decode_params(article_id)
    if not params:
        return url

    timestamp, signature = params
    rpc_payload = [[
        "Fbv4je",
        (
            '["garturlreq",'
            '[[\"X\",\"X\",[\"X\",\"X\"],null,null,1,1,\"US:en\",null,1,null,null,null,null,null,0,1],'
            '\"X\",\"X\",1,[1,1,1],1,1,null,0,0,null,0],'
            f'"{article_id}",{timestamp},"{signature}"]'
        ),
    ]]
    body = f"f.req={quote(json.dumps([rpc_payload], separators=(',', ':')))}"
    response = fetch_url(
        "https://news.google.com/_/DotsSplashUi/data/batchexecute?rpcids=Fbv4je",
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "Referer": "https://news.google.com/",
        },
        data=body,
        timeout_seconds=20,
    )
    raw = response.text
    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith("[["):
            continue
        try:
            parsed = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not parsed or not isinstance(parsed, list):
            continue
        payload = parsed[0]
        if not isinstance(payload, list) or len(payload) < 3:
            continue
        inner = payload[2]
        if not isinstance(inner, str):
            continue
        decoded = json.loads(inner)
        if isinstance(decoded, list) and len(decoded) > 1 and isinstance(decoded[1], str):
            return decoded[1]
    return url


def extract_page_image(url: str) -> str:
    normalized_url = url.strip()
    if not normalized_url:
        return ""
    cached = IMAGE_CACHE.get(normalized_url)
    if cached is not None:
        return cached

    try:
        html = fetch_url(normalized_url, timeout_seconds=10).text
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
            if image_url.startswith(("http://", "https://")):
                IMAGE_CACHE[normalized_url] = image_url[:1024]
                return IMAGE_CACHE[normalized_url]
    except Exception as error:
        LOGGER.debug("Gagal ambil og:image %s: %s", normalized_url, error)

    IMAGE_CACHE[normalized_url] = ""
    return ""


def normalize_source_name(title: str, source_name: str | None, source_url: str) -> str | None:
    cleaned = clean_text(source_name or "")
    if cleaned:
        return cleaned[:255]

    if " - " in title:
        possible = title.rsplit(" - ", 1)[-1].strip()
        if possible and len(possible) <= 64:
            return possible[:255]

    hostname = urlparse(source_url).netloc.lower()
    if hostname.startswith("www."):
        hostname = hostname[4:]
    return hostname or None


def extract_summary(description: str, title: str, source_name: str | None) -> str:
    summary = clean_text(description)
    if not summary:
        return ""
    normalized_summary = summary.lower()
    normalized_title = clean_text(title).lower()
    normalized_source = clean_text(source_name or "").lower()
    if normalized_summary == normalized_title:
        return ""
    if normalized_source and normalized_summary == normalized_source:
        return ""
    if normalized_title and normalized_summary.startswith(normalized_title):
        return ""
    return summary[:400]


def build_news_items(feed_url: str, *, max_items: int) -> list[NewsItem]:
    response = fetch_url(feed_url, timeout_seconds=25)
    root = ET.fromstring(response.content)
    items = root.findall(".//item")
    out: list[NewsItem] = []
    for item in items:
        if len(out) >= max_items:
            break
        title = clean_text(get_text(item, ("title",)))
        google_link = get_text(item, ("link",)).strip()
        description = get_text(item, ("description",))
        published_at = parse_datetime(get_text(item, ("pubDate", "published", "updated")))
        feed_source = find_first_text_by_local_tag(item, "source")
        if not title or not google_link:
            continue

        resolved_url = google_link
        provider = "rss"
        try:
            if GOOGLE_NEWS_HOST in urlparse(google_link).netloc:
                resolved_url = decode_google_news_url(google_link)
                provider = "google_news_resolved" if resolved_url != google_link else "google_news"
        except Exception as error:
            LOGGER.warning("Gagal resolve Google News URL %s: %s", google_link, error)

        source_name = normalize_source_name(title, feed_source, resolved_url)
        image_url = extract_page_image(resolved_url)
        summary = extract_summary(description, title, source_name)
        out.append(
            NewsItem(
                title=title[:255],
                source_url=resolved_url[:1024],
                original_feed_url=google_link[:1024],
                source_name=source_name,
                summary=summary,
                image_url=image_url[:1024] if image_url else None,
                provider=provider[:64],
                published_at=published_at,
            )
        )
    return out


def dedupe_and_trim(items: list[NewsItem], keep_latest: int) -> list[NewsItem]:
    unique: dict[str, NewsItem] = {}
    for item in items:
        if item.source_url and item.source_url not in unique:
            unique[item.source_url] = item
    rows = list(unique.values())
    rows.sort(key=lambda item: item.published_at, reverse=True)
    return rows[:keep_latest]


def sync_to_supabase(items: list[NewsItem], *, supabase_url: str, service_role_key: str) -> int:
    payload: list[dict[str, Any]] = []
    for item in items:
        payload.append(
            {
                "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"news:{item.source_url}")),
                "legacy_mongo_id": f"news:{uuid.uuid5(uuid.NAMESPACE_URL, item.source_url)}",
                "title": item.title,
                "slug": supabase_news_slug(item.title, item.source_url),
                "summary": item.summary,
                "content": "",
                "source_url": item.source_url,
                "source_name": item.source_name,
                "image_url": item.image_url,
                "provider": item.provider,
                "published_at": item.published_at.isoformat(),
            }
        )
    if not payload:
        return 0

    response = requests.post(
        f"{supabase_url.rstrip('/')}/rest/v1/news_items",
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
    cleanup_google_news_rows(
        items,
        supabase_url=supabase_url,
        service_role_key=service_role_key,
    )
    return len(payload)


def cleanup_google_news_rows(
    items: list[NewsItem],
    *,
    supabase_url: str,
    service_role_key: str,
) -> None:
    google_urls = sorted(
        {
            item.original_feed_url
            for item in items
            if item.original_feed_url
            and item.original_feed_url != item.source_url
            and GOOGLE_NEWS_HOST in urlparse(item.original_feed_url).netloc
        }
    )
    for google_url in google_urls:
        response = requests.delete(
            f"{supabase_url.rstrip('/')}/rest/v1/news_items",
            headers={
                "apikey": service_role_key,
                "Authorization": f"Bearer {service_role_key}",
                "Prefer": "return=minimal",
            },
            params={
                "source_url": f"eq.{google_url}",
            },
            timeout=20,
        )
        response.raise_for_status()


def run_once(*, env: dict[str, str], limit_override: int | None = None) -> int:
    supabase_url = env.get("SUPABASE_URL", "").strip()
    service_role_key = env.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not supabase_url or not service_role_key:
        raise SystemExit("SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY wajib diisi.")

    feeds_raw = env.get(
        "NEWS_SYNC_FEEDS",
        "https://news.google.com/rss/search?q=crypto&hl=id&gl=ID&ceid=ID:id",
    )
    feeds = [feed.strip() for feed in feeds_raw.split(",") if feed.strip()]
    keep_latest = max(limit_override or int(env.get("NEWS_SYNC_LIMIT", "20")), 1)

    collected: list[NewsItem] = []
    candidate_limit = min(max(keep_latest * 2, keep_latest), 40)
    for feed_url in feeds:
        LOGGER.info("Fetch feed: %s", feed_url)
        try:
            collected.extend(build_news_items(feed_url, max_items=candidate_limit))
        except Exception as error:
            LOGGER.exception("Gagal proses feed %s: %s", feed_url, error)

    selected = dedupe_and_trim(collected, keep_latest=keep_latest)
    synced = sync_to_supabase(
        selected,
        supabase_url=supabase_url,
        service_role_key=service_role_key,
    )
    LOGGER.info("Sinkronisasi selesai. %s berita tersimpan ke Supabase.", synced)
    return synced


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync Google News RSS ke Supabase news_items.")
    parser.add_argument(
        "--env-file",
        default=str(Path(__file__).resolve().parent / ".env"),
        help="Path ke file environment untuk worker VPS.",
    )
    parser.add_argument(
        "--loop",
        action="store_true",
        help="Jalankan worker terus-menerus sesuai interval.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Aktifkan log debug.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Override jumlah berita yang disinkronkan untuk sekali jalan.",
    )
    args = parser.parse_args()

    configure_logging(args.verbose)
    env = load_env_file(Path(args.env_file))
    if args.loop:
        interval_seconds = max(int(env.get("NEWS_SYNC_INTERVAL_SECONDS", "1800")), 60)
        while True:
            try:
                run_once(env=env, limit_override=args.limit)
            except Exception as error:
                LOGGER.exception("Sync berita gagal: %s", error)
            time.sleep(interval_seconds)
        return

    run_once(env=env, limit_override=args.limit)


if __name__ == "__main__":
    main()
