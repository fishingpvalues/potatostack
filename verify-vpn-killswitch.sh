#!/bin/bash
################################################################################
# VPN Killswitch Verification Script
# Tests that qBittorrent and slskd cannot leak your real IP
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       VPN Killswitch Verification Test            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0

# Test 1: Check Surfshark IP
echo -e "${BLUE}[1/5]${NC} Checking Surfshark container IP..."
SURFSHARK_IP=$(docker exec surfshark curl -s --max-time 10 ipinfo.io/ip 2>/dev/null)

if [ -z "$SURFSHARK_IP" ]; then
    echo -e "      ${RED}✗ Failed to get Surfshark IP${NC}"
    ((ERRORS++))
else
    echo -e "      Surfshark IP: ${GREEN}$SURFSHARK_IP${NC}"

    # Check if it's a VPN IP (not local)
    if [[ $SURFSHARK_IP == 192.168.* ]] || [[ $SURFSHARK_IP == 10.* ]] || [[ $SURFSHARK_IP == 172.16.* ]]; then
        echo -e "      ${RED}✗ WARNING: Surfshark showing local IP! VPN may not be connected.${NC}"
        ((ERRORS++))
    else
        echo -e "      ${GREEN}✓ VPN connected (external IP)${NC}"

        # Get location info
        LOCATION=$(docker exec surfshark curl -s --max-time 10 ipinfo.io/city 2>/dev/null)
        COUNTRY=$(docker exec surfshark curl -s --max-time 10 ipinfo.io/country 2>/dev/null)
        if [ -n "$LOCATION" ]; then
            echo -e "      Location: ${GREEN}$LOCATION, $COUNTRY${NC}"
        fi
    fi
fi

echo ""

# Test 2: Check qBittorrent killswitch
echo -e "${BLUE}[2/5]${NC} Testing qBittorrent killswitch..."
echo "      (qBittorrent should NOT be able to access internet directly)"

if docker exec qbittorrent curl -s --max-time 5 ipinfo.io/ip 2>/dev/null; then
    echo -e "      ${RED}✗ WARNING: qBittorrent can access internet directly!${NC}"
    echo -e "      ${RED}  This means the container has its own network access.${NC}"
    ((ERRORS++))
else
    echo -e "      ${GREEN}✓ qBittorrent network properly isolated${NC}"
    echo -e "      ${GREEN}  (Cannot access internet - this is correct)${NC}"
fi

echo ""

# Test 3: Check slskd killswitch
echo -e "${BLUE}[3/5]${NC} Testing slskd killswitch..."
echo "      (slskd should NOT be able to access internet directly)"

if docker exec slskd curl -s --max-time 5 ipinfo.io/ip 2>/dev/null; then
    echo -e "      ${RED}✗ WARNING: slskd can access internet directly!${NC}"
    echo -e "      ${RED}  This means the container has its own network access.${NC}"
    ((ERRORS++))
else
    echo -e "      ${GREEN}✓ slskd network properly isolated${NC}"
    echo -e "      ${GREEN}  (Cannot access internet - this is correct)${NC}"
fi

echo ""

# Test 4: Simulate VPN disconnect
echo -e "${BLUE}[4/5]${NC} Simulating VPN disconnect..."
echo "      Stopping Surfshark container..."
docker-compose stop surfshark >/dev/null 2>&1
sleep 3

echo "      Testing if qBittorrent lost connectivity..."
if docker logs qbittorrent 2>&1 | tail -20 | grep -iq "network\|connection\|error"; then
    echo -e "      ${GREEN}✓ qBittorrent detected network issue${NC}"
else
    echo -e "      ${YELLOW}⚠ Could not confirm qBittorrent network error (check logs manually)${NC}"
fi

# Try to access internet from qBittorrent (should fail)
if timeout 5 docker exec qbittorrent curl -s ipinfo.io/ip 2>/dev/null; then
    echo -e "      ${RED}🚨 CRITICAL: KILLSWITCH FAILED!${NC}"
    echo -e "      ${RED}  qBittorrent can access internet WITHOUT VPN!${NC}"
    echo -e "      ${RED}  Your real IP may be exposed!${NC}"
    ((ERRORS++))
else
    echo -e "      ${GREEN}✓ Killswitch working (no internet without VPN)${NC}"
fi

echo ""

# Test 5: Restart VPN and verify
echo -e "${BLUE}[5/5]${NC} Restarting VPN and verifying connection..."
docker-compose start surfshark >/dev/null 2>&1
echo "      Waiting for VPN to reconnect (10 seconds)..."
sleep 10

# Verify VPN back online
SURFSHARK_IP_AFTER=$(docker exec surfshark curl -s --max-time 10 ipinfo.io/ip 2>/dev/null)

if [ -z "$SURFSHARK_IP_AFTER" ]; then
    echo -e "      ${RED}✗ Failed to reconnect to VPN${NC}"
    ((ERRORS++))
else
    echo -e "      ${GREEN}✓ VPN reconnected: $SURFSHARK_IP_AFTER${NC}"

    if [[ $SURFSHARK_IP_AFTER == $SURFSHARK_IP ]]; then
        echo -e "      ${GREEN}  Same IP as before (consistent)${NC}"
    else
        echo -e "      ${YELLOW}  IP changed (normal for new connection)${NC}"
    fi
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   SUMMARY                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! VPN killswitch is working correctly.${NC}"
    echo ""
    echo -e "${GREEN}Your P2P traffic is protected:${NC}"
    echo "  • qBittorrent routes through VPN only"
    echo "  • slskd routes through VPN only"
    echo "  • No traffic leaks if VPN disconnects"
    echo ""
    exit 0
else
    echo -e "${RED}✗ $ERRORS issue(s) detected!${NC}"
    echo ""
    echo -e "${RED}Action required:${NC}"
    echo "  1. Check docker-compose.yml network_mode settings"
    echo "  2. Verify Surfshark container is running"
    echo "  3. Check Surfshark logs: docker-compose logs surfshark"
    echo "  4. Review VPN credentials in .env file"
    echo ""
    exit 1
fi
