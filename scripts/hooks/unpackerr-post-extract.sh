#!/bin/bash
################################################################################
# Unpackerr Post-Extract Hook - Sends ntfy notifications on extraction events
################################################################################

NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Variables passed by Unpackerr:
# UN_EVENT: Event type (extract_start, extract_finish, extract_delete, etc.)
# UN_APP: App name (or folder name for standalone)
# UN_PATH: Path to file/folder
# UN_FOLDER: Folder name
# UN_ITEM: Item name
# UN_TYPE: File type (rar, zip, 7z, etc.)
# UN_ERROR: Error message (if any)

title="PotatoStack - Unpackerr"
tags="unpackerr,extract"

case "${UN_EVENT:-}" in
extract_start)
	title="PotatoStack - Unpackerr: Extraction Started"
	message="Started extracting: ${UN_ITEM}\nFolder: ${UN_FOLDER}\nType: ${UN_TYPE}"
	tags="unpackerr,extract,started"
	priority="default"
	;;
extract_finish)
	title="PotatoStack - Unpackerr: Extraction Complete"
	message="Successfully extracted: ${UN_ITEM}\nFolder: ${UN_FOLDER}\nType: ${UN_TYPE}\nPath: ${UN_PATH}"
	tags="unpackerr,extract,success"
	priority="default"
	;;
extract_delete)
	title="PotatoStack - Unpackerr: Archive Deleted"
	message="Deleted original archive: ${UN_ITEM}\nFolder: ${UN_FOLDER}"
	tags="unpackerr,deleted"
	priority="low"
	;;
extract_error)
	title="PotatoStack - Unpackerr: Extraction Failed"
	message="Failed to extract: ${UN_ITEM}\nFolder: ${UN_FOLDER}\nError: ${UN_ERROR}"
	tags="unpackerr,extract,error"
	priority="high"
	;;
*)
	# Unknown event - ignore
	exit 0
	;;
esac

url_target="${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}"

if command -v curl >/dev/null 2>&1; then
	if [ -n "$NTFY_TOKEN" ]; then
		curl -fsS -X POST "$url_target" \
			-H "Title: $title" \
			-H "Tags: $tags" \
			-H "Priority: $priority" \
			-H "Authorization: Bearer $NTFY_TOKEN" \
			-d "$message" >/dev/null 2>&1 || true
	else
		curl -fsS -X POST "$url_target" \
			-H "Title: $title" \
			-H "Tags: $tags" \
			-H "Priority: $priority" \
			-d "$message" >/dev/null 2>&1 || true
	fi
elif command -v wget >/dev/null 2>&1; then
	headers="--header=Title: $title --header=Tags: $tags --header=Priority: $priority"
	if [ -n "$NTFY_TOKEN" ]; then
		headers="$headers --header=Authorization: Bearer $NTFY_TOKEN"
	fi
	wget -q -O- --post-data="$message" $headers "$url_target" >/dev/null 2>&1 || true
fi
