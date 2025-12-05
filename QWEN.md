# PotatoStack Project Context

## Project Overview

PotatoStack is a comprehensive, fully integrated Docker-based self-hosted stack specifically designed for the Le Potato single-board computer (SBC) with only 2GB RAM. It provides a complete home server solution featuring P2P file sharing, encrypted backups, comprehensive monitoring, and cloud storage.

The project includes:
- **VPN & P2P**: Surfshark VPN with killswitch, qBittorrent for torrents, Nicotine+/slskd for Soulseek
- **Storage & Backup**: Kopia for encrypted, deduplicated backups, Nextcloud for self-hosted cloud storage
- **Monitoring Stack**: Prometheus, Grafana, Loki, Thanos, Alertmanager, Netdata with auto-discovery
- **Management Tools**: Portainer, Watchtower, Uptime Kuma, Dozzle, Homepage dashboard
- **Infrastructure**: Nginx Proxy Manager, Gitea Git server

## Project Structure

```
potatostack/
├── docker-compose.yml          # Main Docker orchestration file
├── README.md                   # Comprehensive documentation
├── setup.sh                    # Automated setup script
├── .env.example               # Environment configuration template
├── config/                     # Service configuration files
├── pyproject.toml             # Python project configuration (for tooling)
└── various shell scripts       # Additional utilities
```

## Hardware Requirements

- **Le Potato (AML-S905X-CC)** with 2GB RAM, quad-core ARM Cortex-A53
- **Primary HDD** (mounted at `/mnt/seconddrive`): 500GB+ for backups, Nextcloud data, configs
- **Cache HDD** (mounted at `/mnt/cachehdd`): 250GB+ for active torrents and Soulseek downloads

## Setup Process

1. **Prerequisites**: Install Docker, Docker Compose, and mount HDDs
2. **Run setup script**: `sudo ./setup.sh` (configures system, creates directories, pulls images)
3. **Configure environment**: Update `.env` with passwords and credentials
4. **Start stack**: `docker-compose up -d`

## Key Configuration Files

- `docker-compose.yml`: Defines all 20+ services with resource limits
- `.env`: Contains all sensitive credentials and passwords
- `config/`: Directory with service-specific configurations
- `setup.sh`: Automates system preparation and initial setup

## Security Features

- VPN with killswitch protection for all P2P traffic
- Network isolation using multiple Docker networks
- Resource limits to prevent OOM issues on low-RAM device
- Comprehensive monitoring with alerting

## Access Information

| Service | Port | URL |
|---------|------|-----|
| Homepage Dashboard | 3003 | http://192.168.178.40:3003 |
| Netdata | 19999 | http://192.168.178.40:19999 |
| Nginx Proxy Manager | 81 | http://192.168.178.40:81 |
| Portainer | 9000 | http://192.168.178.40:9000 |
| Grafana | 3000 | http://192.168.178.40:3000 |
| qBittorrent | 8080 | http://192.168.178.40:8080 |

## Development Conventions

- All services are optimized for ARM64 architecture
- Resource limits are strictly enforced (total ~1.7GB RAM usage)
- Docker Compose v3.8 with multiple isolated networks
- Configuration via environment variables from `.env` file
- Persistent data stored on mounted HDDs

## Building and Running

```bash
# Initial setup (run as root)
sudo ./setup.sh

# Start all services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f

# Stop services
docker-compose down
```

## Maintenance Commands

```bash
# Update containers (Watchtower does this automatically)
docker-compose pull && docker-compose up -d

# Check resource usage
docker stats

# View specific service logs
docker-compose logs -f [service_name]

# Backup configuration
tar -czf potatostack-backup-$(date +%Y%m%d).tar.gz docker-compose.yml .env config/
```

## Project Context

This project is optimized for the Le Potato SBC with 2GB RAM and includes comprehensive monitoring via Prometheus/Grafana/Netdata, encrypted backups via Kopia, and secure P2P file sharing through VPN. The entire stack is containerized and designed to run 24/7 on low-power hardware.

The Python project configuration (pyproject.toml) exists likely for development tooling but there are no actual Python application files in the project - this is primarily a Docker orchestration project.