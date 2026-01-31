#!/usr/bin/env python3
"""News pipeline: fetch Miniflux entries + crawl NW.de, extract full text, send keyword alerts."""

import json
import logging
import os
import re
import time
import urllib.error
import urllib.request
from html.parser import HTMLParser

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("news-pipeline")

MINIFLUX_URL = os.environ.get("MINIFLUX_URL", "http://miniflux:8080")
MINIFLUX_API_KEY = os.environ["MINIFLUX_API_KEY"]
EXTRACTOR_URL = os.environ.get("EXTRACTOR_URL", "http://article-extractor:8084")
NTFY_URL = os.environ.get("NTFY_URL", "http://ntfy:80/news-alerts")
TAILSCALE_BASE_URL = os.environ.get(
    "TAILSCALE_BASE_URL", "https://potatostack.tale-iwato.ts.net:8093"
)
KEYWORD_PATTERN = (
    os.environ.get("KEYWORD_PATTERN", "").strip()
    or r"(cs2|counter-strike|hltv|bielefeld|owl|paderborn|\bnw\b|westfalen"
    r"|germany|deutschland|europe|\beu\b|nato|bundesbank|ecb|ezb"
    r"|trade war|tariff|recession|inflation|ukraine|china|taiwan"
    r"|\bafd\b|bundestag|bundeswehr|dax|deutsche bank"
    r"|volkswagen|\bvw\b|mercedes|\bbmw\b|siemens|\bsap\b|basf|bayer"
    r"|thyssenkrupp|\brwe\b|dortmund|d[uü]sseldorf|k[oö]ln"
    r"|semiconductor|cybersecurity|artificial intelligence|\bai\b|nord stream"
    r"|blitzer|j[oö]llenbeck|halle|h[oö]rste)"
)
INTERVAL = int(os.environ.get("INTERVAL_SECONDS", "900"))
MIN_CONTENT_LENGTH = int(os.environ.get("MIN_CONTENT_LENGTH", "500"))

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
# Keep track of seen NW article URLs (persists across cycles in memory)
_nw_seen_urls: set[str] = set()
# Cap the seen set to avoid unbounded growth
_NW_SEEN_MAX = 2000
# Track alerted Miniflux entry IDs to avoid duplicate alerts
_alerted_entry_ids: set[int] = set()
_ALERTED_MAX = 2000

keyword_re = re.compile(KEYWORD_PATTERN, re.IGNORECASE)


# ---------------------------------------------------------------------------
# Helpers
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


class TitleExtractor(HTMLParser):
    """Extract <title> from HTML."""

    def __init__(self):
        super().__init__()
        self._in_title = False
        self.title = ""

    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self._in_title = True

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._in_title:
            self.title += data


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


def fetch_html(url):
    """Fetch raw HTML from a URL."""
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


# ---------------------------------------------------------------------------
# Source tagging
# ---------------------------------------------------------------------------

SOURCE_MAP = {
    "faz": "FAZ",
    "hltv": "HLTV",
    "neue westfälische": "NW",
    "nw.de": "NW",
    "westfalen-blatt": "WB",
    "westfalenblatt": "WB",
    "wall street journal": "WSJ",
    "wsj": "WSJ",
}


def get_source_tag(entry):
    """Derive short source tag from feed title or URL."""
    feed_title = entry.get("feed", {}).get("title", "").lower()
    url = entry.get("url", "").lower()
    for key, tag in SOURCE_MAP.items():
        if key in feed_title or key in url:
            return tag
    return ""


# ---------------------------------------------------------------------------
# Miniflux pipeline
# ---------------------------------------------------------------------------


def fetch_unread_entries():
    """Fetch unread entries from Miniflux."""
    url = f"{MINIFLUX_URL}/v1/entries?status=unread&limit=100"
    result = api_request(url, headers={"X-Auth-Token": MINIFLUX_API_KEY})
    if result and "entries" in result:
        return result["entries"]
    return []


def extract_article(entry_url):
    """Call article-extractor for full-text extraction."""
    result = api_request(
        f"{EXTRACTOR_URL}/extract", method="POST", data={"url": entry_url}
    )
    if result and result.get("content"):
        return result["content"]
    return None


def update_entry_content(entry_id, content):
    """Update a Miniflux entry with extracted content."""
    url = f"{MINIFLUX_URL}/v1/entries/{entry_id}"
    api_request(
        url,
        method="PUT",
        data={"content": content},
        headers={"X-Auth-Token": MINIFLUX_API_KEY},
    )


# ---------------------------------------------------------------------------
# Alerts
# ---------------------------------------------------------------------------


def send_alert(entry):
    """Send ntfy notification for a matching entry."""
    title = entry.get("title", "News Alert")
    source = get_source_tag(entry)
    display_title = f"[{source}] {title}" if source else title
    entry_url = entry.get("url", "")
    entry_id = entry.get("id", "")

    # For Miniflux entries, link to Miniflux reader; for NW crawled, link to source
    if entry_id:
        click_url = f"{TAILSCALE_BASE_URL}/unread/entry/{entry_id}"
    else:
        click_url = entry_url

    payload = {
        "topic": NTFY_URL.rsplit("/", 1)[-1],
        "title": display_title,
        "message": title,
        "click": click_url,
        "actions": [{"action": "view", "label": "Open source", "url": entry_url}],
        "tags": ["newspaper"],
    }
    body = json.dumps(payload).encode("utf-8")
    base_url = NTFY_URL.rsplit("/", 1)[0]
    req = urllib.request.Request(
        base_url, data=body, headers={"Content-Type": "application/json"}
    )
    try:
        urllib.request.urlopen(req, timeout=10)
        log.info("Alert sent: %s", display_title)
    except (urllib.error.URLError, OSError) as exc:
        log.error("Failed to send alert: %s", exc)


# ---------------------------------------------------------------------------
# NW.de crawler
# ---------------------------------------------------------------------------


def crawl_nw_section(section_url):
    """Scrape a NW.de section page and return new article URLs."""
    html = fetch_html(section_url)
    if not html:
        return []
    parser = LinkExtractor()
    parser.feed(html)
    new_urls = [u for u in parser.links if u not in _nw_seen_urls]
    return new_urls


def process_nw_articles():
    """Crawl NW.de sections, extract articles, check keywords, send alerts."""
    global _nw_seen_urls
    all_new = []
    for section in NW_SECTIONS:
        new_urls = crawl_nw_section(section)
        all_new.extend(new_urls)

    if not all_new:
        log.info("NW.de: no new articles")
        return

    log.info("NW.de: found %d new articles", len(all_new))

    for url in all_new:
        _nw_seen_urls.add(url)

        # Extract full text
        result = api_request(
            f"{EXTRACTOR_URL}/extract", method="POST", data={"url": url}
        )
        if not result or not result.get("content"):
            continue

        content = result["content"]
        title = result.get("title", "")

        # Fallback title from URL if extraction didn't get one
        if not title:
            m = re.search(r"/\d+_(.+)\.html$", url)
            if m:
                title = m.group(1).replace("-", " ")

        text = f"{title} {content}"
        if keyword_re.search(text):
            entry = {"title": title, "url": url, "id": "", "feed": {"title": "NW.de"}}
            log.info("NW keyword match: %s", title)
            send_alert(entry)

    # Trim seen set
    if len(_nw_seen_urls) > _NW_SEEN_MAX:
        excess = len(_nw_seen_urls) - _NW_SEEN_MAX
        _nw_seen_urls = set(list(_nw_seen_urls)[excess:])


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------


def mark_entries_read(entry_ids):
    """Mark Miniflux entries as read."""
    if not entry_ids:
        return
    url = f"{MINIFLUX_URL}/v1/entries"
    api_request(
        url,
        method="PUT",
        data={"entry_ids": entry_ids, "status": "read"},
        headers={"X-Auth-Token": MINIFLUX_API_KEY},
    )


def process_miniflux_entries():
    """Process Miniflux entries: extract, keyword-match, alert."""
    global _alerted_entry_ids
    entries = fetch_unread_entries()
    log.info("Miniflux: fetched %d unread entries", len(entries))

    processed_ids = []
    for entry in entries:
        title = entry.get("title", "")
        content = entry.get("content", "")
        entry_url = entry.get("url", "")
        entry_id = entry.get("id")

        processed_ids.append(entry_id)

        # Extract full text if content is short
        if len(content) < MIN_CONTENT_LENGTH and entry_url:
            log.info("Extracting: %s", entry_url)
            extracted = extract_article(entry_url)
            if extracted:
                content = extracted
                update_entry_content(entry_id, content)
                log.info("Updated entry %s with extracted content", entry_id)

        # Check keywords against title + content
        text = f"{title} {content}"
        if keyword_re.search(text) and entry_id not in _alerted_entry_ids:
            log.info("Keyword match: %s", title)
            send_alert(entry)
            _alerted_entry_ids.add(entry_id)

    # Mark all processed entries as read so next fetch gets new entries
    mark_entries_read(processed_ids)
    log.info("Marked %d entries as read", len(processed_ids))

    # Trim alerted set
    if len(_alerted_entry_ids) > _ALERTED_MAX:
        excess = len(_alerted_entry_ids) - _ALERTED_MAX
        _alerted_entry_ids = set(list(_alerted_entry_ids)[excess:])


def main():
    log.info(
        "News pipeline started (interval=%ds, pattern=%s)", INTERVAL, KEYWORD_PATTERN
    )

    # Seed NW seen URLs on first run to avoid alerting on old articles
    log.info("Seeding NW.de seen URLs...")
    for section in NW_SECTIONS:
        html = fetch_html(section)
        if html:
            parser = LinkExtractor()
            parser.feed(html)
            _nw_seen_urls.update(parser.links)
    log.info("Seeded %d NW.de URLs", len(_nw_seen_urls))

    while True:
        try:
            process_miniflux_entries()
        except Exception:
            log.exception("Error in Miniflux processing")

        try:
            process_nw_articles()
        except Exception:
            log.exception("Error in NW.de processing")

        log.info("Sleeping %ds", INTERVAL)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
