# Power & Performance Optimization Guide for Intel N250

## System Profile
- CPU: Intel N250 (4 cores, low TDP 6-15W)
- RAM: 16GB
- Stack: ~90+ services
- Target: Minimize power, maximize efficiency

## 1. CPU Resource Limits (Already Implemented)
All services have `deploy.resources` with CPU limits:
- Heavy services (Jellyfin, Immich ML): 1-2 CPUs
- Medium services (Postgres, n8n): 0.5-1 CPU
- Light services (most): 0.1-0.5 CPU

## 2. RAM Monitoring (Implemented)
- **Netdata**: Real-time monitoring at `http://192.168.178.158:19999`
- **Prometheus + Grafana**: Metrics collection and visualization
- **Beszel**: Docker-specific monitoring

Monitor with: `docker stats` or Netdata dashboard

## 3. Power Scheduling Examples

### Schedule heavy tasks at night using n8n or cron:

#### A. Backup Schedule (via n8n webhook)
Create n8n workflow:
1. Trigger: Cron (daily at 2 AM)
2. HTTP Request to Kopia API: Start backup snapshot
3. Wait for completion
4. Notify via Healthchecks

#### B. Heavy ML Processing (Immich face detection)
Reduce Immich ML CPU during day:
```bash
# Day mode (9 AM): Limit Immich ML to 0.5 CPU
docker update --cpus="0.5" immich-ml

# Night mode (11 PM): Allow full 1.0 CPU for ML
docker update --cpus="1.0" immich-ml
```

Add to crontab on host:
```cron
0 9 * * * docker update --cpus="0.5" immich-ml
0 23 * * * docker update --cpus="1.0" immich-ml
```

#### C. Sonarr/Radarr Download Schedule
Configure in app settings:
- Sonarr/Radarr > Settings > General > Start/Stop Hours
- Or use n8n to pause/resume RSS checks during peak hours

### Example n8n Workflow (Power Schedule)
```json
{
  "name": "Power Optimization Schedule",
  "nodes": [
    {
      "name": "Every Day at 11 PM",
      "type": "n8n-nodes-base.cron",
      "parameters": {
        "cronExpression": "0 23 * * *"
      }
    },
    {
      "name": "Enable Night Mode",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "docker update --cpus=\"1.0\" immich-ml && docker update --cpus=\"1.5\" jellyfin"
      }
    },
    {
      "name": "Every Day at 9 AM",
      "type": "n8n-nodes-base.cron",
      "parameters": {
        "cronExpression": "0 9 * * *"
      }
    },
    {
      "name": "Enable Day Mode",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "docker update --cpus=\"0.5\" immich-ml && docker update --cpus=\"1.0\" jellyfin"
      }
    }
  ]
}
```

## 4. Storage I/O Optimization (Implemented)
- SSD for databases and Docker data (`/mnt/ssd/docker-data`)
- HDD for media and caches (`/mnt/storage`, `/mnt/cachehdd`)
- tmpfs for temp files (Jellyfin, Immich, Paperless)

## 5. Database Connection Pooling (Implemented)
- **PgBouncer**: Reduces Postgres connections from 200+ to ~100
- Used by: Miniflux, Grafana (via pgbouncer:5432)
- Direct connections for services needing transactions (Immich)

## 6. Network Traffic Shaping
Limit bandwidth for non-critical services during peak hours:
```bash
# Limit qBittorrent upload to 5 MB/s during day
# Configure in qBittorrent WebUI: Tools > Options > Speed
# Schedule with n8n API calls to qBittorrent
```

## 7. Quick Sync Hardware Acceleration (Enabled)
- Jellyfin: Uses `/dev/dri/renderD128` for GPU transcoding
- Immich: Can use for video thumbnail generation
- Reduces CPU load by 60-80% during transcoding

## 8. Service Auto-Restart & Health Monitoring
- **Autoheal**: Restarts unhealthy containers
- **Gluetun Monitor**: Restarts VPN-dependent services if VPN drops
- **Healthchecks**: Monitors cron jobs and scheduled tasks

## 9. Prometheus Alerts for Resource Usage
Add to Alertmanager config (`config/alertmanager/config.yml`):
```yaml
route:
  receiver: 'default'
  
receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://n8n:5678/webhook/alerts'

# Alert when RAM > 14GB (87.5%)
# Alert when CPU > 90% for 5 minutes
```

## 10. Disable Unused Services
Stop services you don't actively use:
```bash
# Example: Stop Sentry if not tracking errors
docker stop sentry

# Or set scale to 0 in docker-compose
docker compose up -d --scale sentry=0
```

## Estimated Power Savings
- Idle: ~8-12W (with all services running)
- Light load: ~15-20W
- Heavy load (transcoding, backups): ~25-35W

**Note**: Intel N250 TDP is 6-15W. Most power is from drives and network.
