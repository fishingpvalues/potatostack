# Grafana SOTA 2025 Dashboards

This directory contains comprehensive Grafana dashboards for monitoring the PotatoStack self-hosted infrastructure. All dashboards have been downloaded from grafana.com and configured with the correct datasource UIDs for this deployment.

## Datasource Configuration

All dashboards use the following datasources (automatically provisioned):

| Datasource | UID | Purpose |
|------------|-----|---------|
| Prometheus | `PBFA97CFB590B2093` | Metrics collection |
| Loki | `P8E80F9AEF21F6940` | Log aggregation |
| Alertmanager | `P7647F508D5F54FCB` | Alert management |

## Custom PotatoStack Dashboards

### PotatoStack Specific
- **`potatostack-sota-2025.json`** - Comprehensive PotatoStack monitoring
  - System health (CPU, Memory, Disk, Load)
  - Docker container resource usage
  - Network I/O (TX/RX)
  - Disk I/O (Read/Write)

### Logs & Monitoring
- **`docker-logs.json`** - Docker Container Logs via Loki
  - Log search with level filtering
  - Log volume by container
  - Error log viewer

### Databases
- **`postgresql-monitoring.json`** - PostgreSQL Database Monitoring
  - Database status and connections
  - Transaction rates
  - Cache hit ratio
  - Lock statistics

### Imported Dashboards (Existing)
- **`homelab-overview.json`** - Homelab system overview
- **`media-services.json`** - Media services (*arr stack, Jellyfin)
- **`node-exporter-full.json`** - Full Node Exporter metrics
- **`docker-container-host-metrics.json`** - Docker container metrics
- **`fritzbox-status.json`** - FritzBox router status

---

## SOTA 2025 Dashboards Collection

### System & Infrastructure

#### Node Exporter
- **`sota-1860-Node-Exporter-Full.json`** ⭐ [View on Grafana.com](https://grafana.com/grafana/dashboards/1860)
  - Comprehensive Linux system metrics
  - CPU, Memory, Disk, Network, Filesystem
  - Load averages, interrupt stats
  - One of the most popular dashboards (1.5M+ downloads)

#### Docker & Containers
- **`sota-893-Docker-Monitoring.json`** [View](https://grafana.com/grafana/dashboards/893)
  - Docker container metrics
  - Container CPU, Memory, Network usage
  - Container health status

- **`sota-6407-Docker-Swarm.json`** [View](https://grafana.com/grafana/dashboards/6407)
  - Docker Swarm cluster monitoring
  - Service and task metrics
  - Node resource usage

#### Prometheus
- **`sota-3662-Prometheus-Stats.json`** [View](https://grafana.com/grafana/dashboards/3662)
  - Prometheus self-monitoring
  - TSDB stats
  - Query performance

#### Alertmanager
- **`sota-12519-Alertmanager-Overview.json`** [View](https://grafana.com/grafana/dashboards/12519)
  - Alertmanager overview
  - Alert status and count
  - Alert groupings

#### Loki
- **`sota-10991-Grafana-Loki.json`** [View](https://grafana.com/grafana/dashboards/10991)
  - Loki log system monitoring
  - Log ingestion rates
  - Query performance

- **`sota-14055-Loki-Stack-Monitoring.json`** [View](https://grafana.com/grafana/dashboards/14055)
  - Full Loki stack monitoring
  - Components status
  - Resource usage

- **`sota-15324-Loki-Logs-Dashboard.json`** [View](https://grafana.com/grafana/dashboards/15324)
  - Loki log search and visualization
  - Log level filtering
  - Time-based log exploration

---

### Database Monitoring

#### Redis
- **`sota-14031-Redis-Sentinel.json`** [View](https://grafana.com/grafana/dashboards/14031)
  - Redis Sentinel monitoring
  - Master-slave status
  - Memory and connection stats

#### MySQL
- **`sota-11378-MySQL-Overview.json`** [View](https://grafana.com/grafana/dashboards/11378)
  - MySQL performance metrics
  - Query stats, connections
  - InnoDB buffer pool

#### PostgreSQL
- **`sota-16189-PostgreSQL-Overview.json`** [View](https://grafana.com/grafana/dashboards/16189)
  - PostgreSQL comprehensive monitoring
  - Connections, transactions
  - Locks, cache hit ratio

---

### Web Servers & Reverse Proxies

#### Nginx
- **`sota-11312-Nginx-Ingress.json`** [View](https://grafana.com/grafana/dashboards/11312)
  - Nginx ingress monitoring
  - Request rates, response times
  - Upstream status

#### HAProxy
- **`sota-4279-HAProxy.json`** [View](https://grafana.com/grafana/dashboards/4279)
  - HAProxy load balancer metrics
  - Backend health
  - Request/response stats

#### Traefik
- **`sota-10280-Traefik-2.0.json`** [View](https://grafana.com/grafana/dashboards/10280)
  - Traefik 2.0 monitoring
  - Router, Service, Middleware stats

- **`sota-17346-Traefik.json`** [View](https://grafana.com/grafana/dashboards/17346)
  - Traefik dashboard
  - HTTP metrics
  - Service health

---

### Applications & Services

#### Home Automation
- **`sota-15173-Home-Assistant.json`** [View](https://grafana.com/grafana/dashboards/15173)
  - Home Assistant metrics
  - Component status
  - Entity states

#### Cloud Storage
- **`sota-18230-Nextcloud.json`** [View](https://grafana.com/grafana/dashboards/18230)
  - Nextcloud monitoring
  - File operations
  - User activity

#### Document Management
- **`sota-12019-Paperless-ngx.json`** [View](https://grafana.com/grafana/dashboards/12019)
  - Paperless-ngx metrics
  - Document processing stats

#### VPN
- **`sota-11909-Wireguard.json`** [View](https://grafana.com/grafana/dashboards/11909)
  - WireGuard VPN monitoring
  - Peer status
  - Transfer statistics

---

### Network & DNS

#### AdGuard Home
- **`sota-16098-AdGuard-Home.json`** [View](https://grafana.com/grafana/dashboards/16098)
  - AdGuard Home DNS filtering
  - Query statistics
  - Blocked domains

#### Pi-hole
- **`sota-13758-Pi-hole.json`** [View](https://grafana.com/grafana/dashboards/13758)
  - Pi-hole DNS metrics
  - Block lists
  - Query types

- **`sota-6742-Pi-hole-Exporter.json`** [View](https://grafana.com/grafana/dashboards/6742)
  - Pi-hole exporter metrics

#### Unifi
- **`sota-16569-Unifi-Network.json`** [View](https://grafana.com/grafana/dashboards/16569)
  - Ubiquiti Unifi network
  - Access points status
  - Client metrics

#### Netdata
- **`sota-17565-Netdata.json`** [View](https://grafana.com/grafana/dashboards/17565)
  - Netdata monitoring integration
  - System metrics
  - Application monitoring

---

### Security

- **`sota-14519-CrowdSec.json`** [View](https://grafana.com/grafana/dashboards/14519)
  - CrowdSec security
  - Attack detection
  - Decisions and scenarios

---

### Media Services

#### qBittorrent
- **`sota-20330-Qbittorrent.json`** [View](https://grafana.com/grafana/dashboards/20330)
  - qBittorrent stats
  - Download/Upload speeds
  - Torrent counts

#### Jellyfin
- **`sota-17303-Jellyfin.json`** [View](https://grafana.com/grafana/dashboards/17303)
  - Jellyfin media server metrics
  - Playback sessions
  - Library stats

#### Sonarr
- **`sota-13013-Sonarr.json`** [View](https://grafana.com/grafana/dashboards/13013)
  - Sonarr TV show management
  - Queue status
  - Series stats

#### Radarr
- **`sota-12665-Radarr.json`** [View](https://grafana.com/grafana/dashboards/12665)
  - Radarr movie management
  - Queue status
  - Movie library stats

---

### File Sync

#### Syncthing
- **`sota-11228-Syncthing.json`** [View](https://grafana.com/grafana/dashboards/11228)
  - Syncthing file sync metrics
  - Device status
  - Transfer statistics

---

### Infrastructure

#### Proxmox
- **`sota-14658-Proxmox-VE.json`** [View](https://grafana.com/grafana/dashboards/14658)
  - Proxmox VE monitoring
  - VM and container stats
  - Storage usage

#### Consul
- **`sota-12633-Consul.json`** [View](https://grafana.com/grafana/dashboards/12633)
  - Consul service discovery
  - Health checks
  - KV store stats

#### Zinc
- **`sota-16982-Zinc-Observe.json`** [View](https://grafana.com/grafana/dashboards/16982)
  - Zinc Observe metrics
  - Log ingestion
  - Query performance

---

## How to Add New Dashboards

1. Download dashboard from grafana.com:
   ```bash
   curl -o config/grafana/dashboards/my-dashboard.json \
     https://grafana.com/api/dashboards/XXXXX/revisions/latest/download
   ```

2. Update datasource references:
   ```bash
   sed -i 's/"DS_PROMETHEUS"/"PBFA97CFB590B2093"/g' config/grafana/dashboards/my-dashboard.json
   sed -i 's/"DS_LOKI"/"P8E80F9AEF21F6940"/g' config/grafana/dashboards/my-dashboard.json
   ```

3. Restart Grafana:
   ```bash
   docker compose restart grafana
   ```

## Dashboard Statistics

- **Total Dashboards:** 33+
- **Categories:** 10+
- **Last Updated:** February 2025
- **Grafana Version:** 12.3.1+

## Recommended Starting Dashboards

For new PotatoStack deployments, start with:
1. `potatostack-sota-2025.json` - Main overview
2. `sota-1860-Node-Exporter-Full.json` - System metrics
3. `docker-logs.json` - Log exploration
4. `postgresql-monitoring.json` - Database monitoring
5. `sota-893-Docker-Monitoring.json` - Container monitoring

## Troubleshooting

**Dashboard not loading?**
- Check datasource UIDs match: `PBFA97CFB590B2093` (Prometheus), `P8E80F9AEF21F6940` (Loki)
- Verify Grafana has restarted after adding dashboards

**No data showing?**
- Check Prometheus is scraping targets: http://localhost:9090/targets
- Check Loki is receiving logs: http://localhost:3100/ready
- Verify service exporters are running

## Credits

All dashboards sourced from [grafana.com/dashboards](https://grafana.com/grafana/dashboards/)
- Maintained by the Grafana community
- Each dashboard linked to original author
- Licensed under Apache 2.0 or compatible licenses
