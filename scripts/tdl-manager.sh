#!/bin/bash
# tdl-manager.sh - Self-managing TDL download manager
# Handles VPN disruptions, download hangs, and auto-recovery without external monitors
# Usage: ./scripts/tdl-manager.sh [start|stop|status|fix|logs|attach|monitor]

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
MAX_RETRIES=0  # 0 = infinite retries
RETRY_DELAY=30 # seconds between retries
GLUETUN_API="http://127.0.0.1:8008"
HANG_TIMEOUT=300        # 5 min with no log output = hang
MONITOR_INTERVAL=30     # check every 30s
VPN_WAIT_TIMEOUT=120    # max seconds to wait for VPN
CONTAINER_SETTLE_TIME=5 # seconds to wait after container comes up

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
	local pid
	pid=$(get_download_pid)
	[ -n "$pid" ]
}

# Check tmux session
check_tmux_session() {
	tmux has-session -t "$TMUX_SESSION" 2>/dev/null
}

# Check if tdl container is running
check_container_running() {
	docker ps --filter "name=^tdl$" --filter "status=running" --format "{{.Names}}" 2>/dev/null | grep -q "^tdl$"
}

# Get tdl container ID (short)
get_container_id() {
	docker inspect tdl --format '{{.Id}}' 2>/dev/null | head -c 12
}

# Get gluetun container ID (short)
get_gluetun_id() {
	docker inspect gluetun --format '{{.Id}}' 2>/dev/null | head -c 12
}

# Check VPN is healthy via gluetun API
check_vpn_healthy() {
	local status
	status=$(curl -sf --max-time 5 "$GLUETUN_API/v1/vpn/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
	[ "$status" = "running" ]
}

# Check internet connectivity through tdl container
check_internet_through_vpn() {
	docker exec tdl wget -q -O /dev/null --timeout=5 http://1.1.1.1 2>/dev/null
}

# Wait for VPN to be healthy with timeout
wait_for_vpn() {
	local waited=0
	log "Waiting for VPN to be healthy..."
	while [ "$waited" -lt "$VPN_WAIT_TIMEOUT" ]; do
		if check_vpn_healthy; then
			success "VPN is healthy"
			return 0
		fi
		sleep 5
		waited=$((waited + 5))
		[ $((waited % 15)) -eq 0 ] && info "Still waiting for VPN... (${waited}s/${VPN_WAIT_TIMEOUT}s)"
	done
	error "VPN not healthy after ${VPN_WAIT_TIMEOUT}s"
	return 1
}

# Wait for tdl container to be running
wait_for_container() {
	local waited=0
	local timeout=60
	while [ "$waited" -lt "$timeout" ]; do
		if check_container_running; then
			return 0
		fi
		sleep 2
		waited=$((waited + 2))
	done
	return 1
}

# Ensure tdl container is running (start if needed, no recreation)
ensure_container() {
	if check_container_running; then
		return 0
	fi

	log "Container not running, starting it..."
	cd "$PROJECT_ROOT"
	docker compose up -d tdl
	if wait_for_container; then
		sleep "$CONTAINER_SETTLE_TIME"
		success "Container started"
		return 0
	else
		error "Container failed to start"
		return 1
	fi
}

# Get log file modification time in epoch seconds
get_log_mtime() {
	if [ -f "$LOG_FILE" ]; then
		stat -c %Y "$LOG_FILE" 2>/dev/null || echo "0"
	else
		echo "0"
	fi
}

# Get download statistics
get_stats() {
	if check_download_running; then
		info "Download process: ${GREEN}RUNNING${NC} (PID: $(get_download_pid))"

		local skip_dir="/downloads/.skip-index"
		local temp_count
		temp_count=$(docker exec tdl find "$skip_dir" -name "*.tmp" 2>/dev/null | wc -l)
		local done_count
		done_count=$(docker exec tdl find "$skip_dir" -maxdepth 1 -type f ! -name "*.tmp" 2>/dev/null | wc -l)

		if [ "$temp_count" -gt 0 ]; then
			info "Active downloads: $temp_count files"
			docker exec tdl ls -la "$skip_dir"/*.tmp 2>/dev/null | awk '{printf "  - %s (%s)\n", $9, $5}' | head -5
		fi

		if [ "$done_count" -gt 0 ]; then
			info "Completed in session: $done_count files"
		fi

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

# Kill download process inside container (no container restart)
kill_download_process() {
	if check_download_running; then
		local pid
		pid=$(get_download_pid)
		log "Killing download process (PID: $pid)..."
		docker exec tdl kill -TERM "$pid" 2>/dev/null || true
		for _ in {1..10}; do
			if ! check_download_running; then
				return 0
			fi
			sleep 1
		done
		docker exec tdl kill -9 "$pid" 2>/dev/null || true
	fi
}

# Start download (checks VPN first, handles recovery)
cmd_start() {
	log "Starting TDL download..."

	# Check if already running
	if check_download_running; then
		success "Download is already running! (PID: $(get_download_pid))"
		return 0
	fi

	# Wait for VPN before starting
	if ! wait_for_vpn; then
		error "Cannot start - VPN is not healthy"
		return 1
	fi

	# Ensure container is running
	if ! ensure_container; then
		error "Cannot start - container failed"
		return 1
	fi

	# Verify internet through VPN
	if ! check_internet_through_vpn; then
		warning "Internet not reachable through VPN, waiting..."
		sleep 10
		if ! check_internet_through_vpn; then
			error "Cannot start - no internet through VPN"
			return 1
		fi
	fi

	# Kill old tmux session if exists
	if check_tmux_session; then
		log "Removing old tmux session..."
		tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
	fi

	# Build download command with auto-restart on error
	local download_cmd='
retry_count=0
max_retries='"$MAX_RETRIES"'
retry_delay='"$RETRY_DELAY"'

while true; do
  SKIP_DIR="/downloads/.skip-index"
  rm -rf "$SKIP_DIR"
  mkdir -p "$SKIP_DIR"
  find /adult -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" \
    -o -name "*.mov" -o -name "*.wmv" -o -name "*.webm" \) \
    -exec ln -sf {} "$SKIP_DIR/" \;
  echo "[$(date)] === TDL Download Started (attempt $((retry_count + 1))) ==="
  echo "[$(date)] Indexed $(ls "$SKIP_DIR" | wc -l) existing videos for dedup"

  set +e
  tdl download \
    -f /downloads/saved-messages-all.json \
    -d "$SKIP_DIR" \
    -i mp4,mkv,avi,mov,wmv,webm \
    --skip-same \
    --continue \
    -l 2 \
    --template "{{ .MessageID }}_{{ .FileName }}" \
    2>&1
  exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    echo "[$(date)] Download completed successfully"
    echo "[$(date)] Moving completed files..."
    find "$SKIP_DIR" -maxdepth 1 -type f -exec mv {} /adult-telegram/ \;
    rm -rf "$SKIP_DIR"
    echo "[$(date)] === Download Session Complete ==="
    break
  else
    retry_count=$((retry_count + 1))
    echo "[$(date)] ERROR: Download failed with exit code $exit_code"

    if [ $max_retries -gt 0 ] && [ $retry_count -ge $max_retries ]; then
      echo "[$(date)] Max retries ($max_retries) reached. Giving up."
      exit 1
    fi

    echo "[$(date)] Waiting ${retry_delay}s before retry $retry_count..."
    sleep $retry_delay

    retry_delay=$((retry_delay * 2))
    if [ $retry_delay -gt 300 ]; then
      retry_delay=300
    fi
  fi
done
'

	# Write download script to temp file and execute in tmux
	local script_file="/tmp/tdl-download-script.sh"
	echo "$download_cmd" >"$script_file"
	chmod +x "$script_file"

	# Start in tmux
	tmux new-session -d -s "$TMUX_SESSION" "cat $script_file | docker exec -i tdl sh 2>&1 | tee -a $LOG_FILE"

	sleep 3

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

	kill_download_process

	if check_tmux_session; then
		log "Killing tmux session..."
		tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
	fi

	# Remove PID file to signal intentional stop
	rm -f "$PID_FILE"
	success "Stopped"
}

# Fix: kill download process and restart it (no container recreation)
cmd_fix() {
	log "=== TDL FIX ==="

	# Step 1: Kill download process (NOT the container)
	kill_download_process

	# Kill tmux session
	if check_tmux_session; then
		tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
	fi

	# Step 2: Check if container needs restart (only if not running)
	if ! check_container_running; then
		log "Container not running, waiting for VPN and starting..."
		wait_for_vpn || true
		cd "$PROJECT_ROOT"
		docker compose up -d tdl
		wait_for_container || {
			error "Container failed to start"
			return 1
		}
		sleep "$CONTAINER_SETTLE_TIME"
	fi

	# Step 3: Verify VPN connectivity
	if ! wait_for_vpn; then
		error "VPN not healthy, cannot restart download"
		return 1
	fi

	# Step 4: Start download fresh
	sleep 2
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

# Self-managing monitor: handles VPN changes, download hangs, container restarts
cmd_monitor() {
	log "Starting TDL self-managing monitor (Ctrl+C to stop)..."
	info "Monitors: VPN health, download hangs, container state, gluetun changes"
	echo "$BASHPID" >"$PID_FILE"

	local last_gluetun_id=""
	local last_container_id=""
	local last_log_mtime=0
	local last_download_active=0
	local consecutive_hang_checks=0
	local vpn_down_count=0
	local restart_backoff=30

	# Initialize tracking
	last_gluetun_id=$(get_gluetun_id)
	last_container_id=$(get_container_id)
	last_log_mtime=$(get_log_mtime)
	last_download_active=$(date +%s)

	info "Gluetun ID: $last_gluetun_id"
	info "TDL container ID: $last_container_id"

	# Ensure download is started
	if ! check_download_running; then
		log "Download not running, starting it..."
		cmd_start || true
	fi

	while true; do
		sleep "$MONITOR_INTERVAL"

		# Check PID file - if removed, intentional stop
		if [ ! -f "$PID_FILE" ]; then
			log "PID file removed, exiting monitor (intentional stop)"
			break
		fi

		# === Check 1: Gluetun container changed (recreated by gluetun-monitor or manually) ===
		local current_gluetun_id
		current_gluetun_id=$(get_gluetun_id)
		if [ -n "$last_gluetun_id" ] && [ -n "$current_gluetun_id" ] && [ "$current_gluetun_id" != "$last_gluetun_id" ]; then
			warning "Gluetun container changed: $last_gluetun_id -> $current_gluetun_id"
			log "Waiting for VPN to stabilize after gluetun recreation..."
			last_gluetun_id="$current_gluetun_id"

			# Wait for VPN, then wait for tdl container to come back
			sleep 10
			wait_for_vpn || {
				warning "VPN not healthy after gluetun change, will retry next cycle"
				continue
			}

			# tdl will be recreated by gluetun-monitor or compose dependency
			# Wait for it to come back
			log "Waiting for tdl container to be recreated..."
			wait_for_container || {
				log "TDL container not back yet, starting it..."
				cd "$PROJECT_ROOT"
				docker compose up -d tdl
				wait_for_container || {
					error "TDL container failed to start after gluetun change"
					continue
				}
			}
			sleep "$CONTAINER_SETTLE_TIME"

			# Update container tracking
			last_container_id=$(get_container_id)

			# Restart download in new container
			log "Restarting download after gluetun recreation..."
			if check_tmux_session; then
				tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
			fi
			cmd_start || warning "Failed to restart download after gluetun change"
			last_download_active=$(date +%s)
			consecutive_hang_checks=0
			vpn_down_count=0
			restart_backoff=30
			continue
		fi
		[ -n "$current_gluetun_id" ] && last_gluetun_id="$current_gluetun_id"

		# === Check 2: TDL container changed (recreated externally) ===
		local current_container_id
		current_container_id=$(get_container_id)
		if [ -n "$last_container_id" ] && [ -n "$current_container_id" ] && [ "$current_container_id" != "$last_container_id" ]; then
			warning "TDL container was recreated: $last_container_id -> $current_container_id"
			last_container_id="$current_container_id"

			# Old tmux session is now useless (pointed at old container)
			if check_tmux_session; then
				tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
			fi

			sleep "$CONTAINER_SETTLE_TIME"

			# Restart download in new container
			log "Restarting download in new container..."
			cmd_start || warning "Failed to restart download after container change"
			last_download_active=$(date +%s)
			consecutive_hang_checks=0
			continue
		fi
		[ -n "$current_container_id" ] && last_container_id="$current_container_id"

		# === Check 3: Container not running ===
		if ! check_container_running; then
			warning "TDL container not running"

			# Check VPN first
			if ! check_vpn_healthy; then
				vpn_down_count=$((vpn_down_count + 1))
				warning "VPN also down (count: $vpn_down_count), waiting..."
				continue
			fi
			vpn_down_count=0

			# Start container
			log "Starting tdl container..."
			ensure_container || {
				warning "Failed to start container, will retry"
				continue
			}
			last_container_id=$(get_container_id)

			# Restart download
			if check_tmux_session; then
				tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
			fi
			cmd_start || warning "Failed to restart download after container recovery"
			last_download_active=$(date +%s)
			consecutive_hang_checks=0
			continue
		fi

		# === Check 4: VPN health ===
		if ! check_vpn_healthy; then
			vpn_down_count=$((vpn_down_count + 1))
			if [ "$vpn_down_count" -eq 1 ]; then
				warning "VPN not healthy, download may stall"
			fi
			# Don't try to fix VPN - gluetun-monitor handles that
			# Just track it so we can resume when it comes back
			continue
		fi

		# VPN came back after being down
		if [ "$vpn_down_count" -gt 0 ]; then
			success "VPN recovered after $vpn_down_count failed checks"
			vpn_down_count=0

			# Check if download is still running after VPN recovery
			if ! check_download_running; then
				log "Download stopped during VPN outage, restarting..."
				if check_tmux_session; then
					tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
				fi
				cmd_start || warning "Failed to restart download after VPN recovery"
				last_download_active=$(date +%s)
				consecutive_hang_checks=0
			fi
			continue
		fi

		# === Check 5: Download process died ===
		if ! check_download_running; then
			# Check if download completed
			if tail -5 "$LOG_FILE" 2>/dev/null | grep -q "Download Session Complete"; then
				success "Download completed successfully. Exiting monitor."
				rm -f "$PID_FILE"
				break
			fi

			# Check if tmux session is gone (intentional stop)
			if ! check_tmux_session; then
				log "Tmux session gone - likely intentional stop. Exiting monitor."
				rm -f "$PID_FILE"
				break
			fi

			warning "Download process died, restarting..."
			cmd_start || warning "Failed to restart download"
			last_download_active=$(date +%s)
			consecutive_hang_checks=0
			continue
		fi

		# === Check 6: Download hang detection ===
		local current_mtime
		current_mtime=$(get_log_mtime)
		local now
		now=$(date +%s)

		if [ "$current_mtime" -gt "$last_log_mtime" ]; then
			# Log file was updated - download is making progress
			last_log_mtime="$current_mtime"
			last_download_active="$now"
			consecutive_hang_checks=0
		else
			# No log activity
			local idle_time=$((now - last_download_active))
			if [ "$idle_time" -ge "$HANG_TIMEOUT" ]; then
				consecutive_hang_checks=$((consecutive_hang_checks + 1))
				warning "Download appears hung (no activity for ${idle_time}s, check #$consecutive_hang_checks)"

				# Verify it's actually stuck (not just between files)
				if ! check_internet_through_vpn; then
					warning "Internet not reachable through VPN - network issue, not a hang"
					# Don't kill the download, let VPN recovery handle it
					continue
				fi

				# Kill and restart the download process (NOT the container)
				log "Killing hung download process and restarting..."
				kill_download_process
				if check_tmux_session; then
					tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
				fi

				sleep "$restart_backoff"
				cmd_start || warning "Failed to restart download after hang"
				last_download_active=$(date +%s)

				# Exponential backoff for repeated hangs
				restart_backoff=$((restart_backoff * 2))
				if [ "$restart_backoff" -gt 300 ]; then
					restart_backoff=300
				fi
			fi
		fi
	done
}

# Show status
cmd_status() {
	echo -e "${CYAN}=== TDL Download Status ===${NC}"
	echo ""

	# Container status
	if check_container_running; then
		success "Container: RUNNING"
		docker ps --filter "name=^tdl$" --format "  Uptime: {{.Status}}" | head -1
	else
		error "Container: NOT RUNNING"
	fi

	# VPN status
	echo ""
	if check_vpn_healthy; then
		success "VPN: HEALTHY"
	else
		error "VPN: NOT HEALTHY"
	fi

	# Gluetun ID
	local gid
	gid=$(get_gluetun_id)
	[ -n "$gid" ] && info "Gluetun ID: $gid"

	echo ""
	get_stats

	# Monitor status
	echo ""
	if [ -f "$PID_FILE" ]; then
		local monitor_pid
		monitor_pid=$(cat "$PID_FILE")
		if kill -0 "$monitor_pid" 2>/dev/null; then
			success "Monitor: RUNNING (PID: $monitor_pid)"
		else
			warning "Monitor: STALE PID file (process $monitor_pid not running)"
		fi
	else
		warning "Monitor: NOT RUNNING"
	fi

	echo ""
	local retry_display="infinite"
	[ "$MAX_RETRIES" -gt 0 ] && retry_display="$MAX_RETRIES"
	info "Auto-restart: Enabled (retries: $retry_display, delay: ${RETRY_DELAY}s)"
	info "Hang timeout: ${HANG_TIMEOUT}s"
	echo ""
	info "Quick Commands:"
	echo "  start   - Start/resume download (checks VPN first)"
	echo "  stop    - Stop download gracefully"
	echo "  fix     - Kill download + restart (no container recreation)"
	echo "  attach  - Watch live in tmux"
	echo "  logs    - View recent logs"
	echo "  monitor - Self-managing watchdog (VPN, hangs, recovery)"
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
monitor)
	cmd_monitor
	;;
*)
	echo "Usage: $0 [start|stop|fix|status|logs|attach|monitor]"
	echo ""
	echo "Commands:"
	echo "  start   - Start or resume download (checks VPN health first)"
	echo "  stop    - Stop download gracefully"
	echo "  fix     - Kill download process + restart (no container recreation)"
	echo "  status  - Show current status"
	echo "  logs    - View recent log output"
	echo "  attach  - Attach to live tmux session"
	echo "  monitor - Self-managing watchdog (handles everything)"
	echo ""
	cmd_status
	;;
esac
