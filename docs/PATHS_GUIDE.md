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
- Transmission downloads: `/data/downloads`
- Soulseek shared: `/data/slskd-shared`

### Kopia Backup
**Container sees**: `/data/*` (read-only)
**Host location**: Various `/mnt/storage/*`

Backed up folders:
- Vaultwarden DB: `/data/vaultwarden`
- All Syncthing folders: `/data/syncthing-*`
- Downloads: `/data/downloads`
- Soulseek: `/data/slskd-shared`

**Repository**: `/repository` → `/mnt/storage/kopia/repository`
**Cache**: `/app/cache` → `/mnt/cachehdd/kopia-cache`

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
└── kopia/repository/

/srv/cachehdd/
├── transmission-incomplete/
├── slskd-incomplete/
├── kopia-cache/
└── syncthing-versions/
```

### Transmission
**Container sees**:
- Downloads: `/downloads` → `/mnt/storage/downloads`
- Incomplete: `/incomplete` → `/mnt/cachehdd/transmission-incomplete`

### Slskd (Soulseek)
**Container sees**:
- Shared: `/var/slskd/shared` → `/mnt/storage/slskd-shared`
- Incomplete: `/var/slskd/incomplete` → `/mnt/cachehdd/slskd-incomplete`

## Storage Layout on Host

### Main Storage HDD (`/mnt/storage`)
```
/mnt/storage/
├── downloads/              # Transmission completed downloads
├── slskd-shared/          # Soulseek shared files
├── kopia/
│   └── repository/        # Backup repository
└── syncthing/             # P2P sync folders
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
├── transmission-incomplete/   # Active torrent downloads
├── slskd-incomplete/          # Active Soulseek downloads
├── kopia-cache/               # Backup cache & metadata
└── syncthing-versions/        # File version history
```

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
