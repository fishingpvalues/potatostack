#!/bin/bash
################################################################################
# Alternative Backrest Alerting Strategy
# Monitors backrest logs and oplog to detect backup failures
# Use this if backrest hooks don't work in your version
################################################################################

set -euo pipefail

NTFY_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC_CRITICAL="${NTFY_TOPIC_CRITICAL:-potatostack-critical}"
NTFY_TOPIC_INFO="${NTFY_TOPIC_INFO:-potatostack-info}"
NTFY_DEFAULT_TAGS="${NTFY_DEFAULT_TAGS:-potatostack,backup}"

BACKREST_CONTAINER="backrest"
LAST_SUCCESS_FILE="/tmp/last-backrest-success"

ntfy_send() {
	local topic="$1"
	local priority="$2"
	local title="$3"
	local message="$4"

	curl -fsS -X POST "${NTFY_URL}/${topic}" \
		-H "Title: ${title}" \
		-H "Tags: ${NTFY_DEFAULT_TAGS},backrest" \
		-H "Priority: ${priority}" \
		--connect-timeout 10 \
		--max-time 10 \
		-d "${message}" 2>/dev/null || true
}

echo "=========================================="
echo "Backrest Log Monitor"
echo "=========================================="
echo "Monitoring backrest container logs for backup status..."
echo ""

while true; do
	now=$(date +%s)

	# Check for failed backups in recent logs
	failed_backups=$(docker logs "${BACKREST_CONTAINER}" --since 5m 2>&1 | grep -c "task failed.*backup for plan" || echo "0")

	if [ "$failed_backups" -gt 0 ]; then
		# Check if we've already alerted recently
		if [ -f "$LAST_SUCCESS_FILE" ]; then
			last_alert=$(cat "$LAST_SUCCESS_FILE" 2>/dev/null || echo "0")
			if [ $((now - last_alert)) -lt 300 ]; then
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Backup failure detected, but alert sent recently (< 5 min ago)"
				sleep 60
				continue
			fi
		fi

		ntfy_send "${NTFY_TOPIC_CRITICAL}" "urgent" "🚨 Backrest Backup Failed" "A backup operation failed in the last 5 minutes. Check backrest logs for details."
		echo "$now" >"$LAST_SUCCESS_FILE"
		echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🚨 Sent backup failure alert to ntfy"
	fi

	# Check for successful backups
	success_count=$(docker logs "${BACKREST_CONTAINER}" --since 5m 2>&1 | grep -c "backup completed successfully" || echo "0")

	if [ "$success_count" -gt 0 ]; then
		# Only send success alert if we previously had failures
		if [ -f "$LAST_SUCCESS_FILE" ]; then
			last_alert=$(cat "$LAST_SUCCESS_FILE" 2>/dev/null || echo "0")
			if [ $((now - last_alert)) -ge 300 ]; then
				# We had an alert in the past, now we have success - send recovery
				ntfy_send "${NTFY_TOPIC_INFO}" "default" "✅ Backrest Backup Recovered" "Backrest backup operations are now succeeding after previous failures."
				echo "$now" >"$LAST_SUCCESS_FILE"
				echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Sent backup recovery alert to ntfy"
			fi
		fi
	fi

	sleep 60
done
