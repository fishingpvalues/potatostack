#!/bin/bash
# Optional: Enable ZRAM swap for Le Potato (reduces HDD swap I/O)
# Usage: sudo ./scripts/setup-zram.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./scripts/setup-zram.sh)" >&2
  exit 1
fi

echo "Installing zram-tools..."
apt-get update -y
apt-get install -y zram-tools

echo "Configuring /etc/ztab (256–512MB recommended for 2GB RAM)..."
cat >/etc/ztab <<'ZTAB'
# swap  alg     mem_limit swap_priority  page-clusters  swappiness  streams  mountpoint
swap    lz4     512M      100            0              100         1        /dev/zram0
ZTAB

echo "Enabling ZRAM..."
systemctl enable --now zramswap.service

echo "ZRAM status:"
swapon --show
free -h

echo "ZRAM enabled. You may keep HDD swap as fallback or disable it (swapoff <file>)."
