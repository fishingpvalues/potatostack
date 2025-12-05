#!/bin/bash
################################################################################
# PotatoStack Swap File Manager
# Ensures swap file exists and is activated before Docker starts
################################################################################

set -e

SWAPFILE="/mnt/seconddrive/potatostack.swap"
SWAPSIZE_GB=3

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== PotatoStack Swap Manager ==="

# Check if swap already exists and is active
if swapon --show | grep -q "$SWAPFILE"; then
    echo -e "${GREEN}✓ Swap file already active: $SWAPFILE${NC}"
    swapon --show | grep "$SWAPFILE"
    exit 0
fi

# Check if mount point exists
if [ ! -d "/mnt/seconddrive" ]; then
    echo -e "${YELLOW}⚠ Warning: /mnt/seconddrive not mounted yet${NC}"
    echo "Waiting for disk mount..."
    sleep 5

    if [ ! -d "/mnt/seconddrive" ]; then
        echo "ERROR: /mnt/seconddrive still not available"
        exit 1
    fi
fi

# Check if swap file exists
if [ ! -f "$SWAPFILE" ]; then
    echo -e "${YELLOW}Creating swap file: $SWAPFILE (${SWAPSIZE_GB}GB)${NC}"
    fallocate -l ${SWAPSIZE_GB}G "$SWAPFILE"
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    echo -e "${GREEN}✓ Swap file created${NC}"
fi

# Activate swap
echo "Activating swap file: $SWAPFILE"
swapon "$SWAPFILE"
echo -e "${GREEN}✓ Swap activated${NC}"

# Add to /etc/fstab if not already present
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    echo -e "${GREEN}✓ Added swap file to /etc/fstab${NC}"
fi

# Show current swap status
echo ""
echo "Current swap status:"
swapon --show
free -h

echo ""
echo -e "${GREEN}=== Swap setup complete ===${NC}"
