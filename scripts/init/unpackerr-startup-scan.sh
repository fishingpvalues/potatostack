#!/bin/bash
################################################################################
# Unpackerr Startup Scan - Triggers Unpackerr to process existing archives
################################################################################

set -euo pipefail

DOWNLOADS_BASE="/downloads"
ARCHIVE_PATTERNS="*.rar *.zip *.7z *.tar *.tar.gz *.tar.bz2 *.tgz *.tbz2 *.iso"

echo "[$(date)] Scanning for existing archives..."

# Find all archives and create marker files to trigger Unpackerr
for pattern in ${ARCHIVE_PATTERNS}; do
	while IFS= read -r -d '' archive; do
		if [ -f "$archive" ]; then
			# Create a marker file to trigger Unpackerr's watch
			dir=$(dirname "$archive")
			marker="${dir}/.unpackerr-scan-marker"
			touch "$marker" 2>/dev/null || true

			# Optionally, move archive to ensure it's redetected
			# mv "$archive" "${archive}.scan" 2>/dev/null || true
			# mv "${archive}.scan" "$archive" 2>/dev/null || true
		fi
	done < <(find "${DOWNLOADS_BASE}" -type f -name "$pattern" ! -path "*/incomplete/*")
done

echo "[$(date)] Startup scan complete, found $(find "${DOWNLOADS_BASE}" -type f \( -name "*.rar" -o -name "*.zip" -o -name "*.7z" -o -name "*.tar*" -o -name "*.iso" \) ! -path "*/incomplete/*" | wc -l) archives"
