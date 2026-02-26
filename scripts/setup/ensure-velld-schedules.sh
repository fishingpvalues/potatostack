#!/bin/bash
# ensure-velld-schedules.sh - Re-enable Velld backup schedules if they are missing/disabled
# Run this after velld-api starts if schedules get lost (e.g. after DB reset or update)
set -euo pipefail

VELLD_DB="${VELLD_DB:-/mnt/ssd/docker-data/velld/velld.db}"

if [ ! -f "$VELLD_DB" ]; then
  echo "ERROR: Velld DB not found at $VELLD_DB"
  exit 1
fi

python3 - "$VELLD_DB" <<'PYEOF'
import sys, sqlite3, uuid
from datetime import datetime, timezone

db_path = sys.argv[1]
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Get all connection IDs by name
cur.execute("SELECT id, name FROM connections")
connections = {name: cid for cid, name in cur.fetchall()}

if not connections:
    print("No connections found in velld DB - skipping")
    sys.exit(0)

# Desired schedules: name -> (6-field cron, retention_days)
SCHEDULES = {
    "postgresql - postgres": ("0 0 2 * * *", 7),
    "redis - redis-cache":   ("0 30 2 * * *", 7),
    "mongodb - mongo":       ("0 0 3 * * *", 7),
}

now = datetime.now(timezone.utc).isoformat()
changed = 0

for name, (cron, retention) in SCHEDULES.items():
    conn_id = connections.get(name)
    if not conn_id:
        print(f"WARNING: Connection '{name}' not found, skipping")
        continue

    # Check if schedule already exists and is enabled
    cur.execute("SELECT id, enabled, cron_schedule FROM backup_schedules WHERE connection_id = ?", (conn_id,))
    row = cur.fetchone()

    if row is None:
        sched_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO backup_schedules
            (id, connection_id, enabled, cron_schedule, retention_days, created_at, updated_at)
            VALUES (?, ?, 1, ?, ?, ?, ?)
        """, (sched_id, conn_id, cron, retention, now, now))
        print(f"ADDED schedule for '{name}': {cron}")
        changed += 1
    elif not row[1] or row[2] != cron:
        cur.execute("""
            UPDATE backup_schedules SET enabled = 1, cron_schedule = ?, updated_at = ?
            WHERE id = ?
        """, (cron, now, row[0]))
        print(f"FIXED schedule for '{name}': {cron} (was: enabled={row[1]}, cron={row[2]})")
        changed += 1
    else:
        print(f"OK: '{name}' already has schedule {cron}")

conn.commit()
conn.close()

if changed > 0:
    print(f"\n{changed} schedule(s) updated - restart velld-api to apply")
    sys.exit(2)  # exit 2 = changes made, restart needed
else:
    print("\nAll schedules OK")
    sys.exit(0)
PYEOF

exit_code=$?

if [ $exit_code -eq 2 ]; then
    echo "Restarting velld-api to load updated schedules..."
    docker compose restart velld-api
    echo "Done"
fi
