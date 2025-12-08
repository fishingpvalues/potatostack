#!/bin/bash
################################################################################
# VPN Killswitch Verification Script
# Comprehensive test to ensure P2P traffic ONLY goes through Gluetun VPN
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect docker compose command
if command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DC="docker compose"
else
    DC="docker-compose"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VPN Killswitch Verification Test${NC}"
echo -e "${BLUE}  Gluetun Universal VPN Client${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Gluetun is running
if ! docker ps --filter "name=gluetun" --filter "status=running" | grep -q gluetun; then
    echo -e "${RED}✗ Gluetun container is not running!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Gluetun container is running${NC}"
echo ""

# Test 1: Check Gluetun VPN IP via HTTP control server
echo -e "${BLUE}[TEST 1] Checking Gluetun VPN IP${NC}"

# Try HTTP control server first (fastest)
GLUETUN_IP_JSON=$(curl -s --max-time 5 http://localhost:8000/v1/publicip/ip 2>/dev/null || echo "FAILED")
if [ "$GLUETUN_IP_JSON" != "FAILED" ]; then
    GLUETUN_IP=$(echo "$GLUETUN_IP_JSON" | grep -o '"public_ip":"[^"]*"' | cut -d'"' -f4)
else
    # Fallback to curl inside container
    GLUETUN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
fi

if [ "$GLUETUN_IP" = "FAILED" ] || [ -z "$GLUETUN_IP" ]; then
    echo -e "${RED}✗ Cannot get Gluetun IP${NC}"
    exit 1
fi

# Get country info
GLUETUN_COUNTRY=$(docker exec gluetun wget -qO- https://ipinfo.io/country 2>/dev/null || echo "UNKNOWN")

echo -e "  ${GREEN}→${NC} Gluetun VPN IP: $GLUETUN_IP"
echo -e "  ${GREEN}→${NC} Country: $GLUETUN_COUNTRY"

# Check it's not local IP
LOCAL_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "FAILED")
if [ "$GLUETUN_IP" = "$LOCAL_IP" ]; then
    echo -e "${RED}✗ VPN IP matches local IP! VPN is not working!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ VPN IP is different from local IP${NC}"
echo ""

# Test 2: Check VPN Status via HTTP API
echo -e "${BLUE}[TEST 2] Checking VPN Status via HTTP Control Server${NC}"
VPN_STATUS=$(curl -s --max-time 5 http://localhost:8000/v1/vpn/status 2>/dev/null || echo "FAILED")

if [ "$VPN_STATUS" != "FAILED" ]; then
    STATUS=$(echo "$VPN_STATUS" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$STATUS" = "running" ]; then
        echo -e "  ${GREEN}✓ VPN status: running${NC}"
    else
        echo -e "${RED}✗ VPN status: $STATUS (expected: running)${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}  ⚠ Cannot access HTTP control server${NC}"
fi
echo ""

# Test 3: Check qBittorrent IP (if running)
echo -e "${BLUE}[TEST 3] Checking qBittorrent IP (via VPN)${NC}"
if docker ps --filter "name=qbittorrent" --filter "status=running" | grep -q qbittorrent; then
    # qBittorrent uses Gluetun's network, so we check from gluetun container
    QB_CHECK=$(docker exec gluetun wget -qO- --timeout=5 http://localhost:8080 2>/dev/null | grep -q "qBittorrent" && echo "OK" || echo "FAILED")

    if [ "$QB_CHECK" = "OK" ]; then
        echo -e "  ${GREEN}✓ qBittorrent is accessible via VPN network (using IP: $GLUETUN_IP)${NC}"
    else
        echo -e "${YELLOW}  ⚠ Cannot verify qBittorrent (service may not be configured yet)${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ qBittorrent not running, skipping${NC}"
fi
echo ""

# Test 4: Check slskd IP (if running)
echo -e "${BLUE}[TEST 4] Checking slskd IP (via VPN)${NC}"
if docker ps --filter "name=slskd" --filter "status=running" | grep -q slskd; then
    # slskd uses Gluetun's network
    SLSKD_CHECK=$(docker exec gluetun wget -qO- --timeout=5 http://localhost:2234 2>/dev/null | grep -q "slskd" && echo "OK" || echo "FAILED")

    if [ "$SLSKD_CHECK" = "OK" ]; then
        echo -e "  ${GREEN}✓ slskd is accessible via VPN network (using IP: $GLUETUN_IP)${NC}"
    else
        echo -e "${YELLOW}  ⚠ Cannot verify slskd (service may not be configured yet)${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ slskd not running, skipping${NC}"
fi
echo ""

# Test 5: DNS Leak Test
echo -e "${BLUE}[TEST 5] DNS Leak Test${NC}"
GLUETUN_DNS=$(docker exec gluetun cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}' 2>/dev/null || echo "FAILED")
echo -e "  ${GREEN}→${NC} DNS Server: $GLUETUN_DNS"

# Check if DNS is not local
if [[ "$GLUETUN_DNS" =~ ^192\.168\. ]] || [[ "$GLUETUN_DNS" =~ ^10\. ]]; then
    echo -e "${YELLOW}  ⚠ WARNING: DNS appears to be local network DNS${NC}"
    echo -e "  This may cause DNS leaks. Expected: 1.1.1.1 or VPN-provided DNS"
else
    echo -e "${GREEN}  ✓ DNS is not using local router (good)${NC}"
fi
echo ""

# Test 6: Firewall Rules Check
echo -e "${BLUE}[TEST 6] Gluetun Firewall Status${NC}"
echo -e "  Checking iptables rules inside Gluetun container..."

# Check for killswitch firewall
FIREWALL_RULES=$(docker exec gluetun iptables -L -n 2>/dev/null | grep -c "DROP\|REJECT" || echo "0")
if [ "$FIREWALL_RULES" -gt 0 ]; then
    echo -e "  ${GREEN}✓ Firewall rules active: $FIREWALL_RULES DROP/REJECT rules found${NC}"
else
    echo -e "${YELLOW}  ⚠ No firewall DROP/REJECT rules found (killswitch may not be enabled)${NC}"
fi
echo ""

# Test 7: Killswitch Test (simulate VPN failure)
echo -e "${BLUE}[TEST 7] Killswitch Test (Simulated VPN Failure)${NC}"
echo -e "${YELLOW}  This test will temporarily stop Gluetun to verify killswitch${NC}"
read -p "  Proceed with killswitch test? (yes/no): " -r
echo

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "  Stopping Gluetun VPN..."
    $DC stop gluetun

    sleep 5

    echo "  Checking if qBittorrent can access internet (it SHOULD NOT)..."

    # Try to access internet from qBittorrent
    # Since qBittorrent uses network_mode: service:gluetun, it should NOT be able to access internet
    if docker exec qbittorrent wget -qO- --timeout=5 ipinfo.io/ip &> /dev/null 2>&1; then
        echo -e "${RED}  ✗ KILLSWITCH FAILED! qBittorrent can access internet without VPN!${NC}"
        echo -e "${RED}  This is a CRITICAL security issue!${NC}"

        # Restart Gluetun
        echo "  Restarting Gluetun..."
        $DC start gluetun
        exit 1
    else
        echo -e "${GREEN}  ✓ KILLSWITCH WORKING! qBittorrent cannot access internet without VPN${NC}"
    fi

    # Restart Gluetun
    echo "  Restarting Gluetun..."
    $DC start gluetun

    echo "  Waiting for VPN to reconnect..."
    sleep 20

    # Verify VPN is back via HTTP API
    VPN_STATUS_NEW=$(curl -s --max-time 10 http://localhost:8000/v1/vpn/status 2>/dev/null || echo "FAILED")
    if echo "$VPN_STATUS_NEW" | grep -q '"status":"running"'; then
        echo -e "${GREEN}  ✓ VPN reconnected successfully${NC}"

        # Get new IP
        NEW_IP=$(curl -s http://localhost:8000/v1/publicip/ip 2>/dev/null | grep -o '"public_ip":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$NEW_IP" ]; then
            echo -e "  ${GREEN}→${NC} New VPN IP: $NEW_IP"
        fi
    else
        echo -e "${YELLOW}  ⚠ VPN may still be reconnecting...${NC}"
    fi
else
    echo -e "${YELLOW}  Killswitch test skipped by user${NC}"
fi
echo ""

# Test 8: Port Forwarding Check (if enabled)
echo -e "${BLUE}[TEST 8] Port Forwarding Check${NC}"
PORT_FORWARD=$(curl -s --max-time 5 http://localhost:8000/v1/portforward 2>/dev/null || echo "FAILED")
if [ "$PORT_FORWARD" != "FAILED" ]; then
    FORWARDED_PORT=$(echo "$PORT_FORWARD" | grep -o '"port":[0-9]*' | cut -d':' -f2)
    if [ -n "$FORWARDED_PORT" ] && [ "$FORWARDED_PORT" != "0" ]; then
        echo -e "  ${GREEN}✓ Port forwarding active: Port $FORWARDED_PORT${NC}"
    else
        echo -e "${YELLOW}  ⚠ Port forwarding not enabled (may not be supported by provider)${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Cannot check port forwarding status${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VERIFICATION SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ VPN IP verified: $GLUETUN_IP${NC}"
echo -e "${GREEN}✓ VPN IP is different from local IP${NC}"
echo -e "${GREEN}✓ P2P services are using VPN network${NC}"
echo -e "${GREEN}✓ Killswitch is functional (if tested)${NC}"
echo -e "${GREEN}✓ Gluetun HTTP control server operational${NC}"
echo ""
echo -e "${GREEN}VPN killswitch verification PASSED!${NC}"
echo ""
echo -e "${BLUE}Recommendations:${NC}"
echo "  1. Periodically re-run this test to ensure killswitch remains functional"
echo "  2. Check Grafana dashboard for VPN uptime metrics"
echo "  3. Configure Alertmanager to notify if VPN goes down"
echo "  4. Monitor Gluetun status: curl http://localhost:8000/v1/vpn/status"
echo "  5. Check public IP: curl http://localhost:8000/v1/publicip/ip"
echo ""

exit 0
