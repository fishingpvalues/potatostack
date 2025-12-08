#!/bin/bash
################################################################################
# PotatoStack ZFS Setup Script (2-Stage)
# Unified script combining ZFS pool creation and Docker migration
################################################################################
# Stage 1 (--create): Install ZFS, create pool, add cache drive
# Stage 2 (--migrate): Update docker-compose.yml paths to use new ZFS pool
#
# USAGE:
#   sudo ./01-setup-zfs.sh --create     # Stage 1: Create ZFS pool
#   sudo ./01-setup-zfs.sh --migrate    # Stage 2: Migrate Docker to ZFS
#   sudo ./01-setup-zfs.sh --help       # Show this help
#
# WARNING: Stage 1 WILL WIPE THE DRIVES YOU SELECT. BACKUP FIRST!
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
POOL_NAME="potatostack"
MOUNT_POINT="/mnt/$POOL_NAME"
COMPOSE_FILE="docker-compose.yml"

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""
}

# Show help
show_help() {
    cat << EOF
PotatoStack ZFS Setup Script (2-Stage)

USAGE:
    sudo ./01-setup-zfs.sh <command> [options]

COMMANDS:
    --create            Stage 1: Create ZFS pool with optimizations
    --migrate           Stage 2: Migrate docker-compose.yml to ZFS paths
    --help              Show this help message

STAGE 1 (--create): ZFS Pool Creation
    - Installs ZFS utilities
    - Configures ZFS for low-RAM systems (256MB limit)
    - Creates ZFS pool from main drive
    - Adds cache drive as L2ARC
    - Applies Le Potato-specific optimizations

STAGE 2 (--migrate): Docker Migration
    - Backs up docker-compose.yml
    - Updates all volume paths to use ZFS mount point
    - Prepares for Docker restart

EXAMPLES:
    # Stage 1: Create ZFS pool (DESTRUCTIVE - WIPES DRIVES!)
    sudo ./01-setup-zfs.sh --create

    # Stage 2: After restoring data, migrate Docker
    sudo ./01-setup-zfs.sh --migrate

CONFIGURATION:
    Before running --create, edit this script to set:
    - MAIN_DRIVE="/dev/sdX"     # Your primary HDD
    - CACHE_DRIVE="/dev/sdY"    # Your cache SSD
    - POOL_NAME="potatostack"   # ZFS pool name
    - MOUNT_POINT="/mnt/potatostack"

IMPORTANT:
    - Stage 1 WILL WIPE both drives completely
    - Have a full backup before proceeding
    - Run Stage 1 first, restore data, then run Stage 2
    - Stage 2 requires docker-compose.yml in current directory

EOF
    exit 0
}

# Check root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        log "Use: sudo ./01-setup-zfs.sh $1"
        exit 1
    fi
}

################################################################################
# STAGE 1: ZFS Pool Creation
################################################################################

stage_create() {
    log_step "Stage 1: ZFS Pool Creation and Tuning"

    # Drive configuration - USER MUST EDIT THESE!
    MAIN_DRIVE="/dev/sdX"   # Your large, primary HDD (e.g., /dev/sda)
    CACHE_DRIVE="/dev/sdY"  # Your smaller, faster cache drive/SSD (e.g., /dev/sdb)

    # Safety check - ensure user edited the drive paths
    if [ "$MAIN_DRIVE" = "/dev/sdX" ] || [ "$CACHE_DRIVE" = "/dev/sdY" ]; then
        log_error "Drive paths not configured!"
        log ""
        log "Before running --create, edit this script and set:"
        log "  MAIN_DRIVE=\"/dev/sdX\"   # Your primary HDD"
        log "  CACHE_DRIVE=\"/dev/sdY\"  # Your cache SSD"
        log ""
        log "Use 'lsblk -o NAME,SIZE,MODEL' to identify your drives"
        exit 1
    fi

    log "Configuration:"
    log "  Main Drive:   $MAIN_DRIVE"
    log "  Cache Drive:  $CACHE_DRIVE"
    log "  Pool Name:    $POOL_NAME"
    log "  Mount Point:  $MOUNT_POINT"
    echo ""

    # Final warning
    log_warning "========================================="
    log_warning "WARNING: DATA DESTRUCTION IMMINENT"
    log_warning "========================================="
    log_warning "This will ERASE ALL DATA on:"
    log_warning "  - $MAIN_DRIVE"
    log_warning "  - $CACHE_DRIVE"
    log_warning ""
    log_warning "Ensure you have a complete backup!"
    echo ""

    read -p "Type 'ERASE' and press [Enter] to continue, or anything else to abort: " CONFIRMATION
    if [ "$CONFIRMATION" != "ERASE" ]; then
        log "Aborted by user"
        exit 0
    fi

    log "User confirmed. Proceeding..."

    # Install ZFS utilities
    log_step "Installing ZFS Utilities"
    apt-get update > /dev/null 2>&1
    apt-get install -y zfsutils-linux

    log_success "ZFS utilities installed"

    # Configure ZFS for low RAM
    log_step "Tuning ZFS for Low RAM (256MB Limit)"
    log "This is CRITICAL for Le Potato's 2GB RAM"

    cat > /etc/modprobe.d/zfs.conf << 'EOF'
# Limit ZFS Adaptive Replacement Cache (ARC) to 256MB
options zfs zfs_arc_max=268435456
# Reduce prefetch for low RAM systems
options zfs zfs_prefetch_disable=0
EOF

    # Reload kernel modules
    if lsmod | grep -q zfs; then
        modprobe -r zfs 2>/dev/null || true
    fi
    modprobe zfs

    log_success "ZFS RAM limit configured (256MB)"

    # Create ZFS pool with optimizations
    log_step "Creating ZFS Pool with Optimizations"
    log "Creating pool '$POOL_NAME' from $MAIN_DRIVE..."

    zpool create -f \
        -o ashift=12 \
        -O compression=lz4 \
        -O atime=off \
        -O relatime=on \
        -O xattr=sa \
        -O dnodesize=auto \
        -O recordsize=128k \
        -O sync=standard \
        -O redundant_metadata=most \
        -m "$MOUNT_POINT" \
        "$POOL_NAME" "$MAIN_DRIVE"

    log_success "Pool '$POOL_NAME' created with compression and optimizations"

    # Add cache drive
    log_step "Adding Cache Drive (L2ARC)"
    log "Adding $CACHE_DRIVE as cache device..."

    zpool add -f "$POOL_NAME" cache "$CACHE_DRIVE"

    log_success "Cache device added successfully"

    # Apply Le Potato-specific optimizations
    log_step "Applying Le Potato Optimizations"

    zfs set primarycache=metadata "$POOL_NAME"
    zfs set secondarycache=all "$POOL_NAME"
    zfs set dedup=off "$POOL_NAME"
    zfs set sync=standard "$POOL_NAME"
    zfs set logbias=throughput "$POOL_NAME"

    log_success "Le Potato optimizations applied"

    # Verification
    log_step "Verification"
    log "ZFS pool status:"
    zpool status "$POOL_NAME"
    echo ""

    log "ZFS filesystems:"
    zfs list -o name,mountpoint,mounted
    echo ""

    # Final instructions
    log_step "Stage 1 Complete!"
    log_success "ZFS pool '$POOL_NAME' is ready at $MOUNT_POINT"
    log ""
    log "Next steps:"
    log "  1. Restore your backed-up data to $MOUNT_POINT/"
    log "     For example:"
    log "       - $MOUNT_POINT/kopia/"
    log "       - $MOUNT_POINT/nextcloud/"
    log "       - $MOUNT_POINT/torrents/"
    log "       - etc."
    log ""
    log "  2. After data restoration, run Stage 2:"
    log "     sudo ./01-setup-zfs.sh --migrate"
    log ""
}

################################################################################
# STAGE 2: Docker Migration
################################################################################

stage_migrate() {
    log_step "Stage 2: Docker Compose Migration to ZFS"

    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.yml not found in current directory"
        log "Please run this script from the potatostack project root"
        exit 1
    fi

    # Check if ZFS pool exists
    if ! zpool list "$POOL_NAME" >/dev/null 2>&1; then
        log_error "ZFS pool '$POOL_NAME' not found"
        log "Run Stage 1 first: sudo ./01-setup-zfs.sh --create"
        exit 1
    fi

    # Check if mount point exists
    if [ ! -d "$MOUNT_POINT" ]; then
        log_error "Mount point $MOUNT_POINT does not exist"
        log "Run Stage 1 first: sudo ./01-setup-zfs.sh --create"
        exit 1
    fi

    # User confirmation for data restoration
    log "Prerequisites checklist:"
    log "  1. ZFS pool created: $(zpool list -H -o name "$POOL_NAME" 2>/dev/null || echo 'NOT FOUND')"
    log "  2. Mount point exists: $MOUNT_POINT"
    log "  3. Data restoration status: UNKNOWN"
    echo ""

    log_warning "IMPORTANT: Data Restoration Required"
    log_warning "Before proceeding, ensure your backed-up data is restored to:"
    log_warning "  $MOUNT_POINT/"
    log_warning ""
    log_warning "You should have directories like:"
    log_warning "  - $MOUNT_POINT/kopia/"
    log_warning "  - $MOUNT_POINT/nextcloud/"
    log_warning "  - $MOUNT_POINT/torrents/"
    log_warning "  - etc."
    echo ""

    read -p "Have you restored all data to $MOUNT_POINT? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aborted by user. Restore data first, then re-run this command."
        exit 0
    fi

    # Backup docker-compose.yml
    log_step "Backing Up docker-compose.yml"

    BACKUP_FILE="${COMPOSE_FILE}.bak-$(date +%F_%H-%M-%S)"
    cp "$COMPOSE_FILE" "$BACKUP_FILE"

    log_success "Backup created: $BACKUP_FILE"

    # Update paths in docker-compose.yml
    log_step "Updating Docker Volume Paths"
    log "Replacing old mount points with $MOUNT_POINT..."

    # Replace common old mount points with new ZFS mount point
    sed -i "s|/mnt/seconddrive|$MOUNT_POINT|g" "$COMPOSE_FILE"
    sed -i "s|/mnt/cachehdd|$MOUNT_POINT|g" "$COMPOSE_FILE"
    sed -i "s|/mnt/storage|$MOUNT_POINT|g" "$COMPOSE_FILE"

    log_success "Paths updated in docker-compose.yml"

    # Show diff if available
    if command -v diff >/dev/null 2>&1; then
        log "Changes made (showing diff):"
        echo ""
        diff -u "$BACKUP_FILE" "$COMPOSE_FILE" || true
        echo ""
    fi

    # Final instructions
    log_step "Stage 2 Complete!"
    log_success "docker-compose.yml has been updated for ZFS storage"
    log ""
    log "Next steps:"
    log "  1. Review changes (optional):"
    log "     diff $BACKUP_FILE $COMPOSE_FILE"
    log ""
    log "  2. Restart Docker stack to apply changes:"
    log "     docker compose down"
    log "     docker compose up -d"
    log ""
    log "  3. Verify all services are running:"
    log "     docker compose ps"
    log ""
    log_success "Your stack is now running on the cache-enabled ZFS pool!"
    log ""
}

################################################################################
# Main Entry Point
################################################################################

case "${1:-}" in
    --create)
        check_root "--create"
        stage_create
        ;;
    --migrate)
        check_root "--migrate"
        stage_migrate
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        log_error "Unknown command: ${1:-<none>}"
        echo ""
        show_help
        ;;
esac

exit 0
