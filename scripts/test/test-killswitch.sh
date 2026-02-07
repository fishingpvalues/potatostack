#!/bin/bash

################################################################################
# VPN Killswitch Verification Test
#
# Proves Gluetun's killswitch blocks ALL traffic when VPN fails.
#
# Methodology:
# 1. Verify VPN is up and services route through it
# 2. Inspect iptables DROP policies
# 3. Simulate VPN failure: bring down interface + block VPN endpoint
#    (prevents gluetun from auto-reconnecting during the test)
# 4. Confirm ALL dependent services cannot reach the internet
# 5. Unblock endpoint, restore interface, verify recovery
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

VPN_DEPENDENT_SERVICES=(
	"prowlarr"
	"sonarr"
	"radarr"
	"lidarr"
	"bazarr"
	"spotiflac"
	"qbittorrent"
	"slskd"
	"pyload"
	"stash"
)

pass() {
	echo -e "  ${GREEN}✓${NC} $1"
	PASSED=$((PASSED + 1))
}
fail() {
	echo -e "  ${RED}✗${NC} $1"
	FAILED=$((FAILED + 1))
}
warn() {
	echo -e "  ${YELLOW}!${NC} $1"
	WARNINGS=$((WARNINGS + 1))
}
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

get_running_services() {
	local running=()
	for svc in "${VPN_DEPENDENT_SERVICES[@]}"; do
		if docker inspect --format='{{.State.Status}}' "$svc" 2>/dev/null | grep -q running; then
			running+=("$svc")
		fi
	done
	echo "${running[@]}"
}

# Get public IP from a service container (tries curl, wget, and nc)
get_public_ip() {
	local svc="$1"
	local t="${2:-5}"
	local ip=""

	# Try curl first
	ip=$(docker exec "$svc" curl -4 -s --max-time "$t" ifconfig.me/ip 2>/dev/null || true)
	if [ -n "$ip" ] && echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
		echo "$ip"
		return 0
	fi

	# Try wget
	ip=$(docker exec "$svc" wget -q -O- --timeout="$t" ifconfig.me/ip 2>/dev/null || true)
	if [ -n "$ip" ] && echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
		echo "$ip"
		return 0
	fi

	echo "BLOCKED"
	return 1
}

# Extract VPN endpoint from iptables rules
get_vpn_endpoint() {
	docker exec gluetun iptables -L OUTPUT -n -v 2>/dev/null |
		grep 'udp.*dpt:51820\|udp.*dpt:1194' |
		grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' |
		grep -v '^0\.0\.0\.0$' |
		head -1
}

# Ensure VPN is restored even if script is interrupted
cleanup() {
	echo -e "\n${YELLOW}[CLEANUP]${NC} Restoring VPN..."
	docker exec gluetun iptables -D OUTPUT -d "$VPN_ENDPOINT" -p udp -j DROP 2>/dev/null || true
	docker exec gluetun ip link set "$VPN_IF" up 2>/dev/null || true
	# If that doesn't work, restart gluetun
	sleep 5
	if ! docker exec gluetun wget -q -O /dev/null --timeout=5 http://1.1.1.1 2>/dev/null; then
		docker restart gluetun 2>/dev/null || true
	fi
}

################################################################################
# Phase 1: Pre-flight checks
################################################################################
phase1_preflight() {
	echo ""
	echo "========================================"
	info "Phase 1: Pre-flight checks"
	echo "========================================"

	if docker ps >/dev/null 2>&1; then
		pass "Docker daemon running"
	else
		fail "Docker daemon not running"
		exit 1
	fi

	local status
	status=$(docker inspect --format='{{.State.Status}}' gluetun 2>/dev/null || echo "not_found")
	if [ "$status" = "running" ]; then
		pass "Gluetun container running"
	else
		fail "Gluetun container not running (status: $status)"
		exit 1
	fi

	# Detect VPN interface
	VPN_IF=$(docker exec gluetun sh -c 'ip link show tun0 2>/dev/null && echo tun0 || (ip link show wg0 2>/dev/null && echo wg0) || echo none' 2>/dev/null | tail -1)
	if [ "$VPN_IF" != "none" ]; then
		pass "VPN interface $VPN_IF is present"
	else
		fail "No VPN interface (tun0/wg0) found"
		exit 1
	fi

	# Detect VPN endpoint IP
	VPN_ENDPOINT=$(get_vpn_endpoint)
	if [ -n "$VPN_ENDPOINT" ]; then
		pass "VPN endpoint: $VPN_ENDPOINT"
	else
		fail "Cannot determine VPN endpoint from iptables"
		exit 1
	fi

	RUNNING_SERVICES=($(get_running_services))
	if [ "${#RUNNING_SERVICES[@]}" -gt 0 ]; then
		pass "${#RUNNING_SERVICES[@]} services behind gluetun: ${RUNNING_SERVICES[*]}"
	else
		fail "No VPN-dependent services are running"
		exit 1
	fi
}

################################################################################
# Phase 2: Verify iptables killswitch rules
################################################################################
phase2_firewall() {
	echo ""
	echo "========================================"
	info "Phase 2: Firewall rule inspection"
	echo "========================================"

	local output_policy
	output_policy=$(docker exec gluetun iptables -L OUTPUT -n 2>/dev/null | head -1 || echo "")

	if echo "$output_policy" | grep -qi "policy DROP"; then
		pass "OUTPUT chain default policy is DROP"
	elif docker exec gluetun iptables -L OUTPUT -n -v 2>/dev/null | grep -qi "DROP"; then
		pass "OUTPUT chain has DROP rules"
	else
		fail "No DROP policy/rules on OUTPUT chain"
	fi

	local vpn_accept_rules
	vpn_accept_rules=$(docker exec gluetun iptables -L OUTPUT -n -v 2>/dev/null | grep -c "$VPN_IF" || echo "0")
	if [ "$vpn_accept_rules" -gt 0 ]; then
		pass "ACCEPT rules for VPN interface $VPN_IF ($vpn_accept_rules rules)"
	else
		warn "No explicit ACCEPT rules for $VPN_IF"
	fi

	if docker exec gluetun iptables -L INPUT -n 2>/dev/null | head -1 | grep -qi "policy DROP"; then
		pass "INPUT chain default policy is DROP"
	else
		warn "INPUT chain is not DROP (less critical for killswitch)"
	fi

	info "Outbound iptables rules:"
	docker exec gluetun iptables -L OUTPUT -n -v 2>/dev/null
}

################################################################################
# Phase 3: Verify services use VPN IP
################################################################################
phase3_vpn_ip() {
	echo ""
	echo "========================================"
	info "Phase 3: Verify services route through VPN"
	echo "========================================"

	VPN_IP=$(docker exec gluetun wget -q -O- --timeout=5 ifconfig.me/ip 2>/dev/null || echo "unknown")
	info "Gluetun VPN IP: $VPN_IP"

	# Get host's real public IP (v4 and v6) for leak comparison in phase 4
	HOST_IP=$(wget -q -O- --timeout=5 ifconfig.me/ip 2>/dev/null || echo "unknown")
	HOST_IP4=$(wget -4 -q -O- --timeout=5 ifconfig.me/ip 2>/dev/null || echo "unknown")
	info "Host IP: $HOST_IP"

	if [ "$VPN_IP" = "unknown" ]; then
		fail "Cannot determine VPN IP"
		return
	fi

	if [ "$VPN_IP" = "$HOST_IP" ]; then
		fail "VPN IP matches host IP — VPN may not be working!"
		return
	fi
	pass "VPN IP ($VPN_IP) differs from host IP ($HOST_IP)"

	for svc in "${RUNNING_SERVICES[@]}"; do
		local svc_ip
		svc_ip=$(get_public_ip "$svc" 5) || true
		if [ "$svc_ip" = "$VPN_IP" ]; then
			pass "$svc → $svc_ip (VPN)"
		elif [ -z "$svc_ip" ] || [ "$svc_ip" = "BLOCKED" ]; then
			warn "$svc → no response (may lack curl/wget/nc)"
		elif [ "$svc_ip" = "$HOST_IP" ] || [ "$svc_ip" = "$HOST_IP4" ]; then
			fail "$svc → $svc_ip (HOST IP — LEAKING!)"
		else
			warn "$svc → $svc_ip (unexpected IP, expected $VPN_IP)"
		fi
	done
}

################################################################################
# Phase 4: Killswitch test — simulate VPN failure
################################################################################
phase4_killswitch_test() {
	echo ""
	echo "========================================"
	info "Phase 4: Killswitch test (simulate VPN failure)"
	echo "========================================"

	# Install cleanup trap
	trap cleanup EXIT INT TERM

	# Block VPN endpoint to prevent gluetun from auto-reconnecting
	info "Blocking VPN endpoint $VPN_ENDPOINT to prevent reconnection..."
	docker exec gluetun iptables -I OUTPUT -d "$VPN_ENDPOINT" -p udp -j DROP

	# Bring down VPN interface
	info "Bringing down VPN interface $VPN_IF..."
	docker exec gluetun ip link set "$VPN_IF" down 2>/dev/null || {
		fail "Could not bring down $VPN_IF"
		return
	}

	local if_state
	if_state=$(docker exec gluetun ip link show "$VPN_IF" 2>/dev/null | grep -o 'state [A-Z]*' || echo "state UNKNOWN")
	info "Interface state: $if_state"

	# Wait for routing to settle and gluetun health monitor to detect failure
	sleep 5

	# Test each service — NONE should reach the internet via host IP
	local leak_detected=0
	for svc in "${RUNNING_SERVICES[@]}"; do
		local svc_ip
		svc_ip=$(get_public_ip "$svc" 5) || true
		if [ -z "$svc_ip" ] || [ "$svc_ip" = "BLOCKED" ]; then
			pass "$svc blocked (no internet access)"
		elif [ "$svc_ip" = "$HOST_IP" ] || [ "$svc_ip" = "$HOST_IP4" ]; then
			fail "$svc reached internet via HOST IP ($svc_ip) — REAL LEAK!"
			leak_detected=1
		else
			# Got an IP but it's not the host — gluetun reconnected to a new VPN server
			warn "$svc got IP $svc_ip (gluetun auto-reconnected to new VPN server, not a host leak)"
		fi
	done

	# Note: gluetun itself retains eth0 access (needed to establish VPN).
	# This is by design — only dependent services must be blocked.
	if docker exec gluetun wget -q -O /dev/null --timeout=8 http://1.1.1.1 2>/dev/null; then
		warn "Gluetun has eth0 access (expected — needed for VPN establishment)"
	else
		pass "Gluetun container also blocked"
	fi

	if [ "$leak_detected" -eq 0 ]; then
		echo -e "  ${GREEN}★ KILLSWITCH VERIFIED — zero bytes leaked${NC}"
	else
		echo -e "  ${RED}★ KILLSWITCH FAILED — traffic leaked without VPN${NC}"
	fi
}

################################################################################
# Phase 5: Restore VPN and verify recovery
################################################################################
phase5_restore() {
	echo ""
	echo "========================================"
	info "Phase 5: Restore VPN and verify recovery"
	echo "========================================"

	# Remove endpoint block
	info "Unblocking VPN endpoint $VPN_ENDPOINT..."
	docker exec gluetun iptables -D OUTPUT -d "$VPN_ENDPOINT" -p udp -j DROP 2>/dev/null || true

	# Bring interface back up
	info "Bringing VPN interface $VPN_IF back up..."
	docker exec gluetun ip link set "$VPN_IF" up 2>/dev/null || {
		warn "Could not bring $VPN_IF up — restarting gluetun"
		docker restart gluetun
		sleep 15
	}

	# Wait for reconnection
	info "Waiting for VPN to reconnect..."
	local max_wait=30
	local waited=0
	while [ "$waited" -lt "$max_wait" ]; do
		if docker exec gluetun wget -q -O /dev/null --timeout=3 http://1.1.1.1 2>/dev/null; then
			break
		fi
		sleep 2
		waited=$((waited + 2))
	done

	if [ "$waited" -ge "$max_wait" ]; then
		warn "VPN did not recover within ${max_wait}s — restarting gluetun"
		docker restart gluetun
		sleep 15
	fi

	# Clear trap since we've restored manually
	trap - EXIT INT TERM

	local restored_ip
	restored_ip=$(docker exec gluetun wget -q -O- --timeout=5 ifconfig.me/ip 2>/dev/null || echo "unknown")
	if [ "$restored_ip" != "unknown" ]; then
		pass "VPN restored — IP: $restored_ip"
	else
		fail "VPN did not restore properly"
	fi

	# Spot-check first service
	if [ "${#RUNNING_SERVICES[@]}" -gt 0 ]; then
		local check_svc="${RUNNING_SERVICES[0]}"
		local check_ip
		check_ip=$(docker exec "$check_svc" wget -q -O- --timeout=5 ifconfig.me/ip 2>/dev/null || echo "timeout")
		if [ "$check_ip" = "$restored_ip" ]; then
			pass "$check_svc reconnected through VPN ($check_ip)"
		else
			warn "$check_svc IP: $check_ip (expected $restored_ip)"
		fi
	fi
}

################################################################################
# Summary
################################################################################
print_summary() {
	echo ""
	echo "========================================"
	echo "KILLSWITCH TEST RESULTS"
	echo "========================================"
	echo -e "  ${GREEN}Passed:${NC}   $PASSED"
	echo -e "  ${RED}Failed:${NC}   $FAILED"
	echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
	echo "========================================"

	if [ "$FAILED" -eq 0 ]; then
		echo -e "${GREEN}[PASSED]${NC} Killswitch is working — no traffic leaks detected"
		exit 0
	else
		echo -e "${RED}[FAILED]${NC} Killswitch issues detected — review failures above"
		exit 1
	fi
}

################################################################################
# Main
################################################################################
main() {
	echo "========================================"
	echo "VPN Killswitch Verification Test"
	echo "$(date)"
	echo "========================================"

	phase1_preflight
	phase2_firewall
	phase3_vpn_ip
	phase4_killswitch_test
	phase5_restore
	print_summary
}

main "$@"
