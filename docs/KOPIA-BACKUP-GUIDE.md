# Kopia Backup Guide for PotatoStack

This guide covers how to use Kopia as your central backup solution in PotatoStack.

## Overview

**Web UI**: `https://potatostack.tale-iwato.ts.net:51515`

> **Requirement**: Tailscale must be running on your device to access the backup server.

Kopia is a fast, secure, open-source backup/restore tool with:
- **Deduplication** - Only stores unique data blocks
- **Encryption** - AES-256-GCM encryption at rest
- **Compression** - Multiple algorithms (pgzip, zstd, etc.)
- **Incremental backups** - Only backs up changed files
- **Web UI** - Easy-to-use interface at port 51515
- **Repository Server** - Central backup destination for multiple clients

## Quick Start

### 1. Environment Configuration

Add these to your `.env` file:

```bash
# Repository encryption password (CRITICAL - don't lose this!)
KOPIA_PASSWORD=your_secure_repository_password

# Web UI credentials (use master credentials)
KOPIA_SERVER_USER=admin
KOPIA_SERVER_PASSWORD=your_admin_password
```

The `generate-env.sh` script will set these automatically using your master credentials.

### 2. Start Kopia

```bash
make up
# or specifically
docker compose up -d kopia
```

### 3. Access Web UI

Open: `https://potatostack.tale-iwato.ts.net:51515`

- **Username**: Value of `KOPIA_SERVER_USER` (default: daniel)
- **Password**: Value of `KOPIA_SERVER_PASSWORD`

> **Note**: Uses self-signed TLS certificate. Tailscale provides the secure transport.

---

## Understanding Kopia Concepts

### Repository
The encrypted storage location for all your backups. In PotatoStack, this is stored at:
```
/mnt/storage/kopia/repository
```

### Snapshots
Point-in-time copies of directories. Each snapshot only stores changed data (deduplication).

### Policies
Rules that define:
- **Retention**: How long to keep snapshots
- **Scheduling**: When to take snapshots
- **Compression**: Which algorithm to use

### Default Policy (Set by Init Script)

| Retention Type | Count |
|----------------|-------|
| Latest         | 10    |
| Hourly         | 24    |
| Daily          | 7     |
| Weekly         | 4     |
| Monthly        | 12    |
| Annual         | 3     |

---

## Backup Locations in PotatoStack

The Kopia container has read-only access to these directories:

| Mount Path | Source | Description |
|------------|--------|-------------|
| `/data/vaultwarden` | vaultwarden-data volume | Password vault |
| `/data/syncthing` | /mnt/storage/syncthing | Synced files |
| `/data/downloads` | /mnt/storage/downloads | Downloaded media |
| `/data/slskd-shared` | /mnt/storage/slskd-shared | Shared music |
| `/data/immich` | immich volumes | Photos library |
| `/data/mealie` | /mnt/storage/mealie-data | Recipes |
| `/data/obsidian` | /mnt/storage/obsidian | Notes |

---

## Creating Backups via Web UI

### Step 1: Open Snapshots Tab
Navigate to **Snapshots** in the left sidebar.

### Step 2: Create New Snapshot
1. Click **New Snapshot**
2. Enter the path (e.g., `/data/vaultwarden`)
3. Click **Snapshot Now** for immediate backup

### Step 3: Set Up Scheduled Snapshots
1. Click the **Policy** tab for the path
2. Configure schedule:
   - **Interval**: e.g., every 6 hours
   - **Times of day**: e.g., 03:00, 15:00
3. Click **Save Policy**

---

## Creating Backups via CLI

Access the Kopia CLI inside the container:

```bash
docker exec -it kopia sh
```

### Create a Snapshot
```bash
kopia snapshot create /data/vaultwarden
kopia snapshot create /data/syncthing
kopia snapshot create /data/obsidian
```

### List Snapshots
```bash
kopia snapshot list
kopia snapshot list /data/vaultwarden
```

### Set Snapshot Policy
```bash
# Daily at 3am, keep 7 daily, 4 weekly, 12 monthly
kopia policy set /data/vaultwarden \
  --add-scheduling-interval 24h \
  --add-scheduling-time-of-day 03:00 \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12
```

---

## Restoring Data

### Via Web UI
1. Go to **Snapshots**
2. Click on the snapshot to restore
3. Browse the file tree
4. Click **Restore** on files/folders
5. Choose destination (e.g., `/export`)

### Via CLI
```bash
# Restore entire snapshot
kopia restore <snapshot-id> /export/restore-target

# Restore specific file
kopia restore <snapshot-id>/path/to/file /export/restored-file

# Mount snapshot as filesystem (read-only)
kopia mount <snapshot-id> /mnt/restore
```

---

## Connecting Remote Clients

Kopia serves as a central backup repository for all your devices (Windows, Mac, Linux, Android).

### Server Details

| Setting | Value |
|---------|-------|
| **URL** | `https://potatostack.tale-iwato.ts.net:51515` |
| **Alt URL** | `https://100.108.216.90:51515` (Tailscale IP) |
| **Username** | `daniel` (from KOPIA_SERVER_USER) |
| **Password** | From `.env` KOPIA_SERVER_PASSWORD |

### TLS Certificate Fingerprint

```
CE:31:6F:AA:F6:DA:85:7F:11:61:9F:61:CB:5A:FE:17:E0:EE:A7:F2:C1:6E:CC:56:36:DA:35:8B:48:C4:4F:C9
```

To regenerate (if certificate changes):
```bash
docker exec kopia openssl x509 -in /app/config/tls.crt -noout -fingerprint -sha256 | cut -d= -f2
```

### Step 1: Add User for Each Device

On the server, create a user for each device you want to backup:

```bash
# Format: username@hostname
docker exec kopia kopia server user add daniel@windows-pc --user-password=YOURPASSWORD
docker exec kopia kopia server user add daniel@macbook --user-password=YOURPASSWORD
docker exec kopia kopia server user add daniel@android --user-password=YOURPASSWORD
docker exec kopia kopia server user add daniel@laptop --user-password=YOURPASSWORD
```

List existing users:
```bash
docker exec kopia kopia server user list
```

### Step 2: Connect from Remote Client

#### Windows/Mac/Linux GUI (KopiaUI)

1. Download Kopia from https://kopia.io/docs/installation/
2. Open KopiaUI
3. Select **Connect to Repository** → **Kopia Repository Server**
4. Fill in:
   - **Server Address**: `https://potatostack.tale-iwato.ts.net:51515`
   - **Server Certificate Fingerprint**: (paste fingerprint above)
   - **Username**: `daniel` (or your username)
   - **Password**: Your KOPIA_SERVER_PASSWORD
5. Click **Connect**

#### Command Line (All Platforms)

```bash
kopia repository connect server \
  --url=https://potatostack.tale-iwato.ts.net:51515 \
  --server-cert-fingerprint="CE:31:6F:AA:F6:DA:85:7F:11:61:9F:61:CB:5A:FE:17:E0:EE:A7:F2:C1:6E:CC:56:36:DA:35:8B:48:C4:4F:C9"
```

When prompted, enter username and password.

#### Android (via Termux)

```bash
pkg install kopia
kopia repository connect server \
  --url=https://potatostack.tale-iwato.ts.net:51515 \
  --server-cert-fingerprint="CE:31:6F:AA:F6:DA:85:7F:11:61:9F:61:CB:5A:FE:17:E0:EE:A7:F2:C1:6E:CC:56:36:DA:35:8B:48:C4:4F:C9"
```

### Step 3: Create Backups from Client

Once connected, create snapshots:

```bash
# Windows
kopia snapshot create C:\Users\daniel\Documents
kopia snapshot create C:\Users\daniel\Pictures

# Mac/Linux
kopia snapshot create /home/daniel/Documents
kopia snapshot create /home/daniel/Pictures

# Android (Termux)
kopia snapshot create /storage/emulated/0/DCIM
kopia snapshot create /storage/emulated/0/Download
```

### Step 4: Set Up Scheduled Backups (Optional)

```bash
# Daily backup at 2am
kopia policy set /home/daniel/Documents \
  --add-scheduling-interval-hours 24 \
  --scheduling-time-of-day 02:00

# Verify policy
kopia policy show /home/daniel/Documents
```

### User Isolation

Each user only sees their own snapshots. User `daniel@windows-pc` cannot see snapshots from `daniel@macbook`. This provides security isolation between devices.

---

## Automated Stack Snapshots

PotatoStack includes `stack-snapshot.sh` which runs via cron:

### Configuration in `.env`

```bash
SNAPSHOT_CRON_SCHEDULE=0 3 * * *   # Daily at 3am
SNAPSHOT_PATHS=/data               # What to backup
SNAPSHOT_LOG_FILE=/mnt/storage/kopia/stack-snapshot.log
```

### Manually Trigger Snapshot

```bash
docker exec cron sh /stack-snapshot.sh
```

### View Snapshot Logs

```bash
cat /mnt/storage/kopia/stack-snapshot.log
# or
docker logs cron
```

---

## Maintenance

### Verify Repository Integrity

```bash
docker exec kopia kopia snapshot verify
```

### Check Repository Statistics

```bash
docker exec kopia kopia repository status
docker exec kopia kopia content stats
```

### Cleanup Old Data (Run Periodically)

```bash
# Run maintenance (deduplication cleanup)
docker exec kopia kopia maintenance run --full
```

### View Cache Usage

```bash
docker exec kopia kopia cache info
```

---

## Backup Best Practices

### 1. Test Your Restores
Regularly restore random files to verify backups work.

### 2. Multiple Backup Destinations
Consider syncing `/mnt/storage/kopia/repository` to:
- External USB drive
- Remote server via Syncthing
- Cloud storage (encrypted)

### 3. Monitor Backup Status
Check the backup-monitor service:
```bash
docker logs backup-monitor
```

### 4. Secure Your Password
The `KOPIA_PASSWORD` is the encryption key. If lost:
- **Backups become unrecoverable**
- Store it in Vaultwarden
- Keep an offline copy

---

## Troubleshooting

### Cannot Connect to Repository

```bash
# Check Kopia is running
docker ps | grep kopia

# View logs
docker logs kopia

# Verify repository status
docker exec kopia kopia repository status
```

### Web UI Not Loading

1. Ensure port 51515 is accessible
2. Check if HTTPS is required (use `https://`)
3. Accept the self-signed certificate warning

### Snapshot Fails

```bash
# Check specific error
docker exec kopia kopia snapshot create /data/path --log-level=debug

# Common issues:
# - Path doesn't exist in container
# - Permission denied (check volume mounts)
# - Disk full
```

### High Disk Usage

```bash
# Check what's using space
docker exec kopia kopia content stats

# Run garbage collection
docker exec kopia kopia maintenance run --full
```

---

## Directory Structure

```
/mnt/storage/kopia/
├── repository/           # Encrypted backup data (IMPORTANT!)
│   ├── kopia.repository.f
│   ├── p/               # Pack files (deduplicated blocks)
│   ├── q/               # Index files
│   └── n/               # Metadata
└── stack-snapshot.log   # Automated backup logs

Docker Volumes:
├── kopia-config         # Server configuration, TLS certs
├── kopia-logs           # Server logs

Cache (disposable):
└── /mnt/cachehdd/sync/kopia-cache/
```

---

## Important Files

| File | Location | Purpose |
|------|----------|---------|
| Init Script | `scripts/init/kopia-init.sh` | Initializes repository and starts server |
| Snapshot Script | `scripts/backup/stack-snapshot.sh` | Automated backup cron job |
| Service Config | `docker-compose.yml` (line ~3789) | Container configuration |

---

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KOPIA_PASSWORD` | Yes | - | Repository encryption password |
| `KOPIA_SERVER_USER` | No | admin | Web UI username |
| `KOPIA_SERVER_PASSWORD` | Yes | - | Web UI password |
| `KOPIA_HOSTNAME` | No | potatostack | Override hostname for snapshots |
| `KOPIA_TAG` | No | latest | Docker image tag |
| `SNAPSHOT_CRON_SCHEDULE` | No | 0 3 * * * | Cron schedule for auto-backups |
| `SNAPSHOT_PATHS` | No | /data | Paths to backup |

---

## Resources

- [Kopia Official Documentation](https://kopia.io/docs/)
- [Kopia Repository Server Guide](https://kopia.io/docs/repository-server/)
- [Kopia GitHub](https://github.com/kopia/kopia)
- [Kopia Forum](https://kopia.discourse.group/)

---

## Quick Reference Commands

```bash
# Enter Kopia shell
docker exec -it kopia sh

# Create snapshot
kopia snapshot create /data/vaultwarden

# List all snapshots
kopia snapshot list

# Restore snapshot
kopia restore <snapshot-id> /export/target

# Check repository
kopia repository status

# Run maintenance
kopia maintenance run --full

# Add remote user
kopia server user add username@hostname

# View policies
kopia policy show --global
```
