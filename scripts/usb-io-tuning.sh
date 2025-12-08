#!/bin/bash
# USB I/O tuning for Le Potato (optional): disable autosuspend and set scheduler
# Usage: sudo ./scripts/usb-io-tuning.sh [--persist]

set -euo pipefail

PERSIST=false
if [[ "${1:-}" == "--persist" ]]; then
  PERSIST=true
fi

echo "Disabling USB autosuspend for active USB storage devices..."
for dev in /sys/bus/usb/devices/*/power/control; do
  if grep -qE "/host/|usb-storage|uas" "${dev%/power/control}/uevent" 2>/dev/null || true; then
    echo on > "$dev" || true
  fi
done

echo "Setting I/O scheduler to 'deadline' for HDDs (if available)..."
for disk in /sys/block/sd*/queue/scheduler; do
  if [ -f "$disk" ]; then
    echo deadline > "$disk" 2>/dev/null || true
  fi
done

if $PERSIST; then
  echo "Installing udev rule to persist settings across reboots..."
  cat >/etc/udev/rules.d/80-usb-autosuspend.rules <<'RULE'
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", RUN+="/bin/sh -c 'echo on > /sys$env{DEVPATH}/power/control'"
RULE
  udevadm control --reload-rules && udevadm trigger || true
  echo "Udev rule installed."
else
  echo "Run with --persist to install a udev rule for autosuspend=off."
fi

echo "USB I/O tuning applied."

