# PotatoStack Service Links

Tailnet: `tale-iwato.ts.net`
Host: `potatostack.tale-iwato.ts.net` (100.108.216.90)

**IMPORTANT:** Use the Tailscale hostname or IP directly in your browser. All services now listen on all interfaces (0.0.0.0) and are accessible via Tailscale.

Example: `http://100.108.216.90:7575` or via hostname when Tailscale DNS is configured.

## Dashboards & Management

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Homarr | http://potatostack.tale-iwato.ts.net:7575 | Dashboard |
| Traefik | http://potatostack.tale-iwato.ts.net:8088 | Reverse Proxy Dashboard |
| Uptime Kuma | http://potatostack.tale-iwato.ts.net:3001 | Uptime Monitoring |
| Netdata | http://potatostack.tale-iwato.ts.net:19999 | Real-time System Monitoring |
| Grafana | http://potatostack.tale-iwato.ts.net:3002 | Metrics Dashboard |

## Media Stack

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Jellyfin | http://potatostack.tale-iwato.ts.net:8096 | Media Server |
| Jellyseerr | http://potatostack.tale-iwato.ts.net:5055 | Media Requests |
| Sonarr | http://potatostack.tale-iwato.ts.net:8989 | TV Show Manager |
| Radarr | http://potatostack.tale-iwato.ts.net:7878 | Movie Manager |
| Lidarr | http://potatostack.tale-iwato.ts.net:8686 | Music Manager |
| Prowlarr | http://potatostack.tale-iwato.ts.net:9696 | Indexer Manager |
| Bazarr | http://potatostack.tale-iwato.ts.net:6767 | Subtitle Manager |
| Bookshelf | http://potatostack.tale-iwato.ts.net:8787 | Ebook Manager |
| Audiobookshelf | http://potatostack.tale-iwato.ts.net:13378 | Audiobook Server |
| Maintainerr | http://potatostack.tale-iwato.ts.net:6246 | Media Cleanup |
| Pinchflat | http://potatostack.tale-iwato.ts.net:8945 | YouTube Downloader |

## Download Clients (via Gluetun VPN)

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| qBittorrent | http://potatostack.tale-iwato.ts.net:8282 | Torrent Client |
| Aria2 WebUI | http://potatostack.tale-iwato.ts.net:6880 | Download Manager |
| slskd | http://potatostack.tale-iwato.ts.net:2234 | Soulseek Client |
| SpotiFLAC | http://potatostack.tale-iwato.ts.net:8097 | Spotify Downloader |
| Gluetun | http://potatostack.tale-iwato.ts.net:8000 | VPN Control |

## Photos & Files

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Immich | http://potatostack.tale-iwato.ts.net:2283 | Photo Management |
| Nextcloud | http://potatostack.tale-iwato.ts.net:8443 | Cloud Storage |
| Nextcloud AIO | http://potatostack.tale-iwato.ts.net:8080 | AIO Admin Interface |
| Syncthing | http://potatostack.tale-iwato.ts.net:8384 | File Sync |
| Kopia | http://potatostack.tale-iwato.ts.net:51515 | Backup Manager |

## Development & Productivity

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Gitea | http://potatostack.tale-iwato.ts.net:3004 | Git Server |
| Gitea SSH | ssh://potatostack.tale-iwato.ts.net:2222 | Git SSH |
| Woodpecker | http://potatostack.tale-iwato.ts.net:3006 | CI/CD |
| Code Server | http://potatostack.tale-iwato.ts.net:8444 | VS Code in Browser |
| n8n | http://potatostack.tale-iwato.ts.net:5678 | Workflow Automation |

## Security & Auth

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Authentik | http://potatostack.tale-iwato.ts.net:9000 | Identity Provider |
| Authentik HTTPS | https://potatostack.tale-iwato.ts.net:9443 | Identity Provider (HTTPS) |
| Vaultwarden | http://potatostack.tale-iwato.ts.net:8888 | Password Manager |

## Knowledge & Notes

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Linkding | http://potatostack.tale-iwato.ts.net:9091 | Bookmark Manager |
| Miniflux | http://potatostack.tale-iwato.ts.net:8093 | RSS Reader |

## Finance & Budget

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Actual Budget | http://potatostack.tale-iwato.ts.net:5006 | Budget Tracker |

## Monitoring & Observability

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Prometheus | http://potatostack.tale-iwato.ts.net:9090 | Metrics Database |
| Loki | http://potatostack.tale-iwato.ts.net:3100 | Log Aggregation |
| Alertmanager | http://potatostack.tale-iwato.ts.net:9093 | Alert Management |
| Thanos Query | http://potatostack.tale-iwato.ts.net:10903 | Long-term Metrics |
| Thanos Sidecar | http://potatostack.tale-iwato.ts.net:10902 | Thanos Sidecar |
| Parseable | http://potatostack.tale-iwato.ts.net:8094 | Log Analytics |
| Scrutiny | http://potatostack.tale-iwato.ts.net:8087 | Disk Health |
| CrowdSec Metrics | http://potatostack.tale-iwato.ts.net:6060 | Security Metrics |

## Utilities

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| IT Tools | http://potatostack.tale-iwato.ts.net:8091 | Developer Utilities |
| Healthchecks | http://potatostack.tale-iwato.ts.net:8001 | Cron Monitoring |
| Rustypaste | http://potatostack.tale-iwato.ts.net:8788 | Paste Service |
| Atuin | http://potatostack.tale-iwato.ts.net:8889 | Shell History Sync |
| Trivy | http://potatostack.tale-iwato.ts.net:8081 | Vulnerability Scanner |
| Velld Web | http://potatostack.tale-iwato.ts.net:3010 | Velld Web UI |
| Velld API | http://potatostack.tale-iwato.ts.net:8085 | Velld API |

## Quick Access (Primary Services)

```bash
# Dashboard
open http://potatostack.tale-iwato.ts.net:7575

# Media
open http://potatostack.tale-iwato.ts.net:8096   # Jellyfin
open http://potatostack.tale-iwato.ts.net:5055   # Jellyseerr

# Files
open http://potatostack.tale-iwato.ts.net:2283   # Immich
open http://potatostack.tale-iwato.ts.net:8384   # Syncthing

# Development
open http://potatostack.tale-iwato.ts.net:3004   # Gitea
open http://potatostack.tale-iwato.ts.net:8444   # Code Server
```
