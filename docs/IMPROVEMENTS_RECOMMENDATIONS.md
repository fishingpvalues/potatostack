# PotatoStack Improvements & Recommendations (2025)

Based on research into modern Docker best practices, home lab monitoring trends, and SBC deployments, here are recommendations to enhance your PotatoStack.

## 🔄 AUTOMATED SWAP MANAGEMENT

### Problem
Docker Compose **cannot** create swap files automatically - it's a host-level operation requiring root privileges. Your current setup requires manual swap creation.

### Solution: Systemd Service for Automated Swap

Create a systemd service that ensures swap exists before Docker starts:

**File: `/etc/systemd/system/potatostack-swap.service`**
```ini
[Unit]
Description=PotatoStack Swap File Manager
Before=docker.service
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/ensure-potatostack-swap.sh

[Install]
WantedBy=multi-user.target
```

**File: `/usr/local/bin/ensure-potatostack-swap.sh`**
```bash
#!/bin/bash
set -e

SWAPFILE="/mnt/seconddrive/potatostack.swap"
SWAPSIZE_GB=3

# Check if swap already exists and is active
if swapon --show | grep -q "$SWAPFILE"; then
    echo "Swap file already active: $SWAPFILE"
    exit 0
fi

# Check if swap file exists
if [ ! -f "$SWAPFILE" ]; then
    echo "Creating swap file: $SWAPFILE (${SWAPSIZE_GB}GB)"
    fallocate -l ${SWAPSIZE_GB}G "$SWAPFILE"
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
fi

# Activate swap
echo "Activating swap file: $SWAPFILE"
swapon "$SWAPFILE"

# Add to /etc/fstab if not already present
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    echo "Added swap file to /etc/fstab"
fi
```

**Installation:**
```bash
# Copy files
sudo cp ensure-potatostack-swap.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/ensure-potatostack-swap.sh

# Copy systemd service
sudo cp potatostack-swap.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable potatostack-swap.service
sudo systemctl start potatostack-swap.service

# Verify
sudo systemctl status potatostack-swap.service
free -h
```

### Benefits
✅ Automatic swap creation on boot
✅ No manual intervention needed
✅ Idempotent (safe to run multiple times)
✅ Survives reboots

**Sources:**
- [Managing Docker Applications with Systemd](https://dohost.us/index.php/2025/07/29/managing-docker-applications-with-systemd-running-containers-as-services/)
- [Running Docker Compose as a systemd Service](https://bootvar.com/systemd-service-for-docker-compose/)

---

## 🚀 SYSTEMD AUTO-START FOR POTATOSTACK

### Docker Compose as Systemd Service

Make PotatoStack start automatically on boot:

**File: `/etc/systemd/system/potatostack.service`**
```ini
[Unit]
Description=PotatoStack Docker Compose Stack
Requires=docker.service potatostack-swap.service
After=docker.service potatostack-swap.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/youruser/potatostack
ExecStartPre=/usr/bin/docker-compose pull --quiet --ignore-pull-failures
ExecStart=/usr/bin/docker-compose up -d --remove-orphans
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

# Restart policy
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

**Installation:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable potatostack.service
sudo systemctl start potatostack.service

# Check status
sudo systemctl status potatostack.service

# View logs
sudo journalctl -u potatostack.service -f
```

**Sources:**
- [Docker Compose as Systemd unit](https://unix.stackexchange.com/questions/617622/docker-compose-as-systemd-unit)

---

## 📊 MISSING MONITORING COMPONENTS

Based on [5 Things You Should Be Monitoring on Your Home Lab Network](https://www.virtualizationhowto.com/2025/10/5-things-you-should-be-monitoring-on-your-home-lab-network-but-probably-arent/), here's what PotatoStack is missing:

### 1. **Network Switch Monitoring (SNMP)**

Add SNMP monitoring to track switch health, port utilization, and errors.

**Add to docker-compose.yml:**
```yaml
  snmp-exporter:
    image: prom/snmp-exporter:latest
    container_name: snmp-exporter
    hostname: snmp-exporter
    restart: unless-stopped
    networks:
      - monitoring
    ports:
      - "9116:9116"
    volumes:
      - ./config/snmp-exporter:/etc/snmp_exporter
    command:
      - '--config.file=/etc/snmp_exporter/snmp.yml'
    mem_limit: 64m
    mem_reservation: 32m
    cpus: 0.25
```

**Add to config/prometheus/prometheus.yml:**
```yaml
  - job_name: 'snmp'
    static_configs:
      - targets:
        - 192.168.178.1  # Your Fritzbox
        - 192.168.178.2  # Your switch (if you have one)
    metrics_path: /snmp
    params:
      module: [if_mib]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: snmp-exporter:9116
```

### 2. **Pi-Hole for DNS/Ad-Blocking + Monitoring**

Add network-wide ad blocking and DNS monitoring:

```yaml
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    hostname: pihole
    restart: unless-stopped
    networks:
      - monitoring
      - default
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8084:80"
    environment:
      - TZ=Europe/Berlin
      - WEBPASSWORD=${PIHOLE_PASSWORD}
      - FTLCONF_LOCAL_IPV4=192.168.178.40
      - PIHOLE_DNS_=1.1.1.1;1.0.0.1
    volumes:
      - /mnt/seconddrive/pihole/etc:/etc/pihole
      - /mnt/seconddrive/pihole/dnsmasq:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
    mem_limit: 256m
    mem_reservation: 128m
    cpus: 0.5
```

### 3. **SmokePing for Network Latency Monitoring**

Track network latency and packet loss over time:

```yaml
  smokeping:
    image: linuxserver/smokeping:latest
    container_name: smokeping
    hostname: smokeping
    restart: unless-stopped
    networks:
      - monitoring
      - proxy
    ports:
      - "8085:80"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /mnt/seconddrive/smokeping/config:/config
      - /mnt/seconddrive/smokeping/data:/data
    mem_limit: 128m
    mem_reservation: 64m
    cpus: 0.5
```

### 4. **Fail2Ban for Security Monitoring**

Protect exposed services from brute force attacks:

```yaml
  fail2ban:
    image: crazymax/fail2ban:latest
    container_name: fail2ban
    hostname: fail2ban
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - TZ=Europe/Berlin
      - F2B_LOG_LEVEL=INFO
      - F2B_DB_PURGE_AGE=30d
    volumes:
      - /mnt/seconddrive/fail2ban:/data
      - /var/log:/var/log:ro
    mem_limit: 64m
    mem_reservation: 32m
    cpus: 0.25
```

### 5. **Blackbox Exporter for Endpoint Monitoring**

Monitor external services and endpoint availability:

```yaml
  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    hostname: blackbox-exporter
    restart: unless-stopped
    networks:
      - monitoring
      - proxy
    ports:
      - "9115:9115"
    volumes:
      - ./config/blackbox:/etc/blackbox_exporter
    command:
      - '--config.file=/etc/blackbox_exporter/config.yml'
    mem_limit: 64m
    mem_reservation: 32m
    cpus: 0.25
```

**Source:**
- [5 of the best tools for monitoring your home lab](https://www.xda-developers.com/best-tools-for-monitoring-your-home-lab/)

---

## 🔒 VPN KILLSWITCH VERIFICATION IMPROVEMENTS

Your current `network_mode: service:surfshark` implementation is **correct**! Here are better verification methods:

### Automated Killswitch Test Script

**File: `verify-vpn-killswitch.sh`**
```bash
#!/bin/bash

echo "=== VPN Killswitch Verification ==="
echo ""

# Check Surfshark IP
echo "1. Checking Surfshark container IP..."
SURFSHARK_IP=$(docker exec surfshark curl -s ipinfo.io/ip)
echo "   Surfshark IP: $SURFSHARK_IP"

# Check if it's a VPN IP (not local)
if [[ $SURFSHARK_IP == 192.168.* ]] || [[ $SURFSHARK_IP == 10.* ]]; then
    echo "   ⚠️  WARNING: Surfshark showing local IP!"
else
    echo "   ✅ VPN connected (Netherlands IP)"
fi

echo ""
echo "2. Testing qBittorrent killswitch..."
# qBittorrent should NOT be able to access internet directly
if docker exec qbittorrent curl -s --max-time 5 ipinfo.io/ip 2>/dev/null; then
    echo "   ⚠️  WARNING: qBittorrent can access internet!"
else
    echo "   ✅ qBittorrent network isolated (expected)"
fi

echo ""
echo "3. Testing slskd killswitch..."
if docker exec slskd curl -s --max-time 5 ipinfo.io/ip 2>/dev/null; then
    echo "   ⚠️  WARNING: slskd can access internet!"
else
    echo "   ✅ slskd network isolated (expected)"
fi

echo ""
echo "4. Simulating VPN disconnect..."
docker-compose stop surfshark
sleep 5

echo "   Testing if qBittorrent lost connectivity..."
if docker exec qbittorrent curl -s --max-time 5 ipinfo.io/ip 2>/dev/null; then
    echo "   🚨 CRITICAL: KILLSWITCH FAILED! qBittorrent accessible without VPN!"
    exit 1
else
    echo "   ✅ Killswitch working (no internet without VPN)"
fi

# Restart VPN
echo ""
echo "5. Restarting VPN..."
docker-compose start surfshark
sleep 10

# Verify VPN back online
SURFSHARK_IP_AFTER=$(docker exec surfshark curl -s ipinfo.io/ip)
echo "   Surfshark IP after restart: $SURFSHARK_IP_AFTER"

if [[ $SURFSHARK_IP_AFTER == $SURFSHARK_IP ]]; then
    echo "   ✅ VPN reconnected successfully"
else
    echo "   ℹ️  VPN IP changed (normal for new connection)"
fi

echo ""
echo "=== Verification Complete ==="
```

**Source:**
- [Verifying VPN Status for Docker qBittorrent](https://kunat.dev/notes/check-torrent-client-vpn-ip/)
- [Gluetun Docker Guide - Easy VPN Killswitch](https://www.simplehomelab.com/gluetun-docker-guide/)

---

## 🏗️ DOCKER COMPOSE MODERNIZATION (2025 Best Practices)

### 1. Remove Obsolete Version Field

**Current:**
```yaml
version: '3.8'  # OBSOLETE in 2025
```

**Modern (2025):**
```yaml
# No version field needed - start directly with services
services:
  ...
```

The `version` field is deprecated in modern Docker Compose. Files should start directly with the `services` block.

### 2. Add Health Checks to All Services

**Current:** Only surfshark and kopia have health checks

**Add to missing services:**
```yaml
  prometheus:
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  grafana:
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  nextcloud:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/status.php"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### 3. Use Docker Secrets for Sensitive Data (Optional)

Instead of .env files, use Docker secrets:

```yaml
secrets:
  surfshark_user:
    file: ./secrets/surfshark_user.txt
  surfshark_password:
    file: ./secrets/surfshark_password.txt

services:
  surfshark:
    secrets:
      - surfshark_user
      - surfshark_password
```

**Sources:**
- [Modern Docker Best Practices for 2025](https://talent500.com/blog/modern-docker-best-practices-2025/)
- [NEW Docker 2025: 42 Prod Best Practices](https://docs.benchhub.co/docs/tutorials/docker/docker-best-practices-2025)

---

## 📝 MISSING DOCUMENTATION

### 1. **Backup/Restore Procedures**
Add detailed backup and disaster recovery procedures for:
- Docker volumes
- Configuration files
- Database dumps
- Kopia repository

### 2. **Upgrade Strategy**
Document how to:
- Upgrade individual services
- Test upgrades in isolation
- Roll back failed upgrades

### 3. **Capacity Planning**
Add metrics for when to:
- Add more swap
- Upgrade to larger SD card/eMMC
- Move services to another machine

---

## 🎯 PRIORITY IMPLEMENTATION PLAN

### Phase 1: Critical (Do Now)
1. ✅ **Automated swap management** (systemd service)
2. ✅ **Auto-start on boot** (systemd service for docker-compose)
3. 📝 **VPN killswitch verification script**

### Phase 2: High Value (Next Week)
4. 📊 **Add missing health checks** to all services
5. 🔍 **Add Blackbox Exporter** for endpoint monitoring
6. 🛡️ **Add Fail2Ban** for security

### Phase 3: Enhanced Monitoring (Next Month)
7. 📡 **Add SNMP monitoring** for network devices
8. 🚫 **Add Pi-Hole** for DNS/ad-blocking
9. 📈 **Add SmokePing** for latency tracking

### Phase 4: Modernization (Ongoing)
10. 🏗️ **Remove version field** from docker-compose.yml
11. 🔐 **Migrate to Docker secrets** (optional)
12. 📚 **Complete documentation** gaps

---

## 📦 ESTIMATED MEMORY IMPACT

Adding recommended services:

| Service | Memory | Total Impact |
|---------|--------|--------------|
| SNMP Exporter | 64 MB | +64 MB |
| Pi-Hole | 256 MB | +256 MB |
| SmokePing | 128 MB | +128 MB |
| Fail2Ban | 64 MB | +64 MB |
| Blackbox Exporter | 64 MB | +64 MB |
| **TOTAL NEW** | **576 MB** | **~6.1 GB total** |

**⚠️ Swap Requirement Update**: With new services, increase swap to **4GB minimum**.

---

## 🔗 Additional Resources

- [Self-Hosting Guide on GitHub](https://github.com/mikeroyal/Self-Hosting-Guide)
- [Best Self Hosted Apps in 2025](https://pinggy.io/blog/best_self_hosted_apps_in_2025/)
- [Monitor Your Home Lab with Grafana and Prometheus](https://mattadam.com/2025/05/29/how-to-monitor-your-home-lab-with-grafana-and-prometheus/)
- [Application Monitoring Best Practices In 2025](https://www.netdata.cloud/academy/application-monitoring-2025/)

---

## ✅ Summary

Your PotatoStack is **well-designed** with:
- ✅ Correct VPN killswitch implementation
- ✅ Comprehensive monitoring stack (Prometheus, Grafana, Loki)
- ✅ Proper resource limits
- ✅ Good security practices

**Key Improvements Available**:
1. **Automated swap management** via systemd (most important)
2. **Auto-start on boot** for reliability
3. **Additional monitoring** (network, DNS, security)
4. **Health checks** for all services
5. **Modern Docker Compose** practices (remove version field)

**Recommended Next Step**: Implement Phase 1 (automated swap + auto-start) first, as these provide the most immediate value for reliability and ease of deployment.
