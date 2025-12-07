# PotatoStack Setup Instructions
**Complete Setup Guide - Updated for Gluetun VPN**

## What's Implemented

✅ **Secrets Management** (sops + age)
✅ **Blackbox Exporter** (HTTP/TCP health monitoring)
✅ **Gluetun VPN** (Universal VPN client replacing Surfshark image)
✅ **Enhanced .kopiaignore** (Docker-aware backup exclusions)
✅ **Database Backups** (Automated nightly dumps)

## Quick Start (5 Minutes)

### 1. Set Up Your Credentials

```bash
cd /path/to/potatostack

# Copy example environment file
cp .env.example .env

# Edit and fill in your credentials
nano .env
```

**Required credentials:**
- **SURFSHARK_USER** and **SURFSHARK_PASSWORD** - Get from https://my.surfshark.com/vpn/manual-setup/main (Service Credentials, NOT your account email!)
- **SURFSHARK_COUNTRY** - Full name like "Netherlands" or "Germany"
- **SURFSHARK_CITY** - Optional, like "Amsterdam" or leave blank
- **HOST_BIND** - Already set to 192.168.178.40 (your LAN IP). Change if your Le Potato has a different IP.
- **HOST_ADDR** - Same as HOST_BIND, used for dashboard links
- All database passwords (generate strong random passwords)
- Grafana, Gitea, Nextcloud admin passwords

**Security Note:** HOST_BIND is set to your LAN IP (192.168.178.40) instead of 0.0.0.0 to prevent services from binding to all network interfaces. This improves security by only exposing services on your local network.

### 2. Start the Stack

```bash
# Pull all images
docker compose pull

# Start everything
docker compose up -d

# Check status
docker compose ps
```

### 3. Verify VPN is Working

```bash
# Check Gluetun status
docker logs gluetun --tail 50

# Verify VPN connection
curl http://localhost:8000/v1/publicip/ip

# Should return something like:
# {"public_ip":"185.123.XXX.XXX"}  <- VPN provider IP, NOT your real IP!

# Check VPN status
curl http://localhost:8000/v1/vpn/status
# Should return: {"status":"running"}
```

### 4. Access Services

- **Homepage Dashboard**: http://192.168.178.40:3003
- **Grafana**: http://192.168.178.40:3000 (admin / your_password)
- **qBittorrent**: http://192.168.178.40:8080 (admin / adminadmin)
- **Nextcloud**: http://192.168.178.40:8082
- **Prometheus**: http://192.168.178.40:9090
- **Gluetun Control**: http://192.168.178.40:8000

## Optional: Set Up Secrets Encryption

Encrypt your .env file so you can commit it to git safely:

```bash
# Run interactive setup
./scripts/setup-secrets.sh

# This will:
# 1. Install age and sops
# 2. Generate encryption key
# 3. Encrypt .env to .env.enc
# 4. Update .gitignore

# To edit secrets later:
./scripts/edit-secrets.sh

# To set up auto-decrypt on boot:
sudo ./scripts/setup-decrypt-service.sh
```

## Gluetun VPN Configuration

### Using Your Existing Surfshark Credentials

Gluetun automatically uses the same `SURFSHARK_USER` and `SURFSHARK_PASSWORD` from your .env file. No changes needed!

### Key Features

- **Built-in killswitch**: Blocks ALL non-VPN traffic automatically
- **HTTP control server**: Port 8000 for status checks and management
- **Firewall rules**:
  - Allows LAN access (192.168.178.0/24)
  - Allows P2P incoming port 6881
  - Blocks everything else (security)

### Advanced: Switch to WireGuard

WireGuard is faster and more modern than OpenVPN:

1. Generate credentials at https://my.surfshark.com/vpn/manual-setup/main
2. Select WireGuard → Generate keypair
3. Download the .conf file
4. Extract credentials:
   ```
   [Interface]
   PrivateKey = wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU=
   Address = 10.64.222.21/16
   ```
5. Add to .env:
   ```bash
   SURFSHARK_CONNECTION_TYPE=wireguard
   WIREGUARD_PRIVATE_KEY=wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU=
   WIREGUARD_ADDRESSES=10.64.222.21/16
   ```
6. Add to docker-compose.yml under `gluetun` environment:
   ```yaml
   - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
   - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}
   ```
7. Restart: `docker compose restart gluetun`

### Switch to Another VPN Provider

Gluetun supports 60+ providers. To switch from Surfshark to another:

1. Update .env:
   ```bash
   VPN_SERVICE_PROVIDER=nordvpn  # or protonvpn, mullvad, etc.
   NORDVPN_USER=your_nordvpn_username
   NORDVPN_PASSWORD=your_nordvpn_password
   ```

2. Update docker-compose.yml gluetun environment:
   ```yaml
   - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:-surfshark}
   ```

3. Restart: `docker compose restart gluetun`

See full provider list: https://github.com/qdm12/gluetun-wiki

## Monitoring Setup

### Check Blackbox Exporter

```bash
# Open Prometheus targets
http://192.168.178.40:9090/targets

# Look for "blackbox-http" job
# All services should show UP (green)
```

### Import Grafana Dashboards

1. Go to http://192.168.178.40:3000
2. Login (admin / your_grafana_password from .env)
3. Click + → Import
4. Enter dashboard ID: **1860** (Node Exporter) → Load → Select Prometheus → Import
5. Repeat for:
   - **193** - Docker Container & Host Metrics
   - **20204** - SMART HDD Monitoring
   - **7587** - Prometheus Blackbox Exporter

## Troubleshooting

### VPN Not Connecting

```bash
# Check Gluetun logs
docker logs gluetun

# Common issues:
# 1. Wrong credentials - verify at https://my.surfshark.com/vpn/manual-setup/main
# 2. Incorrect country/city name - use full names (Netherlands, not nl)
# 3. Firewall blocking - check systemd-resolved or ufw

# Restart Gluetun
docker compose restart gluetun
```

### qBittorrent/slskd Can't Connect

```bash
# Verify Gluetun is healthy
docker inspect gluetun | grep -A 5 Health

# Should show "healthy"

# Restart dependent services
docker compose restart qbittorrent slskd
```

### Prometheus Targets Down

```bash
# Check blackbox exporter
docker logs blackbox-exporter

# Verify it can reach services
curl http://localhost:9115/probe?target=http://grafana:3000&module=http_2xx

# Should return: probe_success 1
```

### Database Backup Not Running

```bash
# Check backup containers
docker logs nextcloud-db-backup
docker logs gitea-db-backup

# Verify backups exist
ls -lh /mnt/seconddrive/backups/db/

# Should see .sql.gz files dated recently
```

## Maintenance

### Daily

Automated via containers:
- Database backups (mysqldump/pg_dump)
- Diun checks for image updates (notifications only, no auto-updates)
- Prometheus scrapes metrics

### Weekly

```bash
# Check container health
docker compose ps

# Review Grafana dashboards for anomalies
# Check Alertmanager for fired alerts
```

### Monthly

```bash
# Verify Kopia backups
./scripts/verify-kopia-backups.sh

# Test restore from backup
# Update pinned image tags in .env if needed
```

### Quarterly

- Full disaster recovery test (restore entire stack from Kopia)
- Rotate credentials
- Review and update security policies

## Further Reading

- **Gluetun Documentation**: docs/GLUETUN_MIGRATION.md
- **Secrets Management**: docs/SECRETS_MANAGEMENT.md
- **Priority Implementation**: docs/IMPLEMENTATION_PRIORITY.md
- **Security Guide**: docs/SECURITY.md
- **Stack Overview**: docs/STACK_OVERVIEW.md

## Support

- **GitHub Issues**: (your repo URL)
- **Gluetun Issues**: https://github.com/qdm12/gluetun/issues
- **Kopia Docs**: https://kopia.io/docs/
