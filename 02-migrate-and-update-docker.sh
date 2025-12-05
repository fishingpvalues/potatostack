#!/bin/bash

# ==============================================================================
# Script 02: Migrate Docker Configuration to ZFS Pool
# ==============================================================================
# This script will:
# 1. Back up your existing docker-compose.yml file.
# 2. Update all volume paths in the docker-compose.yml to point to the
#    new unified ZFS mount point.
#
# Run this script AFTER you have successfully run '01-setup-zfs.sh'
# and have restored your data to the new mount point.
# ==============================================================================

# --- Configuration ---
# This should match the POOL_NAME you used in the first script.
POOL_NAME="potatostack"
MOUNT_POINT="/mnt/$POOL_NAME"
COMPOSE_FILE="docker-compose.yml"

# --- Safety Checks ---
set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Docker Compose Migration for ZFS ---"
echo

if [ "$(id -u)" -ne 0 ]; then
  echo "This script should be run as root to ensure permissions. Please use 'sudo bash $0'"
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: Could not find '$COMPOSE_FILE' in the current directory."
    echo "Please run this script from the same directory as your docker-compose.yml file."
    exit 1
fi

# --- User Instructions for Data Restoration ---
echo "--- Important Prerequisite: Data Restoration ---"
echo "Before proceeding, ensure you have copied your backed-up data into the new ZFS pool."
echo
echo "For example, you should have directories like:"
echo "  - $MOUNT_POINT/kopia/"
echo "  - $MOUNT_POINT/nextcloud/"
echo "  - $MOUNT_POINT/torrents/"
echo "  - $MOUNT_POINT/soulseek/"
echo "  - etc."
echo
echo "The script will now update your docker-compose.yml to use these new paths."
echo
read -p "Press [Enter] to continue once your data is restored."

# --- Backup and Update ---
BACKUP_FILE="${COMPOSE_FILE}.bak-$(date +%F_%H-%M-%S)"
echo "Backing up '$COMPOSE_FILE' to '$BACKUP_FILE'..."
cp "$COMPOSE_FILE" "$BACKUP_FILE"
echo "Backup created."
echo

echo "Updating Docker volume paths to point to '$MOUNT_POINT'..."

# Use sed to find and replace the old mount points.
# The '|' character is used as a delimiter to avoid issues with the '/' in file paths.
sed -i 's|/mnt/seconddrive|/mnt/potatostack|g' "$COMPOSE_FILE"
sed -i 's|/mnt/cachehdd|/mnt/potatostack|g' "$COMPOSE_FILE"

echo "Paths successfully updated in '$COMPOSE_FILE'."
echo

# --- Final Steps ---
echo "--- Migration Complete ---"
echo
echo "Your '$COMPOSE_FILE' has been modified to use the new ZFS storage pool."
echo
echo "Next steps:"
echo "1. Review the changes if you wish: 'diff $BACKUP_FILE $COMPOSE_FILE'"
echo "2. Restart your Docker stack to apply the changes:"
echo "   'docker-compose down'"
echo "   'docker-compose up -d'"
echo
echo "Your entire stack should now be running on the new, cache-enabled ZFS pool."
