# LePotato SBC Deployment Guide

## Hardware Specifications

| Component | Specification |
|-----------|---------------|
| **Model** | LePotato (AML-S905X-CC) |
| **CPU** | ARM64 quad-core (1.5GHz) |
| **RAM** | 2GB DDR3 |
| **Network** | 100Mbps Ethernet |
| **Storage** | 64GB eMMC (internal) + USB 2.0 |
| **OS** | Armbian |

## Constraints Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                     LEPOTATO CONSTRAINTS                        │
├─────────────────────────────────────────────────────────────────┤
│  RAM:      2GB      ← Very limited, need lightweight services │
│  Ethernet: 100Mbps  ← Slow, no 4K streaming                     │
│  USB:      2.0      ← Max ~30-40MB/s read/write                │
│  Storage:  64GB     ← Minimal, no media storage                 │
│  Arch:     ARM64    ← Must use ARM-compatible images           │
└─────────────────────────────────────────────────────────────────┘
```

## Recommended Services

### Tier 1: Ideal Candidates (Guaranteed to work)

| Service | RAM | Storage | Network | Notes |
|---------|-----|---------|---------|-------|
| **adguardhome** | ~100MB | ~50MB | Low | DNS + Ad-blocking. Very lightweight |
| **ntfy** | ~50MB | ~20MB | Low | Push notifications. Minimal footprint |
| **healthchecks** | ~100MB | ~50MB | Low | Uptime monitoring. Python-based |
| **searxng** | ~200MB | ~50MB | Medium | Meta search engine. No storage needed |
| **homer** | ~50MB | ~10MB | Low | Dashboard. Static HTML |
| **pairdrop** | ~100MB | ~50MB | Low | P2P file transfer. No storage |
| **flaresolverr** | ~300MB | ~100MB | Medium | Cloudflare bypass. Proxy requests |
| **it-tools** | ~150MB | ~50MB | Low | Collection of IT utilities |
| **gluetun** | ~50MB | ~20MB | High | VPN container. Required for torrent/P2P services |
| **backrest** | ~200MB | ~50MB | Low | Restic backup UI. Very lightweight |
| **tailscale** | ~100MB | ~20MB | Medium | Wireguard VPN. Access services remotely |
| **linkding** | ~150MB | ~50MB | Low | Bookmark manager. SQLite-based, very lightweight |
| **whoogle** | ~200MB | ~50MB | Low | Private Google search proxy. No tracking/ads |
| **redlib** | ~150MB | ~50MB | Low | Privacy Reddit frontend. No bloat |
| **uptime-kuma** | ~300MB | ~100MB | Low | Uptime monitoring. Nice UI |
| **microbin** | ~50MB | ~10MB | Low | Tiny pastebin. Ultra lightweight Go binary |
| **changedetection** | ~200MB | ~50MB | Low | Website change monitoring. Notifications |
| **pi-hole** | ~100MB | ~50MB | Low | DNS-level ad-blocking (alternative to AdGuard) |
| **portainer** | ~200MB | ~100MB | Low | Docker container management UI |

### Tier 2: Usable with Caution

| Service | RAM | Storage | Notes |
|---------|-----|---------|-------|
| **bazarr** | ~300MB | ~200MB | Subtitle downloader only. Minimal storage |
| **prowlarr** | ~300MB | ~200MB | Indexer manager. Very lightweight |
| **rustypaste** | ~100MB | ~50MB | Pastebin service. Text only |
| **filestash** | ~200MB | ~100MB | Web file manager. Proxy to main server |
| **baikal** | ~200MB | ~100MB | CalDAV/CardDAV. Contacts/calendar sync |
| **miniflux** | ~300MB | ~500MB | RSS reader. Stores articles locally |
| **syncthing** | ~200MB | ~100MB | File sync between devices |
| **duplicati** | ~300MB | ~100MB | Backup to various backends |
| **homeassistant** | ~500MB | ~500MB | Home automation. Requires careful resource management |
| **dashy** | ~200MB | ~50MB | Customizable dashboard (alternative to homer) |

### Tier 3: Possible (Requires optimization)

| Service | RAM | Notes |
|---------|-----|-------|
| **uptime-kuma** | ~500MB | Heavier but works on 2GB |
| **qbittorrent** | ~500MB | Lightweight torrent client. Use remote downloads |
| **nginx** | ~50MB | Reverse proxy. For simple configs |

---

## NOT Recommended

### These will NOT work on LePotato:

| Service | Reason |
|---------|--------|
| **jellyfin** | Transcoding needs more CPU/RAM |
| **immich** | ML requires >2GB RAM |
| **stash** | Heavy ffmpeg processing |
| **postgres** | Too heavy for 2GB |
| **prometheus/grafana/loki** | Metrics storage needs disk |
| **gitea** | Git operations need more RAM |
| **paperless-ngx** | OOM issues, needs Celery workers |
| **bitmagnet** | Needs Postgres + heavy I/O |
| **Any media server** | Storage + transcoding |
| **homeassistant** | Better on main server (DB, complexity) |

---

## What's Missing from Your Stack

Based on your current docker-compose, these lightweight services are NOT in your stack but work great on LePotato:

| Service | Why Add | RAM |
|---------|---------|-----|
| **linkding** | Better bookmark manager than Shiori | ~150MB |
| **microbin** | Lighter than rustypaste, no deps | ~50MB |
| **changedetection** | Monitor websites for changes | ~200MB |
| **pi-hole** | Alternative to AdGuard (your choice) | ~100MB |
| **portainer** | Easy container management | ~200MB |
| **dashy** | Alternative to homer, more customizable | ~200MB |
| **duplicati** | Backup solution (you have backrest/restic) | ~300MB |

---

## Network Architecture

### Option A: Standalone Services

```
┌──────────────┐      ┌──────────────────┐
│   LePotato   │      │   Main Server    │
│  (adguard,   │      │  (jellyfin,      │
│   ntfy,      │ ───► │   postgres,      │
│   homer)     │      │   media, etc.)   │
└──────────────┘      └──────────────────┘
```

### Option B: VPN-Enabled Services

If you want qBittorrent/slskd behind VPN on LePotato:

```
┌──────────────┐
│   LePotato   │
│  ┌────────┐  │
│  │gluetun │  │  ← Your own gluetun instance
│  └───┬────┘  │
│      │       │
│  qbittorrent │
│     slskd    │
└──────────────┘
```

---

## Storage Strategy

Since you only have 64GB:

1. **Use main server for data** - Mount via NFS/Samba from main server
2. **Minimal local storage** - Only for configs
3. **Log rotation** - Configure services to limit log size

### Suggested Volume Mounts

```yaml
volumes:
  - /mnt/storage/downloads:/downloads    # Remote mount via NFS
  - /mnt/storage/media:/media              # Remote mount (read-only)
```

---

## Docker Configuration

### Resource Limits (Recommended)

```yaml
deploy:
  resources:
    limits:
      cpus: "1.0"
      memory: 512M    # Never exceed 1GB total
    reservations:
      cpus: "0.25"
      memory: 128M
```

### Docker Compose Example

```yaml
version: "3.8"

services:
  adguardhome:
    image: adguard/adguardhome:latest
    container_name: adguardhome
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "3080:3080/tcp"
    volumes:
      - adguard-work:/opt/adguardhome/work
      - adguard-conf:/opt/adguardhome/conf
    restart: unless-stopped

  ntfy:
    image: binwiederhier/ntfy:latest
    container_name: ntfy
    ports:
      - "3085:80"
    volumes:
      - ntfy-cache:/var/cache/ntfy
    environment:
      - TZ=Europe/Berlin
    restart: unless-stopped

  homer:
    image: b4bz/homer:latest
    container_name: homer
    ports:
      - "3088:8080"
    volumes:
      - ./homer/assets:/www/assets
    restart: unless-stopped

volumes:
  adguard-work:
  adguard-conf:
  ntfy-cache:
```

---

## Services Quick Reference

| Port | Service | URL | Purpose |
|------|---------|-----|---------|
| 53 | adguardhome | http://lepotato:53 | DNS + Ad-block |
| 3080 | adguardhome | http://lepotato:3080 | Admin UI |
| 3085 | ntfy | http://lepotato:3085 | Push notifications |
| 3088 | homer | http://lepotato:3088 | Dashboard |
| 3090 | searxng | http://lepotato:3090 | Search (SearXNG) |
| 3091 | backrest | http://lepotato:3091 | Restic backup UI |
| 3092 | linkding | http://lepotato:3092 | Bookmark manager |
| 3093 | whoogle | http://lepotato:3093 | Private search (Google proxy) |
| 3094 | redlib | http://lepotato:3094 | Reddit frontend |
| 3095 | uptime-kuma | http://lepotato:3095 | Uptime monitoring |
| 3096 | microbin | http://lepotato:3096 | Tiny pastebin |
| 3097 | changedetection | http://lepotato:3097 | Website change monitor |
| 3098 | portainer | http://lepotato:3098 | Docker management UI |
| 3099 | dashy | http://lepotato:3099 | Alternative dashboard |
| 53 | pihole | http://lepotato (if using Pi:53 | DNS-hole) |
| 41641 | tailscale | - | Wireguard VPN (UDP) |
| 3389 | gluetun | - | VPN (no web UI, runs in background) |

---

## Performance Expectations

With 2GB RAM and 100Mbps network:

- **Ad-blocking**: Excellent - handles all network traffic
- **DNS queries**: Fast - minimal CPU
- **File transfers**: Limited to 10-12 MB/s (USB 2.0 bottleneck)
- **4K streaming**: NOT possible (network too slow)
- **1080p streaming**: Possible but slow for multiple users
- **Concurrent services**: 3-5 light services max

---

## Migration Path

Start with these services:

1. **Week 1**: adguardhome + ntfy
2. **Week 2**: homer + flaresolverr (if needed)
3. **Week 3**: searxng + prowlarr
4. **Week 4**: Add more based on usage

Monitor with `docker stats` and adjust limits as needed.
