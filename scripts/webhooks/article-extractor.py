#!/usr/bin/env python3
"""Article extractor HTTP server for n8n news pipeline.

Extracts full article text from URLs using trafilatura with newspaper3k fallback.
Detects paywalled content via German keyword matching.
"""

import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler

import trafilatura
from newspaper import Article

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

PAYWALL_KEYWORDS = [
    "Abonnieren",
    "Premium",
    "Jetzt lesen",
    "FAZ+",
    "E-Paper",
    "Weiterlesen nur mit Abo",
    "Login erforderlich",
    "exklusiv für Abonnenten",
]


def extract_trafilatura(url: str) -> dict | None:
    downloaded = trafilatura.fetch_url(url)
    if not downloaded:
        return None
    text = trafilatura.extract(downloaded, include_comments=False, include_tables=False)
    metadata = trafilatura.extract(downloaded, output_format="json", include_comments=False)
    title = ""
    if metadata:
        try:
            title = json.loads(metadata).get("title", "")
        except (json.JSONDecodeError, AttributeError):
            pass
    if text:
        return {"title": title, "content": text}
    return None


def extract_newspaper(url: str) -> dict | None:
    try:
        article = Article(url, language="de")
        article.download()
        article.parse()
        if article.text:
            return {"title": article.title or "", "content": article.text}
    except Exception as e:
        log.warning("newspaper3k failed for %s: %s", url, e)
    return None


def is_paywalled(text: str) -> bool:
    return any(kw.lower() in text.lower() for kw in PAYWALL_KEYWORDS)


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
            self.send_json(400, {"error": "Invalid JSON, expected {\"url\": \"...\"}"})
            return

        if not url:
            self.send_json(400, {"error": "Missing url field"})
            return

        log.info("Extracting: %s", url)

        result = extract_trafilatura(url)
        method = "trafilatura"
        paywalled = False

        if result and is_paywalled(result["content"]):
            paywalled = True
            log.info("Paywall detected, trying newspaper3k fallback")
            fallback = extract_newspaper(url)
            if fallback and len(fallback["content"]) > len(result["content"]):
                result = fallback
                method = "newspaper3k"

        if not result:
            result = extract_newspaper(url)
            method = "newspaper3k"

        if not result:
            self.send_json(422, {"error": "Could not extract content", "url": url})
            return

        self.send_json(200, {
            "title": result["title"],
            "content": result["content"],
            "paywalled": paywalled,
            "method": method,
        })

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
            return
        self.send_error(404)

    def send_json(self, code: int, data: dict):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        log.info(format, *args)


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8084), ExtractHandler)
    log.info("Article extractor listening on :8084")
    server.serve_forever()
