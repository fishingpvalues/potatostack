# PotatoStack Deployment Checklist

This checklist will guide you through deploying PotatoStack to your Le Potato SBC running Linux.

## Pre-Deployment Checklist

### 1. Hardware Setup
- [ ] Le Potato SBC powered on and running Linux (Debian/Ubuntu recommended)
- [ ] Main HDD connected and accessible
- [ ] Cache HDD connected and accessible
- [ ] Network connected (Ethernet recommended for stability)
- [ ] Minimum 2GB RAM available
- [ ] **CRITICAL: At least 2-3GB swap configured** (PotatoStack allocates ~5.5GB total limits)

**⚠️ MEMORY WARNING**: This stack has container memory limits totaling ~5.5GB, which exceeds the 2GB physical RAM. You MUST configure adequate swap space (2-3GB minimum) or containers will be OOM-killed. The setup.sh script does NOT automatically create swap - you must do this manually (see below).

### 2. Configure Swap Space (CRITICAL)

If you don't have sufficient swap configured, create it now:

```bash
# Check current swap
free -h

# If swap is less than 2GB, create additional swap
sudo fallocate -l 3G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent by adding to /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify
free -h
# You should see at least 2-3GB in the Swap row
```

**Alternative**: If deploying on SD card/eMMC, use a swap file on one of your HDDs:
```bash
sudo fallocate -l 3G /mnt/seconddrive/swapfile
sudo chmod 600 /mnt/seconddrive/swapfile
sudo mkswap /mnt/seconddrive/swapfile
sudo swapon /mnt/seconddrive/swapfile
echo '/mnt/seconddrive/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 3. Mount External Drives

Mount your HDDs to the correct locations:

```bash
# Create mount points
sudo mkdir -p /mnt/seconddrive
sudo mkdir -p /mnt/cachehdd

# Find your drive UUIDs
sudo blkid

# Edit /etc/fstab to add automatic mounting
sudo nano /etc/fstab

# Add lines like (replace UUID with your actual UUIDs):
# UUID=xxxx-xxxx-xxxx /mnt/seconddrive ext4 defaults,nofail 0 2
# UUID=yyyy-yyyy-yyyy /mnt/cachehdd ext4 defaults,nofail 0 2

# Mount all
sudo mount -a

# Verify
df -h
```

### 4. Clone Repository on Le Potato

```bash
# Install git if not already installed
sudo apt update
sudo apt install git -y

# Clone the repository
cd ~
git clone https://github.com/fishingpvalues/potatostack.git
cd potatostack
```

### 5. Configure Environment Variables

```bash
# Copy the example env file
cp .env.example .env

# Edit with your actual credentials
nano .env
```

**CRITICAL**: Update ALL passwords in `.env` file:
- `SURFSHARK_USER` and `SURFSHARK_PASSWORD` - Your Surfshark VPN credentials
- `KOPIA_PASSWORD` and `KOPIA_SERVER_PASSWORD` - Strong passwords for backups
- `NEXTCLOUD_DB_ROOT_PASSWORD`, `NEXTCLOUD_DB_PASSWORD`, `NEXTCLOUD_ADMIN_PASSWORD`
- `GITEA_DB_PASSWORD`
- `GRAFANA_PASSWORD`
- `SLSKD_PASSWORD`
- `ALERT_EMAIL_USER`, `ALERT_EMAIL_PASSWORD`, `ALERT_EMAIL_TO` (Gmail app password)

### 6. Configure Alertmanager Email (Optional)

If you want email alerts:

1. Get a Gmail App Password:
   - Go to https://myaccount.google.com/apppasswords
   - Generate an app password for "Mail"
   - Copy the 16-character password

2. Update `.env` with your email credentials:
   ```
   ALERT_EMAIL_USER=your_email@gmail.com
   ALERT_EMAIL_PASSWORD=your_app_password
   ALERT_EMAIL_TO=alert_recipient@email.com
   ```

3. The alertmanager config uses environment variables, but since Alertmanager doesn't natively support them, you need to manually update the config:
   ```bash
   nano config/alertmanager/config.yml
   ```

   Replace `${ALERT_EMAIL_USER}` with your actual email address, or use an init script to substitute them.

### 7. Run Pre-Flight Check

```bash
# Run the pre-flight check script
chmod +x preflight-check.sh
./preflight-check.sh
```

Fix any errors reported before proceeding.

### 8. Run Setup Script

```bash
# Make setup script executable
chmod +x setup.sh

# Run setup (requires sudo)
sudo ./setup.sh
```

This will:
- Install Docker and Docker Compose
- Create required directories
- Set up permissions
- Initialize Kopia repository
- Optimize system parameters
- Pull Docker images

## Deployment

### 9. Start the Stack

```bash
# Start all services
docker-compose up -d

# Watch logs
docker-compose logs -f
```

### 10. Verify Services

Check that all services are running:

```bash
# Check service status
docker-compose ps

# Check individual service logs if needed
docker-compose logs -f <service-name>
```

All services should show "Up" status.

### 11. Access Web Interfaces

From your network (replace `192.168.178.40` with your Le Potato's IP):

- **Homepage Dashboard**: http://192.168.178.40:3003
- **Portainer**: http://192.168.178.40:9000
- **Grafana**: http://192.168.178.40:3000
- **Prometheus**: http://192.168.178.40:9090
- **Nginx Proxy Manager**: http://192.168.178.40:81
- **qBittorrent**: http://192.168.178.40:8080
- **slskd (Soulseek)**: http://192.168.178.40:2234
- **Nextcloud**: http://192.168.178.40:8082
- **Gitea**: http://192.168.178.40:3001
- **Kopia**: https://192.168.178.40:51515 (HTTPS with self-signed cert)
- **Uptime Kuma**: http://192.168.178.40:3002
- **Dozzle (Logs)**: http://192.168.178.40:8083
- **Netdata**: http://192.168.178.40:19999

## Post-Deployment Configuration

### 12. Configure Nginx Proxy Manager

1. Access NPM at http://192.168.178.40:81
2. Default credentials: `admin@example.com` / `changeme`
3. Change admin password immediately
4. Set up proxy hosts for your services
5. Request Let's Encrypt SSL certificates if exposing externally

### 13. Configure VPN Killswitch Verification

Verify that P2P traffic goes through VPN:

```bash
# Check surfshark container IP
docker exec surfshark curl ipinfo.io

# Should show a Netherlands IP, not your real IP
# Check qBittorrent is using VPN
docker exec qbittorrent curl ipinfo.io
# Should fail or timeout (qBittorrent uses surfshark's network)
```

### 14. Set Up Grafana Dashboards

1. Access Grafana at http://192.168.178.40:3000
2. Login with credentials from `.env` (default: admin / your_password)
3. Import recommended dashboards:
   - **Node Exporter Full**: Dashboard ID `1860`
   - **Docker Container Monitoring**: Dashboard ID `193`
   - **SMART HDD**: Dashboard ID `20204`
   - **Loki Dashboard**: Dashboard ID `13639`

Go to: Dashboard → Import → Enter ID → Select Prometheus datasource → Import

### 15. Configure Kopia Backups

1. Access Kopia at https://192.168.178.40:51515
2. Login with credentials from `.env`
3. Set up snapshot policies:
   - Nextcloud data: `/mnt/seconddrive/nextcloud`
   - Gitea repos: `/mnt/seconddrive/gitea`
   - Container configs: `/home/youruser/potatostack/config`
4. Configure schedule (e.g., daily at 2 AM)

### 16. Set Up Uptime Kuma Monitoring

1. Access Uptime Kuma at http://192.168.178.40:3002
2. Create admin account
3. Add monitors for all critical services
4. Configure notifications (Email, Telegram, Discord, etc.)

### 17. Configure Nextcloud

1. Access Nextcloud at http://192.168.178.40:8082
2. Complete initial setup wizard
3. Enable 2FA in Security settings
4. Add external storage:
   - Torrents folder: `/external/torrents` (read-only)
   - Soulseek folder: `/external/soulseek` (read-only)

### 18. Configure Gitea

1. Access Gitea at http://192.168.178.40:3001
2. Complete initial setup
3. Create admin account
4. Configure SSH access on port 2222 if needed

### 19. Configure qBittorrent

1. Access qBittorrent at http://192.168.178.40:8080
2. Default credentials: `admin` / `adminadmin`
3. **IMPORTANT**: Change password immediately
4. Configure download paths:
   - Default save path: `/downloads`
   - Incomplete path: `/incomplete`
5. Enable Web UI authentication

### 20. Configure slskd (Soulseek)

1. Access slskd at http://192.168.178.40:2234
2. Login with credentials from `.env`
3. Configure your Soulseek account
4. Set shared folders: `/var/slskd/shared`
5. Set download folder: `/var/slskd/incomplete`

### 21. Set Up Portainer

1. Access Portainer at http://192.168.178.40:9000
2. Create admin account
3. Connect local Docker environment
4. Generate API key for Homepage widget:
   - User settings → Access tokens → Add access token
   - Copy token and add to `.env` as `HOMEPAGE_VAR_PORTAINER_KEY`
5. Restart homepage: `docker-compose restart homepage`

## Security Hardening

### 21. Enable Firewall

```bash
# Install ufw if not present
sudo apt install ufw -y

# Allow SSH (adjust port if needed)
sudo ufw allow 22/tcp

# Allow web traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow service ports from local network only
sudo ufw allow from 192.168.178.0/24 to any port 3000:9999 proto tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### 23. Configure External Access (Optional)

If you want external access via your Fritzbox:

1. Set up WireGuard VPN on Fritzbox
2. Access services through VPN only
3. **DO NOT** expose services directly to the internet
4. Use Nginx Proxy Manager for HTTPS with Let's Encrypt
5. Enable fail2ban on exposed services

### 24. Set Up Automated Backups

Create a cron job to backup Docker volumes:

```bash
crontab -e

# Add daily backup at 3 AM
0 3 * * * cd /home/youruser/potatostack && docker-compose exec -T kopia kopia snapshot create /data
```

## Monitoring & Maintenance

### 25. Set Up Health Checks

Verify all health checks are passing:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

All services should show "(healthy)" status.

### 26. Enable Watchtower Notifications

Update `.env` with notification URL:

```bash
# For Telegram
WATCHTOWER_NOTIFICATION_URL=telegram://YOUR_BOT_TOKEN@telegram?channels=YOUR_CHANNEL_ID

# For Discord
WATCHTOWER_NOTIFICATION_URL=discord://YOUR_WEBHOOK_TOKEN@YOUR_WEBHOOK_ID
```

Restart watchtower: `docker-compose restart watchtower`

### 27. Test Alert System

Trigger a test alert:

```bash
# Stop a service to trigger alert
docker-compose stop node-exporter

# Wait 2-3 minutes, check Alertmanager
# Should see "ContainerDown" alert

# Restart service
docker-compose start node-exporter
```

Check if you received email alert (if configured).

## Troubleshooting

### Common Issues

#### 1. VPN Not Connecting
```bash
# Check Surfshark logs
docker-compose logs surfshark

# Verify credentials in .env
# Try switching to different server/protocol
```

#### 2. Out of Memory Errors
```bash
# Check memory usage
free -h

# Add swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# Add to /etc/fstab: /swapfile none swap sw 0 0
```

#### 3. Permission Denied Errors
```bash
# Fix ownership
sudo chown -R 1000:1000 /mnt/seconddrive
sudo chown -R 1000:1000 /mnt/cachehdd
```

#### 4. Container Won't Start
```bash
# Check logs
docker-compose logs <service-name>

# Check resource limits
docker stats

# Restart single service
docker-compose restart <service-name>
```

#### 5. Prometheus/Grafana No Data
```bash
# Check if exporters are running
docker-compose ps | grep exporter

# Verify Prometheus targets
# Go to http://192.168.178.40:9090/targets

# Check Prometheus logs
docker-compose logs prometheus
```

## Backup & Recovery

### Full System Backup
```bash
# Backup docker-compose.yml and configs
tar -czf potatostack-config-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  .env \
  config/ \
  setup.sh \
  preflight-check.sh

# Copy to safe location
```

### Recovery
```bash
# Restore configs
tar -xzf potatostack-config-YYYYMMDD.tar.gz

# Pull images
docker-compose pull

# Start stack
docker-compose up -d

# Restore Kopia backups through Kopia UI
```

## Maintenance Schedule

### Daily
- [ ] Check Uptime Kuma for service status
- [ ] Review Grafana dashboards for anomalies

### Weekly
- [ ] Check Dozzle logs for errors
- [ ] Verify backups completed successfully in Kopia
- [ ] Review disk space usage

### Monthly
- [ ] Update all containers: Watchtower handles this automatically
- [ ] Review and rotate logs if needed
- [ ] Check for security updates: `sudo apt update && sudo apt upgrade`
- [ ] Review Grafana dashboards and alerts

## Success Criteria

Your deployment is successful when:

- ✅ All containers show "Up (healthy)" status
- ✅ Homepage dashboard loads and shows all services
- ✅ VPN is connected (check IP at http://192.168.178.40:8080 via qBittorrent)
- ✅ Grafana shows metrics from all exporters
- ✅ Prometheus shows all targets as "UP"
- ✅ Kopia backups are running on schedule
- ✅ Alertmanager sends test alerts successfully
- ✅ All web interfaces are accessible
- ✅ No critical errors in container logs

## Support & Documentation

- **GitHub Issues**: https://github.com/fishingpvalues/potatostack/issues
- **Stack Documentation**: See README.md, STACK_OVERVIEW.md, SECURITY.md
- **Docker Compose Docs**: https://docs.docker.com/compose/
- **Individual Service Docs**: Check each service's official documentation

---

**IMPORTANT NOTES:**

1. **Never expose services directly to the internet without VPN**
2. **Always use strong, unique passwords**
3. **Enable 2FA where available**
4. **Regularly check backups are working**
5. **Monitor disk space to prevent full disk issues**
6. **Keep the stack updated via Watchtower**

Happy self-hosting! 🎉
