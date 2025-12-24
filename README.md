# PotatoStack Main - Complete Self-Hosted Stack

**Comprehensive Docker Compose stack for Mini PC (16GB RAM)**

## Overview

Upgraded from Kubernetes to Docker Compose with all requested services from `upgrade.txt`.

## Hardware Requirements

- **RAM**: 16GB minimum
- **CPU**: 4+ cores
- **Storage**: SSD + HDD recommended
  - `/mnt/storage` - Main storage (HDD)
  - `/mnt/cachehdd` - Cache storage (HDD/SSD)
- **Network**: 1GB Ethernet

## Included Services (60+ containers)

### Core Infrastructure
- **PostgreSQL** - Shared database for multiple services
- **MongoDB** - Document database
- **Redis** - Cache and sessions
- **Adminer** - Database UI

### Reverse Proxy & SSL
- **Traefik** - Modern reverse proxy (ports 80/443)
- **Nginx Proxy Manager** - Alternative UI-based proxy

### Authentication & Security
- **Authentik** - SSO and 2FA provider
- **Vaultwarden** - Password manager

### VPN & Networking
- **Gluetun** - VPN client (for *arr stack and downloads)
- **Tailscale** - Mesh VPN for remote access

### Cloud & Storage
- **Nextcloud** - Complete cloud platform
- **Syncthing** - P2P file sync

### Finance
- **Firefly III** - Financial management with Deutsche Bank CSV import
- **Firefly Data Importer** - CSV import tool

### Media Management (*arr Stack)
- **Prowlarr** - Indexer manager
- **Sonarr** - TV shows
- **Radarr** - Movies
- **Lidarr** - Music
- **Readarr** - Ebooks
- **Bazarr** - Subtitles
- **Maintainerr** - Library cleanup

### Media Servers
- **Jellyfin** - Media server
- **Jellyseerr** - Request management for Jellyfin
- **Overseerr** - Alternative request management
- **Audiobookshelf** - Audiobooks and podcasts

### Download Clients (Behind VPN)
- **qBittorrent** - Torrent client
- **Aria2** - Download manager
- **AriaNg** - Aria2 web UI

### Photos
- **Immich** - AI-powered photo management

### Monitoring & Observability
- **Prometheus** - Metrics collection
- **Grafana** - Dashboards and visualization
- **Loki** - Log aggregation
- **Promtail** - Log collector
- **Node Exporter** - System metrics
- **cAdvisor** - Container metrics
- **Fritzbox Exporter** - Router metrics
- **Netdata** - Real-time monitoring
- **Uptime Kuma** - Uptime monitoring

### Automation & Workflows
- **n8n** - Workflow automation
- **Huginn** - Self-hosted automation
- **Healthchecks** - Cron monitoring

### Utilities & Tools
- **Rustypaste** - Pastebin
- **Stirling PDF** - PDF tools
- **Linkding** - Bookmark manager
- **Cal.com** - Calendar scheduling
- **Code Server** - VS Code in browser
- **Draw.io** - Diagramming
- **Excalidraw** - Sketching
- **Atuin** - Shell history sync

### Development & Git
- **Gitea** - Git hosting
- **Gitea Runner** - CI/CD for Gitea
- **Drone** - Alternative CI/CD
- **Sentry** - Error tracking

### AI & Special
- **Open WebUI** - LLM interface
- **OctoBot** - AI crypto trading
- **Pinchflat** - YouTube downloader

### Search & Analytics
- **Elasticsearch** - Search engine
- **Kibana** - Elasticsearch UI

### Dashboard
- **Glance** - Modern dashboard (replacing Homepage)

### System Utilities
- **Watchtower** - Auto-update containers
- **Autoheal** - Auto-restart unhealthy containers
- **Portainer** - Container management UI

## Quick Start

1. **Prepare environment**:
   ```bash
   # Create storage directories (will be created automatically by storage-init)
   # /mnt/storage and /mnt/cachehdd must exist and be mounted

   # Copy environment template
   cp .env.example .env

   # Edit .env and fill in all passwords and configuration
   nano .env
   ```

2. **Generate secrets**:
   ```bash
   # Generate random passwords
   openssl rand -base64 32

   # Generate Firefly app key (requires Firefly container running first)
   # Or use: base64:$(openssl rand -base64 32)
   ```

3. **Start core services**:
   ```bash
   # Start databases first
   docker compose up -d postgres mongo redis

   # Wait for databases to initialize
   sleep 30

   # Start everything
   docker compose up -d
   ```

4. **Access services**:
   - Glance Dashboard: `http://192.168.178.40:3006`
   - Grafana: `http://192.168.178.40:3000`
   - Portainer: `https://192.168.178.40:9443`
   - Jellyfin: `http://192.168.178.40:8096`
   - Nextcloud: `http://192.168.178.40:8082`
   - See docker-compose.yml for all ports

## Volume Mounts

- `/mnt/storage/` - Main storage
  - `downloads/` - Downloads
  - `media/tv/` - TV shows
  - `media/movies/` - Movies
  - `media/music/` - Music
  - `media/audiobooks/` - Audiobooks
  - `media/books/` - Ebooks
  - `media/youtube/` - YouTube downloads
  - `photos/` - Immich photos
  - `nextcloud/` - Nextcloud data
  - `syncthing/` - Syncthing folders
  - `projects/` - Code projects

- `/mnt/cachehdd/` - Cache storage
  - `qbittorrent-incomplete/` - Incomplete torrents
  - `jellyfin-cache/` - Transcoding cache
  - `kopia-cache/` - Backup cache

## Network Ports

All services bind to `${HOST_BIND}` (default: 192.168.178.40) except:
- Traefik: ports 80, 443 (bind to all interfaces)
- NPM: ports 81, 8081, 4443
- Tailscale: uses host network

## Resource Limits

Each service has memory limits configured. Total estimated usage:
- Databases: ~3GB
- Media stack: ~4GB
- Monitoring: ~2.5GB
- Other services: ~4GB
- **Total**: ~13.5GB (leaving 2.5GB buffer on 16GB system)

## Management

```bash
# View all running containers
docker compose ps

# View logs for specific service
docker compose logs -f jellyfin

# Restart a service
docker compose restart sonarr

# Update all containers (via Watchtower)
# Auto-updates daily at 4 AM

# Stop everything
docker compose down

# Remove everything including volumes (DANGER!)
docker compose down -v
```

## Backup Strategy

1. **Database backups**: Configure in respective services
2. **Volume backups**: Use Kopia (from light stack) or external backup solution
3. **Config backup**: Backup this directory and `.env` file (encrypted!)

## Security Notes

- All services behind Gluetun use VPN killswitch
- Configure Authentik for SSO across services
- Use Tailscale for secure remote access
- Enable Traefik SSL with Let's Encrypt
- Never expose port 80/443 without proper security

## Troubleshooting

```bash
# Check service health
docker compose ps

# View real-time resource usage
docker stats

# Check specific service logs
docker compose logs -f <service-name>

# Restart unhealthy services
docker compose restart <service-name>

# Check Gluetun VPN status
curl http://192.168.178.40:8000/v1/openvpn/status
```

## Old Stack

The previous Kubernetes-based stack has been moved to `old-k8s-stack/` directory for reference.
