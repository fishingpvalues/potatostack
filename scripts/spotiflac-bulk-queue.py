#!/usr/bin/env python3
"""Bulk queue tracks from a tab-separated music export into SpotiFLAC.

Input format (Apple Music export):
  Title\tDuration\tArtist\tAlbum\tGenre\tPlays\t...

Usage:
  python3 scripts/spotiflac-bulk-queue.py music.txt
  python3 scripts/spotiflac-bulk-queue.py music.txt --dry-run
  python3 scripts/spotiflac-bulk-queue.py music.txt --delay 1.0
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

SPOTIFLAC_URL = "http://127.0.0.1:8097"


def api_post(path: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{SPOTIFLAC_URL}{path}",
        data=data,
        headers={"Content-Type": "application/json"},
    )
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


def add_to_queue(track: dict) -> str | None:
    try:
        result = api_post("/api/download/queue/add", {
            "isrc": track["id"],
            "track_name": track["name"],
            "artist_name": track["artists"],
            "album_name": track["album_name"],
        })
        return result.get("item_id")
    except Exception as e:
        print(f"  [queue error] {e}", file=sys.stderr)
        return None


def parse_music_txt(path: Path) -> list[tuple[str, str, str]]:
    """Return list of (title, artist, album) from tab-separated music export."""
    tracks = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            parts = line.split("\t")
            # Need at least title + duration + artist
            if len(parts) < 3:
                continue
            title = parts[0].strip()
            artist = parts[2].strip()
            album = parts[3].strip() if len(parts) > 3 else ""
            # Skip section headers (no artist column or looks like header)
            if not title or not artist:
                continue
            # Skip lines that are playlist headers like "30." or "MY PLAYLISTS"
            if not artist or artist.isdigit():
                continue
            tracks.append((title, artist, album))
    return tracks


def main():
    parser = argparse.ArgumentParser(description="Bulk queue music into SpotiFLAC")
    parser.add_argument("input", help="Path to music.txt (tab-separated export)")
    parser.add_argument("--dry-run", action="store_true", help="Parse only, no API calls")
    parser.add_argument("--delay", type=float, default=0.3, help="Seconds between requests (default: 0.3)")
    parser.add_argument("--skip", type=int, default=0, help="Skip first N tracks")
    parser.add_argument("--limit", type=int, default=0, help="Stop after N tracks (0=all)")
    args = parser.parse_args()

    tracks = parse_music_txt(Path(args.input))
    print(f"Parsed {len(tracks)} tracks from {args.input}")

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

    queued = 0
    failed = 0
    not_found = 0

    for i, (title, artist, album) in enumerate(tracks, 1):
        print(f"[{i}/{len(tracks)}] {title} — {artist}", end=" ", flush=True)

        result = search_track(title, artist)
        if not result:
            print(f"→ NOT FOUND")
            not_found += 1
            time.sleep(args.delay)
            continue

        item_id = add_to_queue(result)
        if item_id:
            print(f"→ queued ({result['name']} — {result['artists']})")
            queued += 1
        else:
            print(f"→ QUEUE FAILED")
            failed += 1

        time.sleep(args.delay)

    print(f"\nDone: {queued} queued, {not_found} not found, {failed} failed")


if __name__ == "__main__":
    main()
