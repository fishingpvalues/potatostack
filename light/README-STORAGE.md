# PotatoStack Light - Storage Structure

## Overview

All application data is stored in `/mnt/storage` with automatic directory creation on stack startup.

## Automatic Directory Creation

The `storage-init` container automatically creates all required directories when you run:

```bash
docker compose up -d
```

The init container:
- ✅ Runs before any other services
- ✅ Creates all `/mnt/storage` subdirectories
- ✅ Sets ownership to PUID/PGID (1000:1000)
- ✅ Sets permissions to 755
- ✅ Exits after completion (restart: no)

## Required Directory Structure

```
/mnt/storage/
├── downloads/                    # Transmission completed downloads
├── transmission-incomplete/      # Transmission in-progress downloads
├── slskd-shared/                 # Soulseek shared files
├── slskd-incomplete/             # Soulseek incomplete downloads
├── immich/
│   ├── upload/                   # Immich uploaded photos
│   ├── library/                  # Immich processed library
│   └── thumbs/                   # Immich thumbnails
├── kopia/
│   ├── repository/               # Kopia backup repository
│   └── cache/                    # Kopia cache
├── seafile/                      # Seafile file sync data
└── rustypaste/                   # Rustypaste uploaded files
```

## Manual Setup (Optional)

If you need to create directories manually before first run:

### Linux/Armbian:

```bash
cd light
sudo ./setup-storage-directories.sh
```

### Windows (Testing):

```powershell
cd light
.\setup-storage-directories.ps1
```

## Docker Compose Configuration

The storage init service in `docker-compose.yml`:

```yaml
storage-init:
  image: alpine:latest
  container_name: storage-init
  command: sh /init-storage.sh
  environment:
    - PUID=1000
    - PGID=1000
  volumes:
    - /mnt/storage:/mnt/storage
    - ./init-storage.sh:/init-storage.sh:ro
  network_mode: none
  restart: "no"
```

## Service Dependencies

All services that use `/mnt/storage` depend on `storage-init`:

```yaml
depends_on:
  storage-init:
    condition: service_completed_successfully
```

Services with storage dependencies:
- **transmission** - downloads, incomplete
- **slskd** - shared, incomplete
- **immich-server** - upload, library, thumbs
- **immich-microservices** - upload, library, thumbs
- **kopia** - repository, cache (also reads other service data)
- **seafile** - shared folder

## Permissions

All directories are created with:
- **Owner**: PUID:PGID (default 1000:1000)
- **Permissions**: 755 (rwxr-xr-x)

This matches the PUID/PGID used by all containers.

## Storage Requirements

Recommended minimum sizes:

| Directory | Recommended Size | Notes |
|-----------|-----------------|-------|
| `/mnt/storage/downloads` | 100GB+ | Torrent downloads |
| `/mnt/storage/transmission-incomplete` | 50GB+ | Active torrents |
| `/mnt/storage/slskd-shared` | 100GB+ | Music library |
| `/mnt/storage/immich/*` | 500GB+ | Photo storage (grows over time) |
| `/mnt/storage/kopia/repository` | 2TB+ | Backup repository |
| `/mnt/storage/seafile` | 100GB+ | File sync |

**Total Recommended**: 1TB minimum, 2TB+ recommended

## Mounting Storage Drive

Before running the stack, ensure `/mnt/storage` is mounted:

### Check if mounted:
```bash
df -h /mnt/storage
```

### Auto-mount on boot (Armbian):

Add to `/etc/fstab`:
```
UUID=your-drive-uuid  /mnt/storage  ext4  defaults,nofail  0  2
```

Find your UUID:
```bash
sudo blkid | grep /dev/sd
```

## Troubleshooting

### Permission Denied Errors

```bash
# Re-run storage init
docker compose up storage-init

# Or manually fix permissions
sudo chown -R 1000:1000 /mnt/storage
sudo chmod -R 755 /mnt/storage
```

### Storage Init Failed

Check logs:
```bash
docker compose logs storage-init
```

Common issues:
- `/mnt/storage` doesn't exist → Mount your drive first
- No write permissions → Run with sudo or fix ownership
- Wrong PUID/PGID → Update in docker-compose.yml

### Service Won't Start

If a service fails to start due to missing directories:

1. Check if storage-init ran:
   ```bash
   docker compose ps -a storage-init
   ```

2. Verify directories exist:
   ```bash
   ls -la /mnt/storage
   ```

3. Re-run storage init:
   ```bash
   docker compose up storage-init
   ```

## Files Reference

- `light/init-storage.sh` - Auto-run by Docker container
- `light/setup-storage-directories.sh` - Manual setup script (Linux)
- `light/setup-storage-directories.ps1` - Manual setup script (Windows)
- `light/docker-compose.yml` - storage-init service definition

## Migration from Existing Setup

If you have existing data in different locations:

1. Stop the stack:
   ```bash
   docker compose down
   ```

2. Move/copy your data:
   ```bash
   sudo mv /old/path/photos /mnt/storage/immich/upload/
   sudo mv /old/path/downloads /mnt/storage/downloads/
   ```

3. Fix ownership:
   ```bash
   sudo chown -R 1000:1000 /mnt/storage
   ```

4. Start the stack:
   ```bash
   docker compose up -d
   ```

All services will now use the centralized storage structure.
