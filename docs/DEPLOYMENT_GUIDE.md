# PotatoStack Deployment & Testing Guide

## Quick Start (For Server: 192.168.178.158)

### Step 1: Copy Files to Server

From your local machine with access to the server:

```bash
# Copy entire stack to server
scp -r docker-compose.yml .env.example config/ scripts/monitor/run-and-monitor.sh \
    daniel@192.168.178.158:~/light/
```

### Step 2: Run Stack with Monitoring

SSH to server and execute:

```bash
ssh daniel@192.168.178.158
cd ~/light
chmod +x run-and-monitor.sh
./scripts/monitor/run-and-monitor.sh 90  # Monitor for 90 seconds
```

## What the Monitoring Script Does

1. **Pre-flight Checks**: Validates docker-compose.yml and .env
2. **Phased Startup**: Starts services in order:
   - Phase 1: Databases (Postgres, Redis, Mongo, PgBouncer)
   - Phase 2: Networking (Traefik, Gluetun, AdGuard, CrowdSec)
   - Phase 3: Monitoring (Prometheus, Grafana, Loki)
   - Phase 4: All remaining services
3. **Health Monitoring**: Tracks running/failed/unhealthy containers
4. **Log Analysis**: Scans logs for error patterns
5. **Resource Monitoring**: Shows CPU/RAM usage
6. **Issue Report**: Generates comprehensive report with failures

## Stack Specifications

- **Total Services**: 90
- **RAM Limits**: 13.08 GB (optimized for 16GB system)
- **Est. Peak Usage**: 15.04 GB
- **Headroom**: 0.96 GB

### Services Breakdown

**Heavy Tier (768MB each)**:
- immich-machine-learning
- immich-server
- jellyfin
- paperless-ngx

**Core Tier (512MB each)**:
- postgres
- mongo
- redis-cache
- authentik-server

**Standard Tier (384MB each)**:
- code-server, stirling-pdf, gitea, open-webui

**Light Tier (128MB each)**:
- 48 services including *arr stack, monitoring, utilities

## Testing & Validation

### Automated Tests (Already Passed)

```bash
# Run comprehensive validation
./real-test.sh
```

**Results**:
- ✅ YAML syntax valid
- ✅ Docker Compose config valid
- ✅ 90 services configured
- ✅ 30 services with health checks
- ✅ 66 services with log rotation
- ✅ RAM limits optimized (13.08 GB)

### Manual Health Checks

```bash
# Check running services
docker compose ps

# View specific service logs
docker compose logs -f <service-name>

# Check resource usage
docker stats

# View failed services
docker compose ps --filter status=exited

# Restart specific service
docker compose restart <service-name>
```

## Common Issues & Fixes

### Issue: Service Fails to Start

**Symptoms**: Service shows as "exited" in `docker compose ps`

**Fix**:
```bash
# Check logs
docker compose logs --tail 100 <service-name>

# Common causes:
# 1. Missing env vars - check .env file
# 2. Port conflict - check if port already in use
# 3. Volume permissions - check /mnt/* permissions
# 4. Memory limit too low - increase in docker-compose.yml
```

### Issue: High RAM Usage

**Symptoms**: System using >14GB RAM

**Fix**:
```bash
# Disable non-critical services
docker compose stop audiobookshelf code-server open-webui

# Or increase limits in docker-compose.yml and restart
```

### Issue: Database Connection Errors

**Symptoms**: Services can't connect to Postgres/Mongo/Redis

**Fix**:
```bash
# Ensure databases started first
docker compose up -d postgres redis-cache mongo pgbouncer
sleep 10

# Then start dependent services
docker compose up -d
```

### Issue: Permission Denied on Volumes

**Symptoms**: Logs show "permission denied" errors

**Fix**:
```bash
# Fix permissions on bind mounts
sudo chown -R $USER:$USER /mnt/storage /mnt/cachehdd /mnt/ssd/docker-data
sudo chmod -R 755 /mnt/storage /mnt/cachehdd /mnt/ssd/docker-data
```

## Monitoring URLs (After Stack is Running)

Access these from your browser:

### Primary
- **Grafana**: http://192.168.178.158:3002 (main monitoring dashboard)
- **Homarr**: http://192.168.178.158:7575 (dashboard)
- **Traefik**: http://192.168.178.158:8080 (reverse proxy dashboard)

### Monitoring
- **Prometheus**: http://192.168.178.158:9090
- **Thanos Query**: http://192.168.178.158:10903
- **Uptime Kuma**: http://192.168.178.158:3001

### Applications
- **Syncthing**: http://192.168.178.158:8384
- **Jellyfin**: http://192.168.178.158:8096
- **Immich**: http://192.168.178.158:2283
- **Paperless**: http://192.168.178.158:8000

## Performance Optimization

### Enable Swap (Recommended)

```bash
# Create 8GB swap on SSD
sudo fallocate -l 8G /mnt/ssd/swapfile
sudo chmod 600 /mnt/ssd/swapfile
sudo mkswap /mnt/ssd/swapfile
sudo swapon /mnt/ssd/swapfile

# Make permanent
echo '/mnt/ssd/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Schedule Heavy Tasks

Use cron to schedule:
- **Backups**: Run at night (e.g., 2 AM)
- **ML inference (Immich)**: On-demand only
- **Transcoding (Jellyfin)**: During low-usage hours
- **Database maintenance**: Weekly at night

## Backup & Recovery

### Backup Critical Data

```bash
# Vaultwarden passwords
docker compose exec vaultwarden /bin/sh -c 'sqlite3 /data/db.sqlite3 .dump' > vaultwarden-backup.sql

# PostgreSQL databases
docker compose exec postgres pg_dumpall -U postgres > postgres-backup.sql

# All configs
tar -czf configs-backup.tar.gz config/ .env docker-compose.yml
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore volumes
# (copy backup data to volume directories)

# Start services
docker compose up -d
```

## Update Stack

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Remove old images
docker image prune -a
```

## Troubleshooting Commands

```bash
# View all service status
docker compose ps -a

# Follow logs for all services
docker compose logs -f

# Check resource usage
docker stats --no-stream

# Restart unhealthy services
docker compose ps --filter health=unhealthy --format '{{.Service}}' | xargs -r docker compose restart

# Remove and recreate specific service
docker compose rm -sf <service-name>
docker compose up -d <service-name>

# Full stack restart
docker compose restart

# Nuclear option - rebuild everything
docker compose down
docker compose up -d --force-recreate
```

## Support

For issues:
1. Check logs: `docker compose logs <service-name>`
2. Check GitHub issues for the specific service
3. Review service documentation
4. Check Grafana for resource issues
