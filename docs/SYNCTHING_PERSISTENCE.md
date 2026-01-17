# Syncthing Configuration Persistence

## Configuration Storage

Syncthing configuration is **fully persistent** and survives crashes and restarts.

### Where Settings Are Stored

**Docker Volume**: `syncthing-config`
**Container Path**: `/config`
**Managed by**: Docker volume (not host filesystem)

### What Is Persisted

All Syncthing settings are stored in the volume and preserved:

1. **Device Configuration**
   - Device ID
   - Device names
   - Device connections
   - Trusted devices list

2. **Folder Configuration**
   - Folder paths
   - Folder shares
   - Folder types (send/receive, send-only, receive-only)
   - Ignore patterns
   - Versioning settings

3. **Settings**
   - GUI password
   - API key (also in `/keys/syncthing-api-key`)
   - Connection settings (port numbers, etc.)
   - Global discovery settings
   - Relay settings
   - NAT traversal settings

4. **Database**
   - File index
   - Sync state
   - Conflict handling data

## How It Works

### Volume Persistence
```yaml
volumes:
  syncthing-config:/config    # Named volume managed by Docker
```

Named volumes persist across:
- Container restarts
- Container crashes
- Container recreation
- Stack restarts
- System reboots

### Volume Location on Host
```bash
# Find volume location
docker volume inspect syncthing-config

# Typical location (host)
/var/lib/docker/volumes/light_syncthing-config/_data
```

## Verifying Persistence

### Check Volume Exists
```bash
docker volume ls | grep syncthing-config
```

### Inspect Volume
```bash
docker volume inspect syncthing-config
```

### View Configuration Files
```bash
# From host
sudo ls -lh /var/lib/docker/volumes/light_syncthing-config/_data

# From container
docker exec syncthing ls -lh /config
```

### Key Configuration Files
```
/config/
├── config.xml              # Main configuration (devices, folders, settings)
├── cert.pem                # TLS certificate
├── key.pem                 # TLS private key
├── https-cert.pem          # GUI certificate
├── https-key.pem           # GUI private key
├── index-v0.14.0.db/       # Database directory
└── csrftokens.txt          # CSRF tokens for web UI
```

## What Happens When Syncthing Crashes

1. **Container stops** (crash/OOM/error)
2. **Autoheal detects unhealthy status** (if healthcheck fails)
3. **Container restarts automatically** (`restart: unless-stopped`)
4. **Volume remains intact** (not affected by container state)
5. **Syncthing reads config from `/config`** (volume)
6. **All settings restored** (devices, folders, connections)
7. **Syncing resumes** (from last known state)

## Backup Syncthing Configuration

### Manual Backup
```bash
# Backup entire config volume
docker run --rm \
  -v light_syncthing-config:/source:ro \
  -v /mnt/storage/backups:/backup \
  alpine tar czf /backup/syncthing-config-$(date +%Y%m%d).tar.gz -C /source .
```

### Automated Backup (Kopia)
Kopia does NOT currently back up Syncthing config volume (only data folders).

To add Syncthing config to Kopia backups, add to docker-compose.yml:
```yaml
kopia:
  volumes:
    - syncthing-config:/data/syncthing-config:ro
```

## Testing Persistence

### Test 1: Restart Container
```bash
docker restart syncthing
# Wait for startup
curl http://192.168.178.158:8384
# Check if devices and folders are still configured
```

### Test 2: Recreate Container
```bash
cd ~/light
docker compose down
docker compose up -d syncthing
# Configuration should be identical
```

### Test 3: Remove and Recreate
```bash
docker compose stop syncthing
docker compose rm -f syncthing
docker compose up -d syncthing
# Volume persists, all settings restored
```

## Recovery from Data Loss

### If Config Volume Is Lost
If `syncthing-config` volume is deleted:
- Device ID will change (new keys generated)
- All device connections must be re-established
- All folder shares must be reconfigured
- File index will be rebuilt

### Prevention
- **Never run**: `docker volume rm syncthing-config`
- Backup config volume regularly
- Document device IDs and folder configurations

## API Key Persistence

API key is stored in TWO locations:
1. `/config/config.xml` (in volume)
2. `/keys/syncthing-api-key` (in shared-keys volume)

Both persist across restarts. Dashboard widgets can read from `/keys/` if configured.

## Conclusion

✓ **Syncthing configuration is FULLY persistent**
✓ **Crashes do NOT affect configuration**
✓ **All devices, folders, and settings are preserved**
✓ **Automatic recovery on restart**

The only way to lose configuration:
- Manually deleting the `syncthing-config` volume
- Filesystem corruption (rare)
- Intentional `docker volume prune` (don't do this!)
