# OneDrive to Syncthing Migration Scripts

Complete script package for migrating your OneDrive to Syncthing folders using **rclone**.

## Scripts

1. **install-rclone.sh** - Install rclone (fast, reliable cloud sync tool)
2. **setup-rclone-onedrive.sh** - Configure and authenticate with Microsoft OneDrive
3. **download-onedrive.sh** - Download all OneDrive content
4. **migrate-onedrive-to-syncthing.sh** - Move files to Syncthing folders

## Quick Start

```bash
cd ~/potatostack/onedrive-migration-to-syncthing

# Step 1: Install rclone (~1 min)
./install-rclone.sh

# Step 2: Setup and authenticate (~2 min)
./setup-rclone-onedrive.sh
# Browser opens automatically for Microsoft login

# Step 3: Download files (30 min - several hours)
./download-onedrive.sh

# Step 4: Migrate to Syncthing (~10-30 min)
./migrate-onedrive-to-syncthing.sh
```

## Why rclone?

- **Better authentication** - Opens browser automatically, no manual URL copying
- **Faster downloads** - Parallel transfers, resume support
- **More reliable** - Better error handling and retries
- **Multi-cloud** - Works with 70+ cloud providers

## Folder Mapping

| OneDrive Folder | Syncthing Path |
|----------------|----------------|
| Berufliches | /mnt/storage/syncthing/Berufliches |
| Bilder | /mnt/storage/syncthing/Bilder |
| Desktop | /mnt/storage/syncthing/Desktop |
| Dokumente | /mnt/storage/syncthing/Dokumente |
| Obsidian Vault | /mnt/storage/syncthing/Obsidian-Vault |
| Privates | /mnt/storage/syncthing/Privates |
| Persönlicher Tresor | /mnt/storage/syncthing/Privates/vault |
| workdir | /mnt/storage/syncthing/workdir |

## Requirements

- Internet connection
- Sufficient disk space (2-3x your OneDrive size)
- Microsoft OneDrive account credentials

## Disk Space

- Temporary: `/mnt/storage/onedrive-temp` (original download)
- Final: `/mnt/storage/syncthing/*` (migrated folders)
- Archive: `/mnt/storage/syncthing/OneDrive-Archive` (complete backup)

## Manual rclone Commands

```bash
# List OneDrive contents
rclone ls onedrive:

# List top-level folders
rclone lsd onedrive:

# Check OneDrive size
rclone size onedrive:

# Sync specific folder
rclone sync onedrive:Documents /local/path --progress

# Copy single file
rclone copy onedrive:file.txt /local/path

# Check config
rclone config show
```

## Cleanup (Optional)

After verifying everything works:

```bash
# Remove temporary download
sudo rm -rf /mnt/storage/onedrive-temp

# Remove old onedrive client (if installed)
sudo apt remove onedrive
```

## Troubleshooting

**Installation fails**: Run `curl https://rclone.org/install.sh | sudo bash` manually

**Authentication fails**:
  - Run `rclone config` and reconfigure the 'onedrive' remote
  - Delete old config: `rm ~/.config/rclone/rclone.conf`

**Download fails/stops**: Run `./download-onedrive.sh` again - it's resumable

**Token expired**: Run `rclone config reconnect onedrive:`

**Migration issues**: Original files remain in `/mnt/storage/onedrive-temp`

## Verification

Check Syncthing folders:
```bash
ls -lh /mnt/storage/syncthing/
du -sh /mnt/storage/syncthing/*
```

Check archive:
```bash
du -sh /mnt/storage/syncthing/OneDrive-Archive
```

Syncthing Web UI:
```
https://potatostack.tale-iwato.ts.net:8384
```

## Logs

Download logs: `~/.config/rclone/logs/download-*.log`

## Support

- rclone Documentation: https://rclone.org/onedrive/
- PotatoStack Documentation: /home/daniel/potatostack/docs/
