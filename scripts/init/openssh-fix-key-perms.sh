#!/bin/sh
# Fix SSH host key permissions on every container startup.
# LinuxServer.io openssh-server creates host keys with 0755 (inherited from
# the config volume's chmod -R 755 in init-storage.sh). sshd requires 0600
# on private keys or it refuses to load them and exits.
set -e

KEY_DIR="/config/ssh_host_keys"

if [ ! -d "$KEY_DIR" ]; then
    echo "[openssh-init] $KEY_DIR not found yet, skipping"
    exit 0
fi

find "$KEY_DIR" -type f -name "ssh_host_*" ! -name "*.pub" | while read -r key; do
    current=$(stat -c "%a" "$key" 2>/dev/null || stat -f "%Lp" "$key" 2>/dev/null)
    if [ "$current" != "600" ]; then
        chmod 600 "$key"
        echo "[openssh-init] Fixed permissions on $(basename "$key"): ${current} -> 600"
    fi
done

echo "[openssh-init] SSH host key permissions OK"
