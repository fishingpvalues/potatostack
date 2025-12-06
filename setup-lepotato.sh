#!/bin/bash
################################################################################
# PotatoStack Master Setup Script for Le Potato (SOTA Edition)
# Complete automation of deployment, validation, and optimization
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="$(pwd)"
LOG_FILE="/var/log/potatostack-setup-$(date +%Y%m%d-%H%M%S).log"
SETUP_STEPS_COMPLETED=0
SETUP_STEPS_TOTAL=15

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    SETUP_STEPS_COMPLETED=$((SETUP_STEPS_COMPLETED + 1))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${CYAN}[STEP $SETUP_STEPS_COMPLETED/$SETUP_STEPS_TOTAL]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root. Please use 'sudo bash $0'"
    exit 1
fi

# Display banner
clear
echo -e "${MAGENTA}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ████████                                              ║
║     ██  ██  ██  PotatoStack SOTA Edition v2.0            ║
║     ████████                                              ║
║     ██  ██  ██  Optimized for Le Potato SBC              ║
║     ████████    (2GB RAM, ARM Cortex-A53)                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}Starting automated setup at $(date)${NC}"
echo -e "${BLUE}Installation directory: $INSTALL_DIR${NC}"
echo -e "${BLUE}Log file: $LOG_FILE${NC}"
echo ""

# ============================================================================
# STEP 1: PRE-FLIGHT CHECKS
# ============================================================================
log_step "Pre-Flight System Checks"

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    log_warning "Detected architecture: $ARCH (expected: aarch64/arm64)"
    log_warning "This setup is optimized for ARM64. Proceeding anyway..."
fi

# Check memory
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))

if [ "$TOTAL_MEM_GB" -lt 2 ]; then
    log_error "Insufficient memory: ${TOTAL_MEM_GB}GB (minimum: 2GB)"
    exit 1
elif [ "$TOTAL_MEM_GB" -eq 2 ]; then
    log_success "Memory check passed: ${TOTAL_MEM_GB}GB (Le Potato confirmed)"
else
    log_warning "Detected ${TOTAL_MEM_GB}GB RAM (more than Le Potato's 2GB)"
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 4 ]; then
    log_warning "Detected $CPU_CORES CPU cores (Le Potato has 4)"
fi

log_success "Pre-flight checks completed"
echo ""

# ============================================================================
# STEP 2: SYSTEM DEPENDENCIES
# ============================================================================
log_step "Installing System Dependencies"

apt-get update >> "$LOG_FILE" 2>&1

PACKAGES=(
    "docker.io"
    "docker-compose"
    "curl"
    "wget"
    "git"
    "htop"
    "smartmontools"
    "lm-sensors"
    "sysstat"
    "iotop"
    "zfsutils-linux"
)

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        log "Installing $pkg..."
        apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
    fi
done

log_success "System dependencies installed"
echo ""

# ============================================================================
# STEP 3: DOCKER CONFIGURATION
# ============================================================================
log_step "Configuring Docker for Le Potato"

# Add user to docker group if not root
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    log "Added $SUDO_USER to docker group"
fi

# Optimize Docker for ARM + limited RAM
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

systemctl restart docker
log_success "Docker configured for Le Potato"
echo ""

# ============================================================================
# STEP 4: SWAP CONFIGURATION
# ============================================================================
log_step "Configuring Swap (CRITICAL for 2GB RAM)"

# Install systemd swap service
if [ -f "systemd/ensure-potatostack-swap.sh" ]; then
    cp systemd/ensure-potatostack-swap.sh /usr/local/bin/
    chmod +x /usr/local/bin/ensure-potatostack-swap.sh

    cp systemd/potatostack-swap.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable potatostack-swap.service
    systemctl start potatostack-swap.service

    log_success "Swap service installed and started"

    # Verify swap is active
    if swapon --show | grep -q swap; then
        SWAP_SIZE=$(swapon --show | tail -n 1 | awk '{print $3}')
        log_success "Swap active: $SWAP_SIZE"
    else
        log_error "Swap configuration failed"
        exit 1
    fi
else
    log_warning "Swap service files not found, configuring manually..."

    # Manual swap configuration
    if [ -d "/mnt/seconddrive" ]; then
        SWAPFILE="/mnt/seconddrive/potatostack.swap"
        SWAPSIZE_GB=3

        if [ ! -f "$SWAPFILE" ]; then
            log "Creating ${SWAPSIZE_GB}GB swap file at $SWAPFILE..."
            fallocate -l ${SWAPSIZE_GB}G "$SWAPFILE"
            chmod 600 "$SWAPFILE"
            mkswap "$SWAPFILE"
        fi

        swapon "$SWAPFILE"

        if ! grep -q "$SWAPFILE" /etc/fstab; then
            echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        fi

        log_success "Swap configured manually"
    else
        log_warning "Cannot configure swap: /mnt/seconddrive not mounted"
    fi
fi
echo ""

# ============================================================================
# STEP 5: ZFS SETUP (if drives are configured)
# ============================================================================
log_step "ZFS Setup (Optional - Check Configuration)"

if [ -f "01-setup-zfs.sh" ]; then
    log "ZFS setup script found"
    log "You can run it manually after this setup completes:"
    log "  sudo bash 01-setup-zfs.sh"
    log "Remember to configure MAIN_DRIVE and CACHE_DRIVE variables first!"
else
    log_warning "ZFS setup script not found"
fi

log_success "ZFS configuration noted"
echo ""

# ============================================================================
# STEP 6: DIRECTORY STRUCTURE
# ============================================================================
log_step "Creating Directory Structure"

mkdir -p "$INSTALL_DIR/config/"{prometheus,grafana/provisioning/{datasources,dashboards},loki,promtail,alertmanager,homepage}
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/scripts"

log_success "Directory structure created"
echo ""

# ============================================================================
# STEP 7: ENVIRONMENT FILE
# ============================================================================
log_step "Configuring Environment Variables"

if [ ! -f "$INSTALL_DIR/.env" ]; then
    if [ -f "$INSTALL_DIR/.env.example" ]; then
        cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
        log "Created .env from .env.example"
        log_warning "IMPORTANT: Edit .env file and configure all passwords/secrets"
    else
        log_warning ".env.example not found, you'll need to create .env manually"
    fi
fi

log_success "Environment configuration ready"
echo ""

# ============================================================================
# STEP 8: CONFIGURATION VALIDATION
# ============================================================================
log_step "Validating Configuration with OPA Conftest"

if command -v conftest &> /dev/null; then
    if [ -f "policy/docker-compose.rego" ] && [ -f "docker-compose.yml" ]; then
        log "Running OPA policy validation..."

        if conftest test -p policy docker-compose.yml >> "$LOG_FILE" 2>&1; then
            log_success "Docker Compose configuration passes OPA policy checks"
        else
            log_warning "OPA policy validation found issues (check $LOG_FILE)"
            log "Continuing anyway, but review warnings..."
        fi
    else
        log_warning "OPA policy or docker-compose.yml not found"
    fi
else
    log_warning "Conftest not installed, skipping policy validation"
    log "Install with: curl -L https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_arm64.tar.gz | tar xz && mv conftest /usr/local/bin/"
fi

log_success "Configuration validation completed"
echo ""

# ============================================================================
# STEP 9: PULL DOCKER IMAGES (Pre-download for faster first boot)
# ============================================================================
log_step "Pre-downloading Docker Images"

if [ -f "docker-compose.yml" ]; then
    log "Pulling all Docker images (this may take 10-30 minutes on first run)..."
    docker-compose pull --quiet >> "$LOG_FILE" 2>&1 &
    PULL_PID=$!

    # Show progress
    while kill -0 $PULL_PID 2>/dev/null; do
        echo -n "."
        sleep 2
    done
    echo ""

    wait $PULL_PID
    log_success "Docker images downloaded"
else
    log_error "docker-compose.yml not found in $INSTALL_DIR"
    exit 1
fi
echo ""

# ============================================================================
# STEP 10: SYSTEMD SERVICE INSTALLATION
# ============================================================================
log_step "Installing PotatoStack Systemd Service"

if [ -f "systemd/potatostack.service" ]; then
    # Update WorkingDirectory to actual install directory
    sed "s|/home/USER/potatostack|$INSTALL_DIR|g" systemd/potatostack.service | \
    sed "s|User=USER|User=${SUDO_USER:-root}|g" | \
    sed "s|Group=USER|Group=${SUDO_USER:-root}|g" > /etc/systemd/system/potatostack.service

    systemctl daemon-reload
    systemctl enable potatostack.service
    log_success "PotatoStack systemd service installed"
    log "Service will auto-start on boot. Start now with: systemctl start potatostack"
else
    log_warning "potatostack.service not found"
fi

log_success "Systemd service configured"
echo ""

# ============================================================================
# STEP 11: SCRIPT PERMISSIONS
# ============================================================================
log_step "Setting Script Permissions"

for script in scripts/*.sh *.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script"
    fi
done

log_success "Script permissions set"
echo ""

# ============================================================================
# STEP 12: HEALTH CHECK SETUP
# ============================================================================
log_step "Configuring Health Checks"

if [ -f "scripts/health-check.sh" ]; then
    # Create daily health check cron
    CRON_CMD="0 2 * * * $INSTALL_DIR/scripts/health-check.sh >> /var/log/potatostack-health.log 2>&1"

    if ! crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        log "Daily health check cron job installed (2 AM)"
    fi
fi

log_success "Health checks configured"
echo ""

# ============================================================================
# STEP 13: MONITORING CONFIGURATION
# ============================================================================
log_step "Configuring Monitoring Stack"

log "Prometheus, Grafana, and Loki configuration files are in config/"
log "Alert rules include Le Potato-specific thresholds (swap, memory, CPU)"

log_success "Monitoring configuration ready"
echo ""

# ============================================================================
# STEP 14: BACKUP VERIFICATION SETUP
# ============================================================================
log_step "Configuring Backup Verification"

if [ -f "scripts/verify-kopia-backups.sh" ]; then
    # Create monthly backup verification cron
    CRON_CMD="0 3 1 * * $INSTALL_DIR/scripts/verify-kopia-backups.sh >> /var/log/potatostack-backup-verify.log 2>&1"

    if ! crontab -l 2>/dev/null | grep -q "verify-kopia-backups.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        log "Monthly backup verification cron job installed (1st of month, 3 AM)"
    fi
fi

log_success "Backup verification configured"
echo ""

# ============================================================================
# STEP 15: FINAL VALIDATION & SUMMARY
# ============================================================================
log_step "Final System Validation"

# Check critical requirements
VALIDATION_FAILED=false

# Check swap
if ! swapon --show | grep -q swap; then
    log_error "Swap not active (CRITICAL for 2GB RAM)"
    VALIDATION_FAILED=true
fi

# Check Docker
if ! systemctl is-active --quiet docker; then
    log_error "Docker service not running"
    VALIDATION_FAILED=true
fi

# Check .env
if [ ! -f "$INSTALL_DIR/.env" ]; then
    log_error ".env file not configured"
    VALIDATION_FAILED=true
fi

if [ "$VALIDATION_FAILED" = true ]; then
    log_error "Setup validation failed. Please review errors above."
    exit 1
fi

log_success "Final validation passed"
echo ""

# ============================================================================
# SETUP COMPLETE
# ============================================================================

clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║  ✓ POTATOSTACK SETUP COMPLETE!                           ║
║                                                           ║
║  Your Le Potato is ready for deployment!                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  NEXT STEPS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}1. Configure Environment Variables:${NC}"
echo "   nano $INSTALL_DIR/.env"
echo "   (Set all passwords, API keys, and secrets)"
echo ""
echo -e "${YELLOW}2. (Optional) Setup ZFS Storage:${NC}"
echo "   Edit: nano 01-setup-zfs.sh (set MAIN_DRIVE and CACHE_DRIVE)"
echo "   Run: sudo bash 01-setup-zfs.sh"
echo "   Then: sudo bash 02-migrate-and-update-docker.sh"
echo ""
echo -e "${YELLOW}3. Start PotatoStack:${NC}"
echo "   systemctl start potatostack"
echo "   OR"
echo "   cd $INSTALL_DIR && docker-compose up -d"
echo ""
echo -e "${YELLOW}4. Verify Deployment:${NC}"
echo "   bash scripts/health-check.sh"
echo ""
echo -e "${YELLOW}5. Verify VPN Killswitch (IMPORTANT):${NC}"
echo "   bash scripts/verify-vpn-killswitch.sh"
echo ""
echo -e "${YELLOW}6. Verify Backups:${NC}"
echo "   bash scripts/verify-kopia-backups.sh"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  ACCESS YOUR SERVICES${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Homepage:    http://$(hostname -I | awk '{print $1}'):3003"
echo "  Portainer:   http://$(hostname -I | awk '{print $1}'):9000"
echo "  Grafana:     http://$(hostname -I | awk '{print $1}'):3000"
echo "  Prometheus:  http://$(hostname -I | awk '{print $1}'):9090"
echo "  qBittorrent: http://$(hostname -I | awk '{print $1}'):8080"
echo "  Kopia:       https://$(hostname -I | awk '{print $1}'):51515"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Setup completed successfully at $(date)${NC}"
echo -e "${BLUE}Full log: $LOG_FILE${NC}"
echo ""

exit 0
