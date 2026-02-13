#!/bin/bash
################################################################################
# qBittorrent Post-Torrent Hook - Runs on torrent completion
# Configure in qBittorrent: /hooks/post-torrent.sh "%N" "%C" "%F" "%D" "%G"
################################################################################

TORRENT_NAME="${1:-unknown}"
CATEGORY="${2:-}"
CONTENT_PATH="${3:-}"
SAVE_PATH="${4:-}"
TAGS="${5:-}"

NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

LOG_FILE="/config/qBittorrent/logs/post-torrent.log"

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "Torrent finished: ${TORRENT_NAME} | category=${CATEGORY} | tags=${TAGS} | path=${CONTENT_PATH}"

# Move files based on tag if no category is set (tag-based sorting fallback)
# Tags can be: movies, tv, music, audiobooks, books, adult, podcasts, youtube
if [ -z "$CATEGORY" ] && [ -n "$TAGS" ]; then
	# Use first matching tag as the target media folder
	TARGET=""
	for tag in $(echo "$TAGS" | tr ',' ' '); do
		tag=$(echo "$tag" | tr -d ' ')
		if [ -d "/media/${tag}" ]; then
			TARGET="/media/${tag}"
			break
		fi
	done
	if [ -n "$TARGET" ] && [ -e "$CONTENT_PATH" ]; then
		log "Moving ${CONTENT_PATH} -> ${TARGET}/"
		mv "$CONTENT_PATH" "$TARGET/" 2>&1 | tee -a "$LOG_FILE" || log "Move failed for ${CONTENT_PATH}"
	fi
fi

# Send ntfy notification
if command -v curl >/dev/null 2>&1; then
	auth_header=""
	if [ -n "$NTFY_TOKEN" ]; then
		auth_header="-H \"Authorization: Bearer ${NTFY_TOKEN}\""
	fi
	eval curl -s \
		-H "\"Title: Torrent Complete\"" \
		-H "\"Tags: arrow_down,qbittorrent\"" \
		-H "\"Priority: low\"" \
		"$auth_header" \
		-d "\"${TORRENT_NAME}${CATEGORY:+ [${CATEGORY}]}\"" \
		"\"${NTFY_URL}/${NTFY_TOPIC}\"" >> "$LOG_FILE" 2>&1 || true
elif command -v wget >/dev/null 2>&1; then
	wget -q -O- \
		--header="Title: Torrent Complete" \
		--header="Tags: arrow_down,qbittorrent" \
		--header="Priority: low" \
		${NTFY_TOKEN:+--header="Authorization: Bearer ${NTFY_TOKEN}"} \
		--post-data="${TORRENT_NAME}${CATEGORY:+ [${CATEGORY}]}" \
		"${NTFY_URL}/${NTFY_TOPIC}" >> "$LOG_FILE" 2>&1 || true
fi
