#!/bin/bash
################################################################################
# Setup Soulseek Symlinks
# Creates symlinks from Syncthing folders to Soulseek shared directory
# This allows Soulseek to share music, books, audiobooks from Syncthing
################################################################################

SYNCTHING_BASE="/mnt/storage/syncthing"
SLSKD_SHARED="/mnt/storage/slskd-shared"

echo "================================"
echo "Soulseek Symlink Setup"
echo "================================"
echo ""

# Ensure slskd-shared directory exists
if [ ! -d "$SLSKD_SHARED" ]; then
    echo "Creating slskd-shared directory..."
    mkdir -p "$SLSKD_SHARED"
    chown 1000:1000 "$SLSKD_SHARED"
    chmod 755 "$SLSKD_SHARED"
fi

# Function to create symlink safely
create_symlink() {
    local source="$1"
    local link_name="$2"
    local target="$SLSKD_SHARED/$link_name"

    if [ ! -d "$source" ]; then
        echo "⊘ Skipping $link_name (source not found: $source)"
        return 1
    fi

    if [ -L "$target" ]; then
        echo "⚠ Symlink already exists: $link_name (removing old one)"
        rm "$target"
    elif [ -e "$target" ]; then
        echo "⚠ Target exists but is not a symlink: $link_name (skipping)"
        return 1
    fi

    ln -s "$source" "$target"
    if [ $? -eq 0 ]; then
        echo "✓ Created symlink: $link_name → $source"
    else
        echo "✗ Failed to create symlink: $link_name"
    fi
}

echo "Creating symlinks for Soulseek sharing..."
echo ""

# Create symlinks for media content
create_symlink "$SYNCTHING_BASE/music" "music"
create_symlink "$SYNCTHING_BASE/books" "books"
create_symlink "$SYNCTHING_BASE/audiobooks" "audiobooks"
create_symlink "$SYNCTHING_BASE/podcasts" "podcasts"

# Optional: Share downloads folder via Soulseek
echo ""
echo "Optional symlinks (uncomment if needed):"
echo "# create_symlink \"$SYNCTHING_BASE/videos\" \"videos\""
echo "# create_symlink \"$SYNCTHING_BASE/shared\" \"shared\""

echo ""
echo "================================"
echo "Symlink Setup Complete"
echo "================================"
echo ""
echo "Soulseek shared directory: $SLSKD_SHARED"
echo ""
echo "Available shares:"
ls -lh "$SLSKD_SHARED" 2>/dev/null | tail -n +2

echo ""
echo "In slskd container, these appear at: /var/slskd/shared/"
echo ""
echo "Next steps:"
echo "1. Restart slskd container: docker compose restart slskd"
echo "2. Access slskd UI: http://192.168.178.40:2234"
echo "3. Verify shared folders are visible in settings"
echo "4. Configure which folders to share in slskd settings"
echo ""
echo "Note: Soulseek will scan these directories for shareable files"
echo "      Only music, audiobooks, books, and podcasts are linked by default"
