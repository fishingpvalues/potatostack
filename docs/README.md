# PotatoStack - Production Self-Hosted Infrastructure

**Intel N250 Mini PC | 16GB RAM | SOTA 2025**

Complete self-hosted stack with 100 services optimized for low-power hardware.

## Quick Stats

- **Services**: 99 total (news-pipeline background service)
- **RAM Usage**: 12-13GB peak (out of 16GB)
- **Storage**: SSD (Docker data) + HDD (media/cache)
- **Monitoring**: Prometheus (30d retention) + Grafana

## Core Components

### Databases
- PostgreSQL 16 (pgvector) - Multi-database with PgBouncer pooling
- MongoDB 7 - Document database
- Redis 7 - Shared cache (consolidated)

### Security
- CrowdSec - Modern IPS/IDS with community intel
- Authentik - SSO and 2FA provider
- OAuth2-Proxy - OIDC SSO gateway
- Vaultwarden - Password manager
- Fail2Ban - Intrusion prevention
- HashiCorp Vault - Secrets management

### Networking
- Traefik - Reverse proxy with auto-SSL
- AdGuard Home - DNS-level ad blocking
- Gluetun - VPN client with killswitch
- Tailscale - Mesh VPN for remote access
- WireGuard - High-performance VPN server

### Media (*arr stack)
- Jellyfin - Media server (HW acceleration)
- Sonarr/Radarr/Lidarr/Readarr - Media management
- Prowlarr - Indexer manager
- Bazarr - Subtitle management
- qBittorrent + Aria2 - Download clients
- slskd - Soulseek P2P music
- SpotiFLAC - Spotify to FLAC downloader

### Monitoring & Observability (SOTA 2025)
- **Prometheus** - Metrics collection (30 days)
- **Grafana** - Visualization with pre-configured dashboards
- **Loki** - Log aggregation (30 days, TSDB v12)
- **Parseable** - Lightweight log analytics
- **Scrutiny** - HDD SMART monitoring
- **Beszel** - Lightweight Docker monitoring
- **Uptime Kuma** - Uptime checks
- **Alertmanager** - Alert routing

### Applications
- Immich - Photo management with AI tagging
- Paperless-ngx - Document management with OCR
- Miniflux - RSS reader
- Gitea - Git hosting with CI/CD
- Woodpecker CI - Gitea-native pipelines
- Open WebUI - LLM interface
- Obsidian LiveSync - CouchDB-backed note synchronization

### Utilities
- Homarr - Dashboard
- Dockge - Stack manager
- Stirling PDF - PDF tools
- Velld - Database backup scheduler
- Snapshot Scheduler - Automated Kopia snapshots
- DuckDB - Ad-hoc analytics
- Karakeep - AI-powered bookmark manager
- Memos - Note-taking
- Code Server - VS Code in browser
- Actual Budget - Budgeting

## Quick Access

### Primary Interfaces
- **Grafana**: http://192.168.178.158:3002 ⭐ Main monitoring
- **Homarr**: http://192.168.178.158:7575 - Dashboard
- **Jellyfin**: http://192.168.178.158:8096 - Media server

### Monitoring
- **Prometheus**: http://192.168.178.158:9090
- **Beszel**: http://192.168.178.158:8090

### Management
- **Traefik**: http://192.168.178.158:8080
- **Dockge**: http://192.168.178.158:5001
- **Authentik**: http://192.168.178.158:9000

See [FULL_INTEGRATION_SUMMARY.md](FULL_INTEGRATION_SUMMARY.md) for complete service list and URLs.

## Setup

### Prerequisites
```bash
# Create required directories
sudo mkdir -p /mnt/storage /mnt/cachehdd /mnt/ssd/docker-data

# Set permissions
sudo chown -R $(id -u):$(id -g) /mnt/storage /mnt/cachehdd /mnt/ssd/docker-data
```

### Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env
```

### Start Stack
```bash
# Initialize storage
docker compose up -d storage-init

# Start all services
docker compose up -d
```

### Setup Monitoring
```bash
# Import Grafana dashboards
./scripts/import/import-grafana-dashboards.sh

# Access Grafana
open http://192.168.178.158:3002
```

See [QUICK_START.md](QUICK_START.md) for detailed setup instructions.

## Documentation

- **[QUICK_START.md](QUICK_START.md)** - Quick setup guide
- **[FULL_INTEGRATION_SUMMARY.md](FULL_INTEGRATION_SUMMARY.md)** - Complete implementation details
- **[MONITORING_STACK_ANALYSIS.md](MONITORING_STACK_ANALYSIS.md)** - Service overlap analysis
- **[POWER_OPTIMIZATION.md](POWER_OPTIMIZATION.md)** - Power scheduling guide
- **[FINAL_SUMMARY.txt](FINAL_SUMMARY.txt)** - Latest changes summary
- **[PATHS_GUIDE.md](PATHS_GUIDE.md)** - Storage paths and volume mappings
- **[ONEDRIVE_MIGRATION_GUIDE.md](ONEDRIVE_MIGRATION_GUIDE.md)** - OneDrive → Syncthing migration
- **[SYNCTHING_PERSISTENCE.md](SYNCTHING_PERSISTENCE.md)** - Syncthing config persistence
- **[RUSTYPASTE_USAGE.md](RUSTYPASTE_USAGE.md)** - RustyPaste usage and examples
- **[DROIDYPASTE_SETUP.md](DROIDYPASTE_SETUP.md)** - Android client setup for RustyPaste
- **[VAULTWARDEN_SETUP.md](VAULTWARDEN_SETUP.md)** - Vaultwarden setup and hardening
- **[OBSIDIAN_LIVESYNC_SETUP.md](OBSIDIAN_LIVESYNC_SETUP.md)** - Obsidian LiveSync with CouchDB setup guide
- **[HTTPS_CERTIFICATE_SOLUTION.md](HTTPS_CERTIFICATE_SOLUTION.md)** - Local HTTPS with mkcert
- **[OOM_FIX.md](OOM_FIX.md)** - OOM mitigation notes (low-RAM hosts)

## Architecture Highlights

### Database Consolidation
- Single PostgreSQL instance with 18 databases
- PgBouncer connection pooling (200 max clients)
- Shared Redis cache (16 databases, LFU eviction)

### Storage Strategy
- **SSD** (`/mnt/ssd/docker-data`) - Databases, configs, critical data
- **HDD** (`/mnt/storage`) - Media, photos, documents
- **HDD** (`/mnt/cachehdd`) - Caches, metrics

### Resource Optimization
- CPU limits on all services via `deploy.resources`
- Shared services (Redis, PgBouncer) to reduce overhead
- Hardware acceleration (Intel Quick Sync for Jellyfin/Immich)
- Tmpfs for temporary files (reduces disk I/O)

### Monitoring Strategy
- **Real-time**: Grafana (live dashboard)
- **Short-term**: Prometheus (30 days, 30s resolution)
- **Logs**: Loki (30 days, TSDB v12)

## Performance Tuning

### Intel N250 Optimizations
- PostgreSQL tuned for 16GB RAM (1GB shared_buffers)
- MongoDB WiredTiger cache limited to 1.5GB
- All services have CPU/RAM limits
- Quick Sync enabled for transcoding

### Network Optimization
- Traefik with Prometheus metrics
- CrowdSec for automatic IP blocking
- VPN killswitch for *arr stack
- DNS-level ad blocking (AdGuard)

See [POWER_OPTIMIZATION.md](POWER_OPTIMIZATION.md) for scheduling examples.

## Backup Strategy

- **Kopia**: Automated backups with deduplication
- **Targets**: Vaultwarden, Syncthing, photos, media
- **Storage**: Local repository on HDD
- **Schedule**: Daily incremental, weekly full

## Security

- **CrowdSec**: Community-driven IPS/IDS
- **Fail2Ban**: Brute-force protection
- **Authentik**: SSO with 2FA support
- **Vaultwarden**: Password management
- **Traefik**: Automatic SSL with Let's Encrypt
- **HashiCorp Vault**: Enterprise secrets management

## Maintenance

### Update All Containers
```bash
docker compose pull
docker compose up -d
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker logs -f <container_name>

# Via Loki in Grafana
# Query: {container_name="service_name"}
```

### Monitor Resources
```bash
# Docker stats
docker stats

# Grafana (historical)
open http://192.168.178.158:3002
```

### Restart Unhealthy Services
```bash
# Autoheal does this automatically
# Manual restart:
docker compose restart <service_name>
```

## License

This stack configuration is provided as-is for personal use.

## Credits

Built with SOTA 2025 best practices:
- pgvector for embeddings
- TSDB v12 for faster log queries
- PgBouncer for connection pooling
- Consolidated Redis cache
- Modern monitoring stack
