#!/bin/bash
################################################################################
# PotatoStack Light - Directory Verification Script
# Verifies all required directories exist for docker-compose
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration based on environment
MODE="${1:-production}"

if [ "$MODE" = "test" ]; then
    MOCK_BASE="../mock-drives"
    MAIN_DRIVE="$MOCK_BASE/seconddrive"
    CACHE_DRIVE="$MOCK_BASE/cachehdd"
    COMPOSE_FILE="docker-compose.test.yml"
else
    MAIN_DRIVE="/mnt/seconddrive"
    CACHE_DRIVE="/mnt/cachehdd"
    COMPOSE_FILE="docker-compose.yml"
fi

# Required directories based on docker-compose volume mounts
declare -A REQUIRED_DIRS=(
    # Transmission
    ["$MAIN_DRIVE/downloads"]="Transmission - completed downloads"
    ["$CACHE_DRIVE/transmission-incomplete"]="Transmission - incomplete downloads"

    # slskd
    ["$MAIN_DRIVE/slskd-shared"]="slskd - shared files"
    ["$CACHE_DRIVE/slskd-incomplete"]="slskd - incomplete downloads"

    # Immich
    ["$MAIN_DRIVE/immich/upload"]="Immich - user uploads"
    ["$MAIN_DRIVE/immich/library"]="Immich - processed library"
    ["$CACHE_DRIVE/immich/thumbs"]="Immich - thumbnails cache"

    # Seafile
    ["$MAIN_DRIVE/seafile"]="Seafile - file sync & share"

    # Kopia
    ["$MAIN_DRIVE/kopia/repository"]="Kopia - backup repository"
    ["$CACHE_DRIVE/kopia/cache"]="Kopia - backup cache"

    # Rustypaste
    ["$CACHE_DRIVE/rustypaste"]="Rustypaste - pastebin uploads"
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

log_section() {
    echo -e "\n${BLUE}═══${NC} $1"
}

check_directory() {
    local dir=$1
    local desc=$2

    if [ -d "$dir" ]; then
        log_info "$dir"
        return 0
    else
        log_error "$dir (MISSING)"
        echo "   Expected for: $desc"
        return 1
    fi
}

verify_all_directories() {
    local missing=0

    for dir in "${!REQUIRED_DIRS[@]}"; do
        check_directory "$dir" "${REQUIRED_DIRS[$dir]}" || ((missing++))
    done

    return $missing
}

check_permissions() {
    local dir=$1
    if [ ! -r "$dir" ] || [ ! -w "$dir" ]; then
        return 1
    fi
    return 0
}

verify_permissions() {
    log_section "Checking Permissions"

    local issues=0

    for dir in "${!REQUIRED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            if check_permissions "$dir"; then
                log_info "Read/Write OK: $dir"
            else
                log_error "Permission issues: $dir"
                ((issues++))
            fi
        fi
    done

    return $issues
}

get_directory_sizes() {
    log_section "Directory Sizes"

    if [ -d "$MAIN_DRIVE" ]; then
        echo "Main Drive ($MAIN_DRIVE):"
        du -sh "$MAIN_DRIVE"/* 2>/dev/null | sort -h || echo "  (empty)"
    fi

    if [ -d "$CACHE_DRIVE" ]; then
        echo ""
        echo "Cache Drive ($CACHE_DRIVE):"
        du -sh "$CACHE_DRIVE"/* 2>/dev/null | sort -h || echo "  (empty)"
    fi
}

check_drive_space() {
    log_section "Drive Space"

    if [ -d "$MAIN_DRIVE" ]; then
        df -h "$MAIN_DRIVE" | tail -1 | awk '{printf "Main Drive:  %s used / %s total (%s used)\n", $3, $2, $5}'
    fi

    if [ -d "$CACHE_DRIVE" ]; then
        df -h "$CACHE_DRIVE" | tail -1 | awk '{printf "Cache Drive: %s used / %s total (%s used)\n", $3, $2, $5}'
    fi
}

# Main execution
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🥔 PotatoStack Light - Directory Verification"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Mode: $MODE"
    echo "Compose file: $COMPOSE_FILE"
    echo ""

    log_section "Checking Required Directories"

    local missing=0
    verify_all_directories || missing=$?

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $missing -eq 0 ]; then
        log_info "All ${#REQUIRED_DIRS[@]} required directories exist"
    else
        log_error "$missing of ${#REQUIRED_DIRS[@]} required directories are missing"
        echo ""
        echo "Run the setup script to create missing directories:"
        if [ "$MODE" = "test" ]; then
            echo "  ./setup-directories-mock.sh"
        else
            echo "  sudo ./setup-directories.sh"
        fi
        echo ""
        exit 1
    fi

    # Check permissions
    local perm_issues=0
    verify_permissions || perm_issues=$?

    if [ $perm_issues -gt 0 ]; then
        log_warn "$perm_issues permission issues found"
    fi

    # Show disk usage
    echo ""
    check_drive_space

    echo ""
    get_directory_sizes

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Directory structure verified - Ready for Docker Compose"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
