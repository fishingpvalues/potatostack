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

## Media

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Jellyfin | https://potatostack.tale-iwato.ts.net:8096 | https://jellyfin.potatostack.tale-iwato.ts.net | Media Server |
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
| pyLoad-ng | https://potatostack.tale-iwato.ts.net:8076 | https://pyload.potatostack.tale-iwato.ts.net | Download Manager |
| pyLoad Click'n'Load | https://potatostack.tale-iwato.ts.net:9666 | - | Browser Extension |
| slskd | https://potatostack.tale-iwato.ts.net:2234 | https://slskd.potatostack.tale-iwato.ts.net | Soulseek |
| SpotiFLAC | https://potatostack.tale-iwato.ts.net:8097 | https://spotiflac.potatostack.tale-iwato.ts.net | Spotify Downloader |
# | Pinchflat | https://potatostack.tale-iwato.ts.net:8945 | https://pinchflat.potatostack.tale-iwato.ts.net | YouTube Downloader |
| Prowlarr | https://potatostack.tale-iwato.ts.net:9696 | https://prowlarr.potatostack.tale-iwato.ts.net | Indexers |
| Gluetun Control | https://potatostack.tale-iwato.ts.net:8008 | https://gluetun.potatostack.tale-iwato.ts.net | VPN Status |

## Files & Photos

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Filebrowser | https://potatostack.tale-iwato.ts.net:8090 | https://filebrowser.potatostack.tale-iwato.ts.net | Web File Manager |
| Filestash | https://potatostack.tale-iwato.ts.net:8095 | https://filestash.potatostack.tale-iwato.ts.net | Advanced File Manager |
| Syncthing | https://potatostack.tale-iwato.ts.net:8384 | https://syncthing.potatostack.tale-iwato.ts.net | File Sync |
| Immich | https://potatostack.tale-iwato.ts.net:2283 | https://immich.potatostack.tale-iwato.ts.net | Photo Management |

## Development

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Gitea | https://potatostack.tale-iwato.ts.net:3004 | https://git.potatostack.tale-iwato.ts.net | Git Server |
| Gitea SSH | ssh://potatostack.tale-iwato.ts.net:2223 | ssh://git.potatostack.tale-iwato.ts.net:2223 | Git SSH |
| Woodpecker | https://potatostack.tale-iwato.ts.net:3006 | https://ci.potatostack.tale-iwato.ts.net | CI/CD |

## Security

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Vaultwarden | https://potatostack.tale-iwato.ts.net:8888 | https://vault.potatostack.tale-iwato.ts.net | Password Manager |

## Knowledge

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Linkding | https://potatostack.tale-iwato.ts.net:9091 | https://linkding.potatostack.tale-iwato.ts.net | Bookmarks |
| Miniflux | https://potatostack.tale-iwato.ts.net:8093 | https://rss.potatostack.tale-iwato.ts.net | RSS Reader |
| Obsidian LiveSync | https://potatostack.tale-iwato.ts.net:5984 | https://obsidian.potatostack.tale-iwato.ts.net | Notes Sync |

## Productivity

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Mealie | https://potatostack.tale-iwato.ts.net:9925 | https://mealie.potatostack.tale-iwato.ts.net | Recipes |
| Actual Budget | https://potatostack.tale-iwato.ts.net:5006 | https://budget.potatostack.tale-iwato.ts.net | Finance |

## Monitoring

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Prometheus | https://potatostack.tale-iwato.ts.net:9090 | https://prometheus.potatostack.tale-iwato.ts.net | Metrics |
| Loki | https://potatostack.tale-iwato.ts.net:3100 | https://loki.potatostack.tale-iwato.ts.net | Logs |
| Alertmanager | https://potatostack.tale-iwato.ts.net:9093 | https://alerts.potatostack.tale-iwato.ts.net | Alerts |
| Thanos Query | https://potatostack.tale-iwato.ts.net:10903 | https://thanos.potatostack.tale-iwato.ts.net | Long-term Metrics |
| Scrutiny | https://potatostack.tale-iwato.ts.net:8087 | https://scrutiny.potatostack.tale-iwato.ts.net | Disk Health |
| CrowdSec Metrics | https://potatostack.tale-iwato.ts.net:6060 | - | Security Metrics |

## Utilities

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Healthchecks | https://potatostack.tale-iwato.ts.net:8001 | https://healthchecks.potatostack.tale-iwato.ts.net | Cron Monitoring |
| Rustypaste | https://potatostack.tale-iwato.ts.net:8788 | https://paste.potatostack.tale-iwato.ts.net | Paste/File Sharing |
| ntfy | https://potatostack.tale-iwato.ts.net:8060 | https://ntfy.potatostack.tale-iwato.ts.net | Notifications |
| Atuin | https://potatostack.tale-iwato.ts.net:8889 | https://atuin.potatostack.tale-iwato.ts.net | Shell History |
| Trivy | https://potatostack.tale-iwato.ts.net:8081 | - | Security Scanner |

## Backup

| Service | Port Link | Traefik Link | Description |
|---------|-----------|-------------|-------------|
| Velld API | https://potatostack.tale-iwato.ts.net:8085 | https://velld-api.potatostack.tale-iwato.ts.net | Database Backup API |
| Velld Web | https://potatostack.tale-iwato.ts.net:3010 | https://velld.potatostack.tale-iwato.ts.net | Database Backup UI |

## Network Services

| Service | Port | Description |
|---------|------|-------------|
| OpenSSH | 2222 | SSH/SFTP Access |
| Samba | 445 | SMB File Sharing (LAN) |
| Syncthing Discovery | 21027/udp | Local Discovery |
| Syncthing Transfer | 22000 | File Transfer |

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

# Monitoring
open https://potatostack.tale-iwato.ts.net:3002
open https://grafana.potatostack.tale-iwato.ts.net
open https://potatostack.tale-iwato.ts.net:3001
open https://uptime.potatostack.tale-iwato.ts.net

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

## pyLoad-ng Setup

pyLoad-ng runs behind the Gluetun VPN killswitch for privacy.

**Access URLs:**
- Port-based: https://potatostack.tale-iwato.ts.net:8076
- Traefik: https://pyload.potatostack.tale-iwato.ts.net

**Ports:**
- WebUI: 8076 (external) → 8000 (internal)
- Click'n'Load: 9666 (for browser extensions)

**Storage paths:**
- Downloads: `/mnt/storage/downloads/pyload`
- Incomplete: `/mnt/cachehdd/downloads/pyload`

**First-time setup:**
1. Access https://pyload.potatostack.tale-iwato.ts.net
2. Default credentials: `pyload` / `pyload`
3. Change password in Settings → General
4. Configure download paths in Settings → General


## Rustypaste Usage

```bash
# Upload a file (port-based)
curl -F "file=@myfile.txt" https://potatostack.tale-iwato.ts.net:8788

# Upload with expiry (1 hour)
curl -F "file=@myfile.txt" -F "expire=1h" https://potatostack.tale-iwato.ts.net:8788

# Upload with custom name
curl -F "file=@myfile.txt" -F "url=custom-name" https://potatostack.tale-iwato.ts.net:8788

# Delete a file (requires delete token from config)
curl -X DELETE -H "Authorization: <delete_token>" https://potatostack.tale-iwato.ts.net:8788/filename

# Or use Traefik URL:
curl -F "file=@myfile.txt" https://paste.potatostack.tale-iwato.ts.net
```

## Disabled Services

The following services are commented out in docker-compose.yml:
- AdGuard Home - DNS-level ad blocking
- Authentik - SSO provider
- WireGuard - VPN (replaced by Tailscale + Gluetun)
- Open WebUI - LLM interface
- n8n - Workflow automation
- Paperless-ngx - Document management
- Code-server - VS Code in browser
- IT-Tools - Developer tools
- Infisical - Secrets management
- fail2ban - Intrusion prevention (use CrowdSec)

To enable any disabled service:
1. Uncomment service block in docker-compose.yml
2. Run `docker compose up -d <service-name>`
3. Service will be accessible at `https://SERVICE.potatostack.tale-iwato.ts.net`
