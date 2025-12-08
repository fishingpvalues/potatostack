#!/bin/bash
# Setup 2GB swap file for Le Potato to prevent OOM kills
# Run as root: sudo bash setup-swap.sh

set -e

SWAP_FILE="/swapfile"
SWAP_SIZE="2G"

echo "=== Le Potato Swap Setup ==="
echo "Creating ${SWAP_SIZE} swap file at ${SWAP_FILE}..."

# Check if swap already exists
if [ -f "$SWAP_FILE" ]; then
    echo "Swap file already exists at $SWAP_FILE"
    swapon --show | grep "$SWAP_FILE" && echo "Swap is active" || echo "Swap exists but not active"
    exit 0
fi

# Create swap file
echo "Allocating swap file..."
fallocate -l $SWAP_SIZE $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1M count=2048

# Set permissions
chmod 600 $SWAP_FILE

# Setup swap
mkswap $SWAP_FILE

# Enable swap
swapon $SWAP_FILE

# Verify
echo "Swap status:"
swapon --show
free -h

# Make persistent across reboots
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    echo "Added swap to /etc/fstab for persistence"
fi

# Optimize swappiness for SBC (reduce swap usage)
echo "Setting vm.swappiness=10 (use RAM first, swap as last resort)"
sysctl vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

echo ""
echo "✅ Swap setup complete!"
echo "   Total RAM: $(free -h | grep Mem: | awk '{print $2}')"
echo "   Swap: $(free -h | grep Swap: | awk '{print $2}')"
echo ""
echo "Monitor with: free -h"
