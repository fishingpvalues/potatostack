# PotatoStack Service Links

Tailnet: `tale-iwato.ts.net`
Host: `potatostack.tale-iwato.ts.net` (100.108.216.90)

**IMPORTANT:** Use the Tailscale hostname or IP directly in your browser. All services now listen on all interfaces (0.0.0.0) and are accessible via Tailscale.

Example: `http://100.108.216.90:7575` or via hostname when Tailscale DNS is configured.

**For HTTPS/Secure Features (Vaultwarden, WebAuthn, etc.):** Access via Traefik reverse proxy URLs instead of direct ports.

## Services Requiring HTTPS (via Traefik)

These services need HTTPS for full functionality (WebAuthn, SharedArrayBuffer, Crypto API). Access them via Traefik reverse proxy:

| Service | Traefik HTTPS URL | Why HTTPS Required |
|---------|-------------------|-------------------|
| Vaultwarden | https://vault.danielhomelab.local | Web Crypto API for password encryption |
| Gitea | https://git.danielhomelab.local | WebAuthn/Security Keys authentication |
| Actual Budget | https://budget.danielhomelab.local | SharedArrayBuffer for WebAssembly |
| Authentik | https://auth.danielhomelab.local | Secure authentication flows |
| Grafana | https://grafana.danielhomelab.local | Dashboard security |
| Immich | https://immich.danielhomelab.local | Photo uploads and encryption |
| Filebrowser | https://filebrowser.danielhomelab.local | File upload/download security |

**Note:** Add `danielhomelab.local` to your `/etc/hosts` file pointing to your server IP, or configure DNS to resolve these domains.

Example `/etc/hosts` entry:
```
192.168.178.158  vault.danielhomelab.local git.danielhomelab.local budget.danielhomelab.local auth.danielhomelab.local grafana.danielhomelab.local immich.danielhomelab.local filebrowser.danielhomelab.local
```

## Dashboards & Management

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Homarr | http://potatostack.tale-iwato.ts.net:7575 | Dashboard |
| Traefik | http://potatostack.tale-iwato.ts.net:8088 | Reverse Proxy Dashboard |
| Uptime Kuma | http://potatostack.tale-iwato.ts.net:3001 | Uptime Monitoring (with Docker support) |
| Grafana | http://potatostack.tale-iwato.ts.net:3002 | Metrics Dashboard |
| cAdvisor | http://potatostack.tale-iwato.ts.net:8089 | Container Metrics |

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
| Pinchflat | http://potatostack.tale-iwato.ts.net:8945 | YouTube Downloader |

## Download Clients (via Gluetun VPN)

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| qBittorrent | http://potatostack.tale-iwato.ts.net:8282 | Torrent Client |
| Aria2 WebUI | http://potatostack.tale-iwato.ts.net:6880 | Download Manager |
| Aria2 RPC | http://potatostack.tale-iwato.ts.net:6800/jsonrpc | Aria2 JSON-RPC |
| slskd | http://potatostack.tale-iwato.ts.net:2234 | Soulseek Client (shares music & audiobooks) |
| SpotiFLAC | http://potatostack.tale-iwato.ts.net:8097 | Spotify Downloader |
| Gluetun | http://potatostack.tale-iwato.ts.net:8000 | VPN Control |

## Photos & Files

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Immich | http://potatostack.tale-iwato.ts.net:2283 | Photo Management |
| Filebrowser | http://potatostack.tale-iwato.ts.net:8090 | Web File Manager |
| Nextcloud | http://potatostack.tale-iwato.ts.net:8443 | Cloud Storage |
| Nextcloud AIO | http://potatostack.tale-iwato.ts.net:8080 | AIO Admin Interface |
| Syncthing | http://potatostack.tale-iwato.ts.net:8384 | File Sync |
| Kopia | https://potatostack.tale-iwato.ts.net:51515 | Backup Manager (with host backup) |

## Development & Productivity

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Gitea | http://potatostack.tale-iwato.ts.net:3004 | Git Server (use HTTPS via Traefik for WebAuthn) |
| Gitea SSH | ssh://potatostack.tale-iwato.ts.net:2222 | Git SSH |
| Woodpecker | http://potatostack.tale-iwato.ts.net:3006 | CI/CD |
| n8n | http://potatostack.tale-iwato.ts.net:5678 | Workflow Automation |

## Security & Auth

| Service | Tailscale URL | Description |
|---------|---------------|-------------|
| Authentik | http://potatostack.tale-iwato.ts.net:9000 | Identity Provider |
| Authentik HTTPS | https://potatostack.tale-iwato.ts.net:9443 | Identity Provider (HTTPS) |
| Vaultwarden | http://potatostack.tale-iwato.ts.net:8888 | Password Manager (**USE HTTPS for signup/WebAuthn**) |

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

## Disabled Services

| Service | Status | Notes |
|---------|--------|-------|
| Netdata | Disabled | Use Grafana + Prometheus + cAdvisor instead |
| Maintainerr | Disabled | Media cleanup tool |
| Code Server | Disabled | VS Code in browser |

## Quick Access (Primary Services)

```bash
# Dashboard
open http://potatostack.tale-iwato.ts.net:7575   # Homarr

# Media
open http://potatostack.tale-iwato.ts.net:8096   # Jellyfin
open http://potatostack.tale-iwato.ts.net:5055   # Jellyseerr

# Files
open http://potatostack.tale-iwato.ts.net:2283   # Immich
open http://potatostack.tale-iwato.ts.net:8085   # Filebrowser
open http://potatostack.tale-iwato.ts.net:8384   # Syncthing

# Development
open http://potatostack.tale-iwato.ts.net:3004   # Gitea

# Monitoring
open http://potatostack.tale-iwato.ts.net:3002   # Grafana
open http://potatostack.tale-iwato.ts.net:3001   # Uptime Kuma

# Downloads
open http://potatostack.tale-iwato.ts.net:8282   # qBittorrent
open http://potatostack.tale-iwato.ts.net:6880   # Aria2 WebUI (RPC: :6800/jsonrpc)
open http://potatostack.tale-iwato.ts.net:2234   # Soulseek
```

## AriaNg Connection Setup

To connect AriaNg to Aria2:
1. Open AriaNg WebUI at http://potatostack.tale-iwato.ts.net:6880
2. Go to Settings → RPC
3. Set RPC Address: `potatostack.tale-iwato.ts.net`
4. Set RPC Port: `6800`
5. Set RPC Secret: (your ARIA2_RPC_SECRET from .env)

## Kopia Host Backup

Kopia is configured to backup:
- `/etc` - System configuration
- `/home` - User home directories
- `/root` - Root user directory
- `/var/log` - System logs
- Docker data from `/mnt/ssd/docker-data`
- All storage volumes (photos, media, downloads, etc.)
