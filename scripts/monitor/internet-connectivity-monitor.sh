#!/bin/sh
################################################################################
# Internet Connectivity Monitor - Alert on internet down/up
################################################################################

set -eu

CHECK_INTERVAL="${INTERNET_CHECK_INTERVAL:-30}"
FAIL_THRESHOLD="${INTERNET_FAIL_THRESHOLD:-3}"
URLS="${INTERNET_CHECK_URLS:-https://1.1.1.1 https://www.google.com/generate_204 https://cloudflare.com/cdn-cgi/trace}"
TIMEOUT="${INTERNET_CHECK_TIMEOUT:-5}"
NTFY_TAGS="${INTERNET_NTFY_TAGS:-network,internet}"

if [ -f /notify.sh ]; then
	# shellcheck disable=SC1091
	. /notify.sh
fi

notify_internet() {
	local title="$1"
	local message="$2"
	local priority="$3"
	if ! command -v ntfy_send >/dev/null 2>&1; then
		return
	fi
	ntfy_send "$title" "$message" "$priority" "$NTFY_TAGS"
}

check_url() {
	url="$1"
	if command -v curl >/dev/null 2>&1; then
		curl -fsS --max-time "$TIMEOUT" "$url" >/dev/null 2>&1
		return $?
	fi

	if command -v wget >/dev/null 2>&1; then
		wget -q --timeout="$TIMEOUT" --spider "$url" >/dev/null 2>&1
		return $?
	fi

	return 1
}

echo "=========================================="
echo "Internet Connectivity Monitor Started"
echo "URLs: $URLS"
echo "Interval: ${CHECK_INTERVAL}s  Fail threshold: ${FAIL_THRESHOLD}"
echo "Timeout: ${TIMEOUT}s"
echo "=========================================="

fail_count=0
last_state="unknown"

while true; do
	up=false
	for url in $URLS; do
		if check_url "$url"; then
			up=true
			break
		fi
	done

	if [ "$up" = "true" ]; then
		if [ "$last_state" = "down" ]; then
			notify_internet "PotatoStack - Internet restored" "External connectivity restored." "low"
		fi
		fail_count=0
		last_state="up"
	else
		fail_count=$((fail_count + 1))
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Internet check failed ($fail_count/$FAIL_THRESHOLD)"
		if [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
			if [ "$last_state" != "down" ]; then
				notify_internet "PotatoStack - Internet down" "All checks failed for ${FAIL_THRESHOLD} attempts. URLs: ${URLS}" "urgent"
				last_state="down"
			fi
			fail_count=0
		fi
	fi

	sleep "$CHECK_INTERVAL"
done
