#!/bin/sh
set -eu

echo "$(date): Starting weekly Saved Messages video download"

# Export all saved messages
tdl chat export -c 1015621977 -o /downloads/saved-messages-all.json

# Build skip directory with symlinks to all existing videos in /adult
# so --skip-same can detect duplicates across the entire adult tree
SKIP_DIR="/downloads/.skip-index"
rm -rf "$SKIP_DIR"
mkdir -p "$SKIP_DIR"
find /adult -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.avi' \
  -o -name '*.mov' -o -name '*.wmv' -o -name '*.webm' \) \
  -exec ln -sf {} "$SKIP_DIR/" \;
echo "$(date): Indexed $(ls "$SKIP_DIR" | wc -l) existing videos for dedup"

# Download only video files, skip already downloaded (checks skip-index)
tdl download \
  -f /downloads/saved-messages-all.json \
  -d "$SKIP_DIR" \
  -i mp4,mkv,avi,mov,wmv,webm \
  --skip-same \
  -l 2

# Move only real files (not symlinks) to the telegram folder
find "$SKIP_DIR" -maxdepth 1 -type f -exec mv {} /adult-telegram/ \;
rm -rf "$SKIP_DIR"

echo "$(date): Download complete"
