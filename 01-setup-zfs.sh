#!/bin/bash

# ==============================================================================
# Script 01: ZFS Pool Creation and Tuning for PotatoStack
# ==============================================================================
# This script will:
# 1. Install ZFS utilities on your Armbian system.
# 2. Configure ZFS to use a limited amount of RAM (256MB), which is
#    critical for a low-memory device like the Le Potato.
# 3. Guide you through identifying your drives.
# 4. Create a new ZFS storage pool from your main drive.
# 5. Add your faster cache drive as a caching device (L2ARC) to the pool.
#
# ⚠️ WARNING: THIS SCRIPT WILL WIPE THE DRIVES YOU SELECT.
#    HAVE A FULL BACKUP BEFORE YOU PROCEED.
# ==============================================================================

# --- Step 1: Configuration ---
# TODO: EDIT THESE VARIABLES TO MATCH YOUR SYSTEM!
# Use 'lsblk -o NAME,SIZE,MODEL' to find your drive device names.
#
# Example:
# MAIN_DRIVE="/dev/sda"
# CACHE_DRIVE="/dev/sdb"

MAIN_DRIVE="/dev/sdX"   # Your large, primary HDD (e.g., /dev/sda)
CACHE_DRIVE="/dev/sdY" # Your smaller, faster cache drive/SSD (e.g., /dev/sdb)
POOL_NAME="potatostack"  # The name for your new unified storage pool.
MOUNT_POINT="/mnt/$POOL_NAME" # The location where your new storage will be accessible.

# --- Step 2: Safety Checks & Prerequisities ---
set -e # Exit immediately if a command exits with a non-zero status.

echo "--- ZFS Setup for PotatoStack ---"
echo

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo bash $0'"
  exit 1
fi

if [ "$MAIN_DRIVE" == "/dev/sdX" ] || [ "$CACHE_DRIVE" == "/dev/sdY" ]; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! ERROR: Please edit this script to set your drive IDs. !!!"
  echo "!!! MAIN_DRIVE is currently set to: $MAIN_DRIVE            !!!"
  echo "!!! CACHE_DRIVE is currently set to: $CACHE_DRIVE           !!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1
fi

echo "Installing ZFS utilities (zfsutils-linux)..."
apt-get update > /dev/null
apt-get install -y zfsutils-linux

echo
echo "--- Tuning ZFS for Low RAM (256MB Limit) ---"
# This is CRITICAL for the Le Potato's 2GB of RAM.
# It prevents ZFS from using too much memory for its cache (ARC).
cat << EOF > /etc/modprobe.d/zfs.conf
# Limit ZFS Adaptive Replacement Cache (ARC) to 256MB
options zfs zfs_arc_max=268435456
EOF

# Reload kernel modules to apply the change
modprobe -r zfs
modprobe zfs

echo "ZFS RAM limit has been configured."
echo

# --- Step 3: Drive Confirmation ---
echo "--- Drive Configuration ---"
echo "Main Drive (will be wiped):   $MAIN_DRIVE"
echo "Cache Drive (will be wiped):  $CACHE_DRIVE"
echo "Pool will be named:           '$POOL_NAME'"
echo "Pool will be mounted at:      '$MOUNT_POINT'"
echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "You are about to ERASE ALL DATA on $MAIN_DRIVE and $CACHE_DRIVE."
echo "Make sure you have a complete backup of all data on both drives."
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo

read -p "Type 'ERASE' and press [Enter] to continue, or anything else to abort: " CONFIRMATION
if [ "$CONFIRMATION" != "ERASE" ]; then
    echo "Aborted by user."
    exit 0
fi

echo "User confirmed. Proceeding with ZFS pool creation..."
echo

# --- Step 4: ZFS Pool Creation ---
echo "Creating ZFS pool '$POOL_NAME' from main drive $MAIN_DRIVE..."
# -f: force, required to overwrite existing partitions on the drive.
# -o ashift=12: optimizes for 4K sector drives, which is standard for most modern HDDs.
# -m "$MOUNT_POINT": sets the mount point for the root of the pool.
zpool create -f -o ashift=12 -m "$MOUNT_POINT" "$POOL_NAME" "$MAIN_DRIVE"

echo "Pool '$POOL_NAME' created successfully."
echo

echo "Adding $CACHE_DRIVE as a cache device (L2ARC) to the pool..."
zpool add -f "$POOL_NAME" cache "$CACHE_DRIVE"
echo "Cache device added successfully."
echo

# --- Step 5: Verification ---
echo "--- Verification ---"
echo "ZFS pool status:"
zpool status "$POOL_NAME"
echo

echo "ZFS filesystems and mount points:"
zfs list -o name,mountpoint,mounted
echo

echo "--- Script Finished ---"
echo "Your new ZFS storage pool '$POOL_NAME' is ready and mounted at $MOUNT_POINT."
echo "You can now restore your backed-up data into subdirectories inside $MOUNT_POINT."
echo "Next, run the '02-migrate-and-update-docker.sh' script."
