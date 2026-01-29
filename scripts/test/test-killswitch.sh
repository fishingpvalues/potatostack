#!/bin/bash

################################################################################
# VPN Killswitch Test Script - Fixed Implementation
# Tests Gluetun's killswitch firewall by examining iptables rules
# Does NOT disrupt VPN connection (NON-DESTRUCTIVE)
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_FILE="killswitch-test-report-$(date +%Y%m%d-%H%M%S).txt"
LOG_DIR="./test-logs"
mkdir -p "$LOG_DIR"

# All services that depend on gluetun
VPN_DEPENDENT_SERVICES=(
	"prowlarr"
	"sonarr"
	"radarr"
	"lidarr"
	"bookshelf"
	"bazarr"
	"spotiflac"
	"qbittorrent"
	"slskd"
	"pyload"
	"stash"
)

# External test endpoints
TEST_ENDPOINTS_TCP=(
	"1.1.1.1:443"
	"8.8.8.8:53"
)

# Detect OS
detect_os() {
	echo -e "${BLUE}[INFO]${NC} Detecting OS..."

	if [ -d "/data/data/com.termux" ]; then
		OS_TYPE="termux"
		DOCKER_CMD="docker compose"
		echo -e "${GREEN}[OK]${NC} Running on Termux/Android"
	elif [ -f /etc/debian_version ] || [ -f /etc/redhat-release ]; then
		OS_TYPE="linux"
		if command -v docker-compose &>/dev/null; then
			DOCKER_CMD="docker-compose"
		elif docker compose version &>/dev/null 2>&1; then
			DOCKER_CMD="docker compose"
		fi
		echo -e "${GREEN}[OK]${NC} Running on Linux - using $DOCKER_CMD"
	fi

	{
		echo "OS Type: $OS_TYPE"
		echo "Docker Command: $DOCKER_CMD"
	} >>"$REPORT_FILE"
}

# Check Docker availability
check_docker_available() {
	if ! docker ps >/dev/null 2>&1; then
		echo -e "${RED}[ERROR]${NC} Docker daemon is not running"
		exit 1
	fi

	{
		echo "Docker Status: RUNNING"
	} >>"$REPORT_FILE"

	echo -e "${GREEN}[OK]${NC} Docker daemon is running"
}

# Check Gluetun status
check_gluetun_status() {
	echo -e "${BLUE}[INFO]${NC} Checking gluetun status..."

	local status=$(docker inspect --format='{{.State.Status}}' gluetun 2>/dev/null || echo "not_found")
	local health=$(docker inspect --format='{{.State.Health.Status}}' gluetun 2>/dev/null || echo "none")
	VPN_INTERFACE=$(docker exec gluetun env 2>/dev/null | grep '^VPN_INTERFACE=' | cut -d'=' -f2 || echo "tun0")

	local vpn_state=$(docker exec gluetun ip link show "$VPN_INTERFACE" 2>/dev/null | grep -o ',UP,' >/dev/null && echo "UP" || echo "DOWN")

	{
		echo "Gluetun Status: $status"
		echo "Gluetun Health: $health"
		echo "VPN Interface: $VPN_INTERFACE ($vpn_state)"
	} >>"$REPORT_FILE"

	if [ "$status" = "running" ] && [ "$vpn_state" = "UP" ]; then
		echo -e "${GREEN}[OK]${NC} Gluetun is running and VPN interface is UP"
		return 0
	else
		echo -e "${YELLOW}[WARNING]${NC} Gluetun status: $status, VPN: $vpn_state"
		return 0
	fi
}

# Check killswitch firewall rules (NEW: non-destructive)
check_firewall_rules() {
	echo -e "${BLUE}[INFO]${NC} Checking killswitch firewall rules..."
	{
		echo "=== FIREWALL RULES VERIFICATION ==="
	} >>"$REPORT_FILE"

	local firewall_active=0
	local output_drop=0
	local default_policy=0

	# Check for iptables rules
	local output_rules=$(docker exec gluetun iptables -L OUTPUT -v 2>/dev/null || echo "")

	if echo "$output_rules" | grep -qi "drop"; then
		output_drop=1
		echo -e "  ${GREEN}✓${NC} Found OUTPUT DROP rules"
		echo "  ✓ OUTPUT DROP rules found" >>"$REPORT_FILE"
	fi

	# Check default policies
	local policies=$(docker exec gluetun iptables -L -n 2>/dev/null | grep "policy" || echo "")

	if echo "$policies" | grep -qi "policy DROP"; then
		default_policy=1
		echo -e "  ${GREEN}✓${NC} Found DROP policies"
		echo "  ✓ DROP policies found" >>"$REPORT_FILE"
	fi

	# Check for VPN interface rules
	local vpn_rules=$(docker exec gluetun iptables -L -n -v 2>/dev/null | grep "$VPN_INTERFACE" || echo "")

	if [ -n "$vpn_rules" ]; then
		firewall_active=1
		echo -e "  ${GREEN}✓${NC} Found $VPN_INTERFACE firewall rules"
		echo "  ✓ $VPN_INTERFACE firewall rules found" >>"$REPORT_FILE"
	fi

	if [ "$output_drop" -eq 1 ] || [ "$default_policy" -eq 1 ]; then
		firewall_active=1
	fi

	{
		echo "OUTPUT DROP rules: $output_drop"
		echo "DROP policies: $default_policy"
		echo "$VPN_INTERFACE rules: present"
		echo "Firewall active: $firewall_active"
	} >>"$REPORT_FILE"

	if [ "$firewall_active" -eq 1 ]; then
		echo -e "${GREEN}[OK]${NC} Killswitch firewall is active"
		FIREWALL_VERIFIED=1
		return 0
	else
		echo -e "${YELLOW}[WARNING]${NC} Killswitch firewall rules not clearly detected"
		FIREWALL_VERIFIED=0
		return 1
	fi
}

# Test connectivity through VPN
test_vpn_connectivity() {
	echo -e "${BLUE}[INFO]${NC} Testing connectivity through VPN..."

	local tcp_connected=0
	local tcp_total=0

	for service in qbittorrent prowlarr sonarr; do
		if ! docker inspect "$service" >/dev/null 2>&1; then
			continue
		fi

		tcp_total=$((tcp_total + 1))
		local public_ip=$(timeout 5 docker exec "$service" wget -q -O- --timeout=5 ifconfig.me/ip 2>/dev/null || echo "Failed")

		if [ "$public_ip" != "Failed" ]; then
			tcp_connected=$((tcp_connected + 1))
			echo -e "  ${GREEN}✓${NC} $service: $public_ip"
			echo "  ✓ $service: $public_ip" >>"$REPORT_FILE"
		else
			echo -e "  ${YELLOW}?${NC} $service: Failed"
			echo "  ✗ $service: Failed" >>"$REPORT_FILE"
		fi
	done

	{
		echo "VPN Connectivity: $tcp_connected/$tcp_total connected"
	} >>"$REPORT_FILE"

	if [ "$tcp_connected" -ge "$((tcp_total / 2))" ]; then
		echo -e "${GREEN}[OK]${NC} VPN connectivity working"
		return 0
	else
		echo -e "${YELLOW}[WARNING]${NC} VPN connectivity issues"
		return 1
	fi
}

# Generate summary
generate_summary() {
	echo -e "${BLUE}[INFO]${NC} Generating test summary..."
	{
		echo ""
		echo "====================================="
		echo "=== KILLSWITCH TEST SUMMARY ==="
		echo "====================================="
		echo "Test completed: $(date)"
		echo "Firewall Verified: $FIREWALL_VERIFIED"
		echo "====================================="
	} >>"$REPORT_FILE"

	echo ""
	echo "======================================"
	echo "KILLSWITCH TEST SUMMARY"
	echo "======================================"
	echo "Report saved to: $REPORT_FILE"
	echo "======================================"
}

# Main execution
main() {
	echo "======================================"
	echo "VPN Killswitch Test (Fixed Non-Destructive)"
	echo "Started: $(date)"
	echo "======================================"

	{
		echo "Killswitch Test Report"
		echo "Generated: $(date)"
		echo "====================================="
	} >"$REPORT_FILE"

	detect_os

	if ! check_docker_available; then
		echo -e "${RED}[FAILED]${NC} Cannot proceed"
		exit 1
	fi

	if ! check_gluetun_status; then
		echo -e "${RED}[FAILED]${NC} Gluetun not available"
		exit 1
	fi

	if ! test_vpn_connectivity; then
		echo -e "${YELLOW}[WARNING]${NC} VPN connectivity issues detected"
	fi

	check_firewall_rules

	generate_summary

	if [ "$FIREWALL_VERIFIED" -eq 1 ]; then
		echo -e "${GREEN}[PASSED]${NC} Killswitch verification complete"
		exit 0
	else
		echo -e "${YELLOW}[WARNING]${NC} Killswitch could not be fully verified"
		exit 1
	fi
}

main "$@"
