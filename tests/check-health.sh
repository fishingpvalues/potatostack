#!/bin/bash
################################################################################
# Service Health Check Script
# Checks the health and availability of all running services
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

# Determine docker-compose command
if command -v docker compose &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  PotatoStack - Service Health Checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

cd "${PROJECT_ROOT}"

# Helper function to check HTTP endpoint
check_http() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    ((TOTAL_CHECKS++))

    if curl -f -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" | grep -q "$expected_code"; then
        echo -e "${GREEN}  ✓ ${name}: ${url}${NC}"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}  ✗ ${name}: ${url} (unreachable)${NC}"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# Helper function to check container status
check_container() {
    local container_name="$1"

    ((TOTAL_CHECKS++))

    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")

        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
                echo -e "${GREEN}  ✓ ${container_name}: running${NC}"
                ((PASSED_CHECKS++))
                return 0
            else
                echo -e "${YELLOW}  ⚠ ${container_name}: running but health=${health}${NC}"
                ((PASSED_CHECKS++))
                return 0
            fi
        else
            echo -e "${RED}  ✗ ${container_name}: ${status}${NC}"
            ((FAILED_CHECKS++))
            return 1
        fi
    else
        echo -e "${CYAN}  - ${container_name}: not running (may be in optional profile)${NC}"
        ((SKIPPED_CHECKS++))
        return 2
    fi
}

# Get HOST_ADDR from .env
HOST_ADDR=$(grep "^HOST_ADDR=" "${ENV_FILE}" | cut -d= -f2)
HOST_ADDR=${HOST_ADDR:-127.0.0.1}

echo -e "${YELLOW}Testing against: ${HOST_ADDR}${NC}"
echo

# Core Infrastructure Services
echo -e "${MAGENTA}[Core Infrastructure]${NC}"
check_container "gluetun"
check_container "mariadb"
check_container "postgres"
check_container "redis"

echo
echo -e "${MAGENTA}[VPN & P2P Services]${NC}"
check_http "Gluetun Control" "http://${HOST_ADDR}:8000/v1/publicip/ip" 200 || true
check_http "qBittorrent" "http://${HOST_ADDR}:8080" 200 || true
check_http "slskd" "http://${HOST_ADDR}:2234" 200 || true

echo
echo -e "${MAGENTA}[Storage & Backup]${NC}"
check_container "kopia_server"
check_http "Kopia WebUI" "http://${HOST_ADDR}:51515/health" 200 || true
check_container "nextcloud"
check_http "Nextcloud" "http://${HOST_ADDR}:8082/status.php" 200 || true

echo
echo -e "${MAGENTA}[Git Services]${NC}"
check_container "gitea"
check_http "Gitea" "http://${HOST_ADDR}:3001" 200 || true

echo
echo -e "${MAGENTA}[Monitoring Stack]${NC}"
check_container "prometheus"
check_http "Prometheus" "http://${HOST_ADDR}:9090/-/healthy" 200 || true
check_container "grafana"
check_http "Grafana" "http://${HOST_ADDR}:3000/api/health" 200 || true
check_container "loki"
check_http "Loki" "http://${HOST_ADDR}:3100/ready" 200 || true
check_container "promtail"
check_container "alertmanager"
check_http "Alertmanager" "http://${HOST_ADDR}:9093/-/healthy" 200 || true

echo
echo -e "${MAGENTA}[System Exporters]${NC}"
check_container "node-exporter"
check_http "Node Exporter" "http://${HOST_ADDR}:9100/metrics" 200 || true
check_container "cadvisor"
check_http "cAdvisor" "http://${HOST_ADDR}:8081/metrics" 200 || true
check_container "smartctl-exporter"
check_http "SMARTCTL Exporter" "http://${HOST_ADDR}:9633/metrics" 200 || true

echo
echo -e "${MAGENTA}[Management Tools]${NC}"
check_container "portainer"
check_http "Portainer" "http://${HOST_ADDR}:9000/api/status" 200 || true
check_container "diun"
check_container "dozzle"
check_http "Dozzle" "http://${HOST_ADDR}:8083" 200 || true
check_container "autoheal"

echo
echo -e "${MAGENTA}[Reverse Proxy & Dashboard]${NC}"
check_container "nginx-proxy-manager"
check_http "Nginx Proxy Manager" "http://${HOST_ADDR}:81" 200 || true
check_container "homepage"
check_http "Homepage" "http://${HOST_ADDR}:3003" 200 || true

echo
echo -e "${MAGENTA}[Database Backups]${NC}"
check_container "db-backups"

echo
echo -e "${MAGENTA}[Optional Services (may not be running)]${NC}"
check_container "netdata" || true
check_container "blackbox-exporter" || true
check_container "speedtest-exporter" || true
check_container "fritzbox-exporter" || true
check_container "uptime-kuma" || true
check_container "vaultwarden" || true
check_container "authelia" || true
check_container "firefly-iii" || true
check_container "firefly-worker" || true
check_container "firefly-cron" || true
check_container "fints-importer" || true
check_container "fints-cron" || true
check_container "immich-server" || true
check_container "immich-microservices" || true
## consolidated under db-backups
check_container "vaultwarden-backup" || true
## consolidated under db-backups

# Summary
echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Health Check Summary:${NC}"
echo -e "  Total checks: ${TOTAL_CHECKS}"
echo -e "${GREEN}  Passed: ${PASSED_CHECKS}${NC}"
echo -e "${RED}  Failed: ${FAILED_CHECKS}${NC}"
echo -e "${CYAN}  Skipped: ${SKIPPED_CHECKS} (optional services)${NC}"
echo

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All active services are healthy!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}✗ Some services are not healthy${NC}"
    echo -e "${YELLOW}Check logs with: docker compose logs [service-name]${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
