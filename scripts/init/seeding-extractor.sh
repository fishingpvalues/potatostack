#!/bin/bash
################################################################################
# Seeding Extractor - Persistent one-shot extractor for seeding/archive folders
#
# Problem: unpackerr has no persistent state — on restart it re-extracts
# archives that are still present (e.g., kept for seeding).
#
# Solution: Track extracted archives by inode in /config/seeding-extracted.txt.
# Inode is stable across renames, survives restarts, and uniquely identifies
# the physical file even if the path changes.
#
# Seeding folders handled here (NOT by unpackerr's folder watch):
#   /downloads/torrents          (qBittorrent, preserve for seeding)
#   /media/adult                 (qBittorrent adult, preserve for seeding)
#   /storage/downloads/torrent   (HDD torrent downloads, preserve for seeding)
################################################################################

set -euo pipefail

SEEDING_PATHS="/downloads/torrents /media/adult /storage/downloads/torrent"
STATE_FILE="/config/seeding-extracted.txt"
EXTRACT_SUFFIX="_unpackerred"
NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Convert UN_INTERVAL (e.g. "1m", "30s") to seconds for sleep
_interval_secs() {
    local v="${UN_INTERVAL:-1m}"
    case "$v" in
        *h) echo $(( ${v%h} * 3600 )) ;;
        *m) echo $(( ${v%m} * 60 )) ;;
        *s) echo "${v%s}" ;;
        *)  echo 60 ;;
    esac
}
SLEEP_SECS=$(_interval_secs)

touch "$STATE_FILE"

_is_extracted() {
    local inode="$1" dest="$2"
    # Primary: inode-based state (survives dest dir deletion/rename)
    grep -q ":${inode}:" "$STATE_FILE" 2>/dev/null && return 0
    # Fallback: dest dir exists and has content (handles pre-state-file extractions)
    [ -n "$dest" ] && [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]
}

_mark_extracted() {
    local archive="$1" inode="$2"
    echo "$(date +%s):${inode}:${archive}" >> "$STATE_FILE"
}

_notify() {
    local title="$1" message="$2" tags="${3:-package}" priority="${4:-default}"
    local url="${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}"
    [ -n "${NTFY_TOKEN:-}" ] && local auth="-H Authorization: Bearer ${NTFY_TOKEN}" || local auth=""
    # shellcheck disable=SC2086
    curl -fsS -X POST "$url" \
        -H "Title: ${title}" \
        -H "Tags: ${tags}" \
        -H "Priority: ${priority}" \
        ${auth:+-H "$auth"} \
        -d "${message}" >/dev/null 2>&1 || true
}

# For multi-part RARs: only process the entry point (*.rar or *.part1.rar etc.)
# Skip *.r01/r02/... and *.part2.rar/... which are continuation segments.
_is_entry_archive() {
    local f="${1,,}"  # lowercase
    case "$f" in
        # Explicit first-part patterns → process
        *.part1.rar|*.part01.rar|*.part001.rar) return 0 ;;
        # Continuation segments of partN.rar series → skip
        *.part[2-9].rar|*.part[0-9][2-9].rar|*.part[0-9][0-9][2-9].rar) return 1 ;;
        *.part[1-9][0-9].rar|*.part[1-9][0-9][0-9].rar) return 1 ;;
        # Standalone .rar (may be part of .rar/.r01/.r02 multi-part — process it) → process
        *.rar) return 0 ;;
        # zip, 7z are always standalone
        *.zip|*.7z) return 0 ;;
        *) return 1 ;;
    esac
}

_extract_archive() {
    local archive="$1" inode="$2"
    local dir base dest
    dir=$(dirname "$archive")
    base=$(basename "${archive%.*}")
    dest="${dir}/${base}${EXTRACT_SUFFIX}"

    mkdir -p "$dest"

    echo "[$(date)] [Seeding] Extracting: $archive → $dest"
    _notify "Extracting (seeding): $(basename "$archive")" "Dest: ${dest}" "package,arrow_down" "default"

    local ok=0
    case "${archive,,}" in
        *.rar)
            unrar x -o+ "$archive" "$dest/" >/dev/null 2>&1 && ok=1 || true
            ;;
        *.zip)
            unzip -o "$archive" -d "$dest" >/dev/null 2>&1 && ok=1 || true
            ;;
        *.7z)
            7z x "$archive" -o"$dest" -y >/dev/null 2>&1 && ok=1 || true
            ;;
    esac

    if [ "$ok" -eq 1 ]; then
        _mark_extracted "$archive" "$inode"
        chown -R 1000:1000 "$dest" "$dir" 2>/dev/null || true
        chmod -R 755 "$dest" "$dir" 2>/dev/null || true
        echo "[$(date)] [Seeding] Done: $(basename "$archive") (inode $inode)"
        _notify "Extracted (seeding): $(basename "$archive")" "Dest: ${dest}" "white_check_mark,package" "default"
    else
        echo "[$(date)] [Seeding] FAILED: $archive" >&2
        _notify "Extract Failed (seeding): $(basename "$archive")" "Dest: ${dest}" "x,package" "high"
    fi
}

_scan_once() {
    local archive inode dest
    for path in $SEEDING_PATHS; do
        [ -d "$path" ] || continue
        while IFS= read -r -d '' archive; do
            _is_entry_archive "$archive" || continue
            # Skip files actively being downloaded by aria2 (.aria2 control file = in-progress).
            # Exception: if .aria2 hasn't been modified in >1h, aria2 likely crashed and left
            # it orphaned — treat the download as complete and proceed with extraction.
            if [ -f "${archive}.aria2" ]; then
                aria2_age=$(( $(date +%s) - $(stat -c "%Y" "${archive}.aria2" 2>/dev/null || echo 0) ))
                [ "$aria2_age" -lt 3600 ] && continue
                echo "[$(date)] [Seeding] Orphaned .aria2 (${aria2_age}s old), removing: ${archive}.aria2"
                rm -f "${archive}.aria2"
            fi
            inode=$(stat -c "%i" "$archive" 2>/dev/null) || continue
            dest="$(dirname "$archive")/$(basename "${archive%.*}")${EXTRACT_SUFFIX}"
            _is_extracted "$inode" "$dest" && continue
            _extract_archive "$archive" "$inode"
        done < <(find "$path" -maxdepth 3 -type f \
            \( -name "*.rar" -o -name "*.zip" -o -name "*.7z" \) \
            ! -name "*.part" \
            ! -path "*${EXTRACT_SUFFIX}/*" \
            -print0 2>/dev/null)
    done
}

echo "[$(date)] [Seeding] Extractor started (state: $STATE_FILE, interval: ${SLEEP_SECS}s)"

_scan_once

while sleep "$SLEEP_SECS"; do
    _scan_once
done
