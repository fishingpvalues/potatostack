#!/bin/bash
################################################################################
# PotatoStack Complete Test Suite
# Orchestrates the full testing workflow:
#   1. Setup test drives
#   2. Validate docker-compose
#   3. Launch the stack
#   4. Wait for services to start
#   5. Run health checks
#   6. Optional: Cleanup
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env.test"

# Parse arguments
CLEANUP=false
SKIP_SETUP=false
PROFILES=""
WAIT_TIME=120

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        --profile)
            PROFILES="$2"
            shift 2
            ;;
        --wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --cleanup           Stop and remove all containers after tests"
            echo "  --skip-setup        Skip drive setup (assumes already done)"
            echo "  --profile PROFILES  Start with specific profiles (e.g., 'apps,heavy')"
            echo "  --wait SECONDS      Wait time for services to start (default: 120)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Determine docker-compose command
if command -v docker compose &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║          ${GREEN}PotatoStack Complete Test Suite${BLUE}               ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Configuration summary
echo -e "${CYAN}Test Configuration:${NC}"
echo -e "  Project root: ${PROJECT_ROOT}"
echo -e "  Environment: ${ENV_FILE}"
echo -e "  Cleanup after: ${CLEANUP}"
echo -e "  Profiles: ${PROFILES:-none (core services only)}"
echo -e "  Wait time: ${WAIT_TIME}s"
echo

# Step 1: Setup test drives
if [ "$SKIP_SETUP" = false ]; then
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Step 1/5: Setting up test drives${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"

    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Not running as root. Symbolic links will not be created.${NC}"
        echo -e "${YELLOW}Creating test directories without symbolic links...${NC}"
        bash "${SCRIPT_DIR}/setup-test-drives.sh" || {
            echo -e "${RED}Failed to setup test drives${NC}"
            exit 1
        }
    else
        sudo bash "${SCRIPT_DIR}/setup-test-drives.sh" || {
            echo -e "${RED}Failed to setup test drives${NC}"
            exit 1
        }
    fi

    echo
    sleep 2
else
    echo -e "${CYAN}Skipping drive setup (--skip-setup specified)${NC}"
    echo
fi

# Step 2: Validate docker-compose
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Step 2/5: Validating docker-compose configuration${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"

bash "${SCRIPT_DIR}/validate-compose.sh" || {
    echo -e "${RED}Validation failed${NC}"
    exit 1
}

echo
sleep 2

# Step 3: Launch the stack
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Step 3/5: Launching Docker Compose stack${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"

cd "${PROJECT_ROOT}"

# Build docker-compose command (using test override for volume paths)
COMPOSE_CMD="${DOCKER_COMPOSE} -f docker-compose.yml -f docker-compose.test.override.yml --env-file ${ENV_FILE}"
if [ -n "$PROFILES" ]; then
    # Convert comma-separated profiles to --profile flags
    IFS=',' read -ra PROFILE_ARRAY <<< "$PROFILES"
    for profile in "${PROFILE_ARRAY[@]}"; do
        COMPOSE_CMD="${COMPOSE_CMD} --profile ${profile}"
    done
fi

echo -e "${CYAN}Pulling latest images...${NC}"
$COMPOSE_CMD pull --quiet 2>&1 | grep -v "Pulling" || true

echo -e "${CYAN}Starting services...${NC}"
$COMPOSE_CMD up -d 2>&1 | tail -20

echo
sleep 2

# Step 4: Wait for services to start
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Step 4/5: Waiting for services to start (${WAIT_TIME}s)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"

echo -e "${CYAN}Containers starting...${NC}"
for ((i=1; i<=WAIT_TIME; i++)); do
    printf "\r${CYAN}Elapsed: %3d/%d seconds${NC}" $i $WAIT_TIME
    sleep 1

    # Show progress at intervals
    if [ $((i % 30)) -eq 0 ]; then
        echo
        RUNNING=$($COMPOSE_CMD ps --filter "status=running" --format "{{.Name}}" | wc -l)
        echo -e "${GREEN}Running containers: ${RUNNING}${NC}"
    fi
done
echo

echo -e "${CYAN}Container status:${NC}"
$COMPOSE_CMD ps --format table

echo
sleep 2

# Step 5: Health checks
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Step 5/5: Running health checks${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"

bash "${SCRIPT_DIR}/check-health.sh"
HEALTH_STATUS=$?

echo

# Cleanup if requested
if [ "$CLEANUP" = true ]; then
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Cleanup: Stopping and removing containers${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"

    $COMPOSE_CMD down -v

    echo -e "${GREEN}✓ Cleanup complete${NC}"
    echo
fi

# Final summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   ${CYAN}Test Summary${BLUE}                          ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"

if [ $HEALTH_STATUS -eq 0 ]; then
    echo -e "${BLUE}║  ${GREEN}✓ All tests passed!${BLUE}                                   ║${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}║  ${CYAN}The PotatoStack is fully operational.${BLUE}                 ║${NC}"
else
    echo -e "${BLUE}║  ${RED}✗ Some tests failed${BLUE}                                   ║${NC}"
    echo -e "${BLUE}║                                                            ║${NC}"
    echo -e "${BLUE}║  ${YELLOW}Review the health check output above.${BLUE}                ║${NC}"
fi

echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Access information
if [ "$CLEANUP" = false ]; then
    HOST_ADDR=$(grep "^HOST_ADDR=" "${ENV_FILE}" | cut -d= -f2)
    HOST_ADDR=${HOST_ADDR:-127.0.0.1}

    echo -e "${CYAN}Service Access URLs:${NC}"
    echo -e "  Homepage:        ${GREEN}http://${HOST_ADDR}:3003${NC}"
    echo -e "  Grafana:         ${GREEN}http://${HOST_ADDR}:3000${NC}"
    echo -e "  Prometheus:      ${GREEN}http://${HOST_ADDR}:9090${NC}"
    echo -e "  Portainer:       ${GREEN}http://${HOST_ADDR}:9000${NC}"
    echo -e "  Nginx PM:        ${GREEN}http://${HOST_ADDR}:81${NC}"
    echo -e "  qBittorrent:     ${GREEN}http://${HOST_ADDR}:8080${NC}"
    echo -e "  Nextcloud:       ${GREEN}http://${HOST_ADDR}:8082${NC}"
    echo -e "  Dozzle (Logs):   ${GREEN}http://${HOST_ADDR}:8083${NC}"
    echo
    echo -e "${CYAN}Useful commands:${NC}"
    echo -e "  View logs:       ${YELLOW}docker compose -f docker-compose.yml -f docker-compose.test.override.yml --env-file ${ENV_FILE} logs -f [service]${NC}"
    echo -e "  Stop stack:      ${YELLOW}docker compose -f docker-compose.yml -f docker-compose.test.override.yml --env-file ${ENV_FILE} down${NC}"
    echo -e "  Restart service: ${YELLOW}docker compose -f docker-compose.yml -f docker-compose.test.override.yml --env-file ${ENV_FILE} restart [service]${NC}"
    echo -e "  Check status:    ${YELLOW}docker compose -f docker-compose.yml -f docker-compose.test.override.yml --env-file ${ENV_FILE} ps${NC}"
    echo
fi

exit $HEALTH_STATUS
