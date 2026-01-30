#!/bin/bash
################################################################################
# Service Configuration Fixes
# Ensures Loki, Alertmanager and other services work in single-node mode
# Run at startup or after docker-compose changes
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/../../config" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

################################################################################
# Fix Loki Configuration for Single-Node Mode
################################################################################
fix_loki_config() {
	local LOKI_CONFIG="$CONFIG_DIR/loki/loki.yml"

	if [ ! -f "$LOKI_CONFIG" ]; then
		log_warn "Loki config not found at $LOKI_CONFIG"
		return 0
	fi

	log_info "Checking Loki configuration..."

	# Check if memberlist is properly configured
	if ! grep -q "instance_addr: 127.0.0.1" "$LOKI_CONFIG"; then
		log_info "Fixing Loki memberlist configuration for single-node mode..."

		# Backup original
		cp "$LOKI_CONFIG" "$LOKI_CONFIG.bak"

		# Add instance_addr if missing in ring section
		if grep -q "ring:" "$LOKI_CONFIG" && ! grep -q "instance_addr:" "$LOKI_CONFIG"; then
			sed -i '/ring:/a\    instance_addr: 127.0.0.1' "$LOKI_CONFIG"
		fi

		# Add memberlist section if missing
		if ! grep -q "^memberlist:" "$LOKI_CONFIG"; then
			cat >>"$LOKI_CONFIG" <<'EOF'

# Single-node mode - disable clustering
memberlist:
  join_members: []
  bind_addr: []
  abort_if_cluster_join_fails: false
EOF
		fi

		log_info "✓ Loki config fixed for single-node mode"
	else
		log_info "✓ Loki config already configured for single-node mode"
	fi
}

################################################################################
# Ensure Homarr Data Directory Exists with Proper Permissions
################################################################################
fix_homarr_permissions() {
	local HOMARR_DATA="/mnt/ssd/docker-data/homarr"
	local PUID="${PUID:-1000}"
	local PGID="${PGID:-1000}"

	log_info "Checking Homarr data directory..."

	if [ ! -d "$HOMARR_DATA" ]; then
		log_info "Creating Homarr data directory..."
		mkdir -p "$HOMARR_DATA"
	fi

	# Set ownership
	chown -R "$PUID:$PGID" "$HOMARR_DATA" 2>/dev/null || true
	chmod 755 "$HOMARR_DATA" 2>/dev/null || true

	log_info "✓ Homarr data directory ready at $HOMARR_DATA"
}

################################################################################
# Fix Grafana Data Directory Permissions
################################################################################
fix_grafana_permissions() {
	local GRAFANA_DATA="/mnt/ssd/docker-data/grafana"

	log_info "Checking Grafana data directory..."

	if [ ! -d "$GRAFANA_DATA" ]; then
		mkdir -p "$GRAFANA_DATA"
	fi

	# Grafana runs as UID 472
	chown -R 472:472 "$GRAFANA_DATA" 2>/dev/null || true

	log_info "✓ Grafana data directory ready"
}

################################################################################
# Fix Thanos Data Directories
################################################################################
fix_thanos_permissions() {
	local THANOS_BASE="/mnt/cachehdd/observability/thanos"

	log_info "Checking Thanos data directories..."

	mkdir -p "$THANOS_BASE/store" "$THANOS_BASE/compact"

	# Thanos runs as UID 1001
	chown -R 1001:1001 "$THANOS_BASE" 2>/dev/null || true

	log_info "✓ Thanos data directories ready"
}

################################################################################
# Validate Docker Compose Config
################################################################################
validate_compose() {
	log_info "Validating docker-compose.yml..."

	local COMPOSE_FILE="$SCRIPT_DIR/../../docker-compose.yml"

	if docker compose -f "$COMPOSE_FILE" config >/dev/null 2>&1; then
		log_info "✓ docker-compose.yml is valid"
	else
		log_error "docker-compose.yml validation failed"
		docker compose -f "$COMPOSE_FILE" config 2>&1 | head -20
		return 1
	fi
}

################################################################################
# Main
################################################################################
main() {
	echo "========================================"
	echo "Service Configuration Fixes"
	echo "========================================"
	echo ""

	fix_loki_config
	fix_homarr_permissions
	fix_grafana_permissions
	fix_thanos_permissions
	validate_compose

	echo ""
	echo "========================================"
	log_info "All configuration fixes applied"
	echo "========================================"
}

main "$@"
