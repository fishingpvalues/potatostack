#!/bin/bash
################################################################################
# SOPS + AGE Setup Script - Interactive Installation
# Encrypts .env file for secure credential management
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AGE_KEY_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"
SOPS_CONFIG="$PROJECT_ROOT/.sops.yaml"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_ENC_FILE="$PROJECT_ROOT/.env.enc"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SOPS + AGE Setup for PotatoStack${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${YELLOW}⚠ This script is designed for Linux systems.${NC}"
    echo -e "  You appear to be on: $OSTYPE"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Install age
echo -e "${BLUE}[1/7] Installing age (encryption tool)${NC}"
if command_exists age; then
    AGE_VERSION=$(age --version 2>&1 | head -n1 || echo "unknown")
    echo -e "${GREEN}✓ age is already installed: $AGE_VERSION${NC}"
else
    echo -e "${YELLOW}  age not found. Installing...${NC}"

    # Detect package manager
    if command_exists apt-get; then
        echo "  Using apt-get..."
        sudo apt-get update && sudo apt-get install -y age
    elif command_exists yum; then
        echo "  Using yum..."
        sudo yum install -y age
    elif command_exists pacman; then
        echo "  Using pacman..."
        sudo pacman -S --noconfirm age
    else
        echo -e "${RED}✗ Could not detect package manager.${NC}"
        echo "  Please install age manually from: https://github.com/FiloSottile/age"
        echo "  Then re-run this script."
        exit 1
    fi

    if command_exists age; then
        echo -e "${GREEN}✓ age installed successfully${NC}"
    else
        echo -e "${RED}✗ age installation failed${NC}"
        exit 1
    fi
fi
echo ""

# Step 2: Install sops
echo -e "${BLUE}[2/7] Installing sops (secrets manager)${NC}"
if command_exists sops; then
    SOPS_VERSION=$(sops --version 2>&1 | head -n1 || echo "unknown")
    echo -e "${GREEN}✓ sops is already installed: $SOPS_VERSION${NC}"
else
    echo -e "${YELLOW}  sops not found. Installing...${NC}"

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            SOPS_ARCH="amd64"
            ;;
        aarch64|arm64)
            SOPS_ARCH="arm64"
            ;;
        armv7l)
            SOPS_ARCH="arm"
            ;;
        *)
            echo -e "${RED}✗ Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac

    SOPS_VERSION="3.8.1"
    SOPS_URL="https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${SOPS_ARCH}"

    echo "  Downloading sops from: $SOPS_URL"
    sudo curl -L "$SOPS_URL" -o /usr/local/bin/sops
    sudo chmod +x /usr/local/bin/sops

    if command_exists sops; then
        echo -e "${GREEN}✓ sops installed successfully${NC}"
    else
        echo -e "${RED}✗ sops installation failed${NC}"
        exit 1
    fi
fi
echo ""

# Step 3: Generate age key
echo -e "${BLUE}[3/7] Generating age encryption key${NC}"
if [ -f "$AGE_KEY_FILE" ]; then
    echo -e "${YELLOW}⚠ age key already exists at: $AGE_KEY_FILE${NC}"
    read -p "  Overwrite existing key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}  Using existing key${NC}"
    else
        echo -e "${YELLOW}  Generating new key (this will invalidate old encrypted files!)${NC}"
        mkdir -p "$AGE_KEY_DIR"
        age-keygen -o "$AGE_KEY_FILE"
        chmod 600 "$AGE_KEY_FILE"
        echo -e "${GREEN}✓ New age key generated${NC}"
    fi
else
    mkdir -p "$AGE_KEY_DIR"
    age-keygen -o "$AGE_KEY_FILE"
    chmod 600 "$AGE_KEY_FILE"
    echo -e "${GREEN}✓ age key generated at: $AGE_KEY_FILE${NC}"
fi

# Extract public key
AGE_PUBLIC_KEY=$(grep "^# public key:" "$AGE_KEY_FILE" | awk '{print $4}')
echo -e "${GREEN}  Public key: $AGE_PUBLIC_KEY${NC}"
echo ""

# Step 4: Backup age key
echo -e "${BLUE}[4/7] Backing up age key${NC}"
echo -e "${YELLOW}  CRITICAL: Without this key, you cannot decrypt your secrets!${NC}"
echo ""
echo -e "${BLUE}  Your age private key:${NC}"
cat "$AGE_KEY_FILE"
echo ""
echo -e "${YELLOW}  Please save this key to a secure location:${NC}"
echo "  1. Password manager (1Password, Bitwarden, etc.)"
echo "  2. Encrypted USB drive"
echo "  3. Secure cloud storage (encrypted)"
echo ""
read -p "  Press Enter when you have backed up the key..." -r
echo -e "${GREEN}✓ Key backup acknowledged${NC}"
echo ""

# Step 5: Create .sops.yaml
echo -e "${BLUE}[5/7] Creating .sops.yaml configuration${NC}"
if [ -f "$SOPS_CONFIG" ]; then
    echo -e "${YELLOW}⚠ .sops.yaml already exists${NC}"
    read -p "  Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}  Keeping existing .sops.yaml${NC}"
    else
        cat > "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: \.env$
    age: >-
      $AGE_PUBLIC_KEY
EOF
        echo -e "${GREEN}✓ .sops.yaml created${NC}"
    fi
else
    cat > "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: \.env$
    age: >-
      $AGE_PUBLIC_KEY
EOF
    echo -e "${GREEN}✓ .sops.yaml created${NC}"
fi
echo ""

# Step 6: Encrypt .env file
echo -e "${BLUE}[6/7] Encrypting .env file${NC}"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}✗ .env file not found at: $ENV_FILE${NC}"
    echo -e "${YELLOW}  Please create a .env file first (copy from .env.example)${NC}"
    exit 1
fi

if [ -f "$ENV_ENC_FILE" ]; then
    echo -e "${YELLOW}⚠ .env.enc already exists${NC}"
    read -p "  Overwrite with newly encrypted .env? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}  Keeping existing .env.enc${NC}"
    else
        sops --encrypt "$ENV_FILE" > "$ENV_ENC_FILE"
        echo -e "${GREEN}✓ .env encrypted to .env.enc${NC}"
    fi
else
    sops --encrypt "$ENV_FILE" > "$ENV_ENC_FILE"
    echo -e "${GREEN}✓ .env encrypted to .env.enc${NC}"
fi
echo ""

# Step 7: Update .gitignore
echo -e "${BLUE}[7/7] Updating .gitignore${NC}"
GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE_FILE" ]; then
    if grep -q "^\.env$" "$GITIGNORE_FILE"; then
        echo -e "${GREEN}✓ .env already in .gitignore${NC}"
    else
        echo "" >> "$GITIGNORE_FILE"
        echo "# Secrets (encrypted version is .env.enc)" >> "$GITIGNORE_FILE"
        echo ".env" >> "$GITIGNORE_FILE"
        echo -e "${GREEN}✓ Added .env to .gitignore${NC}"
    fi
else
    cat > "$GITIGNORE_FILE" <<EOF
# Secrets (encrypted version is .env.enc)
.env
EOF
    echo -e "${GREEN}✓ Created .gitignore with .env${NC}"
fi
echo ""

# Final instructions
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✓ sops and age installed${NC}"
echo -e "${GREEN}✓ age key generated and backed up${NC}"
echo -e "${GREEN}✓ .sops.yaml created${NC}"
echo -e "${GREEN}✓ .env encrypted to .env.enc${NC}"
echo -e "${GREEN}✓ .gitignore updated${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. To edit encrypted .env:"
echo "     ${YELLOW}sops .env.enc${NC}"
echo ""
echo "  2. To decrypt .env (for docker-compose):"
echo "     ${YELLOW}sops --decrypt .env.enc > .env${NC}"
echo ""
echo "  3. To auto-decrypt on boot, run:"
echo "     ${YELLOW}sudo ./scripts/setup-decrypt-service.sh${NC}"
echo ""
echo "  4. Commit .env.enc to git (NEVER commit .env):"
echo "     ${YELLOW}git add .env.enc .sops.yaml .gitignore${NC}"
echo "     ${YELLOW}git commit -m 'Add encrypted secrets'${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} Keep your age key at ${AGE_KEY_FILE} backed up!"
echo ""

exit 0
