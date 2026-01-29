#!/usr/bin/env python3
"""Alertmanager -> ntfy formatter for enterprise-grade alerts."""

import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import Request, urlopen

HOST = "0.0.0.0"
PORT = int(os.getenv("ALERTMANAGER_NTFY_PORT", "8080"))

NTFY_URL = os.getenv("NTFY_INTERNAL_URL", "http://ntfy:80").rstrip("/")
NTFY_TOKEN = os.getenv("NTFY_TOKEN", "")
DEFAULT_TOPIC = os.getenv("NTFY_TOPIC", "potatostack")
TOPIC_CRITICAL = os.getenv("NTFY_TOPIC_CRITICAL", "")
TOPIC_WARNING = os.getenv("NTFY_TOPIC_WARNING", "")
TOPIC_INFO = os.getenv("NTFY_TOPIC_INFO", "")

PRIORITY_MAP = {
    "critical": "5",
    "warning": "3",
    "info": "2",
    "none": "1",
}


def _pick_topic(severity: str) -> str:
    if severity == "critical" and TOPIC_CRITICAL:
        return TOPIC_CRITICAL
    if severity == "warning" and TOPIC_WARNING:
        return TOPIC_WARNING
    if severity == "info" and TOPIC_INFO:
        return TOPIC_INFO
    return DEFAULT_TOPIC


def _format_alert(alert: dict) -> str:
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    name = labels.get("alertname", "Alert")
    service = labels.get("container_label_com_docker_compose_service") or labels.get("service")
    instance = labels.get("instance", "")
    summary = annotations.get("summary", "")
    description = annotations.get("description", "")
    runbook = annotations.get("runbook", "")
    starts_at = alert.get("startsAt", "")
    ends_at = alert.get("endsAt", "")

    lines = [f"**{name}**"]

    if service:
        lines.append(f"  Service: {service}")
    if instance:
        lines.append(f"  Instance: {instance}")

    if summary:
        lines.append(f"\n  *{summary}*")
    if description:
        lines.append(f"\n  {description}")
    if runbook:
        lines.append(f"\n  📖 Runbook: {runbook}")

    if starts_at:
        lines.append(f"\n  Started: {starts_at}")
    if ends_at:
        lines.append(f"  Resolved: {ends_at}")

    return "\n".join(lines)


def _send_ntfy(title: str, message: str, priority: str, tags: str, topic: str) -> None:
    url = f"{NTFY_URL}/{topic}"
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


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        return

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            payload = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        alerts = payload.get("alerts", [])
        if not alerts:
            self.send_response(200)
            self.end_headers()
            return

        status = payload.get("status", "firing")
        common_labels = payload.get("commonLabels", {})
        common_annotations = payload.get("commonAnnotations", {})

        severity = common_labels.get("severity", "warning")
        alertname = common_labels.get("alertname", "Alert")
        component = common_labels.get("component", "")

        priority = PRIORITY_MAP.get(severity, "3")
        topic = _pick_topic(severity)
        tags = ",".join(filter(None, ["prometheus", severity, component, status]))

        severity_emoji = {"critical": "🚨", "warning": "⚠️", "info": "ℹ️"}.get(severity, "🔔")
        status_emoji = {"firing": "🔥", "resolved": "✅"}.get(status, "🔔")

        title = f"{severity_emoji} PotatoStack - {status.upper()} - {alertname}"
        summary = common_annotations.get("summary", "")
        description = common_annotations.get("description", "")

        lines = []

        if summary:
            lines.append(f"*{summary}*")

        if description:
            lines.append(f"\n{description}")

        if severity != "none":
            lines.append(f"\n**Severity:** {severity.upper()}")
        lines.append(f"**Status:** {status.upper()}")
        lines.append(f"**Alerts:** {len(alerts)}")

        if component:
            lines.append(f"**Component:** {component}")

        lines.append("\n---\n")

        for alert in alerts:
            lines.append(_format_alert(alert))
            lines.append("")

        message = "\n".join(lines).strip()

        try:
            _send_ntfy(title, message, priority, tags, topic)
            self.send_response(200)
        except Exception:
            self.send_response(500)
        self.end_headers()


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Alertmanager ntfy bridge listening on {HOST}:{PORT}")
    while True:
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            break
        except Exception:
            time.sleep(1)
