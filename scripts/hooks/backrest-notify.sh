#!/bin/bash
################################################################################
# Backrest ntfy Notification Hook
# Called by Backrest on backup lifecycle events
################################################################################

set -euo pipefail

NTFY_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC_INFO="${NTFY_TOPIC_INFO:-potatostack-info}"
NTFY_TOPIC_WARNING="${NTFY_TOPIC_WARNING:-potatostack-warning}"
NTFY_TOPIC_CRITICAL="${NTFY_TOPIC_CRITICAL:-potatostack-critical}"
NTFY_DEFAULT_TAGS="${NTFY_DEFAULT_TAGS:-potatostack,backup}"

BACKREST_EVENT="${BACKREST_EVENT:-unknown}"
BACKREST_TASK="${BACKREST_TASK:-unknown}"
BACKREST_REPO="${BACKREST_REPO:-unknown}"
BACKREST_PLAN="${BACKREST_PLAN:-unknown}"
BACKREST_ERROR="${BACKREST_ERROR:-}"
BACKREST_SUMMARY="${BACKREST_SUMMARY:-${BACKREST_EVENT}}"
BACKREST_DURATION="${BACKREST_DURATION:-}"
BACKREST_SNAPSHOT_STATS="${BACKREST_SNAPSHOT_STATS:-}"

ntfy_send() {
	local topic="$1"
	local priority="$2"
	local tags="$3"
	local title="$4"
	local message="$5"

	local url="${NTFY_URL}/${topic}"
	local curl_cmd="curl -fsS -X POST \"${url}\" \
		-H \"Title: ${title}\" \
		-H \"Tags: ${tags}\" \
		-H \"Priority: ${priority}\" \
		--connect-timeout 10 \
		--max-time 10 \
		-d \"${message}\""

	if [ -n "${NTFY_TOKEN:-}" ]; then
		curl_cmd="${curl_cmd} -H \"Authorization: Bearer ${NTFY_TOKEN}\""
	fi

	eval "${curl_cmd}" 2>/dev/null || true
}

determine_event_type() {
	case "${BACKREST_EVENT}" in
	*ERROR | *error) echo "error" ;;
	*WARNING | *warning) echo "warning" ;;
	*SUCCESS | *success) echo "success" ;;
	*START | *start) echo "start" ;;
	*) echo "info" ;;
	esac
}

EVENT_TYPE=$(determine_event_type)

case "${EVENT_TYPE}" in
error)
	NTFY_TOPIC="${NTFY_TOPIC_CRITICAL}"
	NTFY_PRIORITY="urgent"
	NTFY_TAGS="${NTFY_DEFAULT_TAGS},error,critical"

	emoji="🚨"
	title="${emoji} Backup Failed: ${BACKREST_TASK}"
	message="${BACKREST_SUMMARY}${BACKREST_ERROR:+\n\nError: ${BACKREST_ERROR}}"
	;;

warning)
	NTFY_TOPIC="${NTFY_TOPIC_WARNING}"
	NTFY_PRIORITY="high"
	NTFY_TAGS="${NTFY_DEFAULT_TAGS},warning"

	emoji="⚠️"
	title="${emoji} Backup Warning: ${BACKREST_TASK}"
	message="${BACKREST_SUMMARY}${BACKREST_ERROR:+\n\nWarning: ${BACKREST_ERROR}}"
	;;

success)
	NTFY_TOPIC="${NTFY_TOPIC_INFO}"
	NTFY_PRIORITY="default"
	NTFY_TAGS="${NTFY_DEFAULT_TAGS},success"

	emoji="✅"
	title="${emoji} Backup Completed: ${BACKREST_TASK}"
	message="${BACKREST_SUMMARY}${BACKREST_DURATION:+\n\nDuration: ${BACKREST_DURATION}}"

	if [ -n "${BACKREST_SNAPSHOT_STATS:-}" ]; then
		message="${message}\n\n${BACKREST_SNAPSHOT_STATS}"
	fi
	;;

start)
	NTFY_TOPIC="${NTFY_TOPIC_INFO}"
	NTFY_PRIORITY="default"
	NTFY_TAGS="${NTFY_DEFAULT_TAGS},backup"

	emoji="🔄"
	title="${emoji} Backup Started: ${BACKREST_TASK}"
	message="Starting backup for plan: ${BACKREST_PLAN}\nRepo: ${BACKREST_REPO}"
	;;

*)
	NTFY_TOPIC="${NTFY_TOPIC_INFO}"
	NTFY_PRIORITY="default"
	NTFY_TAGS="${NTFY_DEFAULT_TAGS}"

	emoji="ℹ️"
	title="${emoji} Backup Event: ${BACKREST_TASK}"
	message="${BACKREST_SUMMARY}"
	;;
esac

ntfy_send "${NTFY_TOPIC}" "${NTFY_PRIORITY}" "${NTFY_TAGS}" "${title}" "${message}"
