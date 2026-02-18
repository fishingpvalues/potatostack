#!/bin/bash
################################################################################
# Fix Docker Named Volume and Bind Mount Permissions
# Run this if services fail with permission errors on volumes
################################################################################

set -euo pipefail

SSD_BASE="/mnt/ssd/docker-data"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

echo "Fixing named volume permissions..."

# PostgreSQL (UID 999) - uses bind mount, handled by init-storage.sh

# Alertmanager (UID 65534)
docker run --rm -v potatostack_alertmanager-data:/data alpine chown -R 65534:65534 /data 2>/dev/null || true

# Grafana (UID 472)
docker run --rm -v potatostack_grafana-data:/data alpine chown -R 472:472 /data 2>/dev/null || true

echo "✓ Named volume permissions fixed"

echo "Fixing bind mount permissions..."

# Recyclarr (UID 1000) - needs proper ownership for /config/cache
if [ -d "${SSD_BASE}/recyclarr" ]; then
	echo "  Fixing recyclarr permissions..."
	chown -R "${PUID}:${PGID}" "${SSD_BASE}/recyclarr"
fi

# Notifiarr (UID 1000)
if [ -d "${SSD_BASE}/notifiarr" ]; then
	echo "  Fixing notifiarr permissions..."
	chown -R "${PUID}:${PGID}" "${SSD_BASE}/notifiarr"
fi

# Uptime-Kuma (UID 1000) - DISABLED
# if [ -d "${SSD_BASE}/uptime-kuma" ]; then
# 	echo "  Fixing uptime-kuma permissions..."
# 	chown -R "${PUID}:${PGID}" "${SSD_BASE}/uptime-kuma"
# fi

# Velld (UID 1000)
if [ -d "${SSD_BASE}/velld" ]; then
	echo "  Fixing velld permissions..."
	chown -R "${PUID}:${PGID}" "${SSD_BASE}/velld"
fi

# OpenSSH server host key permissions (LinuxServer.io creates them 0755; sshd needs 0600)
if docker inspect openssh-server >/dev/null 2>&1; then
	echo "  Fixing openssh-server host key permissions..."
	docker exec openssh-server sh -c '
		find /config/ssh_host_keys -name "ssh_host_*" ! -name "*.pub" -exec chmod 600 {} \; 2>/dev/null
		echo "  Fixed"
	' || true
fi

# Backrest SSH permissions
if [ -d "${SSD_BASE}/backrest/ssh" ]; then
	echo "  Fixing backrest SSH permissions..."
	chown -R root:root "${SSD_BASE}/backrest/ssh"
	chmod 700 "${SSD_BASE}/backrest/ssh"
	[ -f "${SSD_BASE}/backrest/ssh/id_ed25519" ] && chmod 600 "${SSD_BASE}/backrest/ssh/id_ed25519"
	[ -f "${SSD_BASE}/backrest/ssh/id_ed25519.pub" ] && chmod 644 "${SSD_BASE}/backrest/ssh/id_ed25519.pub"
	[ -f "${SSD_BASE}/backrest/ssh/config" ] && chmod 600 "${SSD_BASE}/backrest/ssh/config"
	[ -f "${SSD_BASE}/backrest/ssh/known_hosts" ] && chmod 600 "${SSD_BASE}/backrest/ssh/known_hosts"
fi

echo "✓ Bind mount permissions fixed"
