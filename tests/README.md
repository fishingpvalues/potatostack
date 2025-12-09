# PotatoStack Test Suite

Automated testing suite for validating the PotatoStack Docker Compose configuration on any PC.

## Overview

This test suite allows you to:
- Test the entire stack without a Le Potato SBC
- Validate configuration files before deployment
- Emulate the required drive structure
- Check service health and availability
- Run integration tests on any development machine

## Quick Start

```bash
# Make scripts executable
chmod +x tests/*.sh

# Run complete test suite
./tests/test-stack.sh

# Run with cleanup (removes containers after test)
./tests/test-stack.sh --cleanup

# Run with optional profiles
./tests/test-stack.sh --profile apps,heavy

# Skip drive setup if already done
./tests/test-stack.sh --skip-setup
```

## Test Scripts

### 1. `setup-test-drives.sh`
Creates the directory structure to emulate `/mnt/seconddrive` and `/mnt/cachehdd`.

**Usage:**
```bash
sudo ./tests/setup-test-drives.sh
```

**What it does:**
- Creates `test-mounts/seconddrive/` with all required subdirectories
- Creates `test-mounts/cachehdd/` for cache storage
- Optionally creates symbolic links (requires sudo) at `/mnt/`

**Without sudo:**
- Creates directories but skips symbolic links
- You'll need to update docker-compose volumes manually

### 2. `validate-compose.sh`
Validates the `docker-compose.yml` syntax and configuration.

**Usage:**
```bash
./tests/validate-compose.sh
```

**Checks:**
- Docker Compose installation
- Syntax validation
- Environment variable definitions
- Required configuration directories
- Volume mount points

### 3. `check-health.sh`
Performs health checks on running services.

**Usage:**
```bash
./tests/check-health.sh
```

**Tests:**
- Container status (running/stopped)
- HTTP endpoints availability
- Service health checks
- Response codes

### 4. `test-stack.sh` (Main Test Runner)
Orchestrates the complete testing workflow.

**Usage:**
```bash
./tests/test-stack.sh [OPTIONS]

Options:
  --cleanup           Stop and remove all containers after tests
  --skip-setup        Skip drive setup (assumes already done)
  --profile PROFILES  Start with specific profiles (e.g., 'apps,heavy')
  --wait SECONDS      Wait time for services to start (default: 120)
  --help              Show help message
```

**Workflow:**
1. Setup test drives
2. Validate docker-compose configuration
3. Launch the Docker Compose stack
4. Wait for services to initialize
5. Run health checks
6. Optional cleanup

## Test Configuration

### Environment File
The test suite uses `.env.test` with fantasy/test values:
- All passwords are test values (NEVER use in production!)
- Services bind to `HOST_ADDR=127.0.0.1` for security
- Tags set to `latest` for testing

### Drive Emulation
Test drives are created in:
```
/home/danielf/workdir/potatostack/test-mounts/
├── seconddrive/          # Emulates /mnt/seconddrive
│   ├── kopia/
│   ├── nextcloud/
│   ├── gitea/
│   └── ...
└── cachehdd/             # Emulates /mnt/cachehdd
    ├── torrents/
    └── soulseek/
```

## Service Profiles

The stack supports different profiles for optional services:

### Core Services (No Profile)
Always started:
- VPN (Gluetun)
- P2P (qBittorrent, slskd)
- Storage (Nextcloud, Kopia)
- Monitoring (Prometheus, Grafana, Loki)
- Management (Portainer, Diun, Dozzle)
- Infrastructure (MariaDB, PostgreSQL, Redis)

### Profile: `apps`
Additional services:
- Vaultwarden (password manager)
- Vaultwarden backup

### Profile: `heavy`
Memory-intensive services:
- Firefly III (finance)
- Firefly worker & cron
- FinTS importer
- Immich (photos)
- Authelia (SSO)

### Profile: `monitoring-extra`
Extra monitoring tools:
- Netdata
- Blackbox Exporter
- Speedtest Exporter
- Fritzbox Exporter
- Uptime Kuma

### Running with Profiles
```bash
# Start with apps profile
./tests/test-stack.sh --profile apps

# Multiple profiles
./tests/test-stack.sh --profile apps,heavy

# All services
./tests/test-stack.sh --profile apps,heavy,monitoring-extra
```

## Example Test Scenarios

### Scenario 1: Quick Validation
Test configuration without starting services:
```bash
./tests/validate-compose.sh
```

### Scenario 2: Core Stack Test
Test core services only:
```bash
./tests/test-stack.sh --wait 180 --cleanup
```

### Scenario 3: Full Stack Test
Test all services including optional ones:
```bash
sudo ./tests/test-stack.sh --profile apps,heavy,monitoring-extra --wait 300
```

### Scenario 4: Development Testing
Test without cleanup to inspect services:
```bash
./tests/test-stack.sh --wait 120
# Services keep running for inspection
# Access at http://127.0.0.1:PORT
```

### Scenario 5: Iterative Testing
After initial setup, skip drive creation:
```bash
# First run
./tests/test-stack.sh

# Make changes to docker-compose.yml...

# Subsequent runs
./tests/test-stack.sh --skip-setup
```

## Troubleshooting

### Permission Errors
If you get permission errors:
```bash
# Option 1: Run with sudo
sudo ./tests/test-stack.sh

# Option 2: Fix Docker permissions
sudo usermod -aG docker $USER
# Log out and back in
```

### VPN Connection Issues
The VPN (Gluetun) will fail to connect with fantasy credentials, which is expected:
- The container will start but VPN won't connect
- qBittorrent and slskd will be accessible but not routed through VPN
- This is normal for testing - they'll work fine with real credentials

### Service Startup Time
Some services take longer to start:
- Increase wait time: `--wait 300`
- Check logs: `docker compose logs -f [service-name]`
- Some services depend on database initialization

### Memory Issues
If running all profiles on limited RAM:
```bash
# Test in stages
./tests/test-stack.sh --profile apps --wait 180
# Stop: docker compose down
./tests/test-stack.sh --profile heavy --wait 180
```

### Port Conflicts
If ports are already in use:
- Stop conflicting services
- Or modify `HOST_BIND` in `.env.test`

## Continuous Integration

For CI/CD pipelines:
```bash
#!/bin/bash
# CI test script
./tests/test-stack.sh --cleanup --wait 240
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✓ All tests passed"
else
    echo "✗ Tests failed"
    # Optional: Upload logs
    docker compose logs > test-logs.txt
fi

exit $exit_code
```

## Cleanup

### Remove Test Containers
```bash
docker compose --env-file .env.test down -v
```

### Remove Test Drives
```bash
# Remove symbolic links (requires sudo)
sudo rm -f /mnt/seconddrive /mnt/cachehdd

# Remove test directories
rm -rf test-mounts/
```

### Complete Cleanup
```bash
# Stop and remove everything
docker compose --env-file .env.test down -v --remove-orphans

# Remove test mounts
sudo rm -f /mnt/seconddrive /mnt/cachehdd
rm -rf test-mounts/

# Remove unused Docker resources
docker system prune -af --volumes
```

## Security Notes

⚠️ **IMPORTANT**: The `.env.test` file contains **FANTASY/TEST VALUES ONLY**

- Never use test credentials in production
- Never commit real credentials to git
- The test environment binds to `127.0.0.1` (localhost only)
- For production, use `.env` with real values and proper security

## Contributing

When adding new services:
1. Update `.env.test` with fantasy values
2. Add health checks to `check-health.sh`
3. Update service list in this README
4. Test with: `./tests/test-stack.sh`

## Support

For issues:
1. Check service logs: `docker compose logs [service]`
2. Verify configuration: `./tests/validate-compose.sh`
3. Review health output: `./tests/check-health.sh`
4. Check Docker daemon: `docker ps`
