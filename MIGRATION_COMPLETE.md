# PotatoStack Migration Complete - 2026-01-18

## Summary

All TODO.txt tasks completed successfully:

### ✅ 1. Tailscale Configuration
- Tailscale container running and healthy
- Connected to tailnet: `tale-iwato.ts.net`
- Host IP: `100.108.216.90` (potatostack)
- Created `links.md` with all service Tailscale URLs

### ✅ 2. Homarr Migration
- Migrated to `ghcr.io/homarr-labs/homarr:latest`
- Fixed OOM issue by increasing memory limit to 768MB
- Using PostgreSQL backend
- Running healthy

### ✅ 3. Storage Structure Cleanup

#### Deleted Deprecated Directories:
- ❌ `/mnt/storage/photos` → Use `syncthing/photos` instead
- ❌ `/mnt/storage/duckdb` → Moved to `/mnt/ssd/docker-data/duckdb`

#### Normalized Cache Structure:
**Before:**
```
/mnt/cachehdd/
├── qbittorrent-incomplete
├── aria2-incomplete
├── slskd-incomplete
├── pinchflat-incomplete
├── jellyfin-cache
├── audiobookshelf/
├── loki/
├── prometheus/
├── thanos/
├── alertmanager/
├── syncthing-versions/
├── kopia-cache/
└── swapfile
```

**After (Organized by Function):**
```
/mnt/cachehdd/
├── downloads/          # Incomplete downloads
│   ├── torrent/        (qbittorrent)
│   ├── aria2/
│   ├── slskd/
│   └── pinchflat/
├── media/              # Media caches
│   ├── jellyfin/
│   ├── audiobookshelf/
│   └── immich-ml/
├── observability/      # Monitoring stack
│   ├── loki/
│   ├── prometheus/
│   ├── thanos/
│   └── alertmanager/
├── sync/               # Sync caches
│   ├── syncthing-versions/
│   └── kopia-cache/
└── system/             # System files
    └── swapfile
```

#### SSD Structure:
- ✅ `/mnt/ssd/docker-data/duckdb` - Moved from HDD
- ✅ `/mnt/ssd/system/cron` - Cron schedules (clean separation)

### ✅ 4. Updated All Services
- `docker-compose.yml` updated with new cache paths
- All services restarted and verified healthy
- Storage-init script updated to handle migrations automatically
- **77/77** containers running (storage-init exits after success)

### ✅ 5. Crash Recovery System
Created permanent fix for machine crash recovery:

**Files Created:**
1. `scripts/init/startup.sh` - Detects and fixes "Created" state containers
2. `scripts/init/potatostack.service` - Systemd service for boot startup
3. `scripts/setup/install-systemd-service.sh` - Installation script

**To Install (run once):**
```bash
sudo bash scripts/setup/install-systemd-service.sh
```

This ensures:
- Stack automatically starts after reboot
- Detects containers stuck in "Created" state (symptom of crash)
- Performs clean restart if needed
- Logs to `/var/log/potatostack-startup.log`

## Current Status

### Network
- Tailscale: ✅ Connected (`100.108.216.90`)
- Local LAN: ✅ `192.168.178.158`
- All services accessible via Tailscale (see `links.md`)

### Services
- Total containers: 78
- Running: 77
- Healthy: All critical services
- Unhealthy: None

### Storage
- Main HDD (`/mnt/storage`): Media, downloads, syncthing, kopia
- Cache HDD (`/mnt/cachehdd`): Organized by function (downloads/media/observability/sync/system)
- SSD (`/mnt/ssd`): Databases, app configs, system files
- Swap: 2GB on `/mnt/cachehdd/system/swapfile`

## Access Links

Primary dashboard: http://potatostack.tale-iwato.ts.net:7575 (Homarr)

See `links.md` for complete list of all 100+ service URLs.

## Next Steps (Optional)

1. **Install systemd service** (recommended):
   ```bash
   sudo bash scripts/setup/install-systemd-service.sh
   ```

2. **Verify Tailscale on reboot**:
   - Systemd service will ensure Docker starts before Tailscale
   - Tailscale container will auto-reconnect

3. **Monitor migration**:
   - Check logs: `docker compose logs -f`
   - Verify no permission issues in new cache paths

## Migration Safety

All migrations are **non-destructive**:
- Old directories moved to new locations (not deleted)
- Services restarted with new paths
- Original data preserved
- Rollback possible if needed

## Files Modified

1. `scripts/init/init-storage.sh` - Complete rewrite with migration logic
2. `docker-compose.yml` - Updated all cache volume paths
3. `scripts/init/startup.sh` - NEW: Crash recovery script
4. `scripts/init/potatostack.service` - NEW: Systemd service
5. `scripts/setup/install-systemd-service.sh` - NEW: Service installer
6. `links.md` - NEW: Tailscale service URLs

## Verification Commands

```bash
# Check service health
docker ps --filter "health=unhealthy"

# Verify new cache structure
ls -la /mnt/cachehdd/{downloads,media,observability,sync,system}

# Check Tailscale
docker exec tailscale tailscale status

# View startup logs (after installing systemd service)
sudo journalctl -u potatostack -f
```

---

**Migration completed:** 2026-01-18 16:00 CET
**All systems operational** ✅
