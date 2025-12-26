#!/bin/bash
################################################################################
# Install abraunegg/onedrive Client (Native Linux, not Docker)
# For Le Potato (ARM) - Build from source
################################################################################

set -e

echo "================================"
echo "OneDrive Client Installation"
echo "abraunegg/onedrive for Linux"
echo "================================"
echo ""

# Check system resources
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
AVAILABLE=$((TOTAL_MEM + TOTAL_SWAP))

echo "System Resources:"
echo "  RAM: ${TOTAL_MEM}MB"
echo "  Swap: ${TOTAL_SWAP}MB"
echo "  Total Available: ${AVAILABLE}MB"
echo ""

if [ "$AVAILABLE" -lt 2048 ]; then
    echo "⚠ WARNING: Build requires minimum 2GB (RAM + Swap)"
    echo "  Current: ${AVAILABLE}MB available"
    echo "  Recommendation: Ensure swap is enabled (docker compose up -d runs storage-init)"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install build dependencies
echo ""
echo "Installing build dependencies..."
sudo apt install -y \
    build-essential \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    pkg-config \
    git \
    curl \
    libsystemd-dev \
    libdbus-1-dev \
    libnotify-dev

# Install D compiler (DMD)
echo ""
echo "Installing DMD compiler..."
if [ ! -f ~/dlang/install.sh ]; then
    curl -fsS https://dlang.org/install.sh -o ~/dlang-install.sh
    chmod +x ~/dlang-install.sh
    ~/dlang-install.sh dmd
else
    echo "✓ D compiler installation script already exists"
fi

# Clone onedrive repository
echo ""
echo "Cloning onedrive repository..."
REPO_DIR="$HOME/onedrive-client"
if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists at $REPO_DIR"
    read -p "Remove and re-clone? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$REPO_DIR"
        git clone https://github.com/abraunegg/onedrive.git "$REPO_DIR"
    fi
else
    git clone https://github.com/abraunegg/onedrive.git "$REPO_DIR"
fi

cd "$REPO_DIR"

# Activate D compiler
echo ""
echo "Activating D compiler..."
source ~/dlang/dmd-*/activate

# Configure and build
echo ""
echo "Configuring build..."
./configure

echo ""
echo "Building onedrive client (this may take 5-10 minutes)..."
make clean
make

# Install
echo ""
echo "Installing onedrive client..."
sudo make install

# Deactivate compiler
deactivate 2>/dev/null || true

# Verify installation
echo ""
echo "Verifying installation..."
if command -v onedrive >/dev/null 2>&1; then
    echo "✓ onedrive client installed successfully"
    onedrive --version
else
    echo "✗ Installation failed"
    exit 1
fi

echo ""
echo "================================"
echo "Installation Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Run the setup script: ./setup-onedrive-sync.sh"
echo "2. Follow authentication prompts"
echo "3. Wait for sync to complete"
echo "4. Run migration script: ./migrate-onedrive-to-syncthing.sh"
echo ""
