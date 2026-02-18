#!/bin/bash
set -euo pipefail

# Rsync data from /mnt/storage to /mnt/storage2 (local HDD-to-HDD, both USB 3.0)
# Uses tmux session "storage-migrate" — auto-attaches or creates
# Safe to re-run anytime (rsync resumes where it left off)
# Pre-verifies which dirs are already synced before touching anything.
#
# Usage:
#   bash scripts/rsync-to-storage2.sh          # attach/create tmux session
#   bash scripts/rsync-to-storage2.sh --worker  # (internal) runs inside tmux

SESSION="storage-migrate"
LOGFILE="/tmp/storage-migrate.log"

# If not called with --worker, handle tmux session management
if [[ "${1:-}" != "--worker" ]]; then
    SCRIPT_PATH="$(readlink -f "$0")"

    # If session exists, just attach to it
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        echo "Session '$SESSION' already running — attaching..."
        echo "  (Detach with Ctrl+B, D to leave it running in background)"
        sleep 1
        exec tmux attach-session -t "$SESSION"
    fi

    # Create new session running the worker
    echo "Creating tmux session '$SESSION'..."
    echo "  Log: $LOGFILE"
    echo "  Detach: Ctrl+B, D (keeps running)"
    echo "  Re-attach: tmux attach -t $SESSION"
    sleep 1
    exec tmux new-session -s "$SESSION" "bash '$SCRIPT_PATH' --worker; echo 'Press Enter to close'; read"
fi

# ============================================================
# Worker — runs inside tmux
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SRC="/mnt/storage"
DST="/mnt/storage2"

DIRS=(
    "media/movies"
    "media/tv"
    "media/adult"
    "downloads"
    "photos"
    "backrest"
    "velld"
)

log()  { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOGFILE"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*" | tee -a "$LOGFILE"; }
err()  { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOGFILE"; }
info() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOGFILE"; }

show_status() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Storage Migration Status${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    df -h "$SRC" "$DST" 2>/dev/null | column -t
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
}

# Pre-flight checks
if [[ ! -d "$DST" ]]; then
    err "$DST not mounted!"
    exit 1
fi

if docker compose ps --quiet 2>/dev/null | head -1 | grep -q .; then
    warn "Stack is still running! Stop it first: docker compose down"
    read -rp "Continue anyway? (y/N) " ans
    [[ "$ans" == "y" ]] || exit 1
fi

echo "" > "$LOGFILE"
show_status

# ============================================================
# Pre-verification: check which dirs are already synced
# ============================================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Checking existing data on storage2...${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

NEEDS_SYNC=()
ALREADY_SYNCED=()
MISSING_SRC=()

check_dir_status() {
    local dir="$1"
    local src_path="$SRC/$dir"
    local dst_path="$DST/$dir"

    if [[ ! -d "$src_path" ]]; then
        echo "missing_src"
        return
    fi

    if [[ ! -d "$dst_path" ]]; then
        echo "needs_sync"
        return
    fi

    local src_count dst_count src_bytes dst_bytes
    src_count=$(find "$src_path" -type f 2>/dev/null | wc -l)
    dst_count=$(find "$dst_path" -type f 2>/dev/null | wc -l)
    src_bytes=$(du -sb "$src_path" 2>/dev/null | cut -f1)
    dst_bytes=$(du -sb "$dst_path" 2>/dev/null | cut -f1)

    if [[ "$src_count" -eq "$dst_count" && "$src_bytes" -eq "$dst_bytes" ]]; then
        echo "synced"
    elif [[ "$dst_count" -gt 0 ]]; then
        echo "partial"
    else
        echo "needs_sync"
    fi
}

for dir in "${DIRS[@]}"; do
    src_path="$SRC/$dir"
    dst_path="$DST/$dir"
    status=$(check_dir_status "$dir")

    case "$status" in
        synced)
            src_count=$(find "$src_path" -type f 2>/dev/null | wc -l)
            src_size=$(du -sh "$src_path" 2>/dev/null | cut -f1)
            echo -e "  ${GREEN}✓ MATCH${NC}    $dir  ($src_count files, $src_size)"
            ALREADY_SYNCED+=("$dir")
            ;;
        partial)
            src_count=$(find "$src_path" -type f 2>/dev/null | wc -l)
            dst_count=$(find "$dst_path" -type f 2>/dev/null | wc -l)
            src_size=$(du -sh "$src_path" 2>/dev/null | cut -f1)
            dst_size=$(du -sh "$dst_path" 2>/dev/null | cut -f1)
            echo -e "  ${YELLOW}~ PARTIAL${NC}  $dir  (src: $src_count files/$src_size — dst: $dst_count files/$dst_size)"
            NEEDS_SYNC+=("$dir")
            ;;
        needs_sync)
            src_size=$(du -sh "$src_path" 2>/dev/null | cut -f1)
            src_count=$(find "$src_path" -type f 2>/dev/null | wc -l)
            echo -e "  ${RED}✗ MISSING${NC}  $dir  ($src_count files, $src_size)"
            NEEDS_SYNC+=("$dir")
            ;;
        missing_src)
            echo -e "  ${CYAN}— SKIP${NC}     $dir  (not in source)"
            MISSING_SRC+=("$dir")
            ;;
    esac
done

echo ""

# ============================================================
# Summary and confirm
# ============================================================
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ ${#ALREADY_SYNCED[@]} -gt 0 && ${#NEEDS_SYNC[@]} -eq 0 ]]; then
    echo -e "${GREEN}  All directories already match — nothing to rsync!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    log "All ${#ALREADY_SYNCED[@]} directories verified matching on both storage and storage2."
    echo ""
    echo "Next steps:"
    echo "  1. cd ~/potatostack"
    echo "  2. Follow NEWHDD.md steps 3-6"
    echo "  3. Or re-run Claude Code to apply docker-compose.yml changes"
    log "Full log: $LOGFILE"
    exit 0
fi

echo -e "${BLUE}  Migration Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
printf "  %-20s %s\n" "Already synced:" "${#ALREADY_SYNCED[@]} dir(s)"
printf "  %-20s %s\n" "Need transfer:" "${#NEEDS_SYNC[@]} dir(s)"
[[ ${#MISSING_SRC[@]} -gt 0 ]] && printf "  %-20s %s\n" "Not in source:" "${#MISSING_SRC[@]} dir(s)"
echo ""

if [[ ${#NEEDS_SYNC[@]} -eq 0 ]]; then
    log "Nothing to sync."
    exit 0
fi

echo -e "Directories to sync:"
for dir in "${NEEDS_SYNC[@]}"; do
    echo -e "  ${YELLOW}→${NC} $dir"
done
echo ""

read -rp "Proceed with rsync for ${#NEEDS_SYNC[@]} dir(s)? (y/N) " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { log "Aborted by user."; exit 0; }

echo ""
log "Starting rsync: $SRC → $DST"
log "Resumable — re-run this script if interrupted"
echo ""

# Rsync flags optimized for local HDD-to-HDD (same machine, USB 3.0):
#   -a            archive mode (preserves permissions, timestamps, symlinks, etc.)
#   -H            preserve hard links
#   -A            preserve ACLs
#   -X            preserve extended attributes
#   --info=progress2  single-line overall progress (not per-file spam)
#   --no-compress  NO compression — local transfer, CPU would be bottleneck not I/O
#   --whole-file   skip delta algorithm — local disk, just copy whole files (faster)
#   --inplace      write directly to destination file (less I/O, no temp file + rename)
#   --preallocate  preallocate destination files (reduces fragmentation on ext4)
#   --delete       remove files in dst that don't exist in src (clean mirror)
RSYNC_OPTS=(
    -aHAX
    --info=progress2
    --no-compress
    --whole-file
    --inplace
    --preallocate
    --delete
    --human-readable
)

TOTAL=${#NEEDS_SYNC[@]}
CURRENT=0
FAILED=()
COMPLETED=()

for dir in "${NEEDS_SYNC[@]}"; do
    CURRENT=$((CURRENT + 1))
    src_path="$SRC/$dir"
    dst_parent="$DST/$(dirname "$dir")"

    src_size=$(du -sh "$src_path" 2>/dev/null | cut -f1)
    src_files=$(find "$src_path" -type f 2>/dev/null | wc -l)

    echo -e "${BLUE}────────────────────────────────────────${NC}"
    log "[$CURRENT/$TOTAL] $dir — $src_size, $src_files files"
    echo -e "${BLUE}────────────────────────────────────────${NC}"

    mkdir -p "$dst_parent"

    start_time=$(date +%s)
    if rsync "${RSYNC_OPTS[@]}" "$src_path/" "$DST/$dir/"; then
        elapsed=$(( $(date +%s) - start_time ))
        mins=$((elapsed / 60))
        secs=$((elapsed % 60))
        log "[$CURRENT/$TOTAL] Done: $dir (${mins}m ${secs}s)"
        COMPLETED+=("$dir")
    else
        err "[$CURRENT/$TOTAL] Failed: $dir (exit code $?)"
        FAILED+=("$dir")
    fi
    echo ""
done

echo ""
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}  MIGRATION COMPLETE${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
show_status

if [[ ${#ALREADY_SYNCED[@]} -gt 0 ]]; then
    log "Already matched (${#ALREADY_SYNCED[@]}) — skipped:"
    for c in "${ALREADY_SYNCED[@]}"; do echo -e "  ${GREEN}✓${NC} $c"; done
fi

if [[ ${#COMPLETED[@]} -gt 0 ]]; then
    log "Transferred (${#COMPLETED[@]}/$TOTAL):"
    for c in "${COMPLETED[@]}"; do echo -e "  ${GREEN}✓${NC} $c"; done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    err "Failed (${#FAILED[@]}/$TOTAL) — re-run script to retry:"
    for f in "${FAILED[@]}"; do echo -e "  ${RED}✗${NC} $f"; done
else
    echo ""
    log "All transfers successful!"
    echo ""
    echo "Next steps:"
    echo "  1. cd ~/potatostack"
    echo "  2. Follow NEWHDD.md steps 3-6"
    echo "  3. Or re-run Claude Code to apply changes automatically"
fi

log "Full log: $LOGFILE"
