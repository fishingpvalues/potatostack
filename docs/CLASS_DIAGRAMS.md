# PotatoStack Class Diagrams

## Table of Contents
1. [Container Service Class Diagram](#container-service-class-diagram)
2. [VPN Container Class Diagram](#vpn-container-class-diagram)
3. [Database Container Class Diagram](#database-container-class-diagram)
4. [Web Service Container Class Diagram](#web-service-container-class-diagram)
5. [Monitoring Container Class Diagram](#monitoring-container-class-diagram)
6. [Service Implementation Classes](#service-implementation-classes)
7. [Network Architecture Classes](#network-architecture-classes)
8. [Storage Architecture Classes](#storage-architecture-classes)
9. [Security Architecture Classes](#security-architecture-classes)
10. [Monitoring Architecture Classes](#monitoring-architecture-classes)

---

## Container Service Class Diagram

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
```

---

## VPN Container Class Diagram

```mermaid
classDiagram
    class SurfsharkVPN {
        +provider: "Surfshark"
        +country: "Netherlands"
        +protocol: "OpenVPN"
        +killswitch: boolean
        +firewall_rules: FirewallRule[]
        +connect()
        +disconnect()
        +get_current_ip()
        +check_connection_health()
    }

    class QBitTorrent {
        +web_ui_port: 8080
        +torrent_port: 6881
        +network_mode: "service:gluetun"
        +max_connections: int
        +max_uploads: int
        +add_torrent()
        +remove_torrent()
        +get_torrent_status()
    }

    class SLSKD {
        +http_port: 2234
        +slsk_port: 50000
        +network_mode: "service:gluetun"
        +username: string
        +password: string
        +shared_folders: string[]
        +download_folder: string
        +login()
        +logout()
        +get_user_status()
    }

    VPNContainer <|-- SurfsharkVPN
    WebServiceContainer <|-- QBitTorrent
    WebServiceContainer <|-- SLSKD
```

---

## Database Container Class Diagram

```mermaid
classDiagram
    class NextcloudDB {
        +type: "MariaDB"
        +version: "10.11"
        +volume: "nextcloud_db"
        +connection_string: string
        +optimize_tables()
        +backup_database()
        +restore_database()
        +check_health()
    }

    class GiteaDB {
        +type: "PostgreSQL"
        +version: "14"
        +volume: "gitea_db"
        +connection_string: string
        +tuning_parameters: TuningParams
        +optimize_performance()
        +backup_database()
        +restore_database()
        +check_health()
    }

    class RedisCache {
        +version: "7-alpine"
        +port: 6379
        +max_memory: string
        +memory_policy: string
        +databases: int
        +connect()
        +disconnect()
        +get_cache_stats()
    }

    DatabaseContainer <|-- NextcloudDB
    DatabaseContainer <|-- GiteaDB
    ContainerService <|-- RedisCache
```

---

## Web Service Container Class Diagram

```mermaid
classDiagram
    class NginxProxyManager {
        +http_port: 80
        +https_port: 443
        +admin_port: 81
        +ssl_certificates: SSLCertificate[]
        +proxy_hosts: ProxyHost[]
        +add_proxy_host()
        +remove_proxy_host()
        +generate_ssl_certificate()
        +get_proxy_stats()
    }

    class Nextcloud {
        +port: 8082
        +admin_user: string
        +admin_password: string
        +trusted_domains: string[]
        +php_memory_limit: string
        +upload_limit: string
        +enable_maintenance_mode()
        +disable_maintenance_mode()
        +optimize_database()
        +get_user_stats()
    }

    class Gitea {
        +port: 3001
        +ssh_port: 2222
        +database_config: DatabaseConfig
        +redis_config: RedisConfig
        +create_repository()
        +delete_repository()
        +get_repository_stats()
    }

    class Kopia {
        +http_port: 51515
        +metrics_port: 51516
        +repository_path: string
        +cache_path: string
        +encryption_key: string
        +create_snapshot()
        +restore_snapshot()
        +verify_repository()
        +get_backup_stats()
    }

    WebServiceContainer <|-- NginxProxyManager
    WebServiceContainer <|-- Nextcloud
    WebServiceContainer <|-- Gitea
    WebServiceContainer <|-- Kopia
```

---

## Monitoring Container Class Diagram

```mermaid
classDiagram
    class Prometheus {
        +port: 9090
        +scrape_interval: "15s"
        +evaluation_interval: "15s"
        +retention_time: string
        +scrape_configs: ScrapeConfig[]
        +rule_files: string[]
        +add_scrape_target()
        +remove_scrape_target()
        +load_rules()
        +get_metric_stats()
    }

    class Grafana {
        +port: 3000
        +admin_user: string
        +admin_password: string
        +datasources: DataSource[]
        +dashboards: Dashboard[]
        +plugins: Plugin[]
        +add_datasource()
        +import_dashboard()
        +get_dashboard_stats()
    }

    class Loki {
        +port: 3100
        +retention_period: string
        +storage_config: StorageConfig
        +ingest_logs()
        +query_logs()
        +get_log_stats()
    }

    class Alertmanager {
        +port: 9093
        +route_config: RouteConfig
        +receiver_configs: ReceiverConfig[]
        +inhibit_rules: InhibitRule[]
        +send_alert()
        +silence_alert()
        +get_alert_stats()
    }

    MonitoringContainer <|-- Prometheus
    MonitoringContainer <|-- Grafana
    MonitoringContainer <|-- Loki
    MonitoringContainer <|-- Alertmanager
```

---

## Service Implementation Classes

```mermaid
classDiagram
    class ServiceManager {
        +services: Service[]
        +start_all()
        +stop_all()
        +restart_all()
        +get_service_status()
        +monitor_health()
    }

    class HealthCheck {
        +test_command: string[]
        +interval: Duration
        +timeout: Duration
        +retries: int
        +start_period: Duration
        +execute()
        +is_healthy()
    }

    class ResourceLimits {
        +memory_limit: string
        +memory_reservation: string
        +cpu_limit: float
        +cpu_reservation: float
        +apply()
        +get_usage()
    }

    class NetworkConfig {
        +networks: Network[]
        +ports: PortMapping[]
        +configure()
        +get_connection_stats()
    }

    class VolumeConfig {
        +volumes: Volume[]
        +mount_points: string[]
        +configure()
        +get_storage_stats()
    }

    class EnvironmentConfig {
        +variables: EnvironmentVar[]
        +load_from_file()
        +validate()
        +get_variable()
    }

    ServiceManager --> Service
    Service --> HealthCheck
    Service --> ResourceLimits
    Service --> NetworkConfig
    Service --> VolumeConfig
    Service --> EnvironmentConfig
```

---

## Network Architecture Classes

```mermaid
classDiagram
    class Network {
        +name: string
        +driver: string
        +subnet: string
        +gateway: string
        +create()
        +destroy()
        +connect_service()
        +disconnect_service()
    }

    class DockerNetwork {
        +network_mode: string
        +isolation: NetworkIsolation
        +firewall_rules: FirewallRule[]
        +configure_firewall()
        +get_traffic_stats()
    }

    class VPNNetwork {
        +vpn_provider: VPNProvider
        +vpn_protocol: string
        +killswitch: boolean
        +route_table: Route[]
        +add_route()
        +remove_route()
        +get_vpn_stats()
    }

    class ServiceNetwork {
        +service_name: string
        +network_mode: string
        +aliases: string[]
        +configure()
        +get_network_stats()
    }

    Network <|-- DockerNetwork
    Network <|-- VPNNetwork
    Network <|-- ServiceNetwork
```

---

## Storage Architecture Classes

```mermaid
classDiagram
    class StorageDevice {
        +device_path: string
        +mount_point: string
        +filesystem_type: string
        +size: string
        +usage: string
        +format()
        +mount()
        +unmount()
        +get_health_stats()
    }

    class HDDStorage {
        +smart_data: SMARTData
        +temperature: float
        +power_on_hours: int
        +reallocated_sectors: int
        +check_health()
        +get_performance_stats()
    }

    class DockerVolume {
        +name: string
        +driver: string
        +mount_path: string
        +create()
        +destroy()
        +get_usage_stats()
    }

    class BackupStorage {
        +repository_path: string
        +cache_path: string
        +encryption: EncryptionConfig
        +retention_policy: RetentionPolicy
        +create_snapshot()
        +restore_snapshot()
        +verify_integrity()
        +get_backup_stats()
    }

    StorageDevice <|-- HDDStorage
    StorageDevice <|-- DockerVolume
    StorageDevice <|-- BackupStorage
```

---

## Security Architecture Classes

```mermaid
classDiagram
    class SecurityManager {
        +firewall_rules: FirewallRule[]
        +ssl_certificates: SSLCertificate[]
        +authentication_providers: AuthProvider[]
        +audit_logs: AuditLog[]
        +configure_firewall()
        +generate_ssl_certificate()
        +add_auth_provider()
        +log_audit_event()
        +get_security_stats()
    }

    class FirewallRule {
        +source_ip: string
        +destination_port: int
        +protocol: string
        +action: string
        +add()
        +remove()
        +is_active()
    }

    class SSLCertificate {
        +domain: string
        +certificate: string
        +private_key: string
        +expiry_date: Date
        +generate()
        +renew()
        +is_valid()
    }

    class AuthProvider {
        +provider_type: string
        +config: AuthConfig
        +users: User[]
        +enable()
        +disable()
        +authenticate()
    }

    class AuditLog {
        +timestamp: Date
        +user: string
        +action: string
        +details: string
        +log()
        +query()
        +export()
    }

    SecurityManager --> FirewallRule
    SecurityManager --> SSLCertificate
    SecurityManager --> AuthProvider
    SecurityManager --> AuditLog
```

---

## Monitoring Architecture Classes

```mermaid
classDiagram
    class MonitoringSystem {
        +metrics_collectors: MetricCollector[]
        +log_collectors: LogCollector[]
        +alert_routers: AlertRouter[]
        +dashboards: Dashboard[]
        +collect_metrics()
        +collect_logs()
        +route_alerts()
        +create_dashboard()
        +get_monitoring_stats()
    }

    class MetricCollector {
        +collector_type: string
        +scrape_targets: ScrapeTarget[]
        +scrape_interval: Duration
        +collect()
        +get_metric()
        +get_stats()
    }

    class LogCollector {
        +log_source: string
        +log_format: string
        +retention_policy: RetentionPolicy
        +collect()
        +query()
        +get_stats()
    }

    class AlertRouter {
        +alert_rules: AlertRule[]
        +receivers: Receiver[]
        +route()
        +silence()
        +get_stats()
    }

    class Dashboard {
        +dashboard_id: string
        +panels: Panel[]
        +datasource: DataSource
        +create()
        +update()
        +export()
        +get_stats()
    }

    MonitoringSystem --> MetricCollector
    MonitoringSystem --> LogCollector
    MonitoringSystem --> AlertRouter
    MonitoringSystem --> Dashboard
```

---

**Document Version**: 2.0
**Last Updated**: December 2025
**Classification**: Internal Use
**Review Cycle**: Quarterly