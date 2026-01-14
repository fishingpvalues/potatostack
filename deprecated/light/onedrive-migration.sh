#!/bin/bash
################################################################################
# OneDrive to Syncthing Migration Script
# Downloads OneDrive content and organizes into Syncthing folder structure
################################################################################

ONEDRIVE_SOURCE="$HOME/OneDrive" # Adjust if OneDrive is at different location
STORAGE_BASE="/mnt/storage/syncthing"
TEMP_ONEDRIVE="/mnt/storage/syncthing/OneDrive-Archive" # Archive location

echo "================================"
echo "OneDrive Migration to Syncthing"
echo "================================"
echo ""

# Check if OneDrive directory exists
if [ ! -d "$ONEDRIVE_SOURCE" ]; then
	echo "ERROR: OneDrive directory not found at $ONEDRIVE_SOURCE"
	echo "Please update ONEDRIVE_SOURCE variable in this script"
	exit 1
fi

# Create archive directory
echo "Creating OneDrive archive directory..."
mkdir -p "$TEMP_ONEDRIVE"

# Function to safely copy with progress
safe_copy() {
	local src="$1"
	local dst="$2"
	local name="$3"

	if [ -d "$src" ]; then
		echo "Copying $name..."
		rsync -avh --progress "$src/" "$dst/" 2>&1 | grep -E '(files|bytes|speedup)'
		if [ $? -eq 0 ]; then
			echo "✓ $name copied successfully"
		else
			echo "⚠ $name copy had issues, check manually"
		fi
	else
		echo "⊘ Skipping $name (not found)"
	fi
}

echo ""
echo "Step 1: Copying OneDrive folders to Syncthing structure..."
echo "-----------------------------------------------------------"

# Map OneDrive folders to Syncthing folders
safe_copy "$ONEDRIVE_SOURCE/Desktop" "$STORAGE_BASE/Desktop" "Desktop"
safe_copy "$ONEDRIVE_SOURCE/Dokumente" "$STORAGE_BASE/Dokumente" "Documents"
safe_copy "$ONEDRIVE_SOURCE/Bilder" "$STORAGE_BASE/Bilder" "Pictures"
safe_copy "$ONEDRIVE_SOURCE/workdir" "$STORAGE_BASE/workdir" "Work Directory"
safe_copy "$ONEDRIVE_SOURCE/Obsidian-Vault" "$STORAGE_BASE/Obsidian-Vault" "Obsidian Vault"
safe_copy "$ONEDRIVE_SOURCE/Attachments" "$STORAGE_BASE/Attachments" "Attachments"

echo ""
echo "Step 2: Handling Private Vault (encrypted content)..."
echo "-------------------------------------------------------"
# OneDrive Private Vault needs to be unlocked first in OneDrive app
if [ -d "$ONEDRIVE_SOURCE/Privater Tresor" ]; then
	echo "Found Private Vault (Privater Tresor)"
	echo "Make sure it's unlocked in OneDrive, then run:"
	echo "  rsync -avh --progress '$ONEDRIVE_SOURCE/Privater Tresor/' '$STORAGE_BASE/Privates/'"
	echo ""
	echo "Or manually unlock and copy the vault contents"
else
	echo "Private Vault not found or not unlocked"
	echo "Please unlock it in OneDrive app first, then copy manually"
fi

# Check for Business content
if [ -d "$ONEDRIVE_SOURCE/Business" ] || [ -d "$ONEDRIVE_SOURCE/Berufliches" ]; then
	echo ""
	echo "Step 3: Copying business/professional content..."
	echo "-------------------------------------------------"
	safe_copy "$ONEDRIVE_SOURCE/Business" "$STORAGE_BASE/Berufliches" "Business (OneDrive)"
	safe_copy "$ONEDRIVE_SOURCE/Berufliches" "$STORAGE_BASE/Berufliches" "Berufliches"
fi

echo ""
echo "Step 4: Creating complete OneDrive archive..."
echo "----------------------------------------------"
echo "Copying entire OneDrive to archive location: $TEMP_ONEDRIVE"
echo "This preserves EVERYTHING including folder structure"
rsync -avh --progress "$ONEDRIVE_SOURCE/" "$TEMP_ONEDRIVE/" 2>&1 | grep -E '(files|bytes|speedup)'

echo ""
echo "Step 5: Setting correct permissions..."
echo "---------------------------------------"
chown -R 1000:1000 "$STORAGE_BASE"
chmod -R 755 "$STORAGE_BASE"
echo "✓ Permissions set to 1000:1000 with 755"

echo ""
echo "================================"
echo "Migration Summary"
echo "================================"
echo ""
echo "Syncthing folders updated:"
echo "  - Desktop: $STORAGE_BASE/Desktop"
echo "  - Documents: $STORAGE_BASE/Dokumente"
echo "  - Pictures: $STORAGE_BASE/Bilder"
echo "  - Work: $STORAGE_BASE/workdir"
echo "  - Obsidian: $STORAGE_BASE/Obsidian-Vault"
echo "  - Attachments: $STORAGE_BASE/Attachments"
echo "  - Business: $STORAGE_BASE/Berufliches"
echo ""
echo "Complete OneDrive archive: $TEMP_ONEDRIVE"
echo ""
echo "Next Steps:"
echo "1. Verify files in Syncthing web UI: http://192.168.178.40:8384"
echo "2. Set up Syncthing shares with your devices"
echo "3. Once syncing works, you can:"
echo "   - Disconnect OneDrive on this machine"
echo "   - Keep using OneDrive on other devices, sync via Syncthing to server"
echo "   - Archive is kept at: $TEMP_ONEDRIVE"
echo ""
echo "Private Vault:"
echo "  Unlock OneDrive Private Vault and manually copy to:"
echo "  $STORAGE_BASE/Privates/"
echo ""

# Calculate space used
echo "Storage usage:"
du -sh "$STORAGE_BASE" 2>/dev/null
echo ""
echo "Archive usage:"
du -sh "$TEMP_ONEDRIVE" 2>/dev/null
