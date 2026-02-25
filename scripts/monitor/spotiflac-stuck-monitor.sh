#!/bin/bash
################################################################################
# SpotiFLAC Stuck Download Monitor
#
# Detects when SpotiFLAC is stuck in an infinite retry loop: items show
# "downloading" status but is_downloading=false and no progress for >30min.
# Auto-restarts the container via docker restart.
################################################################################

set -euo pipefail

SPOTIFLAC_URL="${SPOTIFLAC_URL:-http://127.0.0.1:8097}"
STUCK_THRESHOLD_SECS="${STUCK_THRESHOLD_SECS:-1800}"  # 30 minutes
CHECK_INTERVAL="${CHECK_INTERVAL:-120}"                # 2 minutes
CONTAINER="${CONTAINER:-spotiflac}"

NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

_notify() {
    local title="$1" message="$2" priority="${3:-default}"
    local url="${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}"
    local auth_header=""
    [ -n "${NTFY_TOKEN:-}" ] && auth_header="-H Authorization: Bearer ${NTFY_TOKEN}"
    # shellcheck disable=SC2086
    curl -fsS -X POST "$url" \
        -H "Title: ${title}" \
        -H "Tags: spotiflac,warning" \
        -H "Priority: ${priority}" \
        ${auth_header:+-H "$auth_header"} \
        -d "${message}" >/dev/null 2>&1 || true
}

_check_stuck() {
    python3 - <<PYEOF
import json, urllib.request, sys, time

url = "${SPOTIFLAC_URL}/api/download/queue"
threshold = int("${STUCK_THRESHOLD_SECS}")

try:
    with urllib.request.urlopen(url, timeout=10) as r:
        data = json.loads(r.read())
except Exception as e:
    print(f"[SpotiFLAC Monitor] API unreachable: {e}", file=sys.stderr)
    sys.exit(0)  # Don't trigger restart if API is down

is_downloading = data.get("is_downloading", False)
queue = data.get("queue", [])
now = time.time()

# Only flag stuck if queue worker is idle AND downloads are stale
if is_downloading:
    sys.exit(0)

stuck = [
    x for x in queue
    if x["status"] == "downloading" and now - x.get("start_time", now) > threshold
]

if stuck:
    names = ", ".join(x["track_name"] for x in stuck[:3])
    print(f"[SpotiFLAC Monitor] STUCK: {len(stuck)} items >30min: {names}")
    sys.exit(1)

sys.exit(0)
PYEOF
}

echo "[SpotiFLAC Monitor] Started (threshold: ${STUCK_THRESHOLD_SECS}s, interval: ${CHECK_INTERVAL}s)"

while true; do
    if ! _check_stuck; then
        echo "[SpotiFLAC Monitor] Restarting ${CONTAINER}..."
        _notify "SpotiFLAC: stuck download detected" "Restarting container to clear retry loop." "high"
        docker restart "${CONTAINER}" || true
        sleep 60  # Wait for restart before next check
    fi
    sleep "${CHECK_INTERVAL}"
done
