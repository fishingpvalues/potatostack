# PotatoStack Quick Start Guide

## Pre-Installation Checklist

- [ ] Le Potato SBC with Armbian installed
- [ ] Two HDDs mounted at `/mnt/seconddrive` and `/mnt/cachehdd`
- [ ] Docker and Docker Compose installed
- [ ] VPN account credentials (Surfshark, NordVPN, ProtonVPN, or any Gluetun-supported provider)
- [ ] Email account for alerts (Gmail recommended)

## 5-Minute Setup

```bash
# 1. Clone/download PotatoStack files to your Le Potato
cd ~/
git clone <your-repo> potatostack  # or download and extract
cd potatostack

# 2. Run automated setup
sudo chmod +x setup.sh
sudo ./setup.sh

# 3. Edit environment variables (CRITICAL!)
nano .env
# Fill in ALL passwords and credentials
# Save: Ctrl+O, Enter, Ctrl+X

# 4. Start the stack
docker-compose up -d

# 5. Check everything is running
docker-compose ps
```

## Essential First Steps (30 minutes)

### 1. Access Homepage Dashboard
http://192.168.178.40:3003

This is your central hub for all services.

### 2. Secure Nginx Proxy Manager
1. Go to http://192.168.178.40:81
2. Login: admin@example.com / changeme
3. **Immediately change password!**
4. Settings → Users → Edit admin
5. Enable 2FA

### 3. Configure Grafana Monitoring
1. Go to http://192.168.178.40:3000
2. Login with credentials from .env
3. Import dashboards:
   - Click + → Import
   - Enter ID: **1860** (Node Exporter) → Load → Prometheus → Import
   - Repeat for: **193** (Docker), **20204** (SMART HDD)

### 4. Set Up qBittorrent
1. Go to http://192.168.178.40:8080
2. Login: admin / adminadmin
3. **Change password**: Tools → Options → Web UI
4. Test VPN: Tools → Execution Log
   - Should show VPN provider's IP, not your real IP

### 5. Configure Nextcloud
1. Go to http://192.168.178.40:8082
2. Login with credentials from .env
3. Install recommended apps
4. Settings → Security → Enable 2FA
5. Download apps for your devices: https://nextcloud.com/install/#install-clients

### 6. Connect Kopia Clients
1. Download Kopia: https://kopia.io/docs/installation/
2. Repository → Connect to Repository
   - Server: `https://192.168.178.40:51515`
   - Username: admin (or from .env)
   - Password: From .env KOPIA_SERVER_PASSWORD
   - Accept certificate fingerprint
3. Create snapshot policies

## Verify Everything Works

### Check VPN Killswitch
```bash
# All should show Surfshark IP (not your real IP)
docker exec surfshark curl -s https://ipinfo.io/ip
docker exec qbittorrent curl -s https://ipinfo.io/ip
```

### Check Monitoring
1. Grafana → Node Exporter dashboard
   - Should see CPU, RAM, disk metrics
2. Prometheus → Status → Targets (http://192.168.178.40:9090/targets)
   - All should be "UP" (green)

### Check Backups
```bash
docker logs kopia_server | tail -20
# Should show "Server started" with no errors
```

### Check Containers
```bash
docker-compose ps
# All should be "Up" or "Up (healthy)"
```

## Common Issues & Quick Fixes

### VPN not connecting
```bash
# Check credentials
nano .env  # Verify SURFSHARK_USER and SURFSHARK_PASSWORD

# Try different server
# Edit docker-compose.yml → surfshark → environment
# Change: SURFSHARK_COUNTRY=de (or us, uk, nl)

docker-compose restart surfshark
```

### Out of memory errors
```bash
# Check what's using memory
docker stats

# Restart problematic service
docker-compose restart [service_name]

# If persistent, reduce limits in docker-compose.yml
```

### Can't access services
```bash
# Check if ports are listening
sudo netstat -tlnp | grep -E "3003|8080|51515"

# Check firewall
sudo ufw status
# If active, allow required ports:
sudo ufw allow from 192.168.178.0/24
```

### Kopia "repository not found"
```bash
# Initialize repository (one-time)
docker run --rm \
  -e KOPIA_PASSWORD="your_password" \
  -v /mnt/seconddrive/kopia/repository:/repository \
  -v /mnt/seconddrive/kopia/config:/app/config \
  -v /mnt/seconddrive/kopia/cache:/app/cache \
  kopia/kopia:latest \
  repository create filesystem --path=/repository

# Then restart Kopia
docker-compose restart kopia
```

## Daily Usage

### Download a torrent
1. Homepage → qBittorrent → Add torrent
2. Select category (pr0n/music/tv-shows/movies)
3. Files auto-organize to /mnt/cachehdd/torrents/[category]
4. Access via Nextcloud → External Storage → torrents

### Check system health
1. Homepage → Grafana → Node Exporter dashboard
2. Check SMART dashboard for HDD temperature
3. Uptime Kuma → All services should be green

### View logs
1. Homepage → Dozzle
2. Select container → real-time logs
3. Or: Grafana → Loki dashboard → filter by container

### Update containers
Diun notifies you of available updates. Review Renovate PRs or update manually:
```bash
# Check Diun logs for available updates
docker logs diun

# Manual update (apply after reviewing changes)
docker-compose pull
docker-compose up -d
```

## Remote Access (via WireGuard)

### Set up on Fritzbox
1. Internet → Permit Access → VPN → Add WireGuard connection
2. Create connection for each device (phone, laptop, etc.)
3. Download config file

### On your devices
1. Install WireGuard app
2. Import config file
3. Connect to VPN
4. Access services via http://192.168.178.40:[port]

### Test remote access
1. Turn off WiFi (use mobile data)
2. Connect WireGuard VPN
3. Access http://192.168.178.40:3003
4. Should see Homepage dashboard

## Maintenance Schedule

### Weekly (5 minutes)
- Check Homepage → all services green
- Grafana → verify no alerts
- Uptime Kuma → check uptime percentages

### Monthly (30 minutes)
- Review disk space in Grafana
- Check SMART data for HDD health
- Test Kopia restore (pick random file)
- Backup configs:
  ```bash
  tar -czf backup-$(date +%Y%m%d).tar.gz docker-compose.yml .env config/
  ```

## Getting Help

### View service logs
```bash
docker logs [container_name]
docker logs kopia_server
docker logs surfshark
```

### Check resource usage
```bash
docker stats
# Shows real-time CPU/RAM per container
```

### Restart everything
```bash
docker-compose restart
```

### Nuclear option (reset everything)
```bash
docker-compose down
docker-compose up -d
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Main stack definition |
| `.env` | **Passwords and secrets - NEVER commit!** |
| `setup.sh` | Automated installation script |
| `README.md` | Complete documentation |
| `config/prometheus/alerts.yml` | Alert rules |
| `config/alertmanager/config.yml` | Notification settings |
| `config/homepage/*.yaml` | Dashboard configuration |

## URLs Bookmark List

Save these in your browser:

```
Homepage:     http://192.168.178.40:3003
Grafana:      http://192.168.178.40:3000
qBittorrent:  http://192.168.178.40:8080
Nextcloud:    http://192.168.178.40:8082
Kopia:        https://192.168.178.40:51515
Portainer:    http://192.168.178.40:9000
NPM:          http://192.168.178.40:81
Dozzle:       http://192.168.178.40:8083
```

---

**You're all set! Your Le Potato is now a powerful self-hosted server.**

For detailed documentation, see README.md
