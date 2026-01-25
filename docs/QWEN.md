# PotatoStack - QWEN.md (Legacy Light Reference)

> Ported from the light stack. References to 2GB devices are legacy and kept for context.

## Project Overview

**PotatoStack Light** is an ultra-lean Docker Compose stack optimized for low-RAM devices (for example, 2GB-class single-board computers). The stack provides a comprehensive set of services including VPN-protected P2P downloads, file synchronization, backups, and password management with a total memory footprint of approximately 1.2GB RAM.

### Architecture

The stack includes the following services:
- **Traefik** - Reverse proxy with HTTPS support using mkcert certificates
- **Homarr** - Unified dashboard for all services
- **Gluetun** - VPN client with killswitch functionality
- **qBittorrent** - Torrent client (via VPN)
- **slskd** - Soulseek client (via VPN)
- **Aria2/AriaNg** - Advanced download manager with web UI
- **Syncthing** - P2P file synchronization
- **Vaultwarden** - Bitwarden-compatible password manager
- **Kopia** - Backup server
- **FileBrowser** - Web file manager
- **Portainer** - Container management (optional profile)
- **Samba** - Network file sharing
- **RustyPaste** - File sharing and pastebin service
- **Watchtower** - Automatic container updates
- **Autoheal** - Automatic container recovery

### Storage Strategy

The stack implements a dual-disk caching architecture:
- **Main Storage** (`/mnt/storage`): 14TB HDD for final storage of completed files
- **Cache HDD** (`/mnt/cachehdd`): 500GB SSD for temporary operations and caching

This strategy minimizes write operations on the main HDD and extends its lifespan by handling temporary files, incomplete downloads, and database caches on the faster SSD.

## Building and Running

### Prerequisites

1. Two mounted drives:
   - `/mnt/storage` (main storage)
   - `/mnt/cachehdd` (cache storage)

2. Docker and Docker Compose installed

### Setup Process

1. Mount your drives:
   ```bash
   sudo mkdir -p /mnt/storage /mnt/cachehdd
   # Edit /etc/fstab with your UUIDs
   sudo mount -a
   ```

2. Copy and configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials and settings
   ```

3. Start the stack:
   ```bash
   make up
   # Or: docker compose up -d
   ```

### Key Commands

```bash
make up                 # Start all services
make down               # Stop all services
make restart            # Restart all services
make logs SERVICE=name  # View logs (SERVICE optional)
make ps                 # List running containers
make health             # Check health of all services
make resources          # Monitor RAM usage (critical on 2GB device)
make test               # Run comprehensive integration tests
make lint               # Full validation (YAML, shell, compose)
make format             # Format shell scripts and YAML files
```

### HTTPS Setup

To enable HTTPS with locally-trusted certificates:
```bash
make setup-https        # Generate mkcert certificates
make install-ca         # Show CA installation instructions
```

## Development Conventions

### Code Style

#### Shell Scripts
- Shebang: `#!/bin/bash` (main scripts) or `#!/bin/sh` (init scripts)
- Error handling: `set -euo pipefail`
- Indentation: 2 spaces (no tabs)
- Naming: Functions `snake_case`, Variables `UPPER_SNAKE_CASE`, Local vars `lower_snake_case`
- Comments: Descriptive header blocks with `70+` char separator
- Output: Color-coded with `RED/GREEN/YELLOW/BLUE/NC` variables
- Executable: All scripts must be executable (`chmod +x`)

#### YAML / Docker Compose
- Indentation: 2 spaces, Line width: 120 chars
- Services alphabetically ordered when practical
- Environment variables: `${VAR_NAME:-default}`
- Comments: `# Inline comments with space after #`
- Use `restart: unless-stopped` and configure health checks
- Set resource limits for 2GB RAM environment

### File Organization

- Init scripts: `*-init.sh`, Setup scripts: `setup-*.sh`, Test scripts: `*-test.sh`
- `.env.example` (commit) vs `.env` (NEVER commit)
- `docker-compose.yml` (main) vs `compose.*.yml` (environment-specific)
- Volumes: `/mnt/storage`, `/mnt/cachehdd`, `shared-keys:/keys`

### Memory Management

Critical for the 2GB RAM environment:
- Total stack budget: ~1.3GB RAM
- Use `make resources` frequently to monitor usage
- Watch for OOM kills: `dmesg | grep -i "out of memory"`
- Container limits defined in docker-compose.yml
- Portainer is optional (`--profile optional`) - saves 96MB

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

### Service API Keys

API keys are stored in `/keys/` volume, auto-generated if missing, format: `<service>-api-key`

## Testing Strategy

### Integration Tests (`stack-test-light.sh`)
- OS detection (Linux/Termux)
- Drive structure validation (`/mnt/storage`, `/mnt/cachehdd`)
- Container health checks with OOM detection
- HTTP endpoint testing (all service ports)
- Log analysis (errors/warnings/critical)
- Resource usage monitoring

### Validation (`scripts/validate/validate-stack.sh`)
- YAML syntax (yamllint)
- Docker Compose config validation
- Python YAML parser validation
- Shell script validation (shellcheck)
- Shell script formatting (shfmt)
- Environment variable checks

## Service Access

All services accessible via **https://192.168.178.158** (or your HOST_BIND IP) with locally-trusted certificates:

| Service | HTTPS URL (Traefik) | Direct HTTP (Legacy) |
|---------|---------------------|---------------------|
| Homarr | `https://HOST_BIND/` | `http://HOST_BIND:7575` |
| Traefik Dashboard | `https://HOST_BIND/dashboard/` | - |
| Gluetun | `https://HOST_BIND/gluetun` | `http://HOST_BIND:8000` |
| qBittorrent | `https://HOST_BIND/qbittorrent` | `http://HOST_BIND:8282` |
| slskd | `https://HOST_BIND/slskd` | `http://HOST_BIND:2234` |
| AriaNg | `https://HOST_BIND/ariang` | `http://HOST_BIND:6880` |
| Syncthing | `https://HOST_BIND/syncthing` | `http://HOST_BIND:8384` |
| FileBrowser | `https://HOST_BIND/files` | `http://HOST_BIND:8181` |
| Vaultwarden | `https://HOST_BIND/vault` | `http://HOST_BIND:8443` |
| Portainer | `https://HOST_BIND/portainer` | `http://HOST_BIND:9000` |
| Kopia | `https://HOST_BIND/kopia` | `http://HOST_BIND:51515` |
| RustyPaste | `https://HOST_BIND/paste` | `http://HOST_BIND:8787` |
| Samba | `\\HOST_BIND\storage` | SMB ports 139/445 |

**Note:** Direct port access uses HTTP, not HTTPS. For HTTPS, use Traefik URLs on port 443.

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
- **Monitor RAM usage** - 2GB is tight, OOM kills are common if limits exceeded
- **Backup strategy** - Kopia backs up all Syncthing folders + Vaultwarden + downloads
- **Network binding** - Services bind to `HOST_BIND` IP, not 0.0.0.0 (security)
- **VPN killswitch** - qBittorrent and slskd run inside Gluetun container's network namespace for security
