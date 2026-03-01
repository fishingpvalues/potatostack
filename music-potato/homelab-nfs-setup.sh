#!/bin/bash
# Run this on the HOMELAB (potatostack server) to enable NFS exports
# so Le Potato can mount the music library without Samba
set -euo pipefail

LE_POTATO_SUBNET="${1:-192.168.1.0/24}"   # Your LAN subnet
MUSIC_PATH="/mnt/storage/media/music"

echo "Installing NFS kernel server on homelab..."
apt-get install -y nfs-kernel-server

echo "Adding NFS export..."
EXPORT_LINE="${MUSIC_PATH}  ${LE_POTATO_SUBNET}(ro,sync,no_subtree_check,no_root_squash)"
if ! grep -qF "$MUSIC_PATH" /etc/exports; then
  echo "$EXPORT_LINE" >> /etc/exports
  echo "Export added."
else
  echo "Export already exists."
fi

exportfs -ra
systemctl enable --now nfs-kernel-server

echo ""
echo "NFS exports active:"
exportfs -v

echo ""
echo "On Le Potato, mount with:"
echo "  mount HOMELAB_IP:${MUSIC_PATH} /mnt/music"
echo "Or add to /etc/fstab (see etc/fstab.snippet)"
