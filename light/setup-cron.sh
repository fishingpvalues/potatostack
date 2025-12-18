#!/bin/bash

################################################################################
# Setup Cron Jobs for PotatoStack
# - Nightly backup to second disk (3:00 AM)
# - Docker system prune (weekly, Sunday 4:00 AM)
################################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PotatoStack Cron Job Setup                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-to-second-disk.sh"

# Check if backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo -e "${YELLOW}ERROR: Backup script not found at $BACKUP_SCRIPT${NC}"
    exit 1
fi

# Make backup script executable
chmod +x "$BACKUP_SCRIPT"
echo -e "${GREEN}✓ Made backup script executable${NC}"

# Create crontab entries
CRON_FILE="/tmp/potatostack-cron"

# Get existing crontab (ignore errors if no crontab exists)
crontab -l > "$CRON_FILE" 2>/dev/null || true

# Remove existing PotatoStack entries
sed -i '/# PotatoStack/d' "$CRON_FILE"
sed -i '/backup-to-second-disk.sh/d' "$CRON_FILE"
sed -i '/docker system prune/d' "$CRON_FILE"

# Add new entries
cat >> "$CRON_FILE" << EOF

# PotatoStack - Nightly backup to second disk (3:00 AM)
0 3 * * * $BACKUP_SCRIPT >> /var/log/potatostack/backup-cron.log 2>&1

# PotatoStack - Weekly Docker cleanup (Sunday 4:00 AM)
0 4 * * 0 docker system prune -af --volumes >> /var/log/potatostack/docker-prune.log 2>&1

# PotatoStack - Check Docker container health (every 5 minutes)
*/5 * * * * docker ps --filter "health=unhealthy" --format "{{.Names}}" | grep -q . && echo "[$(date)] Unhealthy containers detected" >> /var/log/potatostack/health-check.log

# PotatoStack - Restart Docker if daemon is unresponsive (every 10 minutes)
*/10 * * * * timeout 30 docker ps > /dev/null 2>&1 || (echo "[$(date)] Docker daemon unresponsive, restarting..." >> /var/log/potatostack/docker-restart.log && systemctl restart docker)
EOF

# Install new crontab
crontab "$CRON_FILE"
rm "$CRON_FILE"

echo -e "${GREEN}✓ Cron jobs installed successfully${NC}"
echo ""

# Show installed cron jobs
echo -e "${CYAN}Installed Cron Jobs:${NC}"
crontab -l | grep -A5 "# PotatoStack"

echo ""
echo -e "${CYAN}Log Files:${NC}"
echo "  Backup logs:        /var/log/potatostack/backup-*.log"
echo "  Backup cron log:    /var/log/potatostack/backup-cron.log"
echo "  Docker prune log:   /var/log/potatostack/docker-prune.log"
echo "  Health check log:   /var/log/potatostack/health-check.log"
echo "  Docker restart log: /var/log/potatostack/docker-restart.log"
echo ""

# Create log directory
sudo mkdir -p /var/log/potatostack
sudo chown -R $USER:$USER /var/log/potatostack
echo -e "${GREEN}✓ Created log directory: /var/log/potatostack${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Cron jobs setup completed successfully           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Mount second disk at /mnt/backup"
echo "  2. Test backup manually: sudo $BACKUP_SCRIPT"
echo "  3. Check cron logs: tail -f /var/log/potatostack/backup-cron.log"
echo ""
