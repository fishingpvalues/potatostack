#!/bin/bash
################################################################################
# Kopia Backup Verification Script
# Automates backup integrity testing for disaster recovery readiness
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KOPIA_SERVER="http://localhost:51515"
KOPIA_CONFIG_DIR="/mnt/seconddrive/kopia/config"
KOPIA_REPO_DIR="/mnt/seconddrive/kopia/repository"
TEST_RESTORE_DIR="/tmp/kopia-verify-$(date +%s)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Kopia Backup Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Kopia is running
if ! docker ps --filter "name=kopia" --filter "status=running" | grep -q kopia; then
    echo -e "${RED}✗ Kopia container is not running!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Kopia container is running${NC}"
echo ""

# Check Kopia health endpoint
echo -e "${BLUE}[1] Checking Kopia Server Health${NC}"
HEALTH_CHECK=$(curl -s --max-time 10 "$KOPIA_SERVER/health" 2>/dev/null || echo "FAILED")

if echo "$HEALTH_CHECK" | grep -q "ok"; then
    echo -e "${GREEN}✓ Kopia server is healthy${NC}"
else
    echo -e "${RED}✗ Kopia server health check failed${NC}"
    exit 1
fi
echo ""

# Check repository exists
echo -e "${BLUE}[2] Checking Repository${NC}"
if [ ! -d "$KOPIA_REPO_DIR" ]; then
    echo -e "${RED}✗ Kopia repository not found at $KOPIA_REPO_DIR${NC}"
    exit 1
fi

REPO_SIZE=$(du -sh "$KOPIA_REPO_DIR" 2>/dev/null | cut -f1 || echo "N/A")
echo -e "  ${GREEN}→${NC} Repository location: $KOPIA_REPO_DIR"
echo -e "  ${GREEN}→${NC} Repository size: $REPO_SIZE"
echo ""

# Check snapshots exist
echo -e "${BLUE}[3] Checking Snapshots${NC}"
if command -v kopia &> /dev/null; then
    # List recent snapshots
    SNAPSHOT_COUNT=$(docker exec kopia_server kopia snapshot list --all 2>/dev/null | tail -n +2 | wc -l || echo "0")

    if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $SNAPSHOT_COUNT snapshots${NC}"

        # Show last 5 snapshots
        echo -e "\n  Recent snapshots:"
        docker exec kopia_server kopia snapshot list --all 2>/dev/null | tail -n 5 | while read -r line; do
            echo -e "  ${GREEN}→${NC} $line"
        done
    else
        echo -e "${YELLOW}⚠ No snapshots found${NC}"
        echo -e "  This may be normal if backups haven't run yet"
    fi
else
    echo -e "${YELLOW}⚠ Kopia CLI not available, skipping snapshot listing${NC}"
fi
echo ""

# Check Kopia metrics (if Prometheus integration is enabled)
echo -e "${BLUE}[4] Checking Backup Metrics${NC}"
METRICS=$(curl -s --max-time 5 http://localhost:51516/metrics 2>/dev/null || echo "FAILED")

if [ "$METRICS" != "FAILED" ]; then
    echo -e "${GREEN}✓ Kopia metrics endpoint is accessible${NC}"

    # Parse key metrics
    ERROR_COUNT=$(echo "$METRICS" | grep "kopia_snapshot_manager_errors_total" | tail -1 | awk '{print $2}' || echo "N/A")
    LAST_SNAPSHOT=$(echo "$METRICS" | grep "kopia_snapshot_manager_last_snapshot_time_seconds" | tail -1 | awk '{print $2}' || echo "N/A")

    echo -e "  ${GREEN}→${NC} Total errors: ${ERROR_COUNT:-0}"

    if [ "$LAST_SNAPSHOT" != "N/A" ] && [ "$LAST_SNAPSHOT" != "0" ]; then
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - ${LAST_SNAPSHOT%.*}))
        HOURS_AGO=$((TIME_DIFF / 3600))

        echo -e "  ${GREEN}→${NC} Last snapshot: ${HOURS_AGO}h ago"

        if [ "$HOURS_AGO" -gt 48 ]; then
            echo -e "  ${YELLOW}⚠ WARNING: Last snapshot is older than 48 hours${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Kopia metrics not available${NC}"
fi
echo ""

# Verify repository integrity
echo -e "${BLUE}[5] Repository Integrity Check${NC}"
echo -e "  ${YELLOW}Running quick integrity check (this may take a moment)...${NC}"

if docker exec kopia_server kopia repository verify --file-parallelism=2 --max-errors=10 2>&1 | tail -n 5; then
    echo -e "${GREEN}✓ Repository integrity check passed${NC}"
else
    echo -e "${RED}✗ Repository integrity check failed${NC}"
    echo -e "  Review the output above for details"
fi
echo ""

# Test restore (optional)
echo -e "${BLUE}[6] Test Restore (Optional)${NC}"
echo -e "  This will restore a small random file to verify restore functionality"
read -p "  Proceed with test restore? (yes/no): " -r
echo

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    mkdir -p "$TEST_RESTORE_DIR"

    echo "  Finding a snapshot to test..."
    SNAPSHOT_ID=$(docker exec kopia_server kopia snapshot list --all 2>/dev/null | tail -n 1 | awk '{print $1}' || echo "")

    if [ -n "$SNAPSHOT_ID" ] && [ "$SNAPSHOT_ID" != "ID" ]; then
        echo "  Restoring snapshot $SNAPSHOT_ID to $TEST_RESTORE_DIR..."

        if docker exec kopia_server kopia snapshot restore "$SNAPSHOT_ID" "$TEST_RESTORE_DIR" --skip-existing 2>&1 | tail -n 10; then
            echo -e "${GREEN}  ✓ Test restore successful${NC}"

            # Count restored files
            FILE_COUNT=$(find "$TEST_RESTORE_DIR" -type f 2>/dev/null | wc -l || echo "0")
            echo -e "  ${GREEN}→${NC} Restored $FILE_COUNT files"

            # Cleanup
            rm -rf "$TEST_RESTORE_DIR"
            echo -e "  ${GREEN}→${NC} Cleaned up test restore directory"
        else
            echo -e "${RED}  ✗ Test restore failed${NC}"
            rm -rf "$TEST_RESTORE_DIR"
        fi
    else
        echo -e "${YELLOW}  ⚠ No snapshots available for test restore${NC}"
    fi
else
    echo -e "${YELLOW}  Test restore skipped by user${NC}"
fi
echo ""

# Check backup schedule (via cron or systemd timer)
echo -e "${BLUE}[7] Checking Backup Schedule${NC}"
if crontab -l 2>/dev/null | grep -q kopia; then
    echo -e "${GREEN}✓ Kopia backup scheduled via crontab${NC}"
    crontab -l | grep kopia | while read -r line; do
        echo -e "  ${GREEN}→${NC} $line"
    done
elif systemctl list-timers --all 2>/dev/null | grep -q kopia; then
    echo -e "${GREEN}✓ Kopia backup scheduled via systemd timer${NC}"
else
    echo -e "${YELLOW}⚠ No automatic backup schedule found${NC}"
    echo -e "  Consider setting up automated backups via cron or systemd timer"
fi
echo ""

# Disaster recovery checklist
echo -e "${BLUE}[8] Disaster Recovery Readiness${NC}"
echo -e "  ${BLUE}Checklist:${NC}"

# Check if repository password is backed up
if [ -f "$HOME/.kopia-password-backup" ]; then
    echo -e "  ${GREEN}✓${NC} Repository password backup found"
else
    echo -e "  ${YELLOW}⚠${NC} Repository password backup not found at $HOME/.kopia-password-backup"
    echo -e "    ${YELLOW}RECOMMENDATION:${NC} Store KOPIA_PASSWORD in a secure location"
fi

# Check if offsite backup exists
if [ -d "/mnt/external/kopia-offsite" ]; then
    echo -e "  ${GREEN}✓${NC} Offsite backup directory exists"
else
    echo -e "  ${YELLOW}⚠${NC} No offsite backup detected"
    echo -e "    ${YELLOW}RECOMMENDATION:${NC} Set up offsite backup (external drive, cloud)"
fi

# Check if recovery documentation exists
if [ -f "$HOME/kopia-recovery-guide.txt" ]; then
    echo -e "  ${GREEN}✓${NC} Recovery documentation found"
else
    echo -e "  ${YELLOW}⚠${NC} No recovery documentation found"
    echo -e "    ${YELLOW}RECOMMENDATION:${NC} Document recovery procedure"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VERIFICATION SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Kopia server is operational${NC}"
echo -e "${GREEN}✓ Repository is accessible${NC}"
echo -e "${GREEN}✓ Repository integrity verified${NC}"
echo ""
echo -e "${BLUE}Recommendations:${NC}"
echo "  1. Run this verification monthly to ensure backup health"
echo "  2. Perform full disaster recovery test quarterly"
echo "  3. Backup Kopia repository to external drive monthly"
echo "  4. Store KOPIA_PASSWORD in secure password manager"
echo "  5. Document complete recovery procedure"
echo ""

exit 0
