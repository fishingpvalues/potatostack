# PotatoStack Light - Agent Guide

Docker Compose stack for hosting services on low-RAM devices (2GB Le Potato).

## Build/Lint/Test Commands

**Makefile targets:**

```bash
make up/down/restart    # Start/stop/restart all services
make test               # Run comprehensive integration tests
make test-quick         # Quick health check only
make lint               # Full validation (YAML, shell, compose)
make validate           # Basic docker-compose config validation
make format             # Format shell scripts and YAML files
make logs SERVICE=      # View logs (SERVICE optional)
make health             # Check health of all services
make resources          # Check resource usage (2GB RAM monitoring)
```

**Running a single test:**
```bash
./stack-test-light.sh              # Full test suite
docker logs -f <service_name>      # View specific service logs
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
docker inspect --format='{{.State.Health.Status}}' <container_name>
```

## Code Style Guidelines

### Shell Scripts

- Shebang: `#!/bin/bash` (main scripts) or `#!/bin/sh` (init scripts)
- Error handling: `set -euo pipefail`
- Indentation: 2 spaces (no tabs)
- Naming: Functions `snake_case`, Variables `UPPER_SNAKE_CASE`, Local vars `lower_snake_case`
- Comments: Descriptive header blocks with `70+` char separator
- Output: Color-coded with `RED/GREEN/YELLOW/BLUE/NC` variables
- Executable: All scripts must be executable (`chmod +x`)

```bash
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Script Purpose Description
################################################################################
```

### YAML / Docker Compose

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

### Volume Structure

- `/mnt/storage` - Primary storage (large files, backups, downloads)
- `/mnt/cachehdd` - Cache directory (fast disk, temporary files)
- `shared-keys` - Docker volume for API keys (auto-generated on first run)
- `homepage-config` - Homepage dashboard widgets configuration

### Error Handling Patterns

**Shell:** Wrap commands in functions with error handling, return meaningful exit codes

```bash
check_service() {
    local service=$1
    if ! docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
        echo -e "${RED}[ERROR]${NC} Service $service not running"
        return 1
    fi
}
```

**Docker Compose:** Configure health checks for all services, use `restart: unless-stopped`, set memory/cpu limits

### Linting Tools

**Shell:** `shellcheck` (static analysis), `shfmt` (formatting)
**YAML:** `yamllint` (linting), `prettier` (formatting, 120 char width), `docker-compose config` (validation)

## Testing Approach

**Integration Tests** (`stack-test-light.sh`):
- OS detection (Linux/Termux)
- Drive structure validation
- Container health checks (with OOM detection)
- HTTP endpoint testing
- Log analysis (errors/warnings/critical)
- Resource usage monitoring

**Validation** (`validate-stack.sh`):
- YAML syntax validation (yamllint)
- Docker Compose config validation
- Python YAML parser validation
- Shell script validation (shellcheck)
- Shell script formatting (shfmt)
- Environment variable checks
- File structure validation

## Project-Specific Patterns

**OS Detection:**
```bash
if [ -d "/data/data/com.termux" ]; then
    OS_TYPE="termux"
    DOCKER_CMD="proot-distro login debian --shared-tmp -- docker"
else
    OS_TYPE="linux"
    DOCKER_CMD="docker"
fi
```

**Service API Keys:** Stored in `/keys/` volume, auto-generated if missing, format: `<service>-api-key`

**Memory Constraints:** Total stack ~1.2GB RAM, monitor for OOM kills, use resource limits in docker-compose.yml

**Windows Development:** If on Windows (not production), use sshpass for remote operations. CLAUDE.md rule: "Always check at beginning if you are on windows or linux"

## Common Patterns

**Check if volume file exists:**
```bash
if [ -f "/keys/service-api-key" ]; then
    API_KEY=$(cat /keys/service-api-key)
else
    API_KEY=$(openssl rand -hex 32)
    echo "$API_KEY" > /keys/service-api-key
fi
```

**Wait for service readiness:**
```bash
timeout 10 /init &
sleep 5
killall service 2>/dev/null || true
sleep 2
```
