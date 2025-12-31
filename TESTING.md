# Stack Testing & Automation

## Quick Start

```bash
# Using Makefile (recommended)
make test              # Run comprehensive integration tests
make test-quick        # Run quick health check only
make health            # Check service health status

# Direct script execution
./stack-test.sh
```

## Features

### Automated Stack Testing (`stack-test.sh`)
Based on **SOTA 2025 Docker Compose testing best practices**, testing ALL 65+ services:

#### Core Test Categories
- **OS Detection**: Automatically detects Termux/Android (proot) or Linux (native docker)
- **Drive Structure Validation**: Verifies mount points (/mnt/storage, /mnt/ssd, /mnt/cachehdd)
- **Health Check Validation**: Waits up to 3 minutes for all containers to become healthy
- **Database Connectivity**: Tests PostgreSQL, pgBouncer, Redis, MongoDB, Immich-Postgres
- **HTTP Endpoint Testing**: Tests ALL 40+ web services including:
  - Monitoring: Grafana, Prometheus, Alertmanager, Uptime-Kuma, Netdata, cAdvisor
  - Media: Sonarr, Radarr, Lidarr, Readarr, Bazarr, Prowlarr, Jellyfin, Jellyseerr, qBittorrent, Audiobookshelf, Pinchflat, Slskd
  - Productivity: Homarr, Paperless-ngx, Linkding, Miniflux, Actual-Budget, Stirling-PDF
  - Development: Gitea, Code-Server
  - Automation: n8n, Healthchecks
  - Security: Vaultwarden, Authentik, AdGuard Home
  - Other: Syncthing, Open-WebUI, Immich, Kopia, Maintainerr, Atuin, IT-Tools
- **Log Analysis**: Greps all container logs for warnings/errors/critical issues
- **Resource Monitoring**: CPU and memory usage per container
- **Consolidated Summary**: Single integrated report with overall PASS/WARN/FAIL status

#### Test Sources (SOTA 2025)
- [Docker Compose Testing Guide](https://medium.com/@dandigam.raju/docker-compose-for-full-stack-testing-a-step-by-step-guide-7e353baf639e)
- [Testcontainers Integration](https://collabnix.com/testcontainers-tutorial-complete-guide-to-integration-testing-with-docker-2025/)
- [Health Check Best Practices](https://last9.io/blog/docker-compose-health-checks/)
- [Testcontainers Best Practices](https://www.docker.com/blog/testcontainers-best-practices/)

### Make Targets
- `make test` - Full integration test suite (starts stack, runs all tests)
- `make test-quick` - Quick health check without log analysis
- `make health` - Detailed health status of all services
- `make up` - Start all services
- `make down` - Stop all services
- `make logs SERVICE=name` - View logs for specific service
- `make ps` - List all running containers
- `make validate` - Validate docker-compose.yml syntax

### Renovate Bot Configuration
Automatic dependency updates for Docker images configured in `renovate.json`:
- Weekly update checks (Monday 6am)
- Grouped updates: databases, *arr stack, network/security
- Security vulnerability alerts
- Digest pinning for reproducibility

## GitHub Actions Workflows

### Stack Testing (`stack-test.yml`)
Runs on:
- Push to main
- Pull requests
- Weekly schedule (Monday 6am)
- Manual trigger

### Renovate (`renovate.yml`)
- Weekly automated dependency updates
- Requires `RENOVATE_TOKEN` secret (optional, falls back to `GITHUB_TOKEN`)

## Testing Best Practices

Based on 2025 industry standards:
1. **Isolation**: Each test gets clean environment
2. **Health Checks**: Services verify readiness before dependent services start
3. **Log Analysis**: Automated grep for error patterns
4. **CI/CD Integration**: GitHub Actions for continuous testing
5. **Resource Monitoring**: Track CPU/memory usage

## Report Structure

```
Stack Test Report
├── OS Detection & Docker Command
├── Stack Startup Status
├── Health Check (container status)
├── Log Analysis
│   ├── Per-container warning/error counts
│   └── Sample issue excerpts
├── Resource Usage (CPU/Memory)
└── Network Connectivity Tests
```

## Customization

### Add Custom Log Patterns
Edit `stack-test.sh` line ~90-95 to add patterns:
```bash
custom=$(grep -iE "your_pattern" "$LOG_DIR/${container}.log" 2>/dev/null | wc -l)
```

### Modify Renovate Schedule
Edit `renovate.json` schedule field:
```json
"schedule": ["before 6am on monday"]
```

### Change Test Services
Modify network connectivity tests in `stack-test.sh` (~170-180) to test your specific services.

## Logs Location
- Test reports: `stack-test-report-YYYYMMDD-HHMMSS.txt`
- Container logs: `./test-logs/*.log`

## Sources
- [Docker Compose Testing Guide](https://medium.com/@dandigam.raju/docker-compose-for-full-stack-testing-a-step-by-step-guide-7e353baf639e)
- [Renovate Docker Compose Docs](https://docs.renovatebot.com/modules/manager/docker-compose/)
- [Docker Compose Best Practices 2025](https://toxigon.com/docker-compose-best-practices-2025)
