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
| `/cache` | `/mnt/cachehdd/backrest/cache` | HDD | Cache |
| `/repos` | `/mnt/storage/backrest/repos` | HDD | Backup repositories |

## Creating a Plan

1. After adding a repo, create a **Plan**
2. Set the directories to back up (paths as seen inside the container)
3. Configure a schedule (e.g. daily at 2 AM)
4. Configure **retention policy** (how many snapshots to keep)
5. Add an **on error hook** for notifications (recommended)

## Backup Configuration

Back up `/mnt/ssd/docker-data/backrest/config/config.json` -- it contains all repo definitions, plans, and encryption passwords.
