# Agent Guidelines for PotatoStack

This repository contains a Docker Compose-based self-hosted infrastructure stack (100 services) optimized for low-power hardware (16GB RAM).

## Build/Lint/Test Commands

### Essential Commands
- `make help` - Display all available commands
- `make up` - Start all services (runs init containers first)
- `make down` - Stop all services
- `make ps` - List running containers with ports
- `make logs SERVICE=name` - View logs for specific service
- `make health` - Check health status of all services

### Testing Commands
- `make test` - Full integration tests (scripts/test/stack-test.sh)
- `make test-quick` - Quick health check only (no log analysis)
- `make test-killswitch` - Test VPN killswitch functionality
- `make containers-check` - Fail if any containers are unhealthy/exited

### Running Single Tests
Test a specific HTTP endpoint:
```bash
curl -f http://localhost:PORT          # Generic HTTP test
curl -I http://localhost:PORT          # HEAD request test
curl -fsS http://localhost:8088/ping   # Traefik ping endpoint
```

Test a specific service:
```bash
# Check container status
docker ps --filter "name=service_name"
docker logs -f service_name            # Follow logs
docker exec service_name command       # Execute command in container

# Test databases
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U postgres -c "SELECT version();"
redis-cli -h localhost ping
mongosh --eval "db.adminCommand('ping')"
```

### Validation & Linting
- `make validate` - Docker-compose syntax + required files check
- `make validate-compose` - Validate docker-compose.yml only
- `make lint` - Full linting (YAML, shell, compose, Dockerfiles)
- `make lint-yaml` - Lint YAML files with yamllint
- `make lint-shell` - Lint shell scripts (shellcheck + shfmt)
- `make lint-compose` - Lint docker-compose.yml (dclint)
- `make lint-full` - Full validation suite with reporting
- `make security` - Security vulnerability scan (trivy)

### Formatting
- `make format` - Format all files (shell + YAML + Dockerfiles)
- `make format-shell` - Format shell scripts with shfmt
- `make format-yaml` - Format YAML files with prettier/yq
- `make format-dockerfiles` - Format Dockerfiles with dockfmt

## Code Style Guidelines

### Shell Scripts
- **Shebang**: `#!/bin/bash` with `set -euo pipefail` (or `#!/bin/sh` with `set -eu` for POSIX)
- **Functions**: snake_case (e.g., `detect_os`, `validate_yaml_syntax`)
- **Colors**: Define RED, GREEN, YELLOW, BLUE, NC at top for output
- **Variables**: UPPER_CASE for constants/exports, lower_case for locals
- **Quoting**: Always quote variables: `"$VAR"` not `$VAR`
- **OS detection**: Support Linux and Termux/Android via proot-distro
- **Comments**: Use `################################################################################` for file headers, `# Section` for sections

### Docker Compose / YAML
- **Indent**: 2 spaces, max 120 chars (200 absolute max per .yamllint)
- **Service names**: lowercase-with-hyphens (e.g., `postgres`, `redis-cache`)
- **Environment vars**: UPPER_CASE in .env, referenced as `${VAR:-default}`
- **Quotes**: Double quotes for strings, especially environment variables
- **Anchors/aliases**: Use `x-common-env`, `x-logging` for reusable configs
- **Section headers**: Use `################################################################################` comments for major groups

### File Organization
```
scripts/
  init/       - Initialization scripts (storage-init, service configs)
  setup/      - Setup/installation scripts (ufw, hardening, autostart)
  test/       - Test scripts (stack-test.sh, test-killswitch.sh)
  validate/   - Validation scripts (validate-stack.sh)
  security/   - Security scanning (security-scan.sh)
  monitor/    - Monitoring scripts (health, connectivity, queue)
  backup/     - Backup scripts (stack-snapshot.sh)
  hooks/      - Service hooks (post-download, post-torrent)
  import/     - Import scripts (grafana dashboards)
  webhooks/   - Webhook handlers
config/<service>/ - Service-specific configuration files
```

### Naming Conventions
- **Scripts**: `name-action.sh` (e.g., `init-storage.sh`, `security-scan.sh`)
- **Functions**: snake_case descriptive names
- **Docker services**: lowercase-with-hyphens
- **Environment vars**: UPPER_CASE_WITH_UNDERSCORES
- **Directories**: lowercase-with-hyphens

### Error Handling
- **Shell**: `set -e` exits on error, `|| true` to ignore specific errors
- **Return codes**: 0=success, non-zero=failure
- **Error messages**: Use colors - RED for errors, YELLOW for warnings, GREEN for success
- **Validation**: Check inputs/paths exist before processing

### Types & Data Structures
- **Shell arrays**: Indexed for lists, associative for key-value pairs
- **String manipulation**: Use `${VAR#prefix}` parameter expansion
- **Numeric operations**: Use `$(( ))` for arithmetic
- **Defaults**: Use `${VAR:-default}` for optional variables

### Security
- **Secrets**: Never commit to repo - use .env file only
- **Permissions**: 755 for executable scripts
- **Input sanitization**: Validate all user inputs
- **Command injection**: Use arrays: `cmd=(docker exec "$container" ls); "${cmd[@]}"`

### Git Workflow
- **Branch naming**: `feature/description`, `fix/description`
- **Commit messages**: Conventional Commits: `type(scope): description`
- **Pre-commit**: Run `make lint && make format`
- **Types**: feat, fix, docs, style, refactor, perf, test, build, ci, chore

### Platform Compatibility
- Support Linux and Termux/Android via proot-distro
- Support `docker-compose` (v1) and `docker compose` (v2)
- Use absolute paths, validate directories exist
- POSIX sh when possible, bash when necessary

### Performance Considerations
- Set CPU/memory limits via `deploy.resources` in docker-compose.yml
- Use shared services (Redis, PostgreSQL) to reduce overhead
- Configure tmpfs for temp files to reduce disk I/O
- Hardware acceleration: Jellyfin uses `/dev/dri/renderD128`

### Storage Layout
- SSD (`/mnt/ssd/docker-data`) - Databases, configs, critical data
- HDD (`/mnt/storage`) - Media, photos, documents, knowledge (obsidian)
- HDD (`/mnt/storage2`) - Additional media storage (16TB ext4, UUID: fa11a826-bbc1-4bc3-a612-f1c2924514cc)
- HDD (`/mnt/cachehdd`) - Caches, metrics

### PostgreSQL Notes
- **Password only set on first init** - changing POSTGRES_SUPER_PASSWORD in .env has no effect if data exists
- **Reset password**: Remove `/mnt/ssd/docker-data/postgres` directory, recreate with `docker compose up -d postgres`
- **Force recreate** all postgres-dependent services after password reset: authentik, n8n, miniflux, immich, grafana, etc.

### Environment Setup
1. Copy `.env.example` to `.env`
2. Set TZ, PUID, PGID in .env
3. Service vars use `SERVICE_VAR` pattern
4. Use defaults: `${VAR:-default}` in compose files

### Firewall Management
- `make firewall-install` - Install UFW with Docker integration
- `make firewall-apply` - Apply PotatoStack firewall rules
- `make firewall-status` - Show current firewall status
- `make firewall-allow` - Allow a Docker container port (interactive)
- `make firewall-deny` - Deny a Docker container port (interactive)

### Troubleshooting
- `make doctor` - Check tool availability and versions
- `make containers-unhealthy` - List unhealthy containers
- `make containers-exited` - List exited containers
- `make resources` - Check resource usage (CPU/Memory)
- `make fix-permissions` - Fix named volume permissions
- `make recovery` - Full recovery after crash (fix Docker + start stack)

## Gluetun VPN Network Constraints

**IMPORTANT:** Services using `network_mode: "service:gluetun"` cannot resolve Docker container hostnames (e.g., `postgres`, `redis-cache`) because they use gluetun's VPN DNS, not Docker's internal DNS.

### Affected Services
qbittorrent, slskd, aria2, pyload, spotiflac, stash, tdl

### Workarounds

1. **Use container IP directly** (current approach):
   ```bash
   # Get postgres IP
   docker inspect postgres --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
   # Returns: 172.22.0.15
   ```
   Then use in docker-compose: `POSTGRES_HOST: 172.22.0.15`

   **Caveat:** IP may change after container recreation - check and update if needed.

2. **Expose service on host**: Bind to `0.0.0.0` and use `host.docker.internal` (security implications).

### Required Configuration

**In `.env`:**
```bash
VPN_INPUT_PORTS=51413,50000,6888  # Add ports for VPN firewall
```

**In `docker-compose.yml` (gluetun service):**
```yaml
FIREWALL_OUTBOUND_SUBNETS: ${LAN_NETWORK:-192.168.178.0/24},172.16.0.0/12
extra_hosts:
  - "host.docker.internal:host-gateway"
```

