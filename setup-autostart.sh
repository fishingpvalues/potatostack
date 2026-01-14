#!/bin/bash
################################################################################
# PotatoStack - Autostart & Hardening Setup
# Run with: sudo bash setup-autostart.sh
################################################################################

set -euo pipefail

echo "==================================================================="
echo "PotatoStack - Autostart & Security Hardening"
echo "==================================================================="

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Stack directory: $SCRIPT_DIR"
echo "Running as: $ACTUAL_USER"
echo "Home: $ACTUAL_HOME"
echo ""

# Security hardening
echo "[1/7] Hardening file permissions..."
if [ -f "$SCRIPT_DIR/.env" ]; then
	chmod 600 "$SCRIPT_DIR/.env"
	chown "$ACTUAL_USER:$ACTUAL_USER" "$SCRIPT_DIR/.env"
	echo "✓ .env file secured (600)"
else
	echo "⚠ No .env file found (will be created later)"
fi

chmod 644 "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
echo "✓ File permissions hardened"

# Configure Docker daemon security
echo "[2/7] Configuring Docker daemon security..."
mkdir -p /etc/docker
DAEMON_JSON="/etc/docker/daemon.json"

if [ ! -f "$DAEMON_JSON" ]; then
	cat >"$DAEMON_JSON" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "icc": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF
	echo "✓ Docker daemon.json created with security defaults"
else
	echo "⚠ daemon.json exists, skipping (manual review recommended)"
fi

# Enable automatic security updates
echo "[3/7] Configuring automatic security updates..."
if command -v apt-get >/dev/null 2>&1; then
	apt-get update -qq
	apt-get install -y -qq unattended-upgrades apt-listchanges 2>/dev/null || true

	cat >/etc/apt/apt.conf.d/50unattended-upgrades-custom <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

	cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
	echo "✓ Automatic security updates enabled"
else
	echo "⚠ apt not available, skipping auto-updates"
fi

# Configure log rotation
echo "[4/7] Configuring log rotation..."
cat >/etc/logrotate.d/potatostack <<'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
}
EOF
echo "✓ Log rotation configured"

# Set system resource limits
echo "[5/7] Configuring system resource limits..."
cat >/etc/security/limits.d/potatostack.conf <<'EOF'
*    soft    nofile    64000
*    hard    nofile    64000
root soft    nofile    64000
root hard    nofile    64000
EOF
echo "✓ System resource limits configured"

# Enable Docker on boot
echo "[6/7] Enabling Docker service on boot..."
systemctl enable docker
systemctl enable containerd
systemctl restart docker

# Verify Docker is enabled
if systemctl is-enabled docker >/dev/null 2>&1; then
	echo "✓ Docker enabled on boot"
else
	echo "✗ Failed to enable Docker"
	exit 1
fi

# Create systemd service file
echo "[7/7] Creating systemd service file..."
cat >/etc/systemd/system/potatostack.service <<EOF
[Unit]
Description=PotatoStack - Self-hosted stack services
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$ACTUAL_USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file created at /etc/systemd/system/potatostack.service"

# Reload systemd
systemctl daemon-reload

# Enable the service
systemctl enable potatostack.service

echo ""
echo "==================================================================="
echo "✓ Autostart & Security Hardening Complete!"
echo "==================================================================="
echo ""
echo "Security measures applied:"
echo "  ✓ File permissions hardened (.env = 600)"
echo "  ✓ Docker daemon security configured"
echo "  ✓ Automatic security updates enabled"
echo "  ✓ Log rotation configured"
echo "  ✓ Resource limits optimized"
echo "  ✓ Autostart on boot enabled"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status potatostack    # Check status"
echo "  sudo systemctl start potatostack     # Start now"
echo "  sudo systemctl stop potatostack      # Stop"
echo "  sudo systemctl disable potatostack   # Disable autostart"
echo ""
echo "Test with: sudo reboot"
echo ""
