#!/bin/bash
################################################################################
# PotatoStack Light - Mock Directory Setup for Testing
# Creates directory structure in mock drives for testing
################################################################################

set -e

MOCK_BASE="../mock-drives"
SECONDDRIVE="$MOCK_BASE/seconddrive"
CACHEHDD="$MOCK_BASE/cachehdd"

echo "🥔 PotatoStack Light - Setting up MOCK directories for testing..."
echo ""

# Create mock base
mkdir -p "$MOCK_BASE"

echo "✅ Mock drives:"
echo "   - $SECONDDRIVE (mock 14TB)"
echo "   - $CACHEHDD (mock 500GB)"
echo ""

# Create directories on main drive (14TB)
echo "📁 Creating directories on mock seconddrive..."
mkdir -p "$SECONDDRIVE/downloads"
mkdir -p "$SECONDDRIVE/slskd-shared"
mkdir -p "$SECONDDRIVE/immich/upload"
mkdir -p "$SECONDDRIVE/immich/library"
mkdir -p "$SECONDDRIVE/seafile"
mkdir -p "$SECONDDRIVE/kopia/repository"

# Create directories on cache drive (500GB)
echo "📁 Creating directories on mock cachehdd..."
mkdir -p "$CACHEHDD/transmission-incomplete"
mkdir -p "$CACHEHDD/slskd-incomplete"
mkdir -p "$CACHEHDD/immich/thumbs"
mkdir -p "$CACHEHDD/kopia/cache"

# Set ownership (current user)
echo "🔐 Setting ownership to $(id -u):$(id -g)..."
chown -R $(id -u):$(id -g) "$MOCK_BASE" 2>/dev/null || true

echo ""
echo "✅ Mock directory structure created successfully!"
echo ""
echo "Storage layout:"
echo ""
echo "📦 $SECONDDRIVE (Main Storage):"
echo "   ├── downloads"
echo "   ├── slskd-shared"
echo "   ├── immich/upload"
echo "   ├── immich/library"
echo "   ├── seafile"
echo "   └── kopia/repository"
echo ""
echo "⚡ $CACHEHDD (Cache Storage):"
echo "   ├── transmission-incomplete"
echo "   ├── slskd-incomplete"
echo "   ├── immich/thumbs"
echo "   └── kopia/cache"
echo ""
echo "🚀 Ready to test: docker compose -f docker-compose.test.yml up -d"
