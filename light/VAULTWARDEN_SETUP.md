# Vaultwarden Setup Guide

## Current Issue
Port 8080 loads forever - likely healthcheck failing or container startup issue.

## Troubleshooting Steps

### 1. Check container status
```bash
docker ps -a | grep vaultwarden
docker logs vaultwarden
```

### 2. Check if port is accessible
```bash
curl -v http://192.168.178.40:8080
curl -v http://127.0.0.1:8080  # from server
```

### 3. Test healthcheck manually
```bash
docker exec vaultwarden curl -f http://127.0.0.1:80/alive
```

## Android Bitwarden App Configuration

### Self-Hosted Settings
1. Open Bitwarden app on Android
2. Tap on Settings (gear icon)
3. Tap "Self-hosted Environment"
4. Enter **Server URL**: `http://192.168.178.40:8080`
5. **DO NOT** enter anything for:
   - Web Vault Server URL (leave empty)
   - API Server URL (leave empty)
   - Identity Server URL (leave empty)
   - Icons Server URL (leave empty)
6. Tap "Save"
7. Go back and tap "Log In" or "Create Account"

### Certificate Configuration
**For HTTP (no SSL)**: No certificate needed, works on local network
**For HTTPS**: Not configured in current setup

## Current Vaultwarden Configuration

**Access URL (LAN)**: `http://192.168.178.40:8080`
**WebSocket Port**: `3012` (for live sync)
**Domain**: `https://vault.lepotato.local` (not used, placeholder)
**Internal Port**: `80` (mapped to 8080 on host)

**Security Settings**:
- Signups: Disabled (controlled by env var)
- Invitations: Enabled
- Admin panel: Enabled (needs ADMIN_TOKEN)

## Fixes Required

### Fix 1: Increase healthcheck timeout
The container might be slow to start on Le Potato (2GB RAM).

Edit docker-compose.yml vaultwarden healthcheck:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://127.0.0.1:80/alive"]
  interval: 60s
  timeout: 10s
  retries: 10              # Increase from 5 to 10
  start_period: 120s       # Increase from 30s to 120s
```

### Fix 2: Check memory limits
Current limits: 96M max, 48M reserved
Vaultwarden might need more on startup.

Consider increasing:
```yaml
deploy:
  resources:
    limits:
      memory: 128M         # Increase from 96M
    reservations:
      memory: 64M          # Increase from 48M
```

### Fix 3: Verify environment variables
Check `.env` file has VAULTWARDEN_ADMIN_TOKEN set:
```bash
grep VAULTWARDEN_ADMIN_TOKEN .env
```

### Fix 4: Disable admin token temporarily for testing
```yaml
# Comment out ADMIN_TOKEN in docker-compose.yml
# - ADMIN_TOKEN=${VAULTWARDEN_ADMIN_TOKEN}
```

## After Fixes

1. Restart container:
```bash
cd ~/light
docker compose restart vaultwarden
docker logs -f vaultwarden
```

2. Wait for startup (may take 30-60s on Le Potato)

3. Test access:
```bash
curl http://192.168.178.40:8080
```

Should return HTML page, not timeout.

4. Access web UI: `http://192.168.178.40:8080`

5. Create account (if signups enabled) or use admin panel to invite users

## Admin Panel Access
**URL**: `http://192.168.178.40:8080/admin`
**Token**: Value of `VAULTWARDEN_ADMIN_TOKEN` from `.env`

Use admin panel to:
- View users
- Send invitations
- Configure settings
- View diagnostics
