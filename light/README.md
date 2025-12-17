# PotatoStack Light - Docker Compose Edition

Minimal production-ready Docker Compose stack for Le Potato, mirroring the full Kubernetes setup with all integrations and functionality.

## Services Included

### VPN & P2P (Gluetun Killswitch)
- **Gluetun** - VPN client with killswitch (Surfshark)
- **Transmission** - Torrent client (wired to Gluetun)
- **slskd** - Soulseek client (wired to Gluetun)

### Core Applications
- **Vaultwarden** - Password manager
- **Portainer** - Container management UI
- **Immich** - Photo management with ML features
- **Kopia** - Central backup server for ALL network devices (laptops, desktops, phones, etc.)
- **Seafile** - File sync & share
- **Rustypaste** - Pastebin service

### Infrastructure
- **PostgreSQL** - Shared database (Immich, Seafile)
- **Redis** - Shared cache (Immich, Seafile)

### Monitoring
- **FritzBox Exporter** - Router metrics

### Storage Architecture
- **14TB Main Drive** (`/mnt/seconddrive`): Downloads, photos, files, backups
- **500GB Cache Drive** (`/mnt/cachehdd`): Temp files, thumbnails, cache
- **Docker Volumes**: Small config/state data only

## Quick Start

### 1. Mount Your Drives

The stack requires two mounted drives:
- **Main storage** (14TB): `/mnt/seconddrive`
- **Cache storage** (500GB): `/mnt/cachehdd`

```bash
# Find your drive UUIDs
sudo blkid

# Edit /etc/fstab and add (replace with your UUIDs):
UUID=xxx-xxx /mnt/seconddrive ext4 defaults 0 2
UUID=yyy-yyy /mnt/cachehdd ext4 defaults 0 2

# Mount drives
sudo mkdir -p /mnt/seconddrive /mnt/cachehdd
sudo mount -a

# Verify
df -h /mnt/seconddrive /mnt/cachehdd
```

### 2. Create Directory Structure
```bash
cd light
chmod +x setup-directories.sh
sudo ./setup-directories.sh
```

This creates all required directories on both drives with proper permissions.

### 3. Configure Environment
```bash
cp .env.example .env
nano .env  # Edit with your values
```

**Required Configuration:**
- Update `HOST_BIND` to your Le Potato's IP
- Configure Surfshark VPN credentials
- Generate strong passwords for all services
- Set your local network subnet in `LAN_NETWORK`

### 4. Start the Stack
```bash
docker compose up -d
```

### 5. Check Status
```bash
docker compose ps
docker compose logs -f
```

## Service Access

All services are accessible on your home LAN via `HOST_BIND` IP:

| Service | URL | Default Port |
|---------|-----|--------------|
| Gluetun Control | http://HOST_BIND:8000 | 8000 |
| Transmission | http://HOST_BIND:9091 | 9091 |
| slskd | http://HOST_BIND:2234 | 2234 |
| Vaultwarden | http://HOST_BIND:8080 | 8080 |
| Portainer | https://HOST_BIND:9443 | 9443 |
| Immich | http://HOST_BIND:2283 | 2283 |
| Kopia | https://HOST_BIND:51515 | 51515 |
| Seafile | http://HOST_BIND:8082 | 8082 |
| Rustypaste | http://HOST_BIND:8001 | 8001 |
| FritzBox Metrics | http://HOST_BIND:9042 | 9042 |

## Network Architecture

### VPN Killswitch
Transmission and slskd use `network_mode: "service:gluetun"` to route all traffic through Gluetun's VPN tunnel. If the VPN connection drops, these services lose internet access (killswitch protection).

### Gluetun Firewall
- Firewall enabled with strict outbound rules
- Only allows traffic to LAN subnet (`FIREWALL_OUTBOUND_SUBNETS`)
- Ports 51413 (Transmission) and 50000 (slskd) forwarded

### LAN Access
All services bind to `HOST_BIND` IP, making them accessible on your home network.

**Remote Access:**
- Connect via WireGuard VPN on FritzBox
- Access all services through VPN tunnel at http://192.168.178.40:PORT
- No port forwarding or firewall rules needed - WireGuard handles security

## Storage Management

### Mounted Drives
The stack uses two mounted HDDs for optimal performance:

**Main Storage** (`/mnt/seconddrive` - 14TB):
- Transmission downloads
- slskd shared files
- Immich photo uploads & library
- Seafile file storage
- Kopia backup repository

**Cache Storage** (`/mnt/cachehdd` - 500GB):
- Transmission incomplete downloads
- slskd incomplete downloads
- Immich thumbnails
- Kopia cache

### Docker Volumes
Small config and state data stored in Docker volumes:
- Database data (Postgres, Redis)
- Service configs (Gluetun, Transmission, slskd, etc.)
- Logs and temp files

## Database Management

### PostgreSQL Databases
Single PostgreSQL instance serves multiple applications:
- `immich` - Immich photos database
- `ccnet_db`, `seafile_db`, `seahub_db` - Seafile databases

### Redis Databases
Shared Redis instance with database separation:
- DB 2 - Immich cache
- DB 6 - Seafile cache

## Backup Strategy

### Kopia Central Backup Server
Kopia runs as a **central backup repository server** accessible to all devices on your network at `https://HOST_BIND:51515`.

**All your devices** (laptops, desktops, phones, tablets) can connect to this Kopia server and perform backups with full read/write access.

#### Local Docker Stack Data Access
Kopia has direct access to all stack data volumes for local backups:
- Vaultwarden data
- Immich uploads & library
- Seafile data
- Transmission downloads
- slskd shared files

#### Connect Your Devices to Kopia

**1. Install Kopia Client**
- Download from: https://kopia.io/docs/installation/
- Available for: Windows, macOS, Linux, Docker

**2. First-Time Connection**
```bash
# Connect to the Kopia server
kopia repository connect server \
  --url https://HOST_BIND:51515 \
  --server-cert-fingerprint <accept-on-first-connect> \
  --override-username=laptop-john \
  --override-hostname=johns-laptop

# Enter server credentials when prompted (KOPIA_SERVER_USER/PASSWORD)
```

**3. Create Backup Snapshot**
```bash
# Backup a directory
kopia snapshot create /path/to/documents

# List snapshots
kopia snapshot list

# Restore from snapshot
kopia snapshot restore <snapshot-id> /path/to/restore
```

**4. Automated Backups**
```bash
# Create backup policy
kopia policy set /path/to/documents --keep-latest 10 --keep-daily 7

# Schedule with cron (Linux/Mac)
0 */6 * * * kopia snapshot create /home/user/documents

# Or use Kopia UI for automated scheduling
kopia server start --ui
```

**All devices on your network** can backup to this central repository with full read/write access!

### Manual Backups
```bash
# Backup PostgreSQL
docker compose exec postgres pg_dumpall -U postgres > backup.sql

# Backup volumes
docker run --rm -v light_vaultwarden-data:/data -v $(pwd):/backup alpine tar czf /backup/vaultwarden-backup.tar.gz /data
```

## Maintenance

### Update Services
```bash
docker compose pull
docker compose up -d
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f gluetun
docker compose logs -f immich-server
```

### Restart Service
```bash
docker compose restart <service-name>
```

### Stop Stack
```bash
docker compose down
```

### Remove Everything (including volumes)
```bash
docker compose down -v
```

## Troubleshooting

### VPN Connection Issues
```bash
docker compose logs gluetun
docker compose exec gluetun wget -qO- ifconfig.me
```

### Transmission/slskd Not Working
Check Gluetun health - these services depend on it:
```bash
docker compose ps gluetun
```

### Database Connection Errors
Ensure PostgreSQL is healthy:
```bash
docker compose exec postgres pg_isready -U postgres
```

### Check Service Health
```bash
docker compose ps
```

## Security

### Network Security
All services bind to `HOST_BIND` IP for **LAN-only access**:
- Services accessible only from 192.168.178.0/24 subnet
- Not exposed on 0.0.0.0 (all interfaces) - violates security policy
- **WireGuard VPN on FritzBox** provides secure remote access
- External access ONLY through WireGuard tunnel (no port forwarding)

### Password Security
**CRITICAL: Change ALL default passwords!**

```bash
# Generate strong passwords
openssl rand -base64 32

# Update .env file with generated passwords for:
# - POSTGRES_SUPER_PASSWORD
# - KOPIA_PASSWORD, KOPIA_SERVER_PASSWORD
# - VAULTWARDEN_ADMIN_TOKEN
# - IMMICH_DB_PASSWORD
# - SEAFILE_DB_PASSWORD, SEAFILE_ADMIN_PASSWORD
# - SLSKD_PASSWORD
# - Surfshark VPN credentials
```

**Change default credentials:**
- Transmission: `admin/admin` (change in docker-compose.yml if needed)
- Portainer: Set on first login
- All other services: Configure via .env

### VPN Killswitch Verification
Ensure P2P traffic ONLY goes through Gluetun VPN:

```bash
# Check Gluetun public IP
curl http://${HOST_BIND}:8000/v1/publicip/ip
# Should show VPN provider's IP, NOT your real IP

# Check VPN status
curl http://${HOST_BIND}:8000/v1/vpn/status
# Should return: {"status":"running"}

# If shows your real IP, DO NOT USE - fix configuration first!
```

### Backup Security
- Kopia uses AES-256 encryption
- Store KOPIA_PASSWORD securely (password manager)
- Regular offsite backups recommended
- Never commit .env file (contains all passwords)

### Regular Security Tasks
**Monthly:**
- [ ] Review and rotate passwords (>90 days)
- [ ] Check VPN killswitch status (Gluetun for P2P)
- [ ] Review container updates (security patches)
- [ ] Test backup restoration
- [ ] Check WireGuard VPN status on FritzBox
- [ ] Review connected WireGuard clients

**Additional Resources:**
- See `../docs/SECURITY.md` for complete security guide
- See `../docs/NETWORK_SECURITY.md` for network configuration details

## Resource Requirements

Minimum for Le Potato:
- 2GB RAM
- 16GB+ storage (+ external storage for media)
- Ethernet connection recommended

## Integration with Kubernetes Setup

This stack mirrors the full K8s deployment:
- Same service configurations
- Same environment variables
- Same network policies (VPN killswitch)
- Same backup strategy
- Same database architecture

Migrate to K8s later by using the configurations in `/k8s` and `/helm` directories.
