# PotatoStack Storage Migration Plan

## Current Storage Analysis

### Storage Drives:
- **Storage (13TB @ /mnt/storage)**: 2.0T used (16%)
- **Cache HDD (458GB @ /mnt/cachehdd)**: 3.3G used (1%)
- **Internal SSD (452GB @ /)**: 18G used (5%)

### Current Distribution Issues:

**❌ ON 13TB STORAGE (should be on faster storage):**
- `/mnt/storage/docker-data/` (424M) - Configs for mongo, redis, crowdsec, homarr, etc.
- `/mnt/storage/photos/` (117M) - Immich photos (small, should be on cachehdd or SSD)
- `/mnt/storage/rustypaste/` (32K) - Pastebin uploads (tiny)
- `/mnt/storage/mealie-data/` (2M) - Mealie recipes (tiny)
- `/mnt/storage/obsidian-couchdb/` (172M) - Obsidian sync database
- `/mnt/storage/onedrive-temp/` (267G) - OneDrive sync temp (large, should be on cachehdd)

**✓ CORRECTLY PLACED:**
- `/mnt/storage/media/` (1.1T) - Large media files (adult, music)
- `/mnt/storage/syncthing/` (534G) - P2P sync
- `/mnt/storage/downloads/` (12G) - Final downloads
- `/mnt/cachehdd/media/` - Immich-ML, Jellyfin cache
- `/mnt/cachehdd/observability/` - Prometheus, Loki, Thanos

**❌ POTENTIAL OPTIMIZATIONS:**
- Docker named volumes (49 volumes) all on 13TB storage in `/mnt/storage/docker/volumes/`
- `/mnt/storage/downloads/incomplete` (6.2G) - Should be on cachehdd
- `/mnt/cachehdd/system/swapfile` (2.1G) - Swap on HDD is slow

---

## Migration Plan - Balanced Approach

### 📊 Phase 1: Small Files & Configs → Internal SSD
*(Total: ~500MB - easily fits on your 18GB used SSD)*

**Move from 13TB storage to SSD:**
```
/mnt/storage/docker-data/ → /mnt/ssd/docker-data/
├── mongo/ (376M)           ✅ Databases benefit from SSD
├── redis-cache/ (30M)       ✅ Redis needs fast I/O
├── crowdsec-db/ (7M)        ✅ Security DB benefits from SSD
├── homarr/ (5.6M)           ✅ Dashboard config
├── crowdsec-config/ (3.1M)
└── (other small configs)
```

**Docker named volumes (configs only):**
- Move ~30 small config volumes (stash-*, grafana-data, jellyfin-config, etc.)
- Total estimated: 200-300MB

### 🚀 Phase 2: Temporary & Cache Data → Cache HDD
*(Total: ~275GB - fits easily in 458GB cachehdd)*

**Move from 13TB storage:**
```
/mnt/storage/onedrive-temp/ (267G) → /mnt/cachehdd/onedrive-temp/
/mnt/storage/downloads/incomplete/ (6.2G) → /mnt/cachehdd/downloads/incomplete/
/mnt/storage/photos/ (117M) → /mnt/cachehdd/photos/  (if small collection)
/mnt/storage/mealie-data/ (2M) → /mnt/ssd/docker-data/mealie/
/mnt/storage/rustypaste/ (32K) → /mnt/ssd/docker-data/rustypaste/
/mnt/storage/obsidian-couchdb/ (172M) → /mnt/ssd/docker-data/obsidian-couchdb/
```

### ⚠️ Phase 3: Consider Moving (Your Choice)

**Swap file (2.1G):**
```
Current: /mnt/cachehdd/system/swapfile (slow HDD)
Better:   /mnt/swapfile (on SSD) - or create zram
```

**Observability data (454M):**
```
Current: /mnt/cachehdd/observability/
Already optimized on fast drive ✓
```

### ✅ Keep on 13TB Storage (Large Files)

```
/mnt/storage/media/adult/        (1.1T)  ✓ Large media
/mnt/storage/media/music/        (33G)   ✓ Media files
/mnt/storage/syncthing/         (534G)  ✓ Large sync data
/mnt/storage/downloads/complete/ (5.4G)  ✓ Final downloads
/mnt/storage/downloads/pyload/   (157M)
```

---

## 🔧 Implementation Notes

**Important considerations:**
1. `/mnt/ssd/docker-data/` currently symlinks to `/mnt/storage/docker-data/` - symlink will need to be replaced with real directory
2. Ensure ~2GB available space on SSD for databases+configs
3. Ensure ~270GB available space on cachehdd for temp files
4. Critical: Some services (postgres, mongo, immich) have data in different locations - need careful migration
5. Stop affected services before moving their data
6. Update docker-compose.yml volume paths after migration

**Services affected by Phase 1:**
- postgres
- mongo
- redis-cache
- crowdsec
- homarr
- grafana
- jellyfin
- stash
- Many other config volumes

**Services affected by Phase 2:**
- qbittorrent (incomplete downloads)
- pyload (incomplete downloads)
- slskd (incomplete downloads)
- immich-server (photos if small)
- audiobookshelf (metadata already on cachehdd)
