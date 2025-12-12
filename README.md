# PotatoStack v2.1 - Complete Self-Hosted Stack for Le Potato SBC

A fully integrated, state-of-the-art Docker stack optimized for the Le Potato single-board computer, featuring P2P file sharing, encrypted backups, comprehensive monitoring, and file sync.

> **Latest (2025-12-12)**: Database consolidation saves 352MB RAM! Seafile now uses PostgreSQL+Redis. All databases optimized for 2GB RAM systems. See `DATABASE-CONSOLIDATION.txt` for details.

## Overview

PotatoStack is designed specifically for the Le Potato (AML-S905X-CC) with its limited resources (2GB RAM, quad-core ARM Cortex-A53). Every service is carefully tuned for stability and performance on this hardware.

### What's Included

#### 🌐 VPN & P2P
- **Gluetun VPN** with killswitch protection (supports Surfshark, NordVPN, ProtonVPN, and 60+ providers)
- **qBittorrent** for torrents (through VPN only)
- **slskd (Soulseek)** for P2P file sharing (through VPN only)

#### 💾 Storage & Backup
- **Kopia** - Encrypted, deduplicated backups with web UI
- **Seafile** - Lightweight file sync & share (Nextcloud alternative)
- **Filebrowser** - Web file manager
- **SFTP + Samba** - Remote file access and LAN streaming

#### 📊 Monitoring Stack
- **Prometheus** - Metrics collection
- **Grafana** - Beautiful dashboards
- **Loki** - Log aggregation
- **Alertmanager** - Email/Telegram/Slack alerts
- **Netdata** ⭐ NEW - Real-time monitoring with auto-discovery
- **node-exporter** - System metrics (CPU, RAM, disk, network)
- **cAdvisor** - Container metrics
- **smartctl-exporter** - HDD health monitoring (SMART data)

#### 🛠️ Management Tools
- **Portainer CE** - Docker GUI management
- **Diun** - Docker image update notifications (safer than auto-updates)
- **Uptime Kuma** - Service uptime monitoring
- **Dozzle** - Real-time log viewer
- **Homepage** - Unified dashboard for all services

#### 🔐 Infrastructure & Security
- **Nginx Proxy Manager** - Reverse proxy with Let's Encrypt SSL
- **Authelia** - Single Sign-On (SSO) with 2FA support
- **Vaultwarden** - Password manager (Bitwarden-compatible)
- **Gitea** - Self-hosted Git server
- **PostgreSQL** - Unified database (Gitea, Immich, Seafile)
- **Redis** - Shared cache (Gitea, Immich, Seafile, Authelia)
- **Immich** - Self-hosted Google Photos alternative

## Hardware Requirements

### Le Potato Specifications
- CPU: Quad-core ARM Cortex-A53 @ 1.416GHz
- RAM: 2GB DDR3
- Architecture: ARM64
- Power: ~4W under load

### Storage Requirements
1. **Main HDD** (mounted at `/mnt/seconddrive`):
   - Sized for long‑term data: 14TB in the reference setup
   - Stores: Kopia backups, shared files, configs, Gitea repos

2. **Cache HDD** (mounted at `/mnt/cachehdd`):
   - High‑IO cache disk: 500GB in the reference setup
   - Stores: Active torrents, Soulseek downloads
   - Used for intelligent caching of frequently accessed files

## Quick Start

### Prerequisites

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo apt install docker-compose

# Mount your HDDs (adjust device names)
sudo mkdir -p /mnt/seconddrive /mnt/cachehdd
# Add to /etc/fstab for permanent mounting:
# UUID=your-uuid-here /mnt/seconddrive ext4 defaults 0 2
# UUID=your-uuid-here /mnt/cachehdd ext4 defaults 0 2
```

### Installation

```bash
# Clone or download the PotatoStack files
cd ~/potatostack

# Option A: One-liner install via Makefile (recommended)
make env && sudo make install

# Option B: Run the automated setup script
sudo ./setup.sh

# Or manual setup:
cp .env.example .env
nano .env  # Fill in your passwords and credentials
          # HOST_BIND is pre-set to 192.168.178.40 for security
          # Change if your Le Potato has a different LAN IP

# Create directory structure
./setup.sh  # Handles this automatically

# Initialize Kopia repository (first time only)
docker run --rm \
  -e KOPIA_PASSWORD="your_strong_password" \
  -v /mnt/seconddrive/kopia/repository:/repository \
  -v /mnt/seconddrive/kopia/config:/app/config \
  -v /mnt/seconddrive/kopia/cache:/app/cache \
  kopia/kopia:latest \
  repository create filesystem --path=/repository

# Start the stack
docker-compose up -d   # or: docker compose up -d

# Check status
docker-compose ps      # or: docker compose ps
docker-compose logs -f # or: docker compose logs -f
```

Local IP and access

- Configure `HOST_ADDR` in `.env` (default: `192.168.178.40`) to match your Le Potato’s LAN IP. Homepage links use this.
- Optionally limit bindings by setting `HOST_BIND` (default `0.0.0.0`) to your LAN IP to avoid exposing ports on all interfaces.
- Expose services externally only via Nginx Proxy Manager with HTTPS and auth.

## Service Access

| Service | URL | Default Port |
|---------|-----|--------------|
| Homepage Dashboard | http://192.168.178.40:3003 | 3003 |
| Grafana | http://192.168.178.40:3000 | 3000 |
| Prometheus | http://192.168.178.40:9090 | 9090 |
| qBittorrent | http://192.168.178.40:8080 | 8080 |
| slskd (Soulseek) | http://192.168.178.40:2234 | 2234 |
| Kopia | https://192.168.178.40:51515 | 51515 |
| Seafile | http://192.168.178.40:8001 | 8001 |
| Immich | http://192.168.178.40:2283 | 2283 |
| Gitea | http://192.168.178.40:3001 | 3001 |
| Authelia SSO | http://192.168.178.40:9091 | 9091 |
| Vaultwarden | http://192.168.178.40:8084 | 8084 |
| Filebrowser | http://192.168.178.40:8087 | 8087 |
| SFTP (SSH) | sftp://192.168.178.40:2223 | 2223 |
| Samba (SMB) | smb://192.168.178.40 | 445 |
| Nginx Proxy Manager | http://192.168.178.40:81 | 81 |
| Portainer | http://192.168.178.40:9000 | 9000 |
| Uptime Kuma | http://192.168.178.40:3002 | 3002 |
| Dozzle | http://192.168.178.40:8083 | 8083 |
| Alertmanager | http://192.168.178.40:9093 | 9093 |

### Default Credentials

**IMPORTANT**: Change these immediately after first login!

- **Nginx Proxy Manager**: admin@example.com / changeme
- **Portainer**: Set on first login
- **Grafana**: admin / (from your .env GRAFANA_PASSWORD)
- **qBittorrent**: admin / adminadmin
- **Kopia**: admin / (from your .env KOPIA_SERVER_PASSWORD)
  (Filebrowser/SFTP/Samba set per your configuration)

## Post-Installation Configuration

### 1. Configure Nginx Proxy Manager

1. Login at http://192.168.178.40:81
2. Change default credentials
3. Add SSL certificates (Let's Encrypt)
4. Create proxy hosts for each service
5. Enable 2FA in settings

### Security Notes

- Change all default passwords (NPM, Grafana, qBittorrent, slskd) and enable 2FA where available.
- Keep Prometheus and other admin UIs accessible only on LAN or behind NPM auth.
- Consider setting `HOST_BIND` in `.env` to your LAN IP to avoid binding to all interfaces.

### USB 2.0 & I/O Tips (Le Potato)

- Prefer sequential I/O: keep active downloads on `/mnt/cachehdd` (already set) and schedule Kopia backups during off‑hours.
- Lower monitoring churn: default scrape interval is 30s and log retention 14d; adjust via `.env` (`PROMETHEUS_RETENTION_DAYS`, `LOKI_RETENTION_DAYS`).
- Log limits applied to all services to reduce SD/HDD wear; consider disabling chatty debug logs inside apps.
- Optional: enable ZRAM swap to reduce HDD I/O:
  - `sudo ./scripts/setup-zram.sh` (installs zram-tools; adds ~512MB compressed swap)
- Optional: USB I/O tuning:
  - `sudo ./scripts/usb-io-tuning.sh` (temporary) or `sudo ./scripts/usb-io-tuning.sh --persist` (udev rule)

### File Access

- Web: Filebrowser (`http://<ip>:8087`)
- SFTP: `sftp -P 2223 files@<ip>` (add your public key to `config/ssh/authorized_keys`)
- SMB: `\\\\<ip>\\seconddrive` (use your Samba user/password)

### 2. Set Up Monitoring Dashboards

Import these Grafana dashboards (ID from grafana.com):

```bash
# In Grafana UI: + → Import Dashboard → Enter ID

1860   # Node Exporter Full
193    # Docker Container Monitoring
20204  # SMART HDD Monitoring
22604  # SMARTctl Exporter Dashboard
11074  # Node Exporter for Prometheus
13639  # Loki Dashboard
```

### 3. Configure Alertmanager

Edit `config/alertmanager/config.yml` to add your notification channels:

```yaml
# For Gmail alerts (already configured in template)
# Enable "App Passwords" in Google Account settings

# For Telegram:
- name: 'telegram'
  telegram_configs:
    - bot_token: 'YOUR_BOT_TOKEN'
      chat_id: YOUR_CHAT_ID

# For Discord:
- name: 'discord'
  discord_configs:
    - webhook_url: 'YOUR_WEBHOOK_URL'
```

### 4. Set Up Kopia Clients

On your other devices (Windows/Mac/Linux/Android/iOS):

1. Download Kopia from https://kopia.io/docs/installation/
2. Connect to repository:
   - Server URL: `https://192.168.178.40:51515`
   - Username: `admin` (or as configured)
   - Password: Your KOPIA_SERVER_PASSWORD
   - Accept self-signed certificate fingerprint
3. Create backup policies and schedules

### 5. Configure Seafile

1. Access http://192.168.178.40:8001
2. Create admin account on first login
3. Create libraries for organization
4. Install desktop/mobile clients: https://www.seafile.com/en/download/
5. Enable 2FA: Settings → Password & Security → Two-Factor Authentication

### 6. Configure Immich (Google Photos Alternative)

1. Access http://192.168.178.40:2283
2. Create admin account
3. Install mobile apps (iOS/Android): https://immich.app/docs/install/mobile
4. Configure upload settings and libraries

### 7. Set Up WireGuard VPN (Fritzbox)

For secure external access:

1. Enable WireGuard on Fritzbox
2. Create VPN profiles for each device
3. Configure firewall rules to allow only VPN IPs
4. Update .env with VPN IP ranges if needed

### 7. Configure qBittorrent

1. Login at http://192.168.178.40:8080
2. Change default password
3. Set download paths:
   - Default: `/downloads`
   - Incomplete: `/incomplete`
4. Enable categories for auto-organization:
   - pr0n → /downloads/pr0n
   - music → /downloads/music
   - tv-shows → /downloads/tv-shows
   - movies → /downloads/movies

### 8. Configure slskd (Soulseek)

1. Access http://192.168.178.40:2234
2. Login with your Soulseek credentials
3. Set shared folders: `/var/slskd/shared`
4. Configure download folder: `/var/slskd/incomplete`

## Architecture

### Network Layout

```
┌─────────────────────────────────────────────────────────┐
│                    Internet                              │
└──────────────────┬──────────────────────────────────────┘
                   │
            ┌──────▼──────┐
            │  Fritzbox   │
            │  Router     │
            └──────┬──────┘
                   │ 192.168.178.0/24
                   │
        ┌──────────▼───────────┐
        │    Le Potato SBC     │
        │  192.168.178.40      │
        └──────────┬───────────┘
                   │
    ┌──────────────┼──────────────┐
    │              │              │
┌───▼────┐  ┌─────▼─────┐  ┌────▼─────┐
│  VPN   │  │ Proxy     │  │ Monitor  │
│ Network│  │ Network   │  │ Network  │
└───┬────┘  └─────┬─────┘  └────┬─────┘
    │             │              │
┌───▼──────┐  ┌──▼────────┐ ┌───▼──────┐
│qBittorrent│ │Nginx PM   │ │Prometheus│
│slskd      │ │Homepage   │ │Grafana   │
└───────────┘ │Seafile    │ │Loki      │
              └───────────┘ └──────────┘
```

### Volume Layout

```
/mnt/seconddrive/          # Main HDD (14TB)
├── kopia/                 # Backup repository
│   ├── repository/        # Encrypted backup data
│   ├── config/            # Kopia configuration
│   ├── cache/             # Metadata cache
│   └── logs/              # Detailed logs
├── seafile/               # File sync & share data
├── immich/                # Photo & video library
├── gitea/                 # Git repositories
├── backups/               # Database & service backups
│   ├── db/                # PostgreSQL dumps
│   └── vaultwarden/       # Vaultwarden backups
├── qbittorrent/config/    # qBittorrent configuration
├── slskd/                 # Soulseek configuration & logs
└── uptime-kuma/           # Monitoring data

/mnt/cachehdd/             # Cache HDD (500GB)
├── torrents/              # Active downloads
│   ├── incomplete/        # In-progress
│   ├── music/            # Completed (category)
│   ├── tv-shows/         # Completed (category)
│   └── movies/           # Completed (category)
└── soulseek/             # Soulseek downloads
    ├── incomplete/        # In-progress
    ├── music/
    ├── tv-shows/
    └── movies/
```

## Resource Management

The stack is highly optimized for Le Potato's 2GB RAM with database consolidation:

| Service | RAM Limit | CPU Limit | Notes |
|---------|-----------|-----------|-------|
| **Database Layer** | | | |
| PostgreSQL | 192MB | 1.0 | Shared: Gitea, Immich, Seafile |
| Redis | 64MB | 0.5 | Shared cache for 4+ services |
| **Core Services** | | | |
| Gluetun VPN | 128MB | 1.0 | Universal VPN client |
| qBittorrent | 384MB | 1.5 | Torrent client |
| slskd | 256MB | 1.0 | Soulseek P2P |
| Kopia | 384MB | 1.5 | Backup server |
| Seafile | 384MB | 1.0 | File sync & share |
| Immich Server | 512MB | 1.5 | Photo management |
| **Monitoring** | | | |
| Prometheus | 192MB | 0.75 | Metrics collection |
| Grafana | 128MB | 0.75 | Dashboards |
| **Management** | | | |
| Portainer | 128MB | 0.5 | Docker GUI |
| Homepage | 192MB | 0.75 | Unified dashboard |
| All others | 64-128MB | 0.25-0.5 | Various |

**Database Consolidation Savings**: -352MB (-58% database memory)
**Total estimated usage**: ~1.4GB RAM under normal load, ~300MB free for burst operations

## Monitoring & Alerts

### Available Metrics

- **System**: CPU, RAM, disk usage, disk I/O, network traffic
- **SMART**: HDD temperature, reallocated sectors, power-on hours, health status
- **Containers**: Per-container CPU/RAM/network usage
- **Kopia**: Backup success/failure, snapshot counts, repository size
- **VPN**: Connection status, IP leak detection

### Alert Rules

Pre-configured alerts (edit `config/prometheus/alerts.yml`):

- High memory usage (>85% for 5min)
- High CPU usage (>80% for 5min)
- Low disk space (<10% free)
- High disk I/O (>80% utilization)
- SMART failures or warnings
- High HDD temperature (>45°C)
- Reallocated sectors detected
- Kopia backup failures
- VPN connection drops
- Container crashes

## Security Best Practices

1. **Change all default passwords** in `.env` file
2. **Enable 2FA** on all services that support it (Authelia, Vaultwarden, NPM, Portainer)
3. **Use strong passwords** - generate with `openssl rand -base64 32`
4. **Restrict VPN access** - Only allow known IPs through Fritzbox firewall
5. **Use HTTPS** - Configure SSL certificates in Nginx Proxy Manager
6. **Regular updates** - Diun notifies you; use Renovate PRs for safe updates
7. **Backup your backups** - Kopia repository to external/cloud storage
8. **Monitor logs** - Check Dozzle and Loki regularly

## Maintenance

### Daily
- Check Homepage dashboard for service status
- Review Grafana for anomalies

### Weekly
- Review Uptime Kuma for downtime incidents
- Check Dozzle logs for errors
- Verify Kopia backups are running

### Monthly
- Review Diun notifications and apply updates via Renovate PRs
- Review disk space on both HDDs
- Check SMART data for HDD health
- Test backup restoration from Kopia
- Review and prune old logs

### Commands

```bash
# View logs
docker-compose logs -f [service_name]

# Restart service
docker-compose restart [service_name]

# Update all containers
docker-compose pull
docker-compose up -d

# Check resource usage
docker stats

# Backup docker-compose and configs
tar -czf potatostack-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env config/

# Stop everything
docker-compose down

# Stop and remove all data (CAREFUL!)
docker-compose down -v
```

## Troubleshooting

### VPN Issues

**Problem**: P2P traffic not going through VPN

```bash
# Check VPN connection
docker exec surfshark curl https://ipinfo.io/ip

# Should show Surfshark IP, not your real IP
# Check qBittorrent is using VPN
docker exec qbittorrent curl https://ipinfo.io/ip
```

**Problem**: VPN keeps disconnecting

- Check Surfshark credentials in `.env`
- Try different server location
- Switch between OpenVPN and WireGuard

### Kopia Issues

**Problem**: Can't connect to Kopia server

```bash
# Check if container is running
docker ps | grep kopia

# View logs
docker logs kopia_server

# Verify repository
docker exec kopia_server kopia repository status
```

**Problem**: Out of memory during backup

- Reduce `GOMAXPROCS` to 1 in docker-compose.yml
- Increase `GOGC` to 75 or 100
- Schedule backups during low-activity hours

### Seafile/Immich Issues

**Problem**: Slow upload/download performance

- Check available RAM: `free -h`
- Check PostgreSQL health: `docker logs postgres | grep -i error`
- Check Redis connections: `docker exec redis redis-cli INFO`
- Verify disk I/O: `docker stats`

### Monitoring Issues

**Problem**: Grafana dashboards show no data

```bash
# Check if Prometheus is scraping
docker logs prometheus

# Verify targets are up
# Open http://192.168.178.40:9090/targets
```

**Problem**: Alerts not being sent

- Check Alertmanager configuration
- Verify email credentials (Gmail app password)
- Check logs: `docker logs alertmanager`

## Mobile Apps

### iOS
- **Immich**: Official app from App Store (photo backup & management)
- **Seafile**: Official app from App Store (file sync & share)
- **Vaultwarden**: Bitwarden app from App Store
- **Kopia**: Use web interface (Safari)
- **Grafana**: Official app from App Store
- **Homepage**: Progressive Web App (add to home screen)
- **WireGuard**: Official app for VPN access

### Android
- **Immich**: Official app from Play Store (photo backup & management)
- **Seafile**: Official app from Play Store (file sync & share)
- **Vaultwarden**: Bitwarden app from Play Store
- **Kopia**: Use web interface (Chrome)
- **Grafana**: Official app from Play Store
- **Homepage**: Progressive Web App
- **WireGuard**: Official app for VPN access
- **Termux**: SSH access to Le Potato

## Advanced Customization

### Adding Custom Dashboards

Place dashboard JSON in `config/grafana/provisioning/dashboards/` - they'll auto-import on restart.

### Custom Alertmanager Routes

Edit `config/alertmanager/config.yml` to route specific alerts to different receivers.

### Adding Services

1. Add service to `docker-compose.yml`
2. Add to appropriate network
3. Set resource limits
4. Add Homepage labels in `docker-compose.yml` (auto-discovery)
5. Add Prometheus scrape config if needed
6. Create alert rules in `config/prometheus/alerts.yml`

## FAQ

**Q: Can I run this on other SBCs?**
A: Yes! Works on Raspberry Pi 4, Odroid, etc. Adjust resource limits accordingly.

**Q: How much power does this use?**
A: Le Potato ~4W + 2x HDD ~10W = ~14W total (€25-30/year at EU electricity prices)

**Q: Can I access this from the internet?**
A: Yes, but ONLY through WireGuard VPN on your Fritzbox. Never expose directly.

**Q: What about IPv6?**
A: Disabled by default for simplicity. Can be enabled if needed.

**Q: How do I add more storage?**
A: Add mount points to docker-compose.yml volumes and update paths in service configs.

## 📖 Documentation

- docs/STACK_OVERVIEW.md – Architecture and service map
- docs/SECURITY.md – Security guide and checklist
- docs/OPERATIONAL_RUNBOOK.md – Day‑2 operations and procedures
- docs/DEPLOYMENT.md – Deployment steps
- docs/QUICKSTART.md – Quick start notes
- Legacy docs moved to docs/archive/

## Support & Contributions

This is a fully integrated, production-ready stack. All services are configured to work together seamlessly.

### Community Research

This stack incorporates best practices from:
- [Virtualization Howto](https://www.virtualizationhowto.com/)
- [XDA Developers](https://www.xda-developers.com/)
- [TechHut](https://techhut.tv/)
- [Techno Tim](https://technotim.live/)
- [Homepage Documentation](https://gethomepage.dev/)
- r/homelab and r/selfhosted communities

See docs/STACK_OVERVIEW.md for detailed architecture and links.

### Useful Links
- [Kopia Documentation](https://kopia.io/docs/)
- [Seafile Documentation](https://manual.seafile.com/)
- [Immich Documentation](https://immich.app/docs/)
- [Authelia Documentation](https://www.authelia.com/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## License

This configuration is provided as-is for personal use. Individual services have their own licenses.

---

**Built with ❤️ for the Le Potato community**
