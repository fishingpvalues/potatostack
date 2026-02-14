# Backrest Backup Alerting Setup

This directory contains the notification hooks and monitoring scripts for Backrest backup alerting.

## Components

### 1. Hook Script: `backrest-notify.sh`
Universal notification hook that sends alerts to ntfy for all Backrest events.

**Features:**
- ✅ Supports all Backrest hook events (start, success, error, warning, prune, check, forget)
- ✅ Automatic priority mapping (errors = urgent, warnings = high, success = default)
- ✅ Topic routing (critical/warning/info)
- ✅ Emoji indicators for quick visual identification
- ✅ Rich context (duration, stats, error messages)

**Environment Variables:**
```bash
NTFY_INTERNAL_URL      # ntfy server URL (default: http://ntfy:80)
NTFY_TOPIC_INFO        # Info topic (default: potatostack-info)
NTFY_TOPIC_WARNING     # Warning topic (default: potatostack-warning)
NTFY_TOPIC_CRITICAL    # Critical topic (default: potatostack-critical)
NTFY_DEFAULT_TAGS     # Default tags (default: potatostack,backup)
NTFY_TOKEN           # Optional authentication token
```

**Backrest Template Variables (passed as environment):**
```bash
BACKREST_EVENT        # Event type (e.g., CONDITION_SNAPSHOT_ERROR)
BACKREST_TASK        # Task name
BACKREST_REPO         # Repository ID
BACKREST_PLAN         # Plan ID
BACKREST_ERROR        # Error message (if applicable)
BACKREST_SUMMARY      # Event summary
BACKREST_DURATION     # Operation duration
BACKREST_SNAPSHOT_STATS # Backup statistics (JSON)
```

## Setup Instructions

### Step 1: Restart backrest with new configuration

```bash
docker compose up -d backrest
```

This will:
- Mount the hook script at `/hooks/backrest-notify.sh`
- Add ntfy environment variables to backrest container

### Step 2: Configure Hooks in Backrest UI

1. **Open Backrest UI:**
   ```bash
   http://localhost:9898
   ```

2. **Navigate to Settings → Hooks**

3. **Add Hooks** for each event you want to monitor:

   **Critical Errors (Recommended):**
   ```
   Name: Critical Error Alerts
   Action: /hooks/backrest-notify.sh
   Trigger Events:
     - CONDITION_SNAPSHOT_ERROR
     - CONDITION_PRUNE_ERROR
     - CONDITION_CHECK_ERROR
     - CONDITION_FORGET_ERROR
     - CONDITION_ANY_ERROR
   On Error: Continue (ON_ERROR_IGNORE)
   Template Variables:
     BACKREST_EVENT={{ .EventName .Event }}
     BACKREST_TASK={{ .Task }}
     BACKREST_REPO={{ .Repo.Id }}
     BACKREST_PLAN={{ .Plan.Id }}
     BACKREST_ERROR={{ .Error }}
     BACKREST_SUMMARY={{ .Summary }}
   ```

   **Warnings (Recommended):**
   ```
   Name: Warning Alerts
   Action: /hooks/backrest-notify.sh
   Trigger Events:
     - CONDITION_SNAPSHOT_WARNING
   On Error: Continue
   Template Variables: Same as above
   ```

   **Success/Info (Recommended):**
   ```
   Name: Backup Success Alerts
   Action: /hooks/backrest-notify.sh
   Trigger Events:
     - CONDITION_SNAPSHOT_START
     - CONDITION_SNAPSHOT_SUCCESS
     - CONDITION_PRUNE_SUCCESS
     - CONDITION_CHECK_SUCCESS
     - CONDITION_FORGET_SUCCESS
   On Error: Continue
   Template Variables:
     BACKREST_EVENT={{ .EventName .Event }}
     BACKREST_TASK={{ .Task }}
     BACKREST_REPO={{ .Repo.Id }}
     BACKREST_PLAN={{ .Plan.Id }}
     BACKREST_SUMMARY={{ .Summary }}
     BACKREST_DURATION={{ .FormatDuration .Duration }}
     BACKREST_SNAPSHOT_STATS={{ .JsonMarshal .SnapshotStats }}
   ```

### Step 3: Verify Backup Monitor

The `backup-monitor.sh` script now includes Backrest staleness detection:

```bash
# Check status
docker logs backup-monitor --tail 20

# Should see:
# Checking backrest snapshot: danielhomelab
# ✓ Backup OK: danielhomelab (age 43200s)
```

**Settings:**
- Max age: 24 hours (configurable via `BACKUP_MAX_AGE_HOURS`)
- Check interval: 3600 seconds (1 hour, configurable via `BACKUP_MONITOR_INTERVAL`)

### Step 4: Test Notifications

**Trigger a manual backup:**
1. Open Backrest UI
2. Navigate to Plans → Backup
3. Click "Run Now"

**Verify notifications:**
```bash
# Check ntfy logs
docker logs ntfy --tail 20

# Or test hook script manually in container
docker exec backrest sh -c '
  BACKREST_EVENT="CONDITION_SNAPSHOT_START"
  BACKREST_TASK="Test Backup"
  BACKREST_REPO="danielhomelab"
  BACKREST_PLAN="Backup"
  BACKREST_SUMMARY="Test backup started"
  /hooks/backrest-notify.sh
'
```

## Alerting Matrix

| Event | Priority | Topic | Emoji | Example Message |
|--------|-----------|--------|--------|----------------|
| Snapshot Start | default | potatostack-info | 🔄 | Backup Started: Backup |
| Snapshot Success | default | potatostack-info | ✅ | Backup Completed: Backup |
| Snapshot Error | urgent | potatostack-critical | 🚨 | Backup Failed: Backup |
| Snapshot Warning | high | potatostack-warning | ⚠️ | Backup Warning: Backup |
| Prune Success | default | potatostack-info | ✅ | Prune Completed |
| Prune Error | urgent | potatostack-critical | 🚨 | Prune Failed |
| Check Success | default | potatostack-info | ✅ | Check Passed |
| Check Error | urgent | potatostack-critical | 🚨 | Check Failed |
| Forget Success | default | potatostack-info | ✅ | Forget Completed |
| Forget Error | urgent | potatostack-critical | 🚨 | Forget Failed |
| Staleness | high | potatostack-warning | ⚠️ | Backup Stale: No backup for 24h |

## Troubleshooting

### Hook not firing

1. **Check hook script is mounted:**
   ```bash
   docker exec backrest ls -la /hooks/backrest-notify.sh
   ```

2. **Check environment variables:**
   ```bash
   docker exec backrest env | grep NTFY
   ```

3. **Test script manually:**
   ```bash
   docker exec backrest bash -c '
     BACKREST_EVENT="CONDITION_SNAPSHOT_SUCCESS" \
     BACKREST_TASK="Test" \
     BACKREST_REPO="test" \
     BACKREST_PLAN="test" \
     BACKREST_SUMMARY="Test success" \
     /hooks/backrest-notify.sh
   '
   ```

4. **Check Backrest logs:**
   ```bash
   docker logs backrest --tail 50 | grep -i hook
   ```

### Notifications not received

1. **Check ntfy is running:**
   ```bash
   docker ps | grep ntfy
   ```

2. **Test ntfy directly:**
   ```bash
   curl -X POST http://localhost:8060/potatostack-info \
     -H "Title: Test" \
     -d "Test message"
   ```

3. **Check network connectivity:**
   ```bash
   docker exec backrest ping -c 1 ntfy
   ```

### Backup monitor not detecting backrest

1. **Check config path:**
   ```bash
   ls -la /mnt/ssd/docker-data/backrest/config/config.json
   ```

2. **Check oplog exists:**
   ```bash
   ls -la /mnt/ssd/docker-data/backrest/data/oplog/
   ```

3. **Check monitor logs:**
   ```bash
   docker logs backup-monitor --tail 30
   ```

## Advanced Configuration

### Change staleness threshold

Edit `.env`:
```bash
BACKUP_MAX_AGE_HOURS=48  # Default is 24
```

Restart backup-monitor:
```bash
docker compose up -d backup-monitor
```

### Custom ntfy topics

Edit `.env`:
```bash
NTFY_TOPIC_INFO=potatostack-backups
NTFY_TOPIC_WARNING=potatostack-alerts
NTFY_TOPIC_CRITICAL=potatostack-emergency
```

### Add authentication to ntfy

Edit `.env`:
```bash
NTFY_TOKEN=your_access_token_here
```

### Monitoring multiple backrest repos

Update `scripts/monitor/backup-monitor.sh` to add more repo checks:
```bash
check_backrest_snapshot "danielhomelab"
check_backrest_snapshot "second-repo"
check_backrest_snapshot "third-repo"
```

## References

- [Backrest Hooks Documentation](https://garethgeorge.github.io/backrest/docs/hooks)
- [Backrest Command Hook Examples](https://garethgeorge.github.io/backrest/cookbooks/command-hook-examples)
- [ntfy Documentation](https://ntfy.sh/)
