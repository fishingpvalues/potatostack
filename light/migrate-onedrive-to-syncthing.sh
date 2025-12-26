#!/bin/bash
################################################################################
# Migrate OneDrive to Syncthing Folders
# Moves downloaded OneDrive content to respective Syncthing folders
################################################################################

set -e

ONEDRIVE_DIR="/mnt/storage/onedrive-temp"
SYNCTHING_BASE="/mnt/storage/syncthing"
ARCHIVE_DIR="/mnt/storage/syncthing/OneDrive-Archive"

echo "================================"
echo "OneDrive → Syncthing Migration"
echo "================================"
echo ""

# Check if OneDrive download exists
if [ ! -d "$ONEDRIVE_DIR" ]; then
    echo "✗ OneDrive download directory not found: $ONEDRIVE_DIR"
    echo "  Run: ./download-onedrive.sh first"
    exit 1
fi

# Show what will be migrated
echo "Source: $ONEDRIVE_DIR"
echo "Target: $SYNCTHING_BASE"
echo ""
echo "Contents to migrate:"
ls -lh "$ONEDRIVE_DIR" 2>/dev/null || echo "Directory is empty"

echo ""
echo "================================"
echo "Migration Plan"
echo "================================"
echo ""

# Function to migrate folder
migrate_folder() {
    local source_name="$1"
    local target_name="$2"
    local source_path="$ONEDRIVE_DIR/$source_name"
    local target_path="$SYNCTHING_BASE/$target_name"

    if [ -d "$source_path" ] || [ -L "$source_path" ]; then
        echo ""
        echo "Migrating: $source_name → $target_name"
        echo "  Source: $source_path"
        echo "  Target: $target_path"

        # Create target if it doesn't exist
        mkdir -p "$target_path"

        # Use rsync for safe copying with progress
        rsync -avh --progress "$source_path/" "$target_path/" 2>&1 | grep -E '(files|speedup|total size)'

        if [ $? -eq 0 ]; then
            echo "  ✓ Migration successful"

            # Show sizes
            SOURCE_SIZE=$(du -sh "$source_path" 2>/dev/null | cut -f1)
            TARGET_SIZE=$(du -sh "$target_path" 2>/dev/null | cut -f1)
            echo "  Source size: $SOURCE_SIZE"
            echo "  Target size: $TARGET_SIZE"
        else
            echo "  ⚠ Migration had issues, check manually"
        fi
    else
        echo "⊘ Skipping $source_name (not found in OneDrive)"
    fi
}

echo "Folder mappings:"
echo "  Berufliches    → Berufliches"
echo "  Bilder         → Bilder"
echo "  Desktop        → Desktop"
echo "  Dokumente      → Dokumente"
echo "  Obsidian Vault → Obsidian-Vault"
echo "  Privates       → Privates"
echo "  workdir        → workdir"
echo ""

read -p "Start migration? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "================================"
echo "Starting Migration"
echo "================================"

# Migrate each folder
migrate_folder "Berufliches" "Berufliches"
migrate_folder "Bilder" "Bilder"
migrate_folder "Desktop" "Desktop"
migrate_folder "Dokumente" "Dokumente"
migrate_folder "Obsidian Vault" "Obsidian-Vault"
migrate_folder "Privates" "Privates"
migrate_folder "workdir" "workdir"

# Handle any additional folders
echo ""
echo "================================"
echo "Additional Folders"
echo "================================"
echo ""

# Find folders not in the standard list
for folder in "$ONEDRIVE_DIR"/*; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")
        case "$folder_name" in
            "Berufliches"|"Bilder"|"Desktop"|"Dokumente"|"Obsidian Vault"|"Privates"|"workdir")
                # Already migrated
                ;;
            *)
                echo "Found additional folder: $folder_name"
                echo "  Not in standard mapping, will be included in archive"
                ;;
        esac
    fi
done

# Create complete archive
echo ""
echo "================================"
echo "Creating Complete Archive"
echo "================================"
echo ""
echo "Archiving entire OneDrive to: $ARCHIVE_DIR"
echo "This preserves EVERYTHING including structure"
echo ""

mkdir -p "$ARCHIVE_DIR"
rsync -avh --progress "$ONEDRIVE_DIR/" "$ARCHIVE_DIR/" 2>&1 | grep -E '(files|speedup|total size)'

echo ""
echo "✓ Archive created"

# Set permissions
echo ""
echo "Setting permissions..."
chown -R 1000:1000 "$SYNCTHING_BASE"
chmod -R 755 "$SYNCTHING_BASE"
echo "✓ Permissions set"

echo ""
echo "================================"
echo "Personal Vault (Persönlicher Tresor)"
echo "================================"
echo ""
echo "⚠ IMPORTANT: OneDrive Personal Vault requires manual unlock!"
echo ""
echo "If you have a Personal Vault on OneDrive:"
echo "1. On Windows/Mac: Unlock Personal Vault in OneDrive app"
echo "2. Navigate to the vault folder"
echo "3. Copy contents manually to: $SYNCTHING_BASE/Privates/vault/"
echo ""
echo "Alternative: Use OneDrive web interface to download vault contents"
echo ""

# Summary
echo "================================"
echo "Migration Summary"
echo "================================"
echo ""
echo "Syncthing folders updated:"
du -sh "$SYNCTHING_BASE"/* 2>/dev/null | grep -v "OneDrive-Archive"

echo ""
echo "Complete archive:"
du -sh "$ARCHIVE_DIR"

echo ""
echo "Total Syncthing storage:"
du -sh "$SYNCTHING_BASE"

echo ""
echo "================================"
echo "Next Steps"
echo "================================"
echo ""
echo "1. Verify files in Syncthing web UI:"
echo "   http://192.168.178.40:8384"
echo ""
echo "2. Set up Syncthing shares with your devices"
echo ""
echo "3. Once syncing works, you can:"
echo "   - Keep OneDrive on Windows/phone, sync via Syncthing to server"
echo "   - Or disconnect OneDrive and use Syncthing exclusively"
echo ""
echo "4. Archive is kept at: $ARCHIVE_DIR"
echo "   You can delete $ONEDRIVE_DIR once you verify everything"
echo ""
echo "5. To remove downloaded OneDrive data:"
echo "   sudo rm -rf $ONEDRIVE_DIR"
echo ""
echo "6. To stop OneDrive client from running:"
echo "   # It's a one-time download, no daemon needed"
echo "   # Just don't run the sync again"
echo ""
