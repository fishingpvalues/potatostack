#!/usr/bin/env python3
"""Article extractor HTTP server using headless Chromium + Bypass Paywalls Clean.

Primary extraction: Chromium with BPC extension loads the page (bypassing paywalls),
then trafilatura extracts clean text from the rendered HTML.
For known sites (FAZ), uses direct API calls discovered from BPC source.
"""

import json
import logging
import os
import re
import subprocess
import threading
import time
import urllib.request
from html.parser import HTMLParser
from http.server import HTTPServer, BaseHTTPRequestHandler

import trafilatura
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

BPC_DIR = os.environ.get("BPC_DIR", "/app/bpc-extension")
CHROME_BIN = os.environ.get("CHROME_BIN", "/usr/bin/chromium-browser")
CHROMEDRIVER_BIN = os.environ.get("CHROMEDRIVER_BIN", "/usr/bin/chromedriver")

_browser_lock = threading.Lock()
_driver = None


class HTMLTextExtractor(HTMLParser):
    """Strip HTML tags, keep text."""

    def __init__(self):
        super().__init__()
        self.parts = []
        self._skip = False

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self._skip = True

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self._skip = False
        if tag in ("p", "div", "br", "li", "h1", "h2", "h3", "h4", "h5", "h6"):
            self.parts.append("\n")

    def handle_data(self, data):
        if not self._skip:
            self.parts.append(data)

    def get_text(self):
        return re.sub(r"\n{3,}", "\n\n", "".join(self.parts)).strip()


def strip_html(html):
    """Convert HTML to plain text."""
    p = HTMLTextExtractor()
    p.feed(html)
    return p.get_text()


# ---------------------------------------------------------------------------
# Site-specific API extractors (from BPC source code analysis)
# ---------------------------------------------------------------------------

def extract_faz_api(url):
    """Extract FAZ article via their internal API (bypasses paywall)."""
    m = re.search(r"-(\d+)\.html", url)
    if not m:
        return None
    article_id = m.group(1)
    api_url = f"https://fnetcore-api-prod.azurewebsites.net/api/v3/article?id={article_id}"
    try:
        req = urllib.request.Request(api_url, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
            "Accept": "application/json",
        })
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
        title = data.get("title", "")
        elements = data.get("content_elements", [])
        parts = []
        for elem in elements:
            html = elem.get("html", "")
            if html:
                parts.append(strip_html(html))
        content = "\n\n".join(p for p in parts if p.strip())
        if content:
            log.info("FAZ API: %d chars for article %s", len(content), article_id)
            return {"title": title, "content": content}
    except Exception as exc:
        log.warning("FAZ API failed for %s: %s", article_id, exc)
    return None


# Map of domain patterns to API extractors
SITE_EXTRACTORS = {
    "faz.net": extract_faz_api,
}


def try_site_api(url):
    """Try site-specific API extraction."""
    for domain, extractor in SITE_EXTRACTORS.items():
        if domain in url:
            return extractor(url)
    return None


# ---------------------------------------------------------------------------
# Browser-based extraction
# ---------------------------------------------------------------------------

def get_chrome_options():
    opts = Options()
    opts.binary_location = CHROME_BIN
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--disable-software-rasterizer")
    opts.add_argument("--disable-extensions-except=" + BPC_DIR)
    opts.add_argument("--load-extension=" + BPC_DIR)
    opts.add_argument("--window-size=1280,720")
    opts.add_argument("--disable-background-networking")
    opts.add_argument("--disable-sync")
    opts.add_argument("--disable-translate")
    opts.add_argument("--disable-default-apps")
    opts.add_argument("--mute-audio")
    opts.add_argument("--lang=de-DE")
    opts.add_argument(
        "--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    )
    return opts


def init_driver():
    global _driver
    if _driver:
        try:
            _driver.quit()
        except Exception:
            pass
    service = Service(executable_path=CHROMEDRIVER_BIN)
    _driver = webdriver.Chrome(service=service, options=get_chrome_options())
    _driver.set_page_load_timeout(30)
    log.info("Chromium driver initialized")
    return _driver


def fetch_with_browser(url):
    """Fetch page HTML using headless Chromium + BPC extension."""
    global _driver
    with _browser_lock:
        try:
            if _driver is None:
                init_driver()
            _driver.get(url)
            return _driver.page_source
        except Exception as exc:
            log.warning("Browser fetch failed, reinitializing: %s", exc)
            try:
                init_driver()
                _driver.get(url)
                return _driver.page_source
            except Exception as exc2:
                log.error("Browser fetch failed after reinit: %s", exc2)
                return None


def extract_from_html(html):
    """Extract text and title from HTML using trafilatura."""
    text = trafilatura.extract(html, include_comments=False, include_tables=False)
    title = ""
    metadata = trafilatura.extract(html, output_format="json", include_comments=False)
    if metadata:
        try:
            title = json.loads(metadata).get("title", "")
        except (json.JSONDecodeError, AttributeError):
            pass
    if text:
        return {"title": title, "content": text}
    return None


# ---------------------------------------------------------------------------
# HTTP server
# ---------------------------------------------------------------------------

class ExtractHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/extract":
            self.send_error(404)
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            data = json.loads(body)
            url = data.get("url", "")
        except (json.JSONDecodeError, AttributeError):
            self.send_json(400, {"error": 'Invalid JSON, expected {"url": "..."}'})
            return

        if not url:
            self.send_json(400, {"error": "Missing url field"})
            return

        log.info("Extracting: %s", url)

        # 1. Try site-specific API (fastest, most reliable)
        result = try_site_api(url)
        method = "site-api"

        # 2. Try Chromium + BPC
        if not result:
            html = fetch_with_browser(url)
            if html:
                result = extract_from_html(html)
                method = "chromium+bpc"

        # 3. Fallback: trafilatura direct fetch
        if not result:
            log.info("Browser extraction failed, falling back to trafilatura")
            downloaded = trafilatura.fetch_url(url)
            if downloaded:
                result = extract_from_html(downloaded)
                method = "trafilatura"

        if not result:
            self.send_json(422, {"error": "Could not extract content", "url": url})
            return

        self.send_json(200, {
            "title": result["title"],
            "content": result["content"],
            "method": method,
        })

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
            return
        self.send_error(404)

    def send_json(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        log.info(format, *args)


BPC_URL = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass-paywalls-chrome-clean-latest.crx&branch=main"
BPC_UPDATE_INTERVAL = 86400  # 24 hours


def update_bpc():
    """Download latest BPC extension and reload driver if changed."""
    try:
        tmp = "/tmp/bpc-update.crx"
        subprocess.run(
            ["curl", "-fsSL", BPC_URL, "-o", tmp],
            check=True,
            timeout=60,
        )
        # Compare with current install by size (CRX changes on every release)
        current_manifest = os.path.join(BPC_DIR, "manifest.json")
        old_size = os.path.getsize(current_manifest) if os.path.exists(current_manifest) else 0
        subprocess.run(
            ["unzip", "-o", tmp, "-d", BPC_DIR],
            check=True,
            timeout=30,
        )
        os.remove(tmp)
        new_size = os.path.getsize(current_manifest) if os.path.exists(current_manifest) else 0
        if new_size != old_size:
            log.info("BPC updated (manifest %d -> %d bytes), restarting driver", old_size, new_size)
            with _browser_lock:
                init_driver()
        else:
            log.info("BPC check: already up to date")
    except Exception as exc:
        log.warning("BPC update failed: %s", exc)


def bpc_updater_loop():
    """Background thread: check for BPC updates once a day."""
    while True:
        time.sleep(BPC_UPDATE_INTERVAL)
        update_bpc()


if __name__ == "__main__":
    log.info("Initializing Chromium driver...")
    init_driver()

    updater = threading.Thread(target=bpc_updater_loop, daemon=True)
    updater.start()
    log.info("BPC auto-updater started (every %ds)", BPC_UPDATE_INTERVAL)

    server = HTTPServer(("0.0.0.0", 8084), ExtractHandler)
    log.info("Article extractor listening on :8084 (Chromium + BPC + site APIs)")
    server.serve_forever()
