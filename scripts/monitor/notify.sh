#!/bin/bash
################################################################################
# ntfy helper - shared notification utilities for monitor scripts
################################################################################

NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOPIC_CRITICAL="${NTFY_TOPIC_CRITICAL:-potatostack-critical}"
NTFY_TOPIC_WARNING="${NTFY_TOPIC_WARNING:-potatostack-warning}"
NTFY_TOPIC_INFO="${NTFY_TOPIC_INFO:-potatostack-info}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
NTFY_DEFAULT_TAGS="${NTFY_DEFAULT_TAGS:-potatostack,monitor}"
NTFY_DEFAULT_PRIORITY="${NTFY_DEFAULT_PRIORITY:-default}"
NTFY_RETRY_COUNT="${NTFY_RETRY_COUNT:-3}"
NTFY_RETRY_DELAY="${NTFY_RETRY_DELAY:-5}"
NTFY_TIMEOUT="${NTFY_TIMEOUT:-10}"

ntfy_send() {
	if [ -z "${NTFY_INTERNAL_URL}" ]; then
		return 0
	fi

	title="$1"
	message="$2"
	priority="${3:-${NTFY_DEFAULT_PRIORITY}}"
	tags="${4:-${NTFY_DEFAULT_TAGS}}"
	topic="${5:-${NTFY_TOPIC}}"
	click="${6:-}"

	url="${NTFY_INTERNAL_URL%/}/${topic}"

	curl_cmd="curl -fsS -X POST \"$url\" \
		-H \"Title: ${title}\" \
		-H \"Tags: ${tags}\" \
		-H \"Priority: ${priority}\" \
		--connect-timeout ${NTFY_TIMEOUT} \
		--max-time ${NTFY_TIMEOUT}"

	if [ -n "$NTFY_TOKEN" ]; then
		curl_cmd="$curl_cmd -H \"Authorization: Bearer ${NTFY_TOKEN}\""
	fi

	if [ -n "$click" ]; then
		curl_cmd="$curl_cmd -H \"Click: ${click}\""
	fi

	curl_cmd="$curl_cmd -d \"$message\""

	if command -v curl >/dev/null 2>&1; then
		attempt=0
		while [ "$attempt" -lt "$NTFY_RETRY_COUNT" ]; do
			if eval "$curl_cmd" >/dev/null 2>&1; then
				return 0
			fi
			attempt=$((attempt + 1))
			if [ "$attempt" -lt "$NTFY_RETRY_COUNT" ]; then
				sleep "$NTFY_RETRY_DELAY"
			fi
		done
		return 1
	fi

	if command -v wget >/dev/null 2>&1; then
		headers="--header=Title: ${title} --header=Tags: ${tags} --header=Priority: ${priority}"
		if [ -n "$NTFY_TOKEN" ]; then
			headers="$headers --header=Authorization: Bearer ${NTFY_TOKEN}"
		fi
		if [ -n "$click" ]; then
			headers="$headers --header=Click: ${click}"
		fi
		# shellcheck disable=SC2086
		wget -q --timeout=${NTFY_TIMEOUT} --post-data "$message" $headers "$url" >/dev/null 2>&1 || true
	fi
}

ntfy_send_json() {
	if [ -z "${NTFY_INTERNAL_URL}" ]; then
		return 0
	fi

	topic="${1:-${NTFY_TOPIC}}"
	title="${2:-Notification}"
	message="${3:-}"
	priority="${4:-${NTFY_DEFAULT_PRIORITY}}"
	tags="${5:-${NTFY_DEFAULT_TAGS}}"
	click="${6:-}"
	attach="${7:-}"
	filename="${8:-}"
	icon="${9:-}"

	url="${NTFY_INTERNAL_URL%/}/${topic}"

	json="{\"title\":\"$title\",\"message\":\"$message\",\"priority\":\"$priority\",\"tags\":[\"${tags//,/\",\"}\"]}"

	if [ -n "$click" ]; then
		json=$(echo "$json" | sed "s/}/\"click\":\"$click\"}/")
	fi

	if [ -n "$attach" ]; then
		json=$(echo "$json" | sed "s/}/\"attach\":\"$attach\"}/")
		if [ -n "$filename" ]; then
			json=$(echo "$json" | sed "s/}/\"filename\":\"$filename\"}/")
		fi
	fi

	if [ -n "$icon" ]; then
		json=$(echo "$json" | sed "s/}/\"icon\":\"$icon\"}/")
	fi

	curl_cmd="curl -fsS -X POST \"$url\" \
		-H \"Content-Type: application/json\" \
		--connect-timeout ${NTFY_TIMEOUT} \
		--max-time ${NTFY_TIMEOUT} \
		-d '$json'"

	if [ -n "$NTFY_TOKEN" ]; then
		curl_cmd="$curl_cmd -H \"Authorization: Bearer ${NTFY_TOKEN}\""
	fi

	if command -v curl >/dev/null 2>&1; then
		attempt=0
		while [ "$attempt" -lt "$NTFY_RETRY_COUNT" ]; do
			if eval "$curl_cmd" >/dev/null 2>&1; then
				return 0
			fi
			attempt=$((attempt + 1))
			if [ "$attempt" -lt "$NTFY_RETRY_COUNT" ]; then
				sleep "$NTFY_RETRY_DELAY"
			fi
		done
		return 1
	fi
}

ntfy_send_critical() {
	ntfy_send "$1" "$2" "urgent" "${NTFY_DEFAULT_TAGS},critical" "${NTFY_TOPIC_CRITICAL}"
}

ntfy_send_warning() {
	ntfy_send "$1" "$2" "high" "${NTFY_DEFAULT_TAGS},warning" "${NTFY_TOPIC_WARNING}"
}

ntfy_send_info() {
	ntfy_send "$1" "$2" "default" "${NTFY_DEFAULT_TAGS},info" "${NTFY_TOPIC_INFO}"
}
