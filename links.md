# PotatoStack Service Links

**Tailnet:** `tale-iwato.ts.net`
**Host:** `potatostack.tale-iwato.ts.net` (100.108.216.90)

All services accessible via HTTPS using Tailscale certificates.
Ensure Tailscale is running on your device, then access: `https://potatostack.tale-iwato.ts.net:PORT`

## Dashboards & Management

| Service | URL | Description |
|---------|-----|-------------|
| Homarr | https://potatostack.tale-iwato.ts.net:7575 | Dashboard |
| Traefik | https://potatostack.tale-iwato.ts.net:8088 | Reverse Proxy Dashboard |
| Uptime Kuma | https://potatostack.tale-iwato.ts.net:3001 | Uptime Monitoring |
| Grafana | https://potatostack.tale-iwato.ts.net:3002 | Metrics Dashboard |
| cAdvisor | https://potatostack.tale-iwato.ts.net:8089 | Container Metrics |

## Media Stack

| Service | URL | Description |
|---------|-----|-------------|
| Jellyfin | https://potatostack.tale-iwato.ts.net:8096 | Media Server |
| Jellyseerr | https://potatostack.tale-iwato.ts.net:5055 | Media Requests |
| Sonarr | https://potatostack.tale-iwato.ts.net:8989 | TV Show Manager |
| Radarr | https://potatostack.tale-iwato.ts.net:7878 | Movie Manager |
| Lidarr | https://potatostack.tale-iwato.ts.net:8686 | Music Manager |
| Prowlarr | https://potatostack.tale-iwato.ts.net:9696 | Indexer Manager |
| Bazarr | https://potatostack.tale-iwato.ts.net:6767 | Subtitle Manager |
| Bookshelf | https://potatostack.tale-iwato.ts.net:8787 | Ebook Manager |
| Audiobookshelf | https://potatostack.tale-iwato.ts.net:13378 | Audiobook Server |
| Navidrome | https://potatostack.tale-iwato.ts.net:4533 | Music Streaming |
| Pinchflat | https://potatostack.tale-iwato.ts.net:8945 | YouTube Downloader |
| Stash | https://potatostack.tale-iwato.ts.net:9900 | Media Organizer |

## Download Clients (via Gluetun VPN)

| Service | URL | Description |
|---------|-----|-------------|
| qBittorrent | https://potatostack.tale-iwato.ts.net:8282 | Torrent Client |
| pyLoad-ng | https://potatostack.tale-iwato.ts.net:8076 | Download Manager (HTTP/FTP) |
| pyLoad Click'n'Load | potatostack.tale-iwato.ts.net:9666 | Browser Extension Port |
| slskd | https://potatostack.tale-iwato.ts.net:2234 | Soulseek Client |
| SpotiFLAC | https://potatostack.tale-iwato.ts.net:8097 | Spotify Downloader |
| Gluetun Control | https://potatostack.tale-iwato.ts.net:8000 | VPN Status & Control |

## Photos & Files

| Service | URL | Description |
|---------|-----|-------------|
| Immich | https://potatostack.tale-iwato.ts.net:2283 | Photo Management |
| Filebrowser | https://potatostack.tale-iwato.ts.net:8090 | Web File Manager |
| Syncthing | https://potatostack.tale-iwato.ts.net:8384 | File Sync |

## Development & Productivity

| Service | URL | Description |
|---------|-----|-------------|
| Gitea | https://potatostack.tale-iwato.ts.net:3004 | Git Server |
| Gitea SSH | ssh://potatostack.tale-iwato.ts.net:2224 | Git SSH |
| OpenSSH | ssh://potatostack.tale-iwato.ts.net:2222 | SSH/SFTP |
| Woodpecker | https://potatostack.tale-iwato.ts.net:3006 | CI/CD |
| n8n | https://potatostack.tale-iwato.ts.net:5678 | Workflow Automation |
| Mealie | https://potatostack.tale-iwato.ts.net:9925 | Recipe Manager |

## Security & Auth

| Service | URL | Description |
|---------|-----|-------------|
| Authentik | https://potatostack.tale-iwato.ts.net:9000 | Identity Provider |
| Authentik HTTPS | https://potatostack.tale-iwato.ts.net:9443 | Identity Provider (native HTTPS) |
| Vaultwarden | https://potatostack.tale-iwato.ts.net:8888 | Password Manager |
| Infisical | https://potatostack.tale-iwato.ts.net:8288 | Secrets Management |

## Knowledge & Notes

| Service | URL | Description |
|---------|-----|-------------|
| Linkding | https://potatostack.tale-iwato.ts.net:9091 | Bookmark Manager |
| Miniflux | https://potatostack.tale-iwato.ts.net:8093 | RSS Reader |
| Obsidian LiveSync | https://potatostack.tale-iwato.ts.net:5984 | Obsidian CouchDB Sync |

## Finance

| Service | URL | Description |
|---------|-----|-------------|
| Actual Budget | https://potatostack.tale-iwato.ts.net:5006 | Budget Tracker |

## Monitoring & Observability

| Service | URL | Description |
|---------|-----|-------------|
| Prometheus | https://potatostack.tale-iwato.ts.net:9090 | Metrics Database |
| Loki | https://potatostack.tale-iwato.ts.net:3100 | Log Aggregation |
| Alertmanager | https://potatostack.tale-iwato.ts.net:9093 | Alert Management |
| Thanos Query | https://potatostack.tale-iwato.ts.net:10903 | Long-term Metrics |
| Thanos Sidecar | https://potatostack.tale-iwato.ts.net:10902 | Thanos Sidecar |
| Scrutiny | https://potatostack.tale-iwato.ts.net:8087 | Disk Health |
| CrowdSec Metrics | https://potatostack.tale-iwato.ts.net:6060 | Security Metrics |

## Utilities

| Service | URL | Description |
|---------|-----|-------------|
| IT Tools | https://potatostack.tale-iwato.ts.net:8091 | Developer Utilities |
| Healthchecks | https://potatostack.tale-iwato.ts.net:8001 | Cron Monitoring |
| Rustypaste | https://potatostack.tale-iwato.ts.net:8788 | Paste/File Sharing |
| ntfy | https://potatostack.tale-iwato.ts.net:8060 | Notification Hub |
| Atuin | https://potatostack.tale-iwato.ts.net:8889 | Shell History Sync |
| Trivy | https://potatostack.tale-iwato.ts.net:8081 | Vulnerability Scanner |

## Backup & Recovery

| Service | URL | Description |
|---------|-----|-------------|
| Kopia | https://potatostack.tale-iwato.ts.net:51515 | Backup Manager |
| Velld API | https://potatostack.tale-iwato.ts.net:8085 | Database Backup API |
| Velld Web | https://potatostack.tale-iwato.ts.net:3010 | Database Backup UI |

## Network Services

| Service | Port | Description |
|---------|------|-------------|
| Samba | 445 | SMB File Sharing (LAN only) |
| Syncthing Discovery | 21027/udp | Syncthing local discovery |
| Syncthing Transfer | 22000 | Syncthing file transfer |

## Quick Access

```bash
# Dashboard
open https://potatostack.tale-iwato.ts.net:7575

# Media
open https://potatostack.tale-iwato.ts.net:8096   # Jellyfin
open https://potatostack.tale-iwato.ts.net:5055   # Jellyseerr

# Files & Photos
open https://potatostack.tale-iwato.ts.net:2283   # Immich
open https://potatostack.tale-iwato.ts.net:8090   # Filebrowser
open https://potatostack.tale-iwato.ts.net:8384   # Syncthing

# Development
open https://potatostack.tale-iwato.ts.net:3004   # Gitea
open https://potatostack.tale-iwato.ts.net:5678   # n8n

# Monitoring
open https://potatostack.tale-iwato.ts.net:3002   # Grafana
open https://potatostack.tale-iwato.ts.net:3001   # Uptime Kuma

# Downloads (behind VPN)
open https://potatostack.tale-iwato.ts.net:8282   # qBittorrent
open https://potatostack.tale-iwato.ts.net:8076   # pyLoad-ng
open https://potatostack.tale-iwato.ts.net:2234   # slskd

# Backups
open https://potatostack.tale-iwato.ts.net:3010   # Velld
open https://potatostack.tale-iwato.ts.net:51515  # Kopia
```

## pyLoad-ng Setup

pyLoad-ng runs behind the Gluetun VPN killswitch for privacy.

**Ports:**
- WebUI: 8076 (external) → 8000 (internal)
- Click'n'Load: 9666 (for browser extensions)

**Storage paths:**
- Downloads: `/mnt/storage/downloads/pyload`
- Incomplete: `/mnt/cachehdd/downloads/pyload`

**First-time setup:**
1. Access https://potatostack.tale-iwato.ts.net:8076
2. Default credentials: `pyload` / `pyload`
3. Change password in Settings → General
4. Configure download paths in Settings → General

**Browser extension:** Install pyLoad Click'n'Load extension and point it to `potatostack.tale-iwato.ts.net:9666`

## Kopia Host Backup

Kopia backs up:
- `/etc` - System configuration
- `/home` - User home directories
- `/root` - Root user directory
- `/var/log` - System logs
- Docker data from `/mnt/ssd/docker-data`
- All storage volumes

## Rustypaste Usage

Upload files via curl:
```bash
# Upload a file
curl -F "file=@myfile.txt" https://potatostack.tale-iwato.ts.net:8788

# Upload with expiry (1 hour)
curl -F "file=@myfile.txt" -F "expire=1h" https://potatostack.tale-iwato.ts.net:8788

# Upload with custom name
curl -F "file=@myfile.txt" -F "url=custom-name" https://potatostack.tale-iwato.ts.net:8788

# Delete a file (requires delete token from config)
curl -X DELETE -H "Authorization: <delete_token>" https://potatostack.tale-iwato.ts.net:8788/filename
```

## Access Methods

See `docs/TRAEFIK_AUTHENTIK_TAILSCALE_GUIDE.md` for detailed explanation of:
- **Tailscale Serve** - Direct port access via `ts.net:PORT`
- **Traefik** - Domain-based routing via `service.local.domain`
- **Authentik** - SSO integration for protected services
