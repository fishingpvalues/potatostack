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

# RSS feeds to fetch directly
# extract=True means try full-text extraction via article-extractor
# extract=False means use RSS description as-is (for hard paywalls where extraction always fails)
RSS_FEEDS = [
    {"url": "https://www.faz.net/rss/aktuell/", "source": "FAZ", "extract": True},
    {"url": "https://www.hltv.org/rss/news", "source": "HLTV", "extract": False},
    {
        "url": "https://www.westfalen-blatt.de/rss/feed?subcategory=/owl/bielefeld",
        "source": "WB",
        "extract": False,
    },
    {"url": "https://feeds.a.dj.com/rss/RSSWorldNews.xml", "source": "WSJ", "extract": False},
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
_FEED_MAX = 500
# Track seen URLs to avoid duplicates
_seen_urls: set[str] = set()
_SEEN_MAX = 5000


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
    items = []
    with _feed_lock:
        for item in _feed_items:
            source = item.get("source", "")
            title = f"[{source}] {item['title']}" if source else item["title"]
            items.append(
                f"<item>"
                f"<title>{escape(title)}</title>"
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
        "<title>PotatoStack News</title>\n"
        "<link>https://potatostack.tale-iwato.ts.net</link>\n"
        "<description>Combined news feed with full-text extraction</description>\n"
        f"{items_xml}\n"
        "</channel>\n</rss>"
    )


def build_source_rss(source, title, link):
    """Generate RSS XML filtered to a single source."""
    items = []
    with _feed_lock:
        for item in _feed_items:
            if item.get("source") != source:
                continue
            items.append(
                f"<item>"
                f"<title>{escape(item['title'])}</title>"
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
        f"<description>{escape(title)} - full text</description>\n"
        f"{items_xml}\n"
        "</channel>\n</rss>"
    )


# Source slug -> (title, link)
_SOURCE_META = {
    "faz": ("FAZ", "https://www.faz.net"),
    "hltv": ("HLTV", "https://www.hltv.org"),
    "wb": ("Westfalen-Blatt", "https://www.westfalen-blatt.de"),
    "wsj": ("WSJ", "https://www.wsj.com"),
    "nw": ("NW.de", "https://www.nw.de"),
}


class FeedHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.rstrip("/").lower()

        if path in ("", "/rss", "/feed"):
            body = build_combined_rss().encode("utf-8")
            self._respond(200, "application/rss+xml; charset=utf-8", body)
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


def add_feed_item(title, url, content, source, pub_date=None):
    """Add an item to the combined feed."""
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
    }

    with _feed_lock:
        _feed_items.insert(0, item)
        if len(_feed_items) > _FEED_MAX:
            _feed_items[:] = _feed_items[:_FEED_MAX]


# ---------------------------------------------------------------------------
# RSS feed processing
# ---------------------------------------------------------------------------


def parse_rss_items(xml_text):
    """Parse RSS XML and return list of {title, url, pub_date, description}."""
    items = []
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

        # Clean HTML from title
        title = strip_html_tags(title)

        if url:
            items.append({
                "title": title,
                "url": url,
                "pub_date": pub_date,
                "description": description,
            })
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

    while True:
        try:
            process_rss_feeds()
        except Exception:
            log.exception("Error in RSS processing")

        try:
            process_nw_articles()
        except Exception:
            log.exception("Error in NW.de processing")

        # Trim seen set
        if len(_seen_urls) > _SEEN_MAX:
            excess = len(_seen_urls) - _SEEN_MAX
            _seen_urls.difference_update(set(list(_seen_urls)[:excess]))

        log.info("Sleeping %ds", INTERVAL)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
