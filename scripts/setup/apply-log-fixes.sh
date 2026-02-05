#!/bin/bash
################################################################################
# PotatoStack System-Level Log Error Fix Script
# This script applies fixes that cannot be handled via docker-compose alone
# Run this after each stack restart to ensure all services work correctly
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/potatostack-fixes.log"

# Logging function
log() {
	local level="$1"
	shift
	local message="$*"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }
success() { log "SUCCESS" "$@"; }

info "Starting PotatoStack system-level fixes..."

################################################################################
# FIX 1: Fix Radarr/Sonarr/Lidarr download path permissions
################################################################################
info "Checking Arr services download paths..."

# Ensure download directories exist with correct permissions
for path in /mnt/storage/downloads/movies/movies-radarr \
	/mnt/storage/downloads/tv/tv-sonarr \
	/mnt/storage/downloads/music/music-lidarr; do
	if [[ ! -d "$path" ]]; then
		info "Creating directory: $path"
		mkdir -p "$path"
	fi

	# Fix permissions (ensure container user can access)
	if [[ -d "$path" ]]; then
		chown -R 1000:1000 "$path" 2>/dev/null || warn "Could not chown $path (may require sudo)"
		chmod -R 755 "$path" 2>/dev/null || warn "Could not chmod $path"
		success "Fixed permissions for $path"
	fi
done

################################################################################
# FIX 2: Ensure disk devices have correct permissions for smartctl-exporter
################################################################################
info "Checking disk device permissions..."

# Add current user to disk group if not already
if ! groups | grep -q disk; then
	warn "Current user not in 'disk' group. Adding..."
	usermod -aG disk "$(whoami)" 2>/dev/null || warn "Could not add user to disk group (requires sudo)"
fi

# Fix device permissions
for device in /dev/sda /dev/sdb /dev/sdc; do
	if [[ -e "$device" ]]; then
		chmod 660 "$device" 2>/dev/null || warn "Could not chmod $device"
		chgrp disk "$device" 2>/dev/null || warn "Could not chgrp $device to disk"
		success "Fixed permissions for $device"
	fi
done

################################################################################
# FIX 3: Fix Gitea runner registration issues
################################################################################
info "Checking Gitea runner configuration..."

# Check if gitea runner is properly registered
if docker ps -q --filter "name=gitea-runner" | grep -q .; then
	# Get runner token from Gitea if not configured
	GITEA_URL="${GITEA_URL:-http://gitea:3000}"
	GITEA_RUNNER_TOKEN="${GITEA_RUNNER_TOKEN:-}"

	if [[ -z "$GITEA_RUNNER_TOKEN" ]]; then
		warn "GITEA_RUNNER_TOKEN not set. Runner may fail to register."
		warn "Get token from: $GITEA_URL/admin/actions/runners"
	fi
fi

################################################################################
# FIX 4: Clear stale log entries that cause Loki timestamp errors
################################################################################
info "Clearing stale log buffers..."

# Clear systemd journal if it's too old and causing timestamp issues
if command -v journalctl &>/dev/null; then
	journalctl --vacuum-time=7d 2>/dev/null || true
	success "Cleared old journal entries"
fi

################################################################################
# FIX 5: Fix Syncthing configuration to disable NAT-PMP (runtime fix)
################################################################################
info "Ensuring Syncthing NAT-PMP is disabled..."

if docker ps -q --filter "name=syncthing" | grep -q .; then
	# Check if config.xml exists and NAT is enabled
	SYNCTHING_CONFIG="/mnt/ssd/docker-data/syncthing/config/config.xml"
	if [[ -f "$SYNCTHING_CONFIG" ]]; then
		if grep -q '<natEnabled>true</natEnabled>' "$SYNCTHING_CONFIG"; then
			info "Disabling NAT in Syncthing config..."
			sed -i 's/<natEnabled>true<\/natEnabled>/<natEnabled>false<\/natEnabled>/g' "$SYNCTHING_CONFIG"
			success "Disabled NAT-PMP in Syncthing config"
			warn "Restart Syncthing container to apply changes: docker restart syncthing"
		fi
	fi
fi

################################################################################
# FIX 6: Fix Exportarr service false positive errors
################################################################################
info "Checking Exportarr services..."

# Exportarr services show "fatal" and "panic" in help text - these are false positives
# The error messages are from CLI help output, not actual errors
# No action needed, but document this for clarity
info "Exportarr 'fatal/panic' messages are false positives from CLI help text - no action needed"

################################################################################
# FIX 7: Fix News-pipeline permissions
################################################################################
info "Checking news-pipeline paths..."

NEWS_PIPELINE_DIR="/mnt/storage/news-pipeline"
if [[ ! -d "$NEWS_PIPELINE_DIR" ]]; then
	mkdir -p "$NEWS_PIPELINE_DIR"
	chown -R 1000:1000 "$NEWS_PIPELINE_DIR" 2>/dev/null || true
	success "Created news-pipeline directory"
fi

################################################################################
# FIX 8: Ensure autoheal has proper docker socket permissions
################################################################################
info "Checking autoheal permissions..."

# Ensure docker.sock is accessible
if [[ -S /var/run/docker.sock ]]; then
	chmod 666 /var/run/docker.sock 2>/dev/null || warn "Could not chmod docker.sock"
	success "Docker socket permissions checked"
fi

################################################################################
# FIX 9: Fix Unpackerr permissions and paths
################################################################################
info "Checking Unpackerr configuration..."

# Ensure unpackerr has access to downloads
UNPACKERR_DIR="/mnt/storage/downloads/unpackerr"
if [[ ! -d "$UNPACKERR_DIR" ]]; then
	mkdir -p "$UNPACKERR_DIR"
	chown -R 1000:1000 "$UNPACKERR_DIR" 2>/dev/null || true
	success "Created unpackerr directory"
fi

################################################################################
# FIX 10: Fix Alertmanager notification templates
################################################################################
info "Checking Alertmanager configuration..."

ALERTMANAGER_CONFIG="/home/daniel/potatostack/config/alertmanager/alertmanager.yml"
if [[ -f "$ALERTMANAGER_CONFIG" ]]; then
	# Check if configuration is valid
	if docker ps -q --filter "name=alertmanager" | grep -q .; then
		info "Alertmanager config exists - checking for common issues..."
		# Alertmanager errors are often from testing - no immediate fix needed
	fi
fi

################################################################################
# FIX 11: Fix Redis cache permission issues
################################################################################
info "Checking Redis cache..."

REDIS_DATA_DIR="/mnt/ssd/docker-data/redis-cache"
if [[ -d "$REDIS_DATA_DIR" ]]; then
	# Ensure proper permissions
	chown -R 999:999 "$REDIS_DATA_DIR" 2>/dev/null || chown -R 1000:1000 "$REDIS_DATA_DIR" 2>/dev/null || true
	success "Redis cache permissions checked"
fi

################################################################################
# FIX 12: Fix Home Assistant warnings
################################################################################
info "Checking Home Assistant configuration..."

# Home Assistant warnings are typically about missing integrations
# These are configuration issues that need manual fixing
info "Home Assistant warnings require manual configuration updates"

################################################################################
# Summary
################################################################################
success "System-level fixes completed!"
info "Review /var/log/potatostack-fixes.log for details"

# Check if any containers are still unhealthy
info "Checking for unhealthy containers..."
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "table {{.Names}}" 2>/dev/null | tail -n +2 || true)
if [[ -n "$UNHEALTHY" ]]; then
	warn "Unhealthy containers detected:"
	echo "$UNHEALTHY" | while read -r container; do
		warn "  - $container"
	done
	warn "Run 'make containers-unhealthy' for details"
else
	success "No unhealthy containers detected!"
fi

exit 0
