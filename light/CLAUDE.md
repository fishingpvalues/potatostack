# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment Detection

**Critical: Always check OS at start.** If on Windows (MINGW/Git Bash), you're NOT on the production machine (Le Potato). Use `sshpass` for remote operations to the production Linux device.

```bash
uname -s  # MINGW* = Windows dev machine, Linux = production Le Potato
```

## Project Overview

**PotatoStack Light** - Ultra-lean Docker Compose stack optimized for low-RAM devices (Le Potato 2GB RAM). Total footprint ~1.2GB RAM. VPN-protected P2P downloads, file sync, backups, password manager with dual-disk caching architecture.

### Core Architecture

- **Dual-disk storage**: `/mnt/storage` (14TB main) + `/mnt/cachehdd` (500GB cache)
- **VPN network containment**: Gluetun container with Transmission + slskd inside (killswitch enabled)
- **HTTPS reverse proxy**: Traefik with mkcert locally-trusted certificates for all services
- **Shared API keys**: Docker volume `shared-keys:/keys` for auto-generated service API keys
- **Init containers**: `storage-init` runs before stack to create directory structure
- **Init scripts**: Each service has `*-init.sh` that configures on first run

### Storage Strategy

```
/mnt/storage/           # Final storage (14TB HDD)
├── downloads/torrent   # Completed torrents
├── slskd-shared/       # Soulseek files
├── syncthing/          # OneDrive mirror + media
└── kopia/repository/   # Backup repository

/mnt/cachehdd/          # Write cache (500GB HDD)
├── transmission-incomplete/  # Active downloads
├── slskd-incomplete/        # Active downloads
├── kopia-cache/             # Dedup cache
└── syncthing-versions/      # File versioning
```

## Common Commands

### Stack Management
```bash
make up                 # Start all services
make down               # Stop all services
make restart            # Restart all services
make logs SERVICE=name  # View logs (SERVICE optional)
make ps                 # List running containers
make health             # Check health of all services
make resources          # Monitor RAM usage (critical on 2GB device)
```

### HTTPS Setup (One-time)
```bash
make setup-https        # Generate mkcert certificates (run on Le Potato)
make install-ca         # Show CA installation instructions for devices
```

### Testing & Validation
```bash
make test               # Comprehensive integration tests (stack-test-light.sh)
make test-quick         # Quick health check only
make lint               # Full validation: YAML, shell, compose syntax
make validate           # Basic docker-compose config validation
make format             # Format shell scripts (shfmt) and YAML (prettier)
```

### Development
```bash
# Test single service endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000

# Check container health status
docker inspect --format='{{.State.Health.Status}}' container_name

# View specific service logs
docker logs -f <service_name>

# Check for OOM kills (critical on 2GB RAM)
dmesg | grep -i "out of memory"
```

## Configuration Files

### Environment Setup
1. Copy `.env.example` to `.env` (NEVER commit `.env`)
2. Required variables:
   - `HOST_BIND` - Le Potato LAN IP (e.g., 192.168.178.40)
   - `SURFSHARK_USER` / `SURFSHARK_PASSWORD` - VPN credentials
   - Service passwords (auto-generated if empty)
   - `SYNCTHING_API_KEY` / `SLSKD_API_KEY` - Get from UIs after first start

### Docker Compose Structure
- `docker-compose.yml` - Main production config
- `compose.production.yml` / `compose.development.yml` / `compose.staging.yml` - Environment overrides
- Services use `restart: unless-stopped` with health checks
- All services have memory limits (critical for 2GB RAM)

### Homepage Dashboard
Config in `homepage-config/`:
- `services.yaml` - Service definitions with API integrations
- `widgets.yaml` - System resource widgets
- `bookmarks.yaml` - Quick links
- `settings.yaml` - Dashboard settings

## Init Scripts Architecture

Each service has an init script that runs on container startup:

### Pattern: Auto-generated API Keys
```bash
# Stored in shared volume /keys/
if [ ! -f "/keys/service-api-key" ]; then
    API_KEY=$(openssl rand -hex 32)
    echo "$API_KEY" > /keys/service-api-key
fi
```

### Pattern: Wait for Config File
```bash
timeout=30
while [ $timeout -gt 0 ]; do
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done
```

### Key Init Scripts
- `init-storage.sh` - Creates dual-disk directory structure, migrates old layouts
- `kopia-init.sh` - Auto-creates backup repository, verifies status before starting server
- `transmission-init.sh` - Configures incomplete-dir, enables DHT/PEX for peer discovery
- `homepage-init.sh` - Extracts API keys from shared volume for widgets
- `slskd-init.sh` / `syncthing-init.sh` - Configure service-specific settings

## Code Style

### Shell Scripts
```bash
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

################################################################################
# Script Purpose (70+ char separator line)
################################################################################

# Variables: UPPER_SNAKE_CASE
# Functions: snake_case
# Local vars: lower_snake_case
```

### YAML / Docker Compose
- Indentation: 2 spaces, line width: 120 chars
- Environment variables: `${VAR_NAME:-default}`
- Shared logging config: `*default-logging` (5MB max, 2 files, compressed)
- Always set `mem_limit` and `mem_reservation` (2GB total budget)
- Health checks: 60-120s intervals (low-power device optimization)

### OS Detection Pattern
```bash
if [ -d "/data/data/com.termux" ]; then
    OS_TYPE="termux"
    DOCKER_CMD="proot-distro login debian --shared-tmp -- docker"
else
    OS_TYPE="linux"
    DOCKER_CMD="docker"
fi
```

## Service Access

All services accessible via **https://192.168.178.40** (or your HOST_BIND IP) with locally-trusted certificates:

| Service | HTTPS URL (via Traefik) | Direct HTTP (Legacy) |
|---------|--------------------------|---------------------|
| Homepage | `https://HOST_BIND/` | `http://HOST_BIND:3000` |
| Traefik Dashboard | `https://HOST_BIND/dashboard/` | `http://HOST_BIND:8080` |
| Gluetun | `https://HOST_BIND/gluetun` | `http://HOST_BIND:8000` |
| Transmission | `https://HOST_BIND/transmission` | `http://HOST_BIND:9091` |
| slskd | `https://HOST_BIND/slskd` | `http://HOST_BIND:2234` |
| AriaNg | `https://HOST_BIND/ariang` | `http://HOST_BIND:6880` |
| Syncthing | `https://HOST_BIND/syncthing` | `http://HOST_BIND:8384` |
| FileBrowser | `https://HOST_BIND/files` | `http://HOST_BIND:8181` |
| Vaultwarden | `https://HOST_BIND/vault` | `http://HOST_BIND:8443` |
| Portainer | `https://HOST_BIND/portainer` | `http://HOST_BIND:9000` |
| Kopia | `https://HOST_BIND/kopia` | `http://HOST_BIND:51515` |
| RustyPaste | `https://HOST_BIND/paste` | `http://HOST_BIND:8787` |
| Samba | `\\HOST_BIND\storage` | SMB ports 139/445 |

**Important:**
- **HTTPS access:** Use Traefik URLs on port 443 (recommended)
- **Direct port access:** Use HTTP (not HTTPS!) for direct port connections
- **SSL_ERROR_RX_RECORD_TOO_LONG?** You're trying HTTPS on a direct port - use HTTP instead or access via Traefik

## Memory Management (CRITICAL)

Total budget: ~1.3GB RAM on 2GB device

- Use `make resources` frequently to monitor usage
- Watch for OOM kills: `dmesg | grep -i "out of memory"`
- Container limits defined in docker-compose.yml
- Swap: 4GB file (swappiness=10)
- ZRAM: ~1GB compressed RAM
- Portainer is optional (`--profile optional`) - saves 96MB
- Traefik HTTPS proxy: ~50MB (essential for secure access)

## Testing Strategy

### Integration Tests (`stack-test-light.sh`)
- OS detection (Linux/Termux)
- Drive structure validation (`/mnt/storage`, `/mnt/cachehdd`)
- Container health checks with OOM detection
- HTTP endpoint testing (all service ports)
- Log analysis (errors/warnings/critical)
- Resource usage monitoring

### Validation (`validate-stack.sh`)
- YAML syntax (yamllint)
- Docker Compose config validation
- Python YAML parser validation
- Shell script validation (shellcheck)
- Shell script formatting (shfmt)
- Environment variable checks

## Common Patterns

### Gluetun Network Container
Transmission and slskd run INSIDE Gluetun container's network namespace (`network_mode: service:gluetun`). This provides VPN killswitch - if VPN drops, they lose network access.

### Service Dependencies
```yaml
depends_on:
  storage-init:
    condition: service_completed_successfully
  gluetun:
    condition: service_healthy
```

### Auto-healing
`autoheal` container restarts unhealthy containers every 30s. Watchtower updates containers at 3 AM daily.

## Troubleshooting

### High Memory
```bash
free -h
docker stats --no-stream
make resources
tail /var/log/memory-pressure.log
```

### VPN Issues
```bash
docker logs gluetun
curl http://HOST_BIND:8000/v1/publicip/ip
```

### Permission Errors
```bash
sudo chown -R 1000:1000 /mnt/storage /mnt/cachehdd
docker compose restart
```

## Important Notes

- **Never commit .env** - contains sensitive passwords
- **Always test on dev machine first** - use sshpass from Windows to deploy
- **Monitor RAM usage** - 2GB is tight, OOM kills are common if limits exceeded
- **Backup strategy** - Kopia backs up all Syncthing folders + Vaultwarden + downloads
- **Network binding** - Services bind to `HOST_BIND` IP, not 0.0.0.0 (security)
