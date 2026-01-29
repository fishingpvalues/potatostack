#!/usr/bin/env python3
"""
Jellyfin webhook to ntfy bridge
Receives Jellyfin webhooks and forwards formatted notifications to ntfy
"""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import Request, urlopen

HOST = "0.0.0.0"
PORT = int(os.getenv("JELLYFIN_NTFY_PORT", "8081"))

NTFY_URL = os.getenv("NTFY_INTERNAL_URL", "http://ntfy:80").rstrip("/")
NTFY_TOKEN = os.getenv("NTFY_TOKEN", "")
NTFY_TOPIC = os.getenv("NTFY_TOPIC", "potatostack")


def _send_ntfy(title: str, message: str, priority: str = "3", tags: str = "jellyfin,media") -> None:
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


def _format_jellyfin_webhook(data: dict) -> tuple[str, str, str]:
    event_type = data.get("NotificationType", "Unknown")
    metadata = data.get("Item", {})
    user = data.get("NotificationUsername", "Unknown")

    title = f"🎬 Jellyfin - {event_type}"
    priority = "3"
    tags = "jellyfin,media"

    if event_type == "PlaybackStarted":
        tags += ",playback"
        title = f"▶️ {user} is watching {metadata.get('Name', 'Unknown')}"
        message = f"User: {user}\nTitle: {metadata.get('Name', 'Unknown')}"
        if metadata.get("SeriesName"):
            message += f"\nSeries: {metadata['SeriesName']}"
            message += f"\nS{metadata.get('ParentIndexNumber', '?')}E{metadata.get('IndexNumber', '?')}"
        if metadata.get("Type") == "Movie":
            tags += ",movie"
        elif metadata.get("Type") == "Episode":
            tags += ",tv"
        priority = "2"

    elif event_type == "PlaybackStopped":
        tags += ",playback"
        title = f"⏸️ {user} stopped watching"
        message = f"User: {user}\nTitle: {metadata.get('Name', 'Unknown')}"
        priority = "1"

    elif event_type == "NewLibraryContent":
        tags += ",new"
        title = f"📚 New content added"
        message = f"Title: {metadata.get('Name', 'Unknown')}\nType: {metadata.get('Type', 'Unknown')}"
        priority = "2"

    elif event_type == "AuthenticationSuccess":
        tags += ",auth"
        title = f"🔑 {user} signed in"
        message = f"User: {user}\nDevice: {data.get('DeviceName', 'Unknown')}\nClient: {data.get('Client', 'Unknown')}"
        priority = "1"

    elif event_type == "AuthenticationFailure":
        tags += ",auth,warning"
        title = f"⚠️ Failed login attempt"
        message = f"User: {user}\nDevice: {data.get('DeviceName', 'Unknown')}\nClient: {data.get('Client', 'Unknown')}"
        priority = "4"

    elif event_type == "ApplicationUpdateAvailable":
        tags += ",update"
        title = f"🔄 Jellyfin update available"
        message = f"Version: {data.get('Version', 'Unknown')}\nRelease date: {data.get('ReleaseDate', 'Unknown')}"
        priority = "3"

    elif event_type == "ItemAdded":
        tags += ",new"
        title = f"➕ New item: {metadata.get('Name', 'Unknown')}"
        message = f"Type: {metadata.get('Type', 'Unknown')}\nPath: {metadata.get('Path', 'Unknown')}"
        priority = "2"

    elif event_type == "ItemUpdated":
        tags += ",update"
        title = f"✏️ Item updated: {metadata.get('Name', 'Unknown')}"
        message = f"Type: {metadata.get('Type', 'Unknown')}"
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
            title, message, priority, tags = _format_jellyfin_webhook(data)
            _send_ntfy(title, message, priority, tags)
            self.send_response(200)
        except Exception:
            self.send_response(500)
        self.end_headers()


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Jellyfin ntfy bridge listening on {HOST}:{PORT}")
    server.serve_forever()
