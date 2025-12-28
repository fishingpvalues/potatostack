#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# PotatoStack Runtime Tests - Actually runs containers and tests health
# For Android/Termux with proot
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
CLEANUP_ON_EXIT=true

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}PotatoStack Runtime Tests${NC}"
echo -e "${BLUE}Actual Container Healthchecks${NC}"
echo -e "${BLUE}================================${NC}\n"

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

cleanup() {
    if [ "$CLEANUP_ON_EXIT" = true ]; then
        echo -e "\n${YELLOW}Cleaning up test containers...${NC}"
        proot -0 docker compose -f ../docker-compose.yml down -v --remove-orphans 2>/dev/null || true
        echo -e "${GREEN}Cleanup complete${NC}"
    fi
}

trap cleanup EXIT

# Test 1: Docker daemon running
echo -e "\n${YELLOW}[1] Docker Daemon Check${NC}"
if proot -0 docker info &>/dev/null; then
    test_result 0 "Docker daemon is running"
else
    test_result 1 "Docker daemon not running (start with: dockerd)"
    exit 1
fi

# Test 2: Start core databases
echo -e "\n${YELLOW}[2] Starting Core Databases${NC}"
cd ..
echo -e "${CYAN}Starting postgres, mongo, redis-cache...${NC}"
if proot -0 docker compose up -d postgres mongo redis-cache 2>&1 | grep -q "Started\|Running"; then
    test_result 0 "Core databases started"
    sleep 5
else
    test_result 1 "Failed to start databases"
fi

# Test 3: PostgreSQL healthcheck
echo -e "\n${YELLOW}[3] PostgreSQL Healthcheck${NC}"
sleep 10  # Wait for postgres to initialize
POSTGRES_HEALTH=$(proot -0 docker inspect postgres --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")
if [ "$POSTGRES_HEALTH" = "healthy" ]; then
    test_result 0 "PostgreSQL is healthy"
elif proot -0 docker exec postgres pg_isready -U postgres &>/dev/null; then
    test_result 0 "PostgreSQL responding (no healthcheck defined)"
else
    test_result 1 "PostgreSQL not healthy (status: $POSTGRES_HEALTH)"
fi

# Test 4: PostgreSQL SOTA settings verification
echo -e "\n${YELLOW}[4] PostgreSQL SOTA Settings (Runtime)${NC}"
SHARED_BUFFERS=$(proot -0 docker exec postgres psql -U postgres -t -c "SHOW shared_buffers;" 2>/dev/null | xargs)
if echo "$SHARED_BUFFERS" | grep -q "1GB"; then
    test_result 0 "PostgreSQL shared_buffers = 1GB (SOTA)"
else
    test_result 1 "PostgreSQL shared_buffers = $SHARED_BUFFERS (expected 1GB)"
fi

# Test 5: PostgreSQL parallel workers
echo -e "\n${YELLOW}[5] PostgreSQL Parallel Workers${NC}"
MAX_WORKERS=$(proot -0 docker exec postgres psql -U postgres -t -c "SHOW max_parallel_workers;" 2>/dev/null | xargs)
if [ "$MAX_WORKERS" = "4" ]; then
    test_result 0 "PostgreSQL max_parallel_workers = 4 (SOTA)"
else
    test_result 1 "PostgreSQL max_parallel_workers = $MAX_WORKERS (expected 4)"
fi

# Test 6: MongoDB healthcheck
echo -e "\n${YELLOW}[6] MongoDB Healthcheck${NC}"
sleep 5
if proot -0 docker exec mongo mongosh --eval "db.adminCommand('ping')" --quiet &>/dev/null; then
    test_result 0 "MongoDB is healthy"
else
    test_result 1 "MongoDB not responding"
fi

# Test 7: MongoDB cache size verification
echo -e "\n${YELLOW}[7] MongoDB Cache Size (Runtime)${NC}"
MONGO_CACHE=$(proot -0 docker exec mongo mongosh --eval "db.serverStatus().wiredTiger.cache.maximum" --quiet 2>/dev/null | tail -1)
# Convert to GB (approximate)
CACHE_GB=$(echo "scale=1; $MONGO_CACHE / 1073741824" | bc 2>/dev/null || echo "unknown")
if echo "$CACHE_GB" | grep -q "1.5\|1.4\|1.6"; then
    test_result 0 "MongoDB cache = ${CACHE_GB}GB (SOTA target: 1.5GB)"
else
    test_result 1 "MongoDB cache = ${CACHE_GB}GB (expected ~1.5GB)"
fi

# Test 8: Redis healthcheck
echo -e "\n${YELLOW}[8] Redis Cache Healthcheck${NC}"
if proot -0 docker exec redis-cache redis-cli ping 2>/dev/null | grep -q "PONG"; then
    test_result 0 "Redis cache is healthy"
else
    test_result 1 "Redis cache not responding"
fi

# Test 9: Redis LFU policy verification
echo -e "\n${YELLOW}[9] Redis LFU Policy (Runtime)${NC}"
REDIS_POLICY=$(proot -0 docker exec redis-cache redis-cli config get maxmemory-policy 2>/dev/null | tail -1)
if [ "$REDIS_POLICY" = "allkeys-lfu" ]; then
    test_result 0 "Redis using LFU eviction policy (SOTA 2025)"
else
    test_result 1 "Redis policy = $REDIS_POLICY (expected allkeys-lfu)"
fi

# Test 10: Redis max memory
echo -e "\n${YELLOW}[10] Redis Max Memory${NC}"
REDIS_MAXMEM=$(proot -0 docker exec redis-cache redis-cli config get maxmemory 2>/dev/null | tail -1)
MAXMEM_MB=$((REDIS_MAXMEM / 1048576))
if [ "$MAXMEM_MB" -ge 500 ] && [ "$MAXMEM_MB" -le 520 ]; then
    test_result 0 "Redis maxmemory = ${MAXMEM_MB}MB"
else
    test_result 1 "Redis maxmemory = ${MAXMEM_MB}MB (expected ~512MB)"
fi

# Test 11: Start services with Redis integration
echo -e "\n${YELLOW}[11] Starting Redis-Integrated Services${NC}"
echo -e "${CYAN}Starting gitea and n8n...${NC}"
if proot -0 docker compose up -d gitea n8n 2>&1 | grep -q "Started\|Running"; then
    test_result 0 "Services started (gitea, n8n)"
    sleep 10
else
    test_result 1 "Failed to start services"
fi

# Test 12: Gitea Redis connection
echo -e "\n${YELLOW}[12] Gitea Redis Connection${NC}"
sleep 5
GITEA_LOGS=$(proot -0 docker logs gitea 2>&1 | tail -50)
if echo "$GITEA_LOGS" | grep -qi "redis" && ! echo "$GITEA_LOGS" | grep -qi "redis.*error\|redis.*fail"; then
    test_result 0 "Gitea connected to Redis (no errors in logs)"
else
    test_result 1 "Gitea may have Redis connection issues"
fi

# Test 13: N8n Redis connection
echo -e "\n${YELLOW}[13] N8n Redis Connection${NC}"
N8N_LOGS=$(proot -0 docker logs n8n 2>&1 | tail -50)
if echo "$N8N_LOGS" | grep -qi "redis" && ! echo "$N8N_LOGS" | grep -qi "redis.*error\|redis.*fail"; then
    test_result 0 "N8n connected to Redis (no errors in logs)"
else
    test_result 1 "N8n may have Redis connection issues"
fi

# Test 14: Network connectivity between services
echo -e "\n${YELLOW}[14] Service Network Connectivity${NC}"
if proot -0 docker exec gitea ping -c 1 redis-cache &>/dev/null; then
    test_result 0 "Gitea can reach redis-cache"
else
    test_result 1 "Network connectivity issue"
fi

# Test 15: Container resource usage
echo -e "\n${YELLOW}[15] Container Resource Usage${NC}"
POSTGRES_MEM=$(proot -0 docker stats postgres --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk '{print $1}' | sed 's/MiB//')
if [ ! -z "$POSTGRES_MEM" ]; then
    test_result 0 "PostgreSQL memory usage: ${POSTGRES_MEM}MiB"
else
    test_result 1 "Could not get resource stats"
fi

# Test 16: Running container count
echo -e "\n${YELLOW}[16] Running Container Count${NC}"
RUNNING_COUNT=$(proot -0 docker ps --filter "status=running" -q | wc -l)
echo -e "${CYAN}Currently running: $RUNNING_COUNT containers${NC}"
if [ "$RUNNING_COUNT" -ge 4 ]; then
    test_result 0 "$RUNNING_COUNT containers running"
else
    test_result 1 "Only $RUNNING_COUNT containers running (expected 4+)"
fi

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Runtime Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${BLUE}Total:  $((TESTS_PASSED + TESTS_FAILED))${NC}\n"

# Show running containers
echo -e "${CYAN}Running containers:${NC}"
proot -0 docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All runtime tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "\n${RED}Some runtime tests failed! ✗${NC}\n"
    exit 1
fi
