#!/bin/bash
# Fix TUN device for Gluetun VPN
# Run with: sudo bash fix-tun.sh

set -e

echo "Loading TUN kernel module..."
modprobe tun

echo "Verifying TUN module is loaded..."
if lsmod | grep -q tun; then
  echo "✓ TUN module loaded successfully"
else
  echo "✗ TUN module failed to load"
  exit 1
fi

echo "Checking /dev/net/tun..."
if [ -e /dev/net/tun ]; then
  ls -la /dev/net/tun
  echo "✓ /dev/net/tun exists"
else
  echo "✗ /dev/net/tun does not exist"
  exit 1
fi

echo ""
echo "To make this persistent across reboots, add 'tun' to /etc/modules:"
echo "  echo 'tun' | sudo tee -a /etc/modules"
echo ""
echo "Now restart gluetun:"
echo "  docker restart gluetun"
