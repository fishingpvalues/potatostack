#!/usr/bin/env python3
"""
Miniflux webhook to ntfy bridge
Receives Miniflux webhooks for new entries and forwards to ntfy
"""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import Request, urlopen

HOST = "0.0.0.0"
PORT = int(os.getenv("MINIFLUX_NTFY_PORT", "8083"))

NTFY_URL = os.getenv("NTFY_INTERNAL_URL", "http://ntfy:80").rstrip("/")
NTFY_TOKEN = os.getenv("NTFY_TOKEN", "")
NTFY_TOPIC = os.getenv("NTFY_TOPIC_INFO", "potatostack-info")


def _send_ntfy(title: str, message: str, priority: str = "2", tags: str = "miniflux,rss") -> None:
    url = f"{NTFY_URL}/{NTFY_TOPIC}"
    headers = {
        "Title": title,
        "Tags": tags,
        "Priority": priority,
    }
    if NTFY_TOKEN:
        headers["Authorization"] = f"Bearer {NTFY_TOKEN}"
    req = Request(url, data=message.encode("utf-8"), headers=headers, method="POST")
    with urlopen(req, timeout=10):
        return


def _format_miniflux_webhook(data: dict) -> tuple[str, str, str, str]:
    event_type = data.get("event_type", "Unknown")
    entry = data.get("entry", {})

    title = "📰 Miniflux"
    priority = "2"
    tags = "miniflux,rss"

    if event_type == "new_entries":
        tags += ",new"
        title = f"📰 New entry: {entry.get('title', 'No title')[:50]}"
        feed_title = entry.get("feed", {}).get("title", "Unknown feed")
        message = f"Feed: {feed_title}\n"
        message += f"Title: {entry.get('title', 'No title')}\n"
        message += f"Author: {entry.get('author', 'Unknown')}\n"
        message += f"URL: {entry.get('url', 'No URL')}"
        priority = "2"

    elif event_type == "feed_created":
        tags += ",feed"
        title = "➕ New Miniflux feed created"
        feed = data.get("feed", {})
        message = f"Feed: {feed.get('title', 'Unknown')}\nURL: {feed.get('feed_url', 'Unknown')}"
        priority = "3"

    elif event_type == "feed_modified":
        tags += ",feed"
        title = "✏️ Miniflux feed modified"
        feed = data.get("feed", {})
        message = f"Feed: {feed.get('title', 'Unknown')}"
        priority = "3"

    elif event_type == "feed_deleted":
        tags += ",feed,warning"
        title = "🗑️ Miniflux feed deleted"
        feed = data.get("feed", {})
        message = f"Feed: {feed.get('title', 'Unknown')}"
        priority = "3"

    else:
        message = f"Event: {event_type}\nData: {json.dumps(data, indent=2)}"

    return title, message, priority, tags


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        try:
            title, message, priority, tags = _format_miniflux_webhook(data)
            _send_ntfy(title, message, priority, tags)
            self.send_response(200)
        except Exception:
            self.send_response(500)
        self.end_headers()


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Miniflux ntfy bridge listening on {HOST}:{PORT}")
    server.serve_forever()
