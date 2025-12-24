# PotatoStack - Comprehensive Self-Hosted Stack

## Overview

PotatoStack is a comprehensive Docker Compose-based self-hosted stack designed for Mini PCs with 16GB RAM. It provides 60+ containerized services including media management, cloud storage, monitoring, automation, development tools, and more. This stack replaces a previous Kubernetes-based implementation with a more resource-efficient Docker Compose configuration optimized for home servers.

## Architecture & Services

### Core Infrastructure (Postgres, MongoDB, Redis, Adminer)
- **PostgreSQL**: Shared database for multiple services with multiple database initialization
- **MongoDB**: Document database for applications requiring NoSQL
- **Redis**: Cache and session storage with memory optimization
- **Adminer**: Database management UI for all databases

### Reverse Proxy & SSL Management
- **Traefik**: Modern reverse proxy with automatic SSL certificate management via Let's Encrypt
- **Nginx Proxy Manager**: Alternative GUI-based proxy management

### Authentication & Security
- **Authentik**: SSO and 2FA provider (PostgreSQL-backed with server/worker architecture)
- **Vaultwarden**: Password manager and 2FA aggregator

### VPN & Networking
- **Gluetun**: VPN client with killswitch functionality for *arr stack and download clients
- **Tailscale**: Mesh VPN for secure remote access

### Cloud & Storage
- **Nextcloud AIO**: All-in-one cloud platform with Collabora Office, Talk, Whiteboard
- **Syncthing**: P2P file synchronization

### Media Management (*arr Stack)
- **Prowlarr**: Indexer manager
- **Sonarr**: TV shows
- **Radarr**: Movies
- **Lidarr**: Music
- **Readarr**: Ebooks
- **Bazarr**: Subtitles
- **Maintainerr**: Library cleanup

### Media Servers
- **Jellyfin**: Media server with hardware acceleration support
- **Jellyseerr/Overseerr**: Request management systems
- **Audiobookshelf**: Audiobooks and podcasts

### Download Clients (Behind VPN)
- **qBittorrent**: Torrent client
- **Aria2/AriaNg**: Download manager with web UI

### Photo Management
- **Immich**: AI-powered photo management with ML components

### Monitoring & Observability
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and visualization
- **Loki/Promtail**: Log aggregation and collection
- **Node Exporter/cAdvisor**: System and container metrics
- **Netdata**: Real-time monitoring
- **Uptime Kuma**: Service uptime monitoring

### Automation & Workflows
- **n8n**: Workflow automation platform
- **Huginn**: Self-hosted IFTTT-like automation
- **Healthchecks**: Cron job monitoring

### Utilities & Tools
- **Rustypaste**: Pastebin service
- **Stirling PDF**: PDF manipulation tools
- **Linkding**: Bookmark manager
- **Cal.com**: Calendar scheduling
- **Code Server**: VS Code in the browser

### Development & Git
- **Gitea**: Git hosting with integrated CI/CD
- **Drone**: Alternative CI/CD platform
- **Sentry**: Error tracking

### AI & Special Applications
- **Open WebUI**: LLM interface for AI models
- **OctoBot**: AI crypto trading bot
- **Pinchflat**: YouTube downloader

### Search & Analytics
- **Elasticsearch/Kibana**: Full search stack

## Storage & Volume Management

The stack requires two storage locations:
- `/mnt/storage/`: Main storage with subdirectories for:
  - `downloads/`: Downloaded content
  - `media/`: TV, movies, music, audiobooks, books
  - `photos/`: Immich photo storage
  - `nextcloud/`: Nextcloud data
  - `syncthing/`: Syncthing synchronization
  - `projects/`: Code projects
- `/mnt/cachehdd/`: Cache storage with:
  - `qbittorrent-incomplete/`: Incomplete torrents
  - `jellyfin-cache/`: Transcoding cache
  - `kopia-cache/`: Backup cache

## Hardware Requirements

- **RAM**: 16GB minimum (stack estimated at 13.5GB, leaving 2.5GB buffer)
- **CPU**: 4+ cores
- **Storage**: SSD + HDD recommended (for performance and capacity)
- **Network**: 1GB Ethernet
- **OS**: Linux with Docker and Docker Compose

## Environment Configuration

The stack uses a `.env` file for configuration based on `.env.example`:
- Database passwords
- VPN credentials
- API keys
- Host binding configuration
- Domain settings
- Service-specific configurations

## Quick Start Commands

```bash
# Initialize environment
cp .env.example .env
# Edit .env with your configuration

# Start core services
docker compose up -d postgres mongo redis

# Wait and start everything
sleep 30
docker compose up -d

# Check status
docker compose ps
```

## Network & Security

- All services bind to `${HOST_BIND}` (typically 192.168.178.40) except:
  - Traefik: ports 80, 443 (binds to all interfaces)
  - NPM: ports 81, 8081, 4443
  - Tailscale: uses host network
- Services behind Gluetun VPN have killswitch protection
- SSL certificates auto-managed by Traefik
- Authentik provides centralized SSO/2FA
- Tailscale provides secure remote access

## Management Commands

```bash
# View all containers
docker compose ps

# View specific service logs
docker compose logs -f service-name

# Restart specific service
docker compose restart service-name

# Stop all services
docker compose down

# Update containers (via Watchtower)
# Auto-updates daily at 4 AM
```

## SOTA 2025 Improvements

- **Nextcloud AIO**: Single container replaces multi-container setup, includes Collabora, Talk, Whiteboard
- **CouchDB**: For Obsidian LiveSync (alternative to paid sync)
- **Diun**: Docker Image Update Notifier (safer than auto-updates)
- **No Authentik Redis**: Removed as Authentik 2025.10+ doesn't require it
- **Grafana Provisioning**: Pre-configured data sources and dashboard directory
- **Comprehensive Documentation**: applist.txt with 75+ services documented

## Backup Strategy

1. Database backups configured in respective services
2. Volume backups using Kopia or external backup solution
3. Configuration backup of directory and `.env` file (encrypted)

## Service Integration

- All services share common databases (PostgreSQL, Redis, MongoDB)
- VPN protection for download clients (*arr stack, qBittorrent, Aria2)
- Centralized monitoring with Prometheus, Loki, and Grafana
- Single Sign-On capability through Authentik
- Automated healing with Autoheal service
- Update notifications via Diun (not auto-updates)

## Development & Extensibility

The stack is designed to be easily extensible with additional services. New services can be added to docker-compose.yml following existing patterns for logging, networking, volumes, and resource limits. The project includes `list.txt` with over 80 additional service ideas for future expansion.