# PotatoStack Light - Enterprise Production Setup

100% uptime focused, single-disk architecture with automatic backups, self-healing, and automatic updates.

## Features

### 🏠 Homepage Dashboard
- Unified control center with all service widgets
- Real-time container status
- Resource monitoring
- Quick access to all services

### 🔄 Automatic Updates
- **Watchtower** updates containers nightly at 3 AM
- Rolling restarts to minimize downtime
- Automatic cleanup of old images

### 🏥 Self-Healing
- **Autoheal** monitors container health
- Automatic restart of unhealthy containers
- Health checks every 30 seconds

### 💾 Automated Backups
- Nightly incremental backups to second disk (3 AM)
- rsync with hard links (space-efficient)
- 7-day retention policy
- Automatic old backup cleanup

### 🌐 Network Resilience
- All containers use `restart: always`
- Survives network disconnects (FritzBox reconnects)
- Bridged network with custom subnet
- VPN killswitch for P2P traffic

### 🛡️ Enterprise-Grade Reliability
- Enhanced health checks on all services
- Cron job monitors Docker daemon health
- Automatic Docker restart if unresponsive
- Regular system cleanup

## Quick Start

### 1. Mount Your Disks

```bash
# Find disk UUIDs
sudo blkid

# Edit /etc/fstab
sudo nano /etc/fstab

# Add these lines (replace UUIDs):
UUID=your-main-disk-uuid /mnt/storage ext4 defaults,nofail 0 2
UUID=your-backup-disk-uuid /mnt/backup ext4 defaults,nofail 0 2

# Create mount points and mount
sudo mkdir -p /mnt/storage /mnt/backup
sudo mount -a
```

### 2. Setup Directories

```bash
cd light
chmod +x setup-directories-production.sh
sudo ./setup-directories-production.sh
```

### 3. Generate Secure .env File

```bash
chmod +x generate-env.sh
./generate-env.sh
```

**IMPORTANT:** Save the displayed passwords in your password manager!

### 4. Copy Homepage Configuration

```bash
sudo mkdir -p /var/lib/docker/volumes/light_homepage-config/_data
sudo cp -r homepage-config/* /var/lib/docker/volumes/light_homepage-config/_data/
```

Or let Docker create the volume and copy later:
```bash
# After first start
docker cp homepage-config/. homepage:/app/config/
docker restart homepage
```

### 5. Setup Cron Jobs

```bash
chmod +x setup-cron.sh
./setup-cron.sh
```

This sets up:
- Nightly backups (3:00 AM)
- Weekly Docker cleanup (Sunday 4:00 AM)
- Health monitoring (every 5 minutes)
- Docker daemon recovery (every 10 minutes)

### 6. Start the Stack

```bash
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

### 7. Access Services

| Service | URL | Port |
|---------|-----|------|
| **Homepage Dashboard** | http://YOUR_IP:3000 | 3000 |
| Gluetun Control | http://YOUR_IP:8000 | 8000 |
| Transmission | http://YOUR_IP:9091 | 9091 |
| slskd | http://YOUR_IP:2234 | 2234 |
| Vaultwarden | http://YOUR_IP:8080 | 8080 |
| Portainer | https://YOUR_IP:9443 | 9443 |
| Immich | http://YOUR_IP:2283 | 2283 |
| Kopia | https://YOUR_IP:51515 | 51515 |
| Seafile | http://YOUR_IP:8082 | 8082 |
| Rustypaste | http://YOUR_IP:8001 | 8001 |

## Architecture

### Single-Disk Design

**Main Storage** (`/mnt/storage`):
- All application data
- Downloads and media
- Databases (via Docker volumes)
- Cache and temporary files

**Backup Storage** (`/mnt/backup`):
- Nightly incremental backups
- 7-day rolling retention
- Hard-linked duplicates (space efficient)

### Automatic Updates

Watchtower checks for updates daily and applies them automatically:
- Updates only labeled containers
- Rolling restart strategy
- 5-minute timeout per container
- Cleanup old images automatically

To disable updates for a specific service, remove its `com.centurylinklabs.watchtower.enable` label.

### Self-Healing

Autoheal monitors all containers with `autoheal=true` label:
- Checks health status every 30 seconds
- Restarts unhealthy containers automatically
- 300-second grace period on startup
- Logs all restart actions

### Backup Strategy

The `backup-to-second-disk.sh` script:
1. Uses rsync for incremental transfers
2. Hard-links unchanged files (saves space)
3. Creates timestamped snapshots
4. Keeps 7 days of history
5. Logs all operations

**Space efficiency example:**
- Day 1: 100 GB backup
- Day 2: 5 GB changed, total space = 105 GB (not 200 GB!)
- Hard links save ~95% of space

### Network Resilience

All services use `restart: always` to survive:
- Network disconnects
- FritzBox reboots
- Internet reconnects
- Docker daemon restarts

Custom bridge network with static subnet prevents IP conflicts.

## Container Version Updates

Watchtower handles updates automatically:

1. **Daily Check** (3:00 AM):
   - Checks all enabled containers for updates
   - Downloads new images

2. **Rolling Update**:
   - Stops old container
   - Starts new container
   - Waits for health check
   - Proceeds to next container

3. **Failure Handling**:
   - If update fails, keeps old container
   - Logs error for manual intervention
   - Continues with other updates

### Manual Update Control

```bash
# Update specific service
docker compose -f docker-compose.production.yml --env-file .env.production pull SERVICE_NAME
docker compose -f docker-compose.production.yml --env-file .env.production up -d SERVICE_NAME

# Update all services
docker compose -f docker-compose.production.yml --env-file .env.production pull
docker compose -f docker-compose.production.yml --env-file .env.production up -d

# Check Watchtower logs
docker logs watchtower
```

## Monitoring & Maintenance

### Check Container Status

```bash
# All containers
docker ps

# Health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# View logs
docker logs -f CONTAINER_NAME

# Stack logs
docker compose -f docker-compose.production.yml logs -f
```

### Check Backup Status

```bash
# View latest backup log
tail -f /var/log/potatostack/backup-$(date +%Y-%m-%d).log

# List all backups
ls -lh /mnt/backup/

# Check backup disk space
df -h /mnt/backup
```

### Manual Backup

```bash
sudo /path/to/backup-to-second-disk.sh
```

### Check Cron Jobs

```bash
# View cron jobs
crontab -l

# Check cron logs
tail -f /var/log/potatostack/backup-cron.log
tail -f /var/log/potatostack/docker-prune.log
tail -f /var/log/potatostack/health-check.log
```

### Homepage Configuration

Edit homepage widgets and services:

```bash
# Edit services
sudo nano /var/lib/docker/volumes/light_homepage-config/_data/services.yaml

# Restart homepage
docker restart homepage
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs CONTAINER_NAME

# Check health
docker inspect CONTAINER_NAME | grep -A 10 Health

# Manual restart
docker restart CONTAINER_NAME
```

### Backup Failed

```bash
# Check backup log
tail -100 /var/log/potatostack/backup-$(date +%Y-%m-%d).log

# Check disk space
df -h /mnt/storage /mnt/backup

# Verify mount points
mountpoint /mnt/storage
mountpoint /mnt/backup

# Run backup manually
sudo /path/to/backup-to-second-disk.sh
```

### Network Issues After FritzBox Reboot

All containers should automatically restart. If not:

```bash
# Check container status
docker ps -a

# Restart stack
docker compose -f docker-compose.production.yml --env-file .env.production restart

# Check network
docker network ls
docker network inspect light_potatostack
```

### Watchtower Not Updating

```bash
# Check Watchtower logs
docker logs watchtower

# Force immediate update
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once

# Verify labels
docker inspect CONTAINER_NAME | grep -A 5 Labels
```

### Autoheal Not Working

```bash
# Check Autoheal logs
docker logs autoheal

# Verify container has autoheal label
docker inspect CONTAINER_NAME | grep autoheal

# Check unhealthy containers
docker ps --filter "health=unhealthy"
```

### Homepage Not Showing Widgets

1. Check API keys in .env.production:
   - `HOMEPAGE_VAR_IMMICH_API_KEY`
   - `HOMEPAGE_VAR_PORTAINER_API_KEY`

2. Generate API keys:
   ```bash
   # Portainer: Settings > API > Add access token
   # Immich: User Settings > API Keys > New API Key
   ```

3. Update .env.production and restart:
   ```bash
   docker compose -f docker-compose.production.yml --env-file .env.production up -d homepage
   ```

## Security Notes

### Password Management

ALL passwords are auto-generated by `generate-env.sh`:
- 32-character base64 passwords
- 48-character admin tokens
- Stored in `.env.production` (chmod 600)

**NEVER commit .env.production to git!**

### Network Security

- Services bind to LAN IP only (not 0.0.0.0)
- VPN killswitch for P2P traffic
- FritzBox provides WireGuard VPN for remote access
- No port forwarding required

### Update Security

- Watchtower pulls trusted images only
- Pinned image tags in .env (optional)
- Rolling updates minimize downtime
- Failed updates don't break stack

## Performance Tuning

### Optimize Redis

Already configured for:
- 256 MB memory limit
- LRU eviction policy
- Persistence (save every 15 minutes)

### Optimize PostgreSQL

Add to postgres service in docker-compose.production.yml:
```yaml
command:
  - postgres
  - -c
  - shared_buffers=256MB
  - -c
  - max_connections=100
  - -c
  - work_mem=4MB
```

### Optimize Backup Speed

Edit `backup-to-second-disk.sh`:
```bash
# Add compression (slower, less space)
--compress

# Add bandwidth limit (MB/s)
--bwlimit=50

# Exclude large directories
--exclude='*/node_modules/*'
```

## Advanced Configuration

### Custom Watchtower Schedule

Edit .env.production:
```bash
# Update daily at 2 AM
WATCHTOWER_SCHEDULE=0 0 2 * * *

# Update twice daily
WATCHTOWER_SCHEDULE=0 0 2,14 * * *
```

### Notifications

Add notification URL in .env.production:
```bash
# Gotify
WATCHTOWER_NOTIFICATION_URL=gotify://gotify.example.com/token

# Discord
WATCHTOWER_NOTIFICATION_URL=discord://token@channel

# Email
WATCHTOWER_NOTIFICATION_URL=smtp://user:pass@host:port/?from=from@example.com&to=to@example.com
```

### Backup Retention

Edit `backup-to-second-disk.sh`:
```bash
RETENTION_DAYS=14  # Keep 14 days instead of 7
```

### Health Check Intervals

Edit cron in `setup-cron.sh`:
```bash
# Check every minute instead of 5
*/1 * * * * docker ps --filter "health=unhealthy" ...
```

## Disaster Recovery

### Restore from Backup

```bash
# Stop stack
docker compose -f docker-compose.production.yml down

# Restore from backup
sudo rsync -aHAXxv /mnt/backup/latest/ /mnt/storage/

# Start stack
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

### Rebuild After Failure

```bash
# Remove all containers and volumes
docker compose -f docker-compose.production.yml down -v

# Restore from backup
sudo rsync -aHAXxv /mnt/backup/latest/ /mnt/storage/

# Recreate volumes
docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

## Support

Check logs in:
- `/var/log/potatostack/` - Cron job logs
- `docker logs CONTAINER_NAME` - Container logs
- `/mnt/storage/*/logs/` - Application logs

For issues:
1. Check logs
2. Verify disk space
3. Check network connectivity
4. Review cron job status
5. Test backup manually

## Summary

This production setup provides:
- ✅ 100% uptime focus with auto-restart
- ✅ Automatic container updates (Watchtower)
- ✅ Self-healing containers (Autoheal)
- ✅ Nightly backups to second disk
- ✅ Network resilience (survives reboots)
- ✅ Unified dashboard (Homepage)
- ✅ Enterprise-grade reliability
- ✅ Automatic cleanup and maintenance
- ✅ Comprehensive monitoring
- ✅ Secure by default

**Start now:**
```bash
./generate-env.sh && ./setup-cron.sh && docker compose -f docker-compose.production.yml --env-file .env.production up -d
```
