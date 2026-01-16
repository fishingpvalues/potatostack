# Agent Guidelines for PotatoStack

This repository contains a Docker Compose-based self-hosted infrastructure stack optimized for low-power hardware.

## Build/Test Commands

### Primary Commands
- `make help` - Display all available commands
- `make up` - Start all services with docker-compose
- `make down` - Stop all services
- `make restart` - Restart all services
- `make test` - Run comprehensive integration tests (scripts/test/stack-test.sh)
- `make test-quick` - Quick health check without log analysis
- `make lint` - Run SOTA 2025 comprehensive validation (YAML, shell, compose)
- `make format` - Format shell scripts (shfmt) and YAML files (prettier/yq)
- `make validate` - Basic docker-compose.yml syntax validation
- `make security` - Run security vulnerability scan (trivy)
- `make logs` - View logs (use SERVICE=name for specific service)
- `make health` - Check health of all services

### Running Single Tests
The test suite (scripts/test/stack-test.sh) runs all tests by default. To test individual components:
- `docker ps --filter "name=service_name"` - Check specific container status
- `docker logs -f service_name` - View logs for specific service
- `docker exec service_name command` - Execute command in container
- `curl -I http://localhost:PORT` - Test HTTP endpoint availability

### Service-Specific Testing
Test services using `test_service_endpoints()` function in scripts/test/stack-test.sh:347-439
- HTTP endpoint tests with curl
- Database connectivity (PostgreSQL, Redis, MongoDB)
- Healthcheck validation
- Log analysis for errors/warnings

## Code Style Guidelines

### Shell Scripts
- Shebang: Use `#!/bin/bash` for bash-specific features, `#!/bin/sh` for POSIX compliance
- Strict mode: Always use `set -euo pipefail`
- Functions: Use snake_case with descriptive names
- Colors: Define color variables at top (RED, GREEN, YELLOW, BLUE, NC)
- Error handling: Check return codes, use conditional logic with `|| true` where appropriate
- Comments: Use `#` for single-line, `#` followed by blank line for section headers
- Quoting: Always quote variables `"$VAR"` to prevent word splitting
- OS detection: Include detect_os() function for Termux/Linux compatibility (see scripts/test/stack-test.sh:27-53)

### YAML / Docker Compose
- Line length: Max 120 characters
- Indentation: 2 spaces
- Quotes: Use double quotes for strings, single for string interpolation
- Anchors/Aliases: Use for common configurations (x-common-env, x-logging in docker-compose.yml:4-10)
- Section headers: Use `#` with descriptive comments
- Service naming: Use lowercase with hyphens
- Environment variables: UPPER_CASE with underscores
- Network: Define networks explicitly when services communicate
- Volumes: Use named volumes for persistence, bind mounts for configs

### File Organization
- Scripts: In `./scripts/` with purpose-based subdirectories (init, setup, monitor, test, validate, security, import, backup)
- Config files: In `./config/` directory
- Service configs: In `./config/<service_name>/` subdirectories
- Documentation: Markdown files in `./docs/`
- Tests: In `./tests/` directory

### Error Handling
- Shell: Use `set -e` to exit on error, `|| true` to ignore specific errors
- Functions should return meaningful exit codes (0 = success, non-zero = failure)
- Log errors to report files in addition to console output
- Use try/catch patterns: `if command; then success; else error_handling; fi`

### Naming Conventions
- Shell scripts: `name-action.sh` (e.g., `scripts/init/init-storage.sh`, `scripts/security/security-scan.sh`)
- Functions: snake_case descriptive names (e.g., `detect_os`, `validate_yaml_syntax`)
- Variables: UPPER_CASE for constants, lower_case for local variables
- Docker services: lowercase-with-hyphens (e.g., `postgres`, `redis-cache`)
- Environment variables: UPPER_CASE (e.g., `POSTGRES_USER`, `TZ`)

### Import/Include Patterns
- Docker Compose: Use `&` for anchors, `*` for aliases to reuse configs
- Shell scripts: Source common functions with `. ./script.sh` or `source script.sh`
- Avoid duplication: Use YAML anchors and shell functions to eliminate repeated code

### Comments and Documentation
- Shell scripts: Add header comment block with purpose, date, author optional
- Complex logic: Add inline comments explaining WHY, not WHAT
- YAML: Add section comments before major blocks
- Environment variables: Document required variables in .env.example

### Security Best Practices
- Never commit secrets or credentials to repository
- Use .env.example as template, .gitignore to protect .env
- Generate secrets at runtime (see scripts/init/init-storage.sh:72-99)
- Run `make security` to scan for vulnerabilities before committing
- Use `make validate` to check docker-compose.yml syntax
- Validate with shellcheck: `shellcheck script.sh`
- Format with shfmt: `shfmt -w script.sh`

### Git Workflow
- Feature branches: `feature/description` or `fix/issue-description`
- Commit messages: Conventional Commits format (type: description)
- PR template: Use `.github/pull_request_template.md`
- Code owners: Defined in `.github/CODEOWNERS`
- Documentation: Keep docs/README.md, docs/QUICK_START.md updated with changes

### Testing Strategy
- Validation: `make validate` - Basic docker-compose syntax check
- Linting: `make lint` - Comprehensive validation suite
- Integration tests: `make test` - Full stack testing
- Quick checks: `make test-quick` - Health check only
- Security: `make security` - Vulnerability scanning

### Logging and Monitoring
- Container logs: Use JSON-file driver with rotation (see x-logging:1-8)
- Test reports: Generated with timestamp (e.g., `validation-report-YYYYMMDD-HHMMSS.txt`)
- Colors: Use consistent color codes for console output (RED=error, GREEN=success, YELLOW=warning, BLUE=info)
- Report files: Save to working directory with descriptive names

### Platform Compatibility
- OS detection: Support Linux and Termux/Android via proot-distro
- Docker commands: Support both `docker-compose` (v1) and `docker compose` (v2)
- Path handling: Use absolute paths, validate directories exist before mounting
- Shell compatibility: Use POSIX sh when possible, bash when necessary

### Code Quality
- Run `make format` before committing changes
- Fix all `make lint` warnings/errors
- Ensure `make validate` passes
- Test with `make test-quick` on changes affecting container startup
- Documentation must be updated with functional changes

### Environment Configuration
- Copy `.env.example` to `.env` before running stack
- Define TZ (timezone), PUID/PGID (user/group IDs) in .env
- Service-specific variables use SERVICE_VAR pattern
- Use defaults in docker-compose.yml: `${VAR:-default}`

### Performance Considerations
- Set CPU/memory limits via `deploy.resources` in docker-compose.yml
- Use shared services (Redis, PostgreSQL) to reduce overhead
- Configure tmpfs for temporary files to reduce disk I/O
- Use hardware acceleration where available (e.g., Quick Sync for Jellyfin)
