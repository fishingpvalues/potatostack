#!/bin/bash
################################################################################
# Install OneDrive Client (Simple - Precompiled Package)
# Ubuntu 24.04 has onedrive 2.4.25 with ARM64 support
################################################################################

set -e

echo "================================"
echo "OneDrive Client Installation"
echo "Using Ubuntu package (ARM64)"
echo "================================"
echo ""

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install onedrive
echo ""
echo "Installing onedrive package..."
sudo apt install -y onedrive

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
echo "Installed from: Ubuntu 24.04 universe repository"
echo "Version: 2.4.25-1build5 (ARM64)"
echo ""
echo "Next step: Run ./setup-onedrive-sync.sh"
echo ""
