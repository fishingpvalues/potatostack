#!/bin/bash
################################################################################
# Edit Encrypted Secrets - Convenience wrapper for sops
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_ENC_FILE="$PROJECT_ROOT/.env.enc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f "$ENV_ENC_FILE" ]; then
    echo -e "${RED}✗ Encrypted .env file not found: $ENV_ENC_FILE${NC}"
    echo -e "${YELLOW}  Run setup-secrets.sh first${NC}"
    exit 1
fi

if ! command -v sops >/dev/null 2>&1; then
    echo -e "${RED}✗ sops not installed${NC}"
    echo -e "${YELLOW}  Run setup-secrets.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}Opening encrypted .env file in editor...${NC}"
sops "$ENV_ENC_FILE"

echo ""
echo -e "${GREEN}✓ Changes saved to .env.enc${NC}"
echo ""
echo -e "${BLUE}To apply changes:${NC}"
echo "  1. Decrypt: ${YELLOW}sops --decrypt .env.enc > .env${NC}"
echo "  2. Restart: ${YELLOW}docker compose down && docker compose up -d${NC}"
echo ""

exit 0
