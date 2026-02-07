# PotatoStack - Paths & Volume Mappings Guide

## Container Path Mappings

### Syncthing
**Container sees**: `/data/*`
**Host location**: `/mnt/storage/syncthing/*`

When setting up folders in Syncthing UI, use `/data/` paths:
- Camera sync (Android): `/data/camera-sync/android`
- Camera sync (iOS): `/data/camera-sync/ios`
- Desktop: `/data/Desktop`
- Photos: `/data/photos`
- Music: `/data/music`
- Videos: `/data/videos`
- Books: `/data/books`
- Audiobooks: `/data/audiobooks`
- Work: `/data/workdir`
- Documents: `/data/Dokumente`
- Pictures: `/data/Bilder`
- Private: `/data/Privates`
- Professional: `/data/Berufliches`
- Obsidian: `/data/Obsidian-Vault`
- Attachments: `/data/Attachments`
- Shared: `/data/shared`
- Backup: `/data/backup`

**Downloads access**:
- qBittorrent downloads: `/data/downloads`
- Soulseek shared: `/data/slskd-shared`

### FileBrowser
**Container sees**: `/srv/*`
**Host location**: Dual mount

Access paths in FileBrowser:
- Main storage: `/srv/storage` → `/mnt/storage`
- Cache HDD: `/srv/cachehdd` → `/mnt/cachehdd`

Full tree:
```
/srv/storage/
├── downloads/
├── slskd-shared/
├── syncthing/
│   ├── Desktop/
│   ├── Obsidian-Vault/
│   ├── camera-sync/android/
│   ├── camera-sync/ios/
│   ├── photos/
│   ├── music/
│   └── ...

/srv/cachehdd/
├── media/                   # Media server caches
├── observability/           # Prometheus, Loki, Alertmanager
├── sync/                    # Syncthing version history
└── system/                  # System cache files
```

### qBittorrent
**Container sees**:
- Downloads: `/downloads` → `/mnt/storage/downloads`
- Incomplete: `/incomplete` → `/mnt/storage/downloads/incomplete/qbittorrent`

### Slskd (Soulseek)
**Container sees**:
- Shared: `/var/slskd/shared` → `/mnt/storage/downloads/slskd`
- Incomplete: `/var/slskd/incomplete` → `/mnt/storage/downloads/incomplete/slskd`

## Storage Layout on Host

### Main Storage HDD (`/mnt/storage`)
```
/mnt/storage/
├── downloads/              # Downloads root
│   ├── incomplete/        # Active downloads (service-specific subdirs)
│   │   ├── sonarr/        # Sonarr incomplete
│   │   ├── radarr/        # Radarr incomplete
│   │   ├── lidarr/        # Lidarr incomplete
│   │   ├── qbittorrent/   # qBittorrent incomplete
│   │   ├── sabnzbd/       # SABnzbd incomplete
│   │   ├── aria2/         # Aria2 incomplete
│   │   ├── slskd/         # Soulseek incomplete
│   │   └── pyload/        # pyLoad incomplete
│   ├── torrent/           # Completed torrent downloads
│   ├── slskd/             # Soulseek shared files
│   ├── pyload/            # pyLoad downloads
│   └── rdt-client/        # Real-Debrid downloads
├── media/                 # Media library (TV, movies, music, etc.)
├── photos/                # Immich photos
├── syncthing/             # P2P sync folders
├── obsidian-couchdb/      # Obsidian LiveSync
├── velld/                 # Velld backups
├── rustypaste/            # Rustypaste uploads
└── backrest/              # Backrest repositories
    ├── Desktop/
    ├── Obsidian-Vault/
    ├── Bilder/
    ├── Dokumente/
    ├── workdir/
    ├── Attachments/
    ├── Privates/
    ├── Berufliches/
    ├── camera-sync/
    │   ├── android/
    │   └── ios/
    ├── photos/
    ├── videos/
    ├── music/
    ├── audiobooks/
    ├── podcasts/
    ├── books/
    ├── shared/
    └── backup/
```

### Cache HDD (`/mnt/cachehdd`)
```
/mnt/cachehdd/
├── media/                     # Media server caches (jellyfin, audiobookshelf, immich-ml)
├── observability/             # Metrics and logs (prometheus, loki, alertmanager)
├── sync/                      # Sync caches (syncthing-versions)
└── system/                    # System files (swap)
```

**Note:** All incomplete downloads have been moved to `/mnt/storage/downloads/incomplete/<service>` for better data integrity and consistent backup patterns.

## Common Setup Scenarios

### Adding smartphone camera backup to Syncthing
1. Open Syncthing UI: `http://192.168.178.158:8384`
2. Add folder in Syncthing UI
3. Folder path (Android): `/data/camera-sync/android`
4. Folder path (iOS): `/data/camera-sync/ios`
5. Share with your phone's device ID
6. On phone: Accept share, select DCIM/Camera folder

**Why this works**: Container has write access to `/data/camera-sync/*` which maps to `/mnt/storage/syncthing/camera-sync/*` owned by uid 1000.

### Sharing music/books via Soulseek
Symlinks created from Syncthing folders → `/mnt/storage/slskd-shared/`:
- Music: `ln -s /mnt/storage/syncthing/music /mnt/storage/slskd-shared/music`
- Books: `ln -s /mnt/storage/syncthing/books /mnt/storage/slskd-shared/books`
- Audiobooks: `ln -s /mnt/storage/syncthing/audiobooks /mnt/storage/slskd-shared/audiobooks`

Slskd container sees these at `/var/slskd/shared/*` and can share them.

## Permissions
All storage owned by: `1000:1000` (user daniel)
All permissions: `755` (rwxr-xr-x)
Syncthing versions: `775` (rwxrwxr-x)
