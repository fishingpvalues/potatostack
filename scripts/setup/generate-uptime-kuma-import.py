#!/usr/bin/env python3
"""
Generate Uptime Kuma import.json for PotatoStack.

Run after adding/removing/changing services:
  python3 scripts/setup/generate-uptime-kuma-import.py

Output: config/uptime-kuma/import.json
Import via: Uptime Kuma → Settings → Backup → Import
"""

import json
import os

# ── Monitor definitions ────────────────────────────────────────────────────────
# fmt: (name, type, host_or_url, port_or_none, health_path, interval, accepted, description)
#
# type:  "http" | "port"
# For http: host_or_url is the full URL (path included if needed)
# For port: host_or_url is hostname, port_or_none is the TCP port
# health_path: appended to base URL for http monitors (ignored for port)
# interval: seconds between checks
# accepted: list of accepted status code ranges (http only)

MONITORS = [
    # ── Infrastructure ──────────────────────────────────────────────────────
    ("PostgreSQL",       "port", "postgres",          5432,  None,               60,  ["200-299"], "PostgreSQL 18 (pgvector)"),
    ("PgBouncer",        "port", "pgbouncer",          5432,  None,               60,  ["200-299"], "PostgreSQL connection pooler"),
    ("Redis",            "port", "redis-cache",        6379,  None,               60,  ["200-299"], "Redis 7 shared cache"),
    ("MongoDB",          "port", "mongo",             27017,  None,               60,  ["200-299"], "MongoDB 7"),
    ("CrowdSec",         "http", "crowdsec",           6060,  "/metrics",         60,  ["200-299"], "IPS/security"),
    ("Gluetun VPN",      "http", "gluetun",            8008,  "/v1/publicip/ip",  60,  ["200-299"], "VPN gateway — checks public IP (HTTP_CONTROL_SERVER_ADDRESS=:8008)"),

    # ── Monitoring ─────────────────────────────────────────────────────────
    ("Homer",            "http", "homer",              8080,  "/",                60,  ["200-299"], "Dashboard"),
    ("Grafana",          "http", "grafana",            3000,  "/api/health",      60,  ["200-299"], "Dashboards"),
    ("Prometheus",       "http", "prometheus",         9090,  "/-/healthy",       60,  ["200-299"], "Metrics"),
    ("Loki",             "http", "loki",               3100,  "/ready",           60,  ["200-299"], "Log aggregation"),
    ("Alertmanager",     "http", "alertmanager",       9093,  "/-/healthy",       60,  ["200-299"], "Alerting"),
    ("Healthchecks",     "port", "healthchecks",       8000,  None,               60,  ["200-299"], "Cron monitoring"),
    ("Scrutiny",         "http", "scrutiny",           8080,  "/",               300,  ["200-399"], "Disk health"),
    ("Dagu",             "http", "dagu",               8080,  "/",                60,  ["200-399"], "Workflow automation"),
    ("WUD",              "http", "wud",                3000,  "/",               120,  ["200-399"], "Docker update watcher"),
    ("ntfy",             "http", "ntfy",                 80,  "/",                60,  ["200-299"], "Push notifications"),
    ("Uptime Kuma",      "http", "uptime-kuma",        3001,  "/",                60,  ["200-399"], "Uptime monitoring (self)"),

    # ── Media ──────────────────────────────────────────────────────────────
    ("Jellyfin",         "http", "jellyfin",           8096,  "/health",          60,  ["200-299"], "Movies & TV"),
    ("Audiobookshelf",   "http", "audiobookshelf",       80,  "/",                60,  ["200-399"], "Audiobooks & Podcasts"),
    ("Kavita",           "http", "kavita",             5000,  "/",                60,  ["200-399"], "Ebooks & Comics"),
    ("Navidrome",        "http", "navidrome",          4533,  "/ping",            60,  ["200-299"], "Music streaming"),
    ("Beets",            "http", "beets",              8337,  "/",               120,  ["200-399"], "Music tagger"),
    ("Stash",            "http", "gluetun",            9900,  "/",                60,  ["200-399"], "Media library (via gluetun)"),
    # ("Karaoke Eternal", "http", "karaoke-eternal", 8044, "/", 120, ["200-399"], "Karaoke"),  # disabled — not running

    # ── Downloads (behind gluetun) ─────────────────────────────────────────
    ("qBittorrent",      "http", "gluetun",            8282,  "/",                60,  ["200-399"], "Torrents (via gluetun)"),
    ("slskd",            "http", "gluetun",            2234,  "/",                60,  ["200-399"], "Soulseek (via gluetun)"),
    ("SpotiFLAC",        "http", "gluetun",            8080,  "/",               120,  ["200-399"], "Spotify ripper (via gluetun, internal port 8080)"),
    ("AriaNg",           "http", "ariang",               80,  "/",               120,  ["200-299"], "HTTP/FTP downloader UI"),

    # ── Photos & Files ─────────────────────────────────────────────────────
    ("Immich",           "http", "immich-server",      2283,  "/api/server/ping", 60,  ["200-299"], "Photo management"),
    ("Filebrowser",      "http", "filebrowser",          80,  "/",                60,  ["200-399"], "File manager"),
    ("Filestash",        "http", "filestash",          8334,  "/",                60,  ["200-399"], "Advanced file manager"),
    ("Syncthing",        "http", "syncthing",          8384,  "/",                60,  ["200-399"], "File sync"),
    ("Velld",            "http", "velld-web",          3000,  "/",               120,  ["200-399"], "Database backups"),

    # ── Productivity ───────────────────────────────────────────────────────
    ("Miniflux",         "http", "miniflux",           8080,  "/healthcheck",     60,  ["200-299"], "RSS reader"),
    ("Obsidian LiveSync","http", "obsidian-livesync",  5984,  "/_up",             60,  ["200-299", "401"], "Notes sync (CouchDB — 401 means up but auth required)"),
    ("Baikal",           "http", "baikal",               80,  "/",                60,  ["200-399"], "Calendar & Contacts (CalDAV/CardDAV)"),
    ("SearXNG",          "http", "searxng",            8080,  "/",                60,  ["200-299"], "Private search engine"),

    # ── Finance ────────────────────────────────────────────────────────────
    ("Actual Budget",    "http", "actual-budget",      5006,  "/",               120,  ["200-399"], "Budgeting"),
    ("Ghostfolio",       "http", "ghostfolio",         3333,  "/api/v1/health",  120,  ["200-299"], "Portfolio tracker"),
    ("Freqtrade",        "http", "freqtrade-bot",      8080,  "/api/v1/ping",     60,  ["200-299"], "Algo trading bot"),
    ("Pairs Screener",   "http", "pairs-screener",     8000,  "/api/v1/screener/status", 120, ["200-299"], "Regime-aware pair selection"),

    # ── Security & Utilities ───────────────────────────────────────────────
    ("Vaultwarden",      "http", "vaultwarden",          80,  "/alive",           60,  ["200-299"], "Password manager"),
    ("Atuin",            "http", "atuin",              8888,  "/",               120,  ["200-399"], "Shell history sync"),
    ("Rustypaste",       "http", "rustypaste",         8000,  "/",               120,  ["200-399"], "Pastebin"),
    ("PairDrop",         "http", "pairdrop",           3000,  "/",               120,  ["200-299"], "P2P file sharing"),

    # ── Remote hosts ───────────────────────────────────────────────────────
    ("Backrest (music-potato)", "port", "music-potato", 9898, None,             120,  ["200-299"], "Backup UI on remote host"),
]


def build_monitor(idx, name, mtype, host_or_url, port, health_path, interval, accepted, description):
    base = {
        "id": idx,
        "name": name,
        "type": mtype,
        "method": "GET",
        "maxretries": 2,
        "maxredirects": 10,
        "weight": 2000,
        "active": 1,
        "interval": interval,
        "retryInterval": 60,
        "keyword": None,
        "invertKeyword": False,
        "expiryNotification": False,
        "ignoreTls": False,
        "upsideDown": False,
        "notificationIDList": {"1": True},
        "headers": None,
        "body": None,
        "accepted_statuscodes": accepted,
        "dnsResolveType": "A",
        "dnsResolveServer": "1.1.1.1",
        "dnsLastResult": None,
        "proxyId": None,
        "description": description,
        "packetSize": 56,
    }

    if mtype == "port":
        base["url"] = None
        base["hostname"] = host_or_url
        base["port"] = port
    else:
        path = health_path or "/"
        base["url"] = f"http://{host_or_url}:{port}{path}"
        base["hostname"] = None
        base["port"] = None

    return base


NTFY_NOTIFICATION = {
    "id": 1,
    "name": "ntfy (potatostack-critical)",
    "type": "ntfy",
    "isDefault": 1,
    "config": json.dumps({
        "ntfyServerUrl": "http://ntfy:80",
        "ntfyTopic": "potatostack-critical",
        "ntfyPriority": 4,
        "ntfyAuthMethod": "none",
        "ntfyToken": "",
        "ntfyIcon": "",
        "ntfyActions": "",
    }),
}


def main():
    monitors = [
        build_monitor(i + 1, *entry)
        for i, entry in enumerate(MONITORS)
    ]

    output = {
        "version": "1.0.0",
        "notificationList": [NTFY_NOTIFICATION],
        "monitorList": monitors,
    }

    out_path = os.path.join(
        os.path.dirname(__file__), "../../config/uptime-kuma/import.json"
    )
    out_path = os.path.normpath(out_path)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    with open(out_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"Written {len(monitors)} monitors → {out_path}")


if __name__ == "__main__":
    main()
