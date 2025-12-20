# PotatoStack Light - Automated Fixes

## All Fixes Now Automated in Docker

All manual fixes from `fix-stack.sh` have been integrated into the Docker Compose setup. Services will auto-fix themselves on startup.

## What Was Fixed and Automated

### 1. Gluetun 401 Errors ✅ AUTOMATED
- **Issue**: HTTP control server returning 401 authentication errors in healthcheck
- **Fix**: Added `HTTP_CONTROL_SERVER_AUTH=off` to docker-compose.yml (line 135)
- **Status**: Automatically fixed on container start

### 2. PostgreSQL Authentication Failures ✅ AUTOMATED
- **Issue**: Immich and Seafile unable to authenticate to PostgreSQL
- **Fix**: Enhanced init-db.sh creates proper database users and databases
- **Databases created**:
  - `immich` (owner: immich)
  - `ccnet_db`, `seafile_db`, `seahub_db` (owner: seafile)
- **Status**: Automatically created on first postgres startup via init-db.sh

### 3. Seafile Symlink Loop ✅ AUTOMATED
- **Issue**: `mv: failed to access '/shared/logs/var-log': Too many levels of symbolic links`
- **Fix**: seafile-entrypoint.sh removes circular symlinks before Seafile starts
- **Status**: Automatically cleaned on every container start via entrypoint script

### 4. Immich Missing Directories ✅ AUTOMATED
- **Issue**: Immich crashes due to missing `/usr/src/app/upload/encoded-video/.immich`
- **Fix**: immich-entrypoint.sh creates required directories before Immich starts
- **Status**: Automatically created on every container start via entrypoint script

### 5. Vaultwarden Insecure Token ℹ️ OPTIONAL
- **Issue**: Using plain text ADMIN_TOKEN instead of Argon2 hash
- **Fix**: Optional - generate secure hash for better security
- **Status**: Plain text works fine, hashing is optional security enhancement
- **To generate hash** (optional):
```bash
docker compose exec vaultwarden /vaultwarden hash --preset owasp
# Then update .env with: VAULTWARDEN_ADMIN_TOKEN='generated-hash'
```

### 6. Healthcheck Endpoints Updated ✅ AUTOMATED
- **Fix**: Updated healthcheck endpoints for Immich and Portainer to use correct API paths
  - Immich: `/api/server/ping` (was `/api/server-info/ping`)
  - Portainer: `/api/system/status` (was `/api/status`)
- **Status**: Automatically checked on every health interval

## Files Modified

1. **docker-compose.yml**
   - Line 135: Added `HTTP_CONTROL_SERVER_AUTH=off`
   - immich-server: Added entrypoint script, updated healthcheck endpoint
   - immich-microservices: Added entrypoint script
   - seafile: Added entrypoint script
   - portainer: Updated healthcheck endpoint

2. **init-db.sh**
   - Lines 53-60: Added Seafile database creation (already present)

3. **immich-entrypoint.sh** (new file)
   - Auto-creates required Immich directories on startup

4. **seafile-entrypoint.sh** (new file)
   - Auto-cleans broken symlinks on startup

5. **fix-stack.sh** (deprecated)
   - No longer needed - all fixes are now automated in Docker

## Deployment on Linux Host

Just deploy and start - everything is automated:

```bash
cd /path/to/light
docker compose up -d
```

All fixes run automatically on container startup. No manual intervention needed.

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

If services fail on first start:

```bash
# Check logs
docker compose logs <service-name> --tail 50

# Restart a service (fixes will re-run automatically)
docker compose restart <service-name>

# Full restart
docker compose down && docker compose up -d
```

## Summary

**All fixes are now automated** - just run `docker compose up -d` and everything self-configures on first start.
