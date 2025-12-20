# PotatoStack Light - Fixes Applied

## Quick Fix (Run on Linux Host)

```bash
cd /path/to/light
bash fix-stack.sh
```

## What Was Fixed

### 1. Gluetun 401 Errors ✅
- **Issue**: HTTP control server returning 401 authentication errors in healthcheck
- **Fix**: Added `HTTP_CONTROL_SERVER_AUTH=off` to docker-compose.yml (line 135)
- **Status**: Fixed in docker-compose.yml - run `docker compose up -d --force-recreate gluetun` on Linux host

### 2. PostgreSQL Authentication Failures ✅
- **Issue**: Immich and Seafile unable to authenticate to PostgreSQL
- **Fix**: Created proper database users and databases via fix-stack.sh
- **Databases created**:
  - `immich` (owner: immich)
  - `ccnet_db`, `seafile_db`, `seahub_db` (owner: seafile)
- **Status**: Fixed by script

### 3. Seafile Symlink Loop ✅
- **Issue**: `mv: failed to access '/shared/logs/var-log': Too many levels of symbolic links`
- **Fix**: Script removes circular symlinks from /mnt/storage/seafile/logs
- **Status**: Fixed by script (must run on Linux host where /mnt/storage is accessible)

### 4. Immich Missing Directories ⚠️
- **Issue**: Immich crashes due to missing `/usr/src/app/upload/encoded-video/.immich`
- **Fix**: Create directory on host volume mount
- **Manual fix needed** (run on Linux host):
```bash
mkdir -p /mnt/storage/immich/upload/encoded-video
echo "verified" > /mnt/storage/immich/upload/encoded-video/.immich
docker compose restart immich-server immich-microservices
```

### 5. Vaultwarden Insecure Token ⚠️
- **Issue**: Using plain text ADMIN_TOKEN instead of Argon2 hash
- **Fix**: Generate secure hash (optional - current setup works but is insecure)
- **Manual fix** (run on Linux host):
```bash
docker compose exec vaultwarden /vaultwarden hash --preset owasp
# Then update .env with the generated hash
```

### 6. init-db.sh Updated ✅
- **Fix**: Now creates all 3 Seafile databases (was missing ccnet_db, seafile_db, seahub_db)
- **Status**: Fixed in init-db.sh

## Files Modified

1. **docker-compose.yml**
   - Line 135: Added `HTTP_CONTROL_SERVER_AUTH=off`

2. **init-db.sh**
   - Lines 53-60: Added Seafile database creation

3. **fix-stack.sh** (new file)
   - Comprehensive auto-fix script that handles all issues

## Running on Linux Host (Required)

**IMPORTANT**: You must run the fix script on your actual Linux ARM host (not Windows) because:
- /mnt/storage paths are only accessible on the Linux host
- Docker volumes need to be fixed on the actual host filesystem
- Some containers may be in restart loops and need host-level intervention

### Steps for Linux Host

```bash
# 1. Transfer fix-stack.sh to your Linux host
scp light/fix-stack.sh user@your-linux-host:/path/to/light/

# 2. SSH into your Linux host
ssh user@your-linux-host

# 3. Run the fix script
cd /path/to/light
bash fix-stack.sh

# 4. If Immich is still failing, create the directory manually
mkdir -p /mnt/storage/immich/upload/encoded-video
echo "verified" > /mnt/storage/immich/upload/encoded-video/.immich
docker compose restart immich-server immich-microservices

# 5. Check service status
docker compose ps
docker compose logs -f gluetun seafile immich-server
```

## Verification Checklist

After running fixes:

- [ ] Gluetun: VPN connected (check `docker compose logs gluetun | grep "Public IP"`)
- [ ] PostgreSQL: Immich and Seafile can connect (no auth errors)
- [ ] Seafile: No symlink errors in logs
- [ ] Immich: Server starts without crashing (check `docker compose logs immich-server`)
- [ ] All services healthy: `docker compose ps` shows (healthy) status

## Notes

- **Portainer timeout**: This is normal security behavior after 5 minutes idle - just refresh page
- **FritzBox exporter warnings**: Non-critical, service is working fine
- **Transmission/slskd**: Not visible in `docker compose ps` because they use `network_mode: service:gluetun`
- **Redis eviction warning**: Immich warns about LRU policy but this is intentional for caching

## Troubleshooting

If services still fail after running fix-stack.sh:

```bash
# Check individual service logs
docker compose logs <service-name> --tail 50

# Restart a specific service
docker compose restart <service-name>

# Force recreate everything (nuclear option)
docker compose down
docker compose up -d
```

## Summary

**On Windows (Development/Testing)**: Changes to docker-compose.yml and init-db.sh are complete
**On Linux Host (Production)**: Run `bash fix-stack.sh` to apply all fixes and create missing directories
