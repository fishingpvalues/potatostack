#!/bin/sh
################################################################################
# Aria2 on-download-error hook — reference copy
# The LIVE version is written to /config/ at container startup by aria2-init.sh
# with the ntfy IP baked in. This file is NOT mounted into the container.
#
# Args: $1=GID $2=num_files $3=file_path
################################################################################

GID="${1:-}"
FILE_PATH="${3:-}"
FILE_NAME=$(basename "${FILE_PATH:-unknown}")
LOG_FILE="/config/aria2-notifications.log"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

_ip=$(nslookup ntfy 127.0.0.11 2>/dev/null | tr ' \t' '\n' \
  | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' \
  | grep -v '127\.0\.0\.11' | head -1 || true)
NTFY_URL=${_ip:+http://${_ip}:80}
NTFY_URL=${NTFY_URL:-${NTFY_INTERNAL_URL:-http://ntfy:80}}

printf '[%s] error: GID=%s path=%s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$GID" "$FILE_PATH" >>"$LOG_FILE"

if command -v curl >/dev/null 2>&1; then
  if [ -n "$NTFY_TOKEN" ]; then
    curl -fsS -X POST "${NTFY_URL}/${NTFY_TOPIC}" \
      -H "Title: Download Error" -H "Tags: x,aria2" -H "Priority: high" \
      -H "Authorization: Bearer ${NTFY_TOKEN}" \
      -d "${FILE_NAME:-unknown}" >>"$LOG_FILE" 2>&1 || true
  else
    curl -fsS -X POST "${NTFY_URL}/${NTFY_TOPIC}" \
      -H "Title: Download Error" -H "Tags: x,aria2" -H "Priority: high" \
      -d "${FILE_NAME:-unknown}" >>"$LOG_FILE" 2>&1 || true
  fi
fi
