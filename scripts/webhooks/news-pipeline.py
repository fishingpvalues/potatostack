#!/usr/bin/env python3
"""News pipeline: fetch RSS feeds + crawl NW.de, extract full text, serve combined RSS feed."""

import hashlib
import json
import logging
import os
import re
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from http.server import HTTPServer, BaseHTTPRequestHandler
from xml.sax.saxutils import escape

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("news-pipeline")

EXTRACTOR_URL = os.environ.get("EXTRACTOR_URL", "http://article-extractor:8084")
INTERVAL = int(os.environ.get("INTERVAL_SECONDS", "900"))
NW_INTERVAL = int(os.environ.get("NW_INTERVAL_SECONDS", "300"))

# Miniflux DB purge settings
MINIFLUX_DB_URL = os.environ.get("MINIFLUX_DB_URL", "")
PURGE_READ_DAYS = int(os.environ.get("PURGE_READ_DAYS", "7"))
PURGE_UNREAD_DAYS = int(os.environ.get("PURGE_UNREAD_DAYS", "30"))
PURGE_INTERVAL_HOURS = int(os.environ.get("PURGE_INTERVAL_HOURS", "6"))
_last_purge: float = 0

# RSS/Atom feeds to fetch directly
# extract=True means try full-text extraction via article-extractor
# extract=False means use RSS description as-is (for hard paywalls where extraction always fails)
# cat: category for grouping feeds (news, work, gaming)
RSS_FEEDS = [
    # German news
    {"url": "https://www.faz.net/rss/aktuell/", "source": "FAZ", "extract": True, "cat": "news"},
    {"url": "https://www.westfalen-blatt.de/rss/feed?subcategory=/owl/bielefeld", "source": "WB", "extract": False, "cat": "news"},
    {"url": "https://www.nzz.ch/recent.rss", "source": "NZZ", "extract": True, "cat": "news"},
    {"url": "https://www.welt.de/feeds/latest.rss", "source": "WELT", "extract": True, "cat": "news"},
    {"url": "https://www.cicero.de/rss.xml", "source": "CICERO", "extract": True, "cat": "news"},
    {"url": "https://www.tichyseinblick.de/feed/", "source": "TE", "extract": True, "cat": "news"},
    # English news
    {"url": "https://www.nationalreview.com/feed/", "source": "NR", "extract": True, "cat": "news"},
    # Gaming
    {"url": "https://www.hltv.org/rss/news", "source": "HLTV", "extract": False, "cat": "gaming"},
    # Work / AI & ML
    {"url": "https://blog.vllm.ai/feed.xml", "source": "VLLM", "extract": False, "cat": "work"},
    {"url": "https://huggingface.co/blog/feed.xml", "source": "HF", "extract": False, "cat": "work"},
    {"url": "https://pytorch.org/blog/feed/", "source": "PYTORCH", "extract": False, "cat": "work"},
    {"url": "https://blog.langchain.com/rss/", "source": "LANGCHAIN", "extract": False, "cat": "work"},
    {"url": "https://thegradient.pub/rss/", "source": "GRADIENT", "extract": False, "cat": "work"},
    {"url": "https://simonwillison.net/atom/everything/", "source": "WILLISON", "extract": False, "cat": "work"},
]

# NW.de sections to crawl (no RSS available)
NW_SECTIONS = [
    "https://www.nw.de/lokal/kreis_paderborn",
    "https://www.nw.de/lokal/bielefeld",
    "https://www.nw.de/lokal/kreis_guetersloh",
    "https://www.nw.de/lokal/kreis_hoexter",
    "https://www.nw.de/lokal/kreis_minden_luebbecke",
    "https://www.nw.de/lokal/kreis_herford",
    "https://www.nw.de/lokal/kreis_lippe",
]

# Combined feed items: list of {title, url, content, source, published, guid}
_feed_items: list[dict] = []
_feed_lock = threading.Lock()
_FEED_MAX = 2000
# Track seen URLs to avoid duplicates
_seen_urls: set[str] = set()
_SEEN_MAX = 15000


# ---------------------------------------------------------------------------
# HTML parsers
# ---------------------------------------------------------------------------


class LinkExtractor(HTMLParser):
    """Extract article links from NW.de section pages."""

    def __init__(self):
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href", "")
            if href and re.match(r"https?://www\.nw\.de/lokal/.+\.html$", href):
                if href not in self.links:
                    self.links.append(href)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def api_request(url, method="GET", data=None, headers=None):
    """Make an HTTP request and return parsed JSON (or None on error)."""
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None
    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as exc:
        log.error("Request %s %s failed: %s", method, url, exc)
        return None


def fetch_url(url):
    """Fetch raw content from a URL."""
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, OSError) as exc:
        log.error("Failed to fetch %s: %s", url, exc)
        return None


def extract_article(entry_url):
    """Call article-extractor for full-text extraction. Returns {title, content} or None."""
    result = api_request(
        f"{EXTRACTOR_URL}/extract", method="POST", data={"url": entry_url}
    )
    if result and result.get("content"):
        return result
    return None


def make_guid(url):
    """Generate a stable GUID from a URL."""
    return hashlib.sha256(url.encode()).hexdigest()[:16]


def strip_cdata(text):
    """Remove CDATA wrappers."""
    text = re.sub(r"<!\[CDATA\[", "", text)
    text = re.sub(r"\]\]>", "", text)
    return text.strip()


def strip_html_tags(html):
    """Remove HTML tags, keep text."""
    return re.sub(r"<[^>]+>", "", html).strip()


# ---------------------------------------------------------------------------
# RSS feed server
# ---------------------------------------------------------------------------


def build_combined_rss():
    """Generate RSS XML from all feed items."""
    return _build_rss_xml("PotatoStack News", "https://potatostack.tale-iwato.ts.net", lambda _: True)


def _build_rss_xml(title, link, filter_fn):
    """Generate RSS XML with items matching filter_fn."""
    items = []
    with _feed_lock:
        for item in _feed_items:
            if not filter_fn(item):
                continue
            src = item.get("source", "")
            item_title = f"[{src}] {item['title']}" if src else item["title"]
            items.append(
                f"<item>"
                f"<title>{escape(item_title)}</title>"
                f"<link>{escape(item['url'])}</link>"
                f"<guid isPermaLink=\"false\">{item['guid']}</guid>"
                f"<pubDate>{item['published']}</pubDate>"
                f"<description><![CDATA[{item.get('content', '')}]]></description>"
                f"</item>"
            )
    items_xml = "\n".join(items)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<rss version="2.0">\n<channel>\n'
        f"<title>{escape(title)}</title>\n"
        f"<link>{escape(link)}</link>\n"
        f"<description>{escape(title)}</description>\n"
        f"{items_xml}\n"
        "</channel>\n</rss>"
    )


def build_source_rss(source, title, link):
    """Generate RSS XML filtered to a single source."""
    return _build_rss_xml(title, link, lambda item: item.get("source") == source)


def build_category_rss(cat_name, sources):
    """Generate RSS XML filtered to a category (list of sources)."""
    title = f"PotatoStack - {cat_name.title()}"
    return _build_rss_xml(title, "https://potatostack.tale-iwato.ts.net", lambda item: item.get("source") in sources)


# Source slug -> (title, link)
_SOURCE_META = {
    "faz": ("FAZ", "https://www.faz.net"),
    "wb": ("Westfalen-Blatt", "https://www.westfalen-blatt.de"),
    "nzz": ("NZZ", "https://www.nzz.ch"),
    "welt": ("Welt", "https://www.welt.de"),
    "cicero": ("Cicero", "https://www.cicero.de"),
    "te": ("Tichys Einblick", "https://www.tichyseinblick.de"),
    "nr": ("National Review", "https://www.nationalreview.com"),
    "hltv": ("HLTV", "https://www.hltv.org"),
    "nw": ("NW.de", "https://www.nw.de"),
    "vllm": ("vLLM", "https://blog.vllm.ai"),
    "hf": ("Hugging Face", "https://huggingface.co"),
    "pytorch": ("PyTorch", "https://pytorch.org"),
    "langchain": ("LangChain", "https://blog.langchain.com"),
    "gradient": ("The Gradient", "https://thegradient.pub"),
    "willison": ("Simon Willison", "https://simonwillison.net"),
}

# Category -> list of source slugs (uppercase to match feed item source field)
_CATEGORIES = {
    "news": ["FAZ", "WB", "NZZ", "WELT", "CICERO", "TE", "NR", "NW"],
    "work": ["VLLM", "HF", "PYTORCH", "LANGCHAIN", "GRADIENT", "WILLISON"],
    "gaming": ["HLTV"],
}


class FeedHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.rstrip("/").lower()

        if path in ("", "/rss", "/feed"):
            body = build_combined_rss().encode("utf-8")
            self._respond(200, "application/rss+xml; charset=utf-8", body)
        elif path.startswith("/rss/cat/"):
            cat = path.split("/rss/cat/", 1)[1]
            sources = _CATEGORIES.get(cat)
            if sources:
                body = build_category_rss(cat, sources).encode("utf-8")
                self._respond(200, "application/rss+xml; charset=utf-8", body)
            else:
                self.send_error(404)
        elif path.startswith("/rss/"):
            slug = path.split("/rss/", 1)[1]
            meta = _SOURCE_META.get(slug)
            if meta:
                body = build_source_rss(slug.upper(), meta[0], meta[1]).encode("utf-8")
                self._respond(200, "application/rss+xml; charset=utf-8", body)
            else:
                self.send_error(404)
        elif path == "/health":
            body = json.dumps({"status": "ok", "items": len(_feed_items)}).encode()
            self._respond(200, "application/json", body)
        else:
            self.send_error(404)

    def _respond(self, code, content_type, body):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


def start_feed_server():
    """Start RSS feed server in background thread."""
    server = HTTPServer(("0.0.0.0", 8085), FeedHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    log.info("Combined RSS feed server started on :8085")


# ---------------------------------------------------------------------------
# Feed item management
# ---------------------------------------------------------------------------


def _parse_pub_timestamp(pub_date_str):
    """Parse RFC 2822 date string to UTC timestamp for sorting. Returns 0 on failure."""
    try:
        return parsedate_to_datetime(pub_date_str).timestamp()
    except Exception:
        return 0


def add_feed_item(title, url, content, source, pub_date=None):
    """Add an item to the combined feed, sorted by publication date (newest first)."""
    global _feed_items

    if url in _seen_urls:
        return

    _seen_urls.add(url)

    if not pub_date:
        pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")

    item = {
        "title": title,
        "url": url,
        "content": content,
        "source": source,
        "published": pub_date,
        "guid": make_guid(url),
        "_ts": _parse_pub_timestamp(pub_date),
    }

    with _feed_lock:
        _feed_items.append(item)
        _feed_items.sort(key=lambda x: x["_ts"], reverse=True)
        if len(_feed_items) > _FEED_MAX:
            _feed_items[:] = _feed_items[:_FEED_MAX]


# ---------------------------------------------------------------------------
# RSS feed processing
# ---------------------------------------------------------------------------


def _iso_to_rfc2822(iso_str):
    """Convert ISO 8601 date to RFC 2822 format."""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return dt.strftime("%a, %d %b %Y %H:%M:%S %z")
    except Exception:
        return ""


def parse_rss_items(xml_text):
    """Parse RSS or Atom XML and return list of {title, url, pub_date, description}."""
    items = []

    # Detect Atom format
    is_atom = "<feed" in xml_text[:500] and "xmlns=\"http://www.w3.org/2005/Atom\"" in xml_text[:500]

    if is_atom:
        for entry_match in re.finditer(r"<entry>(.*?)</entry>", xml_text, re.DOTALL):
            entry_xml = entry_match.group(1)

            title_m = re.search(r"<title[^>]*>(.*?)</title>", entry_xml, re.DOTALL)
            link_m = re.search(r'<link[^>]*href="([^"]+)"', entry_xml)
            pub_m = re.search(r"<published>(.*?)</published>", entry_xml, re.DOTALL)
            if not pub_m:
                pub_m = re.search(r"<updated>(.*?)</updated>", entry_xml, re.DOTALL)
            summary_m = re.search(r"<summary[^>]*>(.*?)</summary>", entry_xml, re.DOTALL)
            if not summary_m:
                summary_m = re.search(r"<content[^>]*>(.*?)</content>", entry_xml, re.DOTALL)

            title = strip_cdata(strip_html_tags(title_m.group(1))) if title_m else ""
            url = link_m.group(1).strip() if link_m else ""
            pub_date = _iso_to_rfc2822(pub_m.group(1).strip()) if pub_m else ""
            description = strip_cdata(summary_m.group(1)) if summary_m else ""

            if url:
                items.append({"title": title, "url": url, "pub_date": pub_date, "description": description})
    else:
        for item_match in re.finditer(r"<item>(.*?)</item>", xml_text, re.DOTALL):
            item_xml = item_match.group(1)

            title_m = re.search(r"<title>(.*?)</title>", item_xml, re.DOTALL)
            link_m = re.search(r"<link>(.*?)</link>", item_xml, re.DOTALL)
            pub_m = re.search(r"<pubDate>(.*?)</pubDate>", item_xml, re.DOTALL)
            desc_m = re.search(r"<description>(.*?)</description>", item_xml, re.DOTALL)

            title = strip_cdata(title_m.group(1)) if title_m else ""
            url = strip_cdata(link_m.group(1)).strip() if link_m else ""
            pub_date = strip_cdata(pub_m.group(1)) if pub_m else ""
            description = strip_cdata(desc_m.group(1)) if desc_m else ""

            title = strip_html_tags(title)

            if url:
                items.append({"title": title, "url": url, "pub_date": pub_date, "description": description})

    return items


def process_rss_feeds():
    """Fetch all RSS feeds, extract full text, add to combined feed."""
    for feed in RSS_FEEDS:
        feed_url = feed["url"]
        source = feed["source"]

        xml = fetch_url(feed_url)
        if not xml:
            log.error("Failed to fetch RSS: %s", feed_url)
            continue

        items = parse_rss_items(xml)
        new_items = [i for i in items if i["url"] not in _seen_urls]

        if not new_items:
            log.info("%s: no new articles", source)
            continue

        log.info("%s: %d new articles", source, len(new_items))

        do_extract = feed.get("extract", True)

        for item in new_items:
            url = item["url"]
            title = item["title"]
            content = ""

            if do_extract:
                result = extract_article(url)
                if result and result.get("content"):
                    content = result["content"]
                    if result.get("title"):
                        title = result["title"]

            if not content:
                content = item.get("description", "")

            add_feed_item(title, url, content, source, item.get("pub_date"))


# ---------------------------------------------------------------------------
# NW.de crawler
# ---------------------------------------------------------------------------


def process_nw_articles():
    """Crawl NW.de sections, extract articles, add to combined feed."""
    all_new = []
    for section in NW_SECTIONS:
        html = fetch_url(section)
        if not html:
            continue
        parser = LinkExtractor()
        parser.feed(html)
        new_urls = [u for u in parser.links if u not in _seen_urls]
        all_new.extend(new_urls)

    if not all_new:
        log.info("NW.de: no new articles")
        return

    log.info("NW.de: found %d new articles", len(all_new))

    for url in all_new:
        result = extract_article(url)

        if result and result.get("content"):
            content = result["content"]
            title = result.get("title", "")
        else:
            content = ""
            title = ""

        if not title:
            m = re.search(r"/\d+_(.+)\.html$", url)
            if m:
                title = m.group(1).replace("-", " ")

        if not title:
            title = url.split("/")[-1].replace(".html", "").replace("-", " ")

        add_feed_item(title, url, content, "NW")


# ---------------------------------------------------------------------------
# Seeding
# ---------------------------------------------------------------------------


def seed_existing():
    """Populate the feed with current articles on startup."""
    log.info("Seeding RSS feeds...")
    process_rss_feeds()

    log.info("Seeding NW.de...")
    process_nw_articles()

    log.info("Seeded %d feed items, %d seen URLs", len(_feed_items), len(_seen_urls))


# ---------------------------------------------------------------------------
# Miniflux DB purge
# ---------------------------------------------------------------------------


def parse_db_url(url):
    """Parse postgres://user:pass@host:port/db URL."""
    import re
    m = re.match(r"postgres://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)", url)
    if not m:
        return None
    return {
        "user": m.group(1),
        "password": m.group(2),
        "host": m.group(3),
        "port": int(m.group(4)),
        "database": m.group(5),
    }


def purge_miniflux_entries():
    """Delete old entries from Miniflux database."""
    global _last_purge

    if not MINIFLUX_DB_URL:
        return

    # Check if purge interval has passed
    now = time.time()
    if now - _last_purge < PURGE_INTERVAL_HOURS * 3600:
        return

    _last_purge = now

    try:
        import pg8000.native
    except ImportError:
        log.warning("pg8000 not installed, skipping purge")
        return

    db_config = parse_db_url(MINIFLUX_DB_URL)
    if not db_config:
        log.error("Invalid MINIFLUX_DB_URL format")
        return

    try:
        conn = pg8000.native.Connection(
            user=db_config["user"],
            password=db_config["password"],
            host=db_config["host"],
            port=db_config["port"],
            database=db_config["database"],
        )

        # Delete old read entries
        read_deleted = conn.run(
            f"DELETE FROM entries WHERE published_at < NOW() - INTERVAL '{PURGE_READ_DAYS} days' AND status = 'read'"
        )

        # Delete old unread entries
        unread_deleted = conn.run(
            f"DELETE FROM entries WHERE published_at < NOW() - INTERVAL '{PURGE_UNREAD_DAYS} days'"
        )

        conn.close()
        log.info("Purged Miniflux: read (>%dd), unread (>%dd)", PURGE_READ_DAYS, PURGE_UNREAD_DAYS)

    except Exception as exc:
        log.error("Miniflux purge failed: %s", exc)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    log.info("News pipeline started (interval=%ds)", INTERVAL)
    start_feed_server()

    # Wait for article-extractor to be ready
    log.info("Waiting for article-extractor...")
    for _ in range(30):
        try:
            urllib.request.urlopen(f"{EXTRACTOR_URL}/health", timeout=5)
            log.info("article-extractor is ready")
            break
        except (urllib.error.URLError, OSError):
            time.sleep(2)

    seed_existing()

    _last_rss = time.time()
    _last_nw = time.time()
    _tick = min(NW_INTERVAL, INTERVAL)

    while True:
        now = time.time()

        if now - _last_rss >= INTERVAL:
            _last_rss = now
            try:
                process_rss_feeds()
            except Exception:
                log.exception("Error in RSS processing")
            try:
                purge_miniflux_entries()
            except Exception:
                log.exception("Error in Miniflux purge")

        if now - _last_nw >= NW_INTERVAL:
            _last_nw = now
            try:
                process_nw_articles()
            except Exception:
                log.exception("Error in NW.de processing")

        # Trim seen set
        if len(_seen_urls) > _SEEN_MAX:
            excess = len(_seen_urls) - _SEEN_MAX
            _seen_urls.difference_update(set(list(_seen_urls)[:excess]))

        log.info("Sleeping %ds", _tick)
        time.sleep(_tick)


if __name__ == "__main__":
    main()
