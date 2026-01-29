#!/usr/bin/env python3
"""
Jellyseerr webhook to ntfy bridge
Receives Jellyseerr webhooks and forwards formatted notifications to ntfy
"""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import Request, urlopen

HOST = "0.0.0.0"
PORT = int(os.getenv("JELLYSEERR_NTFY_PORT", "8082"))

NTFY_URL = os.getenv("NTFY_INTERNAL_URL", "http://ntfy:80").rstrip("/")
NTFY_TOKEN = os.getenv("NTFY_TOKEN", "")
NTFY_TOPIC = os.getenv("NTFY_TOPIC", "potatostack")


def _send_ntfy(title: str, message: str, priority: str = "3", tags: str = "jellyseerr,media") -> None:
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


def _format_jellyseerr_webhook(data: dict) -> tuple[str, str, str, str]:
    event_type = data.get("event_type", "Unknown")
    request = data.get("request", {})
    user = data.get("user", {}).get("username", "Unknown")

    title = f"📋 Jellyseerr - {event_type}"
    priority = "3"
    tags = "jellyseerr,media"

    if event_type == "request.created":
        tags += ",request,new"
        media_type = request.get("media_type", "Unknown")
        title = f"➕ New {media_type} request from {user}"
        message = f"User: {user}\n"
        if media_type == "movie":
            movie = request.get("media", {})
            title = f"🎬 New movie request: {movie.get('title', 'Unknown')}"
            message += f"Title: {movie.get('title', 'Unknown')}\n"
            message += f"Year: {movie.get('release_date', 'Unknown')[:4] if movie.get('release_date') else 'Unknown'}\n"
            message += f"Overview: {movie.get('overview', 'No overview')[:200]}..."
            tags += ",movie"
        elif media_type == "tv":
            series = request.get("media", {})
            title = f"📺 New TV request: {series.get('name', 'Unknown')}"
            message += f"Series: {series.get('name', 'Unknown')}\n"
            message += f"Seasons: {request.get('seasons', 'Unknown')}\n"
            message += f"Overview: {series.get('overview', 'No overview')[:200]}..."
            tags += ",tv"
        priority = "3"

    elif event_type == "request.approved":
        tags += ",request,approved"
        media_type = request.get("media_type", "Unknown")
        title = f"✅ {media_type} request approved"
        message = f"Approved by: {user}\n"
        if media_type == "movie":
            movie = request.get("media", {})
            title = f"✅ Movie approved: {movie.get('title', 'Unknown')}"
            message += f"Title: {movie.get('title', 'Unknown')}"
            tags += ",movie"
        elif media_type == "tv":
            series = request.get("media", {})
            title = f"✅ TV series approved: {series.get('name', 'Unknown')}"
            message += f"Series: {series.get('name', 'Unknown')}"
            tags += ",tv"
        priority = "2"

    elif event_type == "request.available":
        tags += ",request,available"
        media_type = request.get("media_type", "Unknown")
        title = f"🎉 {media_type} now available!"
        message = ""
        if media_type == "movie":
            movie = request.get("media", {})
            title = f"🎉 Movie ready: {movie.get('title', 'Unknown')}"
            message += f"Title: {movie.get('title', 'Unknown')}\n"
            message += f"Quality: {request.get('profile', 'Unknown')}"
            tags += ",movie"
        elif media_type == "tv":
            series = request.get("media", {})
            title = f"🎉 TV ready: {series.get('name', 'Unknown')}"
            message += f"Series: {series.get('name', 'Unknown')}"
            tags += ",tv"
        priority = "4"

    elif event_type == "request.declined":
        tags += ",request,declined,warning"
        media_type = request.get("media_type", "Unknown")
        title = f"❌ {media_type} request declined"
        message = f"Declined by: {user}\nReason: {request.get('rejection_reason', 'No reason provided')}"
        priority = "3"

    elif event_type == "media.added":
        tags += ",media,new"
        media_type = request.get("media_type", "Unknown")
        title = f"📥 New {media_type} added to library"
        message = f"Added by: {user}"
        priority = "2"

    else:
        message = f"Event: {event_type}\nUser: {user}\nData: {json.dumps(data, indent=2)}"

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
            title, message, priority, tags = _format_jellyseerr_webhook(data)
            _send_ntfy(title, message, priority, tags)
            self.send_response(200)
        except Exception:
            self.send_response(500)
        self.end_headers()


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Jellyseerr ntfy bridge listening on {HOST}:{PORT}")
    server.serve_forever()
