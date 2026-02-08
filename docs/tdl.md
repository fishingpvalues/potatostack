# TDL - Telegram Downloader

Downloads videos from Telegram Saved Messages via VPN (gluetun).

## How It Works

1. **On container startup**, download runs immediately in background
2. Waits for VPN/internet connectivity (up to 5 min)
3. Exports saved messages JSON from chat
4. Builds dedup index (symlinks to all videos in `/adult/`)
5. Downloads new videos with `--skip-same --continue` (resumes partial downloads)
6. Retries infinitely with exponential backoff (60s → 2m → 4m → ... → 15m cap) until success
7. Moves completed files to `/adult-telegram/`
8. Cleans up stale processes, skip-index, old .tmp files, rotates logs
9. **Daily cron at 3am** as safety net for picking up new saved messages

### Integration with gluetun-monitor

When VPN drops or gluetun is recreated, `gluetun-monitor` recreates the tdl container. This triggers a fresh download automatically (step 1). No manual intervention needed.

## Storage

| Path | Purpose |
|------|---------|
| `/mnt/storage/downloads/telegram/` | Working dir (JSON exports, logs) |
| `/mnt/storage/media/adult/telegram/` | Final destination for videos |
| `/mnt/storage/downloads/telegram/tdl-download.log` | Download log |

## Manual Commands

### Trigger a download now

```bash
docker exec -d tdl sh -c 'sh /etc/tdl/download-saved.sh >> /downloads/tdl-download.log 2>&1'
```

### Watch it live

```bash
tail -f /mnt/storage/downloads/telegram/tdl-download.log
```

### Check status

```bash
# Is tdl running?
docker ps --filter name=tdl

# Is a download active?
docker exec tdl pgrep -f "tdl download" && echo "DOWNLOADING" || echo "IDLE"

# How many videos downloaded?
ls /mnt/storage/media/adult/telegram/*.mp4 2>/dev/null | wc -l
```

## When It Crashes / How to Fix

### Download stuck or failed

The script self-recovers: 10-min timeout kills hung downloads, infinite retry with backoff. To fix immediately:

```bash
# Kill stuck download + trigger fresh run
docker exec tdl pkill -9 -f "tdl download"
docker exec -d tdl sh -c 'sh /etc/tdl/download-saved.sh >> /downloads/tdl-download.log 2>&1'
```

### A specific file keeps hanging

Add its message ID to the blocklist:

```bash
# Find the message ID from the log (e.g. "Fantasie(1015621977):101" → ID is 101)
echo "101" >> config/tdl/blocklist.txt
docker compose up -d --force-recreate tdl
```

### "Current database is used by another process"

Stale tdl process holding a lock. The script kills these automatically on startup. Manual fix:

```bash
docker exec tdl pkill -9 -f "tdl download"
```

### Container died / was recreated

Cron restarts automatically with the container. Just make sure it's running:

```bash
docker compose up -d tdl
```

### VPN is down

The script waits up to 5 min for internet on startup and before each retry. Check gluetun:

```bash
curl -s http://127.0.0.1:8008/v1/vpn/status
docker exec tdl wget -q -O /dev/null http://1.1.1.1 && echo "VPN OK" || echo "VPN DOWN"
```

### Log file huge

Auto-rotates at 10MB. Manual reset:

```bash
truncate -s 0 /mnt/storage/downloads/telegram/tdl-download.log
```

### Nuclear option (full reset)

```bash
docker exec tdl pkill -9 -f "tdl download"
docker compose up -d --force-recreate tdl
docker exec -d tdl sh -c 'sh /etc/tdl/download-saved.sh >> /downloads/tdl-download.log 2>&1'
tail -f /mnt/storage/downloads/telegram/tdl-download.log
```

## Self-Management Features

The download script handles everything without external monitoring:

- **VPN wait** — waits up to 5 min for internet before starting and before each retry
- **Stale process cleanup** — kills leftover `tdl download` on startup (SIGTERM then SIGKILL)
- **Log rotation** — keeps last 500 lines when log exceeds 10MB
- **Skip-index cleanup** — removes leftover dedup index from crashed runs
- **Old .tmp cleanup** — deletes incomplete downloads older than 7 days
- **Resume downloads** — `--continue` flag resumes partially downloaded files
- **Infinite retry with backoff** — retries forever (60s → 2m → 4m → 8m → 15m cap) until success
- **trap EXIT** — all cleanup runs even on crash

## Files

| File | In Container | Purpose |
|------|-------------|---------|
| `config/tdl/download-saved.sh` | `/etc/tdl/download-saved.sh` | Download script |
| `config/tdl/blocklist.txt` | `/downloads/blocklist.txt` | Message IDs to skip (one per line) |
| `config/tdl/crontab` | `/etc/crontabs/root` | `0 3 * * *` (daily 3am) |
