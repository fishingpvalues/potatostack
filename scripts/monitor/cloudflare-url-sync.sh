#!/bin/bash
################################################################################
# Cloudflare URL Sync - Updates Homer config with current trycloudflare URL
# Run via cron: * * * * * /path/to/cloudflare-url-sync.sh
# Or as a systemd timer
################################################################################

set -euo pipefail

HOMER_CONFIG="/home/daniel/potatostack/config/homer/config.yml"
URL_FILE="/tmp/cloudflare-url.txt"

url=$(docker logs cloudflared 2>&1 | grep -o 'https://[^ ]*trycloudflare.com' | tail -1)

[ -z "$url" ] && exit 0

old_url=$(cat "$URL_FILE" 2>/dev/null || echo "")

[ "$url" = "$old_url" ] && exit 0

echo "$url" >"$URL_FILE"

if [ -n "$old_url" ]; then
	sed -i "s|${old_url}|${url}|g" "$HOMER_CONFIG"
else
	sed -i "s|__CLOUDFLARE_URL__|${url}|g" "$HOMER_CONFIG"
fi

echo "$(date): Updated Homer cloudflare URL to $url"
