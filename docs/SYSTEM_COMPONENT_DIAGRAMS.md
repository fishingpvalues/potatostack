# PotatoStack System Component Diagrams

## Table of Contents

1. [Service Component Model](#service-component-model)
2. [Container Architecture](#container-architecture)
3. [Data Flow Diagrams](#data-flow-diagrams)
4. [Network Topology](#network-topology)
5. [Security Layer Architecture](#security-layer-architecture)
6. [Monitoring Stack](#monitoring-stack)
7. [Storage Architecture](#storage-architecture)
8. [Deployment Architecture](#deployment-architecture)

---

## Service Component Model

### Core Services Component Diagram

```mermaid
graph TB
    subgraph "User Interface Layer"
        UI[Homepage Dashboard]
        WEB[Web Interfaces]
    end
    
    subgraph "Application Services"
        subgraph "Media & Communication"
            QBT[qBittorrent<br/>Torrent Client]
            SLSK[slskd<br/>Soulseek Client]
        end
        
        subgraph "Data Management"
            NC[Nextcloud<br/>File Sync]
            KOP[Kopia<br/>Backup System]
        end
        
        subgraph "Development"
            GT[Gitea<br/>Git Server]
        end
        
        subgraph "Management"
            PE[Portainer<br/>Container Mgmt]
            UK[Uptime Kuma<br/>Monitoring]
            DW[Dozzle<br/>Log Viewer]
        end
    end
    
    subgraph "Infrastructure Services"
        subgraph "Proxy & Load Balancing"
            NPM[Nginx Proxy Manager<br/>SSL Termination]
        end
        
        subgraph "VPN & Security"
            VPN[Surfshark VPN<br/>P2P Protection]
        end
    end
    
    subgraph "Data Services"
        subgraph "Databases"
            NCDB[(Nextcloud DB<br/>MariaDB)]
            GTDB[(Gitea DB<br/>PostgreSQL)]
        end
        
        subgraph "Storage"
            HDD1[/mnt/seconddrive]
            HDD2[/mnt/cachehdd]
            VOL[Docker Volumes]
        end
    end
    
    subgraph "System Services"
        DN[Diun<br/>Update Notifications]
        AH[Autoheal<br/>Restart Unhealthy]
    end
    
    UI --> NPM
    UI --> WEB
    
    NPM --> NC
    NPM --> KOP
    NPM --> GT
    NPM --> PE
    NPM --> UK
    NPM --> DW
    
    QBT --> VPN
    SLSK --> VPN
    
    NC --> NCDB
    NC --> HDD1
    KOP --> HDD1
    GT --> GTDB
    GT --> HDD1
    
    QBT --> HDD2
    SLSK --> HDD2
    
    WT --> PE
```

---

## Container Architecture

### Container Relationship Diagram

```mermaid
classDiagram
    class ContainerService {
        +name: string
        +image: string
        +status: ContainerStatus
        +restart_policy: RestartPolicy
        +health_check: HealthCheck
        +resource_limits: ResourceLimits
        +networks: Network[]
        +volumes: Volume[]
        +environment: EnvironmentVars
        +depends_on: Service[]
        +start()
        +stop()
        +restart()
        +status()
    }
    
    class VPNContainer {
        +type: VPNProvider
        +killswitch: boolean
        +network_mode: service
        +ports: PortMapping[]
        +check_vpn_connection()
        +get_public_ip()
    }
    
    class DatabaseContainer {
        +db_type: DatabaseType
        +volume: Volume
        +connection_string: string
        +backup_strategy: BackupStrategy
        +backup()
        +restore()
        +migrate()
    }
    
    class WebServiceContainer {
        +port: Port
        +ssl_enabled: boolean
        +proxy_config: ProxyConfig
        +authentication: AuthConfig
        +start_web_service()
        +stop_web_service()
    }
    
    class MonitoringContainer {
        +metrics_endpoint: string
        +log_endpoint: string
        +scrape_interval: Duration
        +collect_metrics()
        +send_alerts()
    }
    
    ContainerService <|-- VPNContainer
    ContainerService <|-- DatabaseContainer
    ContainerService <|-- WebServiceContainer
    ContainerService <|-- MonitoringContainer
    
    class SurfsharkVPN {
        +provider: "Surfshark"
        +country: "Netherlands"
        +protocol: "OpenVPN"
    }
    
    class QBitTorrent {
        +web_ui_port: 8080
        +torrent_port: 6881
        +network_mode: "service:gluetun"
    }
    
    class SLSKD {
        +http_port: 2234
        +slsk_port: 50000
        +network_mode: "service:gluetun"
    }
    
    class NextcloudDB {
        +type: "MariaDB"
        +version: "10.11"
        +volume: "nextcloud_db"
    }
    
    class GiteaDB {
        +type: "PostgreSQL"
        +version: "14"
        +volume: "gitea_db"
    }
    
    class NginxProxyManager {
        +http_port: 80
        +https_port: 443
        +admin_port: 81
    }
    
    class Prometheus {
        +port: 9090
        +scrape_interval: "15s"
        +retention: "30d"
    }
    
    class Grafana {
        +port: 3000
        +admin_user: string
        +datasources: DataSource[]
    }
    
    VPNContainer <|-- SurfsharkVPN
    WebServiceContainer <|-- QBitTorrent
    WebServiceContainer <|-- SLSKD
    DatabaseContainer <|-- NextcloudDB
    DatabaseContainer <|-- GiteaDB
    WebServiceContainer <|-- NginxProxyManager
    MonitoringContainer <|-- Prometheus
    MonitoringContainer <|-- Grafana
```

---

## Data Flow Diagrams

### User Authentication Flow

```mermaid
sequenceDiagram
    participant U as User
    participant HP as Homepage
    participant NPM as Nginx Proxy
    participant AUTH as Auth Service
    participant APP as Application
    participant DB as Database
    participant AUDIT as Audit Log
    
    U->>HP: Login Request
    HP->>NPM: Forward to Service
    NPM->>AUTH: Authentication Request
    AUTH->>DB: Verify Credentials
    DB-->>AUTH: User Data
    AUTH->>AUTH: Validate & Create Session
    AUTH->>AUDIT: Log Authentication Event
    AUTH-->>NPM: Auth Success + Session Token
    NPM-->>HP: Redirect to Service
    HP->>APP: Access with Session Token
    APP->>DB: Fetch User Data
    DB-->>APP: User Information
    APP-->>HP: Service Response
    HP-->>U: Dashboard Display
```

### File Upload Flow

```mermaid
sequenceDiagram
    participant U as User
    participant NC as Nextcloud
    participant NPM as Nginx Proxy
    participant ST as Storage Layer
    participant DB as Nextcloud DB
    participant BK as Kopia Backup
    participant PM as Prometheus
    
    U->>NPM: File Upload Request
    NPM->>NC: Forward Upload
    NC->>NC: Process File
    NC->>ST: Store File Data
    ST-->>NC: Storage Confirmation
    NC->>DB: Update Metadata
    DB-->>NC: Metadata Saved
    NC->>BK: Trigger Backup
    BK->>BK: Create Snapshot
    BK->>PM: Export Metrics
    PM-->>BK: Metrics Endpoint
    BK-->>NC: Backup Confirmation
    NC-->>NPM: Upload Success
    NPM-->>U: Success Response
```

### P2P Traffic Flow

```mermaid
sequenceDiagram
    participant P2P as P2P Client
    participant VPN as Surfshark VPN
    participant EXT as External Peers
    participant MON as Monitoring
    participant LG as Logging
    
    P2P->>VPN: Connect to Peers
    VPN->>VPN: Encrypt Traffic
    VPN->>EXT: Encrypted P2P Connection
    EXT-->>VPN: Peer Response
    VPN-->>P2P: Decrypted Data
    P2P->>P2P: Process Data
    P2P->>MON: Export Metrics
    MON->>LG: Log Connection
    LG->>LG: Store in Loki
    
    Note over P2P,LG: All P2P traffic is encrypted and monitored
```

---

## Network Topology

### Detailed Network Architecture

```mermaid
graph TB
    subgraph "External Network"
        subgraph "Internet"
            PEERS[BitTorrent Peers]
            SLSK_NET[Soulseek Network]
            CDN[Content Delivery]
        end
        
        subgraph "VPN Providers"
            SS[Surfshark Servers]
        end
    end
    
    subgraph "Perimeter"
        ROUTER[Fritzbox Router<br/>192.168.178.0/24]
        WG[WireGuard VPN<br/>Remote Access]
        FW[Firewall Rules]
    end
    
    subgraph "Docker Network Stack"
        subgraph "potatostack_vpn"
            VPN_CONTAINER[Surfshark VPN Container]
            QBT_CONTAINER[qBittorrent]
            SLSK_CONTAINER[slskd]
        end
        
        subgraph "potatostack_proxy"
            NPM_CONTAINER[Nginx Proxy Manager]
            HP_CONTAINER[Homepage]
            KOP_CONTAINER[Kopia]
            DW_CONTAINER[Dozzle]
        end
        
        subgraph "potatostack_monitoring"
            PM_CONTAINER[Prometheus]
            GF_CONTAINER[Grafana]
            LK_CONTAINER[Loki]
            AM_CONTAINER[Alertmanager]
            NE_CONTAINER[node-exporter]
            CA_CONTAINER[cadvisor]
            SE_CONTAINER[smartctl-exporter]
            NETD_CONTAINER[netdata]
            DN_CONTAINER[diun]
            AH_CONTAINER[autoheal]
        end
        
        subgraph "potatostack_default"
            NC_CONTAINER[Nextcloud]
            NCDB_CONTAINER[Nextcloud DB]
            GT_CONTAINER[Gitea]
            GTDB_CONTAINER[Gitea DB]
            PE_CONTAINER[Portainer]
            UK_CONTAINER[Uptime Kuma]
        end
    end
    
    subgraph "Physical Network"
        ETH0[eth0 Interface<br/>192.168.178.40]
        USB_NET[USB Network Adapters]
    end
    
    subgraph "Storage Network"
        SATA1[SATA Controller 1]
        SATA2[SATA Controller 2]
        USB_HDD[USB HDD Controllers]
    end
    
    PEERS --> ROUTER
    SLSK_NET --> ROUTER
    CDN --> ROUTER
    SS --> ROUTER
    
    ROUTER --> FW
    FW --> WG
    WG --> ETH0
    
    ETH0 --> VPN_CONTAINER
    ETH0 --> NPM_CONTAINER
    ETH0 --> HP_CONTAINER
    
    VPN_CONTAINER --> QBT_CONTAINER
    VPN_CONTAINER --> SLSK_CONTAINER
    
    NPM_CONTAINER --> NC_CONTAINER
    NPM_CONTAINER --> GT_CONTAINER
    NPM_CONTAINER --> KOP_CONTAINER
    NPM_CONTAINER --> PE_CONTAINER
    NPM_CONTAINER --> UK_CONTAINER
    
    PM_CONTAINER --> GF_CONTAINER
    LK_CONTAINER --> GF_CONTAINER
    AM_CONTAINER --> GF_CONTAINER
    
    NC_CONTAINER --> NCDB_CONTAINER
    GT_CONTAINER --> GTDB_CONTAINER
    
    SATA1 --> NCDB_CONTAINER
    SATA2 --> GTDB_CONTAINER
    USB_HDD --> NC_CONTAINER
```

---

## Security Layer Architecture

### Security Component Model

```mermaid
graph TB
    subgraph "Network Security"
        subgraph "Perimeter Security"
            FW[Firewall<br/>Port Blocking]
            IDS[Intrusion Detection]
            VPN_TUNNEL[VPN Tunnel<br/>Encrypted Channel]
        end
        
        subgraph "Application Security"
            SSL_TLS[SSL/TLS<br/>Certificate Management]
            HSTS[HSTS<br/>Security Headers]
            RATE_LIMIT[Rate Limiting<br/>DDoS Protection]
        end
    end
    
    subgraph "Authentication & Authorization"
        subgraph "Multi-Factor Auth"
            TOTP[TOTP<br/>Time-based OTP]
            U2F[U2F<br/>Hardware Keys]
        end
        
        subgraph "Access Control"
            RBAC[Role-Based Access<br/>Permission Management]
            SESSION[Session Management<br/>Secure Tokens]
        end
    end
    
    subgraph "Data Security"
        subgraph "Encryption"
            ENCRYPT_AT_REST[Encryption at Rest<br/>AES-256]
            ENCRYPT_IN_TRANSIT[Encryption in Transit<br/>TLS 1.3]
        end
        
        subgraph "Backup Security"
            BACKUP_ENCRYPT[Backup Encryption<br/>Kopia]
            KEY_MANAGEMENT[Key Management<br/>Secure Storage]
        end
    end
    
    subgraph "Monitoring & Compliance"
        subgraph "Audit"
            AUDIT_LOG[Audit Logging<br/>All Actions]
            COMPLIANCE[Compliance Monitoring<br/>GDPR, SOC2]
        end
        
        subgraph "Threat Detection"
            ANOMALY[Anomaly Detection<br/>Behavioral Analysis]
            ALERT[Security Alerting<br/>Real-time Response]
        end
    end
    
    FW --> IDS
    IDS --> VPN_TUNNEL
    
    VPN_TUNNEL --> SSL_TLS
    SSL_TLS --> HSTS
    HSTS --> RATE_LIMIT
    
    TOTP --> U2F
    U2F --> RBAC
    RBAC --> SESSION
    
    ENCRYPT_AT_REST --> ENCRYPT_IN_TRANSIT
    ENCRYPT_IN_TRANSIT --> BACKUP_ENCRYPT
    BACKUP_ENCRYPT --> KEY_MANAGEMENT
    
    AUDIT_LOG --> COMPLIANCE
    COMPLIANCE --> ANOMALY
    ANOMALY --> ALERT
```

---

## Monitoring Stack

### Observability Architecture

```mermaid
graph TB
    subgraph "Metrics Collection"
        subgraph "System Metrics"
            NODE[Node Exporter<br/>System Stats]
            SMART[SMART Exporter<br/>Disk Health]
            CPU[CPU Metrics]
            MEM[Memory Metrics]
            NET[Network Metrics]
        end
        
        subgraph "Application Metrics"
            APP[Application Exporters]
            DB[Database Metrics]
            CUSTOM[Custom Metrics]
        end
        
        subgraph "Container Metrics"
            CADV[cAdvisor<br/>Container Stats]
            DOCKER[Docker Metrics]
        end
    end
    
    subgraph "Log Collection"
        PROMT[Promtail<br/>Log Shipper]
        CONTAINER_LOGS[Container Logs]
        SYSTEM_LOGS[System Logs]
        APP_LOGS[Application Logs]
    end
    
    subgraph "Storage Layer"
        PROM[Prometheus<br/>Time Series DB]
        LOKI[Loki<br/>Log Storage]
        THANOS[Thanos<br/>Long-term Storage]
    end
    
    subgraph "Analysis & Visualization"
        GRAF[Grafana<br/>Dashboards]
        ALERTMGR[Alertmanager<br/>Alert Routing]
        THANOS_Q[Thanos Query<br/>Unified Query]
    end
    
    subgraph "Alerting Channels"
        EMAIL[Email<br/>SMTP]
        TELEGRAM[Telegram<br/>Bot API]
        SLACK[Slack<br/>Webhook]
        DISCORD[Discord<br/>Webhook]
    end
    
    NODE --> PROM
    SMART --> PROM
    CPU --> PROM
    MEM --> PROM
    NET --> PROM
    APP --> PROM
    DB --> PROM
    CUSTOM --> PROM
    CADV --> PROM
    DOCKER --> PROM
    
    PROMT --> LOKI
    CONTAINER_LOGS --> PROMT
    SYSTEM_LOGS --> PROMT
    APP_LOGS --> PROMT
    
    PROM --> THANOS
    THANOS --> THANOS_Q
    
    PROM --> GRAF
    LOKI --> GRAF
    THANOS_Q --> GRAF
    
    GRAF --> ALERTMGR
    ALERTMGR --> EMAIL
    ALERTMGR --> TELEGRAM
    ALERTMGR --> SLACK
    ALERTMGR --> DISCORD
```

---

## Storage Architecture

### Data Storage Hierarchy

```mermaid
graph TB
    subgraph "Physical Storage"
        subgraph "Primary Storage"
            SD_CARD[SD Card<br/>16GB+<br/>OS + Base System]
            HDD_MAIN[Main HDD<br/>500GB+<br/>Primary Data]
            HDD_CACHE[Cache HDD<br/>250GB+<br/>Temporary Data]
        end
        
        subgraph "Network Storage"
            NAS[Network Attached Storage<br/>Backup Target]
            CLOUD[Cloud Storage<br/>Off-site Backup]
        end
    end
    
    subgraph "Docker Volume Management"
        subgraph "Named Volumes"
            VOL_NC_DATA[nextcloud_data<br/>User Files]
            VOL_NC_DB[nextcloud_db<br/>Nextcloud Database]
            VOL_GT_DATA[gitea_data<br/>Git Repositories]
            VOL_GT_DB[gitea_db<br/>Gitea Database]
            VOL_PM[prometheus_data<br/>Metrics Storage]
            VOL_GF[grafana_data<br/>Dashboard Config]
            VOL_LK[loki_data<br/>Log Storage]
            VOL_PE[portainer_data<br/>Portainer Config]
        end
    end
    
    subgraph "Application Data Structure"
        subgraph "Main HDD Data"
            subgraph "User Data"
                NC_USER[/nextcloud/user_data/]
                NC_SHARED[/nextcloud/shared/]
            end
            
            subgraph "System Data"
                KOP_REPO[/kopia/repository/]
                KOP_CACHE[/kopia/cache/]
                KOP_CONFIG[/kopia/config/]
                GT_REPOS[/gitea/repositories/]
                UK_DATA[/uptime-kuma/data/]
            end
        end
        
        subgraph "Cache HDD Data"
            subgraph "Downloads"
                TORRENTS[/torrents/]
                INCOMPLETE[/torrents/incomplete/]
                CATEGORIES[/torrents/*/<br/>movies, music, etc.]
            end
            
            subgraph "P2P Cache"
                SOULSEEK[/soulseek/]
                SL_INCOMPLETE[/soulseek/incomplete/]
                SL_CATEGORIES[/soulseek/*/<br/>categorized downloads]
            end
        end
    end
    
    subgraph "Backup Strategy"
        subgraph "Local Backup"
            SNAPSHOT[Automated Snapshots<br/>Kopia]
            RETENTION[Retention Policy<br/>30 days rolling]
        end
        
        subgraph "Remote Backup"
            OFFSITE[Off-site Replication<br/>NAS/Cloud]
            VERIFICATION[Backup Verification<br/>Integrity Checks]
        end
    end
    
    SD_CARD --> VOL_NC_DATA
    SD_CARD --> VOL_NC_DB
    SD_CARD --> VOL_GT_DATA
    SD_CARD --> VOL_GT_DB
    SD_CARD --> VOL_PM
    SD_CARD --> VOL_GF
    SD_CARD --> VOL_LK
    SD_CARD --> VOL_PE
    
    HDD_MAIN --> NC_USER
    HDD_MAIN --> NC_SHARED
    HDD_MAIN --> KOP_REPO
    HDD_MAIN --> KOP_CACHE
    HDD_MAIN --> KOP_CONFIG
    HDD_MAIN --> GT_REPOS
    HDD_MAIN --> UK_DATA
    
    HDD_CACHE --> TORRENTS
    HDD_CACHE --> INCOMPLETE
    HDD_CACHE --> CATEGORIES
    HDD_CACHE --> SOULSEEK
    HDD_CACHE --> SL_INCOMPLETE
    HDD_CACHE --> SL_CATEGORIES
    
    KOP_REPO --> SNAPSHOT
    SNAPSHOT --> RETENTION
    RETENTION --> OFFSITE
    OFFSITE --> VERIFICATION
```

---

## Deployment Architecture

### Multi-Environment Deployment

```mermaid
graph TB
    subgraph "Source Control"
        GIT[Git Repository<br/>Version Control]
        BR_MAIN[Main Branch<br/>Production Ready]
        BR_DEV[Development Branch<br/>Feature Development]
        BR_STAGE[Staging Branch<br/>Pre-production Testing]
    end
    
    subgraph "CI/CD Pipeline"
        subgraph "Continuous Integration"
            BUILD[Build Stage<br/>Container Images]
            TEST[Test Stage<br/>Automated Testing]
            SCAN[Security Scan<br/>Vulnerability Check]
        end
        
        subgraph "Continuous Deployment"
            DEPLOY_STAGE[Deploy to Staging<br/>Integration Testing]
            VALIDATE[Validation Stage<br/>Health Checks]
            DEPLOY_PROD[Deploy to Production<br/>Blue-Green Deployment]
        end
    end
    
    subgraph "Environment Management"
        subgraph "Development Environment"
            DEV[Development Server<br/>Feature Testing]
            DEV_DB[(Development DB<br/>Test Data)]
        end
        
        subgraph "Staging Environment"
            STAGE[Staging Server<br/>Pre-production]
            STAGE_DB[(Staging DB<br/>Sanitized Data)]
        end
        
        subgraph "Production Environment"
            PROD[Production Server<br/>Live Services]
            PROD_DB[(Production DB<br/>Live Data)]
        end
    end
    
    subgraph "Monitoring & Alerting"
        MONITOR[Monitoring Stack<br/>All Environments]
        ALERT[Alert System<br/>Multi-channel]
        DASHBOARD[Operations Dashboard<br/>Unified View]
    end
    
    GIT --> BR_MAIN
    GIT --> BR_DEV
    GIT --> BR_STAGE
    
    BR_DEV --> BUILD
    BUILD --> TEST
    TEST --> SCAN
    SCAN --> DEPLOY_STAGE
    DEPLOY_STAGE --> VALIDATE
    VALIDATE --> DEPLOY_PROD
    
    DEPLOY_STAGE --> DEV
    VALIDATE --> STAGE
    DEPLOY_PROD --> PROD
    
    DEV --> DEV_DB
    STAGE --> STAGE_DB
    PROD --> PROD_DB
    
    DEV --> MONITOR
    STAGE --> MONITOR
    PROD --> MONITOR
    
    MONITOR --> ALERT
    MONITOR --> DASHBOARD
```

---

## Service Dependencies Matrix

| Service | Depends On | Required By | Network | Ports |
|---------|------------|-------------|---------|-------|
| **gluetun** | None | qbittorrent, slskd | vpn | - |
| **qbittorrent** | gluetun | homepage | vpn | 8080, 6881 |
| **slskd** | gluetun | homepage | vpn | 2234, 50000 |
| **kopia** | None | homepage, prometheus | proxy, monitoring | 51515, 51516 |
| **nextcloud** | nextcloud-db | homepage, prometheus | default, proxy | 8082 |
| **nextcloud-db** | None | nextcloud | default | - |
| **gitea** | gitea-db | homepage, prometheus | default, proxy | 3001, 2222 |
| **gitea-db** | None | gitea | default | - |
| **prometheus** | node-exporter, cadvisor, smartctl-exporter | grafana | monitoring | 9090 |
| **grafana** | prometheus, loki | homepage | monitoring, proxy | 3000 |
| **loki** | None | grafana, promtail | monitoring | 3100 |
| **alertmanager** | None | prometheus | monitoring, proxy | 9093 |
| **nginx-proxy-manager** | None | homepage, all web services | proxy, monitoring | 80, 443, 81 |
| **homepage** | nginx-proxy-manager, all services | None | proxy, monitoring, default | 3003 |
| **portainer** | None | homepage | default, proxy | 9000, 9443 |
| **uptime-kuma** | None | homepage | default, proxy, monitoring | 3002 |
| **dozzle** | None | homepage | proxy | 8083 |
| **diun** | docker socket (ro) | None | monitoring | - |
| **autoheal** | docker socket | None | default | - |

---

**Document Version**: 2.0  
**Last Updated**: December 2025  
**Classification**: Internal Use  
**Review Cycle**: Quarterly
