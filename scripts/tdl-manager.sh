#!/bin/bash
# tdl-manager.sh - Full TDL download manager with resume capability
# Usage: ./scripts/tdl-manager.sh [start|stop|status|fix|logs|attach]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/mnt/storage/downloads/telegram/tdl-download.log"
PID_FILE="/tmp/tdl-manager.pid"
TMUX_SESSION="tdl-download"

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# Get download process info
get_download_pid() {
	docker exec tdl ps aux 2>/dev/null | grep "tdl download" | grep -v grep | awk '{print $1}' || echo ""
}

# Check if download is actually running
check_download_running() {
	local pid=$(get_download_pid)
	if [ -n "$pid" ]; then
		return 0
	else
		return 1
	fi
}

# Check tmux session
check_tmux_session() {
	tmux has-session -t "$TMUX_SESSION" 2>/dev/null
}

# Get download statistics
get_stats() {
	if check_download_running; then
		info "Download process: ${GREEN}RUNNING${NC} (PID: $(get_download_pid))"

		# Count temp files (active downloads)
		local temp_count=$(docker exec tdl find /downloads/.skip-index -name "*.tmp" 2>/dev/null | wc -l)
		local done_count=$(docker exec tdl find /downloads/.skip-index -type f ! -name "*.tmp" 2>/dev/null | wc -l)

		if [ "$temp_count" -gt 0 ]; then
			info "Active downloads: $temp_count files"
			docker exec tdl ls -la /downloads/.skip-index/*.tmp 2>/dev/null | awk '{printf "  - %s (%s)\n", $9, $5}' | head -5
		fi

		if [ "$done_count" -gt 0 ]; then
			info "Completed in session: $done_count files"
		fi

		# Show recent log activity
		info "Recent activity (last 3 lines):"
		tail -3 "$LOG_FILE" 2>/dev/null | grep -v "^$" | head -3 | sed 's/^/  /'
	else
		warning "Download process: ${RED}NOT RUNNING${NC}"
	fi

	if check_tmux_session; then
		info "Tmux session: ${GREEN}EXISTS${NC} ($TMUX_SESSION)"
	else
		warning "Tmux session: ${RED}NOT FOUND${NC}"
	fi
}

# Start download
cmd_start() {
	log "Starting TDL download..."

	# Check if already running
	if check_download_running; then
		success "Download is already running!"
		get_stats
		echo ""
		echo "Attach with: ./scripts/tdl-manager.sh attach"
		return 0
	fi

	# Ensure container is running
	if ! docker ps --filter "name=^tdl$" --filter "status=running" --format "{{.Names}}" | grep -q "^tdl$"; then
		log "Container not running, starting it..."
		cd "$PROJECT_ROOT"
		docker compose up -d tdl
		sleep 2
	fi

	# Kill old tmux session if exists
	if check_tmux_session; then
		log "Removing old tmux session..."
		tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
	fi

	# Build download command with resume support
	local download_cmd="mkdir -p /downloads/.skip-index && \
echo \"[\\$(date)] === TDL Download Started ===\" && \
echo \"[\\$(date)] Resuming from previous state (skip-same enabled)\" && \
tdl download \
  -f /downloads/saved-messages-all.json \
  -d /downloads/.skip-index \
  -i mp4,mkv,avi,mov,wmv,webm \
  --skip-same \
  -l 2 \
  --template \"{{ .MessageID }}_{{ .FileName }}\" \
  2>&1 && \
echo \"[\\$(date)] Moving completed files...\" && \
find /downloads/.skip-index -maxdepth 1 -type f -exec mv {} /adult-telegram/ \\; && \
rm -rf /downloads/.skip-index && \
echo \"[\\$(date)] === Download Session Complete ===\""

	# Start in tmux
	tmux new-session -d -s "$TMUX_SESSION" "docker exec tdl sh -c '$download_cmd' 2>&1 | tee -a $LOG_FILE"

	sleep 2

	if check_download_running; then
		success "Download started successfully!"
		echo ""
		echo "Commands:"
		echo "  ./scripts/tdl-manager.sh attach    # Watch live"
		echo "  ./scripts/tdl-manager.sh logs      # View logs"
		echo "  ./scripts/tdl-manager.sh status    # Check status"
	else
		error "Failed to start download"
		return 1
	fi
}

# Stop download gracefully
cmd_stop() {
	log "Stopping TDL download..."

	if check_download_running; then
		local pid=$(get_download_pid)
		log "Sending SIGTERM to download process (PID: $pid)..."
		docker exec tdl kill -TERM "$pid" 2>/dev/null || true

		# Wait for graceful shutdown
		for i in {1..10}; do
			if ! check_download_running; then
				success "Download stopped gracefully"
				break
			fi
			sleep 1
		done

		# Force kill if still running
		if check_download_running; then
			warning "Force killing download process..."
			docker exec tdl kill -9 "$pid" 2>/dev/null || true
		fi
	else
		warning "No download process running"
	fi

	# Kill tmux session
	if check_tmux_session; then
		log "Killing tmux session..."
		tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
	fi

	success "Stopped"
}

# Fix/restart everything (hard reset)
cmd_fix() {
	log "=== TDL HARD RESET ==="

	# Step 1: Stop everything
	cmd_stop || true

	# Step 2: Remove and recreate container
	log "Recreating container..."
	cd "$PROJECT_ROOT"
	docker stop tdl 2>/dev/null || true
	docker rm tdl 2>/dev/null || true
	docker compose up -d tdl

	# Wait for container
	for i in {1..30}; do
		if docker ps --filter "name=^tdl$" --filter "status=running" --format "{{.Names}}" | grep -q "^tdl$"; then
			break
		fi
		sleep 1
	done

	# Step 3: Start fresh
	cmd_start
}

# Show logs
cmd_logs() {
	if [ -f "$LOG_FILE" ]; then
		echo -e "${CYAN}=== Recent Log Output ===${NC}"
		tail -50 "$LOG_FILE" | grep -v "^$" | tail -20
	else
		error "Log file not found: $LOG_FILE"
	fi
}

# Attach to tmux
cmd_attach() {
	if check_tmux_session; then
		echo "Attaching to tmux session (Ctrl+B then D to detach)..."
		sleep 1
		tmux attach -t "$TMUX_SESSION"
	else
		error "No tmux session found. Start download first: ./scripts/tdl-manager.sh start"
	fi
}

# Show status
cmd_status() {
	echo -e "${CYAN}=== TDL Download Status ===${NC}"
	echo ""

	# Container status
	if docker ps --filter "name=^tdl$" --filter "status=running" --format "{{.Names}}" | grep -q "^tdl$"; then
		success "Container: RUNNING"
		docker ps --filter "name=^tdl$" --format "  Uptime: {{.Status}}" | head -1
	else
		error "Container: NOT RUNNING"
	fi

	echo ""
	get_stats

	echo ""
	info "Quick Commands:"
	echo "  start   - Start/resume download"
	echo "  stop    - Stop download gracefully"
	echo "  fix     - Hard reset (kill all, restart fresh)"
	echo "  attach  - Watch live in tmux"
	echo "  logs    - View recent logs"
	echo "  status  - This screen"
}

# Main command handler
case "${1:-status}" in
start)
	cmd_start
	;;
stop)
	cmd_stop
	;;
fix | restart | reset)
	cmd_fix
	;;
status | check)
	cmd_status
	;;
logs | log)
	cmd_logs
	;;
attach | watch)
	cmd_attach
	;;
*)
	echo "Usage: $0 [start|stop|fix|status|logs|attach]"
	echo ""
	echo "Commands:"
	echo "  start   - Start or resume download (safe to run multiple times)"
	echo "  stop    - Stop download gracefully"
	echo "  fix     - Full reset: kill everything, recreate container, start fresh"
	echo "  status  - Show current status"
	echo "  logs    - View recent log output"
	echo "  attach  - Attach to live tmux session"
	echo ""
	cmd_status
	;;
esac
