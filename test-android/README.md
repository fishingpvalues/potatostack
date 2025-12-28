# PotatoStack Android/Termux Tests

Test suite for validating PotatoStack configurations on unrooted Android devices using Termux and proot.

## Prerequisites

```bash
pkg install docker docker-compose proot -y
```

## Test Scripts

### Main Stack Test (Config Validation)
Tests the full PotatoStack (16GB RAM optimized) with SOTA 2025 database settings.

```bash
cd test-android
./test-main-stack.sh
```

**Tests:**
- Termux environment validation
- Required packages check
- Docker Compose syntax validation
- Database SOTA 2025 settings (PostgreSQL, MongoDB, Redis)
- Redis cache integration (N8n, Gitea)
- Orphaned services detection
- Service count and health
- Memory limits configuration
- Network setup
- Proot functionality
- Docker accessibility

### Runtime Test (Actual Containers)
Actually starts containers and performs real healthchecks.

```bash
cd test-android
./test-runtime.sh
```

**Tests:**
- Docker daemon running
- Start core databases (postgres, mongo, redis-cache)
- PostgreSQL healthcheck + SOTA settings verification (1GB buffers)
- PostgreSQL parallel workers verification
- MongoDB healthcheck + cache size verification (1.5GB)
- Redis healthcheck + LFU policy verification
- Redis maxmemory verification (512MB)
- Start Redis-integrated services (gitea, n8n)
- Gitea Redis connection verification
- N8n Redis connection verification
- Network connectivity tests
- Resource usage monitoring
- Container count validation

**⚠️ Note:** Runtime tests actually start containers and will cleanup on exit.

### Light Stack Test
Tests the lightweight PotatoStack (2GB RAM optimized for Le Potato).

```bash
cd test-android
./test-light-stack.sh
```

**Tests:**
- Environment validation
- Lean service count (<20 services)
- Memory optimization (all services <512M)
- Essential services (Homepage, Gluetun, Syncthing, Kopia, Vaultwarden)
- Dual-disk caching setup
- VPN killswitch configuration
- Auto-updates (Watchtower)
- Dashboard configuration
- Resource reservations
- Estimated RAM usage calculation

## Running All Tests

```bash
cd test-android
./run-all-tests.sh
```

## Proot Usage

All tests use proot to simulate root access on unrooted Android devices:
- No root/bootloader unlock required
- Safe containerized testing
- Docker daemon access via proot

## Test Output

Tests use colored output:
- 🟢 Green: Passed tests
- 🔴 Red: Failed tests
- 🟡 Yellow: Test categories
- 🔵 Blue: Information

## Expected Results

### Main Stack
- ~90+ services
- PostgreSQL: 1GB shared_buffers
- MongoDB: 1.5GB cache
- Redis: LFU eviction policy
- N8n & Gitea with Redis integration

### Light Stack
- <20 services
- All services <512M memory
- Total RAM usage <1800M
- Dual-disk caching
- VPN killswitch active
