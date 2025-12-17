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
- **500GB Cache Drive** (`/mnt/cachehdd`): Temp files, thumbnails, cache, pastebin uploads
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

**Production (Le Potato):**
```bash
cd light
chmod +x setup-directories.sh
sudo ./setup-directories.sh
```

**Testing (Windows/macOS):**
```bash
cd light
chmod +x setup-directories-mock.sh
./setup-directories-mock.sh
```

The setup scripts create all required directories with:
- Automatic drive detection and size reporting
- Color-coded output for easy verification
- Duplicate detection (warns if directories already exist)
- Directory verification after creation
- Proper permissions (PUID/PGID 1000)

**Verify Setup:**
```bash
chmod +x verify-directories.sh

# For production
./verify-directories.sh

# For testing
./verify-directories.sh test
```

The verification script checks:
- All 11 required directories exist
- Read/write permissions are correct
- Drive space usage
- Directory sizes

### 3. Configure Environment
```bash
cp .env.example .env
nano .env  # Edit with your values
```

**Required Configuration:**
- Update `HOST_BIND` to your Le Potato's IP (e.g., `192.168.178.40`)
- Configure Surfshark VPN credentials from https://my.surfshark.com/vpn/manual-setup/main
- Generate strong passwords for all services using `openssl rand -base64 32`
- Set your local network subnet in `LAN_NETWORK` (e.g., `192.168.178.0/24`)
- `VPN_DNS` must be a single IP address (e.g., `1.1.1.1`) - Gluetun doesn't support comma-separated DNS

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
- Rustypaste uploads

### Docker Volumes
Small config and state data stored in Docker volumes:
- Database data (Postgres, Redis)
- Service configs (Gluetun, Transmission, slskd, etc.)
- Logs and temp files

## Database Management

### PostgreSQL Databases
Single PostgreSQL instance serves multiple applications:
- `immich` - Immich photos database
  - Extensions: `vectors` (pgvecto.rs), `cube`, `earthdistance`, `pg_trgm`
  - Owner: `immich` user with full schema permissions
- `ccnet_db`, `seafile_db`, `seahub_db` - Seafile databases
  - Owner: `seafile` user

**Initialization:**
The stack uses `init-db.sh` (bash script) instead of SQL for database initialization:
- Reads `IMMICH_DB_PASSWORD` and `SEAFILE_DB_PASSWORD` from environment
- Creates database users and databases with proper ownership
- Installs all required PostgreSQL extensions for Immich
- Grants necessary permissions to prevent "permission denied" errors

### Redis Databases
Shared Redis instance with database separation:
- DB 2 - Immich cache
- DB 6 - Seafile cache

### Database Credentials
All database passwords are configured in `.env`:
- `POSTGRES_SUPER_PASSWORD` - PostgreSQL superuser
- `IMMICH_DB_PASSWORD` - Immich database user
- `SEAFILE_DB_PASSWORD` - Seafile database user

**Security:** Never use `current_setting()` in SQL files - it cannot read OS environment variables. Use shell scripts with `psql` heredocs instead.

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

# Check if databases were created
docker compose exec postgres psql -U postgres -c "\l"

# Check if users exist
docker compose exec postgres psql -U postgres -c "\du"

# Verify Immich extensions
docker compose exec postgres psql -U postgres -d immich -c "\dx"
```

**Common Issues:**
- **"permission denied for schema vectors"**: Run database initialization again or grant permissions manually
- **"function earthdistance does not exist"**: Missing extensions - recreate database volume
- **"password authentication failed"**: Check `.env` file has correct database passwords

### Immich Startup Issues
If Immich fails to start with database errors:
```bash
# Check Immich logs
docker compose logs immich-server --tail 50

# Verify database extensions and permissions
docker compose exec postgres psql -U postgres -d immich -c "
  SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'vectors';
  SELECT extname FROM pg_extension;
"

# Grant missing permissions (if needed)
docker compose exec postgres psql -U postgres -d immich -c "
  GRANT USAGE ON SCHEMA vectors TO immich;
  GRANT ALL ON ALL TABLES IN SCHEMA vectors TO immich;
  ALTER DATABASE immich OWNER TO immich;
  ALTER SCHEMA public OWNER TO immich;
"
```

### Rustypaste Permission Errors
If rustypaste shows "Permission denied" errors:
```bash
# Check directory ownership
ls -ld /mnt/cachehdd/rustypaste

# Fix permissions
sudo chown -R 1000:1000 /mnt/cachehdd/rustypaste
docker compose restart rustypaste
```

### VPN DNS Issues
If Gluetun fails with DNS parsing errors:
```bash
# Check logs
docker compose logs gluetun --tail 20

# Verify DNS config in .env (must be single IP, NOT comma-separated)
# ✅ Correct: VPN_DNS=1.1.1.1
# ❌ Wrong: VPN_DNS=1.1.1.1,1.0.0.1
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

## Testing

A complete test environment is available for validation:

```bash
cd light

# 1. Setup mock directories (creates ../mock-drives/)
chmod +x setup-directories-mock.sh
./setup-directories-mock.sh

# 2. Verify setup
chmod +x verify-directories.sh
./verify-directories.sh test

# 3. Run test stack (uses Windows-compatible paths)
docker compose -f docker-compose.test.yml --env-file .env.test up -d

# Check status
docker compose -f docker-compose.test.yml --env-file .env.test ps

# View logs
docker compose -f docker-compose.test.yml --env-file .env.test logs -f

# Tear down test environment
docker compose -f docker-compose.test.yml --env-file .env.test down -v
```

**Test Environment Differences:**
- Uses test credentials (see `.env.test`)
- Rustypaste uses `./data/rustypaste` bind mount (Windows-compatible)
- All ports bound to `127.0.0.1` for local testing
- VPN uses dummy credentials (won't actually connect)

**Production vs Test Paths:**
| Service | Production (Linux) | Test (Mock Drives) |
|---------|-------------------|-------------------|
| Main Drive | `/mnt/seconddrive/` | `../mock-drives/seconddrive/` |
| Cache Drive | `/mnt/cachehdd/` | `../mock-drives/cachehdd/` |
| PostgreSQL init | `init-db.sh` | `init-db.sh` (same) |
| All services | Host IP binding | `127.0.0.1` binding |

## Integration with Kubernetes Setup

This stack mirrors the full K8s deployment:
- Same service configurations
- Same environment variables
- Same network policies (VPN killswitch)
- Same backup strategy
- Same database architecture

Migrate to K8s later by using the configurations in `/k8s` and `/helm` directories.

## Technical Notes

### PostgreSQL Initialization
- Uses **bash script** (`init-db.sh`) not SQL file
- SQL `current_setting()` cannot read Docker environment variables
- Shell script with `psql` heredocs reads env vars correctly
- Includes all Immich extensions and permission grants
- Idempotent - safe to run multiple times

### Rustypaste Configuration
- Deprecated `random_url.enabled` commented out (causes warnings)
- Uses bind mount instead of Docker volume for cross-platform compatibility
- Linux: `/mnt/cachehdd/rustypaste` (cache drive for temp uploads)
- Windows: `./data/rustypaste` (local directory for testing)

### VPN Configuration
- Gluetun requires single DNS IP, not comma-separated
- Invalid: `DNS_ADDRESS=1.1.1.1,1.0.0.1` causes parse error
- Valid: `DNS_ADDRESS=1.1.1.1`
- Set via `VPN_DNS` in `.env` file

### Container Dependencies
Services with health checks enforce startup order:
1. `postgres`, `redis` - Start first, wait for healthy
2. `gluetun` - Starts independently
3. `immich-*`, `seafile`, `vaultwarden` - Wait for postgres + redis
4. `transmission`, `slskd` - Wait for gluetun (network dependency)

## Development Workflow

### Making Changes
1. Test changes in test environment first
2. Verify all services start successfully
3. Check logs for errors
4. Apply to production `docker-compose.yml`
5. Commit both test and production changes

### Adding New Services
1. Add service to `docker-compose.test.yml`
2. Test with `.env.test` credentials
3. Update `.env.example` with new variables
4. Add to production `docker-compose.yml`
5. Update README with service info
6. Add port to service access table

### Database Schema Changes
1. Never modify databases directly in production
2. Test schema changes in test environment
3. Update `init-db.sh` if needed
4. Document changes in commit message
5. Create backup before applying to production
