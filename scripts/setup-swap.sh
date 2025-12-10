#!/bin/bash
################################################################################
# PotatoStack Swap Configuration Script
# Configures optimal swap settings for Le Potato (2GB RAM) devices
################################################################################
# USAGE:
#   sudo ./scripts/setup-swap.sh
################################################################################

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    echo "Please use: sudo ./scripts/setup-swap.sh"
    exit 1
fi

# Check if on Le Potato (ARM64)
if ! grep -q "Le Potato" /proc/device-tree/model 2>/dev/null; then
    echo "Warning: This script is optimized for Le Potato (ARM64) devices"
    echo "Continuing anyway..."
fi

# Check if on ARM64
if ! uname -m | grep -q "aarch64"; then
    echo "Warning: This script is optimized for ARM64 architecture"
    echo "Continuing anyway..."
fi

# Check available memory
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
TOTAL_MEM_GB=$((TOTAL_MEM_MB / 1024))

echo "======================================"
echo "  PotatoStack Swap Configuration"
echo "  $(date)"
echo "======================================"
echo ""
echo "Detected system:"
echo "  - Total Memory: ${TOTAL_MEM_GB}GB (${TOTAL_MEM_MB}MB)"
echo "  - Architecture: $(uname -m)"
echo ""

# Calculate recommended swap size
# For 2GB RAM systems: 2GB swap (1:1 ratio)
if [ "$TOTAL_MEM_GB" -eq 2 ]; then
    RECOMMENDED_SWAP_GB=2
    RECOMMENDED_SWAP_MB=$((RECOMMENDED_SWAP_GB * 1024))
    RECOMMENDED_SWAP_KB=$((RECOMMENDED_SWAP_MB * 1024))
    echo "Recommended swap size for 2GB RAM: ${RECOMMENDED_SWAP_GB}GB"
elif [ "$TOTAL_MEM_GB" -lt 2 ]; then
    RECOMMENDED_SWAP_GB=1
    RECOMMENDED_SWAP_MB=$((RECOMMENDED_SWAP_GB * 1024))
    RECOMMENDED_SWAP_KB=$((RECOMMENDED_SWAP_MB * 1024))
    echo "Recommended swap size for <2GB RAM: ${RECOMMENDED_SWAP_GB}GB"
else
    RECOMMENDED_SWAP_GB=$((TOTAL_MEM_GB * 2))
    RECOMMENDED_SWAP_MB=$((RECOMMENDED_SWAP_GB * 1024))
    RECOMMENDED_SWAP_KB=$((RECOMMENDED_SWAP_MB * 1024))
    echo "Recommended swap size: ${RECOMMENDED_SWAP_GB}GB (2:1 ratio with RAM)"
fi
echo ""

# Check current swap status
echo "Current swap status:"
if swapon --show | grep -q swap; then
    CURRENT_SWAP=$(free | grep Swap | awk '{print $2}')
    CURRENT_SWAP_MB=$((CURRENT_SWAP / 1024))
    echo "  - Swap is active: ${CURRENT_SWAP_MB}MB"
else
    echo "  - No swap configured"
fi
echo ""

# Configure vm.swappiness
echo "Configuring vm.swappiness..."
echo "  - Setting vm.swappiness to 10 (conservative, prefer RAM over swap)"
sysctl vm.swappiness=10

# Make the setting persistent
if [ -f /etc/sysctl.conf ]; then
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        echo "  - Added to /etc/sysctl.conf"
    else
        sed -i 's/^vm\.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
        echo "  - Updated in /etc/sysctl.conf"
    fi
else
    echo "  - Warning: /etc/sysctl.conf not found"
fi
echo ""

# Configure swappiness for zram if present
if [ -f /sys/block/zram0/disksize ]; then
    echo "Configuring zram swappiness..."
    echo "  - Setting zram swappiness to 100 (aggressively use zram)"
    sysctl vm.swappiness=100
    echo "vm.swappiness=100" >> /etc/sysctl.conf
    echo "  - Added to /etc/sysctl.conf"
    echo ""
fi

# Check if we need to create a swap file
if [ "$(free | grep Swap | awk '{print $2}')" -eq 0 ]; then
    echo "No swap configured. Creating swap file..."

    # Find available disk space
    AVAILABLE_ROOT=$(df / | awk 'NR==2 {print $4}')
    AVAILABLE_ROOT_KB=$((AVAILABLE_ROOT * 1024))

    if [ "$AVAILABLE_ROOT_KB" -lt "$RECOMMENDED_SWAP_KB" ]; then
        echo "  - Warning: Not enough space on root partition"
        echo "  - Available: $((AVAILABLE_ROOT_KB / 1024 / 1024))GB"
        echo "  - Recommended: $RECOMMENDED_SWAP_GB GB"
        echo "  - Using maximum available space instead"
        SWAP_SIZE_KB=$AVAILABLE_ROOT_KB
        SWAP_SIZE_MB=$((SWAP_SIZE_KB / 1024))
        SWAP_SIZE_GB=$((SWAP_SIZE_MB / 1024))
    else
        SWAP_SIZE_KB=$RECOMMENDED_SWAP_KB
        SWAP_SIZE_MB=$RECOMMENDED_SWAP_MB
        SWAP_SIZE_GB=$RECOMMENDED_SWAP_GB
    fi

    # Create swap file
    echo "Creating ${SWAP_SIZE_GB}GB swap file at /swapfile..."
    fallocate -l ${SWAP_SIZE_KB}K /swapfile

    # Set permissions
    chmod 600 /swapfile

    # Format as swap
    mkswap /swapfile

    # Enable swap
    swapon /swapfile

    # Make persistent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
        echo "  - Added to /etc/fstab"
    fi

    echo "  - Swap file created and activated"
    echo ""
else
    echo "Swap already configured. Skipping swap file creation."
    echo ""
fi

# Verify settings
echo "Verifying configuration..."
echo ""

# Check vm.swappiness
CURRENT_SWAPPINESS=$(sysctl vm.swappiness | awk '{print $3}')
echo "vm.swappiness: $CURRENT_SWAPPINESS"
if [ "$CURRENT_SWAPPINESS" -eq 10 ]; then
    echo "  ✓ Correct (10 for swap file)"
elif [ "$CURRENT_SWAPPINESS" -eq 100 ]; then
    echo "  ✓ Correct (100 for zram)"
else
    echo "  ⚠ Warning: Unexpected value"
fi

# Check swap status
SWAP_TOTAL=$(free | grep Swap | awk '{print $2}')
SWAP_TOTAL_MB=$((SWAP_TOTAL / 1024))
echo "Swap total: ${SWAP_TOTAL_MB}MB"
if [ "$SWAP_TOTAL_MB" -gt 0 ]; then
    echo "  ✓ Swap is active"
else
    echo "  ✗ No swap active"
fi

# Check memory usage
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED=$(free | grep Mem | awk '{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
echo "Memory usage: ${MEM_PERCENT}%"

# Check swap usage
SWAP_USED=$(free | grep Swap | awk '{print $3}')
if [ "$SWAP_USED" -gt 0 ]; then
    SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
    echo "Swap usage: ${SWAP_PERCENT}%"
else
    echo "Swap usage: 0%"
fi

echo ""
echo "======================================"
echo "  Configuration Complete"
echo "======================================"
echo ""
echo "Summary:"
echo "  - vm.swappiness: $CURRENT_SWAPPINESS"
echo "  - Swap size: ${SWAP_TOTAL_MB}MB"
echo "  - Memory usage: ${MEM_PERCENT}%"
echo ""
echo "Recommendations:"
echo "  1. Monitor system performance with: free -h"
echo "  2. Check swap usage with: vmstat 1"
echo "  3. Run health checks with: ./scripts/health-check.sh"
echo ""
echo "For optimal performance on Le Potato:"
echo "  - Keep memory usage < 80%"
echo "  - Keep swap usage < 50% (prefer adding more RAM)"
echo ""