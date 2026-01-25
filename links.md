# PotatoStack Service Links

**Tailnet:** `tale-iwato.ts.net`
**Host:** `potatostack.tale-iwato.ts.net` (100.108.216.90)

All services accessible via HTTPS using Tailscale certificates.
Ensure Tailscale is running on your device, then access: `https://potatostack.tale-iwato.ts.net:PORT`

## Dashboards

| Service | URL | Description |
|---------|-----|-------------|
| Homarr | https://potatostack.tale-iwato.ts.net:7575 | Main Dashboard |
| Traefik | https://potatostack.tale-iwato.ts.net:8088 | Reverse Proxy Dashboard |
| Uptime Kuma | https://potatostack.tale-iwato.ts.net:3001 | Uptime Monitoring |
| Grafana | https://potatostack.tale-iwato.ts.net:3002 | Metrics Dashboard |
| cAdvisor | https://potatostack.tale-iwato.ts.net:8089 | Container Metrics |

## Media

| Service | URL | Description |
|---------|-----|-------------|
| Jellyfin | https://potatostack.tale-iwato.ts.net:8096 | Media Server |
| Jellyseerr | https://potatostack.tale-iwato.ts.net:5055 | Media Requests |
| Sonarr | https://potatostack.tale-iwato.ts.net:8989 | TV Shows |
| Radarr | https://potatostack.tale-iwato.ts.net:7878 | Movies |
| Lidarr | https://potatostack.tale-iwato.ts.net:8686 | Music |
| Bazarr | https://potatostack.tale-iwato.ts.net:6767 | Subtitles |
| Bookshelf | https://potatostack.tale-iwato.ts.net:8787 | Ebooks |
| Audiobookshelf | https://potatostack.tale-iwato.ts.net:13378 | Audiobooks |
| Navidrome | https://potatostack.tale-iwato.ts.net:4533 | Music Streaming |
| Stash | https://potatostack.tale-iwato.ts.net:9900 | Media Organizer |

## Downloads (via VPN)

| Service | URL | Description |
|---------|-----|-------------|
| qBittorrent | https://potatostack.tale-iwato.ts.net:8282 | Torrents |
| pyLoad-ng | https://potatostack.tale-iwato.ts.net:8076 | Download Manager |
| pyLoad Click'n'Load | potatostack.tale-iwato.ts.net:9666 | Browser Extension |
| slskd | https://potatostack.tale-iwato.ts.net:2234 | Soulseek |
| SpotiFLAC | https://potatostack.tale-iwato.ts.net:8097 | Spotify Downloader |
| Pinchflat | https://potatostack.tale-iwato.ts.net:8945 | YouTube Downloader |
| Prowlarr | https://potatostack.tale-iwato.ts.net:9696 | Indexers |
| Gluetun Control | https://potatostack.tale-iwato.ts.net:8008 | VPN Status |

## Files & Photos

| Service | URL | Description |
|---------|-----|-------------|
| Filebrowser | https://potatostack.tale-iwato.ts.net:8090 | Web File Manager |
| Filestash | https://potatostack.tale-iwato.ts.net:8095 | Advanced File Manager |
| Syncthing | https://potatostack.tale-iwato.ts.net:8384 | File Sync |
| Immich | https://potatostack.tale-iwato.ts.net:2283 | Photo Management |

## Development

| Service | URL | Description |
|---------|-----|-------------|
| Gitea | https://potatostack.tale-iwato.ts.net:3004 | Git Server |
| Gitea SSH | ssh://potatostack.tale-iwato.ts.net:2223 | Git SSH |
| OpenSSH | ssh://potatostack.tale-iwato.ts.net:2222 | SSH/SFTP |
| Woodpecker | https://potatostack.tale-iwato.ts.net:3006 | CI/CD |

## Security

| Service | URL | Description |
|---------|-----|-------------|
| Vaultwarden | https://potatostack.tale-iwato.ts.net:8888 | Password Manager |

## Knowledge

| Service | URL | Description |
|---------|-----|-------------|
| Linkding | https://potatostack.tale-iwato.ts.net:9091 | Bookmarks |
| Miniflux | https://potatostack.tale-iwato.ts.net:8093 | RSS Reader |
| Obsidian LiveSync | https://potatostack.tale-iwato.ts.net:5984 | Notes Sync |

## Productivity

| Service | URL | Description |
|---------|-----|-------------|
| Mealie | https://potatostack.tale-iwato.ts.net:9925 | Recipes |
| Actual Budget | https://potatostack.tale-iwato.ts.net:5006 | Finance |

## Monitoring

| Service | URL | Description |
|---------|-----|-------------|
| Prometheus | https://potatostack.tale-iwato.ts.net:9090 | Metrics |
| Loki | https://potatostack.tale-iwato.ts.net:3100 | Logs |
| Alertmanager | https://potatostack.tale-iwato.ts.net:9093 | Alerts |
| Thanos Query | https://potatostack.tale-iwato.ts.net:10903 | Long-term Metrics |
| Scrutiny | https://potatostack.tale-iwato.ts.net:8087 | Disk Health |
| CrowdSec Metrics | https://potatostack.tale-iwato.ts.net:6060 | Security Metrics |

## Utilities

| Service | URL | Description |
|---------|-----|-------------|
| Healthchecks | https://potatostack.tale-iwato.ts.net:8001 | Cron Monitoring |
| Rustypaste | https://potatostack.tale-iwato.ts.net:8788 | Paste/File Sharing |
| ntfy | https://potatostack.tale-iwato.ts.net:8060 | Notifications |
| Atuin | https://potatostack.tale-iwato.ts.net:8889 | Shell History |
| Trivy | https://potatostack.tale-iwato.ts.net:8081 | Security Scanner |

## Backup

| Service | URL | Description |
|---------|-----|-------------|
| Kopia | https://potatostack.tale-iwato.ts.net:51515 | Backup Manager |
| Velld API | https://potatostack.tale-iwato.ts.net:8085 | Database Backup API |
| Velld Web | https://potatostack.tale-iwato.ts.net:3010 | Database Backup UI |

## Network Services

| Service | Port | Description |
|---------|------|-------------|
| Samba | 445 | SMB File Sharing (LAN) |
| Syncthing Discovery | 21027/udp | Local Discovery |
| Syncthing Transfer | 22000 | File Transfer |

## Quick Access

```bash
# Dashboard
open https://potatostack.tale-iwato.ts.net:7575

# Media
open https://potatostack.tale-iwato.ts.net:8096
open https://potatostack.tale-iwato.ts.net:5055

# Files & Photos
open https://potatostack.tale-iwato.ts.net:2283
open https://potatostack.tale-iwato.ts.net:8090
open https://potatostack.tale-iwato.ts.net:8095
open https://potatostack.tale-iwato.ts.net:8384

# Development
open https://potatostack.tale-iwato.ts.net:3004

# Monitoring
open https://potatostack.tale-iwato.ts.net:3002
open https://potatostack.tale-iwato.ts.net:3001

# Downloads (VPN)
open https://potatostack.tale-iwato.ts.net:8282
open https://potatostack.tale-iwato.ts.net:8076
open https://potatostack.tale-iwato.ts.net:2234

# Backups
open https://potatostack.tale-iwato.ts.net:3010
open https://potatostack.tale-iwato.ts.net:51515
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

## Kopia Host Backup

Kopia backs up:
- `/etc` - System configuration
- `/home` - User home directories
- `/root` - Root user directory
- `/var/log` - System logs
- Docker data from `/mnt/ssd/docker-data`
- All storage volumes

## Rustypaste Usage

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
