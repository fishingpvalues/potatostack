# PotatoStack Service Access Guide

Your services are accessible at `192.168.178.158` or via Traefik at `*.danielhomelab.local`.

## Starting Point: Homarr Dashboard

**Homarr** is your central dashboard for all services:
- **URL**: `https://home.danielhomelab.local` or `http://192.168.178.158:7575`
- Configure Homarr to add tiles for all your services
- Use it as your daily homepage to access everything

---

## All Services by Category

### Core Infrastructure
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| Traefik (Reverse Proxy) | - | 192.168.178.158:80/443 |
| Authentik (SSO) | https://authentik.danielhomelab.local | 192.168.178.158:9000 |
| AdGuard Home (DNS) | - | 192.168.178.158:3000 |
| Vaultwarden (Passwords) | https://vault.danielhomelab.local | 192.168.178.158:8043 |
| Infisical (Secrets) | https://secrets.danielhomelab.local | 192.168.178.158:8288 |

### Media Streaming
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| **Jellyfin** (Media Server) | https://jellyfin.danielhomelab.local | 192.168.178.158:8096 |
| Jellyseerr (Requests) | https://jellyseerr.danielhomelab.local | 192.168.178.158:5055 |
| Audiobookshelf | https://audiobookshelf.danielhomelab.local | 192.168.178.158:13378 |

### Media Management (Arr Stack)
| Service | HTTPS URL | VPN Port |
|---------|-----------|----------|
| Sonarr (TV Shows) | https://sonarr.danielhomelab.local | Via Gluetun :8989 |
| Radarr (Movies) | https://radarr.danielhomelab.local | Via Gluetun :7878 |
| Lidarr (Music) | https://lidarr.danielhomelab.local | Via Gluetun :8686 |
| Prowlarr (Indexers) | https://prowlarr.danielhomelab.local | Via Gluetun :9696 |
| Bazarr (Subtitles) | https://bazarr.danielhomelab.local | Via Gluetun :6767 |
| Bookshelf (Ebooks) | https://bookshelf.danielhomelab.local | Via Gluetun :8787 |

### Downloads (VPN Protected)
| Service | HTTPS URL | VPN Port |
|---------|-----------|----------|
| qBittorrent | https://qbittorrent.danielhomelab.local | Via Gluetun :8090 |
| Slskd (Soulseek) | https://slskd.danielhomelab.local | Via Gluetun :2234 |

### Photos & Files
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| Immich (Photos) | https://immich.danielhomelab.local | 192.168.178.158:2283 |
| Filebrowser | https://filebrowser.danielhomelab.local | 192.168.178.158:8090 |
| Filestash (Advanced) | https://filestash.danielhomelab.local | 192.168.178.158:8095 |
| Syncthing | https://syncthing.danielhomelab.local | 192.168.178.158:8384 |
| Samba (File Shares) | - | smb://192.168.178.158 |

### Monitoring & Observability
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| **Grafana** | https://grafana.danielhomelab.local | 192.168.178.158:3002 |
| Prometheus | https://prometheus.danielhomelab.local | 192.168.178.158:9090 |
| Uptime Kuma | https://uptime.danielhomelab.local | 192.168.178.158:3001 |
| Loki (Logs) | https://loki.danielhomelab.local | 192.168.178.158:3100 |
| Scrutiny (Disks) | https://scrutiny.danielhomelab.local | 192.168.178.158:8085 |

### Automation & Tools
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| n8n (Workflows) | https://n8n.danielhomelab.local | 192.168.178.158:5678 |
| Healthchecks | https://healthchecks.danielhomelab.local | 192.168.178.158:8001 |
| ntfy (Notifications) | https://ntfy.danielhomelab.local | 192.168.178.158:8060 |

### Productivity
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| Miniflux (RSS) | https://miniflux.danielhomelab.local | 192.168.178.158:8088 |
| Linkding (Bookmarks) | https://linkding.danielhomelab.local | 192.168.178.158:9091 |
| Paperless-ngx (Docs) | https://paperless.danielhomelab.local | 192.168.178.158:8085 |
| Actual Budget | https://actual.danielhomelab.local | 192.168.178.158:5006 |
| IT-Tools | https://it-tools.danielhomelab.local | 192.168.178.158:8087 |
| Rustypaste | https://paste.danielhomelab.local | 192.168.178.158:8788 |

### Development
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| Gitea | https://gitea.danielhomelab.local | 192.168.178.158:3003 |
| Code Server | https://code.danielhomelab.local | 192.168.178.158:8444 |
| Woodpecker CI | https://woodpecker.danielhomelab.local | 192.168.178.158:8000 |

### Security & Networking
| Service | HTTPS URL | Direct IP:Port |
|---------|-----------|----------------|
| CrowdSec | - | 192.168.178.158:8080 |
| Fail2ban | - | - |
| Gluetun (VPN) | - | 192.168.178.158:8000 |
| WireGuard | - | 192.168.178.158:51820/udp |
| Tailscale | - | Host network |

---

## Quick Start

1. **Open Homarr**: `https://home.danielhomelab.local`
2. **Add service tiles** for your most-used apps
3. **Login with Authentik** for SSO across services
4. **Stream content** via Jellyfin at `https://jellyfin.danielhomelab.local`
5. **Monitor everything** via Grafana at `https://grafana.danielhomelab.local`

## DNS Setup

Add to your local DNS (AdGuard/Pi-hole/hosts file):
```
192.168.178.158 *.danielhomelab.local
```

Or configure your router's DNS to point `*.danielhomelab.local` to `192.168.178.158`.
