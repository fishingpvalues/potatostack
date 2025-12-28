#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# PotatoStack Light Stack - Android/Termux Test Script (Unrooted)
# Tests light stack (2GB RAM optimized) using proot
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}PotatoStack Light Stack Test${NC}"
echo -e "${BLUE}Android/Termux Unrooted (2GB)${NC}"
echo -e "${BLUE}================================${NC}\n"

# Function to print test result
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Check if running in Termux
echo -e "\n${YELLOW}[1] Environment Check${NC}"
if [ -d "/data/data/com.termux" ]; then
    test_result 0 "Running in Termux"
else
    test_result 1 "Not running in Termux"
    exit 1
fi

# Test 2: Check required packages
echo -e "\n${YELLOW}[2] Required Packages${NC}"
REQUIRED_PKGS="docker docker-compose proot"
for pkg in $REQUIRED_PKGS; do
    if command -v $pkg &> /dev/null; then
        test_result 0 "$pkg installed"
    else
        test_result 1 "$pkg not installed (run: pkg install $pkg)"
    fi
done

# Test 3: Check light stack docker-compose.yml
echo -e "\n${YELLOW}[3] Light Stack Configuration${NC}"
if [ -f "../light/docker-compose.yml" ]; then
    test_result 0 "light/docker-compose.yml exists"
else
    test_result 1 "light/docker-compose.yml not found"
    exit 1
fi

# Test 4: Validate light stack docker-compose.yml
echo -e "\n${YELLOW}[4] Docker Compose Validation${NC}"
cd ../light
if docker compose config --quiet; then
    test_result 0 "docker-compose.yml is valid"
else
    test_result 1 "docker-compose.yml has syntax errors"
fi

# Test 5: Check memory limits (2GB optimized)
echo -e "\n${YELLOW}[5] Memory Optimization Check (2GB RAM)${NC}"
MAX_MEM=$(grep -oP "memory: \K\d+M" docker-compose.yml | sort -nr | head -1 | sed 's/M//')
if [ ! -z "$MAX_MEM" ] && [ "$MAX_MEM" -le 512 ]; then
    test_result 0 "Memory limits optimized for 2GB RAM (max: ${MAX_MEM}M)"
else
    test_result 1 "Memory limits may be too high for 2GB RAM"
fi

# Test 6: Count services (should be lean)
echo -e "\n${YELLOW}[6] Service Count (Lean Stack)${NC}"
SERVICE_COUNT=$(grep -c "container_name:" docker-compose.yml || echo "0")
echo -e "Total services: ${BLUE}$SERVICE_COUNT${NC}"
if [ "$SERVICE_COUNT" -le 20 ]; then
    test_result 0 "Service count is lean ($SERVICE_COUNT services)"
else
    test_result 1 "Too many services for light stack ($SERVICE_COUNT services)"
fi

# Test 7: Check essential services
echo -e "\n${YELLOW}[7] Essential Services Check${NC}"
ESSENTIAL_SERVICES="homepage gluetun syncthing kopia vaultwarden portainer"
for service in $ESSENTIAL_SERVICES; do
    if grep -q "container_name: $service" docker-compose.yml; then
        test_result 0 "Essential service '$service' present"
    else
        test_result 1 "Missing essential service '$service'"
    fi
done

# Test 8: Check for dual-disk setup
echo -e "\n${YELLOW}[8] Dual-Disk Configuration${NC}"
if grep -q "/mnt/storage" docker-compose.yml && grep -q "/mnt/cachehdd" docker-compose.yml; then
    test_result 0 "Dual-disk caching configured"
else
    test_result 1 "Dual-disk configuration missing"
fi

# Test 9: Check logging configuration (smaller logs for 2GB)
echo -e "\n${YELLOW}[9] Logging Configuration${NC}"
if grep -q "max-size: \"5m\"" docker-compose.yml; then
    test_result 0 "Lean logging configured (5MB max)"
else
    test_result 1 "Logging not optimized for low RAM"
fi

# Test 10: Check VPN killswitch (Gluetun)
echo -e "\n${YELLOW}[10] VPN Configuration${NC}"
if grep -q "gluetun" docker-compose.yml && grep -q "NET_ADMIN" docker-compose.yml; then
    test_result 0 "VPN with killswitch configured"
else
    test_result 1 "VPN configuration missing"
fi

# Test 11: Check Watchtower auto-updates
echo -e "\n${YELLOW}[11] Auto-Update Configuration${NC}"
if grep -q "watchtower" docker-compose.yml; then
    test_result 0 "Watchtower auto-updates configured"
else
    test_result 1 "Auto-updates not configured"
fi

# Test 12: Proot environment test
echo -e "\n${YELLOW}[12] Proot Environment Test${NC}"
if command -v proot &> /dev/null; then
    if proot -0 id &> /dev/null; then
        test_result 0 "Proot working (can simulate root)"
    else
        test_result 1 "Proot not working properly"
    fi
else
    test_result 1 "Proot not installed"
fi

# Test 13: Docker socket access (via proot)
echo -e "\n${YELLOW}[13] Docker Accessibility${NC}"
if proot -0 docker ps &> /dev/null; then
    test_result 0 "Docker accessible via proot"
    RUNNING_CONTAINERS=$(proot -0 docker ps --format '{{.Names}}' | wc -l)
    echo -e "   Running containers: ${BLUE}$RUNNING_CONTAINERS${NC}"
else
    test_result 1 "Docker not accessible (may need daemon start)"
fi

# Test 14: Check Homepage dashboard
echo -e "\n${YELLOW}[14] Dashboard Configuration${NC}"
if [ -d "../light/homepage-config" ]; then
    CONFIG_FILES=$(ls -1 ../light/homepage-config/*.yaml 2>/dev/null | wc -l)
    if [ "$CONFIG_FILES" -ge 3 ]; then
        test_result 0 "Homepage dashboard configured ($CONFIG_FILES config files)"
    else
        test_result 1 "Homepage dashboard incomplete"
    fi
else
    test_result 1 "Homepage config directory missing"
fi

# Test 15: Check resource reservations
echo -e "\n${YELLOW}[15] Resource Reservations${NC}"
if grep -q "reservations:" docker-compose.yml; then
    test_result 0 "Resource reservations configured"
else
    test_result 1 "Resource reservations missing"
fi

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${BLUE}Total:  $((TESTS_PASSED + TESTS_FAILED))${NC}\n"

# Calculate estimated RAM usage
echo -e "${BLUE}Estimated RAM Usage:${NC}"
TOTAL_MEM=$(grep -oP "memory: \K\d+M" docker-compose.yml | awk '{sum += $1} END {print sum}')
echo -e "Total limits: ${YELLOW}${TOTAL_MEM}M${NC} (Target: <1800M for 2GB system)\n"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}\n"
    exit 1
fi
