#!/bin/bash

################################################################################
# PotatoStack Unified Setup Script
# Combines setup.sh + setup-lepotato.sh + preflight-check.sh
# Optimized for Le Potato SBC (ARM64, 2GB RAM)
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/potatostack-setup-$(date +%Y%m%d-%H%M%S).log"
ERRORS=0
WARNINGS=0
SETUP_STEPS_COMPLETED=0
SETUP_STEPS_TOTAL=15

# CLI Flags
MODE="full"           # full, preflight, minimal
NONINTERACTIVE=false
SKIP_PULL=false
ENABLE_ZFS=false

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
    ((ERRORS++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    ((WARNINGS++))
}

log_step() {
    echo -e "${CYAN}[STEP $SETUP_STEPS_COMPLETED/$SETUP_STEPS_TOTAL]${NC} $1" | tee -a "$LOG_FILE"
}

check_pass() {
    echo -e "[${GREEN}✓${NC}] $1" | tee -a "$LOG_FILE"
}

check_warn() {
    echo -e "[${YELLOW}⚠${NC}] $1" | tee -a "$LOG_FILE"
    ((WARNINGS++))
}

check_fail() {
    echo -e "[${RED}✗${NC}] $1" | tee -a "$LOG_FILE"
    ((ERRORS++))
}

# Help message
show_help() {
    cat << EOF
PotatoStack Unified Setup Script

USAGE:
    sudo ./setup.sh [OPTIONS]

MODES:
    (default)          Full interactive setup
    --preflight        Pre-flight checks only (no changes)
    --minimal          Minimal setup (skip optional components)

OPTIONS:
    --non-interactive  Skip interactive prompts (CI/CD mode)
    --skip-pull        Skip pulling Docker images
    --zfs              Include ZFS setup workflow
    --help             Show this help message

EXAMPLES:
    sudo ./setup.sh                        # Full interactive setup
    sudo ./setup.sh --preflight            # Check system readiness
    sudo ./setup.sh --non-interactive      # Automated setup
    sudo ./setup.sh --zfs                  # Setup with ZFS pool

REQUIREMENTS:
    - Root/sudo access
    - ARM64/aarch64 architecture (recommended)
    - 2GB RAM minimum
    - Docker and Docker Compose
    - /mnt/seconddrive and /mnt/cachehdd mounted

For more information, see: https://github.com/anthropics/potatostack
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preflight)
            MODE="preflight"
            shift
            ;;
        --minimal)
            MODE="minimal"
            shift
            ;;
        --non-interactive)
            NONINTERACTIVE=true
            shift
            ;;
        --skip-pull)
            SKIP_PULL=true
            shift
            ;;
        --zfs)
            ENABLE_ZFS=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root. Please use 'sudo ./setup.sh'"
    exit 1
fi

# Display banner
clear
echo -e "${MAGENTA}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ████████                                              ║
║     ██  ██  ██  PotatoStack Unified Setup v2.1           ║
║     ████████                                              ║
║     ██  ██  ██  Optimized for Le Potato SBC              ║
║     ████████    (2GB RAM, ARM Cortex-A53)                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [ "$MODE" = "preflight" ]; then
    echo -e "${BLUE}Running in PRE-FLIGHT CHECK mode (read-only)${NC}"
elif [ "$MODE" = "minimal" ]; then
    echo -e "${BLUE}Running in MINIMAL SETUP mode${NC}"
else
    echo -e "${BLUE}Running in FULL SETUP mode${NC}"
fi

echo -e "${BLUE}Installation directory: $SCRIPT_DIR${NC}"
echo -e "${BLUE}Log file: $LOG_FILE${NC}"
echo ""

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

run_preflight_checks() {
    log_step "Pre-Flight System Checks"

    echo -e "\n${BLUE}=== System Architecture ===${NC}"
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        check_pass "Architecture: $ARCH (ARM64)"
    else
        check_warn "Architecture: $ARCH (Expected ARM64, may work but not tested)"
    fi

    echo -e "\n${BLUE}=== Memory Check ===${NC}"
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -ge 1800 ]; then
        check_pass "RAM: ${TOTAL_RAM}MB available"
    else
        check_fail "RAM: ${TOTAL_RAM}MB (Minimum 2GB required)"
    fi

    FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
    if [ "$FREE_RAM" -lt 500 ]; then
        check_warn "Only ${FREE_RAM}MB RAM free (recommend >500MB before starting)"
    fi

    echo -e "\n${BLUE}=== Swap Check ===${NC}"
    SWAP=$(free -m | awk '/^Swap:/{print $2}')
    if [ "$SWAP" -ge 1024 ]; then
        check_pass "Swap: ${SWAP}MB configured"
    elif [ "$SWAP" -gt 0 ]; then
        check_warn "Swap: ${SWAP}MB (Recommend ≥1GB for stability)"
    else
        check_warn "No swap configured (Strongly recommend adding swap for 2GB RAM)"
    fi

    echo -e "\n${BLUE}=== Docker Check ===${NC}"
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        check_pass "Docker installed: $DOCKER_VERSION"

        if docker ps &> /dev/null; then
            check_pass "Docker daemon running"
        else
            check_fail "Docker daemon not running (try: sudo systemctl start docker)"
        fi
    else
        check_fail "Docker not installed"
    fi

    echo -e "\n${BLUE}=== Docker Compose Check ===${NC}"
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        check_pass "Docker Compose installed: $COMPOSE_VERSION"
    elif docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        check_pass "Docker Compose (plugin) installed: $COMPOSE_VERSION"
    else
        check_fail "Docker Compose not installed"
    fi

    echo -e "\n${BLUE}=== Storage Check ===${NC}"
    if [ -d "/mnt/seconddrive" ]; then
        SECOND_SIZE=$(df -h /mnt/seconddrive 2>/dev/null | awk 'NR==2{print $2}')
        SECOND_AVAIL=$(df -h /mnt/seconddrive 2>/dev/null | awk 'NR==2{print $4}')
        check_pass "Main HDD mounted: /mnt/seconddrive ($SECOND_SIZE total, $SECOND_AVAIL free)"

        if touch /mnt/seconddrive/.writetest 2>/dev/null; then
            rm /mnt/seconddrive/.writetest
            check_pass "Main HDD is writable"
        else
            check_fail "Main HDD is not writable (check permissions)"
        fi
    else
        check_fail "Main HDD not mounted at /mnt/seconddrive"
    fi

    if [ -d "/mnt/cachehdd" ]; then
        CACHE_SIZE=$(df -h /mnt/cachehdd 2>/dev/null | awk 'NR==2{print $2}')
        CACHE_AVAIL=$(df -h /mnt/cachehdd 2>/dev/null | awk 'NR==2{print $4}')
        check_pass "Cache HDD mounted: /mnt/cachehdd ($CACHE_SIZE total, $CACHE_AVAIL free)"

        if touch /mnt/cachehdd/.writetest 2>/dev/null; then
            rm /mnt/cachehdd/.writetest
            check_pass "Cache HDD is writable"
        else
            check_fail "Cache HDD is not writable (check permissions)"
        fi
    else
        check_fail "Cache HDD not mounted at /mnt/cachehdd"
    fi

    echo -e "\n${BLUE}=== Network Check ===${NC}"
    IP=$(hostname -I | awk '{print $1}')
    check_pass "Local IP: $IP"

    if ping -c 1 8.8.8.8 &> /dev/null 2>&1; then
        check_pass "Internet connectivity OK"
    else
        check_warn "No internet connection (required for pulling Docker images)"
    fi

    echo -e "\n${BLUE}=== Configuration Check ===${NC}"
    if [ -f "$SCRIPT_DIR/.env" ]; then
        check_pass ".env file exists"

        if grep -q "change_this" "$SCRIPT_DIR/.env" || grep -q "your_" "$SCRIPT_DIR/.env"; then
            check_warn ".env contains default passwords - UPDATE BEFORE DEPLOYING!"
        else
            check_pass ".env appears to be customized"
        fi
    else
        check_warn ".env file not found (will be created from .env.example)"
    fi

    if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        check_pass "docker-compose.yml exists"
    else
        check_fail "docker-compose.yml not found"
    fi

    log_success "Pre-flight checks completed"

    # Summary
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    SUMMARY                         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"

    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! System is ready for PotatoStack deployment.${NC}"
        return 0
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) found. Review warnings above.${NC}"
        echo -e "\nSystem should work, but review warnings for optimal performance."
        return 0
    else
        echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found.${NC}"
        echo -e "\n${RED}Please fix errors before proceeding with full setup.${NC}"
        return 1
    fi
}

# Run preflight checks
run_preflight_checks

# If preflight-only mode, exit here
if [ "$MODE" = "preflight" ]; then
    if [ $ERRORS -eq 0 ]; then
        echo -e "\n${GREEN}Pre-flight checks passed!${NC}"
        echo -e "Ready to run: ${BLUE}sudo ./setup.sh${NC}"
        exit 0
    else
        echo -e "\n${RED}Pre-flight checks failed. Fix errors above.${NC}"
        exit 1
    fi
fi

# Ask for confirmation if there were errors
if [ $ERRORS -gt 0 ] && [ "$NONINTERACTIVE" = false ]; then
    echo ""
    read -p "Errors detected. Continue anyway? (yes/no): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy][Ee][Ss]$ ]]; then
        log_error "Setup cancelled by user"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}Proceeding with installation...${NC}"
echo ""

################################################################################
# MAIN SETUP
################################################################################

# Determine docker compose command
if command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DC="docker compose"
else
    DC="docker-compose"
fi

log_step "Installing System Dependencies"

apt-get update >> "$LOG_FILE" 2>&1 || log_warning "apt-get update failed"

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
)

# Add ZFS if enabled
if [ "$ENABLE_ZFS" = true ]; then
    PACKAGES+=("zfsutils-linux")
fi

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l 2>/dev/null | grep -q "^ii  $pkg"; then
        log "Installing $pkg..."
        apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1 || log_warning "Failed to install $pkg"
    fi
done

log_success "System dependencies installed"

log_step "Configuring Docker for Le Potato"

# Add user to docker group
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER" 2>/dev/null || true
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

systemctl restart docker 2>/dev/null || true
log_success "Docker configured"

log_step "Configuring Swap (CRITICAL for 2GB RAM)"

# Install systemd swap service if available
if [ -f "$SCRIPT_DIR/systemd/ensure-potatostack-swap.sh" ]; then
    cp "$SCRIPT_DIR/systemd/ensure-potatostack-swap.sh" /usr/local/bin/
    chmod +x /usr/local/bin/ensure-potatostack-swap.sh

    cp "$SCRIPT_DIR/systemd/potatostack-swap.service" /etc/systemd/system/ 2>/dev/null || true
    systemctl daemon-reload
    systemctl enable potatostack-swap.service 2>/dev/null || true
    systemctl start potatostack-swap.service 2>/dev/null || true

    log_success "Swap service installed"
else
    # Manual swap configuration
    if [ -d "/mnt/seconddrive" ] && [ ! -f "/mnt/seconddrive/potatostack.swap" ]; then
        SWAPFILE="/mnt/seconddrive/potatostack.swap"
        SWAPSIZE_GB=3

        log "Creating ${SWAPSIZE_GB}GB swap file..."
        fallocate -l ${SWAPSIZE_GB}G "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1G count=$SWAPSIZE_GB 2>/dev/null
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE" >> "$LOG_FILE" 2>&1
        swapon "$SWAPFILE" 2>/dev/null || true

        if ! grep -q "$SWAPFILE" /etc/fstab 2>/dev/null; then
            echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        fi

        log_success "Swap configured manually"
    fi
fi

log_step "Creating Directory Structure"

mkdir -p "$SCRIPT_DIR/config/"{prometheus,grafana/provisioning/{datasources,dashboards},loki,promtail,alertmanager,homepage,fints-importer}
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/scripts"
mkdir -p "$SCRIPT_DIR/docs"

# Create data directories on mounted drives
if [ -d "/mnt/seconddrive" ]; then
    mkdir -p /mnt/seconddrive/{kopia/{repository,config,cache,logs,tmp},qbittorrent/{config,logs},slskd/{config,logs},nextcloud,gitea,uptime-kuma,backups/{db,vaultwarden}}
    chown -R 1000:1000 /mnt/seconddrive 2>/dev/null || true
fi

if [ -d "/mnt/cachehdd" ]; then
    mkdir -p /mnt/cachehdd/{torrents/incomplete,soulseek/incomplete}
    chown -R 1000:1000 /mnt/cachehdd 2>/dev/null || true
fi

log_success "Directory structure created"

log_step "Configuring Environment Variables"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        log "Created .env from .env.example"

        if [ "$NONINTERACTIVE" = false ]; then
            log_warning "IMPORTANT: Edit .env file and configure all passwords/secrets"
            read -p "Press enter to edit .env now, or Ctrl+C to exit and edit later..."
            ${EDITOR:-nano} "$SCRIPT_DIR/.env"
        else
            log_warning "Non-interactive mode: Remember to edit .env before deployment"
        fi
    else
        log_error ".env.example not found"
    fi
fi

log_success "Environment configuration ready"

log_step "System Optimizations"

# Increase inotify limits
grep -q '^fs.inotify.max_user_watches=524288' /etc/sysctl.conf || echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
grep -q '^fs.inotify.max_user_instances=512' /etc/sysctl.conf || echo "fs.inotify.max_user_instances=512" >> /etc/sysctl.conf

# Enable IP forwarding for VPN
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

sysctl -p >/dev/null 2>&1 || true

log_success "System optimizations applied"

if [ "$SKIP_PULL" = false ] && [ "$MODE" != "minimal" ]; then
    log_step "Pulling Docker Images"

    cd "$SCRIPT_DIR"
    if [ -f "docker-compose.yml" ]; then
        log "Pulling images (this may take 10-30 minutes)..."
        $DC pull >> "$LOG_FILE" 2>&1 || log_warning "Some images failed to pull"
        log_success "Docker images downloaded"
    fi
fi

log_step "Making Scripts Executable"

for script in "$SCRIPT_DIR"/scripts/*.sh "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script" 2>/dev/null || true
    fi
done

log_success "Script permissions set"

log_step "Configuring Health Checks & Monitoring"

if [ -f "$SCRIPT_DIR/scripts/health-check.sh" ]; then
    CRON_CMD="0 2 * * * $SCRIPT_DIR/scripts/health-check.sh >> /var/log/potatostack-health.log 2>&1"

    if ! crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        log "Daily health check cron job installed (2 AM)"
    fi
fi

log_success "Health checks configured"

log_step "Final Validation"

# Check critical requirements
VALIDATION_FAILED=false

if ! systemctl is-active --quiet docker 2>/dev/null; then
    log_error "Docker service not running"
    VALIDATION_FAILED=true
fi

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log_error ".env file not configured"
    VALIDATION_FAILED=true
fi

if [ "$VALIDATION_FAILED" = true ]; then
    log_error "Setup validation failed"
    exit 1
fi

log_success "Final validation passed"

################################################################################
# ZFS SETUP (if requested)
################################################################################

if [ "$ENABLE_ZFS" = true ]; then
    echo ""
    log_step "ZFS Setup Workflow"

    if [ -f "$SCRIPT_DIR/01-setup-zfs.sh" ]; then
        log "ZFS setup script found"
        log "Next steps for ZFS:"
        log "  1. Edit 01-setup-zfs.sh (set MAIN_DRIVE and CACHE_DRIVE)"
        log "  2. Run: sudo ./01-setup-zfs.sh --create"
        log "  3. Run: sudo ./01-setup-zfs.sh --migrate"
    else
        log_warning "ZFS setup script not found"
    fi
fi

################################################################################
# SETUP COMPLETE
################################################################################

clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║  ✓ POTATOSTACK SETUP COMPLETE!                           ║
║                                                           ║
║  Your system is ready for deployment!                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  NEXT STEPS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}1. Review Environment Configuration:${NC}"
echo "   \${EDITOR:-nano} $SCRIPT_DIR/.env"
echo "   (Ensure all passwords and secrets are set)"
echo ""
echo -e "${YELLOW}2. Start PotatoStack:${NC}"
echo "   cd $SCRIPT_DIR && docker compose up -d"
echo "   OR: make up"
echo ""
echo -e "${YELLOW}3. Verify Deployment:${NC}"
echo "   make health"
echo ""
echo -e "${YELLOW}4. Enable Auto-Start (Optional):${NC}"
echo "   make systemd"
echo ""
echo -e "${YELLOW}5. Important Security Checks:${NC}"
echo "   make vpn-test        # Verify VPN killswitch"
echo "   make backup-verify   # Verify Kopia backups"
echo ""

if [ "$ENABLE_ZFS" = true ]; then
    echo -e "${YELLOW}6. Complete ZFS Setup (if needed):${NC}"
    echo "   Edit: nano 01-setup-zfs.sh"
    echo "   Run: sudo ./01-setup-zfs.sh --create"
    echo "   Run: sudo ./01-setup-zfs.sh --migrate"
    echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  ACCESS YOUR SERVICES${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
IP=$(hostname -I | awk '{print $1}')
echo "  Homepage:         http://$IP:3003"
echo "  Portainer:        http://$IP:9000"
echo "  Grafana:          http://$IP:3000"
echo "  Prometheus:       http://$IP:9090"
echo "  Firefly III:      http://$IP:8085"
echo "  Vaultwarden:      http://$IP:8084"
echo "  qBittorrent:      http://$IP:8080"
echo "  Kopia:            https://$IP:51515"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Setup completed successfully at $(date)${NC}"
echo -e "${BLUE}Full log: $LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}Remember to:${NC}"
echo "  - Configure Nginx Proxy Manager for HTTPS"
echo "  - Set up Authelia 2FA"
echo "  - Configure Firefly III and FinTS importer"
echo "  - Test all services"
echo ""

exit 0
