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

#### Container Status & Health
- `docker ps --filter "name=service_name"` - Check specific container status
- `docker logs -f service_name` - View logs for specific service
- `docker exec service_name command` - Execute command in container
- `curl -I http://localhost:PORT` - Test HTTP endpoint availability

#### Service-Specific Testing
Test services using `test_service_endpoints()` function in scripts/test/stack-test.sh:347-439
- HTTP endpoint tests with curl (GET/HEAD requests)
- Database connectivity (PostgreSQL, Redis, MongoDB)
- Healthcheck validation via Docker API
- Log analysis for errors/warnings/critical messages

#### Database Testing
- PostgreSQL: `PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER -d postgres -c "SELECT version();"`
- Redis: `redis-cli -h localhost ping`
- MongoDB: `mongosh --eval "db.runCommand('ping')"`

#### Quick Validation Commands
- `make validate-compose` - Validate docker-compose.yml syntax only
- `make lint-yaml` - Lint YAML files with yamllint
- `make lint-shell` - Lint shell scripts with shellcheck
- `make health` - Check all service health statuses

## Code Style Guidelines

### Shell Scripts
- **Shebang**: Use `#!/bin/bash` for bash-specific features, `#!/bin/sh` for POSIX compliance
- **Strict mode**: Always use `set -euo pipefail` for robust error handling
- **Functions**: Use snake_case with descriptive names (e.g., `detect_os`, `validate_yaml_syntax`)
- **Colors**: Define color variables at top (RED, GREEN, YELLOW, BLUE, NC) for consistent output
- **Error handling**: Check return codes, use conditional logic with `|| true` where appropriate
- **Comments**: Use `#` for single-line, `#` followed by blank line for section headers
- **Quoting**: Always quote variables `"$VAR"` to prevent word splitting and globbing
- **OS detection**: Include detect_os() function for Termux/Linux compatibility (see scripts/test/stack-test.sh:27-53)
- **Variable naming**: UPPER_CASE for constants, lower_case for local variables
- **Function parameters**: Use positional parameters ($1, $2) with descriptive names in comments
- **Exit codes**: Use meaningful exit codes (0=success, 1=error, 2=invalid usage)

### YAML / Docker Compose
- **Line length**: Max 200 characters (yamllint config), aim for 120 for readability
- **Indentation**: 2 spaces consistently
- **Quotes**: Use double quotes for strings, single quotes for string interpolation
- **Anchors/Aliases**: Use `&` for anchors, `*` for aliases to reuse common configurations
- **Section headers**: Use `#` with descriptive comments for major sections
- **Service naming**: lowercase-with-hyphens (e.g., `postgres`, `redis-cache`)
- **Environment variables**: UPPER_CASE with underscores (e.g., `POSTGRES_USER`, `TZ`)
- **Networks**: Define networks explicitly when services communicate
- **Volumes**: Use named volumes for persistence, bind mounts for configs
- **Resource limits**: Set CPU/memory limits via `deploy.resources` for production
- **Healthchecks**: Define healthchecks for critical services with appropriate intervals
- **Labels**: Use consistent labeling for service discovery and monitoring

### File Organization
- **Scripts**: In `./scripts/` with purpose-based subdirectories (init, setup, monitor, test, validate, security, import, backup)
- **Config files**: In `./config/` directory with service-specific subdirectories
- **Service configs**: In `./config/<service_name>/` subdirectories
- **Documentation**: Markdown files in `./docs/` directory
- **Environment files**: `.env.example` as template, `.env` for local overrides (gitignored)
- **Test files**: Integration tests in `./scripts/test/`, validation scripts in `./scripts/validate/`

### Formatting & Linting
- **Shell scripts**: Use shfmt for formatting (`make format-shell`)
- **YAML files**: Use prettier or yq for formatting (`make format-yaml`)
- **Dockerfiles**: Use dockfmt for formatting (`make format-dockerfiles`)
- **Linting**: Run `make lint` before committing (shellcheck, yamllint, dclint)
- **Line length**: 200 chars max for YAML, aim for 120; shell scripts follow shfmt defaults
- **Trailing whitespace**: Remove all trailing whitespace
- **Final newlines**: Ensure files end with a single newline

### Error Handling
- **Shell**: Use `set -e` to exit on error, `|| true` to ignore specific errors
- **Functions**: Return meaningful exit codes (0=success, non-zero=failure)
- **Error messages**: Use consistent color coding (RED for errors, YELLOW for warnings)
- **Log errors**: Write to report files and console output
- **Try/catch patterns**: Use `if command; then success; else error_handling; fi`
- **Resource cleanup**: Use trap commands for cleanup on script exit
- **Input validation**: Validate inputs before processing

### Naming Conventions
- **Shell scripts**: `name-action.sh` (e.g., `scripts/init/init-storage.sh`, `scripts/security/security-scan.sh`)
- **Functions**: snake_case descriptive names (e.g., `detect_os`, `validate_yaml_syntax`)
- **Variables**: UPPER_CASE for constants and environment vars, lower_case for local variables
- **Docker services**: lowercase-with-hyphens (e.g., `postgres`, `redis-cache`)
- **Environment variables**: UPPER_CASE with underscores (e.g., `POSTGRES_USER`, `TZ`)
- **Config files**: lowercase-with-hyphens (e.g., `traefik-config.yml`)
- **Directories**: lowercase-with-hyphens for consistency

### Import/Include Patterns
- **Docker Compose**: Use `&` for anchors, `*` for aliases to reuse common configurations
- **Shell scripts**: Source common functions with `. ./script.sh` or `source script.sh`
- **Avoid duplication**: Use YAML anchors and shell functions to eliminate repeated code
- **Modular design**: Break large scripts into smaller, reusable functions
- **Path handling**: Use absolute paths when possible, validate directory existence

### Types & Data Structures
- **Shell arrays**: Use indexed arrays for lists, associative arrays for key-value pairs
- **String manipulation**: Use parameter expansion `${VAR#prefix}` instead of external tools when possible
- **Numeric operations**: Use `$(( ))` for arithmetic, validate numeric inputs
- **Boolean logic**: Use 0/non-zero exit codes for boolean operations
- **Configuration**: Use environment variables with defaults `${VAR:-default}`

### Security Best Practices
- **Secrets**: Never commit secrets, use environment variables or external secret management
- **File permissions**: Set appropriate permissions on scripts (755 for executables)
- **Input sanitization**: Validate and sanitize all user inputs
- **Command injection**: Use arrays for safe command execution: `cmd=(docker exec "$container" ls); "${cmd[@]}"`
- **Privilege escalation**: Avoid running scripts as root unless absolutely necessary

### Comments and Documentation
- **Shell scripts**: Add header comment block with purpose, usage, and date
- **Complex logic**: Add inline comments explaining WHY, not WHAT the code does
- **YAML**: Add section comments before major blocks using `#` headers
- **Environment variables**: Document all required variables in .env.example with descriptions
- **Function documentation**: Use comment blocks above functions describing parameters and return values
- **API endpoints**: Document service endpoints and their purposes in comments

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

### Development Workflow
- **Pre-commit**: Always run `make lint && make format` before committing
- **Testing**: Run `make test-quick` for changes affecting container startup
- **Documentation**: Update docs/README.md and docs/AGENTS.md with functional changes
- **Branch naming**: Use `feature/description` or `fix/issue-description` for branches
- **Commit messages**: Follow Conventional Commits: `type(scope): description`
- **Code review**: Ensure all automated checks pass before requesting review
- **Environment setup**: Copy `.env.example` to `.env` and configure service-specific variables

### Tooling & Dependencies
- **Required tools**: docker, docker-compose/docker compose, make
- **Optional tools**: yamllint, shellcheck, shfmt, prettier, yq, trivy, hadolint, dockfmt
- **Validation**: Run `make doctor` to check tool availability and versions
- **Updates**: Keep tools updated to latest versions for security and feature improvements
