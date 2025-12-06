#!/bin/bash
################################################################################
# PotatoStack Health Check Script
# Verifies all critical services and system health for Le Potato
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
check "Docker Compose is available" "command -v docker-compose" true

if docker-compose ps &> /dev/null; then
    # Count services
    TOTAL_SERVICES=$(docker-compose ps --services | wc -l)
    RUNNING_SERVICES=$(docker-compose ps --filter "status=running" --services | wc -l)

    echo -e "  ${GREEN}→${NC} Running services: $RUNNING_SERVICES / $TOTAL_SERVICES"

    # Check critical services
    check "Surfshark VPN is running" "docker-compose ps surfshark | grep -q Up" true
    check "Prometheus is running" "docker-compose ps prometheus | grep -q Up" false
    check "Grafana is running" "docker-compose ps grafana | grep -q Up" false
    check "Kopia is running" "docker-compose ps kopia | grep -q Up" false
    check "Portainer is running" "docker-compose ps portainer | grep -q Up" false
else
    echo -e "${RED}  Cannot access docker-compose. Are you in the right directory?${NC}"
fi
echo ""

# 4. VPN CHECKS
echo -e "${BLUE}[4] VPN & NETWORK SECURITY${NC}"
if docker ps --filter "name=surfshark" --filter "status=running" | grep -q surfshark; then
    # Check VPN IP
    VPN_IP=$(docker exec surfshark curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "FAILED")
    LOCAL_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "FAILED")

    if [ "$VPN_IP" != "FAILED" ] && [ "$VPN_IP" != "$LOCAL_IP" ]; then
        echo -e "  ${GREEN}✓${NC} VPN IP: $VPN_IP"
        check "qBittorrent using VPN" "docker exec surfshark curl -s --max-time 10 ipinfo.io/ip | grep -q $VPN_IP" true
    else
        echo -e "  ${RED}✗ VPN check failed or VPN IP matches local IP${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "${YELLOW}  Surfshark not running, skipping VPN checks${NC}"
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

if [ -d "/mnt/seconddrive/kopia" ]; then
    KOPIA_REPO_SIZE=$(du -sh /mnt/seconddrive/kopia/repository 2>/dev/null | cut -f1 || echo "N/A")
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
check "/mnt/seconddrive is mounted" "mountpoint -q /mnt/seconddrive" true
check "/mnt/cachehdd is mounted" "mountpoint -q /mnt/cachehdd" true
echo ""

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
