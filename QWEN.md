# PotatoStack - QWEN.md

## Project Overview

**PotatoStack** is a Docker Compose-based self-hosted infrastructure stack with 100+ services, optimized for low-power hardware (Intel N250 Mini PC, 16GB RAM). It follows SOTA 2025 standards and includes comprehensive monitoring, automation, and media services.

### Architecture

The stack includes the following core components:

**Storage Layout:**
- SSD (`/mnt/ssd/docker-data`) - Databases, configs, critical data
- HDD (`/mnt/storage`) - Media, photos, documents
- HDD (`/mnt/cachehdd`) - Caches, incomplete downloads, metrics

**Core Services:**
- PostgreSQL 16 (pgvector) with PgBouncer - 18 databases consolidated
- MongoDB 7, Redis 7 (shared cache, 16 databases)
- Traefik (reverse proxy), Gluetun (VPN), CrowdSec (IPS)
- Prometheus → Thanos (1yr retention) → Grafana
- Loki (logs), Netdata/cAdvisor (monitoring)

**Security & Intrusion Prevention:**
- CrowdSec - Modern IPS/IDS with community threat intelligence
- CrowdSec Traefik Bouncer - Blocks malicious IPs at reverse proxy level

**Authentication & Security:**
- Authentik - SSO and 2FA provider
- Vaultwarden - Password manager and 2FA aggregator

**DNS & Ad Blocking:**
- AdGuard Home - DNS-level ad blocking with encrypted DNS

**Media & Downloading:**
- *arr stack (Sonarr, Radarr, Lidarr, etc.) - Media management
- qBittorrent, Aria2 - Download clients
- Jellyfin - Media streaming

**Productivity & Automation:**
- Homarr - Dashboard
- Paperless-ngx - Document management
- Gitea + Woodpecker - Git hosting and CI/CD
- n8n - Workflow automation

## Building and Running

### Prerequisites

1. Three mounted drives:
   - `/mnt/ssd/docker-data` (SSD for databases/configs)
   - `/mnt/storage` (main storage)
   - `/mnt/cachehdd` (cache storage)

2. Docker and Docker Compose installed

### Setup Process

1. Mount your drives:
   ```bash
   sudo mkdir -p /mnt/ssd/docker-data /mnt/storage /mnt/cachehdd
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
make help             # Show all available commands
make up               # Start all services
make down             # Stop all services
make restart          # Restart all services
make logs             # View logs (SERVICE=name for specific service)
make health           # Check service health
make ps               # List running containers
make resources        # Monitor resource usage
make test             # Full integration tests
make test-quick       # Quick health check
make validate         # Docker-compose syntax validation
make lint             # YAML, shell, compose linting
make security         # Trivy vulnerability scan
make format           # Format all files (shfmt, prettier)
```

### Firewall Management

```bash
make firewall-install # Install UFW with Docker integration
make firewall-apply   # Apply PotatoStack firewall rules
make firewall-status  # Show firewall status
make firewall-list    # List Docker container firewall rules
```

## Development Conventions

### Code Style

#### Shell Scripts
- Shebang: `#!/bin/bash` with `set -euo pipefail`
- Indentation: 2 spaces (no tabs)
- Naming: Functions `snake_case`, Variables `UPPER_SNAKE_CASE`, Local vars `lower_snake_case`
- Output: Color-coded with `RED/GREEN/YELLOW/BLUE/NC` variables
- Always quote variables: `"$VAR"`
- OS detection for Linux/Termux compatibility

#### Docker Compose / YAML
- Indentation: 2 spaces, Line width: 120 chars
- Use anchors/aliases for common configs (x-common-env, x-logging)
- lowercase-with-hyphens for service names
- UPPER_CASE for environment variables

### File Organization

- `scripts/` - init/, setup/, test/, validate/, security/, monitor/, backup/
- `config/` - Service configs in `config/<service_name>/`
- `docs/` - All documentation
- Init scripts: `*-init.sh`, Setup scripts: `setup-*.sh`, Test scripts: `*-test.sh`

### Git Workflow

- Conventional Commits: `type(scope): description`
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Feature branches: `feature/description`, `fix/description`
- Run `make lint && make format` before committing

## Testing Strategy

### Integration Tests (`scripts/test/stack-test.sh`)
- OS detection (Linux/Termux)
- Drive structure validation
- Container health checks with OOM detection
- HTTP endpoint testing (all service ports)
- Log analysis (errors/warnings/critical)
- Resource usage monitoring
- Database connectivity tests

### Validation (`scripts/validate/validate-stack.sh`)
- YAML syntax (yamllint)
- Docker Compose config validation
- Python YAML parser validation
- Shell script validation (shellcheck)
- Shell script formatting (shfmt)
- Environment variable checks

## Service Access

All services are accessible via **https://192.168.178.158** (or your HOST_BIND IP):

| Service | HTTPS URL |
|---------|-----------|
| Homarr | `https://homarr.HOST_DOMAIN` |
| Traefik Dashboard | `https://traefik.HOST_DOMAIN` |
| Authentik | `https://authentik.HOST_DOMAIN` |
| Vaultwarden | `https://vault.HOST_DOMAIN` |
| AdGuard Home | `https://dns.HOST_DOMAIN` |
| *arr stack | `https://service.HOST_DOMAIN` (e.g., sonarr, radarr) |
| Jellyfin | `https://jellyfin.HOST_DOMAIN` |
| Gitea | `https://gitea.HOST_DOMAIN` |
| Paperless-ngx | `https://paperless.HOST_DOMAIN` |

## Troubleshooting

### Resource Issues
```bash
make resources          # Check resource usage
make health             # Check service health
docker stats --no-stream
```

### Service Issues
```bash
docker logs -f service_name    # View service logs
docker exec service_name cmd   # Execute in container
curl -I https://service.HOST_DOMAIN  # Test HTTP endpoint
make logs SERVICE=name         # View specific service logs
```

### Network/Firewall Issues
```bash
make firewall-status         # Check firewall status
make firewall-list           # List container rules
sudo ufw status verbose      # Direct UFW status
```

## Important Notes

- **Never commit .env** - contains sensitive passwords
- **Monitor resource usage** - designed for 16GB RAM systems
- **Backup strategy** - Kopia backs up all configured folders
- **Network binding** - Services bind to `HOST_BIND` IP for security
- **VPN routing** - Download clients route through Gluetun for privacy