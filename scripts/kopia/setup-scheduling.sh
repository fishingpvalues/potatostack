#!/bin/bash
################################################################################
# Kopia Backup Scheduling Setup
# Configures automated backups via cron for Potato Stack
# Optimized schedule to avoid conflicts with other services
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POTATOSTACK_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

################################################################################
# DISPLAY CURRENT SCHEDULE
################################################################################

cat << 'EOF'
================================================================================
                    Kopia Backup Scheduling Setup
================================================================================

This script will configure automated backup schedules optimized for Le Potato:

RECOMMENDED SCHEDULE (3-2-1 Backup Strategy):
  ✓ Daily snapshots:   3:00 AM (after database backups complete at 2:30 AM)
  ✓ Quick maintenance: 4:00 AM (weekly on Sundays)
  ✓ Full maintenance:  4:00 AM (monthly on 1st Sunday)
  ✓ Verification:      5:00 AM (weekly on Mondays)

Time allocations (prevent overlap):
  - Database backups: 2:00-2:30 AM (docker-compose built-in)
  - Kopia snapshots:  3:00-3:45 AM (estimated 30-45 min)
  - Maintenance:      4:00-5:00 AM (weekly, 30-60 min)
  - Verification:     5:00-5:30 AM (weekly, 15-30 min)

================================================================================
EOF

echo ""

################################################################################
# CHECK EXISTING CRON JOBS
################################################################################

log_info "Checking for existing Kopia cron jobs..."

if crontab -l 2>/dev/null | grep -q kopia; then
    log_warn "Existing Kopia cron jobs found:"
    crontab -l | grep kopia
    echo ""
    read -p "Remove existing Kopia cron jobs? (yes/no): " -r
    echo

    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        crontab -l 2>/dev/null | grep -v kopia | crontab -
        log_success "Existing cron jobs removed"
    else
        log_warn "Keeping existing cron jobs - manual merge may be required"
    fi
fi

echo ""

################################################################################
# CRON SCHEDULE OPTIONS
################################################################################

log_info "Select backup schedule:"
echo ""
echo "1. RECOMMENDED - Daily backups + weekly maintenance (Le Potato optimized)"
echo "   - Daily snapshots at 3:00 AM"
echo "   - Quick maintenance on Sundays at 4:00 AM"
echo "   - Full maintenance on 1st Sunday at 4:00 AM"
echo "   - Verification on Mondays at 5:00 AM"
echo ""
echo "2. CONSERVATIVE - Every other day + bi-weekly maintenance (minimal resource use)"
echo "   - Snapshots every 2 days at 3:00 AM"
echo "   - Quick maintenance bi-weekly"
echo ""
echo "3. AGGRESSIVE - Twice daily + daily maintenance (high-value data)"
echo "   - Snapshots at 3:00 AM and 3:00 PM"
echo "   - Daily quick maintenance at 4:00 AM"
echo ""
echo "4. CUSTOM - I'll configure manually"
echo ""

read -p "Enter choice (1-4): " SCHEDULE_CHOICE
echo ""

################################################################################
# CREATE CRON ENTRIES
################################################################################

CRON_ENTRIES=""

case $SCHEDULE_CHOICE in
    1)
        log_info "Setting up RECOMMENDED schedule..."
        CRON_ENTRIES=$(cat << EOF
# Kopia Backup Schedule - Potato Stack (Recommended)
# Generated on $(date)

# Daily snapshots at 3:00 AM (after DB backups at 2:00 AM)
0 3 * * * cd $POTATOSTACK_DIR && ./scripts/kopia/create-snapshots.sh >> /mnt/seconddrive/kopia/logs/cron-snapshots.log 2>&1

# Quick maintenance on Sundays at 4:00 AM
0 4 * * 0 cd $POTATOSTACK_DIR && ./scripts/kopia/maintenance.sh >> /mnt/seconddrive/kopia/logs/cron-maintenance.log 2>&1

# Full maintenance on 1st Sunday of month at 4:00 AM
0 4 1-7 * 0 cd $POTATOSTACK_DIR && FULL_MAINTENANCE=true ./scripts/kopia/maintenance.sh >> /mnt/seconddrive/kopia/logs/cron-maintenance-full.log 2>&1

# Verification on Mondays at 5:00 AM
0 5 * * 1 cd $POTATOSTACK_DIR && ./scripts/verify-kopia-backups.sh >> /mnt/seconddrive/kopia/logs/cron-verify.log 2>&1
EOF
)
        ;;

    2)
        log_info "Setting up CONSERVATIVE schedule..."
        CRON_ENTRIES=$(cat << EOF
# Kopia Backup Schedule - Potato Stack (Conservative)
# Generated on $(date)

# Snapshots every 2 days at 3:00 AM
0 3 */2 * * cd $POTATOSTACK_DIR && ./scripts/kopia/create-snapshots.sh >> /mnt/seconddrive/kopia/logs/cron-snapshots.log 2>&1

# Quick maintenance bi-weekly (1st and 15th) at 4:00 AM
0 4 1,15 * * cd $POTATOSTACK_DIR && ./scripts/kopia/maintenance.sh >> /mnt/seconddrive/kopia/logs/cron-maintenance.log 2>&1

# Verification monthly on 2nd at 5:00 AM
0 5 2 * * cd $POTATOSTACK_DIR && ./scripts/verify-kopia-backups.sh >> /mnt/seconddrive/kopia/logs/cron-verify.log 2>&1
EOF
)
        ;;

    3)
        log_info "Setting up AGGRESSIVE schedule..."
        CRON_ENTRIES=$(cat << EOF
# Kopia Backup Schedule - Potato Stack (Aggressive)
# Generated on $(date)

# Snapshots twice daily at 3:00 AM and 3:00 PM
0 3,15 * * * cd $POTATOSTACK_DIR && ./scripts/kopia/create-snapshots.sh >> /mnt/seconddrive/kopia/logs/cron-snapshots.log 2>&1

# Quick maintenance daily at 4:00 AM
0 4 * * * cd $POTATOSTACK_DIR && ./scripts/kopia/maintenance.sh >> /mnt/seconddrive/kopia/logs/cron-maintenance.log 2>&1

# Full maintenance weekly on Sundays at 4:00 AM
0 4 * * 0 cd $POTATOSTACK_DIR && FULL_MAINTENANCE=true ./scripts/kopia/maintenance.sh >> /mnt/seconddrive/kopia/logs/cron-maintenance-full.log 2>&1

# Verification weekly on Mondays at 5:00 AM
0 5 * * 1 cd $POTATOSTACK_DIR && ./scripts/verify-kopia-backups.sh >> /mnt/seconddrive/kopia/logs/cron-verify.log 2>&1
EOF
)
        ;;

    4)
        log_info "Custom schedule selected - showing example:"
        cat << 'EOF'

Example cron entries (edit as needed):

# Daily snapshots
0 3 * * * cd /path/to/potatostack && ./scripts/kopia/create-snapshots.sh

# Weekly maintenance
0 4 * * 0 cd /path/to/potatostack && ./scripts/kopia/maintenance.sh

# Monthly verification
0 5 1 * * cd /path/to/potatostack && ./scripts/verify-kopia-backups.sh

EOF
        log_info "Run: crontab -e"
        exit 0
        ;;

    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

################################################################################
# INSTALL CRON ENTRIES
################################################################################

log_info "Installing cron entries..."

# Backup existing crontab
if crontab -l &>/dev/null; then
    crontab -l > /tmp/crontab.backup.$(date +%s)
    log_info "Existing crontab backed up to /tmp/crontab.backup.*"
fi

# Add new entries
(crontab -l 2>/dev/null; echo ""; echo "$CRON_ENTRIES") | crontab -

log_success "Cron entries installed successfully!"
echo ""

################################################################################
# VERIFY INSTALLATION
################################################################################

log_info "Verifying installation..."
echo ""
log_info "Current Kopia cron jobs:"
crontab -l | grep -A 20 "Kopia Backup Schedule"
echo ""

################################################################################
# SYSTEMD TIMER ALTERNATIVE (Optional)
################################################################################

cat << 'EOF'
================================================================================
                    ALTERNATIVE: Systemd Timers
================================================================================

If you prefer systemd timers over cron, use these service/timer files:

1. Create /etc/systemd/system/kopia-snapshot.service:
   [Unit]
   Description=Kopia Daily Snapshot
   [Service]
   Type=oneshot
   ExecStart=/path/to/potatostack/scripts/kopia/create-snapshots.sh
   User=youruser

2. Create /etc/systemd/system/kopia-snapshot.timer:
   [Unit]
   Description=Daily Kopia Snapshots
   [Timer]
   OnCalendar=daily
   OnCalendar=03:00
   Persistent=true
   [Install]
   WantedBy=timers.target

3. Enable and start:
   sudo systemctl enable --now kopia-snapshot.timer
   sudo systemctl list-timers

================================================================================
EOF

echo ""

################################################################################
# LOG ROTATION SETUP
################################################################################

log_info "Setting up log rotation..."

LOG_ROTATION_CONFIG="/etc/logrotate.d/kopia-potatostack"

cat << 'EOF' | sudo tee "$LOG_ROTATION_CONFIG" > /dev/null
/mnt/seconddrive/kopia/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

if [ -f "$LOG_ROTATION_CONFIG" ]; then
    log_success "Log rotation configured at $LOG_ROTATION_CONFIG"
else
    log_warn "Could not create log rotation config (requires sudo)"
fi

echo ""

################################################################################
# SUMMARY
################################################################################

log_info "=========================================="
log_info "  SCHEDULING SETUP COMPLETE"
log_info "=========================================="
echo ""

log_success "Automated backups are now scheduled!"
echo ""

log_info "Next steps:"
echo "  1. Wait for first scheduled run or test manually:"
echo "     cd $POTATOSTACK_DIR && ./scripts/kopia/create-snapshots.sh"
echo ""
echo "  2. Monitor cron logs:"
echo "     tail -f /mnt/seconddrive/kopia/logs/cron-*.log"
echo ""
echo "  3. Check cron execution:"
echo "     grep CRON /var/log/syslog | grep kopia"
echo ""
echo "  4. Verify backups are running:"
echo "     docker exec kopia_server kopia snapshot list --all"
echo ""

exit 0
