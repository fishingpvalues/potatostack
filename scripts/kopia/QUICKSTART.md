# Kopia Quick Start Guide - Potato Stack

## 5-Minute Setup

### Step 1: Configure Policies (NO Compression for Le Potato)

```bash
cd /path/to/potatostack
./scripts/kopia/setup-policies.sh
```

**What it does:**
- ✅ Disables compression (saves CPU on ARM64)
- ✅ Sets GFS retention (7 latest, 14 daily, 8 weekly, 12 monthly, 3 annual)
- ✅ Configures Le Potato-optimized performance limits
- ✅ Enables error handling (continues on permission errors)

### Step 2: Create First Backup

```bash
./scripts/kopia/create-snapshots.sh
```

**What it backs up:**
- Nextcloud data, Gitea repos, qBittorrent/slskd configs
- Database dumps (MariaDB, PostgreSQL)
- Vaultwarden backups
- Docker configs and compose files
- All Potato Stack scripts

### Step 3: Automate Backups

```bash
./scripts/kopia/setup-scheduling.sh
# Choose option 1: RECOMMENDED
```

**Schedule (Recommended):**
- 🕒 3:00 AM - Daily snapshots
- 🕓 4:00 AM - Weekly maintenance (Sundays)
- 🕔 5:00 AM - Weekly verification (Mondays)

### Step 4: Verify Everything Works

```bash
./scripts/verify-kopia-backups.sh
```

**Checks:**
- ✅ Kopia server running
- ✅ Repository accessible
- ✅ Snapshots exist
- ✅ Metrics available
- ✅ No errors

---

## Daily Operations

### Check Backup Status

```bash
# List recent snapshots
docker exec kopia_server kopia snapshot list --all --max-results=10

# Repository size and stats
docker exec kopia_server kopia repository status

# Check last backup time
docker exec kopia_server kopia snapshot list --all | head -5
```

### Manual Backup Now

```bash
# Full backup of all critical data
./scripts/kopia/create-snapshots.sh

# Backup specific path
docker exec kopia_server kopia snapshot create /host/mnt/seconddrive/nextcloud
```

### View Logs

```bash
# Today's snapshot log
tail -f /mnt/seconddrive/kopia/logs/snapshots-$(date +%Y-%m-%d).log

# Cron backup logs
tail -f /mnt/seconddrive/kopia/logs/cron-snapshots.log

# Kopia server log
docker exec kopia_server tail -f /app/logs/kopia.log
```

### Monitor in Grafana

```bash
# Open Kopia dashboard
xdg-open http://192.168.178.40:3000/d/kopia

# Or visit directly:
# http://192.168.178.40:3000
```

---

## Weekly Maintenance

### Run Maintenance (Manual)

```bash
# Quick maintenance (~10 minutes)
./scripts/kopia/maintenance.sh

# Full maintenance (~1 hour, monthly)
FULL_MAINTENANCE=true ./scripts/kopia/maintenance.sh
```

**What it does:**
- Applies retention policies (deletes old snapshots)
- Runs garbage collection
- Verifies repository integrity
- Cleans up old logs (>30 days)
- Reports disk space usage

### Verify Backups

```bash
./scripts/verify-kopia-backups.sh
```

---

## Disaster Recovery

### Restore Single File

```bash
# 1. Find the snapshot
docker exec kopia_server kopia snapshot list --all

# 2. Browse snapshot contents
docker exec kopia_server kopia ls <snapshot-id>:<path>

# 3. Restore specific file/directory
docker exec kopia_server kopia snapshot restore <snapshot-id>:<path> \
  --target=/restore \
  --skip-existing

# 4. Copy restored file to desired location
cp /restore/path/to/file /final/destination
```

### Restore Full System

```bash
# 1. Connect to repository
docker run --rm -it \
  -v /mnt/seconddrive/kopia:/repository \
  kopia/kopia:latest \
  repository connect filesystem \
  --path=/repository \
  --password="$KOPIA_PASSWORD"

# 2. List available snapshots
docker exec kopia_server kopia snapshot list --all

# 3. Restore latest full snapshot
docker exec kopia_server kopia snapshot restore <latest-snapshot-id> \
  --target=/restore \
  --skip-existing

# 4. Restore databases from dumps
cd /restore/mnt/seconddrive/backups/db

# Nextcloud
gunzip < nextcloud-db-latest.sql.gz | \
  docker exec -i nextcloud-db mysql -u nextcloud -pYOUR_PASSWORD nextcloud

# Gitea
gunzip < gitea-db-latest.sql.gz | \
  docker exec -i gitea-db psql -U gitea -d gitea

# Firefly
gunzip < firefly-db-latest.sql.gz | \
  docker exec -i firefly-db mysql -u firefly -pYOUR_PASSWORD firefly

# 5. Restart services
docker-compose down && docker-compose up -d
```

---

## Monitoring & Alerts

### Check Prometheus Metrics

```bash
# View all Kopia metrics
curl http://localhost:51516/metrics | grep kopia_

# Last snapshot time
curl -s http://localhost:51516/metrics | grep kopia_snapshot_manager_last_snapshot_time

# Error count
curl -s http://localhost:51516/metrics | grep kopia_snapshot_manager_errors_total
```

### Active Alerts

```bash
# Check Prometheus alerts
xdg-open http://192.168.178.40:9090/alerts

# Check Alertmanager
xdg-open http://192.168.178.40:9093
```

### Email Notification Setup

Edit `.env`:
```bash
ALERT_EMAIL_USER=your-email@gmail.com
ALERT_EMAIL_PASSWORD=your-app-password
ALERT_EMAIL_TO=alerts@example.com
```

Restart Alertmanager:
```bash
docker-compose restart alertmanager
```

---

## Troubleshooting

### Kopia Server Won't Start

```bash
# Check logs
docker logs kopia_server

# Common fixes:
sudo chown -R 1000:1000 /mnt/seconddrive/kopia
docker-compose restart kopia
```

### Snapshot Failed

```bash
# Check disk space
df -h /mnt/seconddrive

# Check memory
docker stats kopia_server

# View detailed error
docker exec kopia_server tail -50 /app/logs/kopia.log
```

### Cron Not Running

```bash
# Check crontab
crontab -l | grep kopia

# Check system cron logs
grep CRON /var/log/syslog | grep kopia

# Test manual run
cd /path/to/potatostack
./scripts/kopia/create-snapshots.sh
```

### Repository Integrity Issues

```bash
# Quick verify
docker exec kopia_server kopia repository verify \
  --file-parallelism=2 \
  --max-errors=10

# Full verify (slow)
docker exec kopia_server kopia repository verify --full

# Repair (if needed)
docker exec kopia_server kopia repository repair --repair-damaged-content
```

---

## Important Paths

| Description | Path |
|-------------|------|
| Repository | `/mnt/seconddrive/kopia/repository` |
| Config | `/mnt/seconddrive/kopia/config` |
| Cache | `/mnt/seconddrive/kopia/cache` |
| Logs | `/mnt/seconddrive/kopia/logs` |
| Snapshots script | `./scripts/kopia/create-snapshots.sh` |
| Maintenance script | `./scripts/kopia/maintenance.sh` |
| Verify script | `./scripts/verify-kopia-backups.sh` |
| Policies script | `./scripts/kopia/setup-policies.sh` |
| Scheduling script | `./scripts/kopia/setup-scheduling.sh` |

---

## Key Settings (Le Potato Optimized)

| Setting | Value | Reason |
|---------|-------|--------|
| Compression | **NONE** | Save ARM64 CPU cycles |
| Memory Limit | 768 MB | Avoid OOM on 2GB RAM |
| Parallel Snapshots | 1 | Prevent memory exhaustion |
| Parallel File Reads | 2 | Balance speed vs. RAM |
| Upload Limit | 50 MB/s | USB 3.0 safe bandwidth |
| Splitter | FIXED-4M | Good dedup without compression |
| Retention (Daily) | 14 days | Balance history vs. space |
| Retention (Weekly) | 8 weeks | ~2 months history |
| Retention (Monthly) | 12 months | 1 year history |

---

## Getting Help

1. **Check logs first:**
   ```bash
   docker logs kopia_server
   tail -50 /mnt/seconddrive/kopia/logs/kopia.log
   ```

2. **Run verification:**
   ```bash
   ./scripts/verify-kopia-backups.sh
   ```

3. **Review full documentation:**
   ```bash
   cat scripts/kopia/README.md
   ```

4. **Kopia Official Docs:**
   https://kopia.io/docs/

5. **Open an issue:**
   https://github.com/yourusername/potatostack/issues

---

**Pro Tip:** Bookmark this page and the Grafana dashboard for quick access!

📊 Grafana: http://192.168.178.40:3000/d/kopia
🖥️ Kopia UI: https://192.168.178.40:51515
📈 Prometheus: http://192.168.178.40:9090
