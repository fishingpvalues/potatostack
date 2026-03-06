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
    # Notification deferred until after 7z attempt below
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

# Send ntfy for all events except extractfailed (that one is sent after 7z below)
[ "${UN_EVENT:-}" != "extractfailed" ] && _ntfy_post

# 7z fallback extraction on failure: extract all files possible, log errors, keep original
if [ "${UN_EVENT:-}" = "extractfailed" ] && [ -f "${UN_PATH:-}" ]; then
  _archive="${UN_PATH}"
  _outdir="${UN_DATA_OUTPUT:-$(dirname "${_archive}")}"
  _logfile="$(dirname "${_archive}")/.extract-errors.log"

  mkdir -p "${_outdir}" 2>/dev/null || true

  # Run 7z — extracts everything it can even on CRC errors (-y = yes to all)
  _7z_out=$(7z x -y "${_archive}" -o"${_outdir}" 2>&1) || true
  _7z_errors=$(echo "${_7z_out}" | grep -E "^ERROR" || true)

  # Write logfile entry
  {
    echo "=== $(date -Iseconds) === ${_archive}"
    if [ -n "${_7z_errors}" ]; then
      echo "FAILED FILES:"
      echo "${_7z_errors}"
    else
      echo "OK: 7z extracted all files (unpackerr had checksum issues)"
    fi
    echo ""
  } >> "${_logfile}"

  # Send follow-up ntfy with 7z result; delete original only on clean 7z success
  if [ -n "${_7z_errors}" ]; then
    _failed_count=$(echo "${_7z_errors}" | wc -l)
    curl -fsS -X POST "${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}" \
      -H "Title: 7z partial: ${_item} (${_failed_count} file(s) corrupt)" \
      -H "Tags: x,package" \
      -H "Priority: default" \
      -d "Bad files logged to: ${_logfile}" >/dev/null 2>&1 || true
    # Keep original — extraction was incomplete
  else
    curl -fsS -X POST "${NTFY_INTERNAL_URL%/}/${NTFY_TOPIC}" \
      -H "Title: 7z OK: ${_item}" \
      -H "Tags: white_check_mark,package" \
      -H "Priority: default" \
      -d "7z extracted successfully. Deleting archive." >/dev/null 2>&1 || true
    # Clean success — delete original
    rm -f "${_archive}" 2>/dev/null || true
  fi

  # Fix ownership of output dir
  chown 1000:1000 "${_outdir}" 2>/dev/null || true
  chmod 755 "${_outdir}" 2>/dev/null || true
fi

# Ownership fix on archive file (non-recursive to avoid inotify flood)
if [ -n "${UN_PATH:-}" ] && [ -f "${UN_PATH:-}" ]; then
  chown 1000:1000 "${UN_PATH}" 2>/dev/null || true
  chmod 755 "${UN_PATH}" 2>/dev/null || true
fi
# Fix top-level output dir ownership only
if [ -n "${UN_DATA_OUTPUT:-}" ] && [ -d "${UN_DATA_OUTPUT:-}" ]; then
  chown 1000:1000 "${UN_DATA_OUTPUT}" 2>/dev/null || true
  chmod 755 "${UN_DATA_OUTPUT}" 2>/dev/null || true
fi
