# OOM (Out of Memory) Error Fix

> Note: Ported from the light stack. The steps here mainly apply to low-RAM hosts.

## Problem Analysis

### Error Pattern
```
Memory cgroup out of memory: Killed process 311978 (apk)
total-vm:38328kB, anon-rss:15704kB, file-rss:752kB
```

**Process killed**: `apk` (Alpine Package Manager)
**Memory used**: ~15-16MB RSS (resident memory)
**Total VM**: ~38MB (virtual memory)

### Root Cause

The `apk` process is running in the `storage-init` container during startup. This container:
1. Creates directory structure
2. Sets permissions
3. **Installs openssl** via `apk add --no-cache openssl`

The OOM killer is triggered when `apk` tries to install packages but hits the memory cgroup limit.

### Why This Happens

On low-RAM hosts (~2GB), when Docker applies memory limits:
- Default cgroup limits may be too restrictive
- `apk` needs ~20-30MB to install packages
- Multiple retries (visible in logs every ~15-30 minutes)
- Container keeps restarting trying to complete init

## Fixes Applied

### Fix 1: Add Memory Limits to storage-init
**Changed**: Added explicit memory limits to prevent cgroup OOM
**Location**: `docker-compose.yml` - storage-init service

```yaml
storage-init:
  deploy:
    resources:
      limits:
        memory: 64M        # Sufficient for apk install
      reservations:
        memory: 32M
```

**Why 64M**:
- `apk` needs ~20-30MB
- Overhead for shell, processes
- Comfortable margin

### Fix 2: Alternative - Pre-generate API Keys
**Option**: Generate keys outside container, avoid `apk install`

Create script `generate-keys.sh`:
```bash
#!/bin/bash
mkdir -p ./keys
openssl rand -base64 48 | tr -d '\n' > ./keys/slskd-api-key
openssl rand -hex 32 | tr -d '\n' > ./keys/syncthing-api-key
chmod 644 ./keys/*
```

Then modify `init-storage.sh` to skip openssl installation:
```bash
# Remove this line:
# apk add --no-cache openssl >/dev/null 2>&1

# Keys should already exist from host
if [ -f "/keys/slskd-api-key" ]; then
    echo "✓ Using existing API keys"
else
    echo "⚠ Warning: API keys not found, generate them first!"
fi
```

### Fix 3: Optimize Alpine Package Installation
**Modify**: `init-storage.sh` to handle OOM gracefully

```bash
# Add retry logic with reduced memory footprint
install_openssl() {
    if command -v openssl >/dev/null 2>&1; then
        echo "✓ openssl already available"
        return 0
    fi

    echo "Installing openssl..."
    apk add --no-cache openssl 2>&1
    if [ $? -ne 0 ]; then
        echo "⚠ Failed to install openssl, using fallback"
        return 1
    fi
}

install_openssl || echo "Continuing without openssl..."
```

## Monitoring OOM Errors

### Check for OOM Events
```bash
# System logs
sudo journalctl -k | grep -i "out of memory"

# Docker events
docker events --filter 'event=oom'

# Specific container logs
docker logs storage-init 2>&1 | grep -i oom
```

### Check Memory Usage
```bash
# System memory
free -h

# Container memory usage
docker stats --no-stream

# Check cgroup limits
docker inspect storage-init | grep -i memory
```

## Prevention

### 1. Automatic Swap Setup (Already Configured!)
**DONE**: The stack now automatically creates and enables 2GB swap on cache HDD!

The `storage-init` container now:
- Creates `/mnt/cachehdd/swapfile` (2GB)
- Initializes and enables it automatically
- Checks and re-enables on every stack start
- Persists across reboots

**Location**: `/mnt/cachehdd/swapfile`
**Size**: 2GB
**Permissions**: 600 (root:root)
**Status**: Automatically managed

Check swap status:
```bash
swapon --show
free -h
```

Manual enable (if needed):
```bash
sudo swapon /mnt/cachehdd/swapfile
```

### 2. Reduce Memory Footprint
**Current stack memory allocation**:
```
homarr:          96M max
watchtower:      48M max
autoheal:        24M max
gluetun-monitor: 16M max
gluetun:         96M max
transmission:    (inherited from gluetun network)
slskd:           (inherited from gluetun network)
vaultwarden:     128M max (increased)
portainer:       96M max
kopia:           192M max
syncthing:       384M max
filebrowser:     96M max
storage-init:    64M max (NEW)

Total reserved: ~1.3GB
```

With 2GB RAM, this is tight but workable with swap.

### 3. Stagger Container Starts
Modify `docker-compose.yml` to start heavy services after init:

```yaml
# Already implemented via depends_on
depends_on:
  storage-init:
    condition: service_completed_successfully
```

This ensures `storage-init` completes before heavy services start.

## Verification

### Test Fix
```bash
cd ~/light

# Stop stack
docker compose down

# Start with logs
docker compose up -d
docker compose logs -f storage-init

# Look for success message
# "✓ Storage initialization complete"
# "✓ Generated slskd API key"
# "✓ Generated Syncthing API key"
```

### Verify No More OOM
```bash
# Wait 30 minutes, check for OOM events
sudo journalctl -k --since "30 minutes ago" | grep -i "out of memory"

# Should return empty (no OOM)
```

### Check Container Status
```bash
docker compose ps

# storage-init should show:
# STATUS: Exited (0)  # Success exit
```

## If OOM Persists

### Emergency Fix: Disable Memory Limits Temporarily
```yaml
storage-init:
  # Comment out deploy section temporarily
  # deploy:
  #   resources:
  #     limits:
  #       memory: 64M
```

### Check System Memory Pressure
```bash
# Overall memory usage
free -h

# Top memory consumers
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# System processes
top -o %MEM
```

### Reduce Other Container Limits
If system is critically low on memory, reduce limits on optional services:
- Portainer: Reduce to 64M (or disable with profile)
- FileBrowser: Reduce to 64M
- Homarr: Reduce to 64M

## Recommended Solution

**Best approach**: Fix 1 (128M limit) + automatic swap (both applied!)

This provides:
- Enough memory for `apk install` and `dd` (swap creation)
- 2GB swap automatically created and enabled
- Swap persists and auto-enables on every start
- Safety margin for memory pressure
- Clean, maintainable solution

**Changes applied**:
- `docker-compose.yml`: storage-init memory limit 128M, added SYS_ADMIN capability
- `init-storage.sh`: Automatic swap file creation, initialization, and enabling
