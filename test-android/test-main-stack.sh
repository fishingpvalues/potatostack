#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# PotatoStack Main Stack - Android/Termux Test Script (Unrooted)
# Tests main stack using proot for isolated testing
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
echo -e "${BLUE}PotatoStack Main Stack Test${NC}"
echo -e "${BLUE}Android/Termux Unrooted${NC}"
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

# Test 3: Check docker-compose.yml exists
echo -e "\n${YELLOW}[3] Configuration Files${NC}"
if [ -f "../docker-compose.yml" ]; then
    test_result 0 "docker-compose.yml exists"
else
    test_result 1 "docker-compose.yml not found"
    exit 1
fi

# Test 4: Validate docker-compose.yml syntax
echo -e "\n${YELLOW}[4] Docker Compose Validation${NC}"
cd ..
if docker compose config --quiet; then
    test_result 0 "docker-compose.yml is valid"
else
    test_result 1 "docker-compose.yml has syntax errors"
fi

# Test 5: Check database configurations
echo -e "\n${YELLOW}[5] Database Configuration Check${NC}"

# PostgreSQL
if grep -q "postgres:" docker-compose.yml && grep -q "shared_buffers=1GB" docker-compose.yml; then
    test_result 0 "PostgreSQL SOTA 2025 settings applied"
else
    test_result 1 "PostgreSQL missing SOTA settings"
fi

# MongoDB
if grep -q "mongo:" docker-compose.yml && grep -q "wiredTigerCacheSizeGB=1.5" docker-compose.yml; then
    test_result 0 "MongoDB SOTA 2025 settings applied"
else
    test_result 1 "MongoDB missing SOTA settings"
fi

# Redis Cache
if grep -q "redis-cache:" docker-compose.yml && grep -q "allkeys-lfu" docker-compose.yml; then
    test_result 0 "Redis cache with SOTA 2025 LFU policy"
else
    test_result 1 "Redis cache missing or not configured"
fi

# Test 6: Check for orphaned services
echo -e "\n${YELLOW}[6] Orphaned Services Check${NC}"
if ! grep -q "container_name: redis$" docker-compose.yml; then
    test_result 0 "No orphaned Redis service"
else
    test_result 1 "Orphaned Redis service found"
fi

# Test 7: Check Redis integration in services
echo -e "\n${YELLOW}[7] Redis Integration Check${NC}"

# N8n with Redis
if grep -A 20 "n8n:" docker-compose.yml | grep -q "QUEUE_BULL_REDIS_HOST"; then
    test_result 0 "N8n configured with Redis queue"
else
    test_result 1 "N8n missing Redis configuration"
fi

# Gitea with Redis
if grep -A 30 "gitea:" docker-compose.yml | grep -q "GITEA__cache__ADAPTER: redis"; then
    test_result 0 "Gitea configured with Redis cache"
else
    test_result 1 "Gitea missing Redis configuration"
fi

# Test 8: Count total services
echo -e "\n${YELLOW}[8] Service Count${NC}"
SERVICE_COUNT=$(grep -c "container_name:" docker-compose.yml || echo "0")
echo -e "Total services: ${BLUE}$SERVICE_COUNT${NC}"
if [ "$SERVICE_COUNT" -gt 80 ]; then
    test_result 0 "Service count is healthy ($SERVICE_COUNT services)"
else
    test_result 1 "Service count is low ($SERVICE_COUNT services)"
fi

# Test 9: Check memory limits
echo -e "\n${YELLOW}[9] Memory Limits Check${NC}"
if grep -q "memory: 1G" docker-compose.yml; then
    test_result 0 "Memory limits configured"
else
    test_result 1 "Memory limits missing"
fi

# Test 10: Check network configuration
echo -e "\n${YELLOW}[10] Network Configuration${NC}"
if grep -q "potatostack" docker-compose.yml; then
    test_result 0 "Custom network 'potatostack' configured"
else
    test_result 1 "Custom network not found"
fi

# Test 11: Proot environment test
echo -e "\n${YELLOW}[11] Proot Environment Test${NC}"
if command -v proot &> /dev/null; then
    if proot -0 id &> /dev/null; then
        test_result 0 "Proot working (can simulate root)"
    else
        test_result 1 "Proot not working properly"
    fi
else
    test_result 1 "Proot not installed"
fi

# Test 12: Docker socket access (via proot)
echo -e "\n${YELLOW}[12] Docker Accessibility${NC}"
if proot -0 docker ps &> /dev/null; then
    test_result 0 "Docker accessible via proot"
    RUNNING_CONTAINERS=$(proot -0 docker ps --format '{{.Names}}' | wc -l)
    echo -e "   Running containers: ${BLUE}$RUNNING_CONTAINERS${NC}"
else
    test_result 1 "Docker not accessible (may need daemon start)"
fi

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${BLUE}Total:  $((TESTS_PASSED + TESTS_FAILED))${NC}\n"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}\n"
    exit 1
fi
