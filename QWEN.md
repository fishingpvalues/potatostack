# PotatoStack v2.0 - Complete Self-Hosted Stack for Le Potato SBC

## Project Overview

PotatoStack is a fully integrated, state-of-the-art Docker stack optimized for the Le Potato single-board computer (SBC), featuring P2P file sharing, encrypted backups, comprehensive monitoring, and cloud storage. The stack is specifically designed for the Le Potato hardware (AML-S905X-CC) with its limited resources (2GB RAM, quad-core ARM Cortex-A53), with every service carefully tuned for stability and performance on this hardware.

### Core Components

#### 🌐 VPN & P2P
- **Gluetun VPN** with killswitch protection (supports Surfshark, NordVPN, ProtonVPN, and 60+ providers)
- **qBittorrent** for torrents (through VPN only)
- **slskd (Soulseek)** for P2P file sharing (through VPN only)

#### 💾 Storage & Backup
- **Kopia** - Encrypted, deduplicated backups with web UI
- **Nextcloud** - Self-hosted cloud storage with sync clients
- Integrated access to shared media folders

#### 📊 Monitoring Stack
- **Prometheus** - Metrics collection
- **Grafana** - Beautiful dashboards
- **Loki** - Log aggregation
- **Alertmanager** - Email/Telegram/Slack alerts
- **Netdata** - Real-time monitoring with auto-discovery
- **node-exporter** - System metrics (CPU, RAM, disk, network)
- **cAdvisor** - Container metrics
- **smartctl-exporter** - HDD health monitoring (SMART data)

#### 🛠️ Management Tools
- **Portainer CE** - Docker GUI management
- **Diun** - Docker image update notifications (safer than auto-updates)
- **Uptime Kuma** - Service uptime monitoring
- **Dozzle** - Real-time log viewer
- **Homepage** - Unified dashboard for all services

#### 🔐 Infrastructure
- **Nginx Proxy Manager** - Reverse proxy with Let's Encrypt SSL
- **Gitea** - Self-hosted Git server
- **Vaultwarden** - Bitwarden-compatible password manager
- **Authelia** - Single Sign-On & 2FA

#### 💰 Finance Management
- **Firefly III** - Household finance & budgeting
- **FinTS Importer** - Deutsche Bank auto-import

#### 📷 Media Management
- **Immich** - Self-hosted Google Photos alternative

## Building and Running

### Prerequisites

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo apt install docker-compose

# Mount your HDDs (adjust device names)
sudo mkdir -p /mnt/seconddrive /mnt/cachehdd
# Add to /etc/fstab for permanent mounting:
# UUID=your-uuid-here /mnt/seconddrive ext4 defaults 0 2
# UUID=your-uuid-here /mnt/cachehdd ext4 defaults 0 2
```

### Installation Methods

#### Method 1: Makefile (Recommended)
```bash
# One-liner install via Makefile
make env && sudo make install

# Or step by step:
make env                 # Create .env from .env.example
sudo make setup          # Run full system setup
sudo make up             # Start all Docker services
sudo make systemd        # Install systemd services for auto-start
```

#### Method 2: Direct Script Execution
```bash
# Run the automated setup script
sudo ./setup.sh

# Or manual setup:
cp .env.example .env
nano .env  # Fill in your passwords and credentials
          # HOST_BIND is pre-set to 192.168.178.40 for security
          # Change if your Le Potato has a different LAN IP

# Create directory structure
./setup.sh  # Handles this automatically

# Initialize Kopia repository (first time only)
docker run --rm \
  -e KOPIA_PASSWORD="your_strong_password" \
  -v /mnt/seconddrive/kopia/repository:/repository \
  -v /mnt/seconddrive/kopia/config:/app/config \
  -v /mnt/seconddrive/kopia/cache:/app/cache \
  kopia/kopia:latest \
  repository create filesystem --path=/repository

# Start the stack
docker-compose up -d   # or: docker compose up -d

# Check status
docker-compose ps      # or: docker compose ps
docker-compose logs -f # or: docker compose logs -f
```

### Service Access

| Service | URL | Default Port |
|---------|-----|--------------|
| Homepage Dashboard | http://192.168.178.40:3003 | 3003 |
| Netdata | http://192.168.178.40:19999 | 19999 |
| Nginx Proxy Manager | http://192.168.178.40:81 | 81 |
| Portainer | http://192.168.178.40:9000 | 9000 |
| Grafana | http://192.168.178.40:3000 | 3000 |
| Prometheus | http://192.168.178.40:9090 | 9090 |
| qBittorrent | http://192.168.178.40:8080 | 8080 |
| slskd (Soulseek) | http://192.168.178.40:2234 | 2234 |
| Kopia | https://192.168.178.40:51515 | 51515 |
| Nextcloud | http://192.168.178.40:8082 | 8082 |
| Gitea | http://192.168.178.40:3001 | 3001 |
| Uptime Kuma | http://192.168.178.40:3002 | 3002 |
| Dozzle | http://192.168.178.40:8083 | 8083 |
| Alertmanager | http://192.168.178.40:9093 | 9093 |

### Available Makefile Targets

```bash
# Setup & Installation:
make env              # Create .env from .env.example
make preflight        # Run pre-flight system checks
make setup            # Run full system setup (requires sudo)
make install          # Complete installation (env + setup + up + systemd)
make systemd          # Install systemd services

# Docker Runtime:
make up               # Start all Docker services
make down             # Stop all Docker services
make restart          # Restart all Docker services
make ps               # List running containers
make logs             # Follow container logs
make pull             # Pull latest Docker images

# Health & Monitoring:
make health           # Full system health check
make health-quick     # Quick status check
make health-security  # Security audit
make vpn-test         # Verify VPN kill switch
make backup-verify    # Verify Kopia backups

# Secrets Management:
make secrets-init     # Initialize secrets store
make secrets-edit     # Edit encrypted secrets
make secrets-list     # List all encrypted secrets

# ZFS Storage (optional):
make zfs-create       # Create ZFS pool (destructive!)
make zfs-migrate      # Migrate Docker to ZFS paths

# Code Quality:
make validate         # Validate docker-compose.yml
make conftest         # Run OPA policy tests
make check            # Run pre-commit checks
make fmt              # Format markdown and YAML

# Profiles:
make up-cache         # Start with Redis cache for Nextcloud
```

## Architecture and Design

### Network Layout
The stack implements a multi-network Docker setup with:
- `vpn` network for VPN and P2P traffic
- `monitoring` network for monitoring services
- `proxy` network for reverse proxy and web services
- `default` network for internal service communication

### Resource Management
The stack is optimized for Le Potato's 2GB RAM with specific resource limits for each service:
- VPN: 256MB RAM, 1.0 CPU
- qBittorrent: 512MB RAM, 1.5 CPU
- slskd: 384MB RAM, 1.0 CPU
- Kopia: 768MB RAM, 2.0 CPU
- Nextcloud: 512MB RAM, 1.5 CPU

### Storage Architecture
- `/mnt/seconddrive/` (Main HDD) - Long-term data storage
- `/mnt/cachehdd/` (Cache HDD) - High-IO cache for active downloads

### Security Features
- VPN Killswitch via Gluetun
- Network isolation with multiple Docker networks
- Resource limits to prevent system overload
- Security-hardened container configurations
- Regular security audits and updates

## Development Conventions

### Configuration Management
- All configuration is managed through `.env` files
- Default passwords must be changed before deployment
- Environment variables are used for all sensitive information
- Configuration files are mounted as volumes to containers

### Docker Compose Structure
- Services are organized by functional groups with comments
- Health checks are implemented for all critical services
- Resource limits are specified for each service
- Labels are used for service discovery and homepage integration

### Monitoring and Logging
- All services have appropriate logging configuration
- Prometheus metrics are exposed where available
- Loki is used for centralized log aggregation
- Health checks and alerting are configured for all services

### Security Best Practices
- Default passwords must be changed immediately
- Services are bound to local interfaces by default
- Network segmentation isolates different service types
- Regular backup and verification procedures are implemented

## Maintenance Operations

### Daily
- Check Homepage dashboard for service status
- Review Grafana for anomalies

### Weekly
- Review Uptime Kuma for downtime incidents
- Check Dozzle logs for errors
- Verify Kopia backups are running

### Monthly
- Review Diun notifications and apply updates via Renovate PRs
- Review disk space on both HDDs
- Check SMART data for HDD health
- Test backup restoration from Kopia
- Review and prune old logs

### Common Commands
```bash
# View logs
docker-compose logs -f [service_name]

# Restart service
docker-compose restart [service_name]

# Update all containers
docker-compose pull
docker-compose up -d

# Check resource usage
docker stats

# Backup docker-compose and configs
tar -czf potatostack-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env config/

# Stop everything
docker-compose down

# Stop and remove all data (CAREFUL!)
docker-compose down -v
```