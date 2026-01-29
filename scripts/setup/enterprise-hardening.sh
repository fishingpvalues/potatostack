#!/bin/bash
################################################################################
# PotatoStack - Enterprise-Grade Hardening & Resilience Setup
#
# Features:
#   - Hardware watchdog for kernel hang recovery
#   - Auto-login on boot (optional)
#   - Network resilience monitoring
#   - Automatic service recovery
#   - Memory pressure handling
#   - Disk space monitoring with auto-cleanup
#   - Weekly auto-reboot (optional)
#
# Run with: sudo bash scripts/setup/enterprise-hardening.sh
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

echo ""
echo "=================================================================="
echo "PotatoStack - Enterprise-Grade Hardening & Resilience"
echo "=================================================================="
echo ""
info "Stack directory: $REPO_ROOT"
info "Running as: $ACTUAL_USER"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
	error "Please run with sudo: sudo bash $0"
	exit 1
fi

################################################################################
# 1. Hardware Watchdog - Auto-reboot on kernel hang
################################################################################
echo ""
echo "[1/10] Configuring Hardware Watchdog..."

# Check if watchdog hardware exists
if [ -e /dev/watchdog ]; then
	apt-get update -qq
	apt-get install -y -qq watchdog 2>/dev/null || true

	cat >/etc/watchdog.conf <<'EOF'
# PotatoStack Watchdog Configuration
# Reboots system if:
#   - Kernel hangs (no ping to watchdog device)
#   - System load exceeds threshold
#   - Memory usage critical
#   - Key processes die

watchdog-device = /dev/watchdog
watchdog-timeout = 60
realtime = yes
priority = 1

# Check every 10 seconds
interval = 10

# Reboot if 1-minute load average > 24 (adjust for your CPU cores)
max-load-1 = 24

# Reboot if less than 100MB memory available
min-memory = 100

# Ensure these processes are running (add your critical processes)
# pidfile = /var/run/docker.pid

# Repair binary to run before reboot
# repair-binary = /usr/sbin/repair

# Test binary - if this fails, watchdog triggers
test-binary = /usr/local/bin/watchdog-test.sh
test-timeout = 30

# Log file
log-dir = /var/log/watchdog
EOF

	# Create watchdog test script
	mkdir -p /var/log/watchdog
	cat >/usr/local/bin/watchdog-test.sh <<'EOF'
#!/bin/bash
# Watchdog health check - exit 0 if healthy, non-zero triggers reboot

# Check if systemd is responding
if ! systemctl is-system-running &>/dev/null; then
    echo "systemd not responding" >> /var/log/watchdog/failures.log
    exit 1
fi

# Check if Docker is responding
if ! docker info &>/dev/null 2>&1; then
    echo "$(date): Docker daemon not responding" >> /var/log/watchdog/failures.log
    # Don't reboot for Docker - just log
    # exit 1
fi

# Check disk space (reboot won't help, but log it)
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$ROOT_USAGE" -gt 95 ]; then
    echo "$(date): Root disk usage critical: ${ROOT_USAGE}%" >> /var/log/watchdog/failures.log
fi

exit 0
EOF
	chmod +x /usr/local/bin/watchdog-test.sh

	systemctl enable watchdog
	systemctl restart watchdog
	log "Hardware watchdog enabled (auto-reboot on kernel hang)"
else
	warn "No hardware watchdog device found (/dev/watchdog)"
	info "Software watchdog will be configured instead"

	# Load softdog module
	modprobe softdog 2>/dev/null || true
	echo "softdog" >>/etc/modules-load.d/softdog.conf 2>/dev/null || true
fi

################################################################################
# 2. Auto-Login Configuration (Console)
################################################################################
echo ""
echo "[2/10] Configuring Auto-Login..."

# Ask user
read -rp "Enable auto-login on console TTY1? [y/N]: " ENABLE_AUTOLOGIN
if [[ "$ENABLE_AUTOLOGIN" =~ ^[Yy]$ ]]; then
	mkdir -p /etc/systemd/system/getty@tty1.service.d
	cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $ACTUAL_USER --noclear %I \$TERM
Type=idle
EOF
	systemctl daemon-reload
	log "Auto-login enabled for user: $ACTUAL_USER on TTY1"
	warn "Security note: Physical access grants full access"
else
	log "Auto-login skipped"
fi

################################################################################
# 3. Kernel Parameters for Stability
################################################################################
echo ""
echo "[3/10] Configuring Kernel Parameters..."

cat >/etc/sysctl.d/99-potatostack-hardening.conf <<'EOF'
# PotatoStack Kernel Hardening

# Memory management - prevent OOM better
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 0
vm.overcommit_ratio = 80
vm.panic_on_oom = 0
vm.oom_kill_allocating_task = 1

# Network stability
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Connection tracking for Docker
net.netfilter.nf_conntrack_max = 262144

# File descriptors
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Kernel panic behavior - auto-reboot after 10 seconds
kernel.panic = 10
kernel.panic_on_oops = 1

# Security
kernel.dmesg_restrict = 0
kernel.kptr_restrict = 1
EOF

sysctl --system >/dev/null 2>&1
log "Kernel parameters optimized for stability"

################################################################################
# 4. Systemd Service Hardening
################################################################################
echo ""
echo "[4/10] Hardening Systemd Services..."

# Ensure Docker has proper restart policy
mkdir -p /etc/systemd/system/docker.service.d
cat >/etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
Restart=always
RestartSec=5
StartLimitIntervalSec=300
StartLimitBurst=5
EOF

# Update potatostack service with better resilience
cat >/etc/systemd/system/potatostack.service <<EOF
[Unit]
Description=PotatoStack - Self-hosted Infrastructure Stack
Documentation=file://$REPO_ROOT/README.md
Requires=docker.service
After=docker.service network-online.target local-fs.target
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=oneshot
RemainAfterExit=yes
User=$ACTUAL_USER
Group=docker
WorkingDirectory=$REPO_ROOT
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="COMPOSE_HTTP_TIMEOUT=300"

# Wait for mounts and network
ExecStartPre=/bin/bash -c 'until mountpoint -q /mnt/storage; do sleep 2; done'
ExecStartPre=/bin/bash -c 'until ping -c1 1.1.1.1 &>/dev/null; do sleep 2; done'
ExecStartPre=/bin/sleep 5

# Start with startup script for better recovery
ExecStart=/bin/bash $REPO_ROOT/scripts/init/startup.sh
ExecStop=/usr/bin/docker compose down --timeout 120
ExecReload=/usr/bin/docker compose up -d --remove-orphans

TimeoutStartSec=900
TimeoutStopSec=180
Restart=on-failure
RestartSec=60

# Systemd hardening
ProtectSystem=strict
ReadWritePaths=$REPO_ROOT /mnt/ssd /mnt/storage /mnt/cachehdd /var/run/docker.sock /var/log
NoNewPrivileges=false
PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker
systemctl enable potatostack.service
log "Systemd services hardened with auto-recovery"

################################################################################
# 5. Network Resilience Monitor
################################################################################
echo ""
echo "[5/10] Creating Network Resilience Monitor..."

cat >/usr/local/bin/network-watchdog.sh <<'EOF'
#!/bin/bash
################################################################################
# Network Watchdog - Monitors connectivity and restarts services on failure
################################################################################

LOG_FILE="/var/log/potatostack/network-watchdog.log"
mkdir -p /var/log/potatostack

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Test targets (multiple for redundancy)
TEST_HOSTS="1.1.1.1 8.8.8.8 9.9.9.9"
FAIL_THRESHOLD=3
CONSECUTIVE_FAILURES=0

check_network() {
    for host in $TEST_HOSTS; do
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            return 0
        fi
    done
    return 1
}

restart_networking() {
    log "Attempting network recovery..."

    # Try DHCP renewal first
    if command -v dhclient &>/dev/null; then
        dhclient -r 2>/dev/null || true
        sleep 2
        dhclient 2>/dev/null || true
    fi

    # Restart systemd-networkd if available
    if systemctl is-active systemd-networkd &>/dev/null; then
        systemctl restart systemd-networkd
    fi

    # Restart NetworkManager if available
    if systemctl is-active NetworkManager &>/dev/null; then
        systemctl restart NetworkManager
    fi

    sleep 10
}

while true; do
    if check_network; then
        if [ "$CONSECUTIVE_FAILURES" -gt 0 ]; then
            log "Network restored after $CONSECUTIVE_FAILURES failures"
        fi
        CONSECUTIVE_FAILURES=0
    else
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        log "Network check failed (attempt $CONSECUTIVE_FAILURES/$FAIL_THRESHOLD)"

        if [ "$CONSECUTIVE_FAILURES" -ge "$FAIL_THRESHOLD" ]; then
            log "Network failure threshold reached - attempting recovery"
            restart_networking
            CONSECUTIVE_FAILURES=0
        fi
    fi

    sleep 30
done
EOF
chmod +x /usr/local/bin/network-watchdog.sh

# Create systemd service for network watchdog
cat >/etc/systemd/system/network-watchdog.service <<'EOF'
[Unit]
Description=Network Connectivity Watchdog
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/network-watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable network-watchdog.service
systemctl start network-watchdog.service
log "Network resilience monitor enabled"

################################################################################
# 6. Enhanced Health Check Service
################################################################################
echo ""
echo "[6/10] Creating Enhanced Health Check Service..."

cat >/usr/local/bin/potatostack-healthcheck.sh <<'EOF'
#!/bin/bash
################################################################################
# PotatoStack Enhanced Health Check
# - Checks container health
# - Restarts unhealthy containers
# - Monitors resource usage
# - Sends alerts via ntfy (if configured)
################################################################################

set -euo pipefail

COMPOSE_DIR="/home/daniel/potatostack"
LOG_FILE="/var/log/potatostack/healthcheck.log"
NTFY_TOPIC="${NTFY_TOPIC:-}"
NTFY_URL="${NTFY_URL:-http://localhost:8091}"

mkdir -p /var/log/potatostack

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

alert() {
    local message="$1"
    local priority="${2:-default}"

    log "ALERT: $message"

    # Send to ntfy if configured
    if [ -n "$NTFY_TOPIC" ]; then
        curl -s -X POST "$NTFY_URL/$NTFY_TOPIC" \
            -H "Title: PotatoStack Alert" \
            -H "Priority: $priority" \
            -H "Tags: warning,server" \
            -d "$message" 2>/dev/null || true
    fi
}

cd "$COMPOSE_DIR" || exit 1

# Check for unhealthy containers
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$UNHEALTHY" ]; then
    log "Found unhealthy containers: $UNHEALTHY"
    for container in $UNHEALTHY; do
        log "Restarting unhealthy container: $container"
        docker restart "$container" 2>&1 | tee -a "$LOG_FILE" || true
    done
    alert "Restarted unhealthy containers: $UNHEALTHY" "high"
fi

# Check for containers in restart loop (restarting status)
RESTARTING=$(docker ps --filter "status=restarting" --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$RESTARTING" ]; then
    log "Found containers in restart loop: $RESTARTING"
    alert "Containers in restart loop: $RESTARTING" "urgent"
fi

# Check for exited containers that should be running
EXITED=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | grep -v "storage-init\|tailscale-https-setup" || true)
if [ -n "$EXITED" ]; then
    log "Found exited containers: $EXITED"
    log "Attempting to restart via docker compose..."
    docker compose up -d 2>&1 | tee -a "$LOG_FILE" || true
fi

# Check disk space
for mount in / /mnt/ssd /mnt/storage /mnt/cachehdd; do
    if mountpoint -q "$mount" 2>/dev/null; then
        USAGE=$(df "$mount" | awk 'NR==2 {print $5}' | tr -d '%')
        if [ "$USAGE" -gt 90 ]; then
            alert "Disk space critical on $mount: ${USAGE}% used" "urgent"

            # Auto-cleanup Docker if it's the Docker storage
            if [ "$mount" = "/mnt/storage" ] || [ "$mount" = "/" ]; then
                log "Running Docker cleanup..."
                docker system prune -f 2>&1 | tee -a "$LOG_FILE" || true
            fi
        elif [ "$USAGE" -gt 80 ]; then
            log "Disk space warning on $mount: ${USAGE}% used"
        fi
    fi
done

# Check memory pressure
MEM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_PERCENT=$((100 - (MEM_AVAILABLE * 100 / MEM_TOTAL)))
if [ "$MEM_PERCENT" -gt 90 ]; then
    alert "Memory usage critical: ${MEM_PERCENT}%" "urgent"
elif [ "$MEM_PERCENT" -gt 80 ]; then
    log "Memory usage warning: ${MEM_PERCENT}%"
fi

# Report status
RUNNING=$(docker ps --filter "status=running" --format "{{.Names}}" 2>/dev/null | wc -l)
TOTAL=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
log "Health check complete: $RUNNING/$TOTAL containers running"
EOF
chmod +x /usr/local/bin/potatostack-healthcheck.sh

# Update health check timer
cat >/etc/systemd/system/potatostack-health.service <<EOF
[Unit]
Description=PotatoStack Health Check
After=potatostack.service docker.service
Requires=docker.service

[Service]
Type=oneshot
User=root
Environment="NTFY_TOPIC=${NTFY_TOPIC:-potatostack}"
ExecStart=/usr/local/bin/potatostack-healthcheck.sh
EOF

cat >/etc/systemd/system/potatostack-health.timer <<'EOF'
[Unit]
Description=PotatoStack Health Check Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable potatostack-health.timer
systemctl start potatostack-health.timer
log "Enhanced health check service created"

################################################################################
# 7. Memory Pressure Handler (OOM Prevention)
################################################################################
echo ""
echo "[7/10] Configuring Memory Pressure Handling..."

cat >/usr/local/bin/memory-pressure-handler.sh <<'EOF'
#!/bin/bash
################################################################################
# Memory Pressure Handler - Prevents OOM by proactive cleanup
################################################################################

LOG_FILE="/var/log/potatostack/memory-pressure.log"
mkdir -p /var/log/potatostack

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Get memory percentage used
get_mem_percent() {
    local available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    local total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    echo $((100 - (available * 100 / total)))
}

while true; do
    MEM_PERCENT=$(get_mem_percent)

    if [ "$MEM_PERCENT" -gt 85 ]; then
        log "Memory pressure detected: ${MEM_PERCENT}%"

        # Clear page cache (safe operation)
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

        # Clear Docker build cache
        docker builder prune -f 2>/dev/null || true

        NEW_MEM=$(get_mem_percent)
        log "After cleanup: ${NEW_MEM}%"

        if [ "$NEW_MEM" -gt 90 ]; then
            log "CRITICAL: Memory still high after cleanup"
            # Optionally restart heavy containers
            # docker restart immich-ml 2>/dev/null || true
        fi
    fi

    sleep 60
done
EOF
chmod +x /usr/local/bin/memory-pressure-handler.sh

cat >/etc/systemd/system/memory-pressure-handler.service <<'EOF'
[Unit]
Description=Memory Pressure Handler
After=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/memory-pressure-handler.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable memory-pressure-handler.service
systemctl start memory-pressure-handler.service
log "Memory pressure handler enabled"

################################################################################
# 8. Weekly Auto-Reboot (Optional)
################################################################################
echo ""
echo "[8/10] Configuring Scheduled Maintenance..."

read -rp "Enable weekly auto-reboot for maintenance? (Sunday 4am) [y/N]: " ENABLE_AUTOREBOOT
if [[ "$ENABLE_AUTOREBOOT" =~ ^[Yy]$ ]]; then
	cat >/etc/systemd/system/weekly-reboot.service <<'EOF'
[Unit]
Description=Weekly Maintenance Reboot

[Service]
Type=oneshot
ExecStart=/bin/systemctl reboot
EOF

	cat >/etc/systemd/system/weekly-reboot.timer <<'EOF'
[Unit]
Description=Weekly Reboot Timer

[Timer]
OnCalendar=Sun *-*-* 04:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

	systemctl daemon-reload
	systemctl enable weekly-reboot.timer
	log "Weekly auto-reboot enabled (Sunday 4am)"
else
	log "Weekly auto-reboot skipped"
fi

################################################################################
# 9. Docker Daemon Hardening
################################################################################
echo ""
echo "[9/10] Hardening Docker Daemon..."

# Backup existing config
if [ -f /etc/docker/daemon.json ]; then
	cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

cat >/etc/docker/daemon.json <<'EOF'
{
  "data-root": "/mnt/storage/docker",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "default-shm-size": "128M",
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3
}
EOF

systemctl daemon-reload
systemctl restart docker
log "Docker daemon hardened"

################################################################################
# 10. Final Verification
################################################################################
echo ""
echo "[10/10] Final Verification..."

# Verify all services
SERVICES="docker potatostack.service network-watchdog.service memory-pressure-handler.service potatostack-health.timer"
ALL_OK=true

for service in $SERVICES; do
	if systemctl is-enabled "$service" &>/dev/null; then
		log "$service is enabled"
	else
		warn "$service is NOT enabled"
		ALL_OK=false
	fi
done

# Verify watchdog
if systemctl is-enabled watchdog &>/dev/null 2>&1; then
	log "Hardware watchdog is enabled"
else
	warn "Hardware watchdog is NOT enabled"
fi

echo ""
echo "=================================================================="
if [ "$ALL_OK" = true ]; then
	echo -e "${GREEN}Enterprise-Grade Hardening Complete!${NC}"
else
	echo -e "${YELLOW}Hardening Complete with Warnings${NC}"
fi
echo "=================================================================="
echo ""
echo "Summary of protections enabled:"
echo "  - Hardware/software watchdog for kernel hang recovery"
echo "  - Network connectivity monitoring with auto-recovery"
echo "  - Enhanced container health checks every 10 minutes"
echo "  - Memory pressure handler to prevent OOM"
echo "  - Docker daemon hardening with live-restore"
echo "  - Kernel parameters optimized for stability"
echo "  - Auto-reboot on kernel panic (10 second delay)"
echo ""
echo "Log locations:"
echo "  /var/log/potatostack/healthcheck.log"
echo "  /var/log/potatostack/network-watchdog.log"
echo "  /var/log/potatostack/memory-pressure.log"
echo "  /var/log/watchdog/"
echo ""
echo "Commands:"
echo "  systemctl status potatostack          # Stack status"
echo "  systemctl status network-watchdog     # Network monitor"
echo "  journalctl -u potatostack -f          # Stack logs"
echo "  /usr/local/bin/potatostack-healthcheck.sh  # Manual health check"
echo ""
echo "Test with: sudo reboot"
echo ""
