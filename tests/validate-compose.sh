#!/bin/bash
################################################################################
# Docker Compose Validation Script
# Validates the docker-compose.yml file and checks for common issues
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT}/.env.test"

ERRORS=0
WARNINGS=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  PotatoStack - Docker Compose Validation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check if docker-compose is installed
echo -e "${YELLOW}[1/6] Checking Docker Compose installation...${NC}"
if command -v docker compose &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    echo -e "${GREEN}✓ Docker Compose (plugin) found${NC}"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    echo -e "${GREEN}✓ docker-compose (standalone) found${NC}"
else
    echo -e "${RED}✗ Docker Compose not found!${NC}"
    echo "  Install: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if .env.test file exists
echo -e "${YELLOW}[2/6] Checking test environment file...${NC}"
if [ ! -f "${ENV_FILE}" ]; then
    echo -e "${RED}✗ .env.test file not found!${NC}"
    echo "  Expected: ${ENV_FILE}"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ .env.test file exists${NC}"
    # Count environment variables
    ENV_COUNT=$(grep -c "^[A-Z]" "${ENV_FILE}" || true)
    echo "  Variables defined: ${ENV_COUNT}"
fi

# Validate docker-compose.yml syntax
echo -e "${YELLOW}[3/6] Validating docker-compose.yml syntax...${NC}"
cd "${PROJECT_ROOT}"
export ENV_FILE_PATH="${ENV_FILE}"

if $DOCKER_COMPOSE --env-file "${ENV_FILE}" config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ docker-compose.yml syntax is valid${NC}"
else
    echo -e "${RED}✗ docker-compose.yml has syntax errors!${NC}"
    $DOCKER_COMPOSE --env-file "${ENV_FILE}" config 2>&1 | head -20
    ((ERRORS++))
    exit 1
fi

# Count services
SERVICE_COUNT=$($DOCKER_COMPOSE --env-file "${ENV_FILE}" config --services | wc -l)
echo "  Total services defined: ${SERVICE_COUNT}"

# Check for required directories
echo -e "${YELLOW}[4/6] Checking required configuration directories...${NC}"
REQUIRED_DIRS=(
    "config/prometheus"
    "config/grafana/provisioning"
    "config/loki"
    "config/promtail"
    "config/alertmanager"
    "config/diun"
    "config/homepage"
    "config/mariadb/init"
    "config/postgres/init"
    "config/blackbox"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "${PROJECT_ROOT}/${dir}" ]; then
        echo -e "${GREEN}  ✓ ${dir}${NC}"
    else
        echo -e "${YELLOW}  ⚠ ${dir} (missing - may cause issues)${NC}"
        ((WARNINGS++))
    fi
done

# Check for missing environment variables
echo -e "${YELLOW}[5/6] Checking for undefined environment variables...${NC}"
UNDEFINED_VARS=$($DOCKER_COMPOSE --env-file "${ENV_FILE}" config 2>&1 | grep -i "variable.*is not set" || true)
if [ -z "$UNDEFINED_VARS" ]; then
    echo -e "${GREEN}✓ All environment variables are defined${NC}"
else
    echo -e "${RED}✗ Undefined environment variables found:${NC}"
    echo "$UNDEFINED_VARS"
    ((ERRORS++))
fi

# Check volume mounts (informational only - test override uses local paths)
echo -e "${YELLOW}[6/6] Checking volume mount points...${NC}"
if [ -d "/mnt/seconddrive" ] || [ -L "/mnt/seconddrive" ]; then
    echo -e "${GREEN}  ✓ /mnt/seconddrive exists${NC}"
else
    echo -e "${CYAN}  ℹ /mnt/seconddrive not found (OK for testing - using override)${NC}"
fi

if [ -d "/mnt/cachehdd" ] || [ -L "/mnt/cachehdd" ]; then
    echo -e "${GREEN}  ✓ /mnt/cachehdd exists${NC}"
else
    echo -e "${CYAN}  ℹ /mnt/cachehdd not found (OK for testing - using override)${NC}"
fi

# Summary
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Validation successful!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ ${WARNINGS} warning(s) - review above${NC}"
    fi
else
    echo -e "${RED}✗ Validation failed with ${ERRORS} error(s)${NC}"
    exit 1
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Display service list
echo -e "${YELLOW}Services in stack:${NC}"
$DOCKER_COMPOSE --env-file "${ENV_FILE}" config --services | sort | column

echo
echo -e "${GREEN}Ready to launch stack!${NC}"
