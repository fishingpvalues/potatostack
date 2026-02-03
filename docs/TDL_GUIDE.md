# TDL (Telegram Downloader) Guide

TDL downloads videos from your Telegram Saved Messages automatically.

## Overview

- **Service**: `tdl` container
- **Network**: Routes through `gluetun` (VPN)
- **Storage**: Downloads to `/mnt/storage/downloads/telegram/`, moves completed to `/mnt/storage/media/adult/telegram/`
- **Automation**: Runs weekly (Sunday 3am) via cron
- **Log**: `/mnt/storage/downloads/telegram/tdl-download.log`

## Quick Start

### Check Status
```bash
./scripts/tdl-manager.sh status
```

Shows:
- Container health
- Download progress (PID, active files)
- Recent log activity

### Start Download
```bash
./scripts/tdl-manager.sh start
```
- Safe to run multiple times - won't start duplicate downloads
- Uses `--skip-same` to resume from where it left off
- Automatically skips already-downloaded files

### Watch Live
```bash
./scripts/tdl-manager.sh attach
```
Shows real-time download progress bars.

**Detach**: Press `Ctrl+B` then `D` to exit without stopping.

### Stop Download
```bash
./scripts/tdl-manager.sh stop
```
Gracefully stops current downloads (waits 10s for active files to finish).

### Fix Stuck/Hung Downloads
```bash
./scripts/tdl-manager.sh fix
```
**Nuclear option** - use when:
- Download appears frozen (no progress for >30 min)
- Container is unhealthy
- Process crashed but tmux session still exists

**What it does:**
1. Stops download gracefully
2. Kills tmux session
3. Removes and recreates tdl container
4. Starts fresh download (resumes from last position due to `--skip-same`)

### View Logs
```bash
./scripts/tdl-manager.sh logs
```
Shows last 20 lines of download log.

## Manual Commands

If you prefer not to use the manager:

```bash
# Check if downloading
docker exec tdl ps aux | grep tdl

# Watch logs
tail -f /mnt/storage/downloads/telegram/tdl-download.log

# Enter container
docker exec -it tdl sh

# Manual download (inside container)
tdl download \
  -f /downloads/saved-messages-all.json \
  -d /downloads/.skip-index \
  -i mp4,mkv,avi,mov,wmv,webm \
  --skip-same \
  -l 2
```

## Troubleshooting

### Download is stuck/frozen
```bash
# Check if process is running
./scripts/tdl-manager.sh status

# If stuck, fix it
./scripts/tdl-manager.sh fix
```

### Container won't start
```bash
# Check gluetun is healthy (tdl depends on it)
docker ps --filter name=gluetun

# Check logs
docker logs tdl --tail 50

# Recreate
docker compose up -d tdl --force-recreate
```

### Files not moving to final location
If downloads complete but files stay in temp folder:
```bash
# Check if move command failed
docker exec tdl ls -la /downloads/.skip-index/

# Manually move them
docker exec tdl sh -c 'find /downloads/.skip-index -type f -exec mv {} /adult-telegram/ \;'
```

### Resume from crash
```bash
# Simply start again - skip-same prevents re-downloads
./scripts/tdl-manager.sh start
```

## Configuration

### Change download settings
Edit: `config/tdl/download-saved.sh`

Key options:
- `-l 2` = 2 concurrent downloads (change number)
- `--skip-same` = skip duplicates (keep enabled)
- `-i mp4,mkv,...` = file types to download

### Change schedule
Edit: `config/tdl/crontab`

Default: `0 3 * * 0` = Every Sunday at 3:00 AM

Format: `min hour day month weekday`
- `0 3 * * *` = Daily at 3am
- `0 */6 * * *` = Every 6 hours
- `0 3 * * 0` = Weekly Sunday 3am (default)

## File Locations

| Path | Description |
|------|-------------|
| `/mnt/storage/downloads/telegram/` | Working directory, logs, JSON exports |
| `/mnt/storage/downloads/telegram/saved-messages-all.json` | Exported message list |
| `/mnt/storage/downloads/telegram/tdl-download.log` | Download log |
| `/mnt/storage/downloads/telegram/cron.log` | Weekly cron job log |
| `/mnt/storage/media/adult/telegram/` | **Final destination** for completed videos |

## Advanced

### Export messages manually
```bash
docker exec tdl tdl chat export -c 1015621977 -o /downloads/manual-export.json
```

### Download specific message only
```bash
docker exec tdl tdl download \
  --from 1015621977 \
  -m 12345 \
  -d /adult-telegram/
```

### Check what will be downloaded
```bash
docker exec tdl tdl chat export -c 1015621977 -o /tmp/check.json
docker exec tdl cat /tmp/check.json | jq '.[] | select(.type=="video") | {id: .message_id, name: .file_name}'
```
