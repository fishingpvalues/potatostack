# Enterprise-Grade Homelab Stack Optimization

**Target Hardware**: ThinkCentre/ASUS NUC 14 Mini PC
**Current Stack**: 73 services, optimized Docker Compose
**Goal**: Production-ready, enterprise-grade reliability

---

## 🏗️ Infrastructure Architecture

### Hardware Recommendations (2025)

**Best Options for 24/7 Enterprise Operation**:
- **Lenovo ThinkCentre M75q / M70q Gen 5**: Business-grade reliability, ECC memory support, ~8W power draw
- **Intel NUC 13 Pro**: Up to 64GB DDR4 RAM, perfect for Proxmox/Docker/K8s
- **ASUS NUC 14 Pro**: Latest gen, excellent thermals
- **Beelink SER7**: AMD Ryzen 7 7735HS (8C/16T), best price/performance

**Typical Enterprise Homelab Power**: 20-50W total
**Post-lease ThinkCentres**: ~130€ each, professional-grade components

**Sources**:
- [Best Mini PCs for Home Lab 2025](https://terminalbytes.com/best-mini-pcs-for-home-lab-2025/)
- [Ultimate Home Lab Starter Stack for 2026](https://www.virtualizationhowto.com/2025/12/ultimate-home-lab-starter-stack-for-2026-key-recommendations/)
- [Best Mini PC for Homelab 2025](https://homelabsec.com/posts/best-mini-pc-homelab-2025/)

---

## 🔐 CRITICAL: Secrets Management (Enterprise Requirement)

### Current State: ❌ INSECURE
Your `.env` files contain plaintext passwords - **unacceptable for production**.

### Enterprise Solution: HashiCorp Vault

**Why Vault**:
- Encryption at rest and in transit
- Audit logging of all secret access
- Automatic secret rotation
- Role-based access control (RBAC)
- Shamir's Secret Sharing for unsealing

**Implementation**:
```yaml
# Add to docker-compose.yml
vault:
  image: hashicorp/vault:${VAULT_TAG:-latest}
  container_name: vault
  ports:
    - "${HOST_BIND:-192.168.178.40}:8200:8200"
  environment:
    VAULT_ADDR: http://0.0.0.0:8200
    VAULT_API_ADDR: http://0.0.0.0:8200
  volumes:
    - vault-data:/vault/data
    - vault-logs:/vault/logs
    - ./config/vault:/vault/config:ro
  cap_add:
    - IPC_LOCK
  command: server
  networks:
    - potatostack
  restart: unless-stopped
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 256M
      reservations:
        cpus: '0.25'
        memory: 128M
```

**Setup Steps**:
1. Initialize Vault with `vault operator init`
2. Unseal with key shares
3. Enable KV secrets engine: `vault secrets enable -version=2 kv`
4. Store secrets: `vault kv put kv/postgres password=${POSTGRES_SUPER_PASSWORD}`
5. Update services to use Vault agent for secret injection

**Alternative for Docker Compose only**: Mozilla SOPS with age encryption
```bash
# Encrypt .env files
sops --encrypt --age <public-key> .env > .env.enc
```

**Sources**:
- [Docker Compose Secrets Management](https://www.bitdoze.com/docker-compose-secrets/)
- [4 Ways to Securely Store Secrets in Docker](https://blog.gitguardian.com/how-to-handle-secrets-in-docker/)
- [Setting up Vault with Docker Compose](https://www.kapstan.io/blog/setting-up-guardian-of-secrets-part-1-docker-compose-deployment-of-vault)

---

## 📊 Enterprise Observability Stack

### Replace: Basic Monitoring → Full APM + Distributed Tracing

**Current Stack Issues**:
- Beszel: Basic metrics only
- Loki/Promtail: Logs only
- No application performance monitoring (APM)
- No distributed tracing
- No error tracking correlation

### SOTA 2025 Solution: SigNoz (Self-Hosted, OpenTelemetry-Native)

**Why SigNoz**:
- All-in-one: APM + Logs + Traces + Metrics + Alerts
- OpenTelemetry native (industry standard)
- ClickHouse backend (used by Uber, Cloudflare)
- 100% open-source alternative to Datadog ($$$)
- Auto-instrumentation for Java/Node.js

**Add to Stack**:
```yaml
# SigNoz - OpenTelemetry APM
signoz-clickhouse:
  image: clickhouse/clickhouse-server:${CLICKHOUSE_TAG:-23.11-alpine}
  container_name: signoz-clickhouse
  volumes:
    - signoz-clickhouse-data:/var/lib/clickhouse/
  networks:
    - potatostack
  restart: unless-stopped
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        cpus: '1.0'
        memory: 1G

signoz-otel-collector:
  image: signoz/signoz-otel-collector:${SIGNOZ_TAG:-latest}
  container_name: signoz-otel-collector
  command: ["--config=/etc/otel-collector-config.yaml"]
  volumes:
    - ./config/signoz/otel-collector-config.yaml:/etc/otel-collector-config.yaml
  ports:
    - "${HOST_BIND:-192.168.178.40}:4317:4317"   # OTLP gRPC
    - "${HOST_BIND:-192.168.178.40}:4318:4318"   # OTLP HTTP
  networks:
    - potatostack
  depends_on:
    - signoz-clickhouse
  restart: unless-stopped
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 512M

signoz-query-service:
  image: signoz/query-service:${SIGNOZ_TAG:-latest}
  container_name: signoz-query-service
  command: ["-config=/root/config/prometheus.yml"]
  volumes:
    - ./config/signoz/prometheus.yml:/root/config/prometheus.yml
  ports:
    - "${HOST_BIND:-192.168.178.40}:8080:8080"
  networks:
    - potatostack
  depends_on:
    - signoz-clickhouse
  restart: unless-stopped
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 1G

signoz-frontend:
  image: signoz/frontend:${SIGNOZ_TAG:-latest}
  container_name: signoz-frontend
  ports:
    - "${HOST_BIND:-192.168.178.40}:3301:3301"
  networks:
    - potatostack
  depends_on:
    - signoz-query-service
  restart: unless-stopped
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.signoz.rule=Host(`observability.${HOST_DOMAIN:-local.domain}`)"
    - "traefik.http.routers.signoz.entrypoints=websecure"
    - "traefik.http.routers.signoz.tls=true"
    - "traefik.http.services.signoz.loadbalancer.server.port=3301"
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 512M
```

**Instrumentation**:
1. Add OpenTelemetry SDK to your apps
2. Point to `http://signoz-otel-collector:4317`
3. Get automatic APM, traces, error tracking

**Alternative**: LGTM Stack (Loki + Grafana + Tempo + Mimir)
**You already have Loki** - just add Tempo (traces) and Mimir (long-term metrics)

**Sources**:
- [SigNoz - Open Source Datadog Alternative](https://signoz.io/)
- [12 OpenTelemetry-Compatible Platforms 2025](https://uptrace.dev/blog/opentelemetry-compatible-platforms)
- [Top 10 OpenTelemetry Platforms](https://clickhouse.com/resources/engineering/top-opentelemetry-compatible-platforms)

---

## 💾 Enterprise Backup & Disaster Recovery

### Current State: ❌ NO BACKUP STRATEGY

**3-2-1 Backup Rule** (Industry Standard):
- **3** copies of your data
- **2** different storage media types
- **1** offsite/cloud copy

### Implementation

#### 1. Primary Backup: Kopia (Already in Stack ✅)
**Enhanced Configuration**:
```yaml
kopia:
  # ... existing config ...
  environment:
    # Add encryption
    KOPIA_PASSWORD: ${KOPIA_PASSWORD}  # Move to Vault
    # Retention policies
    KOPIA_SNAPSHOT_RETENTION_POLICY: "7:daily,4:weekly,12:monthly,10:yearly"
    # Compression
    KOPIA_COMPRESSION: zstd-fastest
  volumes:
    # Backup critical services
    - vaultwarden-data:/data/vaultwarden:ro
    - postgres-data:/data/postgres:ro
    - nextcloud-aio-mastercontainer:/data/nextcloud:ro
    - /mnt/storage:/data/storage:ro
    # Offsite target
    - /mnt/offsite-backup:/offsite:rw
```

#### 2. Add Proxmox Backup Server (If Using Proxmox)
**Benefits**:
- Deduplication (saves 60-80% space)
- Incremental backups
- Compression
- Encryption at rest
- Free and open-source

```yaml
proxmox-backup-server:
  image: proxmox/proxmox-backup-server:${PBS_TAG:-latest}
  container_name: pbs
  ports:
    - "${HOST_BIND:-192.168.178.40}:8007:8007"
  volumes:
    - pbs-data:/var/lib/proxmox-backup
    - /mnt/backup-storage:/mnt/datastore
  networks:
    - potatostack
  restart: unless-stopped
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
```

#### 3. Offsite Cold Storage: AWS Glacier Deep Archive
**Cost**: $0.99/TB/month (cheapest cloud storage)

**Setup**:
```bash
# Install AWS CLI
apt install awscli

# Configure Kopia to sync to Glacier
kopia repository create s3 \
  --bucket=your-backup-bucket \
  --storage-class=DEEP_ARCHIVE \
  --access-key=${AWS_ACCESS_KEY} \
  --secret-access-key=${AWS_SECRET_KEY}
```

#### 4. Automated Backup Verification
**Critical**: Test backups monthly

```yaml
# Add backup-tester service
backup-tester:
  image: alpine:latest
  container_name: backup-tester
  command: sh /test-backups.sh
  volumes:
    - ./scripts/test-backups.sh:/test-backups.sh:ro
    - /mnt/backup-storage:/backups:ro
  networks:
    - potatostack
  restart: "no"  # Run via cron
```

**test-backups.sh**:
```bash
#!/bin/sh
# Verify latest Kopia snapshot
kopia snapshot verify --file-parallelism=4

# Test restore to /tmp
kopia restore latest /tmp/restore-test

# Alert if failed
if [ $? -ne 0 ]; then
  curl -X POST ${HEALTHCHECK_URL}/fail
fi
```

**Sources**:
- [Ultimate Home Lab Backup Strategy 2025](https://www.virtualizationhowto.com/2025/10/ultimate-home-lab-backup-strategy-2025-edition/)
- [AWS Glacier Deep Archive for Homelab](https://ahmadmu.com/blogs/glacier-backup-solution)
- [3-2-1 Backup Strategy for Homelab](https://kenbinlab.com/backup-strategy-for-homelab/)

---

## 🔄 High Availability & Failover

### Current State: Single Point of Failure

**Enterprise Requirements**:
- Zero downtime during maintenance
- Automatic failover on hardware failure
- Geographic redundancy

### Option 1: Docker Swarm (Simplest HA)

**Convert to Swarm Mode**:
```bash
# Initialize swarm
docker swarm init

# Convert compose to stack
docker stack deploy -c docker-compose.yml potatostack

# Add worker nodes (second mini PC)
docker swarm join --token <worker-token> <manager-ip>:2377
```

**Benefits**:
- Native Docker Secrets (encrypted)
- Service replication
- Automatic container restart across nodes
- Rolling updates with zero downtime

**Update services for HA**:
```yaml
services:
  traefik:
    deploy:
      mode: replicated
      replicas: 2  # Run on 2 nodes
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
        max_attempts: 3
```

### Option 2: Kubernetes (Full Enterprise Grade)

**Lightweight K8s for Homelab**: K3s
```bash
# Install K3s on mini PC
curl -sfL https://get.k3s.io | sh -

# Convert Docker Compose to K8s manifests
kompose convert -f docker-compose.yml
```

**Benefits over Swarm**:
- Industry standard orchestration
- Better scaling capabilities
- Extensive ecosystem (Helm charts)
- Service mesh support (Istio/Linkerd)

**Recommended for**:
- 3+ mini PCs
- Need for advanced scheduling
- CI/CD pipelines with ArgoCD

### Option 3: Automated Failover with Keepalived

**For critical services** (Traefik, databases):
```yaml
keepalived:
  image: osixia/keepalived:${KEEPALIVED_TAG:-latest}
  container_name: keepalived
  network_mode: host
  cap_add:
    - NET_ADMIN
  environment:
    KEEPALIVED_VIRTUAL_IPS: "192.168.178.100"
    KEEPALIVED_PRIORITY: 100
  volumes:
    - ./config/keepalived/keepalived.conf:/usr/local/etc/keepalived/keepalived.conf:ro
  restart: unless-stopped
```

**Result**: Virtual IP (192.168.178.100) automatically moves to healthy node

**Sources**:
- [Building Production-Grade HA Kubernetes](https://code2deploy.com/blog/building-a-production-grade-highly-available-self-hosted-kubernetes-cluster/)
- [Failover vs Disaster Recovery 2025](https://novotech.com/pages/failover-vs-disaster-recovery-what-should-your-business-have-in-2024)

---

## 🛡️ Security Hardening (Enterprise Requirements)

### 1. Network Segmentation

**Current**: Single `potatostack` network ❌

**Enterprise**: Multiple isolated networks

```yaml
networks:
  frontend:  # Public-facing (Traefik, NGINX)
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.1.0/24

  backend:  # Databases, internal APIs
    driver: bridge
    internal: true  # No internet access
    ipam:
      config:
        - subnet: 172.22.2.0/24

  vpn:  # Services behind VPN only
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.3.0/24

  monitoring:  # Observability stack
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.4.0/24

services:
  traefik:
    networks:
      - frontend
      - monitoring

  postgres:
    networks:
      - backend  # NOT exposed to frontend

  nextcloud-aio:
    networks:
      - frontend
      - backend
```

### 2. Enable AppArmor/SELinux Profiles

```yaml
services:
  vaultwarden:
    security_opt:
      - apparmor=docker-default
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
```

### 3. Add Fail2Ban for Intrusion Prevention

```yaml
fail2ban:
  image: crazymax/fail2ban:${FAIL2BAN_TAG:-latest}
  container_name: fail2ban
  network_mode: host
  cap_add:
    - NET_ADMIN
    - NET_RAW
  volumes:
    - fail2ban-data:/data
    - /var/log:/var/log:ro
    - traefik-logs:/var/log/traefik:ro
  environment:
    F2B_DB_PURGE_AGE: 30d
    F2B_LOG_LEVEL: INFO
  restart: unless-stopped
```

### 4. Vulnerability Scanning

**Add Trivy for container scanning**:
```yaml
trivy:
  image: aquasec/trivy:${TRIVY_TAG:-latest}
  container_name: trivy
  command: ["server", "--listen", "0.0.0.0:8081"]
  ports:
    - "${HOST_BIND:-192.168.178.40}:8081:8081"
  volumes:
    - trivy-cache:/root/.cache/
    - /var/run/docker.sock:/var/run/docker.sock:ro
  networks:
    - potatostack
  restart: unless-stopped
```

**Scan all images daily**:
```bash
#!/bin/bash
# scan-images.sh
for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
  trivy image --severity CRITICAL,HIGH $image
done
```

**Sources**:
- [Docker Security Best Practices 2025](https://talent500.com/blog/modern-docker-best-practices-2025/)
- [Docker Production Security](https://thinksys.com/devops/docker-best-practices/)

---

## 📈 Advanced Monitoring & Alerting

### Add Alertmanager for Prometheus

```yaml
alertmanager:
  image: prom/alertmanager:${ALERTMANAGER_TAG:-latest}
  container_name: alertmanager
  ports:
    - "${HOST_BIND:-192.168.178.40}:9093:9093"
  volumes:
    - ./config/alertmanager:/etc/alertmanager
    - alertmanager-data:/alertmanager
  command:
    - '--config.file=/etc/alertmanager/config.yml'
    - '--storage.path=/alertmanager'
  networks:
    - potatostack
  restart: unless-stopped
  deploy:
    resources:
      limits:
        cpus: '0.25'
        memory: 128M
```

**config/alertmanager/config.yml**:
```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'discord'

receivers:
  - name: 'discord'
    discord_configs:
      - webhook_url: '${DISCORD_WEBHOOK}'
        title: '🚨 {{ .GroupLabels.alertname }}'

  - name: 'telegram'
    telegram_configs:
      - bot_token: '${TELEGRAM_BOT_TOKEN}'
        chat_id: ${TELEGRAM_CHAT_ID}

  - name: 'email'
    email_configs:
      - to: '${ALERT_EMAIL}'
        from: 'alerts@homelab.local'
        smarthost: 'smtp.gmail.com:587'
        auth_username: '${SMTP_USER}'
        auth_password: '${SMTP_PASSWORD}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster']
```

### Critical Alerts to Configure

```yaml
# prometheus-alerts.yml
groups:
  - name: infrastructure
    interval: 30s
    rules:
      - alert: HighMemoryUsage
        expr: (node_memory_Active_bytes / node_memory_MemTotal_bytes) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value }}%"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 15
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space low on {{ $labels.instance }}"

      - alert: ContainerDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.job }} is down"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels:
          severity: warning

      - alert: BackupFailed
        expr: kopia_snapshot_success == 0
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "Backup failed for {{ $labels.repository }}"
```

**Sources**:
- [Best Home Lab Tools 2025](https://www.virtualizationhowto.com/2025/10/best-home-lab-tools-youre-crazy-not-to-use-in-2025/)

---

## 🔧 Container Management Upgrade

### Current: Dockge (Good) → Upgrade to Komodo (SOTA 2025)

**Komodo** is the newest container management platform that homelabbers are adopting in late 2025/2026.

**Why Komodo > Portainer/Dockge**:
- Free and fast
- Modern UI/UX
- Real-time monitoring built-in
- Easier multi-stack management
- Built-in resource usage tracking
- No bloat compared to Portainer

```yaml
komodo:
  image: ghcr.io/mbecker20/komodo:${KOMODO_TAG:-latest}
  container_name: komodo
  ports:
    - "${HOST_BIND:-192.168.178.40}:9120:9120"
  environment:
    KOMODO_HOST: "0.0.0.0"
    KOMODO_PORT: "9120"
    KOMODO_DATABASE_URL: "mongodb://mongo:27017/komodo"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - komodo-data:/data
  networks:
    - potatostack
  depends_on:
    - mongo
  restart: unless-stopped
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.komodo.rule=Host(`komodo.${HOST_DOMAIN:-local.domain}`)"
    - "traefik.http.routers.komodo.entrypoints=websecure"
    - "traefik.http.routers.komodo.tls=true"
    - "traefik.http.services.komodo.loadbalancer.server.port=9120"
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 512M
      reservations:
        cpus: '0.25'
        memory: 256M
```

**Sources**:
- [Ultimate Home Lab Starter Stack for 2026](https://www.virtualizationhowto.com/2025/12/ultimate-home-lab-starter-stack-for-2026-key-recommendations/)

---

## 🎯 Implementation Roadmap

### Phase 1: Critical Security (Week 1)
- [ ] Deploy HashiCorp Vault
- [ ] Migrate all secrets from `.env` to Vault
- [ ] Enable network segmentation
- [ ] Add Fail2Ban
- [ ] Configure SSL certificates for all services

### Phase 2: Observability (Week 2)
- [ ] Deploy SigNoz or LGTM stack
- [ ] Instrument applications with OpenTelemetry
- [ ] Configure Alertmanager
- [ ] Set up critical alerts (disk, memory, backup failures)
- [ ] Create Grafana dashboards

### Phase 3: Backup & DR (Week 3)
- [ ] Configure 3-2-1 backup strategy
- [ ] Set up automated Kopia snapshots
- [ ] Configure offsite backup to AWS Glacier
- [ ] Test restore procedures
- [ ] Document recovery runbooks

### Phase 4: High Availability (Week 4)
- [ ] Purchase second mini PC for redundancy
- [ ] Set up Docker Swarm or K3s
- [ ] Configure service replication
- [ ] Implement Keepalived for VIP failover
- [ ] Test failover scenarios

### Phase 5: Hardening (Ongoing)
- [ ] Add Trivy vulnerability scanning
- [ ] Enable AppArmor profiles
- [ ] Implement read-only containers where possible
- [ ] Regular security audits
- [ ] Update dependencies monthly

---

## 📊 Expected Results After Enterprise Optimization

### Current State (SOTA 2025 Homelab)
- Services: 73
- CPU limits: ✅ Yes
- Memory optimization: ✅ Yes
- Log rotation: ✅ Yes
- Secrets management: ❌ Plaintext .env
- Backup: ⚠️ Kopia only (no offsite)
- HA/Failover: ❌ No
- APM/Tracing: ❌ No
- Network segmentation: ❌ Single network

### After Enterprise Grade Optimization
- Services: ~85 (added Vault, SigNoz, Fail2Ban, Alertmanager, etc.)
- Secrets management: ✅ Vault with encryption
- Backup: ✅ 3-2-1 strategy (local + NAS + Glacier)
- HA/Failover: ✅ Docker Swarm with 2+ nodes
- Observability: ✅ Full APM with distributed tracing
- Security: ✅ Network segmentation, vulnerability scanning
- Monitoring: ✅ Comprehensive alerts with Alertmanager
- Uptime: 99.9% (vs 95% single-node)
- **Recovery Time Objective (RTO)**: < 5 minutes (automated failover)
- **Recovery Point Objective (RPO)**: < 1 hour (hourly backups)

---

## 💰 Cost Analysis

### Hardware
- **Second Mini PC** (ThinkCentre M70q used): ~€130
- **NAS for local backups** (Synology DS220+): ~€250
- **Total Hardware**: ~€380

### Cloud Services
- **AWS Glacier** (2TB backup): $1.98/month
- **Domain + SSL** (Cloudflare): $0/month (free tier)
- **Total Monthly**: ~$2/month

### Comparison vs Commercial
- **Datadog**: $15/host/month = $30/month
- **PagerDuty**: $21/user/month
- **1Password Teams**: $8/user/month
- **Total Commercial**: ~$60/month

**Savings**: ~$700/year by self-hosting enterprise-grade stack

---

## 📚 Additional Resources

### Essential Reading
- [Self-Hosting Guide (GitHub)](https://github.com/mikeroyal/Self-Hosting-Guide)
- [Awesome OpenTelemetry](https://github.com/magsther/awesome-opentelemetry)
- [CNCF Cloud Native Landscape](https://landscape.cncf.io/)

### Monitoring & Alerting
- [Best Home Lab Tools 2025](https://www.virtualizationhowto.com/2025/10/best-home-lab-tools-youre-crazy-not-to-use-in-2025/)
- [Kube Prometheus Stack Guide](https://atmosly.com/blog/kube-prometheus-stack-a-comprehensive-guide-for-kubernetes-monitoring)

### Disaster Recovery
- [AWS Disaster Recovery Strategies](https://n2ws.com/blog/aws-disaster-recovery/aws-disaster-recovery)
- [Instant Failover Best Practices](https://www.imperva.com/learn/availability/instant-failover/)

---

**Next Step**: Start with Phase 1 (Security) - Deploy HashiCorp Vault and migrate secrets.
