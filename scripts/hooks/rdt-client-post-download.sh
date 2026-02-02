#!/bin/bash
################################################################################
# rdt-client Post-Download Hook - Runs on download completion
# Call from rdt-client WebUI: /hooks/post-download.sh "{name}"
################################################################################

DOWNLOAD_NAME="${1:-unknown}"

NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

LOG_FILE="/data/db/logs/post-download.log"

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "Download finished: ${DOWNLOAD_NAME}"

# Send ntfy notification
if command -v curl >/dev/null 2>&1; then
	auth_header=""
	if [ -n "$NTFY_TOKEN" ]; then
		auth_header="-H \"Authorization: Bearer ${NTFY_TOKEN}\""
	fi
	eval curl -s \
		-H "\"Title: Download Complete\"" \
		-H "\"Tags: arrow_down,real-debrid\"" \
		-H "\"Priority: low\"" \
		"$auth_header" \
		-d "\"${DOWNLOAD_NAME}\"" \
		"\"${NTFY_URL}/${NTFY_TOPIC}\"" >> "$LOG_FILE" 2>&1 || true
elif command -v wget >/dev/null 2>&1; then
	wget -q -O- \
		--header="Title: Download Complete" \
		--header="Tags: arrow_down,real-debrid" \
		--header="Priority: low" \
		${NTFY_TOKEN:+--header="Authorization: Bearer ${NTFY_TOKEN}"} \
		--post-data="${DOWNLOAD_NAME}" \
		"${NTFY_URL}/${NTFY_TOPIC}" >> "$LOG_FILE" 2>&1 || true
fi
