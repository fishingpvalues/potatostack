# Kopia Backup System for Potato Stack

Complete backup solution for Le Potato SBC running the Potato Stack.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Scripts](#scripts)
- [Monitoring](#monitoring)
- [Maintenance](#maintenance)
- [Disaster Recovery](#disaster-recovery)
- [Troubleshooting](#troubleshooting)

## Overview

### Design Principles

1. **NO COMPRESSION** - Optimized for Le Potato ARM64 CPU
   - Storage is cheap, CPU cycles are precious
   - Avoids memory pressure on 2GB RAM
   - Faster backup/restore operations

2. **Conservative Resource Limits**
   - Max 768MB RAM for Kopia server
   - Single parallel snapshot (prevents OOM)
   - USB 3.0 bandwidth limiting (50 MB/s)
   - 2 parallel file reads maximum

3. **3-2-1 Backup Strategy**
   - 3 copies of data (primary + 2 backups)
   - 2 different media types (HDD + cloud/NAS)
   - 1 off-site copy (optional cloud)

4. **Automated & Monitored**
   - Daily snapshots at 3:00 AM
   - Weekly maintenance (Sundays 4:00 AM)
   - Monthly full maintenance (1st Sunday)
   - Prometheus metrics + Grafana dashboards
   - Alertmanager notifications

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Potato Stack Services                        │
│  (Nextcloud, Gitea, qBittorrent, Vaultwarden, Firefly, etc.)   │
└────────────┬────────────────────────────────────────────────────┘
             │ writes data to
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Storage Locations                             │
│  • /mnt/seconddrive/* (configs, repos, databases)               │
│  • /mnt/cachehdd/* (downloads, media)                           │
│  • Docker volumes (Prometheus, Grafana, Loki, etc.)             │
└────────────┬────────────────────────────────────────────────────┘
             │ backed up by
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Kopia Backup Server                            │
│  • Daily snapshots (3:00 AM)                                    │
│  • NO compression (Le Potato optimized)                         │
│  • Deduplication (FIXED-4M splitter)                           │
│  • GFS retention (7 latest, 14 daily, 8 weekly, 12 monthly)    │
└────────────┬────────────────────────────────────────────────────┘
             │ stores to
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Primary Repository                               │
│  Location: /mnt/seconddrive/kopia/repository                    │
│  Encryption: AES-256 (KOPIA_PASSWORD from .env)                │
│  Type: Filesystem                                                │
└────────────┬────────────────────────────────────────────────────┘
             │ optionally replicate to
             ▼
┌─────────────────────────────────────────────────────────────────┐
│            Secondary/Offsite Repositories                        │
│  • USB external drive (local redundancy)                        │
│  • NAS (SMB/NFS mount)                                          │
│  • Cloud (S3, B2, Google Cloud, SFTP)                           │
└─────────────────────────────────────────────────────────────────┘
```

### What Gets Backed Up

#### Critical Data (Daily Snapshots)
- Kopia configuration: `/mnt/seconddrive/kopia/config`
- Nextcloud data: `/mnt/seconddrive/nextcloud`
- Gitea repositories: `/mnt/seconddrive/gitea`
- qBittorrent config: `/mnt/seconddrive/qbittorrent/config`
- slskd config: `/mnt/seconddrive/slskd/config`
- Uptime Kuma data: `/mnt/seconddrive/uptime-kuma`
- Database dumps: `/mnt/seconddrive/backups/db`
- Vaultwarden backups: `/mnt/seconddrive/backups/vaultwarden`
- Docker configs: `./config/*`
- Docker Compose files: `./docker-compose.yml`, `.env`
- Scripts: `./scripts/*`

#### Excluded (via .kopiaignore)
- Docker runtime data (`/var/lib/docker/overlay2`, `/var/lib/docker/containers`)
- Kopia's own repository and cache (prevents recursion)
- Prometheus/Grafana/Loki time-series data (regenerates)
- Incomplete downloads (`torrents/incomplete`, `soulseek/incomplete`)
- Logs, temporary files, caches
- System directories (`/proc`, `/sys`, `/dev`, `/run`)

## Quick Start

### 1. Initial Setup

```bash
cd /path/to/potatostack

# Set up Kopia policies (NO compression, Le Potato optimized)
./scripts/kopia/setup-policies.sh

# Verify Kopia is running
docker ps | grep kopia

# Check repository status
docker exec kopia_server kopia repository status
```

### 2. Create First Snapshot

```bash
# Manual snapshot of all critical data
./scripts/kopia/create-snapshots.sh

# List snapshots
docker exec kopia_server kopia snapshot list --all
```

### 3. Set Up Automation

```bash
# Configure automated backups (choose option 1: RECOMMENDED)
./scripts/kopia/setup-scheduling.sh

# Verify cron installation
crontab -l | grep kopia
```

### 4. Verify Backups

```bash
# Run comprehensive verification
./scripts/verify-kopia-backups.sh

# Check Prometheus metrics
curl http://localhost:51516/metrics | grep kopia_
```

## Configuration

### Policy Settings (setup-policies.sh)

```bash
# Compression: NONE (optimized for Le Potato)
--compression=none

# Retention: GFS (Grandfather-Father-Son)
--keep-latest 7        # Last 7 snapshots
--keep-hourly 24       # Last 24 hours
--keep-daily 14        # Last 14 days
--keep-weekly 8        # Last 8 weeks
--keep-monthly 12      # Last 12 months
--keep-annual 3        # Last 3 years

# Performance: Conservative (2GB RAM, USB 3.0)
--parallel-upload-above-size-mib=32    # Parallel for files >32MB
--max-parallel-snapshots=1              # One snapshot at a time
--max-parallel-file-reads=2             # Two concurrent file reads
--upload-max-megabytes-per-sec=50       # 50 MB/s limit (USB safe)

# Deduplication: FIXED-4M splitter
--splitter=FIXED-4M                     # Good balance for mixed content

# Error Handling
--ignore-dir-errors                     # Continue on permission errors
--ignore-file-errors                    # Continue on file access errors
```

### Docker Compose Configuration

```yaml
kopia:
  environment:
    - KOPIA_PASSWORD=${KOPIA_PASSWORD}              # Repository encryption
    - GOGC=50                                       # Aggressive GC (low RAM)
    - GOMAXPROCS=2                                  # Limit CPU cores
    - KOPIA_PROMETHEUS_ENABLED=true                 # Metrics export
  mem_limit: 768m                                   # Hard memory limit
  mem_reservation: 384m                             # Soft reservation
  cpus: 2                                           # CPU limit
```

### Environment Variables (.env)

```bash
# Kopia Configuration
KOPIA_PASSWORD=your_secure_password_here            # Repository encryption
KOPIA_SERVER_USER=admin                             # Web UI username
KOPIA_SERVER_PASSWORD=your_server_password_here     # Web UI password
KOPIA_TAG=latest                                    # Docker image tag

# Optional: Cloud Repository Credentials
B2_KEY_ID=your_backblaze_key_id
B2_APPLICATION_KEY=your_backblaze_app_key
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
```

## Scripts

### create-snapshots.sh

Creates snapshots of all critical Potato Stack data.

```bash
# Manual execution
./scripts/kopia/create-snapshots.sh

# Custom container name
KOPIA_CONTAINER=kopia_custom ./scripts/kopia/create-snapshots.sh

# Check logs
tail -f /mnt/seconddrive/kopia/logs/snapshots-*.log
```

**Features:**
- Backs up all critical paths (configs, databases, repos)
- Tags snapshots with `type:automated`, `stack:potatostack`
- Runs quick maintenance after snapshots
- Detailed logging with timestamps
- Exit code 1 if any snapshots fail

### maintenance.sh

Repository maintenance and optimization.

```bash
# Quick maintenance (5-10 minutes)
./scripts/kopia/maintenance.sh

# Full maintenance (30-60 minutes, monthly recommended)
FULL_MAINTENANCE=true ./scripts/kopia/maintenance.sh

# Dry run (preview deletions)
DRY_RUN=true ./scripts/kopia/maintenance.sh
```

**Tasks:**
- Repository statistics
- Snapshot expiration (apply retention policies)
- Cache management
- Maintenance tasks (GC, verification, compaction)
- Quick integrity check
- Disk space analysis
- Log cleanup (>30 days)

### setup-policies.sh

Configures Kopia backup policies.

```bash
./scripts/kopia/setup-policies.sh
```

**Policies Set:**
- Retention (GFS: 7/24/14/8/12/3)
- Compression (NONE - Le Potato optimized)
- Scheduling (daily at 3:00 AM)
- Performance (conservative for 2GB RAM)
- Error handling (ignore inaccessible files)
- Deduplication (FIXED-4M splitter)
- Upload limits (50 MB/s USB safe)

### setup-scheduling.sh

Interactive cron setup wizard.

```bash
./scripts/kopia/setup-scheduling.sh
```

**Options:**
1. **RECOMMENDED** - Daily backups + weekly maintenance
2. **CONSERVATIVE** - Every 2 days + bi-weekly maintenance
3. **AGGRESSIVE** - Twice daily + daily maintenance
4. **CUSTOM** - Manual configuration

**Schedule (RECOMMENDED):**
- 3:00 AM - Daily snapshots
- 4:00 AM - Quick maintenance (Sundays)
- 4:00 AM - Full maintenance (1st Sunday)
- 5:00 AM - Verification (Mondays)

### verify-kopia-backups.sh

Comprehensive backup verification (existing script).

```bash
./scripts/verify-kopia-backups.sh
```

**Checks:**
1. Kopia container status
2. Server health endpoint
3. Repository accessibility
4. Snapshot count and recency
5. Prometheus metrics
6. Repository integrity
7. Optional test restore
8. Backup schedule
9. Disaster recovery checklist

### multi-repo-example.sh

Educational guide for multi-repository setup (existing).

```bash
# View examples only (DRY_RUN=true by default)
./scripts/kopia/multi-repo-example.sh
```

**Demonstrates:**
- Secondary USB/NAS repository setup
- Cloud repository (B2, S3, SFTP)
- Multi-repository workflows
- Docker Compose configuration
- Verification across repositories

## Monitoring

### Prometheus Metrics

Kopia exports metrics on port 51516:

```bash
curl http://localhost:51516/metrics
```

**Key Metrics:**
- `kopia_snapshot_manager_errors_total` - Cumulative error count
- `kopia_snapshot_manager_last_snapshot_time_seconds` - Last snapshot timestamp
- `kopia_snapshot_duration_seconds` - Snapshot duration
- `kopia_repository_size_bytes` - Repository size
- `kopia_server_memory_bytes` - Memory usage
- `up{job="kopia"}` - Server availability

### Grafana Dashboard

Pre-configured dashboard: `config/grafana/provisioning/dashboards/dashboards/kopia-backup-monitoring.json`

**Panels:**
- Snapshot success/failure rate
- Last snapshot age
- Repository size growth
- Backup duration trends
- Error count timeline
- Memory/CPU usage

Access: http://192.168.178.40:3000/d/kopia

### Alertmanager Alerts

Configured in `config/prometheus/alerts.yml`:

| Alert | Condition | Severity | Description |
|-------|-----------|----------|-------------|
| `KopiaBackupFailed` | Errors >0 in 1h | Critical | Backup errors detected |
| `KopiaNoRecentSnapshot` | >24h since snapshot | Warning | No recent backups |
| `KopiaServerDown` | Server unreachable | Critical | Kopia server offline |
| `KopiaHighMemoryUsage` | >60% of 768MB | Warning | Memory pressure |
| `KopiaRepositorySpaceLow` | >90% capacity | Warning | Storage nearly full |
| `KopiaSnapshotDuration` | >1 hour | Warning | Snapshot taking too long |

### Email Notifications

Configure in `.env`:

```bash
ALERT_EMAIL_USER=your-email@gmail.com
ALERT_EMAIL_PASSWORD=your-app-password
ALERT_EMAIL_TO=alerts@example.com
```

Test alerts:

```bash
# Trigger test alert
docker exec alertmanager amtool alert add \
  alertname="TestAlert" \
  severity="info"
```

## Maintenance

### Daily Tasks (Automated)

```bash
# 3:00 AM - Create snapshots
./scripts/kopia/create-snapshots.sh

# Check cron logs
tail -f /mnt/seconddrive/kopia/logs/cron-snapshots.log
```

### Weekly Tasks (Automated)

```bash
# Sundays 4:00 AM - Quick maintenance
./scripts/kopia/maintenance.sh

# Mondays 5:00 AM - Verification
./scripts/verify-kopia-backups.sh

# Check logs
tail -f /mnt/seconddrive/kopia/logs/cron-maintenance.log
tail -f /mnt/seconddrive/kopia/logs/cron-verify.log
```

### Monthly Tasks (Manual)

```bash
# 1st Sunday 4:00 AM - Full maintenance (automated)
FULL_MAINTENANCE=true ./scripts/kopia/maintenance.sh

# Manual full verification
docker exec kopia_server kopia repository verify --full

# Check repository health
docker exec kopia_server kopia repository status

# Review disk space
df -h /mnt/seconddrive
du -sh /mnt/seconddrive/kopia/repository
```

### Quarterly Tasks (Manual)

```bash
# Full disaster recovery test
1. Document current state
2. Restore test data to temporary location
3. Verify restored data integrity
4. Test application recovery (database restore, config import)
5. Update disaster recovery documentation

# Offsite backup sync
1. Connect external USB drive or verify cloud sync
2. Create/update secondary repository
3. Copy latest snapshots to offsite location
```

## Disaster Recovery

### Scenario 1: Restore Single File/Directory

```bash
# List available snapshots
docker exec kopia_server kopia snapshot list --all

# List files in a snapshot
docker exec kopia_server kopia ls <snapshot-id>

# Restore specific path
docker exec kopia_server kopia snapshot restore <snapshot-id> \
  --target=/restore \
  --skip-existing
```

### Scenario 2: Restore Full System

```bash
# 1. Fresh Potato Stack installation
git clone <your-potatostack-repo>
cd potatostack

# 2. Connect to existing repository
docker run --rm -it \
  -v /mnt/seconddrive/kopia:/repository \
  kopia/kopia:latest \
  repository connect filesystem \
  --path=/repository \
  --password="$KOPIA_PASSWORD"

# 3. List and restore latest snapshot
docker exec kopia_server kopia snapshot list --all
docker exec kopia_server kopia snapshot restore <latest-snapshot-id> \
  --target=/restore

# 4. Restore databases
cd /restore/mnt/seconddrive/backups/db
gunzip < nextcloud-db-latest.sql.gz | docker exec -i nextcloud-db mysql -u nextcloud -p nextcloud
gunzip < gitea-db-latest.sql.gz | docker exec -i gitea-db psql -U gitea -d gitea

# 5. Restart services
docker-compose down && docker-compose up -d
```

### Scenario 3: Total Data Loss (Offsite Recovery)

```bash
# 1. Set up new Le Potato with Potato Stack
# 2. Install Kopia client
# 3. Connect to cloud/offsite repository

docker exec kopia_server kopia repository connect b2 \
  --bucket=my-kopia-backups \
  --key-id="$B2_KEY_ID" \
  --key="$B2_APPLICATION_KEY" \
  --password="$KOPIA_PASSWORD"

# 4. Restore from offsite snapshot
docker exec kopia_server kopia snapshot list --all
docker exec kopia_server kopia snapshot restore <snapshot-id> \
  --target=/restore

# 5. Follow Scenario 2 steps 4-5
```

### Recovery Checklist

- [ ] Repository password (`KOPIA_PASSWORD`) stored securely
- [ ] Secondary repository configured (USB/NAS/Cloud)
- [ ] Restore procedure documented
- [ ] Database restore scripts tested
- [ ] Application configuration restore verified
- [ ] Contact information for cloud provider (if used)
- [ ] Encryption keys backed up separately
- [ ] Recovery tested within last 90 days

## Troubleshooting

### Issue: Kopia Container Won't Start

```bash
# Check container logs
docker logs kopia_server

# Common causes:
1. Missing KOPIA_PASSWORD in .env
2. Repository directory permissions (should be writable)
3. Port 51515/51516 already in use

# Fix permissions
sudo chown -R 1000:1000 /mnt/seconddrive/kopia

# Restart container
docker-compose restart kopia
```

### Issue: Snapshots Failing

```bash
# Check Kopia logs
docker exec kopia_server tail -f /app/logs/kopia.log

# Common causes:
1. Disk full (check df -h /mnt/seconddrive)
2. Permission denied (check paths in create-snapshots.sh)
3. Memory exhaustion (check docker stats kopia_server)

# Fix: Increase memory limit in docker-compose.yml
mem_limit: 1g  # Increase from 768m if needed
```

### Issue: High Memory Usage (OOM Kills)

```bash
# Check memory stats
docker stats kopia_server

# Solutions:
1. Reduce parallel operations (already at minimum: 1 snapshot, 2 file reads)
2. Increase GOGC value (more aggressive GC)
   GOGC=25 (default: 50)
3. Split snapshots into smaller chunks
4. Schedule backups when system is idle
```

### Issue: Slow Backup Performance

```bash
# Check bottleneck
1. CPU: top -p $(docker inspect -f '{{.State.Pid}}' kopia_server)
2. Disk I/O: iostat -x 5
3. Network: iftop (if using NAS/cloud)

# Solutions:
1. Already using NO compression (fastest)
2. Increase upload bandwidth limit (if network allows)
   --upload-max-megabytes-per-sec=100
3. Use SSD for repository if possible
4. Enable parallel uploads for larger files
   --parallel-upload-above-size-mib=16
```

### Issue: Repository Corruption

```bash
# Verify repository integrity
docker exec kopia_server kopia repository verify --full

# Repair repository (if needed)
docker exec kopia_server kopia repository repair \
  --repair-damaged-content

# Last resort: Restore from secondary repository
# See multi-repo-example.sh for setup
```

### Issue: Cron Jobs Not Running

```bash
# Check cron status
systemctl status cron  # or 'crond' on some systems

# Verify crontab entries
crontab -l | grep kopia

# Check cron logs
grep CRON /var/log/syslog | grep kopia
tail -f /mnt/seconddrive/kopia/logs/cron-*.log

# Test manual execution
cd /path/to/potatostack
./scripts/kopia/create-snapshots.sh

# Fix: Ensure scripts are executable
chmod +x scripts/kopia/*.sh
```

### Issue: Metrics Not Appearing in Prometheus

```bash
# Check Kopia metrics endpoint
curl http://localhost:51516/metrics

# Check Prometheus scrape config
cat config/prometheus/prometheus.yml | grep -A 5 kopia

# Check Prometheus targets
http://192.168.178.40:9090/targets

# Restart Prometheus if needed
docker-compose restart prometheus
```

## Best Practices

### 1. Security

- ✅ Use strong `KOPIA_PASSWORD` (32+ characters)
- ✅ Store repository password in secure password manager
- ✅ Keep `.env` file out of version control
- ✅ Enable Kopia UI authentication (`KOPIA_SERVER_PASSWORD`)
- ✅ Use TLS for remote repository access
- ✅ Regularly rotate cloud API keys

### 2. Reliability

- ✅ Test restores quarterly (disaster recovery drill)
- ✅ Monitor Prometheus alerts
- ✅ Keep logs for 30 days (automatic rotation)
- ✅ Maintain secondary repository (3-2-1 rule)
- ✅ Verify repository integrity monthly
- ✅ Document recovery procedures

### 3. Performance

- ✅ NO compression (Le Potato optimized)
- ✅ Schedule backups during low-activity periods (3:00 AM)
- ✅ Conservative resource limits (768MB RAM, 2 CPUs)
- ✅ USB 3.0 bandwidth limiting (50 MB/s)
- ✅ Single parallel snapshot (prevents OOM)

### 4. Storage Efficiency

- ✅ Use `.kopiaignore` to exclude unnecessary files
- ✅ GFS retention policy (balances history vs. space)
- ✅ FIXED-4M splitter (good deduplication without compression)
- ✅ Run maintenance weekly (garbage collection)
- ✅ Monitor repository size growth

## Support & Resources

### Official Kopia Documentation
- Website: https://kopia.io
- GitHub: https://github.com/kopia/kopia
- Documentation: https://kopia.io/docs/

### Potato Stack
- Issues: https://github.com/yourusername/potatostack/issues
- Discussions: https://github.com/yourusername/potatostack/discussions

### Quick Reference

```bash
# Start Kopia server
docker-compose up -d kopia

# Create snapshot
./scripts/kopia/create-snapshots.sh

# List snapshots
docker exec kopia_server kopia snapshot list --all

# Repository status
docker exec kopia_server kopia repository status

# Verify backups
./scripts/verify-kopia-backups.sh

# Maintenance
./scripts/kopia/maintenance.sh

# View metrics
curl http://localhost:51516/metrics

# Grafana dashboard
http://192.168.178.40:3000/d/kopia

# Kopia UI
https://192.168.178.40:51515
```

---

**Last Updated:** 2025-12-08
**Version:** 1.0
**Optimized For:** Le Potato (ARM64, 2GB RAM)
