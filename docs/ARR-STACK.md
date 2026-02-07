# ARR Stack Guide

All *arr services run behind Gluetun VPN (`network_mode: "service:gluetun"`).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GLUETUN VPN                                    │
│  ┌─────────────┐                                                            │
│  │  Prowlarr   │──── Manages indexers for all *arr apps                     │
│  │   :9696     │                                                            │
│  └──────┬──────┘                                                            │
│         │ pushes indexers to                                                │
│         ▼                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Sonarr    │  │   Radarr    │  │   Lidarr    │  │  Bookshelf  │        │
│  │   :8989     │  │   :7878     │  │   :8686     │  │   :8787     │        │
│  │  TV Shows   │  │   Movies    │  │    Music    │  │   Ebooks    │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                │                │
│         └────────────────┴────────────────┴────────────────┘                │
│                                   │                                         │
│                    sends downloads to                                       │
│                                   ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      DOWNLOAD CLIENTS                                │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │ rdt-client  │  │ qBittorrent │  │    slskd    │  │    aria2    │ │   │
│  │  │   :6500     │  │   :8282     │  │   :2234     │  │   :6800     │ │   │
│  │  │   Debrid    │  │   Torrent   │  │  Soulseek   │  │  HTTP/FTP   │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

                                   │
                    downloads to /mnt/storage
                                   ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│                         MEDIA SERVERS & SUPPORT                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐   │
│  │  Jellyfin   │  │ Jellyseerr  │  │   Bazarr    │  │ Audiobookshelf   │   │
│  │   :8096     │  │   :5055     │  │   :6767     │  │     :13378       │   │
│  │   Stream    │  │  Requests   │  │  Subtitles  │  │ Audiobooks/Pods  │   │
│  └─────────────┘  └─────────────┘  └─────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Services

### Indexer Management

| Service | Port | Purpose |
|---------|------|---------|
| **Prowlarr** | 9696 | Indexer manager - configure once, syncs to all *arrs |
| **FlareSolverr** | 8191 | Cloudflare bypass proxy for Prowlarr |

### Media Managers (*arr apps)

| Service | Port | Media Type | Library Path |
|---------|------|------------|--------------|
| **Sonarr** | 8989 | TV Shows | `/mnt/storage/media/tv` |
| **Radarr** | 7878 | Movies | `/mnt/storage/media/movies` |
| **Lidarr** | 8686 | Music | `/mnt/storage/media/music` |
| **Bookshelf** | 8787 | Ebooks | `/mnt/storage/media/books` |

### Download Clients

| Service | Port | Type | Use Case |
|---------|------|------|----------|
| **rdt-client** | 6500 | Debrid | Real-Debrid/TorBox - instant cached downloads |
| **qBittorrent** | 8282 | Torrent | Traditional torrenting |
| **slskd** | 2234 | P2P | Soulseek - rare music |
| **aria2** | 6800 | HTTP/FTP | Direct downloads |
| **pyLoad** | 8076 | DDL | File hosters (1fichier, etc) |

### Media Servers & Support

| Service | Port | Purpose |
|---------|------|---------|
| **Jellyfin** | 8096 | Media streaming (movies, TV, music) |
| **Jellyseerr** | 5055 | Request management UI |
| **Bazarr** | 6767 | Automatic subtitle downloads |
| **Audiobookshelf** | 13378 | Audiobooks & podcasts |

## Setup Flow

### 1. Configure Prowlarr (do this first)

1. Open `http://localhost:9696`
2. **Settings > Indexers**: Add your indexers (1337x, RARBG, etc)
3. **Settings > Apps**: Add each *arr app:
   - Sonarr: `http://127.0.0.1:8989` (same VPN namespace)
   - Radarr: `http://127.0.0.1:7878`
   - Lidarr: `http://127.0.0.1:8686`
   - Bookshelf: `http://127.0.0.1:8787`
4. Get API keys from each app's Settings > General

### 1b. Configure FlareSolverr (for Cloudflare-protected indexers)

Many indexers like 1337x use Cloudflare protection. FlareSolverr runs a headless browser to solve these challenges.

**Setup in Prowlarr:**

1. Go to **Settings → Indexers**
2. Click **+** under "Indexer Proxies" (not regular indexers)
3. Select **FlareSolverr**
4. Configure:
   ```
   Name: FlareSolverr
   Tags: flaresolverr
   Host: http://127.0.0.1:8191
   Request Timeout: 60
   ```
5. Click **Test** then **Save**

**Using FlareSolverr with indexers:**

When adding Cloudflare-protected indexers (1337x, etc):
1. Add the indexer normally
2. In the indexer settings, add the `flaresolverr` tag
3. Save - requests will now route through FlareSolverr

**Notes:**
- First request to each site may take 10-30 seconds (solving challenge)
- FlareSolverr uses ~256-512MB RAM (headless Chrome)
- Both Prowlarr and FlareSolverr run behind Gluetun VPN

### 2. Configure Download Clients (in each *arr app)

**For rdt-client (Debrid - recommended):**
```
Settings > Download Clients > Add > qBittorrent
Host: 127.0.0.1
Port: 6500
Category: sonarr (or radarr, lidarr, etc)
```

**For qBittorrent (traditional torrents):**
```
Settings > Download Clients > Add > qBittorrent
Host: 127.0.0.1
Port: 8282
Username: daniel
Password: (from .env)
Category: sonarr (or radarr, lidarr, etc)
```

### 3. Configure Root Folders

In each *arr app, set the root folder:
- Sonarr: `/tv`
- Radarr: `/movies`
- Lidarr: `/music`
- Bookshelf: `/books`

### 4. Configure Jellyfin

1. Open `http://localhost:8096`
2. Add libraries pointing to:
   - Movies: `/mnt/storage/media/movies`
   - TV Shows: `/mnt/storage/media/tv`
   - Music: `/mnt/storage/media/music`

### 5. Configure Jellyseerr

1. Open `http://localhost:5055`
2. Connect to Jellyfin
3. Add Sonarr: `http://gluetun:8989` (arr apps share gluetun's network)
4. Add Radarr: `http://gluetun:7878`

### 6. Configure Bazarr

1. Open `http://localhost:6767`
2. **Settings > Sonarr**: `http://gluetun:8989` (via gluetun network)
3. **Settings > Radarr**: `http://gluetun:7878`
4. **Settings > Providers**: Add OpenSubtitles, Subscene, etc

## Storage Layout

```
/mnt/storage/
├── downloads/
│   ├── rdt-client/      # Debrid downloads
│   ├── qbittorrent/     # Torrent downloads
│   ├── aria2/           # HTTP downloads
│   └── slskd/           # Soulseek downloads
└── media/
    ├── movies/          # Radarr library
    ├── tv/              # Sonarr library
    ├── music/           # Lidarr library
    ├── books/           # Bookshelf library
    ├── audiobooks/      # Audiobookshelf
    └── podcasts/        # Audiobookshelf
```

## Typical Workflow

1. **Request**: User requests movie/show via Jellyseerr
2. **Search**: Sonarr/Radarr searches Prowlarr indexers
3. **Download**: Sends to rdt-client (debrid) or qBittorrent
4. **Import**: *arr imports and renames to library folder
5. **Subtitles**: Bazarr fetches subtitles
6. **Stream**: Watch on Jellyfin

## Internal Communication

All VPN services communicate via `127.0.0.1` (same gluetun network namespace):

| From | To | Address |
|------|-----|---------|
| Sonarr | rdt-client | `127.0.0.1:6500` |
| Sonarr | qBittorrent | `127.0.0.1:8282` |
| Prowlarr | Sonarr | `127.0.0.1:8989` |
| Prowlarr | FlareSolverr | `127.0.0.1:8191` |

Services outside VPN reach *arrs via gluetun container:

| From | To | Address |
|------|-----|---------|
| Jellyseerr | Sonarr | `gluetun:8989` |
| Bazarr | Radarr | `gluetun:7878` |
| Jellyfin | - | Direct library access via bind mounts |

## Quick Reference

```bash
# Check all arr services
docker ps --filter "name=sonarr|radarr|lidarr|prowlarr|bazarr"

# View logs
docker logs -f sonarr
docker logs -f radarr

# Restart arr stack
docker compose restart prowlarr sonarr radarr lidarr bazarr
```
