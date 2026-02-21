#!/bin/bash
################################################################################
# Unpackerr Post-Extract Hook - Sends ntfy notifications on extraction events
# Unpackerr event names: extracting, extracted, extractfailed, deleting, deletefailed
################################################################################

NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

# Variables passed by Unpackerr:
# UN_EVENT:        extracting | extracted | extractfailed | deleting | deletefailed
# UN_APP:          "folder" for folder-mode watchers
# UN_PATH:         path to the item being extracted
# UN_DATA_OUTPUT:  output folder path
# UN_DATA_ARCHIVE_0: first archive filename
# UN_DATA_ERROR:   error message (on failure events)
# UN_DATA_BYTES:   bytes extracted
# UN_DATA_FILES:   number of files extracted

title=""
message=""
tags=""
priority=""

_item="${UN_DATA_ARCHIVE_0:-${UN_PATH:-unknown}}"
_item="$(basename "${_item}")"
_folder="${UN_DATA_OUTPUT:-${UN_PATH:-?}}"

case "${UN_EVENT:-}" in
  extracting)
    title="Extracting: ${_item}"
    message="Folder: ${_folder}"
    tags="package,arrow_down"
    priority="default"
    ;;
  extracted)
    title="Extracted: ${_item}"
    message="Files: ${UN_DATA_FILES:-?}  Size: ${UN_DATA_BYTES:-?}B\nFolder: ${_folder}"
    tags="white_check_mark,package"
    priority="default"
    ;;
  extractfailed)
    title="Extract Failed: ${_item}"
    message="Error: ${UN_DATA_ERROR:-unknown error}\nFolder: ${_folder}"
    tags="x,package"
    priority="high"
    ;;
  deleting)
    title="Deleting: ${_item}"
    message="Folder: ${_folder}"
    tags="wastebasket"
    priority="min"
    ;;
  deletefailed)
    title="Delete Failed: ${_item}"
    message="Error: ${UN_DATA_ERROR:-unknown error}\nFolder: ${_folder}"
    tags="x,wastebasket"
    priority="default"
    ;;
  *)
    # Unknown/unhandled event (e.g. imported, startup)
    exit 0
    ;;
esac

# Send ntfy notification
_ntfy_post() {
  local url="${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}"
  local auth_header=""
  [ -n "$NTFY_TOKEN" ] && auth_header="-H Authorization: Bearer ${NTFY_TOKEN}"

  curl -fsS -X POST "$url" \
    -H "Title: ${title}" \
    -H "Tags: ${tags}" \
    -H "Priority: ${priority}" \
    ${auth_header:+-H "$auth_header"} \
    -d "${message}" >/dev/null 2>&1 || true
}

_ntfy_post

# Ownership fix on extracted or failed (ensure files are accessible by daniel:daniel)
# Note: UN_PATH can be a file (archive) or directory — don't use -d check
if [ -n "${UN_PATH:-}" ]; then
  chown -R 1000:1000 "${UN_PATH}" 2>/dev/null || true
  chmod -R 755 "${UN_PATH}" 2>/dev/null || true
fi
if [ -n "${UN_DATA_OUTPUT:-}" ]; then
  chown -R 1000:1000 "${UN_DATA_OUTPUT}" 2>/dev/null || true
  chmod -R 755 "${UN_DATA_OUTPUT}" 2>/dev/null || true
fi
