# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
EXPLORE: USE HAIKU
PLAN: USE OPUS
EXECUTE: USE SONNET
## Project Overview

PotatoStack is a Docker Compose-based self-hosted infrastructure stack with 100 services, optimized for low-power hardware (Intel N250 Mini PC, 16GB RAM). Uses SOTA 2025 standards.

## Essential Commands

```bash
make help          # Show all available commands
make up            # Start all services
make down          # Stop all services
make restart       # Restart all services
make logs          # View logs (SERVICE=name for specific service)
make health        # Check service health

# Testing & Validation
make test          # Full integration tests (scripts/test/stack-test.sh)
make test-quick    # Quick health check
make validate      # Docker-compose syntax validation
make lint          # YAML, shell, compose linting
make security      # Security vulnerability scan

# Formatting
make format        # Format all files (shfmt, prettier)
```

## Architecture

**Storage Layout:**
- SSD (`/mnt/ssd/docker-data`) - Databases, configs, critical data
- HDD (`/mnt/storage`) - Media, photos, documents, knowledge (obsidian)
- HDD (`/mnt/storage2`) - Additional media storage (16TB ext4)
- HDD (`/mnt/cachehdd`) - Caches, metrics

**Core Services:**
- PostgreSQL 16 (pgvector) with PgBouncer - 18 databases consolidated
- MongoDB 7, Redis 7 (shared cache, 16 databases)
- Traefik (reverse proxy), Gluetun (VPN), CrowdSec (IPS)
- Prometheus (30d retention) → Grafana
- Loki (logs)

**Network:** All services on `potatostack` network, socket-proxy for privileged ops.

**Remote Access (Tailscale):**
- `HOST_BIND=127.0.0.1` - Services bind to localhost only
- Tailscale serve proxies localhost ports via HTTPS to `potatostack.tale-iwato.ts.net:<port>`
- Access pattern: `https://potatostack.tale-iwato.ts.net:8093` (miniflux example)
- DO NOT set `HOST_BIND=0.0.0.0` - conflicts with Tailscale serve bindings
- **Tailscale runs as a container** - use `docker exec tailscale tailscale <command>` for CLI operations
- Add new ports to `TAILSCALE_SERVE_PORTS` in docker-compose.yml (both tailscale-https-init and tailscale-https-monitor)

## Code Style

**Shell Scripts:**
- `#!/bin/bash` with `set -euo pipefail`
- snake_case functions, UPPER_CASE constants
- Color output: RED, GREEN, YELLOW, BLUE, NC variables
- OS detection for Linux/Termux compatibility (see scripts/test/stack-test.sh:27-53)
- Always quote variables: `"$VAR"`

**Docker Compose / YAML:**
- 2-space indent, 120 char max line length
- Use anchors/aliases for common configs (x-common-env, x-logging at lines 4-10)
- lowercase-with-hyphens for service names
- UPPER_CASE for environment variables

**File Organization:**
- `scripts/` - init/, setup/, test/, validate/, security/, monitor/, backup/
- `config/` - Service configs in `config/<service_name>/`
- `docs/` - All documentation

## Git Workflow

- Conventional Commits: `type(scope): description`
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Feature branches: `feature/description`, `fix/description`
- Run `make lint && make format` before committing

## Testing Individual Services

```bash
docker ps --filter "name=service_name"    # Check container status
docker logs -f service_name               # View service logs
docker exec service_name command          # Execute in container
curl -I http://localhost:PORT             # Test HTTP endpoint
```

## Key Files

- `docker-compose.yml` - Main orchestration (3284 lines)
- `.env.example` - Environment template (copy to .env)
- `scripts/test/stack-test.sh` - Comprehensive test suite
- `Makefile` - All automation commands

## PostgreSQL Maintenance

**Password is only set on first init.** If you change `POSTGRES_SUPER_PASSWORD` in `.env`, PostgreSQL ignores it because the data directory already exists.

**To reset PostgreSQL password:**
```bash
# 1. Stop postgres and dependents
docker compose stop postgres pgbouncer

# 2. Remove data directory (DESTROYS ALL DATA)
sudo rm -rf /mnt/ssd/docker-data/postgres
sudo mkdir -p /mnt/ssd/docker-data/postgres
sudo chmod 700 /mnt/ssd/docker-data/postgres

# 3. Recreate postgres (will reinitialize with password from .env)
docker compose up -d postgres

# 4. Force recreate ALL postgres-dependent services (they cache the password)
docker compose up -d --force-recreate \
  pgbouncer authentik-server authentik-worker \
  miniflux immich-server grafana postgres-exporter \
  healthchecks karakeep atuin gitea woodpecker-server homarr infisical \
  freqtrade-bot regime-classifier ghostfolio
```

**PostgreSQL-dependent services:** postgres, pgbouncer, authentik-server, authentik-worker, miniflux, immich-server, grafana, postgres-exporter, healthchecks, karakeep, atuin, gitea, woodpecker-server, homarr, infisical, freqtrade-bot, regime-classifier, ghostfolio, baikal

**Data locations:**
- PostgreSQL data: `/mnt/ssd/docker-data/postgres`
- Password env var: `POSTGRES_SUPER_PASSWORD` in `.env`

## Gluetun VPN Network Limitations

Services using `network_mode: "service:gluetun"` have special networking constraints:

**Problem:** Docker's internal DNS (container name resolution) doesn't work through gluetun's VPN network namespace. Services behind gluetun cannot resolve hostnames like `postgres` or `redis-cache`.

**Solutions:**
1. **Use container IPs directly** (current approach for bitmagnet):
   ```yaml
   POSTGRES_HOST: 172.22.0.15  # Get with: docker inspect postgres --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
   ```
   - Fragile: IP changes if postgres is recreated
   - After postgres restart, check IP and update if needed

2. **Expose service on host** and use `host.docker.internal`:
   - Requires binding to `0.0.0.0` (security implications)
   - Add `extra_hosts: ["host.docker.internal:host-gateway"]` to gluetun

**Required gluetun configuration:**
```yaml
# .env - Add ports for VPN firewall
VPN_INPUT_PORTS=51413,50000,6888,3333,3334

# docker-compose.yml - Allow Docker network traffic
FIREWALL_OUTBOUND_SUBNETS: ${LAN_NETWORK:-192.168.178.0/24},172.16.0.0/12
```

**Services behind gluetun:** qbittorrent, slskd, aria2, pyload, spotiflac, stash, bitmagnet, tdl

**Bitmagnet-specific:**
- Uses postgres IP: `172.22.0.15` (check after postgres restart)
- Redis cache disabled (not exposed on host)
- DHT port 3334, WebUI port 3333

## Preferences

- Prioritize code over documentation
- Minimize token usage
- Keep responses concise
