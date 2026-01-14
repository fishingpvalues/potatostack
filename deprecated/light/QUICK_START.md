# Quick Start Guide - Light Stack

All fixes applied and ready to use!

## OneDrive Migration (New!)

Complete solution to download your OneDrive and migrate to Syncthing:

```bash
cd ~/light
chmod +x *.sh

# 1. Install OneDrive client (~2 min - EASY!)
./install-onedrive-simple.sh  # Precompiled package from Ubuntu

# 2. Setup and authenticate (~5 min, requires browser)
./setup-onedrive-sync.sh

# 3. Download everything (time varies)
./download-onedrive.sh

# 4. Migrate to Syncthing (~30 min)
./migrate-onedrive-to-syncthing.sh
```

**See**: `ONEDRIVE_MIGRATION_GUIDE.md` for detailed instructions

**Folder mappings**:
- Berufliches → /mnt/storage/syncthing/Berufliches
- Bilder → /mnt/storage/syncthing/Bilder
- Desktop → /mnt/storage/syncthing/Desktop
- Dokumente → /mnt/storage/syncthing/Dokumente
- Obsidian Vault → /mnt/storage/syncthing/Obsidian-Vault
- Privates → /mnt/storage/syncthing/Privates (porn subfolder included)
- workdir → /mnt/storage/syncthing/workdir

---

## Syncthing Setup

**Web UI**: http://192.168.178.40:8384

**Camera sync from phone**:
1. In Syncthing UI: Add folder
2. Path: `/data/camera-sync/android` (or `/data/camera-sync/ios`)
3. Share with your phone's device ID
4. On phone: Accept share, select DCIM/Camera

**See**: `PATHS_GUIDE.md` for all path mappings

---

## Vaultwarden (Password Manager)

**Web UI**: http://192.168.178.40:8080

**Android Bitwarden app**:
1. Settings → Self-hosted Environment
2. Server URL: `http://192.168.178.40:8080`
3. Leave all other fields empty
4. Save → Create account or Log in

**See**: `VAULTWARDEN_SETUP.md` for troubleshooting

---

## Soulseek Setup

Share media from Syncthing:

```bash
cd ~/light
./setup-soulseek-symlinks.sh
docker compose restart slskd
```

**Shares**: music, books, audiobooks, podcasts
**NOT shared**: porn, photos, videos, personal files

**Web UI**: http://192.168.178.40:2234

---

## Service URLs

| Service      | URL                           | Purpose                |
|--------------|-------------------------------|------------------------|
| Homepage     | http://192.168.178.40:3000   | Dashboard              |
| Syncthing    | http://192.168.178.40:8384   | File sync              |
| Vaultwarden  | http://192.168.178.40:8080   | Password manager       |
| Transmission | http://192.168.178.40:9091   | Torrents               |
| Slskd        | http://192.168.178.40:2234   | Soulseek               |
| Kopia        | https://192.168.178.40:51515 | Backups                |
| FileBrowser  | http://192.168.178.40:8181   | File manager           |
| Portainer    | https://192.168.178.40:9443  | Docker management      |

---

## System Status

```bash
# Check all containers
docker compose ps

# Check swap
swapon --show
free -h

# Check disk space
df -h

# View logs
docker compose logs -f [service]
```

---

## Documentation

| File                           | Content                              |
|--------------------------------|--------------------------------------|
| `ONEDRIVE_MIGRATION_GUIDE.md` | Complete OneDrive migration guide    |
| `PATHS_GUIDE.md`               | Volume mappings for all services     |
| `VAULTWARDEN_SETUP.md`         | Vaultwarden configuration            |
| `SYNCTHING_PERSISTENCE.md`     | Config persistence explanation       |
| `OOM_FIX.md`                   | Memory management details            |
| `FIXES_SUMMARY.md`             | All fixes applied                    |

---

## Important Notes

**Swap**: 2GB auto-created on cache HDD, no OOM errors
**Config persistence**: All settings survive crashes (Docker volumes)
**Syncthing paths**: Use `/data/*` in UI (maps to `/mnt/storage/syncthing/*`)
**Personal Vault**: Requires manual unlock and transfer (see guide)

---

## Quick Fixes

**OOM errors**: Already fixed (2.9GB swap active)
**Vaultwarden slow**: Already fixed (increased memory, longer healthcheck)
**Syncthing permissions**: Already fixed (folders pre-created, correct permissions)
**API keys**: Auto-generated on every start
