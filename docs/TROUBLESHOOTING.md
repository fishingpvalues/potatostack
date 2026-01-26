# PotatoStack Troubleshooting Guide

Common issues and their solutions.

## Docker Storage Corruption

### Symptoms
After a system crash (OOM, kernel panic, power loss), Docker may have corrupted storage:
```
Error response from daemon: layer does not exist
Error response from daemon: stat /mnt/storage/docker/overlay2/...: no such file or directory
unable to get image '...': Error response from daemon: ...
```

### Solution
Run the Docker storage recovery script:
```bash
sudo bash scripts/setup/fix-docker-storage.sh
```

**What it does:**
1. Stops Docker completely
2. Removes corrupted `overlay2` and `image` directories
3. Recreates clean directories
4. Restarts Docker
5. Pulls all images fresh
6. Starts the stack

**Your data is SAFE** - only Docker's internal image cache is removed. All your volumes (postgres data, photos, configs) are stored separately in `/mnt/ssd/docker-data/` and `/mnt/storage/`.

### Manual Recovery
If the script doesn't work, manual steps:
```bash
# Stop Docker completely
sudo systemctl stop docker.socket docker
sudo pkill -9 dockerd 2>/dev/null || true

# Remove ALL corrupted storage (aggressive mode)
sudo rm -rf /mnt/storage/docker/containers
sudo rm -rf /mnt/storage/docker/overlay2
sudo rm -rf /mnt/storage/docker/image
sudo rm -rf /mnt/storage/docker/buildkit
sudo rm -rf /mnt/storage/docker/network/files

# Recreate directories
sudo mkdir -p /mnt/storage/docker/{containers,overlay2,image,buildkit,network/files}

# Start Docker
sudo systemctl start docker.socket docker

# Start stack
cd /home/daniel/potatostack
docker compose up -d
```

### What Gets Removed vs What's Safe

| Directory | Removed | Contains |
|-----------|---------|----------|
| `/mnt/storage/docker/containers` | YES | Container metadata (stale references) |
| `/mnt/storage/docker/overlay2` | YES | Image layers (re-downloaded) |
| `/mnt/storage/docker/image` | YES | Image metadata |
| `/mnt/storage/docker/buildkit` | YES | Build cache |
| `/mnt/storage/docker/volumes` | **NO** | Named volumes (your data!) |
| `/mnt/ssd/docker-data/*` | **NO** | Service data (postgres, configs) |
| `/mnt/storage/photos` | **NO** | Your photos |

---

## Out of Memory (OOM) Crashes

### Symptoms
- System becomes unresponsive
- SSH connections drop
- `last -x` shows "crash" instead of clean shutdown
- `journalctl -b -1 | grep oom` shows OOM killer messages

### Diagnosis
```bash
# Check previous boot for OOM events
journalctl -b -1 | grep -i "oom\|kill\|memory"

# Check which container was killed
journalctl -b -1 | grep "oom-kill"
```

### Common Culprits
1. **Immich** - Video transcoding (especially HEVC) uses lots of RAM
2. **Immich-ML** - Machine learning inference
3. **Jellyfin** - Hardware transcoding

### Solutions
1. **Increase memory limits** in `docker-compose.yml`:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 2G  # Increase from default
   ```

2. **Enable memory pressure handler**:
   ```bash
   sudo bash scripts/setup/enterprise-hardening.sh
   ```

3. **Add more swap** (if needed):
   ```bash
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

---

## Containers Stuck in "Created" State

### Symptoms
After reboot, containers show as "Created" but never start.

### Solution
The startup script handles this automatically, but manual fix:
```bash
docker compose down --remove-orphans
docker compose up -d
```

Or use the startup script:
```bash
bash scripts/init/startup.sh
```

---

## Network Connectivity Issues

### Symptoms
- Containers can't reach the internet
- VPN containers (gluetun) failing
- Tailscale disconnected

### Diagnosis
```bash
# Check if Docker network exists
docker network ls | grep potatostack

# Check container network
docker exec traefik ping -c 1 1.1.1.1

# Check gluetun status
docker logs gluetun --tail 50
```

### Solutions
1. **Restart gluetun and dependents**:
   ```bash
   docker restart gluetun
   sleep 10
   docker restart qbittorrent slskd
   ```

2. **Recreate Docker network**:
   ```bash
   docker compose down
   docker network rm potatostack 2>/dev/null || true
   docker compose up -d
   ```

3. **Check host networking**:
   ```bash
   ping -c 1 1.1.1.1
   systemctl status systemd-networkd
   ip addr show
   ```

---

## Service Won't Start After Crash

### General Recovery
```bash
# Check what's wrong
docker compose ps
docker logs <service-name> --tail 100

# Force recreate
docker compose up -d --force-recreate <service-name>

# Nuclear option - full restart
docker compose down --remove-orphans
docker compose up -d
```

### PostgreSQL Issues
If Postgres won't start after crash:
```bash
# Check logs
docker logs postgres --tail 100

# If "database system was not properly shut down"
# It should auto-recover, just wait a few minutes

# If corrupted, restore from backup (see KOPIA-BACKUP-GUIDE.md)
```

---

## Healthcheck Failing

### Diagnosis
```bash
# Check which containers are unhealthy
docker ps --filter "health=unhealthy"

# Check healthcheck logs
docker inspect <container> | jq '.[0].State.Health'
```

### Common Fixes
1. **Wait longer** - some services need time after restart
2. **Check dependencies** - is postgres/redis running?
3. **Check resource limits** - container might be OOM killed internally

---

## Useful Commands

```bash
# Full system status
make health

# View logs for specific service
make logs SERVICE=immich-server

# Restart everything cleanly
make restart

# Check disk space
df -h /mnt/storage /mnt/ssd

# Check memory
free -h

# Check recent crashes
last -x | head -20
journalctl -b -1 -p err
```

---

## Prevention

Run the enterprise hardening script to enable auto-recovery:
```bash
sudo bash scripts/setup/enterprise-hardening.sh
```

This enables:
- Hardware watchdog (auto-reboot on kernel hang)
- Network connectivity monitor
- Memory pressure handler
- Container health checks every 10 minutes
- Auto-restart of failed services
