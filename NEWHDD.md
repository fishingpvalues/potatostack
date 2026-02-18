# New 16TB HDD Integration Plan

## Drive Info
- Mount: `/mnt/storage2` (ext4, label "storage2")
- UUID: `fa11a826-bbc1-4bc3-a612-f1c2924514cc`
- Size: 15T (14T usable)
- Permissions: `daniel:daniel`

## Strategy
Move large/write-heavy data from `/mnt/storage` → `/mnt/storage2`:
- **media** (movies, tv, adult) — 1.3TB
- **downloads** (all) — 2.1TB
- **photos** (immich) — 13GB
- **backups** (backrest, velld) — small

Keep on `/mnt/storage`:
- music, audiobooks, podcasts (small, navidrome/audiobookshelf)
- syncthing, slskd-shared, financial-data, rustypaste, pairdrop
- all caches (`/mnt/storage/cache/`)
- obsidian-couchdb, onedrive-temp

## Step 1: Create folder structure (DONE)
```bash
mkdir -p /mnt/storage2/{media/{movies,tv,adult/telegram},downloads/{torrents,aria2,slskd,pyload,telegram,incomplete/{qbittorrent,aria2,slskd,pyload}},photos,backrest/repos,velld/backups}
```

## Step 2: Stop stack & rsync data
```bash
cd ~/potatostack && docker compose down
# Then run:
bash scripts/rsync-to-storage2.sh
```

## Step 3: Update docker-compose.yml
These volume mapping changes are needed (line numbers may shift):

### Services with `/mnt/storage/media/movies` or `/mnt/storage/media/tv` or `/mnt/storage/media/adult`:
- **jellyfin** (L1797-1798): `/mnt/storage/media/tv` → `/mnt/storage2/media/tv`, `/mnt/storage/media/movies` → `/mnt/storage2/media/movies`
- **qbittorrent** (L1982): `/mnt/storage/media:/media` → `/mnt/storage2/media:/media`
- **unpackerr** (L1451): `/mnt/storage/media:/media` → `/mnt/storage2/media:/media`
- **stash** (L3483): `/mnt/storage/media/adult:/data` → `/mnt/storage2/media/adult:/data`
- **tdl** (L2218-2219): `/mnt/storage/media/adult:/adult:ro` → `/mnt/storage2/media/adult:/adult:ro`, `/mnt/storage/media/adult/telegram:/adult-telegram` → `/mnt/storage2/media/adult/telegram:/adult-telegram`
- **slskd** (L2097-2098): keep music/audiobooks on storage (read-only, not moved)

### Services with `/mnt/storage/downloads`:
- **spotiflac** (L1934): → `/mnt/storage2/downloads:/downloads`
- **unpackerr** (L1450): → `/mnt/storage2/downloads:/downloads`
- **qbittorrent** (L1980-1981): → `/mnt/storage2/downloads/torrents:/downloads`, `/mnt/storage2/downloads/incomplete/qbittorrent:/incomplete`
- **aria2** (L2025-2026): → `/mnt/storage2/downloads/aria2:/downloads`, `/mnt/storage2/downloads/incomplete/aria2:/incomplete`
- **slskd** (L2091-2092): → `/mnt/storage2/downloads/slskd:/var/slskd/downloads`, `/mnt/storage2/downloads/incomplete/slskd:/var/slskd/incomplete`
- **pyload** (L2173-2174): → `/mnt/storage2/downloads/pyload:/downloads`, `/mnt/storage2/downloads/incomplete/pyload:/incomplete`
- **tdl** (L2217): → `/mnt/storage2/downloads/telegram:/downloads`

### Services with `/mnt/storage/photos`:
- **immich-server** (L2331): → `/mnt/storage2/photos:/usr/src/app/upload`

### Services with `/mnt/storage/backrest` or `/mnt/storage/velld`:
- **backrest** (L4351,4353): → `/mnt/storage2/backrest/repos:/repos`, add `/mnt/storage2:/mnt/storage2` mount
- **velld** (L4283): → `/mnt/storage2/velld/backups:/app/backups`

### File management services (add storage2 as additional mount):
- **filebrowser** (L653): ADD `/mnt/storage2:/srv/storage2`
- **filestash** (L699): ADD `/mnt/storage2:/mnt/storage2`
- **openssh-server** (L3932): ADD `/mnt/storage2:/data/storage2`
- **samba** (L4026-4027): ADD `/mnt/storage2:/mnt/storage2` volume + new share config
- **disk-space-monitor** (L4110): ADD `/mnt/storage2:/mnt/storage2:ro`
- **backup-monitor** (L4140): ADD `/mnt/storage2:/mnt/storage2:ro`
- **stack-snapshot** (L37): ADD `/mnt/storage2:/mnt/storage2`

### Samba: add new share
```yaml
SAMBA_VOLUME_CONFIG_storage2: |
  [storage2]
  path = /mnt/storage2
  browsable = yes
  writable = yes
  read only = no
  guest ok = no
  valid users = daniel
  force user = daniel
  force group = daniel
  create mask = 0777
  directory mask = 0777
```

### Commented-out services (update for when re-enabled):
- sonarr (L1149-1151): tv → storage2, downloads → storage2
- radarr (L1186-1188): movies → storage2, downloads → storage2
- lidarr (L1223-1225): downloads → storage2 (music stays)
- bazarr (L1260-1261): movies/tv → storage2
- pinchflat (L3440-3441): downloads → storage2
- paperless (L3227-3229): keep on storage (small)

## Step 4: Update .env
```
DISK_MONITOR_PATHS=/mnt/storage /mnt/ssd /mnt/cachehdd /mnt/storage2
BACKUP_MONITOR_PATHS=/mnt/storage/stack-snapshot.log /mnt/storage2/velld/backups /mnt/storage2/backrest/repos
```

## Step 5: Start stack & verify
```bash
docker compose up -d
docker compose ps --format "table {{.Name}}\t{{.Status}}" | grep -v healthy
```

## Step 6: Cleanup (after verification)
```bash
# Only after confirming everything works!
rm -rf /mnt/storage/media/movies /mnt/storage/media/tv /mnt/storage/media/adult
rm -rf /mnt/storage/downloads
rm -rf /mnt/storage/photos
rm -rf /mnt/storage/backrest /mnt/storage/velld
```
