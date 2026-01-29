#!/bin/sh
################################################################################
# ntfy helper - shared notification utilities for monitor scripts
################################################################################

NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
NTFY_DEFAULT_TAGS="${NTFY_DEFAULT_TAGS:-potatostack,monitor}"
NTFY_DEFAULT_PRIORITY="${NTFY_DEFAULT_PRIORITY:-default}"

ntfy_send() {
	if [ -z "${NTFY_INTERNAL_URL}" ] || [ -z "${NTFY_TOPIC}" ]; then
		return
	fi

	title="$1"
	message="$2"
	priority="${3:-${NTFY_DEFAULT_PRIORITY}}"
	tags="${4:-${NTFY_DEFAULT_TAGS}}"

	url="${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}"

	if command -v curl >/dev/null 2>&1; then
		if [ -n "$NTFY_TOKEN" ]; then
			curl -fsS -X POST "$url" \
				-H "Title: ${title}" \
				-H "Tags: ${tags}" \
				-H "Priority: ${priority}" \
				-H "Authorization: Bearer ${NTFY_TOKEN}" \
				-d "$message" >/dev/null 2>&1 || true
		else
			curl -fsS -X POST "$url" \
				-H "Title: ${title}" \
				-H "Tags: ${tags}" \
				-H "Priority: ${priority}" \
				-d "$message" >/dev/null 2>&1 || true
		fi
		return
	fi

	if command -v wget >/dev/null 2>&1; then
		headers="--header=Title: ${title} --header=Tags: ${tags} --header=Priority: ${priority}"
		if [ -n "$NTFY_TOKEN" ]; then
			headers="$headers --header=Authorization: Bearer ${NTFY_TOKEN}"
		fi
		# shellcheck disable=SC2086
		wget -q --post-data "$message" $headers "$url" >/dev/null 2>&1 || true
	fi
}
