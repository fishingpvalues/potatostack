#!/bin/bash

################################################################################
# Nightly Backup Script - Main Disk to Second Disk
# Runs via cron to sync /mnt/storage to /mnt/backup
# Uses rsync for incremental backups with hard links
################################################################################

set -e

# Configuration
SOURCE_DIR="/mnt/storage"
BACKUP_DIR="/mnt/backup"
LOG_DIR="/var/log/potatostack"
LOG_FILE="$LOG_DIR/backup-$(date +%Y-%m-%d).log"
RETENTION_DAYS=7

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start backup
log "╔════════════════════════════════════════════════════╗"
log "║  PotatoStack Nightly Backup to Second Disk        ║"
log "╚════════════════════════════════════════════════════╝"
log ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR: Source directory $SOURCE_DIR does not exist!"
    exit 1
fi

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR: Backup directory $BACKUP_DIR does not exist!"
    log "Please mount the second disk at $BACKUP_DIR"
    exit 1
fi

# Check available space
SOURCE_SIZE=$(du -sb "$SOURCE_DIR" | cut -f1)
BACKUP_AVAIL=$(df -B1 "$BACKUP_DIR" | tail -1 | awk '{print $4}')

log "Source size: $(numfmt --to=iec-i --suffix=B $SOURCE_SIZE)"
log "Backup available: $(numfmt --to=iec-i --suffix=B $BACKUP_AVAIL)"

if [ "$SOURCE_SIZE" -gt "$BACKUP_AVAIL" ]; then
    log "ERROR: Not enough space on backup disk!"
    log "Need: $(numfmt --to=iec-i --suffix=B $SOURCE_SIZE)"
    log "Have: $(numfmt --to=iec-i --suffix=B $BACKUP_AVAIL)"
    exit 1
fi

# Create timestamped backup directory
BACKUP_TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DEST="$BACKUP_DIR/backup-$BACKUP_TIMESTAMP"
LATEST_LINK="$BACKUP_DIR/latest"

log "Creating backup: $BACKUP_DEST"

# Find previous backup for hard linking
PREVIOUS_BACKUP=""
if [ -L "$LATEST_LINK" ]; then
    PREVIOUS_BACKUP=$(readlink -f "$LATEST_LINK")
    if [ -d "$PREVIOUS_BACKUP" ]; then
        log "Using previous backup for hard links: $PREVIOUS_BACKUP"
    fi
fi

# Run rsync with progress
log "Starting rsync..."
log ""

RSYNC_OPTS=(
    -aHAXxv                          # Archive mode with all attributes
    --numeric-ids                     # Don't map uid/gid values
    --delete                          # Delete files that don't exist in source
    --delete-excluded                 # Delete excluded files from dest
    --partial                         # Keep partially transferred files
    --info=progress2                  # Show progress
    --exclude='*.tmp'                 # Exclude temp files
    --exclude='*.swp'                 # Exclude swap files
    --exclude='.Trash-*'              # Exclude trash
    --exclude='lost+found'            # Exclude filesystem recovery
)

# Add link-dest if previous backup exists
if [ -n "$PREVIOUS_BACKUP" ]; then
    RSYNC_OPTS+=(--link-dest="$PREVIOUS_BACKUP")
fi

# Execute rsync
if rsync "${RSYNC_OPTS[@]}" "$SOURCE_DIR/" "$BACKUP_DEST/" 2>&1 | tee -a "$LOG_FILE"; then
    log ""
    log "✓ Backup completed successfully"

    # Update latest symlink
    ln -snf "$BACKUP_DEST" "$LATEST_LINK"
    log "✓ Updated latest link: $LATEST_LINK -> $BACKUP_DEST"

    # Calculate backup size
    BACKUP_SIZE=$(du -sb "$BACKUP_DEST" | cut -f1)
    log "Backup size: $(numfmt --to=iec-i --suffix=B $BACKUP_SIZE)"

    # Calculate space saved by hard links
    if [ -n "$PREVIOUS_BACKUP" ]; then
        TOTAL_SIZE=$(du -sb "$BACKUP_DEST" "$PREVIOUS_BACKUP" | awk '{sum+=$1} END {print sum}')
        ACTUAL_SIZE=$(du -sb "$BACKUP_DIR" | cut -f1)
        SAVED_SIZE=$((TOTAL_SIZE - ACTUAL_SIZE))
        if [ "$SAVED_SIZE" -gt 0 ]; then
            log "Space saved by hard links: $(numfmt --to=iec-i --suffix=B $SAVED_SIZE)"
        fi
    fi
else
    log "ERROR: Backup failed!"
    exit 1
fi

# Cleanup old backups
log ""
log "Cleaning up backups older than $RETENTION_DAYS days..."

find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -mtime +$RETENTION_DAYS | while read OLD_BACKUP; do
    log "Removing old backup: $OLD_BACKUP"
    rm -rf "$OLD_BACKUP"
done

log "✓ Cleanup completed"

# Show disk usage
log ""
log "Disk Usage:"
df -h "$SOURCE_DIR" "$BACKUP_DIR" | tee -a "$LOG_FILE"

log ""
log "╔════════════════════════════════════════════════════╗"
log "║  Backup completed successfully                     ║"
log "╚════════════════════════════════════════════════════╝"

# Cleanup old log files
find "$LOG_DIR" -name "backup-*.log" -mtime +30 -delete

exit 0
