# OneDrive to Syncthing Migration Guide

Complete guide for downloading your entire OneDrive and migrating to Syncthing folders.

## Overview

**Method**: Native Linux OneDrive client (abraunegg/onedrive) - NOT Docker
**Source**: Your Microsoft OneDrive account
**Temporary Storage**: `/mnt/storage/onedrive-temp`
**Final Destination**: `/mnt/storage/syncthing/*`
**Archive**: `/mnt/storage/syncthing/OneDrive-Archive` (complete backup)

## Prerequisites

- Le Potato with 2GB RAM + 2GB swap (already configured)
- Sufficient disk space on `/mnt/storage`
- Microsoft OneDrive account credentials
- Internet connection

## Folder Mapping

Your OneDrive structure → Syncthing folders:

| OneDrive Folder      | Syncthing Path                           |
|----------------------|------------------------------------------|
| Berufliches          | /mnt/storage/syncthing/Berufliches      |
| Bilder               | /mnt/storage/syncthing/Bilder           |
| Desktop              | /mnt/storage/syncthing/Desktop          |
| Dokumente            | /mnt/storage/syncthing/Dokumente        |
| Obsidian Vault       | /mnt/storage/syncthing/Obsidian-Vault   |
| Privates             | /mnt/storage/syncthing/Privates         |
| workdir              | /mnt/storage/syncthing/workdir          |
| Persönlicher Tresor  | Manual → Privates/vault                 |

## Step-by-Step Process

### Step 1: Install OneDrive Client (~10-15 minutes)

```bash
cd ~/light
chmod +x install-onedrive-client.sh
./install-onedrive-client.sh
```

**What it does**:
- Installs build dependencies
- Installs D compiler (DMD)
- Clones abraunegg/onedrive repository
- Compiles from source
- Installs to system

**Requirements**: 2GB RAM + Swap (you have this from storage-init)

### Step 2: Setup and Authenticate (~5 minutes)

```bash
./setup-onedrive-sync.sh
```

**What it does**:
- Creates configuration directory
- Downloads config template
- Sets sync directory to `/mnt/storage/onedrive-temp`
- Enables logging
- **Starts authentication flow**

**Authentication Steps**:
1. Script displays a Microsoft login URL
2. Open URL in browser (on any device)
3. Sign in to Microsoft account
4. Grant permissions
5. Copy the ENTIRE redirect URL from browser address bar
6. Paste it back into the terminal

**Example redirect URL**:
```
https://login.microsoftonline.com/common/oauth2/nativeclient?code=M.C123...
```

Copy everything from `https://` to the end.

### Step 3: Download OneDrive Content (time varies)

```bash
./download-onedrive.sh
```

**What it does**:
- Shows available disk space
- Confirms you want to proceed
- Downloads ALL content from OneDrive
- Shows progress in real-time
- Logs to `~/.config/onedrive/logs/`

**Time estimate**:
- 10GB OneDrive: ~15-30 minutes (depends on internet speed)
- 50GB OneDrive: 1-2 hours
- 100GB+: Several hours

**Download is resumable**: If interrupted, run again and it continues.

### Step 4: Migrate to Syncthing Folders (~10-30 minutes)

```bash
./migrate-onedrive-to-syncthing.sh
```

**What it does**:
- Shows migration plan
- Uses rsync to safely copy folders
- Maps OneDrive folders → Syncthing folders
- Creates complete archive at `OneDrive-Archive`
- Sets correct permissions (1000:1000)
- Shows sizes and summary

**Safe operation**: Uses rsync (preserves files, shows progress, verifiable)

### Step 5: Handle Personal Vault (Manual)

**OneDrive Personal Vault** (Persönlicher Tresor) requires manual unlock:

**Option A: From Windows/Mac**:
1. Open OneDrive app
2. Unlock Personal Vault (biometric/PIN)
3. Copy vault contents
4. Transfer to server: `/mnt/storage/syncthing/Privates/vault/`

**Option B: OneDrive Web**:
1. Go to onedrive.live.com
2. Unlock Personal Vault
3. Download vault contents as ZIP
4. Transfer and extract to server

**Recommended**: Use Syncthing to sync vault from another device where it's unlocked.

## Complete Workflow

```bash
# 1. Install (one-time, ~15 min)
cd ~/light
chmod +x *.sh
./install-onedrive-client.sh

# 2. Authenticate (~5 min)
./setup-onedrive-sync.sh
# Follow authentication prompts in browser

# 3. Download (varies, 30min - several hours)
./download-onedrive.sh
# Wait for completion, logs show progress

# 4. Migrate to Syncthing (~30 min)
./migrate-onedrive-to-syncthing.sh
# Verify in Syncthing UI

# 5. Verify
# Open Syncthing: http://192.168.178.40:8384
# Check folders have content

# 6. Cleanup (optional, after verification)
sudo rm -rf /mnt/storage/onedrive-temp
```

## Verification

### Check Syncthing Folders
```bash
ls -lh /mnt/storage/syncthing/
du -sh /mnt/storage/syncthing/*
```

### Check Archive
```bash
du -sh /mnt/storage/syncthing/OneDrive-Archive
```

### Syncthing Web UI
```
http://192.168.178.40:8384
```
Navigate folders, verify files are present.

## Troubleshooting

### Build Fails (Out of Memory)
```bash
# Check swap is enabled
swapon --show
free -h

# Enable if not active
sudo swapon /mnt/cachehdd/swapfile

# Or restart stack to auto-enable
cd ~/light
docker compose down
docker compose up -d
```

### Authentication Fails
- Make sure you copy the ENTIRE redirect URL
- Try authentication flow again: `./setup-onedrive-sync.sh`
- Check internet connection
- For work/school accounts: May need Device Authorization Flow (see docs)

### Download Stops/Fails
- Download is resumable, just run `./download-onedrive.sh` again
- Check disk space: `df -h /mnt/storage`
- Check logs: `cat ~/.config/onedrive/logs/download-*.log`

### Migration Issues
- Script uses rsync (safe, won't delete originals)
- If fails, you still have: `/mnt/storage/onedrive-temp` (original download)
- Manual copy: `cp -r /mnt/storage/onedrive-temp/Desktop /mnt/storage/syncthing/Desktop`

## Disk Space Planning

**Temporary Space Needed**: 2-3x your OneDrive size
- 1x in `/mnt/storage/onedrive-temp` (download)
- 1x in `/mnt/storage/syncthing/*` (migrated folders)
- 1x in `/mnt/storage/syncthing/OneDrive-Archive` (complete backup)

**After Cleanup**: 2x your OneDrive size (syncthing folders + archive)

**Can delete**:
- `/mnt/storage/onedrive-temp` (after successful migration)
- `/mnt/storage/syncthing/OneDrive-Archive` (if you trust Syncthing copies)

## Post-Migration

### Option 1: Keep OneDrive + Syncthing
- Keep OneDrive active on Windows/phone
- Use Syncthing to sync to server
- Server acts as additional backup
- OneDrive client NOT needed on server

### Option 2: Syncthing Only
- Disconnect OneDrive on devices
- Use Syncthing exclusively
- Set up Syncthing on all devices
- Server is primary storage

### Recommended: Hybrid
- Keep OneDrive on primary devices (Windows, phone)
- Use Syncthing to keep server in sync
- Server provides offline access and backup
- Best of both worlds

## Cleanup

After verifying everything works:

```bash
# Remove temporary OneDrive download
sudo rm -rf /mnt/storage/onedrive-temp

# Optional: Remove OneDrive client (one-time use)
sudo make uninstall
cd ~/onedrive-client
cd ..
rm -rf ~/onedrive-client

# Optional: Remove D compiler
rm -rf ~/dlang
```

## Files Created

**Scripts**:
- `install-onedrive-client.sh` - Install OneDrive client
- `setup-onedrive-sync.sh` - Configure and authenticate
- `download-onedrive.sh` - Download from OneDrive
- `migrate-onedrive-to-syncthing.sh` - Move to Syncthing folders

**Directories**:
- `~/.config/onedrive/` - OneDrive client config
- `~/.config/onedrive/logs/` - Download logs
- `/mnt/storage/onedrive-temp/` - Temporary download location
- `/mnt/storage/syncthing/OneDrive-Archive/` - Complete backup

## Support

**OneDrive Client Issues**: https://github.com/abraunegg/onedrive/issues
**Syncthing Issues**: http://192.168.178.40:8384 (check logs)
**Disk Space**: `df -h` and `du -sh /mnt/storage/*`

## Security Notes

- OneDrive client stores OAuth tokens in `~/.config/onedrive/`
- Tokens are secure, don't share
- After migration, can revoke app access: https://account.live.com/consent/Manage
- Syncthing uses encrypted P2P sync
- Personal Vault requires manual unlock (extra security layer)
