#!/usr/bin/env python3
"""Bulk download tracks from a tab-separated music export via SpotiFLAC.

Input format (Apple Music export):
  Title\tDuration\tArtist\tAlbum\tGenre\tPlays\t...

Usage:
  python3 scripts/spotiflac-bulk-queue.py music.txt
  python3 scripts/spotiflac-bulk-queue.py music.txt --dry-run
  python3 scripts/spotiflac-bulk-queue.py music.txt --delay 1.0
  python3 scripts/spotiflac-bulk-queue.py --drain-queue   # process stuck queue items
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

SPOTIFLAC_URL = "http://127.0.0.1:8097"


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
                print(f"→ done")
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
    parser.add_argument("input", nargs="?", help="Path to music.txt (tab-separated export)")
    parser.add_argument("--dry-run", action="store_true", help="Parse only, no API calls")
    parser.add_argument("--delay", type=float, default=0.3, help="Seconds between requests (default: 0.3)")
    parser.add_argument("--skip", type=int, default=0, help="Skip first N tracks")
    parser.add_argument("--limit", type=int, default=0, help="Stop after N tracks (0=all)")
    parser.add_argument("--drain-queue", action="store_true", help="Process all stuck 'queued' items in SpotiFLAC")
    args = parser.parse_args()

    if args.drain_queue:
        drain_queue(args.delay)
        return

    if not args.input:
        parser.error("input file required unless --drain-queue")

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

    downloaded = 0
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

        ok = download_track(result)
        if ok:
            print(f"→ done ({result['name']} — {result['artists']})")
            downloaded += 1
        else:
            print(f"→ FAILED")
            failed += 1

        time.sleep(args.delay)

    print(f"\nDone: {downloaded} downloaded, {not_found} not found, {failed} failed")


if __name__ == "__main__":
    main()
