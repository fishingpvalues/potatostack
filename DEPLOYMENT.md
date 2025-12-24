# PotatoStack Deployment Guide

## 🚀 Quick Start

**Hardware:** Mini PC with 16GB RAM, 4+ core CPU, 1GB ethernet, SSD

**Target:** Full-featured homelab with 75+ self-hosted services

---

## Prerequisites

### 1. Install Docker & Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

### 2. Prepare Storage Mounts

```bash
# Create mount points (adjust to your drives)
sudo mkdir -p /mnt/storage /mnt/cachehdd

# Example: Mount HDDs (add to /etc/fstab for persistence)
# UUID=your-uuid-here /mnt/storage ext4 defaults 0 2
# UUID=your-uuid-here /mnt/cachehdd ext4 defaults 0 2

# Verify mounts
df -h /mnt/storage /mnt/cachehdd
```

### 3. Clone Repository (or extract files)

```bash
cd ~/
git clone https://github.com/yourusername/potatostack.git
cd potatostack
```

---

## Configuration

### 1. Create .env File

```bash
cp .env.example .env
nano .env
```

**Essential variables to configure:**

```bash
# Network
HOST_BIND=192.168.178.40  # Your Mini PC IP
HOST_DOMAIN=local.domain   # Or your actual domain
ACME_EMAIL=your@email.com  # For SSL certificates

# Databases (generate strong passwords)
POSTGRES_SUPER_PASSWORD=$(openssl rand -base64 32)
MONGO_ROOT_PASSWORD=$(openssl rand -base64 32)

# Authentik
AUTHENTIK_DB_PASSWORD=$(openssl rand -base64 32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 64)

# Vaultwarden
VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 32)

# VPN (if using Gluetun)
VPN_PROVIDER=surfshark  # or your provider
VPN_USER=your_vpn_username
VPN_PASSWORD=your_vpn_password

# Tailscale (get from https://login.tailscale.com/admin/settings/keys)
TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxxx

# WireGuard (optional)
WIREGUARD_SERVERURL=your-domain.duckdns.org  # or 'auto'
WIREGUARD_PEERS=vps,android,laptop,tablet
```

**Generate all passwords:**

```bash
# Quick command to generate all secrets
for var in POSTGRES_SUPER_PASSWORD MONGO_ROOT_PASSWORD AUTHENTIK_DB_PASSWORD \
           FIREFLY_DB_PASSWORD IMMICH_DB_PASSWORD SENTRY_DB_PASSWORD \
           VAULTWARDEN_ADMIN_TOKEN GRAFANA_PASSWORD N8N_PASSWORD; do
  echo "$var=$(openssl rand -base64 32)"
done

# For secret keys (longer)
for var in AUTHENTIK_SECRET_KEY FIREFLY_APP_KEY HUGINN_SECRET_TOKEN \
           HEALTHCHECKS_SECRET_KEY SENTRY_SECRET_KEY; do
  echo "$var=$(openssl rand -base64 64)"
done
```

### 2. Configure Fritzbox (for WireGuard)

See [REMOTE-ACCESS.md](./REMOTE-ACCESS.md) for detailed instructions.

**Quick steps:**
1. Login to http://fritz.box
2. Go to Internet → Permit Access → Port Sharing
3. Forward port 51820 UDP to your Mini PC (192.168.178.40)

---

## Deployment

### 1. Initialize Storage

```bash
# Start storage init (creates directories)
docker compose up storage-init
```

### 2. Start Core Services

```bash
# Start databases first
docker compose up -d postgres mongo redis

# Wait 30 seconds for databases to initialize
sleep 30

# Verify databases are healthy
docker compose ps | grep -E "postgres|mongo|redis"
```

### 3. Start All Services

```bash
# Start everything
docker compose up -d

# Monitor startup (Ctrl+C to exit logs)
docker compose logs -f

# Check status
docker compose ps
```

### 4. Verify Services

```bash
# Check all containers are running
docker compose ps

# Check specific services
docker compose logs traefik
docker compose logs grafana
docker compose logs jellyfin
```

---

## First-Time Setup

### 1. Grafana

1. Go to `http://192.168.178.40:3000`
2. Login: `admin` / password from `GRAFANA_PASSWORD` in .env
3. Dashboards should auto-load from config
4. Import additional dashboards (see config/grafana/dashboards/README.md)

### 2. Authentik (SSO)

1. Go to `http://192.168.178.40:9000`
2. Follow setup wizard
3. Create admin account
4. Configure applications for other services

### 3. Vaultwarden

1. Go to `http://192.168.178.40:8888`
2. Create account
3. Access admin: `http://192.168.178.40:8888/admin`
4. Login with `VAULTWARDEN_ADMIN_TOKEN`

### 4. Nextcloud AIO

1. Go to `http://192.168.178.40:8080` (AIO interface)
2. Follow setup wizard
3. Enable addons: Collabora, Talk, Whiteboard
4. Nextcloud will be at: `http://192.168.178.40:8443`

### 5. Jellyfin

1. Go to `http://192.168.178.40:8096`
2. Follow setup wizard
3. Add media libraries: /data/movies, /data/tvshows, /data/music
4. Configure hardware acceleration (see docker-compose.yml comments)

### 6. Firefly III

1. Go to `http://192.168.178.40:8083`
2. Create account
3. Generate Personal Access Token: Profile → OAuth → Create New Token
4. Add token to .env: `FIREFLY_ACCESS_TOKEN=xxx`
5. Restart importer: `docker compose restart firefly-importer`
6. CSV Import: `http://192.168.178.40:8084`

### 7. Gitea

1. Go to `http://192.168.178.40:3004`
2. Complete initial setup
3. Create admin account
4. Generate Runner Token: Settings → Actions → Runners → Create Token
5. Add to .env: `GITEA_RUNNER_TOKEN=xxx`
6. Restart runner: `docker compose restart gitea-runner`

### 8. n8n

1. Go to `http://192.168.178.40:5678`
2. Login with `N8N_USER` and `N8N_PASSWORD`
3. Create workflows for automation

### 9. Prometheus & Monitoring

1. Prometheus: `http://192.168.178.40:9090`
2. Check targets: `http://192.168.178.40:9090/targets`
3. All should be "UP"

### 10. Tailscale (Remote Access)

See [REMOTE-ACCESS.md](./REMOTE-ACCESS.md)

```bash
# Get auth key from https://login.tailscale.com/admin/settings/keys
# Add to .env: TAILSCALE_AUTHKEY=tskey-auth-xxx
docker compose up -d tailscale
docker logs tailscale  # Verify "Logged in"
```

---

## Service Access

Once deployed, access services at:

| Service | URL | Default Port |
|---------|-----|--------------|
| **Dashboards** | | |
| Glance Dashboard | http://192.168.178.40:3006 | 3006 |
| Grafana | http://192.168.178.40:3000 | 3000 |
| Traefik Dashboard | http://192.168.178.40:8080 | 8080 |
| Portainer | http://192.168.178.40:9443 | 9443 |
| **Media** | | |
| Jellyfin | http://192.168.178.40:8096 | 8096 |
| Immich Photos | http://192.168.178.40:2283 | 2283 |
| Jellyseerr | http://192.168.178.40:5055 | 5055 |
| Audiobookshelf | http://192.168.178.40:13378 | 13378 |
| **ARR Stack** | | |
| Prowlarr | http://192.168.178.40:9696 | 9696 |
| Sonarr | http://192.168.178.40:8989 | 8989 |
| Radarr | http://192.168.178.40:7878 | 7878 |
| Lidarr | http://192.168.178.40:8686 | 8686 |
| Readarr | http://192.168.178.40:8787 | 8787 |
| Bazarr | http://192.168.178.40:6767 | 6767 |
| **Downloads** | | |
| qBittorrent | http://192.168.178.40:8282 | 8282 |
| Aria2 WebUI | http://192.168.178.40:6880 | 6880 |
| **Cloud & Sync** | | |
| Nextcloud AIO | http://192.168.178.40:8443 | 8443 |
| Syncthing | http://192.168.178.40:8384 | 8384 |
| **Knowledge** | | |
| CouchDB (Obsidian) | http://192.168.178.40:5984 | 5984 |
| **Finance** | | |
| Firefly III | http://192.168.178.40:8083 | 8083 |
| Firefly Importer | http://192.168.178.40:8084 | 8084 |
| **Dev Tools** | | |
| Gitea | http://192.168.178.40:3004 | 3004 |
| Code Server | http://192.168.178.40:8443 | 8443 |
| Drone CI | http://192.168.178.40:8089 | 8089 |
| Sentry | http://192.168.178.40:9092 | 9092 |
| **Utilities** | | |
| Stirling PDF | http://192.168.178.40:8086 | 8086 |
| Linkding | http://192.168.178.40:9091 | 9091 |
| Cal.com | http://192.168.178.40:3003 | 3003 |
| Draw.io | http://192.168.178.40:8087 | 8087 |
| Excalidraw | http://192.168.178.40:8088 | 8088 |
| **Automation** | | |
| n8n | http://192.168.178.40:5678 | 5678 |
| Huginn | http://192.168.178.40:3002 | 3002 |
| Healthchecks | http://192.168.178.40:8001 | 8001 |
| **Monitoring** | | |
| Prometheus | http://192.168.178.40:9090 | 9090 |
| Netdata | http://192.168.178.40:19999 | 19999 |
| Uptime Kuma | http://192.168.178.40:3001 | 3001 |
| **Auth** | | |
| Authentik | http://192.168.178.40:9000 | 9000 |
| Vaultwarden | http://192.168.178.40:8888 | 8888 |
| **AI** | | |
| Open WebUI | http://192.168.178.40:3005 | 3005 |
| OctoBot | http://192.168.178.40:5001 | 5001 |
| **Database Admin** | | |
| Adminer | http://192.168.178.40:8090 | 8090 |
| Kibana | http://192.168.178.40:5601 | 5601 |

---

## Maintenance

### Update All Containers

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Remove old images
docker image prune -af
```

### Backup

```bash
# Backup all volumes
docker run --rm \
  -v /var/lib/docker/volumes:/volumes \
  -v /mnt/storage/backups:/backup \
  alpine tar czf /backup/docker-volumes-$(date +%Y%m%d).tar.gz /volumes

# Backup configs
tar czf /mnt/storage/backups/config-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env config/
```

### Monitor Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f jellyfin

# Last 100 lines
docker compose logs --tail=100 grafana
```

### Restart Service

```bash
docker compose restart SERVICE_NAME
```

### Stop All

```bash
docker compose down
```

### Remove Everything (dangerous!)

```bash
# Stop and remove containers, networks, volumes
docker compose down -v
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs SERVICE_NAME

# Check resources
docker stats

# Restart service
docker compose restart SERVICE_NAME
```

### Database Connection Issues

```bash
# Check database is running
docker compose ps | grep postgres

# Check logs
docker compose logs postgres

# Restart database
docker compose restart postgres

# Wait for health check
docker compose ps postgres
```

### Permission Issues

```bash
# Check ownership
ls -la /mnt/storage

# Fix permissions (adjust UID:GID if needed)
sudo chown -R 1000:1000 /mnt/storage
sudo chown -R 1000:1000 /mnt/cachehdd
```

### Port Conflicts

```bash
# Check what's using a port
sudo lsof -i :PORT_NUMBER

# Change port in .env or docker-compose.yml
```

### Out of Memory

```bash
# Check memory usage
docker stats

# Increase swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## Performance Tuning

### For 16GB RAM Systems

The compose file already has memory limits. For better performance:

1. **Disable unused services** - Comment them out in docker-compose.yml
2. **Adjust memory limits** - Increase for critical services
3. **Use SSD for Docker volumes** - Move `/var/lib/docker` to SSD
4. **Enable zram compression**

```bash
# Install zram
sudo apt install zram-config
```

### Enable Jellyfin Hardware Acceleration

See comments in docker-compose.yml (line ~802):

```bash
# Check GPU
ls -la /dev/dri/

# Get render group ID
getent group render | cut -d: -f3

# Uncomment and adjust in docker-compose.yml
```

---

## Security

### 1. Firewall

```bash
# Install UFW
sudo apt install ufw

# Allow SSH
sudo ufw allow 22/tcp

# Allow WireGuard
sudo ufw allow 51820/udp

# Allow services (or use Tailscale/VPN only)
sudo ufw allow from 192.168.178.0/24

# Enable
sudo ufw enable
```

### 2. Auto-Updates

```bash
# Unattended upgrades
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. Monitor with Diun

Diun is already configured - it will notify you of updates via:
- Discord
- Telegram
- Gotify

Configure webhooks in .env.

---

## Next Steps

1. **Remote Access**: Setup Tailscale or WireGuard - see [REMOTE-ACCESS.md](./REMOTE-ACCESS.md)
2. **SSL Certificates**: Configure Let's Encrypt for Traefik
3. **Backups**: Set up automated backups with Kopia or Restic
4. **Monitoring**: Import Grafana dashboards - see config/grafana/dashboards/README.md
5. **Automation**: Create n8n workflows for your stack

---

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Tailscale Homelab Guide](https://tailscale.com/use-cases/homelab)

---

**Need Help?**
- Check service-specific documentation
- Review logs: `docker compose logs SERVICE_NAME`
- Community: r/selfhosted, r/homelab
