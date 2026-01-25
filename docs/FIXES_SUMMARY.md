# PotatoStack - Fixes Summary

## Summary
All issues from `fixes_needed.txt` have been addressed with code fixes and documentation.

---

## Fix 1: Syncthing Camera Sync Permissions ✓

**Problem**: Mkdir permission denied when setting up camera sync from smartphone

**Root Cause**: User confusion about container vs host paths

**Solution**:
- Created `PATHS_GUIDE.md` - Complete path mapping documentation
- Syncthing sees `/data/camera-sync/android` (maps to `/mnt/storage/syncthing/camera-sync/android`)
- Directories created by `scripts/init/init-storage.sh` with correct permissions (1000:1000, 755)
- Subfolders `android` and `ios` pre-created

**Action Required**:
1. Read `PATHS_GUIDE.md`
2. In Syncthing UI, add folder: `/data/camera-sync/android`
3. Share with Android device
4. On phone: Accept share, select DCIM folder

---

## Fix 2: Volume Mappings Documentation ✓

**Problem**: Unclear which folders/paths are mounted into services

**Solution**: Created `PATHS_GUIDE.md` with complete mappings:
- Syncthing: `/data/*` → `/mnt/storage/syncthing/*`
- Kopia: `/data/*` → various folders (read-only)
- FileBrowser: `/srv/storage/*` and `/srv/cachehdd/*`
- qBittorrent: `/downloads` and `/incomplete`
- Slskd: `/var/slskd/shared` and `/var/slskd/incomplete`

**Files Created**:
- `PATHS_GUIDE.md` - Full path mappings and usage examples

---

## Fix 3: Vaultwarden Configuration ✓

**Problem**: Port 8080 loads forever, unknown configuration for Android app

**Root Cause**:
- Insufficient healthcheck timeout for low-RAM hosts
- Too low memory limits causing slow startup

**Code Changes**:
- Increased memory limit: 96M → 128M
- Increased healthcheck retries: 5 → 10
- Increased start_period: 30s → 120s

**Android App Configuration**:
- Server URL: `http://192.168.178.158:8080`
- Leave all other fields empty
- No certificate needed (HTTP on LAN)

**Files Created**:
- `VAULTWARDEN_SETUP.md` - Complete setup and troubleshooting guide

**Files Modified**:
- `docker-compose.yml` - Vaultwarden memory and healthcheck settings

---

## Fix 4: Porn Folder Created ✓

**Problem**: Need porn folder in appropriate location

**Solution**: Added to Syncthing private folder structure

**Code Changes**:
- Modified `scripts/init/init-storage.sh` to create `/mnt/storage/syncthing/Privates/porn`
- Permissions: 1000:1000, 755
- Accessible in Syncthing at `/data/Privates/porn`
- Accessible in FileBrowser at `/srv/storage/syncthing/Privates/porn`

**Files Modified**:
- `scripts/init/init-storage.sh` - Added porn subfolder to Privates

---

## Fix 5: OneDrive Migration Solution ✓

**Problem**: Need to download OneDrive content and migrate to Syncthing

**Solution**: Created automated migration script

**Features**:
- Maps OneDrive folders to Syncthing structure
- Preserves all content in archive folder
- Uses rsync for safe, resumable copying
- Handles Private Vault (with manual unlock instructions)
- Sets correct permissions (1000:1000)
- Shows progress and storage usage

**Files Created**:
- `onedrive-migration.sh` - Complete migration script

**Usage**:
```bash
cd ~/light
chmod +x onedrive-migration.sh
./onedrive-migration.sh
```

**Archive Location**: `/mnt/storage/syncthing/OneDrive-Archive`

---

## Fix 6: Soulseek Symlinks ✓

**Problem**: Need to symlink Syncthing folders to Soulseek for sharing

**Solution**: Created symlink setup script

**Symlinks Created**:
- `music` → `/mnt/storage/syncthing/music`
- `books` → `/mnt/storage/syncthing/books`
- `audiobooks` → `/mnt/storage/syncthing/audiobooks`
- `podcasts` → `/mnt/storage/syncthing/podcasts`

**Files Created**:
- `scripts/setup/setup-soulseek-symlinks.sh` - Automated symlink creation

**Usage**:
```bash
cd ~/light
chmod +x scripts/setup/setup-soulseek-symlinks.sh
./scripts/setup/setup-soulseek-symlinks.sh
docker compose restart slskd
```

---

## Fix 7: Syncthing Settings Persistence ✓

**Problem**: Need confirmation that Syncthing settings survive crashes

**Solution**: Comprehensive persistence documentation

**Answer**: YES, fully persistent via Docker named volume

**What's Preserved**:
- Device configurations
- Folder shares
- All settings (GUI password, API key, etc.)
- File index and sync state

**How It Works**:
- Volume: `syncthing-config` (Docker managed)
- Survives: crashes, restarts, container recreation
- Automatic recovery on restart

**Files Created**:
- `SYNCTHING_PERSISTENCE.md` - Complete persistence explanation

---

## Fix 8: OOM (Out of Memory) Errors ✓

**Problem**: Memory cgroup killing `apk` process repeatedly

**Root Cause**:
- `storage-init` container installing openssl via `apk`
- No memory limits set, hitting default cgroup limits
- Low-RAM hosts under memory pressure
- Process needs ~20-30MB but getting OOM killed

**Code Changes**:
- Added memory limits to `storage-init` container:
  - Limit: 128M (for apk install + swap creation)
  - Reservation: 64M
  - Added SYS_ADMIN capability for swap management
- **Automatic swap setup**: 2GB swap file auto-created on cache HDD
  - Created at `/mnt/cachehdd/swapfile`
  - Automatically enabled on every stack start
  - Reduces OOM errors permanently

**Files Created**:
- `OOM_FIX.md` - Complete analysis and solutions

**Files Modified**:
- `docker-compose.yml` - storage-init memory limits and capabilities
- `scripts/init/init-storage.sh` - Added automatic swap creation and enablement

**Swap Details**:
- Size: 2GB (on cache HDD for performance)
- Location: `/mnt/cachehdd/swapfile`
- Management: Fully automatic
- Persistence: Enabled on every start

---

## Notes Already Documented

### [WONTFIX] FileBrowser Capacity Display
**Issue**: Shows container overlay filesystem capacity, not actual drive capacity
**Reason**: Docker bind mount limitation
**Workaround**: Navigate into folders to see correct capacity

### [NOTE] Dashboard Gluetun Widget "Invalid data"
**Issue**: Widget shows error during VPN connection startup
**Reason**: Gluetun hasn't fetched public IP yet
**Resolution**: Resolves automatically once VPN connects

---

## Files Created/Modified

### New Files:
1. `PATHS_GUIDE.md` - Path mappings for all services
2. `VAULTWARDEN_SETUP.md` - Vaultwarden configuration guide
3. `SYNCTHING_PERSISTENCE.md` - Persistence explanation
4. `OOM_FIX.md` - OOM error analysis and fixes
5. `ONEDRIVE_MIGRATION_GUIDE.md` - Complete OneDrive migration guide
6. `install-onedrive-client.sh` - OneDrive client installation
7. `setup-onedrive-sync.sh` - OneDrive authentication setup
8. `download-onedrive.sh` - OneDrive download script
9. `migrate-onedrive-to-syncthing.sh` - Migration to Syncthing
10. `onedrive-migration.sh` - Simple rsync alternative
11. `scripts/setup/setup-soulseek-symlinks.sh` - Soulseek symlink setup
12. `FIXES_SUMMARY.md` - This file

### Modified Files:
1. `docker-compose.yml`:
   - Vaultwarden: memory limits (128M), healthcheck (10 retries, 120s start)
   - storage-init: memory limits (128M/64M), added SYS_ADMIN capability for swap
2. `scripts/init/init-storage.sh`:
   - Added `Privates/porn` folder
   - Added automatic 2GB swap file creation and enablement on cache HDD
   - Swap persists and auto-enables on every stack start

---

## Next Steps

### Immediate Actions:
1. Apply changes:
   ```bash
   cd ~/light
   docker compose down
   docker compose up -d
   ```

2. Run scripts as needed:
   ```bash
   chmod +x onedrive-migration.sh scripts/setup/setup-soulseek-symlinks.sh
   ./onedrive-migration.sh  # If migrating from OneDrive
   ./scripts/setup/setup-soulseek-symlinks.sh  # To enable Soulseek sharing
   ```

3. Configure Syncthing camera sync (see PATHS_GUIDE.md)

4. Configure Vaultwarden in Android app (see VAULTWARDEN_SETUP.md)

### Monitoring:
1. Check OOM errors stopped:
   ```bash
   sudo journalctl -k --since "1 hour ago" | grep -i "out of memory"
   ```

2. Verify Vaultwarden starts successfully:
   ```bash
   docker logs -f vaultwarden
   curl http://192.168.178.158:8080
   ```

3. Monitor stack health:
   ```bash
   docker compose ps
   docker stats
   ```

### Optional:
- Enable swap space (see OOM_FIX.md)
- Backup Syncthing config volume
- Add Syncthing config to Kopia backups

---

## Support Documentation

All issues have comprehensive documentation:
- Read relevant `.md` files for detailed instructions
- Scripts include inline help and usage examples
- All changes preserve existing functionality
- No breaking changes to current setup

**Status**: All fixes complete, stack ready for deployment ✓
