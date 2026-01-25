#!/bin/bash
################################################################################
# Download OneDrive Content (using rclone)
# Downloads all files from OneDrive to local directory
################################################################################

set -eu

SYNC_DIR="/mnt/storage/onedrive-temp"
REMOTE_NAME="onedrive"
LOG_DIR="$HOME/.config/rclone/logs"

echo "============================================================"
echo "Download OneDrive Content (rclone)"
echo "============================================================"
echo ""

# Check prerequisites
if ! command -v rclone >/dev/null 2>&1; then
	echo "✗ rclone not found"
	echo "  Please run: ./install-rclone.sh"
	exit 1
fi

if ! rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:$"; then
	echo "✗ OneDrive remote not configured"
	echo "  Please run: ./setup-rclone-onedrive.sh"
	exit 1
fi

# Test connection
echo "Testing OneDrive connection..."
if ! rclone lsd ${REMOTE_NAME}: --max-depth 1 >/dev/null 2>&1; then
	echo "✗ Cannot connect to OneDrive"
	echo "  Try: ./setup-rclone-onedrive.sh"
	exit 1
fi
echo "✓ Connection OK"
echo ""

# Check disk space
echo "Checking disk space..."
mkdir -p "$SYNC_DIR"
SYNC_DIR_MOUNTPOINT=$(df "$SYNC_DIR" | tail -1 | awk '{print $6}')
AVAILABLE_SPACE=$(df "$SYNC_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

echo "  Target directory: $SYNC_DIR"
echo "  Mount point: $SYNC_DIR_MOUNTPOINT"
echo "  Available space: ${AVAILABLE_GB}GB"
echo ""

# Get OneDrive size estimate (skipped for faster startup)
echo "Skipping OneDrive size check (starting download directly)..."
echo "  Available disk space: ${AVAILABLE_GB}GB"
echo ""

# Check if already synced
if [ -d "$SYNC_DIR" ] && [ "$(ls -A "$SYNC_DIR" 2>/dev/null)" ]; then
	echo "⚠ Files already exist in $SYNC_DIR"
	echo ""
	echo "Current contents:"
	ls -lh "$SYNC_DIR" | head -20
	echo ""
	read -p "Continue downloading (will sync/resume)? (y/N): " -n 1 -r
	echo ""
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Cancelled"
		exit 0
	fi
fi

# Create log directory
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/download-$(date +%Y%m%d_%H%M%S).log"

echo "Starting download..."
echo "  This may take a while (15 min - several hours)"
echo "  Log file: $LOG_FILE"
echo ""
echo "Press Ctrl+C to pause (download is resumable)"
echo ""

# Run rclone sync with progress
rclone sync "${REMOTE_NAME}:" "$SYNC_DIR" \
	--progress \
	--transfers 4 \
	--checkers 8 \
	--contimeout 60s \
	--timeout 300s \
	--retries 3 \
	--low-level-retries 10 \
	--stats 10s \
	--stats-one-line \
	--log-file="$LOG_FILE" \
	--log-level INFO \
	2>&1 | tee -a "$LOG_FILE"

RESULT=$?

# Check result
if [ $RESULT -eq 0 ]; then
	echo ""
	echo "============================================================"
	echo "✓ Download Complete!"
	echo "============================================================"
	echo ""

	# Show summary
	echo "Downloaded to: $SYNC_DIR"
	echo ""

	if [ -d "$SYNC_DIR" ]; then
		echo "Contents:"
		echo ""
		du -sh "$SYNC_DIR"/* 2>/dev/null | sort -hr | head -20
		echo ""

		TOTAL_SIZE=$(du -sh "$SYNC_DIR" 2>/dev/null | cut -f1)
		TOTAL_FILES=$(find "$SYNC_DIR" -type f 2>/dev/null | wc -l)
		TOTAL_DIRS=$(find "$SYNC_DIR" -type d 2>/dev/null | wc -l)

		echo "Summary:"
		echo "  Total size: $TOTAL_SIZE"
		echo "  Total files: $TOTAL_FILES"
		echo "  Total directories: $TOTAL_DIRS"
	fi

	echo ""
	echo "Next step: Run ./migrate-onedrive-to-syncthing.sh"
	echo ""
else
	echo ""
	echo "⚠ Download completed with warnings/errors (exit code: $RESULT)"
	echo ""
	echo "Check the log file for details:"
	echo "  $LOG_FILE"
	echo ""
	echo "You can run this script again to resume/resync"
	echo ""
fi
