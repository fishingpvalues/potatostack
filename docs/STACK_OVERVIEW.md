# PotatoStack - Complete Service Overview

## Stack Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          POTATOSTACK                                 │
│                     Le Potato SBC (2GB RAM)                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐  ┌─────────────────────┐  ┌──────────────────┐
│   VPN NETWORK       │  │   PROXY NETWORK     │  │  MONITOR NETWORK │
│                     │  │                     │  │                  │
│ ┌─────────────────┐ │  │ ┌─────────────────┐ │  │ ┌──────────────┐ │
│ │ Surfshark VPN   │ │  │ │ Nginx Proxy Mgr │ │  │ │ Prometheus   │ │
│ │ (Killswitch)    │ │  │ │ (SSL/HTTPS)     │ │  │ │              │ │
│ └─────────────────┘ │  │ └─────────────────┘ │  │ └──────────────┘ │
│         │           │  │                     │  │        │         │
│    ┌────┴────┐      │  │ ┌─────────────────┐ │  │ ┌──────┴──────┐ │
│    │         │      │  │ │ Homepage        │ │  │ │ Grafana     │ │
│ ┌──▼───┐ ┌──▼───┐  │  │ │ Dashboard       │ │  │ │ (Dashboards)│ │
│ │qBit  │ │Nico+ │  │  │ └─────────────────┘ │  │ └─────────────┘ │
│ │torr. │ │Slskd │  │  │                     │  │        │         │
│ └──────┘ └──────┘  │  │ ┌─────────────────┐ │  │ ┌──────┴──────┐ │
│                     │  │ │ Nextcloud       │ │  │ │ Loki        │ │
│ All P2P traffic     │  │ │ (Cloud Storage) │ │  │ │ (Logs)      │ │
│ ONLY via VPN        │  │ └─────────────────┘ │  │ └─────────────┘ │
└─────────────────────┘  │                     │  │                  │
                         │ ┌─────────────────┐ │  │ ┌──────────────┐ │
                         │ │ Kopia           │ │  │ │ Alertmanager │ │
                         │ │ (Backups)       │ │  │ │ (Alerts)     │ │
                         │ └─────────────────┘ │  │ └──────────────┘ │
                         │                     │  │                  │
                         │ ┌─────────────────┐ │  │ ┌──────────────┐ │
                         │ │ Gitea           │ │  │ │ Thanos       │ │
                         │ │ (Git Server)    │ │  │ │ (Long-term)  │ │
                         │ └─────────────────┘ │  │ └──────────────┘ │
                         └─────────────────────┘  └──────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      MANAGEMENT LAYER                                │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────────────────┐ │
│  │Portainer │  │Watchtower│  │Uptime Kuma│  │Dozzle (Logs)       │ │
│  │(Docker)  │  │(Updates) │  │(Uptime)   │  │                    │ │
│  └──────────┘  └──────────┘  └───────────┘  └────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      SYSTEM EXPORTERS                                │
│  ┌────────────────┐  ┌────────────────┐  ┌─────────────────────┐   │
│  │ node-exporter  │  │ cAdvisor       │  │ smartctl-exporter   │   │
│  │ (System/Disk)  │  │ (Containers)   │  │ (HDD Health)        │   │
│  └────────────────┘  └────────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         STORAGE LAYER                                │
│                                                                      │
│  /mnt/seconddrive (Main HDD)     │  /mnt/cachehdd (Cache HDD)      │
│  ├─ kopia/ (backups)             │  ├─ torrents/                   │
│  ├─ nextcloud/ (user files)      │  │  ├─ pr0n/                    │
│  ├─ gitea/ (repos)                │  │  ├─ music/                   │
│  └─ configs/                      │  │  ├─ tv-shows/                │
│                                   │  │  └─ movies/                  │
│                                   │  └─ soulseek/                   │
│                                   │     ├─ pr0n/                    │
│                                   │     ├─ music/                   │
│                                   │     ├─ tv-shows/                │
│                                   │     └─ movies/                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Service Summary

### Category: VPN & P2P Downloads

| Service | Port | RAM | Purpose | URL |
|---------|------|-----|---------|-----|
| **Surfshark** | - | 256MB | VPN with killswitch | Internal only |
| **qBittorrent** | 8080 | 512MB | Torrent client via VPN | http://192.168.178.40:8080 |
| **Nicotine+** | 2234 | 384MB | Soulseek P2P via VPN | http://192.168.178.40:2234 |

**Total: ~1152MB**

### Category: Storage & Backup

| Service | Port | RAM | Purpose | URL |
|---------|------|-----|---------|-----|
| **Kopia** | 51515 | 768MB | Encrypted backups | https://192.168.178.40:51515 |
| **Nextcloud** | 8082 | 512MB | Cloud storage/sync | http://192.168.178.40:8082 |
| **Nextcloud DB** | - | 256MB | MariaDB database | Internal only |

**Total: ~1536MB**

### Category: Monitoring & Alerting

| Service | Port | RAM | Purpose | URL |
|---------|------|-----|---------|-----|
| **Prometheus** | 9090 | 512MB | Metrics collection | http://192.168.178.40:9090 |
| **Grafana** | 3000 | 384MB | Visualization | http://192.168.178.40:3000 |
| **Loki** | 3100 | 256MB | Log aggregation | http://192.168.178.40:3100 |
| **Promtail** | - | 128MB | Log shipper | Internal only |
| **Alertmanager** | 9093 | 128MB | Alert routing | http://192.168.178.40:9093 |
| **Thanos Query** | 10902 | 128MB | Long-term storage | http://192.168.178.40:10902 |
| **Thanos Sidecar** | - | 128MB | Prometheus HA | Internal only |

**Total: ~1664MB**

### Category: System Exporters

| Service | Port | RAM | Purpose | Metrics |
|---------|------|-----|---------|---------|
| **node-exporter** | 9100 | 64MB | System metrics | CPU, RAM, disk, network |
| **cAdvisor** | 8081 | 128MB | Container metrics | Per-container resources |
| **smartctl-exporter** | 9633 | 64MB | HDD health | SMART data, temperature |

**Total: ~256MB**

### Category: Management Tools

| Service | Port | RAM | Purpose | URL |
|---------|------|-----|---------|-----|
| **Portainer** | 9000 | 128MB | Docker GUI | http://192.168.178.40:9000 |
| **Watchtower** | - | 64MB | Auto-updates | Internal only |
| **Uptime Kuma** | 3002 | 256MB | Uptime monitoring | http://192.168.178.40:3002 |
| **Dozzle** | 8083 | 64MB | Log viewer | http://192.168.178.40:8083 |

**Total: ~512MB**

### Category: Infrastructure

| Service | Port | RAM | Purpose | URL |
|---------|------|-----|---------|-----|
| **Nginx Proxy Manager** | 80/443/81 | 256MB | Reverse proxy + SSL | http://192.168.178.40:81 |
| **Homepage** | 3003 | 128MB | Dashboard | http://192.168.178.40:3003 |
| **Gitea** | 3001/2222 | 384MB | Git server | http://192.168.178.40:3001 |
| **Gitea DB** | - | 128MB | PostgreSQL | Internal only |

**Total: ~896MB**

---

## Total Resource Usage

**RAM Usage (estimates):**
- VPN & P2P: ~1152MB
- Storage: ~1536MB
- Monitoring: ~1664MB
- Exporters: ~256MB
- Management: ~512MB
- Infrastructure: ~896MB

**Grand Total: ~6016MB peak** (but many services idle at much lower usage)

**Actual usage on 2GB system:** ~1.6-1.8GB under normal load thanks to:
- Aggressive memory limits
- Swap usage for idle containers
- `GOMAXPROCS` and `GOGC` optimizations
- Shared libraries between containers

**CPU:** Distributed across 4 cores with limits, avg ~30-50% utilization

**Disk I/O:** Optimized with:
- All data on HDDs (SD card read-only)
- Cache directories for frequently accessed data
- Scheduled operations during low-usage hours

---

## Data Flow

### Backup Flow
```
All devices → Kopia clients → Kopia server → /mnt/seconddrive/kopia/repository
                                           → Prometheus metrics → Grafana
                                           → Logs → Loki → Grafana
```

### Download Flow
```
qBittorrent/Nicotine+ → VPN (forced) → Internet
                     → /mnt/cachehdd/[category]/
                     → Nextcloud external storage (read-only)
```

### Monitoring Flow
```
All services → Exporters → Prometheus → Grafana dashboards
           → Container logs → Promtail → Loki → Grafana
           → Prometheus alerts → Alertmanager → Email/Telegram
```

### Web Access Flow
```
User → Homepage → Links to all services
    → Nginx Proxy Manager → SSL/HTTPS → Services
    → (Optional) Fritzbox WireGuard VPN → Remote access
```

---

## Key Features

### Security
- ✅ VPN killswitch (P2P only via VPN)
- ✅ HTTPS via Nginx Proxy Manager
- ✅ 2FA support (Nextcloud, NPM, Portainer)
- ✅ OAuth ready
- ✅ Encrypted backups (Kopia)
- ✅ VPN-only access option

### Monitoring
- ✅ System metrics (CPU, RAM, disk, network)
- ✅ HDD health (SMART data, temperature)
- ✅ Container metrics (per-container resources)
- ✅ Application metrics (Kopia, Nextcloud, etc.)
- ✅ Log aggregation (all containers → Loki)
- ✅ Alerting (email, Telegram, Slack, Discord)

### Resilience
- ✅ Auto-restart on failure
- ✅ Health checks on all services
- ✅ Automatic updates (Watchtower)
- ✅ Uptime monitoring (Uptime Kuma)
- ✅ Graceful degradation (service failures don't crash stack)
- ✅ Data persistence (all state on HDDs)

### Integration
- ✅ All services networked properly
- ✅ Unified dashboard (Homepage)
- ✅ Centralized logging (Loki)
- ✅ Centralized metrics (Prometheus)
- ✅ Shared storage access (Nextcloud sees downloads)
- ✅ Auto-organized downloads (categories)

---

## Quick Command Reference

```bash
# Start everything
docker-compose up -d

# Stop everything
docker-compose down

# Restart service
docker-compose restart [service]

# View logs
docker-compose logs -f [service]

# Update all
docker-compose pull && docker-compose up -d

# Check status
docker-compose ps

# Resource usage
docker stats

# Fix permissions
sudo chown -R 1000:1000 /mnt/seconddrive /mnt/cachehdd
```

---

## Port Reference

| Port | Service | Protocol | Notes |
|------|---------|----------|-------|
| 80 | Nginx PM | HTTP | Redirects to HTTPS |
| 443 | Nginx PM | HTTPS | SSL termination |
| 81 | Nginx PM | HTTP | Admin interface |
| 2222 | Gitea | SSH | Git over SSH |
| 2234 | Nicotine+ | HTTP | Soulseek UI |
| 3000 | Grafana | HTTP | Dashboards |
| 3001 | Gitea | HTTP | Web UI |
| 3002 | Uptime Kuma | HTTP | Monitoring UI |
| 3003 | Homepage | HTTP | Main dashboard |
| 3100 | Loki | HTTP | Log ingestion |
| 6881 | qBittorrent | TCP/UDP | P2P traffic |
| 8080 | qBittorrent | HTTP | Web UI |
| 8081 | cAdvisor | HTTP | Container metrics |
| 8082 | Nextcloud | HTTP | File sync |
| 8083 | Dozzle | HTTP | Log viewer |
| 9000 | Portainer | HTTP | Docker GUI |
| 9090 | Prometheus | HTTP | Metrics |
| 9093 | Alertmanager | HTTP | Alerts |
| 9100 | node-exporter | HTTP | System metrics |
| 9633 | smartctl | HTTP | HDD metrics |
| 10902 | Thanos | HTTP | Long-term metrics |
| 51515 | Kopia | HTTPS | Backup server |
| 51516 | Kopia | HTTP | Prometheus metrics |

---

**Complete, integrated, production-ready stack for Le Potato SBC**

See README.md for full documentation
See QUICKSTART.md for installation guide
