# Backrest Setup

Backrest (v1.11.2) provides a web UI for managing [restic](https://restic.net/) backups.

## Access

- URL: `https://potatostack.tale-iwato.ts.net:9898`
- Port `9898` must be listed in `TAILSCALE_SERVE_PORTS` in `docker-compose.yml`

## Creating a Repository

1. Open the Backrest UI and click **Add Repo**
2. Set a unique **Repo ID** (e.g. `local-documents`)
3. Set the **URI** to a path under `/repos/`, e.g.:
   - `/repos/documents`
   - `/repos/photos`
   - `/repos/config-backups`
4. Generate or set a **password** -- store this somewhere safe (e.g. password manager)
5. Enable **Auto Unlock** (recommended for single-client setups)

The `/repos` path maps to `/mnt/storage/backrest/repos` on the host HDD.

## Container Paths

| Container Path | Host Path | Storage | Purpose |
|---|---|---|---|
| `/data` | `/mnt/ssd/docker-data/backrest/data` | SSD | Database |
| `/config` | `/mnt/ssd/docker-data/backrest/config` | SSD | Configuration |
| `/cache` | `/mnt/ssd/docker-data/backrest/cache` | SSD | Cache (moved from HDD to avoid spin-up I/O errors) |
| `/repos` | `/mnt/storage/backrest/repos` | HDD | Backup repositories |

## Creating a Plan

1. After adding a repo, create a **Plan**
2. Set the directories to back up (paths as seen inside the container)
3. Configure a schedule (e.g. daily at 2 AM)
4. Configure **retention policy** (how many snapshots to keep)
5. Add an **on error hook** for notifications (recommended)

## Backup Configuration

Back up `/mnt/ssd/docker-data/backrest/config/config.json` -- it contains all repo definitions, plans, and encryption passwords.

Here's what's worth backing up with your 1TB budget:                                                             
             
  Must backup (~10GB)                                                                                              
                                                                                                                 
  ┌───────────────────────────────┬────────────┬─────────────────────────────────┐                                 
  │             Path              │    Size    │               Why               │                               
  ├───────────────────────────────┼────────────┼─────────────────────────────────┤                                 
  │ /mnt/ssd/docker-data/         │ ~6GB       │ All service configs, DBs, state │                                 
  ├───────────────────────────────┼────────────┼─────────────────────────────────┤                                 
  │ /home/daniel/potatostack/     │ 11MB       │ Stack config, .env, compose     │                                 
  ├───────────────────────────────┼────────────┼─────────────────────────────────┤                                 
  │ /home/daniel/potatostack/.env │ (in above) │ All passwords & secrets         │                                 
  └───────────────────────────────┴────────────┴─────────────────────────────────┘

  Strongly recommended (~8GB)

  ┌────────────────────────────────────────┬───────┬───────────────────────────────┐
  │                  Path                  │ Size  │              Why              │
  ├────────────────────────────────────────┼───────┼───────────────────────────────┤
  │ /mnt/storage/photos/                   │ 7.5GB │ Irreplaceable personal photos │
  ├────────────────────────────────────────┼───────┼───────────────────────────────┤
  │ /mnt/storage/syncthing/Obsidian-Vault/ │ 180MB │ Your knowledge base           │
  ├────────────────────────────────────────┼───────┼───────────────────────────────┤
  │ /mnt/storage/syncthing/Privates/       │ 398MB │ Personal documents            │
  └────────────────────────────────────────┴───────┴───────────────────────────────┘

  Optional if space allows (~27GB)

  ┌───────────────────────────────────┬──────┬───────────┐
  │               Path                │ Size │    Why    │
  ├───────────────────────────────────┼──────┼───────────┤
  │ /mnt/storage/syncthing/Dokumente/ │ 27GB │ Documents │
  └───────────────────────────────────┴──────┴───────────┘

  Skip (replaceable/huge)

  ┌─────────────────────────────────────┬───────┬───────────────────────────────────────────────┐
  │                Path                 │ Size  │                      Why                      │
  ├─────────────────────────────────────┼───────┼───────────────────────────────────────────────┤
  │ /mnt/storage/downloads/             │ 2TB   │ Re-downloadable                               │
  ├─────────────────────────────────────┼───────┼───────────────────────────────────────────────┤
  │ /mnt/storage/media/                 │ 1.2TB │ Re-downloadable                               │
  ├─────────────────────────────────────┼───────┼───────────────────────────────────────────────┤
  │ /mnt/storage/syncthing/Berufliches/ │ 215GB │ Already synced via Syncthing to other devices │
  ├─────────────────────────────────────┼───────┼───────────────────────────────────────────────┤
  │ /mnt/storage/onedrive-temp/         │ 267GB │ Temp/already in OneDrive                      │
  ├─────────────────────────────────────┼───────┼───────────────────────────────────────────────┤
  │ /mnt/ssd/docker-data/stash/         │ 4.6GB │ Regeneratable (thumbnails/cache)              │
  └─────────────────────────────────────┴───────┴───────────────────────────────────────────────┘

  Backrest exclude patterns for docker-data

  /mnt/ssd/docker-data/stash/cache/**
  /mnt/ssd/docker-data/stash/generated/**
  /mnt/ssd/docker-data/redis-cache/**
  /mnt/ssd/docker-data/crowdsec-db/**

  Total estimate: ~45GB — fits easily in 1TB with tons of room for history/snapshots.

  Note on Postgres: the DB is ~9GB (mostly bitmagnet which is regeneratable). It's inside the docker volume, not
  /mnt/ssd/docker-data/postgres/. You should add a pg_dump cron job to back up to a file that Backrest can pick up:

  docker exec postgres pg_dumpall -U postgres | gzip > /mnt/ssd/docker-data/backrest/pgdump.sql.gz

  ################################################################################
# BACKREST CONFIG FOR HETZNER STORAGE BOX BX11 (1TB)
################################################################################
#
# Repo: sftp://u546612@u546612.your-storagebox.de:23/backup
#
# === HETZNER BX11 CONSTRAINTS ===
# - 1 TB total space
# - 10 concurrent SFTP connections max (exceeding = blocked)
# - Port 23 (OpenSSH key format)
# - Set IO_BEST_EFFORT_LOW + CPU_LOW (already done)
#
# === SPACE BUDGET (raw, pre-dedup) ===
# Syncthing important:   ~268G (Berufliches 215G, Dokumente 27G, Bilder 24G, rest ~2G)
# Docker-data (filtered): ~6G  (postgres, mongo, grafana, vaultwarden, obsidian, gitea, etc)
# Photos (immich):         7.5G
# Potatostack repo:       <50M
# ----------------------------------
# Total raw:              ~282G
# With restic dedup+zstd: ~200G estimated
# With retention policy:  ~400-500G (fits in 1TB)
#
# === PATHS TO BACK UP ===
#
# [1] Potatostack repo (configs, scripts, compose)
#     /mnt/potatostack
#
# [2] Docker service data (SSD) - critical app state
#     /mnt/ssd/docker-data/
#
# [3] Photos (immich uploads)
#     /mnt/storage/photos/
#
# [4] Syncthing folders - ALL important ones:
#     /mnt/storage/syncthing/Berufliches/        215G  work files
#     /mnt/storage/syncthing/Dokumente/           27G  documents
#     /mnt/storage/syncthing/Bilder/              24G  pictures (MISSING from current config!)
#     /mnt/storage/syncthing/Privates/           398M  personal
#     /mnt/storage/syncthing/Obsidian-Vault/     180M  notes
#     /mnt/storage/syncthing/Desktop/            425M  desktop files
#     /mnt/storage/syncthing/workdir/            984M  working directory
#
# === SYNCTHING FOLDERS TO SKIP ===
#     OneDrive-Archive/    267G  SKIP - duplicate of above folders (old OneDrive export)
#     photos/              empty SKIP - symlink placeholder
#     videos/              empty SKIP
#     music/               empty SKIP
#     camera-sync/         empty SKIP
#     audiobooks/          empty SKIP
#     podcasts/            empty SKIP
#     books/               empty SKIP
#     shared/              empty SKIP
#     backup/              empty SKIP
#     Attachments/         empty SKIP
#     Studium/             empty SKIP
#     nvim/                empty SKIP
#     Microsoft-Copilot-Chat-Dateien/  SKIP - AI chat exports, not critical
#
# === DOCKER-DATA EXCLUDES (regenerable/cache) ===
#     stash/cache/**                4.6G  regenerable thumbnails
#     stash/generated/**            regenerable transcodes
#     redis-cache/**                ephemeral session data
#     crowdsec-db/**                regenerable threat DB
#     prometheus/**                 metrics (regenerable, 30d retention anyway)
#     loki/**                       logs (regenerable)
#     recyclarr/**                  281M config templates (re-downloadable)
#     karakeep-meilisearch/**       search index (rebuilt from karakeep data)
#     parseable/**                  log storage (regenerable)
#     diun/**                       image update tracking (regenerable)
#     cron/**                       cron state (trivial)
#     code-server/**                VS Code server cache
#     unpackerr/**                  extraction state
#     soularr/**                    music matching state
#     sentry/**                     error tracking (regenerable)
#
# === DOCKER-DATA TO KEEP (critical state) ===
#     postgres/            all 18 databases (CRITICAL)
#     mongo/               app data (authentik, etc)
#     vaultwarden/         passwords (CRITICAL)
#     obsidian-couchdb/    notes sync DB
#     gitea/               git repos
#     grafana/             dashboards + datasources
#     actual-budget/       financial data
#     healthchecks/        monitoring config
#     karakeep/            bookmarks
#     navidrome/           music library DB
#     stash/config/        stash settings + plugins
#     stash/metadata/      scene metadata
#     backrest/            backup config itself
#     authentik/           SSO/auth data
#     homarr/              dashboard config
#     slskd/               soulseek config
#     bitmagnet/           DHT index config
#     gokapi/              file sharing config
#     filebrowser/         file manager config
#     filestash/           file manager config
#     velld/               app data
#     scrutiny/            SMART history
#     alertmanager/        alert config
#     n8n/                 automation workflows
#     wireguard/           VPN keys
#     woodpecker/          CI config
#
# === RECOMMENDED RETENTION (fits 1TB) ===
#     daily:   7
#     weekly:  4
#     monthly: 6
#     yearly:  2
#
# === PERFORMANCE SETTINGS FOR HETZNER ===
#     - ioNice: IO_BEST_EFFORT_LOW (already set)
#     - cpuNice: CPU_LOW (already set)
#     - Prune monthly (already set: 0 0 1 * *)
#     - Check monthly with 10% read subset (already set)
#     - autoUnlock: true (already set)
#     - Consider: --pack-size 32 (larger packs = fewer SFTP connections)
#
# === BACKREST CONFIG.JSON CHANGES NEEDED ===
# 1. Add missing syncthing paths (Bilder, Desktop, workdir)
# 2. Add all docker-data excludes listed above
# 3. Remove /mnt/storage/syncthing/ wildcard - use explicit paths only
#
# === ACTION: Apply these changes in Backrest WebUI at :9898 ===
# Or edit /mnt/ssd/docker-data/backrest/config/config.json directly
################################################################################