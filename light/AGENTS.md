# PotatoStack Light - Agent Guide

This repository contains a Docker Compose stack for hosting various services on low-RAM devices (2GB Le Potato).

## Build/Lint/Test Commands

**Makefile targets (run from repository root):**

```bash
# Start/stop stack
make up              # Start all services
make down            # Stop all services
make restart         # Restart all services

# Testing
make test            # Run comprehensive integration tests
make test-quick      # Quick health check only

# Linting & Validation
make lint            # Full validation (YAML, shell, compose)
make validate        # Basic docker-compose config validation
make format          # Format shell scripts and YAML files

# Monitoring
make logs SERVICE=   # View logs (SERVICE optional)
make health          # Check health of all services
make resources       # Check resource usage (2GB RAM monitoring)
```

**Running a single test:**
```bash
# Test specific service endpoint
./stack-test-light.sh  # Runs full test suite

# Or manually test a single service
docker logs -f <service_name>
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
```

## Code Style Guidelines

### Shell Scripts

**Shebang:**
- Use `#!/bin/bash` for main scripts (full bash features)
- Use `#!/bin/sh` for init scripts (POSIX compatibility)

**Error Handling:**
```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

**Indentation:** 2 spaces (no tabs)

**Naming:**
- Functions: `snake_case`
- Variables: `UPPER_SNAKE_CASE`
- Local variables: `lower_snake_case`

**Comments:**
- Use descriptive header blocks (70+ char separator)
```bash
################################################################################
# Script Purpose Description
################################################################################
```

**Output:**
- Use color-coded output for scripts:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
echo -e "${GREEN}[OK]${NC} Operation successful"
```

**Executable:** All scripts must be executable: `chmod +x script.sh`

### YAML / Docker Compose

**Indentation:** 2 spaces

**Line width:** 120 characters (per .prettierrc)

**Structure:**
- Services alphabetically ordered (when practical)
- Use descriptive service names
- Include comments for complex configurations

**Environment Variables:**
- Reference via `${VAR_NAME:-default}` for defaults
- All secrets in .env file (NEVER commit .env)

**Comments:** `# Inline comments with space after #`

### Error Handling

**Shell:**
- Always use `set -euo pipefail`
- Wrap commands in functions with error handling
- Return meaningful exit codes

**Docker Compose:**
- Use `restart: unless-stopped`
- Configure health checks for all services
- Set resource limits for 2GB RAM environment

### File Organization

**Shell Scripts:**
- Init scripts: `*-init.sh`
- Setup scripts: `setup-*.sh`
- Test scripts: `*-test.sh`

**Config:**
- `.env.example` - Template (commit this)
- `.env` - Actual values (NEVER commit)
- `docker-compose.yml` - Main stack
- `compose.*.yml` - Environment-specific

### Linting Tools

**Shell:**
- `shellcheck` - Static analysis
- `shfmt` - Formatting

**YAML:**
- `yamllint` - Linting (max 200 line width warning)
- `prettier` - Formatting (120 char width)
- `docker-compose config` - Validation

## Testing Approach

**Integration Tests:** `stack-test-light.sh`
- OS detection (Linux/Termux)
- Drive structure validation
- Container health checks (with OOM detection)
- Service endpoint testing (HTTP)
- Log analysis (errors/warnings/critical)
- Resource usage monitoring

**Validation:** `validate-stack.sh`
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

**Service API Keys:**
- Stored in `/keys/` volume
- Auto-generated on first run if missing
- Format: `<service>-api-key`

**Memory Constraints:**
- Total stack: ~1.2GB RAM
- Monitor for OOM kills in logs
- Use resource limits in docker-compose.yml

**Windows Development:**
- If on Windows (not production), use sshpass for remote operations
- CLAUDE.md rule: "Always check at beginning if you are on windows or linux"
