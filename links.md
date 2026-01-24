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
| Readarr | https://potatostack.tale-iwato.ts.net:8787 | Ebook Manager |
| Audiobookshelf | https://potatostack.tale-iwato.ts.net:13378 | Audiobook Server |
| Navidrome | https://potatostack.tale-iwato.ts.net:4533 | Music Streaming |
| Pinchflat | https://potatostack.tale-iwato.ts.net:8945 | YouTube Downloader |
| Stash | https://potatostack.tale-iwato.ts.net:9900 | Media Organizer |

## Download Clients (via Gluetun VPN)

| Service | URL | Description |
|---------|-----|-------------|
| qBittorrent | https://potatostack.tale-iwato.ts.net:8282 | Torrent Client |
| Aria2 WebUI | https://potatostack.tale-iwato.ts.net:6880 | Download Manager |
| Aria2 RPC | https://potatostack.tale-iwato.ts.net:6800/jsonrpc | Aria2 JSON-RPC |
| slskd | https://potatostack.tale-iwato.ts.net:2234 | Soulseek Client |
| SpotiFLAC | https://potatostack.tale-iwato.ts.net:8097 | Spotify Downloader |
| Gluetun | https://potatostack.tale-iwato.ts.net:8000 | VPN Control |

## Photos & Files

| Service | URL | Description |
|---------|-----|-------------|
| Immich | https://potatostack.tale-iwato.ts.net:2283 | Photo Management |
| Filebrowser | https://potatostack.tale-iwato.ts.net:8090 | Web File Manager |
| Nextcloud | https://potatostack.tale-iwato.ts.net:8443 | Cloud Storage |
| Nextcloud AIO | https://potatostack.tale-iwato.ts.net:8080 | AIO Admin Interface |
| Syncthing | https://potatostack.tale-iwato.ts.net:8384 | File Sync |
| Kopia | https://potatostack.tale-iwato.ts.net:51515 | Backup Manager |

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
| Parseable | https://potatostack.tale-iwato.ts.net:8094 | Log Analytics |
| Scrutiny | https://potatostack.tale-iwato.ts.net:8087 | Disk Health |
| CrowdSec | https://potatostack.tale-iwato.ts.net:6060 | Security Metrics |

## Utilities

| Service | URL | Description |
|---------|-----|-------------|
| IT Tools | https://potatostack.tale-iwato.ts.net:8091 | Developer Utilities |
| Healthchecks | https://potatostack.tale-iwato.ts.net:8001 | Cron Monitoring |
| Rustypaste | https://potatostack.tale-iwato.ts.net:8788 | Paste Service |
| ntfy | https://potatostack.tale-iwato.ts.net:8060 | Notification Hub |
| Atuin | https://potatostack.tale-iwato.ts.net:8889 | Shell History Sync |
| Trivy | https://potatostack.tale-iwato.ts.net:8081 | Vulnerability Scanner |

## Quick Access

```bash
# Dashboard
open https://potatostack.tale-iwato.ts.net:7575

# Media
open https://potatostack.tale-iwato.ts.net:8096   # Jellyfin
open https://potatostack.tale-iwato.ts.net:5055   # Jellyseerr

# Files
open https://potatostack.tale-iwato.ts.net:2283   # Immich
open https://potatostack.tale-iwato.ts.net:8090   # Filebrowser

# Development
open https://potatostack.tale-iwato.ts.net:3004   # Gitea

# Monitoring
open https://potatostack.tale-iwato.ts.net:3002   # Grafana
open https://potatostack.tale-iwato.ts.net:3001   # Uptime Kuma

# Downloads
open https://potatostack.tale-iwato.ts.net:8282   # qBittorrent
```

## Kopia Host Backup

Kopia backs up:
- `/etc` - System configuration
- `/home` - User home directories
- `/root` - Root user directory
- `/var/log` - System logs
- Docker data from `/mnt/ssd/docker-data`
- All storage volumes

## AriaNg Connection Setup

1. Open https://potatostack.tale-iwato.ts.net:6880
2. Settings → RPC
3. RPC Address: `potatostack.tale-iwato.ts.net`
4. RPC Port: `6800`
5. RPC Secret: (from .env `ARIA2_RPC_SECRET`)
