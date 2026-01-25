# Agent Guidelines for PotatoStack

This repository contains a Docker Compose-based self-hosted infrastructure stack (100 services) optimized for low-power hardware (16GB RAM).

## Build/Lint/Test Commands

### Essential Commands
- `make help` - Display all available commands
- `make up` - Start all services
- `make down` - Stop all services
- `make test` - Full integration tests (scripts/test/stack-test.sh)
- `make test-quick` - Quick health check only
- `make validate` - Docker-compose syntax validation
- `make lint` - YAML, shell, compose linting (yamllint, shellcheck, dclint)
- `make format` - Format all files (shfmt, prettier)
- `make security` - Trivy vulnerability scan
- `make logs SERVICE=name` - View logs for specific service

### Running Single Tests
- `docker ps --filter "name=service_name"` - Check specific container
- `docker logs -f service_name` - View service logs
- `docker exec service_name command` - Execute in container
- `curl -I http://localhost:PORT` - Test HTTP endpoint
- `PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U postgres -c "SELECT version();"` - Test PostgreSQL
- `redis-cli -h localhost ping` - Test Redis
- `mongosh --eval "db.adminCommand('ping')"` - Test MongoDB

### Individual Service Tests
Test HTTP endpoints individually using curl:
`curl -f http://localhost:PORT` where PORT is service-specific (e.g., 8088 for Traefik, 3000 for Grafana)

## Code Style Guidelines

### Shell Scripts
- **Shebang**: `#!/bin/bash` with `set -euo pipefail`
- **Functions**: snake_case (e.g., `detect_os`, `validate_yaml_syntax`)
- **Colors**: RED, GREEN, YELLOW, BLUE, NC variables at top
- **OS detection**: Support Linux/Termux (see scripts/test/stack-test.sh:27-53)
- **Variables**: UPPER_CASE constants, lower_case locals, always quote `"$VAR"`
- **Comments**: Single-line `#`, header `#` with blank line for sections

### Docker Compose / YAML
- **Indent**: 2 spaces, 120 char max line length (200 absolute max)
- **Anchors/aliases**: `x-common-env`, `x-logging` patterns (docker-compose.yml:4-10)
- **Service names**: lowercase-with-hyphens (e.g., `postgres`, `redis-cache`)
- **Environment vars**: UPPER_CASE (e.g., `POSTGRES_USER`, `TZ`)
- **Quotes**: Double quotes for strings, environment vars
- **Section headers**: `#` comments for major service groups

### File Organization
- `scripts/init/` - Initialization scripts
- `scripts/setup/` - Setup/installation scripts
- `scripts/test/` - Test scripts
- `scripts/validate/` - Validation scripts
- `scripts/security/` - Security scanning
- `scripts/monitor/` - Monitoring scripts
- `scripts/backup/` - Backup scripts
- `config/<service_name>/` - Service configs

### Error Handling
- **Shell**: `set -e` exits on error, `|| true` ignores specific errors
- **Return codes**: 0=success, non-zero=failure
- **Error messages**: RED for errors, YELLOW for warnings
- **Validation**: Check inputs/paths before processing

### Naming Conventions
- **Scripts**: `name-action.sh` (e.g., `init-storage.sh`, `security-scan.sh`)
- **Functions**: snake_case descriptive names
- **Docker services**: lowercase-with-hyphens
- **Environment vars**: UPPER_CASE_WITH_UNDERSCORES
- **Directories**: lowercase-with-hyphens

### Formatting & Linting
- **Shell**: shfmt for formatting (`make format-shell`)
- **YAML**: prettier or yq for formatting (`make format-yaml`)
- **Lint**: `make lint` before committing (shellcheck, yamllint, dclint)
- **No trailing whitespace**: Remove all trailing whitespace
- **Final newline**: Ensure single newline at file end

### Types & Data Structures
- **Shell arrays**: Indexed for lists, associative for key-value pairs
- **String manipulation**: `${VAR#prefix}` parameter expansion
- **Numeric operations**: `$(( ))` for arithmetic
- **Defaults**: `${VAR:-default}` for optional vars

### Security
- **Secrets**: Never commit to repo, use .env file
- **Permissions**: 755 for executable scripts
- **Input sanitization**: Validate all user inputs
- **Command injection**: Use arrays: `cmd=(docker exec "$container" ls); "${cmd[@]}"`

### Git Workflow
- **Branch naming**: `feature/description`, `fix/description`
- **Commit messages**: Conventional Commits: `type(scope): description`
- **Pre-commit**: Run `make lint && make format`
- **Types**: feat, fix, docs, style, refactor, perf, test, build, ci, chore

### Testing Strategy
- `make test` - Full integration tests
- `make test-quick` - Quick health check
- `make validate` - Syntax validation
- `make lint` - Comprehensive validation
- `make security` - Vulnerability scan

### Environment
- Copy `.env.example` to `.env`
- Set TZ, PUID, PGID in .env
- Service vars use `SERVICE_VAR` pattern
- Use defaults: `${VAR:-default}` in compose files

### PostgreSQL Notes
- **Password only set on first init** - changing POSTGRES_SUPER_PASSWORD in .env has no effect if data exists
- **Reset password**: Remove `/mnt/ssd/docker-data/postgres` directory, recreate with `docker compose up -d postgres`
- **Force recreate all postgres-dependent services** after password reset: authentik, n8n, miniflux, mealie, immich, grafana, etc.

### Platform Compatibility
- Support Linux and Termux/Android via proot-distro
- Support `docker-compose` (v1) and `docker compose` (v2)
- Use absolute paths, validate directories exist
- POSIX sh when possible, bash when necessary

### Performance Considerations
- Set CPU/memory limits via `deploy.resources` in docker-compose.yml
- Use shared services (Redis, PostgreSQL) to reduce overhead
- Configure tmpfs for temp files to reduce disk I/O
- Hardware acceleration: Jellyfin uses `/dev/dri/renderD128` (docker-compose.yml:415)
