#!/usr/bin/env python3
"""Bulk download tracks from a tab-separated music export via SpotiFLAC.

Input format (Apple Music export / manual):
  Title\tDuration\tArtist\tAlbum\tGenre\tPlays\t...

Usage:
  python3 config/spotiflac/spotiflac-bulk-queue.py                     # uses music.txt in same dir
  python3 config/spotiflac/spotiflac-bulk-queue.py path/to/music.txt
  python3 config/spotiflac/spotiflac-bulk-queue.py music.txt --dry-run
  python3 config/spotiflac/spotiflac-bulk-queue.py music.txt --delay 1.0
  python3 config/spotiflac/spotiflac-bulk-queue.py --drain-queue       # process stuck queue items
"""

import argparse
import json
import re
import sqlite3
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

SPOTIFLAC_URL = "http://127.0.0.1:8097"
BEETS_DB = Path("/mnt/ssd/docker-data/beets/library.db")
DEFAULT_MUSIC_TXT = Path(__file__).parent / "music.txt"


def _normalize(s: str) -> str:
    """Lowercase, strip featured artists, remix tags, punctuation for fuzzy matching."""
    s = s.lower()
    s = re.sub(r"\(feat\.?[^)]*\)", "", s)
    s = re.sub(r"\bfeat\.?\s+\S+.*", "", s)
    s = re.sub(r"\s*-\s*(original mix|radio edit|extended mix|remaster(ed)?.*|live.*)$", "", s)
    s = re.sub(r"[^\w\s]", "", s)
    return re.sub(r"\s+", " ", s).strip()


def in_beets(title: str, artist: str) -> bool:
    """Return True if a track matching title+artist exists in the beets library."""
    if not BEETS_DB.exists():
        return False
    nt, na = _normalize(title), _normalize(artist)
    try:
        con = sqlite3.connect(f"file:{BEETS_DB}?mode=ro", uri=True)
        cur = con.cursor()
        cur.execute(
            "SELECT 1 FROM items WHERE lower(title)=? AND (lower(artist)=? OR lower(artists) LIKE ?) LIMIT 1",
            (nt, na, f"%{na}%"),
        )
        found = cur.fetchone() is not None
        if not found:
            cur.execute("SELECT 1 FROM items WHERE lower(title)=? LIMIT 1", (nt,))
            found = cur.fetchone() is not None
        con.close()
        return found
    except Exception:
        return False


def api_post(path: str, payload: dict, timeout: int = 15) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{SPOTIFLAC_URL}{path}",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def api_get(path: str) -> dict:
    req = urllib.request.Request(f"{SPOTIFLAC_URL}{path}")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def search_track(title: str, artist: str) -> dict | None:
    query = f"{title} {artist}"
    try:
        result = api_post("/api/spotify/search", {"query": query, "type": "track"})
        tracks = result.get("tracks", [])
        return tracks[0] if tracks else None
    except Exception as e:
        print(f"  [search error] {e}", file=sys.stderr)
        return None


def download_track(track: dict) -> bool:
    """Download via /api/download (synchronous). spotify_id drives Tidal lookup."""
    try:
        result = api_post("/api/download", {
            "isrc": track["id"],
            "spotify_id": track["id"],
            "track_name": track["name"],
            "artist_name": track["artists"],
            "album_name": track["album_name"],
        }, timeout=120)
        if result.get("success"):
            return True
        err = result.get("error", "unknown error")
        print(f"  [download error] {err}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"  [download error] {e}", file=sys.stderr)
        return False


def parse_music_txt(path: Path) -> list[tuple[str, str, str]]:
    """Return list of (title, artist, album) from tab-separated music export, deduped within file."""
    tracks = []
    seen: set[tuple[str, str]] = set()
    file_dupes = 0
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            title = parts[0].strip()
            artist = parts[2].strip()
            album = parts[3].strip() if len(parts) > 3 else ""
            if not title or not artist or artist.isdigit():
                continue
            key = (_normalize(title), _normalize(artist))
            if key in seen:
                file_dupes += 1
                continue
            seen.add(key)
            tracks.append((title, artist, album))
    if file_dupes:
        print(f"Skipped {file_dupes} duplicate entries within {path.name}")
    return tracks


def drain_queue(delay: float) -> None:
    """Process all 'queued' items in the SpotiFLAC queue via /api/download."""
    try:
        data = api_get("/api/download/queue")
    except Exception as e:
        print(f"Failed to fetch queue: {e}", file=sys.stderr)
        return

    pending = [q for q in data.get("queue", []) if q["status"] in ("queued", "downloading")]
    print(f"Found {len(pending)} pending/stuck items in queue")

    done = failed = 0
    for i, item in enumerate(pending, 1):
        isrc = item["isrc"]
        print(f"[{i}/{len(pending)}] {item['track_name']} — {item['artist_name']}", end=" ", flush=True)
        try:
            result = api_post("/api/download", {
                "isrc": isrc,
                "spotify_id": isrc,
                "track_name": item["track_name"],
                "artist_name": item["artist_name"],
                "album_name": item["album_name"],
            }, timeout=120)
            if result.get("success"):
                print("→ done")
                done += 1
            else:
                print(f"→ FAILED: {result.get('error', '?')}")
                failed += 1
        except Exception as e:
            print(f"→ ERROR: {e}")
            failed += 1
        time.sleep(delay)

    print(f"\nDone: {done} downloaded, {failed} failed")


def main():
    parser = argparse.ArgumentParser(description="Bulk download music via SpotiFLAC")
    parser.add_argument("input", nargs="?", default=str(DEFAULT_MUSIC_TXT),
                        help=f"Path to music.txt (default: {DEFAULT_MUSIC_TXT})")
    parser.add_argument("--dry-run", action="store_true", help="Parse only, no API calls")
    parser.add_argument("--delay", type=float, default=0.3, help="Seconds between requests (default: 0.3)")
    parser.add_argument("--skip", type=int, default=0, help="Skip first N tracks")
    parser.add_argument("--limit", type=int, default=0, help="Stop after N tracks (0=all)")
    parser.add_argument("--drain-queue", action="store_true", help="Process all stuck 'queued' items in SpotiFLAC")
    args = parser.parse_args()

    if args.drain_queue:
        drain_queue(args.delay)
        return

    music_txt = Path(args.input)
    if not music_txt.exists():
        print(f"music.txt not found at {music_txt} — nothing to do")
        sys.exit(0)

    tracks = parse_music_txt(music_txt)
    if not tracks:
        print(f"No tracks in {music_txt} — nothing to do")
        sys.exit(0)

    print(f"Parsed {len(tracks)} tracks from {music_txt.name}")

    if args.skip:
        tracks = tracks[args.skip:]
        print(f"Skipping first {args.skip}, processing {len(tracks)} remaining")
    if args.limit:
        tracks = tracks[:args.limit]
        print(f"Limiting to {args.limit} tracks")

    if args.dry_run:
        print("\nDry run - first 10 tracks:")
        for t, a, al in tracks[:10]:
            print(f"  {t} — {a} [{al}]")
        return

    if BEETS_DB.exists():
        print(f"Beets library found — will skip already-imported tracks")
    else:
        print(f"Warning: beets library not found at {BEETS_DB}, skipping collection check")

    downloaded = failed = not_found = already_have = 0

    for i, (title, artist, album) in enumerate(tracks, 1):
        print(f"[{i}/{len(tracks)}] {title} — {artist}", end=" ", flush=True)

        if in_beets(title, artist):
            print("→ already in library, skipping")
            already_have += 1
            continue

        result = search_track(title, artist)
        if not result:
            print("→ NOT FOUND")
            not_found += 1
            time.sleep(args.delay)
            continue

        ok = download_track(result)
        if ok:
            print(f"→ done ({result['name']} — {result['artists']})")
            downloaded += 1
        else:
            print("→ FAILED")
            failed += 1

        time.sleep(args.delay)

    print(f"\nDone: {downloaded} downloaded, {not_found} not found, {failed} failed, {already_have} already in library")


if __name__ == "__main__":
    main()
