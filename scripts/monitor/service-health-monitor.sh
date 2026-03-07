#!/bin/sh
################################################################################
# Service Health Monitor - HTTP and TCP health checks for key services
# Entry format: name|url  (http://, https://, or tcp://host:port)
################################################################################

set -eu

CHECK_INTERVAL="${SERVICE_MONITOR_INTERVAL:-60}"
FAIL_THRESHOLD="${SERVICE_MONITOR_FAIL_THRESHOLD:-3}"
TIMEOUT="${SERVICE_MONITOR_TIMEOUT:-5}"
NTFY_TAGS="${SERVICE_MONITOR_NTFY_TAGS:-service,health}"

SERVICES="${SERVICE_MONITOR_SERVICES:-\
ntfy|http://ntfy:80 \
grafana|http://grafana:3000/api/health \
jellyfin|http://jellyfin:8096/health \
navidrome|http://navidrome:4533/ping \
vaultwarden|http://vaultwarden:80 \
syncthing|http://syncthing:8384 \
miniflux|http://miniflux:8080/healthcheck \
actual-budget|http://actual-budget:5006 \
ghostfolio|http://ghostfolio:3333 \
prometheus|http://prometheus:9090/-/healthy \
loki|http://loki:3100/ready \
atuin|http://atuin:8888 \
crowdsec|http://crowdsec:6060/metrics \
uptime-kuma|http://uptime-kuma:3001 \
healthchecks|tcp://healthchecks:8000 \
music-potato-ssh|tcp://music-potato:22 \
music-potato-backrest|tcp://music-potato:9898 \
}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_service() {
	local title="$1"
	local message="$2"
	local priority="$3"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$NTFY_TAGS"
}

echo "=========================================="
echo "Service Health Monitor Started"
echo "Interval: ${CHECK_INTERVAL}s  Fail threshold: ${FAIL_THRESHOLD}"
echo "Timeout: ${TIMEOUT}s"
echo "Services: $(echo "$SERVICES" | tr ' ' '\n' | grep -c '|') configured"
echo "=========================================="

STATE_FILE="/tmp/service-health-state"
COUNTER_DIR="/tmp/service-health-counters"
touch "$STATE_FILE"
mkdir -p "$COUNTER_DIR"

check_service() {
	local url="$1"
	case "$url" in
	tcp://*)
		local hostport="${url#tcp://}"
		local host="${hostport%:*}"
		local port="${hostport##*:}"
		nc -zw"$TIMEOUT" "$host" "$port" >/dev/null 2>&1
		return $?
		;;
	*)
		if command -v wget >/dev/null 2>&1; then
			wget -q --timeout="$TIMEOUT" --spider "$url" >/dev/null 2>&1
			return $?
		fi
		if command -v curl >/dev/null 2>&1; then
			curl -fsS --max-time "$TIMEOUT" "$url" >/dev/null 2>&1
			return $?
		fi
		return 1
		;;
	esac
}

while true; do
	for entry in $SERVICES; do
		name="${entry%%|*}"
		url="${entry##*|}"
		counter_file="${COUNTER_DIR}/${name}"
		[ -f "$counter_file" ] || echo 0 >"$counter_file"
		fail_count=$(cat "$counter_file")
		prev=$(grep -F "${name}=" "$STATE_FILE" | tail -n1 | cut -d= -f2 || true)

		if check_service "$url"; then
			echo 0 >"$counter_file"
			if [ "$prev" = "down" ]; then
				grep -v -F "${name}=" "$STATE_FILE" >"${STATE_FILE}.tmp" || true
				mv "${STATE_FILE}.tmp" "$STATE_FILE"
			fi
		else
			fail_count=$((fail_count + 1))
			echo "$fail_count" >"$counter_file"
			echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ ${name} unreachable ($fail_count/$FAIL_THRESHOLD) - $url"

			if [ "$fail_count" -ge "$FAIL_THRESHOLD" ] && [ "$prev" != "down" ]; then
				notify_service "PotatoStack - ${name} down" "${name} failed ${fail_count} consecutive checks. URL: ${url}" "urgent"
				grep -v -F "${name}=" "$STATE_FILE" >"${STATE_FILE}.tmp" || true
				mv "${STATE_FILE}.tmp" "$STATE_FILE"
				echo "${name}=down" >>"$STATE_FILE"
				echo 0 >"$counter_file"
			fi
		fi
	done

	sleep "$CHECK_INTERVAL"
done
