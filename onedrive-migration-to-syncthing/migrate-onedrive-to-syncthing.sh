#!/bin/bash
################################################################################
# Migrate OneDrive to Syncthing
# Moves downloaded OneDrive files to Syncthing folder structure
################################################################################

set -eu

SOURCE_DIR="/mnt/storage/onedrive-temp"
DEST_BASE="/mnt/storage/syncthing"
ARCHIVE_DIR="/mnt/storage/syncthing/OneDrive-Archive"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

echo "============================================================"
echo "Migrate OneDrive to Syncthing"
echo "============================================================"
echo ""

# Check prerequisites
if [ ! -d "$SOURCE_DIR" ]; then
    echo "✗ Source directory not found"
    echo "  $SOURCE_DIR"
    echo ""
    echo "Did you run ./download-onedrive.sh?"
    exit 1
fi

if [ "$(ls -A "$SOURCE_DIR" 2>/dev/null)" = "" ]; then
    echo "✗ Source directory is empty"
    echo "  $SOURCE_DIR"
    exit 1
fi

# Check destination
if [ ! -d "$DEST_BASE" ]; then
    echo "Creating Syncthing directory..."
    mkdir -p "$DEST_BASE"
fi

# Define folder mappings (OneDrive folder -> Syncthing destination)
# Add your custom mappings here
declare -A FOLDERS=(
    # German folder names (common OneDrive defaults)
    ["Berufliches"]="${DEST_BASE}/Berufliches"
    ["Bilder"]="${DEST_BASE}/Bilder"
    ["Desktop"]="${DEST_BASE}/Desktop"
    ["Dokumente"]="${DEST_BASE}/Dokumente"
    ["Privates"]="${DEST_BASE}/Privates"
    ["Persönlicher Tresor"]="${DEST_BASE}/Privates/vault"
    ["workdir"]="${DEST_BASE}/workdir"

    # Obsidian vault variations
    ["Obsidian Vault"]="${DEST_BASE}/Obsidian-Vault"
    ["Obsidian"]="${DEST_BASE}/Obsidian-Vault"
    ["obsidian"]="${DEST_BASE}/Obsidian-Vault"

    # English folder names (OneDrive defaults)
    ["Documents"]="${DEST_BASE}/Dokumente"
    ["Pictures"]="${DEST_BASE}/Bilder"
    ["Photos"]="${DEST_BASE}/Bilder"

    # Camera/Photo sync folders
    ["Camera Roll"]="${DEST_BASE}/camera-sync/onedrive"
    ["Eigene Aufnahmen"]="${DEST_BASE}/camera-sync/onedrive"

    # Attachments
    ["Attachments"]="${DEST_BASE}/Attachments"
    ["E-Mail-Anhänge"]="${DEST_BASE}/Attachments"
    ["Email attachments"]="${DEST_BASE}/Attachments"

    # Music
    ["Music"]="${DEST_BASE}/music/onedrive"
    ["Musik"]="${DEST_BASE}/music/onedrive"

    # Videos
    ["Videos"]="${DEST_BASE}/videos/onedrive"

    # Shared folders
    ["Shared"]="${DEST_BASE}/shared"
    ["Freigegeben"]="${DEST_BASE}/shared"
)

echo "Migration Plan:"
echo "  Source: $SOURCE_DIR"
echo "  Destination: $DEST_BASE"
echo "  Archive: $ARCHIVE_DIR"
echo ""

# Show what will be migrated
echo "Detected OneDrive folders:"
echo ""

FOUND_FOLDERS=0
for item in "$SOURCE_DIR"/*; do
    [ -e "$item" ] || continue
    folder=$(basename "$item")

    # Skip hidden files
    [[ "$folder" =~ ^\. ]] && continue

    if [ -d "$item" ]; then
        size=$(du -sh "$item" 2>/dev/null | cut -f1)
        files=$(find "$item" -type f 2>/dev/null | wc -l)

        if [[ -v "FOLDERS[$folder]" ]]; then
            dest="${FOLDERS[$folder]}"
            printf "  ✓ %-25s → %-30s (%s, %d files)\n" "$folder" "$(basename "$dest")" "$size" "$files"
        else
            printf "  ? %-25s → %-30s (%s, %d files)\n" "$folder" "OneDrive-Archive/unmapped" "$size" "$files"
        fi
        FOUND_FOLDERS=$((FOUND_FOLDERS + 1))
    else
        # File in root
        size=$(du -sh "$item" 2>/dev/null | cut -f1)
        printf "  📄 %-25s → %-30s (%s)\n" "$folder" "OneDrive-Archive/root-files" "$size"
    fi
done

echo ""
echo "Found $FOUND_FOLDERS folders to migrate"
echo ""

read -p "Proceed with migration? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Starting migration..."
echo ""

# Create archive directory
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR/unmapped"
mkdir -p "$ARCHIVE_DIR/root-files"

# Statistics
MIGRATED=0
ARCHIVED=0
FAILED=0
TOTAL_SIZE=0

# Function to migrate a folder
migrate_folder() {
    local src="$1"
    local dest="$2"
    local name=$(basename "$src")

    if [ ! -e "$src" ]; then
        return 1
    fi

    # Ensure destination directory exists
    mkdir -p "$dest"

    # Get size before migration
    local size_before=$(du -sb "$src" 2>/dev/null | cut -f1 || echo "0")

    echo "→ Migrating: $name"
    echo "  From: $src"
    echo "  To: $dest"

    # Use rsync for safe migration with progress
    if rsync -ah --progress --stats "$src/" "$dest/" 2>&1 | tail -5; then
        echo "  ✓ Success"
        TOTAL_SIZE=$((TOTAL_SIZE + size_before))
        return 0
    else
        echo "  ✗ Failed"
        return 1
    fi
}

# Migrate mapped folders
for folder in "${!FOLDERS[@]}"; do
    source_path="$SOURCE_DIR/$folder"
    dest_path="${FOLDERS[$folder]}"

    if [ ! -d "$source_path" ]; then
        continue
    fi

    echo ""
    if migrate_folder "$source_path" "$dest_path"; then
        # Also copy to archive for backup
        mkdir -p "$ARCHIVE_DIR/$folder"
        rsync -a "$source_path/" "$ARCHIVE_DIR/$folder/" 2>/dev/null
        MIGRATED=$((MIGRATED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

# Handle unmapped folders and root files
echo ""
echo "Processing unmapped items..."

for item in "$SOURCE_DIR"/*; do
    [ -e "$item" ] || continue
    name=$(basename "$item")

    # Skip hidden files
    [[ "$name" =~ ^\. ]] && continue

    # Skip if already handled
    if [[ -v "FOLDERS[$name]" ]]; then
        continue
    fi

    echo ""
    if [ -d "$item" ]; then
        echo "→ Archiving unmapped folder: $name"
        if rsync -ah --progress "$item/" "$ARCHIVE_DIR/unmapped/$name/" 2>&1 | tail -3; then
            echo "  ✓ Archived to: OneDrive-Archive/unmapped/$name"
            ARCHIVED=$((ARCHIVED + 1))
        fi
    else
        echo "→ Archiving root file: $name"
        if cp -v "$item" "$ARCHIVE_DIR/root-files/"; then
            echo "  ✓ Archived to: OneDrive-Archive/root-files/"
            ARCHIVED=$((ARCHIVED + 1))
        fi
    fi
done

# Set permissions
echo ""
echo "Setting permissions..."
chown -R "$PUID:$PGID" "$DEST_BASE" 2>/dev/null || true
chmod -R 775 "$DEST_BASE" 2>/dev/null || true
echo "✓ Permissions set to $PUID:$PGID"

# Summary
if [ "$TOTAL_SIZE" -gt 0 ]; then
    TOTAL_SIZE_HR=$(numfmt --to=iec --suffix=B $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")
else
    TOTAL_SIZE_HR="0B"
fi

echo ""
echo "============================================================"
echo "Migration Complete!"
echo "============================================================"
echo ""
echo "Summary:"
echo "  Folders migrated: $MIGRATED"
echo "  Items archived: $ARCHIVED"
echo "  Folders failed: $FAILED"
echo "  Total size migrated: $TOTAL_SIZE_HR"
echo ""
echo "Locations:"
echo "  Syncthing folders: $DEST_BASE"
echo "  Complete archive: $ARCHIVE_DIR"
echo "  Original download: $SOURCE_DIR"
echo ""

# Show syncthing contents
echo "Syncthing folder sizes:"
echo ""
du -sh "$DEST_BASE"/* 2>/dev/null | sort -hr | head -20
echo ""

echo "Next steps:"
echo "  1. Verify files in Syncthing: https://potatostack.tale-iwato.ts.net:8384"
echo "  2. Configure Syncthing to sync folders with your devices"
echo "  3. After verification, optionally remove temp files:"
echo "     sudo rm -rf $SOURCE_DIR"
echo ""
echo "To add a folder to Syncthing sync:"
echo "  - Open Syncthing Web UI"
echo "  - Click 'Add Folder'"
echo "  - Set path to the folder under $DEST_BASE"
echo "  - Share with your devices"
echo ""
