# POTATOSTACK - Phased Deployment Guide for Le Potato (2GB RAM)

## ⚠️ IMPORTANT: Resource Reality Check

Your Le Potato has **2GB RAM + recommended 2GB swap = 4GB total**. This guide uses phased deployment to avoid overwhelming the system.

**Expected RAM Usage:**
- **Phase 1 (Core)**: ~800MB
- **Phase 2 (Storage)**: ~1.2GB total
- **Phase 3 (Monitoring)**: ~1.6GB total
- **Phase 4 (Optional)**: ~2GB+ (tight fit!)

---

## Pre-Deployment Checklist

### 1. Setup Swap (CRITICAL!)
```bash
sudo bash scripts/setup-swap.sh
```

Verify:
```bash
free -h
# Should show 2GB swap
```

### 2. Verify External Storage
```bash
df -h | grep -E "potatostack"
# Should show your mounted ZFS dataset
```

### 3. Create .env File
```bash
cp .env.example .env
nano .env
# Fill in all passwords and credentials
```

### 4. Install Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose (if not included)
sudo apt install docker-compose-plugin -y
```

---

## Phase 1: Core Infrastructure (~800MB)

**Services**: VPN, Databases, Redis, Reverse Proxy

```bash
# Create necessary directories
mkdir -p config/{mariadb/init,prometheus,grafana,nginx-proxy-manager}

# Start core services
docker compose up -d mariadb redis postgres nginx-proxy-manager portainer homepage

# Wait 2 minutes for initialization
sleep 120

# Verify
docker compose ps
docker stats --no-stream

# Check RAM usage
free -h
```

**Expected**: ~800MB used, swap minimal

**Troubleshooting**:
- If MariaDB crashes: Check `docker logs mariadb` - may need to increase `innodb_buffer_pool_size`
- If Redis OOMs: Reduce `maxmemory` to 96MB in docker-compose.yml

---

## Phase 2: Storage & Productivity (~1.2GB total)

**Services**: Nextcloud, Gitea, Kopia

```bash
# Start storage services
docker compose up -d nextcloud gitea kopia

# Wait for Nextcloud to initialize (5 minutes)
sleep 300

# Check status
docker compose ps
free -h

# Access Nextcloud
echo "Nextcloud: http://$(hostname -I | awk '{print $1}'):8082"
```

**Expected**: ~1.2GB used, <500MB swap

**Test**:
- Login to Nextcloud (admin credentials from .env)
- Upload a test file
- Check `docker stats nextcloud` - should be <300MB

---

## Phase 3: Monitoring Stack (~1.6GB total)

**Services**: Prometheus, Grafana, Loki, Exporters

```bash
# Start monitoring
docker compose up -d prometheus grafana loki promtail \
    node-exporter cadvisor smartctl-exporter

# Wait 1 minute
sleep 60

# Check metrics
curl -s http://localhost:9090/api/v1/targets | grep -c "\"health\":\"up\""

# Access Grafana
echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "Default login: admin / (check .env GRAFANA_PASSWORD)"
```

**Expected**: ~1.6GB used, ~500MB swap

**Configure Grafana**:
1. Login to Grafana
2. Navigate to Dashboards → Browse
3. Open "POTATOSTACK Overview" dashboard
4. Verify metrics are flowing

---

## Phase 4: VPN & P2P (~1.8GB total)

**Services**: Gluetun, qBittorrent, slskd

```bash
# Start VPN stack
docker compose up -d gluetun

# Wait for VPN connection (30 seconds)
sleep 30

# Verify VPN
docker compose exec gluetun wget -qO- ifconfig.me
# Should show Surfshark IP, not your real IP

# Start P2P services
docker compose up -d qbittorrent slskd

# Check status
docker compose ps | grep -E "gluetun|qbittorrent|slskd"
```

**Expected**: ~1.8GB used, ~700MB swap

**Test**:
- qBittorrent: http://YOUR_IP:8080 (default: admin/adminadmin)
- slskd: http://YOUR_IP:2234
- Add ONE test torrent, monitor with `docker stats qbittorrent`

---

## Phase 5: Optional Services (USE PROFILES!)

### Option A: Password Manager (~1.9GB total)
```bash
docker compose --profile apps up -d vaultwarden vaultwarden-backup
```

### Option B: Extended Monitoring (~2GB+ total)
```bash
docker compose --profile monitoring-extra up -d \
    netdata uptime-kuma speedtest-exporter fritzbox-exporter blackbox-exporter
```

**⚠️ WARNING**: Do NOT enable `--profile heavy` (Immich/Firefly/Authelia) without 4GB+ RAM!

---

## Monitoring & Maintenance

### Real-Time Monitoring
```bash
# Memory/CPU
watch -n 5 'free -h && echo && docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"'

# Alerts in Grafana
# Navigate to Alerting → Alert Rules
# Configured alerts: >80% RAM, >80% CPU, service down
```

### Daily Checks
```bash
# Container health
docker compose ps

# Disk space
df -h

# Logs (if errors)
docker compose logs --tail=50 <service_name>
```

### Performance Tuning
If services are slow:

1. **Check swap usage**: `free -h` - if swap >1GB, reduce services
2. **Check CPU**: `htop` - if load avg >4, schedule heavy tasks (backups, scans)
3. **Restart heavy services**: `docker compose restart <service>`
4. **Reduce Prometheus retention**: Edit prometheus.yml, change `--storage.tsdb.retention.time=7d`

---

## Rollback / Troubleshooting

### Service Won't Start
```bash
# Check logs
docker compose logs <service_name> --tail=100

# Common fixes:
# - Database not ready: Wait 2 minutes, try again
# - OOM killed: Reduce mem_limit in docker-compose.yml
# - Port conflict: Change port in docker-compose.yml
```

### System Unresponsive
```bash
# SSH may lag - be patient
# Check load average
cat /proc/loadavg
# If >10, kill heavy service:
docker compose stop immich-server  # or qbittorrent, etc.

# Reboot if frozen
sudo reboot
```

### Reset Everything
```bash
# DANGER: Deletes all containers (not volumes)
docker compose down
docker system prune -af
# Re-deploy from Phase 1
```

---

## Success Criteria

After full deployment:
- [ ] All Phase 1-4 services show "healthy" or "running"
- [ ] Grafana dashboards show metrics
- [ ] RAM usage <2GB (check `free -h`)
- [ ] Swap usage <1GB
- [ ] Load average <3 (check `uptime`)
- [ ] Can access Nextcloud, Grafana, qBittorrent via web UI
- [ ] VPN shows external IP via `docker compose exec gluetun curl ifconfig.me`

**If any fails, stop at that phase and debug before continuing!**

---

## Performance Expectations

**Acceptable**:
- Nextcloud: 2-5 second page loads
- qBittorrent: 5-10 torrents at 50MB/s combined
- Grafana: Dashboards render in 2-3 seconds
- Kopia: Backups run without crashing (may be slow)

**Concerning (need to scale back)**:
- SSH lag >5 seconds
- Swap usage >1.5GB sustained
- Load average >6 for >10 minutes
- Services randomly restarting (OOM kills)

**Good luck! Monitor closely for the first 48 hours.**
