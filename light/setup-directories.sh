#!/bin/bash
################################################################################
# PotatoStack Light - Directory Setup Script
# Creates required directory structure on mounted HDDs
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAIN_DRIVE="/mnt/seconddrive"
CACHE_DRIVE="/mnt/cachehdd"
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Directory structure definitions
declare -A MAIN_DIRS=(
    ["downloads"]="Transmission completed torrents"
    ["slskd-shared"]="Soulseek shared files"
    ["immich/upload"]="Immich user photo uploads"
    ["immich/library"]="Immich processed photo library"
    ["seafile"]="Seafile file sync & share data"
    ["kopia/repository"]="Kopia central backup repository"
)

declare -A CACHE_DIRS=(
    ["transmission-incomplete"]="Transmission incomplete downloads"
    ["slskd-incomplete"]="Soulseek downloads in progress"
    ["immich/thumbs"]="Immich photo thumbnails"
    ["kopia/cache"]="Kopia backup cache"
    ["rustypaste"]="Rustypaste pastebin uploads"
)

# Functions
log_info() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️${NC}  $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

check_drive() {
    local drive=$1
    if [ ! -d "$drive" ]; then
        log_error "Drive $drive not found!"
        echo "   Please mount the drive before running this script"
        return 1
    fi
    local size=$(df -h "$drive" | tail -1 | awk '{print $2}')
    log_info "Drive detected: $drive ($size)"
    return 0
}

create_directories() {
    local base_path=$1
    local -n dirs=$2
    local label=$3

    echo ""
    echo "📁 Creating directories on $base_path ($label)..."

    for dir in "${!dirs[@]}"; do
        local full_path="$base_path/$dir"
        if [ -d "$full_path" ]; then
            log_warn "Already exists: $dir"
        else
            sudo mkdir -p "$full_path"
            log_info "Created: $dir"
        fi
    done
}

verify_directories() {
    local base_path=$1
    local -n dirs=$2
    local missing=0

    for dir in "${!dirs[@]}"; do
        if [ ! -d "$base_path/$dir" ]; then
            log_error "Missing: $base_path/$dir"
            ((missing++))
        fi
    done

    return $missing
}

set_permissions() {
    echo ""
    echo "🔐 Setting ownership to $PUID:$PGID..."

    sudo chown -R "$PUID:$PGID" "$MAIN_DRIVE"
    log_info "Permissions set on $MAIN_DRIVE"

    sudo chown -R "$PUID:$PGID" "$CACHE_DRIVE"
    log_info "Permissions set on $CACHE_DRIVE"
}

print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🥔 PotatoStack Light - Directory Structure"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 $MAIN_DRIVE (Main Storage):"
    for dir in "${!MAIN_DIRS[@]}"; do
        printf "   ├── %-30s # %s\n" "$dir" "${MAIN_DIRS[$dir]}"
    done

    echo ""
    echo "⚡ $CACHE_DRIVE (Cache Storage):"
    for dir in "${!CACHE_DIRS[@]}"; do
        printf "   ├── %-30s # %s\n" "$dir" "${CACHE_DIRS[$dir]}"
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Ready to start: docker compose up -d"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
    echo "🥔 PotatoStack Light - Setting up directories..."
    echo ""

    # Check drives
    check_drive "$MAIN_DRIVE" || exit 1
    check_drive "$CACHE_DRIVE" || exit 1

    # Create directories
    create_directories "$MAIN_DRIVE" MAIN_DIRS "Main Storage"
    create_directories "$CACHE_DRIVE" CACHE_DIRS "Cache Storage"

    # Verify all directories were created
    echo ""
    echo "🔍 Verifying directory structure..."
    local failed=0
    verify_directories "$MAIN_DRIVE" MAIN_DIRS || ((failed+=$?))
    verify_directories "$CACHE_DRIVE" CACHE_DIRS || ((failed+=$?))

    if [ $failed -gt 0 ]; then
        log_error "$failed directories missing!"
        exit 1
    fi
    log_info "All directories verified"

    # Set permissions
    set_permissions

    # Print summary
    print_summary
}

main "$@"
