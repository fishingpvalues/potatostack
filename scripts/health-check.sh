#!/bin/bash
################################################################################
# PotatoStack Health Check Script
# Verifies all critical services and system health for Le Potato
################################################################################
# USAGE:
#   ./scripts/health-check.sh              # Full health check (default)
#   ./scripts/health-check.sh --quick      # Quick status check only
#   ./scripts/health-check.sh --security   # Security checks only
#   ./scripts/health-check.sh --help       # Show this help
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Mode flags
MODE="${1:-full}"

# Function to check and print result
check() {
    local description="$1"
    local command="$2"
    local critical="${3:-false}"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "Checking $description... "

    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$critical" = "true" ]; then
            echo -e "${RED}✗ FAIL (CRITICAL)${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        else
            echo -e "${YELLOW}⚠ WARNING${NC}"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            return 0
        fi
    fi
}

show_help() {
    cat << EOF
PotatoStack Health Check Script

USAGE:
    ./scripts/health-check.sh [mode]

MODES:
    (none)          Full health check (default) - all checks
    --quick         Quick status check - essential services only
    --security      Security checks - VPN, firewall, ports, permissions
    --help          Show this help message

EXAMPLES:
    ./scripts/health-check.sh              # Full check
    ./scripts/health-check.sh --quick      # Quick check
    ./scripts/health-check.sh --security   # Security audit

EXIT CODES:
    0 - All critical checks passed
    1 - Some checks failed (1-2 failures)
    2 - Multiple critical failures (3+ failures)

EOF
    exit 0
}

# Detect docker compose command
if command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DC="docker compose"
else
    DC="docker-compose"
fi

################################################################################
# QUICK MODE - Essential services only
################################################################################

mode_quick() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  PotatoStack Quick Status Check${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    check "Docker is running" "systemctl is-active --quiet docker" true
    check "Swap is configured" "swapon --show | grep -q swap" true

    if $DC ps &> /dev/null; then
        TOTAL_SERVICES=$($DC ps --services | wc -l)
        RUNNING_SERVICES=$($DC ps --filter "status=running" --services | wc -l)
        echo -e "  ${GREEN}→${NC} Running services: $RUNNING_SERVICES / $TOTAL_SERVICES"

        check "Gluetun VPN is running" "$DC ps gluetun | grep -q Up" true
        check "Prometheus is running" "$DC ps prometheus | grep -q Up" false
    fi
    echo ""
}

################################################################################
# SECURITY MODE - Security audit checks
################################################################################

mode_security() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  PotatoStack Security Audit${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    # 1. VPN SECURITY
    echo -e "${BLUE}[1] VPN & NETWORK SECURITY${NC}"
    if docker ps --filter "name=gluetun" --filter "status=running" | grep -q gluetun; then
        # Check VPN IP via Gluetun HTTP control server
        VPN_IP_JSON=$(curl -s --max-time 5 http://localhost:8000/v1/publicip/ip 2>/dev/null || echo "FAILED")
        if [ "$VPN_IP_JSON" != "FAILED" ]; then
            VPN_IP=$(echo "$VPN_IP_JSON" | grep -o '"public_ip":"[^"]*"' | cut -d'"' -f4)
        else
            VPN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
        fi

        LOCAL_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "FAILED")

        if [ "$VPN_IP" != "FAILED" ] && [ "$VPN_IP" != "$LOCAL_IP" ]; then
            echo -e "  ${GREEN}✓${NC} VPN IP: $VPN_IP"
            echo -e "  ${GREEN}✓${NC} Local IP: $LOCAL_IP (different - good)"

            VPN_STATUS=$(curl -s --max-time 5 http://localhost:8000/v1/vpn/status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$VPN_STATUS" = "running" ]; then
                echo -e "  ${GREEN}✓${NC} VPN status: running"
            fi

            check "qBittorrent using VPN network" "docker exec gluetun wget -qO- --timeout=5 http://localhost:8080 2>/dev/null | grep -q 'qBittorrent'" true
            check "VPN kill switch active" "docker exec gluetun iptables -L | grep -q DROP" true
        else
            echo -e "  ${RED}✗ VPN check failed or VPN IP matches local IP${NC}"
            echo -e "  ${RED}  VPN IP: $VPN_IP${NC}"
            echo -e "  ${RED}  Local IP: $LOCAL_IP${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        echo -e "${YELLOW}  Gluetun not running - VPN security cannot be verified${NC}"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    echo ""

    # 2. FIREWALL & PORTS
    echo -e "${BLUE}[2] FIREWALL & PORT SECURITY${NC}"
    if command -v ufw >/dev/null 2>&1; then
        check "UFW firewall is active" "ufw status | grep -q 'Status: active'" true
        check "SSH is rate limited" "ufw status | grep -q 'LIMIT.*22'" false
    else
        echo -e "${YELLOW}  UFW not installed, skipping firewall checks${NC}"
    fi

    # Check for exposed ports
    if command -v netstat >/dev/null 2>&1 || command -v ss >/dev/null 2>&1; then
        EXPOSED_PORTS=$(ss -tlnp 2>/dev/null | grep -v '127.0.0.1' | grep -v '::1' | grep 'LISTEN' || netstat -tlnp 2>/dev/null | grep -v '127.0.0.1' | grep 'LISTEN' || echo "")
        if [ -n "$EXPOSED_PORTS" ]; then
            echo -e "  ${YELLOW}→${NC} Exposed ports (non-localhost):"
            echo "$EXPOSED_PORTS" | awk '{print "    " $4}' | sort -u
        fi
    fi
    echo ""

    # 3. FILE PERMISSIONS
    echo -e "${BLUE}[3] FILE PERMISSIONS & SECRETS${NC}"
    check ".env file is protected (600)" "[ -f .env ] && [ \$(stat -c '%a' .env 2>/dev/null || stat -f '%Lp' .env 2>/dev/null) = '600' ]" true
    check "SSH key permissions correct" "[ ! -f ~/.ssh/id_rsa ] || [ \$(stat -c '%a' ~/.ssh/id_rsa 2>/dev/null || stat -f '%Lp' ~/.ssh/id_rsa 2>/dev/null) = '600' ]" false

    if [ -d ".secrets" ]; then
        check ".secrets directory exists" "[ -d .secrets ]" false
        UNENCRYPTED_SECRETS=$(find .secrets -type f ! -name '*.age' ! -name '.gitignore' ! -name '*.md' 2>/dev/null | wc -l || echo "0")
        if [ "$UNENCRYPTED_SECRETS" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠ Found $UNENCRYPTED_SECRETS unencrypted file(s) in .secrets/${NC}"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        else
            echo -e "  ${GREEN}✓${NC} All secrets are encrypted"
        fi
    fi
    echo ""

    # 4. DOCKER SECURITY
    echo -e "${BLUE}[4] DOCKER SECURITY${NC}"
    check "Docker daemon is secure" "! docker info 2>/dev/null | grep -q 'Insecure Registries'" false
    check "Docker socket is protected" "[ \$(stat -c '%a' /var/run/docker.sock 2>/dev/null || stat -f '%Lp' /var/run/docker.sock 2>/dev/null) = '660' ] || [ \$(stat -c '%a' /var/run/docker.sock 2>/dev/null || stat -f '%Lp' /var/run/docker.sock 2>/dev/null) = '666' ]" false

    # Check for containers running as root
    ROOT_CONTAINERS=$(docker ps --format '{{.Names}}' --filter "label=com.docker.compose.project" 2>/dev/null | while read -r container; do
        USER=$(docker inspect "$container" --format '{{.Config.User}}' 2>/dev/null || echo "")
        if [ -z "$USER" ]; then
            echo "$container"
        fi
    done || echo "")

    if [ -n "$ROOT_CONTAINERS" ]; then
        echo -e "  ${YELLOW}⚠ Containers running as root:${NC}"
        echo "$ROOT_CONTAINERS" | while read -r container; do
            [ -n "$container" ] && echo "    - $container"
        done
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    echo ""

    # 5. AUTHENTICATION & ACCESS
    echo -e "${BLUE}[5] AUTHENTICATION & ACCESS CONTROL${NC}"
    if docker ps --filter "name=authelia" --filter "status=running" | grep -q authelia; then
        check "Authelia is running" "docker ps | grep -q authelia" false
        check "Authelia is accessible" "curl -s --max-time 5 http://localhost:9091/api/health | grep -q OK" false
    else
        echo -e "${YELLOW}  Authelia not running, skipping auth checks${NC}"
    fi

    # Check for default passwords in .env
    if [ -f .env ]; then
        DEFAULT_PASSWORDS=$(grep -i 'password.*change' .env 2>/dev/null | wc -l || echo "0")
        if [ "$DEFAULT_PASSWORDS" -gt 0 ]; then
            echo -e "  ${RED}✗ Found $DEFAULT_PASSWORDS default password(s) in .env${NC}"
            echo -e "  ${RED}  Please change all passwords containing 'change'${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "  ${GREEN}✓${NC} No obvious default passwords found"
        fi
    fi
    echo ""
}

################################################################################
# FULL MODE - Complete health check
################################################################################

mode_full() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  PotatoStack Health Check${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    # 1. SYSTEM CHECKS
    echo -e "${BLUE}[1] SYSTEM HEALTH${NC}"
    check "Swap is configured" "swapon --show | grep -q swap" true
    check "Swap usage < 80%" "awk '\$1==\"Swap:\" && (\$3/\$2)*100 < 80 {exit 0} \$1==\"Swap:\" {exit 1}' <(free)" false
    check "Memory usage < 90%" "awk '\$1==\"Mem:\" && (\$3/\$2)*100 < 90 {exit 0} \$1==\"Mem:\" {exit 1}' <(free)" false
    check "CPU load < 4 (cores)" "awk '{if (\$1 < 4) exit 0; else exit 1}' /proc/loadavg" false
    check "Root partition > 10% free" "df / | awk 'NR==2 {if (substr(\$5,1,length(\$5)-1) < 90) exit 0; else exit 1}'" true
    echo ""

    # 2. ZFS CHECKS
    echo -e "${BLUE}[2] ZFS STORAGE${NC}"
    if command -v zpool &> /dev/null; then
        check "ZFS pool exists" "zpool list potatostack" true
        check "ZFS pool is healthy" "zpool status potatostack | grep -q 'state: ONLINE'" true
        check "ZFS pool not degraded" "! zpool status potatostack | grep -q DEGRADED" true
        check "ZFS compression is enabled" "zfs get compression potatostack | grep -q lz4" false

        # Show ZFS compression ratio
        COMP_RATIO=$(zfs get compressratio potatostack -H -o value 2>/dev/null || echo "N/A")
        echo -e "  ${GREEN}→${NC} Compression ratio: ${COMP_RATIO}"
    else
        echo -e "${YELLOW}  ZFS not installed, skipping ZFS checks${NC}"
    fi
    echo ""

    # 3. DOCKER CHECKS
    echo -e "${BLUE}[3] DOCKER SERVICES${NC}"
    check "Docker is running" "systemctl is-active --quiet docker" true
    check "Docker Compose is available" "command -v docker-compose || docker compose version" true

    if $DC ps &> /dev/null; then
        # Count services
        TOTAL_SERVICES=$($DC ps --services | wc -l)
        RUNNING_SERVICES=$($DC ps --filter "status=running" --services | wc -l)

        echo -e "  ${GREEN}→${NC} Running services: $RUNNING_SERVICES / $TOTAL_SERVICES"

        # Check critical services
        check "Gluetun VPN is running" "$DC ps gluetun | grep -q Up" true
        check "Prometheus is running" "$DC ps prometheus | grep -q Up" false
        check "Grafana is running" "$DC ps grafana | grep -q Up" false
        check "Kopia is running" "$DC ps kopia | grep -q Up" false
        check "Portainer is running" "$DC ps portainer | grep -q Up" false
    else
        echo -e "${RED}  Cannot access docker-compose. Are you in the right directory?${NC}"
    fi
    echo ""

    # 4. VPN CHECKS
    echo -e "${BLUE}[4] VPN & NETWORK SECURITY${NC}"
    if docker ps --filter "name=gluetun" --filter "status=running" | grep -q gluetun; then
        # Check VPN IP via Gluetun HTTP control server
        VPN_IP_JSON=$(curl -s --max-time 5 http://localhost:8000/v1/publicip/ip 2>/dev/null || echo "FAILED")
        if [ "$VPN_IP_JSON" != "FAILED" ]; then
            VPN_IP=$(echo "$VPN_IP_JSON" | grep -o '"public_ip":"[^"]*"' | cut -d'"' -f4)
        else
            VPN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
        fi

        LOCAL_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "FAILED")

        if [ "$VPN_IP" != "FAILED" ] && [ "$VPN_IP" != "$LOCAL_IP" ]; then
            echo -e "  ${GREEN}✓${NC} VPN IP: $VPN_IP"

            # Check VPN status via HTTP API
            VPN_STATUS=$(curl -s --max-time 5 http://localhost:8000/v1/vpn/status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$VPN_STATUS" = "running" ]; then
                echo -e "  ${GREEN}✓${NC} VPN status: running"
            fi

            check "qBittorrent using VPN network" "docker exec gluetun wget -qO- --timeout=5 http://localhost:8080 2>/dev/null | grep -q 'qBittorrent'" true
        else
            echo -e "  ${RED}✗ VPN check failed or VPN IP matches local IP${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        echo -e "${YELLOW}  Gluetun not running, skipping VPN checks${NC}"
    fi
    echo ""

    # 5. MONITORING CHECKS
    echo -e "${BLUE}[5] MONITORING STACK${NC}"
    check "Prometheus is accessible" "curl -s --max-time 5 http://localhost:9090/-/healthy | grep -q Prometheus" false
    check "Grafana is accessible" "curl -s --max-time 5 http://localhost:3000/api/health | grep -q ok" false
    check "Alertmanager is accessible" "curl -s --max-time 5 http://localhost:9093/-/healthy | grep -q OK" false
    check "Node exporter is accessible" "curl -s --max-time 5 http://localhost:9100/metrics | grep -q node_" true
    echo ""

    # 6. BACKUP CHECKS
    echo -e "${BLUE}[6] BACKUP SYSTEM${NC}"
    check "Kopia is accessible" "curl -s --max-time 5 http://localhost:51515/health | grep -q ok" false

    if [ -d "/mnt/seconddrive/kopia" ] || [ -d "/mnt/potatostack/kopia" ]; then
        KOPIA_DIR="/mnt/potatostack/kopia"
        [ ! -d "$KOPIA_DIR" ] && KOPIA_DIR="/mnt/seconddrive/kopia"

        KOPIA_REPO_SIZE=$(du -sh "$KOPIA_DIR/repository" 2>/dev/null | cut -f1 || echo "N/A")
        echo -e "  ${GREEN}→${NC} Kopia repository size: $KOPIA_REPO_SIZE"

        # Check last backup (if kopia CLI is available)
        if command -v kopia &> /dev/null; then
            LAST_BACKUP=$(kopia snapshot list --all 2>/dev/null | tail -n 1 | awk '{print $1}' || echo "Unknown")
            echo -e "  ${GREEN}→${NC} Last snapshot: $LAST_BACKUP"
        fi
    else
        echo -e "${YELLOW}  Kopia repository not found at expected location${NC}"
    fi
    echo ""

    # 7. DISK HEALTH CHECKS
    echo -e "${BLUE}[7] DISK HEALTH (SMART)${NC}"
    if command -v smartctl &> /dev/null; then
        for disk in /dev/sda /dev/sdb; do
            if [ -e "$disk" ]; then
                check "SMART status for $disk" "smartctl -H $disk | grep -q PASSED" true
            fi
        done
    else
        echo -e "${YELLOW}  smartctl not installed, skipping SMART checks${NC}"
    fi
    echo ""

    # 8. MOUNT POINT CHECKS
    echo -e "${BLUE}[8] MOUNT POINTS${NC}"
    # Check for either old mount points or new ZFS mount point
    if mountpoint -q /mnt/potatostack 2>/dev/null; then
        check "/mnt/potatostack is mounted (ZFS)" "mountpoint -q /mnt/potatostack" true
    else
        check "/mnt/seconddrive is mounted" "mountpoint -q /mnt/seconddrive" true
        check "/mnt/cachehdd is mounted" "mountpoint -q /mnt/cachehdd" true
    fi
    echo ""
}

################################################################################
# Main Entry Point
################################################################################

case "$MODE" in
    --quick|-q)
        mode_quick
        ;;
    --security|-s)
        mode_security
        ;;
    --help|-h|help)
        show_help
        ;;
    full|--full|-f|"")
        mode_full
        ;;
    *)
        echo -e "${RED}Unknown mode: $MODE${NC}"
        echo ""
        show_help
        ;;
esac

# Summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  HEALTH CHECK SUMMARY${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Total checks:    $TOTAL_CHECKS"
echo -e "${GREEN}Passed:         $PASSED_CHECKS${NC}"
echo -e "${YELLOW}Warnings:       $WARNING_CHECKS${NC}"
echo -e "${RED}Failed:         $FAILED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    exit 0
elif [ $FAILED_CHECKS -lt 3 ]; then
    echo -e "${YELLOW}⚠ Some checks failed. Please review.${NC}"
    exit 1
else
    echo -e "${RED}✗ Multiple critical failures detected!${NC}"
    exit 2
fi
