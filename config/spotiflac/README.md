# SpotiFLAC Bulk Importer

Automatically downloads your music wishlist via SpotiFLAC, with duplicate detection against your beets library.

## How it works

1. You add tracks to `music.txt` (tab-separated, Apple Music export format)
2. Dagu runs `spotiflac-bulk-queue.py` nightly at 4am as part of `beets-nightly`
3. Script checks each track against your beets library — already-imported tracks are skipped
4. New tracks are searched on Spotify and downloaded via SpotiFLAC (Tidal/Qobuz FLAC)
5. Beets then imports the downloads, tags them, and moves them to the music library

## music.txt format

Tab-separated, Apple Music export style:

```
Title\tDuration\tArtist\tAlbum\tGenre\tPlays\t...
```

The script reads columns: `[0]=Title`, `[2]=Artist`, `[3]=Album`.

**To get this from Apple Music:**
- Select all tracks in a playlist (Cmd+A)
- Copy (Cmd+C) and paste into a text editor — macOS pastes as TSV
- Save as `music.txt` in this folder

## Manual usage

```bash
# Dry run — see what would be downloaded without actually downloading
python3 config/spotiflac/spotiflac-bulk-queue.py --dry-run

# Download everything in music.txt
python3 config/spotiflac/spotiflac-bulk-queue.py

# Use a different file
python3 config/spotiflac/spotiflac-bulk-queue.py /path/to/other.txt

# Process stuck items in SpotiFLAC's queue
python3 config/spotiflac/spotiflac-bulk-queue.py --drain-queue

# Slow down requests (default: 0.3s between tracks)
python3 config/spotiflac/spotiflac-bulk-queue.py --delay 1.0
```

## Duplicate detection

- **Within music.txt**: identical title+artist entries are deduplicated automatically
- **Against beets library**: tracks already in `/mnt/storage/media/music` are skipped
- Matching is fuzzy: ignores feat. tags, remix suffixes, punctuation differences

## Files

| File | Purpose |
|------|---------|
| `music.txt` | Your wishlist — edit this |
| `spotiflac-bulk-queue.py` | The downloader script |

## Dagu schedule

Runs as the first step of `beets-nightly` (4am daily).
View logs: Dagu UI → beets-nightly → spotiflac-from-list step.
