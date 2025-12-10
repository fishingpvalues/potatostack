# PotatoStack Technical Specifications

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Service Specifications](#service-specifications)
3. [API Documentation](#api-documentation)
4. [Configuration Reference](#configuration-reference)
5. [Integration Guide](#integration-guide)
6. [Performance Benchmarks](#performance-benchmarks)
7. [Security Specifications](#security-specifications)
8. [Deployment Specifications](#deployment-specifications)
9. [Monitoring Specifications](#monitoring-specifications)
10. [Maintenance Specifications](#maintenance-specifications)

---

## System Architecture

### Hardware Specifications

#### Minimum Requirements

| Component | Specification | Notes |
|-----------|---------------|-------|
| **Primary Device** | Le Potato SBC (AML-S905X-CC) | ARM64 architecture |
| **CPU** | Quad-core ARM Cortex-A53 @ 1.416GHz | 4 cores, 64-bit |
| **RAM** | 2GB DDR3 | LPDDR2/3 |
| **Storage** | 16GB+ microSD (Class 10) | OS and base system |
| **Network** | Gigabit Ethernet | Primary network interface |
| **Power** | 5V/3A USB-C | ~15W with HDDs |

#### Recommended Configuration

| Component | Specification | Purpose |
|-----------|---------------|---------|
| **Main Storage** | 500GB+ HDD (SATA/USB 3.0) | Primary data storage |
| **Cache Storage** | 250GB+ HDD (SATA/USB 3.0) | Temporary downloads |
| **Network** | USB 3.0 Gigabit Ethernet | Additional network interfaces |
| **Power Supply** | 5V/4A (20W) | Stable power delivery |

### Software Architecture

#### Operating System

```yaml
Base System: Ubuntu 22.04 LTS (ARM64)
Kernel: Linux 5.15.x
Architecture: ARM64 (AArch64)
Container Runtime: Docker 24.0+
Orchestration: Docker Compose v2
Package Manager: APT (Debian-based)
```

#### Container Architecture

```yaml
Container Runtime:
  Engine: Docker CE 24.0+
  Runtime: runc
  Network: Bridge networking with custom networks
  Storage: OverlayFS with named volumes
  Security: User namespaces, AppArmor/SELinux
  
Networks:
  potatostack_default: Default bridge network
  potatostack_proxy: Proxy and reverse proxy services
  potatostack_monitoring: Monitoring and observability
  potatostack_vpn: VPN and P2P services
  
Volumes:
  Type: Named volumes with driver local
  Backup: External HDD mount points
  Data Persistence: All critical data on external storage
```

---

## Service Specifications

### Core Services

#### 1. Homepage Dashboard

```yaml
Service: homepage
Image: ghcr.io/gethomepage/homepage:latest
Port: 3000 (internal), 3003 (external)
Memory: 128MB limit, 64MB reservation
CPU: 0.5 cores

Configuration:
  Authentication: Optional basic auth
  API Integration: Docker API, service discovery
  Widgets: Custom widgets for all services
  Theme: Configurable light/dark theme
  
Dependencies:
  - docker socket access
  - All service health endpoints
  
Environment Variables:
  - PUID: 1000
  - PGID: 1000
  
Mounts:
  - ./config/homepage:/app/config
  - /var/run/docker.sock:/var/run/docker.sock:ro
  - /mnt/seconddrive:/mnt/seconddrive:ro
  - /mnt/cachehdd:/mnt/cachehdd:ro
```

#### 2. Nginx Proxy Manager

```yaml
Service: nginx-proxy-manager
Image: jc21/nginx-proxy-manager:latest
Ports: 
  - 80:80 (HTTP)
  - 443:443 (HTTPS)
  - 81:81 (Admin UI)
Memory: 256MB limit, 128MB reservation
CPU: 1 core

Configuration:
  SSL: Let's Encrypt integration
  Forward Proxy: HTTP/HTTPS proxying
  Rate Limiting: Configurable rate limits
  Access Control: IP whitelisting/blacklisting
  
Dependencies:
  - None (foundational service)
  
Environment Variables:
  - DB_SQLITE_FILE: /data/database.sqlite
  - DISABLE_IPV6: true
  
Mounts:
  - npm_data:/data
  - npm_ssl:/etc/letsencrypt
```

#### 3. Gluetun VPN

```yaml
Service: gluetun
Image: qmcgaw/gluetun:latest
Network: potatostack_vpn
Memory: 256MB limit, 128MB reservation
CPU: 1 core

Configuration:
  Provider: Surfshark (configurable)
  Protocol: OpenVPN/WireGuard
  Country: Netherlands (AMS)
  Killswitch: Enabled
  DNS: 1.1.1.1, 1.0.0.1
  
Environment Variables:
  - VPN_SERVICE_PROVIDER: surfshark
  - VPN_TYPE: openvpn
  - OPENVPN_USER: ${SURFSHARK_USER}
  - OPENVPN_PASSWORD: ${SURFSHARK_PASSWORD}
  - SERVER_COUNTRIES: Netherlands
  - SERVER_CITIES: Amsterdam
  - FIREWALL: on
  - FIREWALL_OUTBOUND_SUBNETS: ${LAN_NETWORK:-192.168.178.0/24}
  
Capabilities:
  - NET_ADMIN
  - SYS_MODULE (if needed)
  
Devices:
  - /dev/net/tun
  
Health Check:
  - Type: HTTP GET
  - URL: http://localhost:8000/v1/publicip/ip
  - Interval: 5 minutes
```

#### 4. Nextcloud

```yaml
Service: nextcloud
Image: nextcloud:stable
Port: 80 (internal), 8082 (external)
Memory: 512MB limit, 256MB reservation
CPU: 1.5 cores

Configuration:
  Web Server: Apache2 with PHP 8.1
  Database: MariaDB 10.11
  PHP Memory: 512MB
  Upload Limit: 10GB
  Trusted Domains: 192.168.178.40, lepotato.local
  
Dependencies:
  - nextcloud-db (MariaDB)
  
Environment Variables:
  - MYSQL_HOST: nextcloud-db
  - MYSQL_DATABASE: nextcloud
  - MYSQL_USER: nextcloud
  - MYSQL_PASSWORD: ${NEXTCLOUD_DB_PASSWORD}
  - NEXTCLOUD_ADMIN_USER: ${NEXTCLOUD_ADMIN_USER}
  - NEXTCLOUD_ADMIN_PASSWORD: ${NEXTCLOUD_ADMIN_PASSWORD}
  - NEXTCLOUD_TRUSTED_DOMAINS: 192.168.178.40 lepotato.local
  - OVERWRITEPROTOCOL: https
  - PHP_MEMORY_LIMIT: 512M
  - PHP_UPLOAD_LIMIT: 10G
  
Mounts:
  - nextcloud_data:/var/www/html
  - /mnt/seconddrive/nextcloud:/data
  - /mnt/cachehdd/torrents:/external/torrents:ro
  - /mnt/cachehdd/soulseek:/external/soulseek:ro
```

#### 5. Kopia Backup Server

```yaml
Service: kopia
Image: kopia/kopia:latest
Ports:
  - 51515:51515 (HTTP API)
  - 51516:51516 (Metrics)
Memory: 768MB limit, 384MB reservation
CPU: 2 cores

Configuration:
  Repository: Filesystem backend
  Encryption: AES-256-GCM
  Compression: Zstandard
  Deduplication: Enabled
  Retention: 30 days rolling
  
Dependencies:
  - None
  
Environment Variables:
  - TZ: Europe/Berlin
  - KOPIA_PASSWORD: ${KOPIA_PASSWORD}
  - GOGC: 50
  - GOMAXPROCS: 2
  - KOPIA_CONFIG_PATH: /app/config/repository.config
  - KOPIA_CACHE_DIRECTORY: /app/cache
  - KOPIA_LOG_DIR: /app/logs
  - KOPIA_PROMETHEUS_ENABLED: true
  - KOPIA_PROMETHEUS_LISTEN_ADDR: :51516
  
Mounts:
  - /mnt/seconddrive/kopia/repository:/repository
  - /mnt/seconddrive/kopia/config:/app/config
  - /mnt/seconddrive/kopia/cache:/app/cache
  - /mnt/seconddrive/kopia/logs:/app/logs
  - /mnt/seconddrive/kopia/tmp:/tmp
  - /:/host:ro
  
Capabilities:
  - SYS_ADMIN
  - SYS_PTRACE
  
Devices:
  - /dev/fuse:/dev/fuse
```

#### 6. Prometheus Monitoring

```yaml
Service: prometheus
Image: prom/prometheus:latest
Port: 9090
Memory: 512MB limit, 256MB reservation
CPU: 1 core

Configuration:
  Scrape Interval: 15s
  Evaluation Interval: 15s
  Storage: 30 days retention
  Metrics Format: OpenMetrics
  
Dependencies:
  - node-exporter
  - cadvisor
  - smartctl-exporter
  
Configuration Files:
  - ./config/prometheus/prometheus.yml
  - ./config/prometheus/alerts.yml
  
Mounts:
  - ./config/prometheus:/etc/prometheus
  - prometheus_data:/prometheus
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

#### 7. Grafana Visualization

```yaml
Service: grafana
Image: grafana/grafana:latest
Port: 3000
Memory: 384MB limit, 192MB reservation
CPU: 1 core

Configuration:
  Authentication: Admin user with password
  Plugins: piechart-panel, clock-panel
  Analytics: Reporting disabled
  
Dependencies:
  - prometheus
  - loki
  
Environment Variables:
  - GF_SECURITY_ADMIN_USER: ${GRAFANA_USER}
  - GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
  - GF_INSTALL_PLUGINS: grafana-piechart-panel,grafana-clock-panel
  - GF_SERVER_ROOT_URL: %(protocol)s://%(domain)s:%(http_port)s/grafana/
  - GF_ANALYTICS_REPORTING_ENABLED: false
  
Mounts:
  - grafana_data:/var/lib/grafana
  - ./config/grafana/provisioning:/etc/grafana/provisioning
```

#### 8. qBittorrent

```yaml
Service: qbittorrent
Image: lscr.io/linuxserver/qbittorrent:latest
Network: service:gluetun
Ports:
  - 8080:8080 (Web UI)
  - 6881:6881 (TCP/UDP)
Memory: 512MB limit, 256MB reservation
CPU: 1.5 cores

Configuration:
  Web UI: Port 8080
  BitTorrent Port: 6881
  Default User: admin
  Default Password: adminadmin
  
Dependencies:
  - gluetun (must be healthy)
  
Environment Variables:
  - PUID: 1000
  - PGID: 1000
  - TZ: Europe/Berlin
  - WEBUI_PORT: 8080
  - TORRENTING_PORT: 6881
  
Mounts:
  - /mnt/seconddrive/qbittorrent/config:/config
  - /mnt/cachehdd/torrents:/downloads
  - /mnt/cachehdd/torrents/incomplete:/incomplete
  
Homepage Integration:
  - Group: Media & Downloads
  - Widget: qbittorrent
  - URL: http://gluetun:8080
```

#### 9. slskd (Soulseek Client)

```yaml
Service: slskd
Image: ghcr.io/slskd/slskd:latest
Network: service:gluetun
Ports:
  - 2234:2234 (HTTP API)
  - 50000:50000 (Soulseek Protocol)
Memory: 384MB limit, 192MB reservation
CPU: 1 core

Configuration:
  HTTP API: Port 2234
  Soulseek Port: 50000
  Username: admin (configurable)
  Metrics: Enabled
  
Dependencies:
  - gluetun (must be healthy)
  
Environment Variables:
  - PUID: 1000
  - PGID: 1000
  - TZ: Europe/Berlin
  - SLSKD_HTTP_PORT: 2234
  - SLSKD_SLSK_LISTEN_PORT: 50000
  - SLSKD_USERNAME: ${SLSKD_USER:-admin}
  - SLSKD_PASSWORD: ${SLSKD_PASSWORD}
  - SLSKD_METRICS: true
  - SLSKD_METRICS_URL: http://localhost:5031/metrics
  
Mounts:
  - /mnt/seconddrive/slskd/config:/app
  - /mnt/seconddrive/slskd/logs:/app/logs
  - /mnt/cachehdd/soulseek:/var/slskd/shared
  - /mnt/cachehdd/soulseek/incomplete:/var/slskd/incomplete
  
Homepage Integration:
  - Group: Media & Downloads
  - Widget: generic
  - URL: http://gluetun:2234
```

### Database Services

#### MariaDB (Consolidated Database)

```yaml
Service: mariadb
Image: mariadb:10.11
Memory: 256MB limit, 128MB reservation
CPU: 0.5 cores

Configuration:
  Version: MariaDB 10.11
  Character Set: utf8mb4
  Collation: utf8mb4_unicode_ci
  InnoDB Settings:
    - transaction-isolation: READ-COMMITTED
    - binlog-format: ROW
    - innodb-file-per-table: 1
    - skip-innodb-read-only-compressed
    
Dependencies:
  - None
  
Environment Variables:
  - MYSQL_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
  
Mounts:
  - mariadb_data:/var/lib/mysql
   - ./config/mariadb/init:/docker-entrypoint-initdb.d:ro
   - ./config/mariadb/low-memory.cnf:/etc/mysql/conf.d/low-memory.cnf:ro
```

#### PostgreSQL (Consolidated Database)

```yaml
Service: postgres
Image: tensorchord/pgvecto-rs:pg14-v0.2.0
Memory: 256MB limit, 128MB reservation
CPU: 1 core

Configuration:
  Version: PostgreSQL 14 with pgvecto-rs extension
  Character Set: UTF8
  Extensions: pgvecto-rs for vector search
  
Dependencies:
  - None
  
Environment Variables:
  - POSTGRES_USER: postgres
  - POSTGRES_PASSWORD: ${POSTGRES_SUPER_PASSWORD}
  - POSTGRES_DB: postgres
  - GITEA_DB_PASSWORD: ${GITEA_DB_PASSWORD}
  - IMMICH_DB_PASSWORD: ${IMMICH_DB_PASSWORD}
  
Mounts:
  - postgres_data:/var/lib/postgresql/data
  - ./config/postgres/init:/docker-entrypoint-initdb.d:ro
```

---

## API Documentation

### Homepage Dashboard API

#### Service Status Endpoint

```http
GET /api/health
Content-Type: application/json

Response:
{
  "services": {
    "nextcloud": {
      "status": "online",
      "response_time": 45,
      "url": "http://localhost:8082"
    },
    "kopia": {
      "status": "online", 
      "response_time": 32,
      "url": "http://localhost:51515"
    },
    "qbittorrent": {
      "status": "online",
      "response_time": 28,
      "url": "http://gluetun:8080"
    }
  },
  "timestamp": "2025-12-06T22:07:00Z"
}
```

#### System Information Endpoint

```http
GET /api/system
Content-Type: application/json

Response:
{
  "uptime": "15d 4h 23m",
  "load_average": [0.45, 0.52, 0.48],
  "memory": {
    "total": "1.9G",
    "used": "1.2G",
    "available": "700M",
    "percentage": 63
  },
  "disk": {
    "main": {
      "total": "465G",
      "used": "234G",
      "available": "231G",
      "percentage": 50
    },
    "cache": {
      "total": "232G",
      "used": "45G", 
      "available": "187G",
      "percentage": 19
    }
  }
}
```

### Kopia API

#### Repository Status

```http
GET http://localhost:51515/api/v1/repository/status
Authorization: Basic base64(username:password)

Response:
{
  "config": {
    "format": "kopia.repository.filessync.filessyncRepository",
    "uuid": "abc123-def456-ghi789",
    "time": "2025-12-06T22:07:00Z"
  },
  "cache": {
    "location": "/app/cache",
    "max_size": "5G",
    "used": "1.2G"
  },
  "parameters": {
    "content_cache_size": "500M",
    "metadata_cache_size": "500M",
    "upload_queue_size": "100"
  }
}
```

#### Snapshot Management

```http
GET http://localhost:51515/api/v1/snapshots
Authorization: Basic base64(username:password)

Response:
{
  "snapshots": [
    {
      "id": "snapshot123",
      "start_time": "2025-12-06T20:00:00Z",
      "end_time": "2025-12-06T20:15:23Z",
      "source": {
        "paths": ["/home/user/documents"],
        "user": "user",
        "host": "laptop"
      },
      "stats": {
        "total_bytes": 1073741824,
        "num_files": 1250,
        "num_dirs": 45
      }
    }
  ]
}
```

#### Create Snapshot

```http
POST http://localhost:51515/api/v1/snapshots/create
Authorization: Basic base64(username:password)
Content-Type: application/json

{
  "source": {
    "paths": ["/path/to/backup"]
  },
  "tags": ["daily", "important"],
  "description": "Daily backup of important documents"
}
```

### Prometheus API

#### Query Metrics

```http
GET http://localhost:9090/api/v1/query?query=up
Content-Type: application/json

Response:
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "__name__": "up",
          "instance": "localhost:9090",
          "job": "prometheus"
        },
        "value": [1701904020, "1"]
      }
    ]
  }
}
```

#### Query Range

```http
GET http://localhost:9090/api/v1/query_range?query=rate(container_cpu_usage_seconds_total[5m])&start=2025-12-06T20:00:00Z&end=2025-12-06T22:00:00Z&step=60s
Content-Type: application/json

Response:
{
  "status": "success",
  "data": {
    "resultType": "matrix",
    "result": [
      {
        "metric": {
          "container_label_com_docker_compose_service": "nextcloud"
        },
        "values": [
          [1701904020, "0.25"],
          [1701904080, "0.23"],
          [1701904140, "0.26"]
        ]
      }
    ]
  }
}
```

### Grafana API

#### Get Dashboards

```http
GET http://localhost:3000/api/search
Authorization: Bearer <grafana_token>

Response:
[
  {
    "id": 1,
    "uid": "dashboard123",
    "title": "System Overview",
    "type": "dash-db",
    "tags": ["system", "overview"],
    "folderId": 0,
    "folderUid": "",
    "uri": "db/system-overview"
  }
]
```

#### Create Dashboard

```http
POST http://localhost:3000/api/dashboards/db
Authorization: Bearer <grafana_token>
Content-Type: application/json

{
  "dashboard": {
    "id": null,
    "uid": null,
    "title": "Custom Dashboard",
    "tags": ["custom"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Load",
        "type": "stat",
        "targets": [
          {
            "expr": "up",
            "legendFormat": "Services Up"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  },
  "overwrite": false,
  "message": "Created new dashboard"
}
```

### Nextcloud API

#### User Management

```http
GET http://localhost:8082/ocs/v2.php/cloud/users
Authorization: Basic base64(username:app_password)
Accept: application/json

Response:
{
  "ocs": {
    "meta": {
      "status": "ok",
      "statuscode": 200,
      "message": "OK"
    },
    "data": {
      "users": [
        {
          "id": "user1",
          "displayname": "User One",
          "email": "user1@example.com"
        }
      ]
    }
  }
}
```

#### File Operations

```http
GET http://localhost:8082/remote.php/dav/files/user1/
Authorization: Basic base64(username:app_password)

Response:
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
  <d:response>
    <d:href>/remote.php/dav/files/user1/</d:href>
    <d:propstat>
      <d:prop>
        <oc:fileid>123</oc:fileid>
        <d:getlastmodified>Wed, 06 Dec 2025 22:07:00 GMT</d:getlastmodified>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>
```

### qBittorrent Web API

#### Get Torrents

```http
GET http://localhost:8080/api/v2/torrents/info
Authorization: Basic base64(username:password)

Response:
[
  {
    "hash": "abc123def456",
    "name": "ubuntu-22.04.iso",
    "size": 4718592000,
    "progress": 45.6,
    "state": "downloading",
    "dlspeed": 5242880,
    "upspeed": 0,
    "ratio": 0.0,
    "eta": 7200,
    "category": "linux"
  }
]
```

#### Add Torrent

```http
POST http://localhost:8080/api/v2/torrents/add
Authorization: Basic base64(username:password)
Content-Type: multipart/form-data

torrents: <file>
save_path: /downloads/movies
category: movies
```

### Gitea API

#### Repository Information

```http
GET http://localhost:3001/api/v1/repos/user/repo
Authorization: token <gitea_token>

Response:
{
  "id": 1,
  "name": "repository",
  "full_name": "user/repository",
  "description": "A test repository",
  "private": false,
  "clone_url": "http://192.168.178.40:3001/user/repository.git",
  "ssh_url": "ssh://git@192.168.178.40:2222/user/repository.git",
  "size": 1024,
  "default_branch": "main",
  "created_at": "2025-12-06T22:07:00Z",
  "updated_at": "2025-12-06T22:07:00Z"
}
```

#### Create Repository

```http
POST http://localhost:3001/api/v1/user/repos
Authorization: token <gitea_token>
Content-Type: application/json

{
  "name": "new-repository",
  "description": "A new repository created via API",
  "private": false,
  "auto_init": true
}
```

---

## Configuration Reference

### Environment Variables

#### Core Configuration

```bash
# VPN Configuration
SURFSHARK_USER=your_surfshark_username
SURFSHARK_PASSWORD=your_surfshark_password

# Kopia Backup
KOPIA_PASSWORD=change_this_to_a_very_strong_password
KOPIA_SERVER_USER=admin
KOPIA_SERVER_PASSWORD=change_this_to_another_strong_password

# Nextcloud
NEXTCLOUD_DB_ROOT_PASSWORD=strong_random_password_here
NEXTCLOUD_DB_PASSWORD=another_strong_password
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=your_nextcloud_admin_password

# Gitea
GITEA_DB_PASSWORD=gitea_database_password

# Grafana
GRAFANA_USER=admin
GRAFANA_PASSWORD=secure_grafana_password

# Alertmanager Email Notifications
ALERT_EMAIL_USER=your_gmail_address@gmail.com
ALERT_EMAIL_PASSWORD=your_gmail_app_password
ALERT_EMAIL_TO=your_alert_recipient@email.com

# Soulseek
SLSKD_USER=admin
SLSKD_PASSWORD=change_this_slskd_password

# Netdata Cloud (Optional)
NETDATA_CLAIM_TOKEN=
NETDATA_CLAIM_ROOMS=

# Diun Notifications (configure in config/diun/diun.yml)
# Supports: Gotify, Telegram, Discord, Email, Webhook
```

#### Homepage Configuration

```yaml
# config/homepage/settings.yaml
---
appearance:
  title: "PotatoStack Dashboard"
  description: "Self-hosted infrastructure dashboard"
  theme: "dark"
  primaryColor: "#00d4aa"
  textColor: "#ffffff"
  backgroundColor: "#0f0f0f"

header:
  logo: ""
  title: "PotatoStack"
  icon: ""
  favicon: ""

services:
  - group: "Media & Downloads"
    icon: mdi:download
    services:
      - name: "qBittorrent"
        url: "http://192.168.178.40:8080"
        icon: mdi:torrent
        widget:
          type: "qbittorrent"
          url: "http://gluetun:8080"
          username: "admin"
          password: "{{HOMEPAGE_VAR_QBITTORRENT_PASSWORD}}"
      
      - name: "slskd (Soulseek)"
        url: "http://192.168.178.40:2234"
        icon: mdi:music
        widget:
          type: "generic"
          url: "http://gluetun:2234"

  - group: "Storage & Sync"
    icon: mdi:cloud
    services:
      - name: "Nextcloud"
        url: "http://192.168.178.40:8082"
        icon: mdi:nextcloud
        widget:
          type: "nextcloud"
          url: "http://nextcloud:80"
          username: "{{HOMEPAGE_VAR_NEXTCLOUD_USER}}"
          password: "{{HOMEPAGE_VAR_NEXTCLOUD_PASSWORD}}"
      
      - name: "Kopia"
        url: "http://192.168.178.40:51515"
        icon: mdi:backup-restore
        widget:
          type: "kopia"
          url: "http://kopia:51515"

  - group: "Development"
    icon: mdi:code-tags
    services:
      - name: "Gitea"
        url: "http://192.168.178.40:3001"
        icon: mdi:git

  - group: "Monitoring"
    icon: mdi:chart-line
    services:
      - name: "Grafana"
        url: "http://192.168.178.40:3000"
        icon: mdi:chart-line
        widget:
          type: "grafana"
          url: "http://grafana:3000"
          username: "{{HOMEPAGE_VAR_GRAFANA_USER}}"
          password: "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}"
      
      - name: "Prometheus"
        url: "http://192.168.178.40:9090"
        icon: mdi:chart-timeline-variant
      
      - name: "Netdata"
        url: "http://192.168.178.40:19999"
        icon: mdi:chart-bell-curve-cumulative

  - group: "Management"
    icon: mdi:cog
    services:
      - name: "Portainer"
        url: "http://192.168.178.40:9000"
        icon: mdi:docker
        widget:
          type: "portainer"
          url: "http://portainer:9000"
      
      - name: "Uptime Kuma"
        url: "http://192.168.178.40:3002"
        icon: mdi:heart-pulse
      
      - name: "Nginx Proxy Manager"
        url: "http://192.168.178.40:81"
        icon: mdi:reverse-proxy
        widget:
          type: "npm"
          url: "http://nginx-proxy-manager:81"
          username: "{{HOMEPAGE_VAR_NPM_USER}}"
          password: "{{HOMEPAGE_VAR_NPM_PASSWORD}}"
```

#### Prometheus Configuration

```yaml
# config/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'potatostack'
    instance: 'lepotato'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - 'alerts.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'lepotato'
          node: 'main'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          instance: 'lepotato'

  - job_name: 'smartctl'
    static_configs:
      - targets: ['smartctl-exporter:9633']
        labels:
          instance: 'lepotato'

  - job_name: 'kopia'
    static_configs:
      - targets: ['kopia:51516']
        labels:
          service: 'backup'
          instance: 'lepotato'

  - job_name: 'nginx-proxy-manager'
    static_configs:
      - targets: ['nginx-proxy-manager:81']
        labels:
          service: 'proxy'

  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container_name
      - source_labels: [__meta_docker_container_label_com_docker_compose_service]
        target_label: service
      - source_labels: [__meta_docker_container_label_com_docker_compose_project]
        target_label: project
```

#### Alert Rules

```yaml
# config/prometheus/alerts.yml
groups:
  - name: potatostack.rules
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 5 minutes."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes."

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space low on {{ $labels.instance }}"
          description: "Disk usage is above 90% for more than 5 minutes on {{ $labels.mountpoint }}."

      - alert: ContainerRestarted
        expr: increase(kube_pod_container_status_restarts_total[1h]) > 0
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.container }} restarted"
          description: "Container {{ $labels.container }} in pod {{ $labels.pod }} restarted {{ $value }} times in the last hour."

      - alert: KopiaBackupFailed
        expr: kopia_backup_last_success_timestamp < time() - 86400
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Kopia backup has not succeeded in 24 hours"
          description: "The last successful Kopia backup was more than 24 hours ago."

      - alert: VPNConnectionDown
        expr: up{job="gluetun"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "VPN connection is down"
          description: "The Gluetun VPN connection has been down for more than 2 minutes."

      - alert: SMARTDiskFailure
        expr: smartctl_health_status{status="FAILED"} == 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "SMART failure detected on {{ $labels.device }}"
          description: "SMART health check failed on device {{ $labels.device }}. Consider replacing the disk."
```

#### Alertmanager Configuration

```yaml
# config/alertmanager/config.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@your-domain.com'
  smtp_auth_username: 'alerts@your-domain.com'
  smtp_auth_password: 'your-app-password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
    - match:
        severity: warning
      receiver: 'warning-alerts'

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: '{{ .Env "ALERT_EMAIL_TO" }}'
        subject: 'PotatoStack Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Labels: {{ range .Labels.SortedPairs }}{{ .Name }}: {{ .Value }}{{ end }}
          {{ end }}

  - name: 'critical-alerts'
    email_configs:
      - to: '{{ .Env "ALERT_EMAIL_TO" }}'
        subject: 'CRITICAL: PotatoStack Alert - {{ .GroupLabels.alertname }}'
        body: |
          🚨 CRITICAL ALERT 🚨
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Instance: {{ .Labels.instance }}
          {{ end }}
          
          Please investigate immediately!

  - name: 'warning-alerts'
    email_configs:
      - to: '{{ .Env "ALERT_EMAIL_TO" }}'
        subject: 'WARNING: PotatoStack Alert - {{ .GroupLabels.alertname }}'
        body: |
          ⚠️ WARNING ALERT ⚠️
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Instance: {{ .Labels.instance }}
          {{ end }}
          
          Please review when convenient.

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

---

## Integration Guide

### Third-Party Integrations

#### Email Integration (Gmail)

```yaml
# Gmail SMTP Configuration
SMTP Settings:
  Server: smtp.gmail.com
  Port: 587 (TLS) or 465 (SSL)
  Security: STARTTLS or SSL/TLS
  Authentication: App Password (required)

Steps to Configure:
  1. Enable 2-Factor Authentication on Gmail
  2. Generate App Password for "Mail"
  3. Use App Password in ALERT_EMAIL_PASSWORD
  4. Configure Alertmanager with Gmail settings
```

#### Telegram Integration

```yaml
# Telegram Bot Configuration
Steps to Configure:
  1. Create Telegram Bot via @BotFather
  2. Get Bot Token
  3. Get Chat ID (send message to bot, then call API)
  4. Configure Diun in config/diun/diun.yml

Configuration in diun.yml:
  notif:
    telegram:
      token: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
      chatIDs:
        - -123456789
```

#### Discord Integration

```yaml
# Discord Webhook Configuration
Steps to Configure:
  1. Go to Discord Server Settings > Integrations > Webhooks
  2. Create New Webhook
  3. Copy Webhook URL
  4. Configure Diun in config/diun/diun.yml

Configuration in diun.yml:
  notif:
    discord:
      webhookURL: https://discord.com/api/webhooks/123456789012345678/ABCdefGHIjklMNOpqrsTUVwxyz
      mentions:
        - "@everyone"
```

#### Netdata Cloud Integration

```yaml
# Netdata Cloud Configuration
Steps to Configure:
  1. Sign up at netdata.cloud
  2. Create Space and Room
  3. Get Claim Token and Room IDs
  4. Configure environment variables

Environment Variables:
  NETDATA_CLAIM_TOKEN=<your_claim_token>
  NETDATA_CLAIM_ROOMS=<room1,room2>
```

### Mobile App Integration

#### Nextcloud Mobile Apps

```yaml
# iOS Configuration
App: Nextcloud (Official)
Download: App Store
Configuration:
  Server URL: http://192.168.178.40:8082
  Username: Your Nextcloud username
  Password: Your Nextcloud password
  Certificate: Accept self-signed certificate

# Android Configuration  
App: Nextcloud (Official)
Download: Google Play Store
Configuration:
  Server URL: http://192.168.178.40:8082
  Username: Your Nextcloud username
  Password: Your Nextcloud password
  Certificate: Accept self-signed certificate
```

#### Grafana Mobile App

```yaml
# Mobile App Configuration
iOS: Grafana Mobile (Official)
Android: Grafana Mobile (Official)

Configuration:
  Server URL: http://192.168.178.40:3000
  Username: admin
  Password: Your Grafana password
  Protocol: HTTP (not HTTPS for local IP)
```

### API Client Integration

#### Python Client Example

```python
import requests
import json
from datetime import datetime

class PotatoStackClient:
    def __init__(self, base_url="http://192.168.178.40", auth=None):
        self.base_url = base_url
        self.auth = auth
        self.session = requests.Session()
        
    def get_service_health(self):
        """Get service health status"""
        url = f"{self.base_url}:3003/api/health"
        response = self.session.get(url)
        return response.json()
    
    def get_system_metrics(self):
        """Get Prometheus metrics"""
        url = f"{self.base_url}:9090/api/v1/query"
        params = {"query": "up"}
        response = self.session.get(url, params=params)
        return response.json()
    
    def get_nextcloud_users(self, username, password):
        """Get Nextcloud users"""
        url = f"{self.base_url}:8082/ocs/v2.php/cloud/users"
        auth = (username, password)
        headers = {"Accept": "application/json"}
        response = self.session.get(url, auth=auth, headers=headers)
        return response.json()
    
    def get_kopia_snapshots(self, username, password):
        """Get Kopia snapshots"""
        url = f"{self.base_url}:51515/api/v1/snapshots"
        auth = (username, password)
        response = self.session.get(url, auth=auth)
        return response.json()

# Usage Example
client = PotatoStackClient()

# Get service health
health = client.get_service_health()
print(json.dumps(health, indent=2))

# Get system metrics
metrics = client.get_system_metrics()
print(json.dumps(metrics, indent=2))
```

#### Go Client Example

```go
package main

import (
    "encoding/json"
    "fmt"
    "net/http"
    "time"
)

type PotatoStackClient struct {
    BaseURL string
    Client  *http.Client
}

type ServiceHealth struct {
    Services map[string]struct {
        Status       string `json:"status"`
        ResponseTime int    `json:"response_time"`
        URL          string `json:"url"`
    } `json:"services"`
    Timestamp time.Time `json:"timestamp"`
}

func NewPotatoStackClient(baseURL string) *PotatoStackClient {
    return &PotatoStackClient{
        BaseURL: baseURL,
        Client: &http.Client{
            Timeout: 10 * time.Second,
        },
    }
}

func (c *PotatoStackClient) GetServiceHealth() (*ServiceHealth, error) {
    url := fmt.Sprintf("%s:3003/api/health", c.BaseURL)
    
    resp, err := c.Client.Get(url)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    var health ServiceHealth
    if err := json.NewDecoder(resp.Body).Decode(&health); err != nil {
        return nil, err
    }
    
    return &health, nil
}

func (c *PotatoStackClient) GetPrometheusMetrics(query string) (map[string]interface{}, error) {
    url := fmt.Sprintf("%s:9090/api/v1/query", c.BaseURL)
    
    req, err := http.NewRequest("GET", url, nil)
    if err != nil {
        return nil, err
    }
    
    q := req.URL.Query()
    q.Set("query", query)
    req.URL.RawQuery = q.Encode()
    
    resp, err := c.Client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    var result map[string]interface{}
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, err
    }
    
    return result, nil
}

func main() {
    client := NewPotatoStackClient("http://192.168.178.40")
    
    // Get service health
    health, err := client.GetServiceHealth()
    if err != nil {
        fmt.Printf("Error getting health: %v\n", err)
        return
    }
    
    fmt.Printf("Service Health:\n%+v\n", health)
    
    // Get Prometheus metrics
    metrics, err := client.GetPrometheusMetrics("up")
    if err != nil {
        fmt.Printf("Error getting metrics: %v\n", err)
        return
    }
    
    fmt.Printf("Prometheus Metrics:\n%+v\n", metrics)
}
```

---

## Performance Benchmarks

### Resource Utilization

#### CPU Usage by Service

| Service | Idle (%) | Active (%) | Peak (%) | Cores |
|---------|----------|------------|----------|-------|
| gluetun | 2-5 | 5-15 | 25 | 1.0 |
| qbittorrent | 3-8 | 10-30 | 40 | 1.5 |
| slskd | 2-5 | 8-20 | 30 | 1.0 |
| nextcloud | 5-10 | 15-35 | 50 | 1.5 |
| kopia | 3-8 | 20-60 | 80 | 2.0 |
| prometheus | 5-12 | 10-25 | 35 | 1.0 |
| grafana | 3-8 | 8-20 | 30 | 1.0 |
| loki | 2-5 | 5-15 | 25 | 0.5 |

#### Memory Usage by Service

| Service | Idle (MB) | Active (MB) | Peak (MB) | Limit (MB) |
|---------|-----------|-------------|-----------|------------|
| gluetun | 50-80 | 80-150 | 200 | 256 |
| qbittorrent | 100-150 | 200-400 | 500 | 512 |
| slskd | 80-120 | 150-300 | 380 | 384 |
| nextcloud | 200-300 | 300-450 | 512 | 512 |
| kopia | 200-300 | 400-600 | 768 | 768 |
| prometheus | 150-250 | 250-400 | 512 | 512 |
| grafana | 100-180 | 180-300 | 384 | 384 |
| loki | 50-100 | 100-200 | 256 | 256 |

#### Network Performance

| Metric | Value | Notes |
|--------|-------|-------|
| **VPN Throughput** | 50-100 Mbps | Surfshark OpenVPN |
| **File Transfer (Nextcloud)** | 30-80 MB/s | Local network |
| **Database Queries** | < 100ms | Simple queries |
| **API Response Time** | < 500ms | Homepage dashboard |
| **Container Startup** | 10-60s | Depends on service |

#### Storage Performance

| Storage Type | Read (MB/s) | Write (MB/s) | IOPS | Notes |
|--------------|-------------|--------------|------|-------|
| **SD Card (OS)** | 20-40 | 10-25 | 100-300 | Read-heavy |
| **Main HDD** | 80-150 | 60-120 | 150-300 | General data |
| **Cache HDD** | 100-180 | 80-140 | 200-400 | Downloads |

### Throughput Benchmarks

#### Concurrent User Limits

| Service | Concurrent Users | Response Time | Notes |
|---------|------------------|---------------|-------|
| **Homepage** | 50-100 | < 1s | Dashboard only |
| **Nextcloud** | 10-25 | < 2s | File operations |
| **Grafana** | 5-15 | < 3s | Dashboard queries |
| **Kopia** | 5-10 | < 5s | Backup operations |
| **qBittorrent** | 100-500 | N/A | Many torrents |

#### Backup Performance

| Operation | Time | Throughput | Notes |
|-----------|------|------------|-------|
| **Daily Snapshot** | 15-30 min | 50-100 MB/min | Incremental |
| **Weekly Full** | 2-4 hours | 100-200 MB/min | Complete |
| **Kopia Sync** | 5-15 min | 1-5 GB/min | Network backup |
| **Restore Test** | 30-60 min | 1-3 GB/min | Random files |

---

## Security Specifications

### Authentication & Authorization

#### Multi-Factor Authentication Support

| Service | 2FA Method | Configuration |
|---------|------------|---------------|
| **Nextcloud** | TOTP, U2F, WebAuthn | Admin panel |
| **Nginx Proxy Manager** | 2FA plugin | Web interface |
| **Portainer** | 2FA, LDAP | Security settings |
| **Gitea** | TOTP, U2F | User settings |

#### Access Control Matrix

| Service | Anonymous | Authenticated | Admin | API |
|---------|-----------|---------------|-------|-----|
| **Homepage** | Yes (configurable) | Yes | Full | Read-only |
| **Nextcloud** | No | Yes (user-specific) | Yes | Full |
| **Grafana** | No | Yes (viewer/editor) | Admin | Read-only |
| **Kopia** | No | Yes (user-specific) | Admin | Full |
| **qBittorrent** | No | Yes (user-specific) | Admin | Full |

### Network Security

#### Firewall Rules

```bash
#!/bin/bash
# UFW Firewall Configuration

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (restrict to specific IPs)
sudo ufw allow from 192.168.178.0/24 to any port 22

# Allow HTTP/HTTPS for reverse proxy
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow specific service ports (internal network only)
sudo ufw allow from 192.168.178.0/24 to any port 3000  # Grafana
sudo ufw allow from 192.168.178.0/24 to any port 3001  # Gitea
sudo ufw allow from 192.168.178.0/24 to any port 3002  # Uptime Kuma
sudo ufw allow from 192.168.178.0/24 to any port 3003  # Homepage
sudo ufw allow from 192.168.178.0/24 to any port 8082  # Nextcloud
sudo ufw allow from 192.168.178.0/24 to any port 9000  # Portainer
sudo ufw allow from 192.168.178.0/24 to any port 9090  # Prometheus
sudo ufw allow from 192.168.178.0/24 to any port 19999 # Netdata

# Allow WireGuard VPN
sudo ufw allow 51820/udp

# Rate limiting for SSH
sudo ufw limit ssh

# Enable firewall
sudo ufw enable
```

#### SSL/TLS Configuration

```yaml
# Nginx Proxy Manager SSL Configuration
SSL Configuration:
  Protocol: TLS 1.2, TLS 1.3
  Cipher Suites: Modern compatibility
  Certificate: Let's Encrypt (automated)
  Certificate Authority: ISRG Root X1
  OCSP Stapling: Enabled
  HSTS: Enabled (max-age=31536000)
  
SSL Settings:
  ssl_protocols: TLSv1.2 TLSv1.3
  ssl_ciphers: ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
  ssl_prefer_server_ciphers: off
  ssl_session_cache: shared:SSL:10m
  ssl_session_timeout: d
```

### 1 Data Protection

#### Encryption Specifications

| Data Type | Algorithm | Key Size | Notes |
|-----------|-----------|----------|-------|
| **Kopia Backups** | AES-256-GCM | 256-bit | Client-side encryption |
| **Database** | AES-256-CBC | 256-bit | MariaDB/PostgreSQL |
| **File System** | LUKS | 256-bit | Full disk encryption |
| **Network** | TLS 1.3 | 256-bit | All HTTPS traffic |
| **VPN** | OpenVPN AES-256 | 256-bit | P2P traffic |

#### Key Management

```bash
# Key Generation and Management

# Generate strong passwords
openssl rand -base64 32  # For database passwords
openssl rand -base64 64  # For Kopia encryption

# Generate SSH keys for remote access
ssh-keygen -t ed25519 -C "potatostack-admin"

# Certificate management (Let's Encrypt)
certbot certonly --standalone -d your-domain.com

# GPG keys for sensitive data
gpg --gen-key
```

### Security Monitoring

#### Log Analysis

```bash
#!/bin/bash
# Security log analysis script

echo "=== SECURITY LOG ANALYSIS ==="

# Failed login attempts
echo "Failed SSH login attempts:"
grep "Failed password" /var/log/auth.log | tail -20

# Docker security events
echo -e "\nDocker security events:"
docker events --since 1h | grep -E "destroy|kill|die" | tail -10

# Suspicious network connections
echo -e "\nSuspicious network connections:"
ss -tuln | grep -v ":80\|:443\|:22\|:8080\|:3000\|:3001\|:3002\|:3003\|:8082\|:9000\|:9090\|:19999\|:51515"

# Container security scans
echo -e "\nContainer security scan:"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity HIGH,CRITICAL \
  $(docker images --format "{{.Repository}}:{{.Tag}}" | head -5)

echo "=== ANALYSIS COMPLETE ==="
```

#### Vulnerability Scanning

```bash
#!/bin/bash
# Vulnerability scanning script

echo "=== VULNERABILITY SCANNING ==="

# System packages
echo "Scanning system packages..."
sudo apt list --upgradable | grep -i security

# Container images
echo "Scanning container images..."
if command -v trivy >/dev/null 2>&1; then
  docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
    echo "Scanning $image..."
    trivy image --severity HIGH,CRITICAL "$image"
  done
fi

# Open ports scan
echo "Scanning open ports..."
nmap -sS -O 127.0.0.1

# SSL certificate check
echo "Checking SSL certificates..."
find /etc/letsencrypt -name "*.pem" -exec openssl x509 -in {} -text -noout \; | \
  grep -E "Not After|Subject:|Issuer:"

echo "=== SCANNING COMPLETE ==="
```

---

**Document Version**: 2.0  
**Last Updated**: December 2025  
**Classification**: Internal Use  
**Review Cycle**: Quarterly  
**Technical Owner**: Infrastructure Team
