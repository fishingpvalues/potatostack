# PotatoStack Service Links

**Tailnet:** `tale-iwato.ts.net`
**Host:** `potatostack.tale-iwato.ts.net` (100.108.216.90)
**Domain:** `potatostack.tale-iwato.ts.net` (Traefik routes)

All services accessible via HTTPS using Tailscale certificates or Traefik reverse proxy.

## Dashboards

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Homarr | https://potatostack.tale-iwato.ts.net:7575 | https://home.potatostack.tale-iwato.ts.net | Main Dashboard |
| Traefik | https://potatostack.tale-iwato.ts.net:8088 | https://traefik.potatostack.tale-iwato.ts.net | Reverse Proxy Dashboard |
| Traefik GUI | - | https://traefik-gui.potatostack.tale-iwato.ts.net | Traefik Alternative UI |
| Uptime Kuma | https://potatostack.tale-iwato.ts.net:3001 | https://uptime.potatostack.tale-iwato.ts.net | Uptime Monitoring |
| Grafana | https://potatostack.tale-iwato.ts.net:3002 | https://grafana.potatostack.tale-iwato.ts.net | Metrics Dashboard |
| cAdvisor | https://potatostack.tale-iwato.ts.net:8089 | https://cadvisor.potatostack.tale-iwato.ts.net | Container Metrics |

## Core Infrastructure

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Traefik HTTP | http://potatostack.tale-iwato.ts.net:80 | - | HTTP Redirect |
| Traefik HTTPS | https://potatostack.tale-iwato.ts.net:443 | - | HTTPS Entry |
| Gluetun Control | https://potatostack.tale-iwato.ts.net:8008 | https://gluetun.potatostack.tale-iwato.ts.net | VPN Status |
| Vaultwarden WebUI | https://potatostack.tale-iwato.ts.net:8888 | https://vault.potatostack.tale-iwato.ts.net | Password Manager |
| Vaultwarden WebSockets | https://potatostack.tale-iwato.ts.net:3012 | - | Live Sync |

## Media

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Jellyfin | https://potatostack.tale-iwato.ts.net:8096 | https://jellyfin.potatostack.tale-iwato.ts.net | Media Server |
| Jellyfin HTTPS | https://potatostack.tale-iwato.ts.net:8920 | - | Media Server (HTTPS) |
| Jellyseerr | https://potatostack.tale-iwato.ts.net:5055 | https://jellyseerr.potatostack.tale-iwato.ts.net | Media Requests |
| Sonarr | https://potatostack.tale-iwato.ts.net:8989 | https://sonarr.potatostack.tale-iwato.ts.net | TV Shows |
| Radarr | https://potatostack.tale-iwato.ts.net:7878 | https://radarr.potatostack.tale-iwato.ts.net | Movies |
| Lidarr | https://potatostack.tale-iwato.ts.net:8686 | https://lidarr.potatostack.tale-iwato.ts.net | Music |
| Bazarr | https://potatostack.tale-iwato.ts.net:6767 | https://bazarr.potatostack.tale-iwato.ts.net | Subtitles |
| Bookshelf | https://potatostack.tale-iwato.ts.net:8787 | https://bookshelf.potatostack.tale-iwato.ts.net | Ebooks |
| Audiobookshelf | https://potatostack.tale-iwato.ts.net:13378 | https://audiobooks.potatostack.tale-iwato.ts.net | Audiobooks |
| Navidrome | https://potatostack.tale-iwato.ts.net:4533 | https://music.potatostack.tale-iwato.ts.net | Music Streaming |
| Stash | https://potatostack.tale-iwato.ts.net:9900 | - | Media Organizer (VPN only) |

## Downloads (via VPN)

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| qBittorrent | https://potatostack.tale-iwato.ts.net:8282 | https://qbittorrent.potatostack.tale-iwato.ts.net | Torrents |
| qBittorrent Peer | - | - | 51413/tcp, 51413/udp |
| pyLoad-ng | https://potatostack.tale-iwato.ts.net:8076 | https://pyload.potatostack.tale-iwato.ts.net | Download Manager |
| pyLoad Click'n'Load | https://potatostack.tale-iwato.ts.net:9666 | - | Browser Extension |
| slskd | https://potatostack.tale-iwato.ts.net:2234 | https://slskd.potatostack.tale-iwato.ts.net | Soulseek |
| slskd Peer | - | - | 50000 |
| SpotiFLAC | https://potatostack.tale-iwato.ts.net:8097 | https://spotiflac.potatostack.tale-iwato.ts.net | Spotify Downloader |
| Prowlarr | https://potatostack.tale-iwato.ts.net:9696 | https://prowlarr.potatostack.tale-iwato.ts.net | Indexers |

## Files & Photos

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Filebrowser | https://potatostack.tale-iwato.ts.net:8090 | https://filebrowser.potatostack.tale-iwato.ts.net | Web File Manager |
| Filestash | https://potatostack.tale-iwato.ts.net:8095 | https://filestash.potatostack.tale-iwato.ts.net | Advanced File Manager |
| Syncthing WebUI | https://potatostack.tale-iwato.ts.net:8384 | https://syncthing.potatostack.tale-iwato.ts.net | File Sync |
| Syncthing Discovery | - | - | 21027/udp |
| Syncthing Transfer | - | - | 22000/tcp, 22000/udp |
| Immich | https://potatostack.tale-iwato.ts.net:2283 | https://immich.potatostack.tale-iwato.ts.net | Photo Management |

## Development

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Gitea | https://potatostack.tale-iwato.ts.net:3004 | https://git.potatostack.tale-iwato.ts.net | Git Server |
| Gitea SSH | ssh://potatostack.tale-iwato.ts.net:2223 | ssh://git.potatostack.tale-iwato.ts.net:2223 | Git SSH |
| Woodpecker | https://potatostack.tale-iwato.ts.net:3006 | https://ci.potatostack.tale-iwato.ts.net | CI/CD |

## Automation & Workflows

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| n8n | https://potatostack.tale-iwato.ts.net:5678 | https://n8n.potatostack.tale-iwato.ts.net | Workflow Automation |
| RSS-Bridge | https://potatostack.tale-iwato.ts.net:3007 | https://rssbridge.potatostack.tale-iwato.ts.net | RSS Feed Generator |
| Miniflux Webhook | - | https://miniflux-webhook.potatostack.tale-iwato.ts.net | RSS to ntfy |
| Jellyfin Webhook | - | https://jellyfin-webhook.potatostack.tale-iwato.ts.net | Media to ntfy |
| Jellyseerr Webhook | - | https://jellyseerr-webhook.potatostack.tale-iwato.ts.net | Requests to ntfy |
| Healthchecks | https://potatostack.tale-iwato.ts.net:8001 | https://healthchecks.potatostack.tale-iwato.ts.net | Cron Monitoring |

## Knowledge & Productivity

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Obsidian LiveSync | https://potatostack.tale-iwato.ts.net:5984 | https://obsidian.potatostack.tale-iwato.ts.net | Notes Sync |
| Linkding | https://potatostack.tale-iwato.ts.net:9091 | https://linkding.potatostack.tale-iwato.ts.net | Bookmarks |
| Miniflux | https://potatostack.tale-iwato.ts.net:8093 | https://rss.potatostack.tale-iwato.ts.net | RSS Reader |
| Mealie | https://potatostack.tale-iwato.ts.net:9925 | https://mealie.potatostack.tale-iwato.ts.net | Recipes |
| Actual Budget | https://potatostack.tale-iwato.ts.net:5006 | https://budget.potatostack.tale-iwato.ts.net | Finance |

## Monitoring & Observability

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Prometheus | https://potatostack.tale-iwato.ts.net:9090 | https://prometheus.potatostack.tale-iwato.ts.net | Metrics Collection |
| Thanos Sidecar | https://potatostack.tale-iwato.ts.net:10902 | - | Long-term Storage |
| Thanos Query | https://potatostack.tale-iwato.ts.net:10903 | https://thanos.potatostack.tale-iwato.ts.net | Unified Query |
| Loki | https://potatostack.tale-iwato.ts.net:3100 | https://loki.potatostack.tale-iwato.ts.net | Log Aggregation |
| Alertmanager | https://potatostack.tale-iwato.ts.net:9093 | https://alerts.potatostack.tale-iwato.ts.net | Alert Routing |
| Scrutiny | https://potatostack.tale-iwato.ts.net:8087 | https://scrutiny.potatostack.tale-iwato.ts.net | Disk Health |
| CrowdSec Metrics | https://potatostack.tale-iwato.ts.net:6060 | - | Security Metrics |

## Security & Notifications

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| ntfy | https://potatostack.tale-iwato.ts.net:8060 | https://ntfy.potatostack.tale-iwato.ts.net | Notification Hub |
| Alertmanager ntfy | - | - | Alert Formatter |
| Trivy | https://potatostack.tale-iwato.ts.net:8081 | - | Security Scanner |

## Utilities & Tools

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Rustypaste | https://potatostack.tale-iwato.ts.net:8788 | https://paste.potatostack.tale-iwato.ts.net | Pastebin |
| Atuin | https://potatostack.tale-iwato.ts.net:8889 | https://atuin.potatostack.tale-iwato.ts.net | Shell History |
| OpenSSH | ssh://potatostack.tale-iwato.ts.net:2222 | - | SSH/SFTP Access |
| Samba | - | - | SMB File Sharing (445) |

## Backup & Storage

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Velld API | https://potatostack.tale-iwato.ts.net:8085 | https://velld-api.potatostack.tale-iwato.ts.net | Database Backup API |
| Velld Web | https://potatostack.tale-iwato.ts.net:3010 | https://velld.potatostack.tale-iwato.ts.net | Database Backup UI |
| Backrest | https://potatostack.tale-iwato.ts.net:9898 | https://backrest.potatostack.tale-iwato.ts.net | Restic Backup WebUI |

## Monitoring Scripts (Background)

| Service | Description |
|---------|-------------|
| Gluetun Monitor | VPN connection monitoring & restart |
| Disk Space Monitor | Storage usage alerts |
| Traefik Log Monitor | Certificate error monitoring |
| Backup Monitor | Backup freshness checks |
| DB Health Monitor | PostgreSQL/Redis health |
| Tailscale Connectivity Monitor | Mesh network health |
| Internet Connectivity Monitor | Network availability |
| slskd Queue Monitor | Soulseek queue tracking |
| Immich Log Monitor | Photo service error monitoring |

## Databases (Internal)

| Service | Internal Port | Description |
|---------|---------------|-------------|
| PostgreSQL | 5432 | Primary Database |
| PgBouncer | 5432 | Connection Pool |
| MongoDB | 27017 | Document Database |
| Redis Cache | 6379 | Shared Cache |
| CouchDB | 5984 | Obsidian Sync |

## Development Tools

| Service | Port Link | Description |
|---------|-----------|-------------|
| Article Extractor | - | Full-text extraction service |
| DuckDB Container | - | Ad-hoc analytics (no port) |
| tdl Container | - | Telegram downloader (VPN) |

## Quick Access

```bash
# Dashboard
open https://potatostack.tale-iwato.ts.net:7575
open https://home.potatostack.tale-iwato.ts.net

# Media
open https://potatostack.tale-iwato.ts.net:8096
open https://jellyfin.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:5055
open https://jellyseerr.potatostack.tale-iwato.ts.net

# Files & Photos
open https://potatostack.tale-iwato.ts.net:2283
open https://immich.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:8090
open https://filebrowser.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:8095
open https://filestash.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:8384
open https://syncthing.potatostack.tale-iwato.ts.net

# Development
open https://potatostack.tale-iwato.ts.net:3004
open https://git.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:3006
open https://ci.potatostack.tale-iwato.ts.net

# Automation
open https://potatostack.tale-iwato.ts.net:5678
open https://n8n.potatostack.tale-iwato.ts.net

# Monitoring
open https://potatostack.tale-iwato.ts.net:3002
open https://grafana.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:3001
open https://uptime.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:9090
open https://prometheus.potatostack.tale-iwato.ts.net

# Downloads (VPN)
open https://potatostack.tale-iwato.ts.net:8282
open https://qbittorrent.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:8076
open https://pyload.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:2234
open https://slskd.potatostack.tale-iwato.ts.net

# Backups
open https://potatostack.tale-iwato.ts.net:3010
open https://velld.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:9898
open https://backrest.potatostack.tale-iwato.ts.net
```

## Access Methods

### Tailscale HTTPS (Port-based)
- URL: `https://potatostack.tale-iwato.ts.net:PORT`
- Requires: Tailscale installed and logged in
- Works for: All services with exposed ports
- Advantage: Direct access, no DNS setup needed

### Traefik Reverse Proxy (Domain-based)
- URL: `https://SERVICE.potatostack.tale-iwato.ts.net`
- Requires: Tailscale DNS enabled (automatic)
- Works for: All services with Traefik labels
- Advantage: Clean URLs, unified SSL, SSO integration

### VPN-Tunnelled Services
Some services run behind Gluetun VPN for privacy:
- Sonarr, Radarr, Lidarr, Bazarr, Bookshelf
- qBittorrent, pyLoad, slskd
- SpotiFLAC, Stash

Access these via:
1. Traefik URL (recommended) - `https://sonarr.potatostack.tale-iwato.ts.net`
2. Direct port through Gluetun - `https://potatostack.tale-iwato.ts.net:8989`

## Storage Structure

```
/mnt/storage          - Main HDD storage (media, downloads, files)
/mnt/ssd/docker-data  - SSD docker volumes (databases, configs)
/mnt/cachehdd        - Cache HDD (temp files, transcodes)
```

## Network Configuration

```
Tailscale Network: tale-iwato.ts.net
Docker Network: potatostack (172.22.0.0/16)
VPN Network: Gluetun (varies by provider)
```

## Disabled Services

The following services are commented out in docker-compose.yml:
- AdGuard Home - DNS-level ad blocking
- Authentik - SSO provider
- WireGuard - VPN (replaced by Tailscale + Gluetun)
- Open WebUI - LLM interface
- Paperless-ngx - Document management (OOM issues)
- Code-server - VS Code in browser
- IT-Tools - Developer tools
- Infisical - Secrets management
- fail2ban - Intrusion prevention (use CrowdSec)
- Maintainerr - Media library cleanup
- Pinchflat - YouTube downloader
- Stirling-PDF - PDF tools

To enable any disabled service:
1. Uncomment service block in docker-compose.yml
2. Run `docker compose up -d <service-name>`
3. Service will be accessible at `https://SERVICE.potatostack.tale-iwato.ts.net`
