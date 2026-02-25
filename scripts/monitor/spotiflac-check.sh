#!/bin/bash
# SpotiFLAC stuck-download check + auto-restart
# Called by dagu every 5 minutes.
# Exits 0 if OK, exits 1 if stuck (also triggers docker restart).

set -euo pipefail

CONTAINER="${CONTAINER:-spotiflac}"
STUCK_THRESHOLD="${STUCK_THRESHOLD:-1800}"  # 30 minutes

DATA=$(docker exec "${CONTAINER}" wget -qO- http://127.0.0.1:8080/api/download/queue 2>/dev/null) || {
    echo "[spotiflac-check] API unreachable - skipping"
    exit 0
}

RESULT=$(echo "$DATA" | python3 -c "
import json, sys, time

data = json.loads(sys.stdin.read())
threshold = int('${STUCK_THRESHOLD}')

if data.get('is_downloading'):
    print('ok')
    sys.exit(0)

now = time.time()
stuck = [x for x in data.get('queue', [])
         if x['status'] == 'downloading' and now - x.get('start_time', now) > threshold]

if not stuck:
    total = len(data.get('queue', []))
    print(f'ok ({total} queued)')
    sys.exit(0)

names = ', '.join(x['track_name'] for x in stuck[:3])
print(f'stuck:{len(stuck)}:{names}')
sys.exit(1)
" 2>&1) || true

if [[ "$RESULT" == stuck:* ]]; then
    echo "[spotiflac-check] STUCK detected: ${RESULT#stuck:*:} - restarting..."
    docker restart "${CONTAINER}"
    echo "[spotiflac-check] Restarted ${CONTAINER}"
    exit 1
fi

echo "[spotiflac-check] ${RESULT}"
