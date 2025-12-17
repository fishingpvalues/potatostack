#!/bin/bash
################################################################################
# PotatoStack Light - Mock Directory Setup for Testing
# Creates directory structure in mock drives for testing
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MOCK_BASE="../mock-drives"
MAIN_DRIVE="$MOCK_BASE/seconddrive"
CACHE_DRIVE="$MOCK_BASE/cachehdd"

# Directory structure definitions (same as production)
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
            mkdir -p "$full_path"
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
    echo "🔐 Setting ownership to $(id -u):$(id -g)..."

    chown -R "$(id -u):$(id -g)" "$MOCK_BASE" 2>/dev/null || true
    log_info "Permissions set on $MOCK_BASE"
}

print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🥔 PotatoStack Light - Mock Directory Structure"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 $MAIN_DRIVE (Mock Main Storage):"
    for dir in "${!MAIN_DIRS[@]}"; do
        printf "   ├── %-30s # %s\n" "$dir" "${MAIN_DIRS[$dir]}"
    done

    echo ""
    echo "⚡ $CACHE_DRIVE (Mock Cache Storage):"
    for dir in "${!CACHE_DIRS[@]}"; do
        printf "   ├── %-30s # %s\n" "$dir" "${CACHE_DIRS[$dir]}"
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Ready to test: docker compose -f docker-compose.test.yml up -d"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
    echo "🥔 PotatoStack Light - Setting up MOCK directories for testing..."
    echo ""

    # Create mock base
    mkdir -p "$MOCK_BASE"
    log_info "Mock drives base: $MOCK_BASE"

    # Create directories
    create_directories "$MAIN_DRIVE" MAIN_DIRS "Mock Main Storage"
    create_directories "$CACHE_DRIVE" CACHE_DIRS "Mock Cache Storage"

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
