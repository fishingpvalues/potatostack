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