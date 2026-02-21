# Beets Music Manager

WebUI: `https://potatostack.tale-iwato.ts.net:8337`

All commands run as user `abc` inside the container:
```bash
docker exec -u abc beets beet <command>
```

---

## Import Workflow

### SpotiFLAC downloads (main source)
```bash
# Auto-apply best match, no prompts
docker exec -u abc beets beet import -A /downloads/spotiflac

# With manual confirmation on ambiguous matches
docker exec -u abc beets beet import /downloads/spotiflac
```

### slskd / Soulseek downloads
```bash
docker exec -u abc beets beet import /downloads/slskd
docker exec -u abc beets beet import -A /downloads/slskd
```

### All downloads at once
```bash
docker exec -u abc beets beet import -A /downloads
```

### Specific album folder
```bash
docker exec -u abc beets beet import -A "/downloads/slskd/Artist - Album (2024)"
```

**Import flags:**
- `-A` / `--nowrite` — auto-apply, skip prompts (use for well-tagged FLAC)
- `-t` / `--timid` — ask for confirmation even on strong matches
- `-C` / `--nocopy` — don't copy, just tag in place (use with caution)
- `--search-artist "Name"` — override artist for matching
- `--search-album "Title"` — override album for matching

---

## Library Management

```bash
# Re-sync existing library tags with MusicBrainz
docker exec -u abc beets beet mbsync

# Re-fetch missing album art
docker exec -u abc beets beet fetchart

# Re-embed art into all files
docker exec -u abc beets beet embedart

# Re-fetch lyrics
docker exec -u abc beets beet lyrics

# Calculate ReplayGain for all tracks
docker exec -u abc beets beet replaygain

# Re-fetch genres
docker exec -u abc beets beet lastgenre
```

---

## Search & Inspect

```bash
# List all albums
docker exec -u abc beets beet list -a

# Search by artist
docker exec -u abc beets beet list artist:Radiohead

# Search by year
docker exec -u abc beets beet list year:2024

# Show detailed tags for a track
docker exec -u abc beets beet info "track title"

# Show missing tracks in albums
docker exec -u abc beets beet missing

# Find duplicates
docker exec -u abc beets beet duplicates
docker exec -u abc beets beet duplicates -a  # album level
```

---

## File Integrity

```bash
# Check for corrupt files
docker exec -u abc beets beet bad

# Check specific folder
docker exec -u abc beets beet bad path:/music/Artist/Album
```

---

## Stats & Info

```bash
# Show loaded plugins and version
docker exec -u abc beets beet version

# Count tracks and albums
docker exec -u abc beets beet stats

# Show current config
docker exec -u abc beets beet config
```

---

## Paths

| Path (in container) | Host path | Description |
|---------------------|-----------|-------------|
| `/music` | `/mnt/storage/media/music` | Library (RW) |
| `/downloads` | `/mnt/storage2/downloads` | All download sources |
| `/downloads/slskd` | `/mnt/storage2/downloads/slskd` | Soulseek |
| `/downloads/torrents` | `/mnt/storage2/downloads/torrents` | qBittorrent |
| `/downloads/aria2` | `/mnt/storage2/downloads/aria2` | Aria2 |
| `/downloads/pyload` | `/mnt/storage2/downloads/pyload` | pyLoad |
| `/config` | `/mnt/ssd/docker-data/beets` | DB + logs |

---

## Library Organization

Files are organized as:
```
/music/
  Artist/
    2024 - Album/
      01 - Track Title.flac
      cover.jpg
    2024 - Multi Disc Album/
      1-01 - Track Title.flac    ← disc-track for multi-disc
  Various Artists/
    2024 - Compilation/
      01 - Artist - Title.flac
  Singletons/
    Artist/
      Title.flac
```

---

## Interactive shell

```bash
docker exec -it -u abc beets bash
# then: beet import /downloads/slskd
```
