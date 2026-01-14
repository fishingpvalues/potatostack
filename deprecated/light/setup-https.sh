#!/bin/bash
set -euo pipefail

################################################################################
# HTTPS Setup Script - mkcert + Traefik
# Generates locally-trusted certificates for all services
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CERTS_DIR="./traefik/certs"
CA_DIR="./traefik/ca"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}PotatoStack HTTPS Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Load environment variables
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Strip Windows line endings and load .env
set -a
# shellcheck disable=SC1091
source <(sed 's/\r$//' .env)
set +a

HOST_IP="${HOST_BIND:-192.168.178.40}"

################################################################################
# Install mkcert
################################################################################
echo -e "${YELLOW}[1/4] Checking mkcert installation...${NC}"

if ! command -v mkcert &>/dev/null; then
    echo "Installing mkcert..."

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            MKCERT_ARCH="amd64"
            ;;
        aarch64|arm64)
            MKCERT_ARCH="arm64"
            ;;
        armv7l)
            MKCERT_ARCH="arm"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac

    # Download latest mkcert
    MKCERT_VERSION="v1.4.4"
    MKCERT_URL="https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-${MKCERT_ARCH}"

    wget -q "$MKCERT_URL" -O /tmp/mkcert
    chmod +x /tmp/mkcert
    sudo mv /tmp/mkcert /usr/local/bin/mkcert

    echo -e "${GREEN}✓ mkcert installed${NC}"
else
    echo -e "${GREEN}✓ mkcert already installed${NC}"
fi

################################################################################
# Create directories
################################################################################
echo ""
echo -e "${YELLOW}[2/4] Creating certificate directories...${NC}"

mkdir -p "$CERTS_DIR"
mkdir -p "$CA_DIR"

################################################################################
# Generate CA and certificates
################################################################################
echo ""
echo -e "${YELLOW}[3/4] Generating certificates...${NC}"

# Set CAROOT to our custom location
export CAROOT="$CA_DIR"

# Install local CA
if [ ! -f "$CA_DIR/rootCA.pem" ]; then
    echo "Creating local Certificate Authority..."
    mkcert -install
    echo -e "${GREEN}✓ CA created${NC}"
else
    echo -e "${GREEN}✓ CA already exists${NC}"
fi

# Generate certificate for the host IP and localhost
cd "$CERTS_DIR"

if [ ! -f "cert.pem" ] || [ ! -f "key.pem" ]; then
    echo "Generating certificate for $HOST_IP..."
    mkcert \
        "$HOST_IP" \
        "localhost" \
        "127.0.0.1" \
        "::1" \
        "*.local"

    # Rename to standard names
    mv "${HOST_IP}+4.pem" cert.pem
    mv "${HOST_IP}+4-key.pem" key.pem

    echo -e "${GREEN}✓ Certificate generated${NC}"
else
    echo -e "${GREEN}✓ Certificate already exists${NC}"
fi

cd - > /dev/null

################################################################################
# Create installation instructions
################################################################################
echo ""
echo -e "${YELLOW}[4/4] Creating installation guide...${NC}"

CA_CERT_PATH="$(pwd)/$CA_DIR/rootCA.pem"

cat > "./traefik/INSTALL-CA.md" <<EOF
# HTTPS Certificate Installation Guide

## Overview
All services are now accessible via HTTPS using locally-trusted certificates.
To avoid browser warnings, install the CA certificate on all your devices.

## Certificate Location
**CA Certificate:** \`$CA_CERT_PATH\`

## Installation Instructions

### Windows
1. Copy \`rootCA.pem\` to your Windows machine
2. Rename to \`rootCA.crt\`
3. Double-click the file
4. Click "Install Certificate"
5. Select "Local Machine"
6. Choose "Place all certificates in the following store"
7. Click "Browse" and select "Trusted Root Certification Authorities"
8. Click "Finish"

### macOS
1. Copy \`rootCA.pem\` to your Mac
2. Double-click the file (opens Keychain Access)
3. Double-click the certificate in Keychain Access
4. Expand "Trust"
5. Set "When using this certificate" to "Always Trust"
6. Close and enter your password

### Linux
\`\`\`bash
# Ubuntu/Debian
sudo cp rootCA.pem /usr/local/share/ca-certificates/potatostack-ca.crt
sudo update-ca-certificates

# Fedora/RHEL
sudo cp rootCA.pem /etc/pki/ca-trust/source/anchors/potatostack-ca.crt
sudo update-ca-trust
\`\`\`

### Android
1. Transfer \`rootCA.pem\` to your Android device
2. Rename to \`rootCA.crt\`
3. Go to Settings → Security → Encryption & credentials
4. Tap "Install a certificate"
5. Select "CA certificate"
6. Find and select the \`rootCA.crt\` file
7. Enter your PIN/password if prompted

**Note:** On Android 11+, user-installed CAs only work for apps targeting API 23 or lower, or apps that explicitly trust user certificates.

### iOS/iPadOS
1. Transfer \`rootCA.pem\` to your iOS device (via AirDrop, email, or cloud)
2. Open the file - iOS will prompt to install profile
3. Go to Settings → General → VPN & Device Management
4. Tap the profile and install it
5. Go to Settings → General → About → Certificate Trust Settings
6. Enable "Full Trust" for the certificate

## Access URLs
After installing the CA certificate, access services via:

- Homepage: https://$HOST_IP:3000
- Gluetun: https://$HOST_IP:8000
- Transmission: https://$HOST_IP:9091
- slskd: https://$HOST_IP:2234
- Syncthing: https://$HOST_IP:8384
- FileBrowser: https://$HOST_IP:8181
- Vaultwarden: https://$HOST_IP:8443
- Portainer: https://$HOST_IP:9443
- Kopia: https://$HOST_IP:51515
- AriaNg: https://$HOST_IP:6880
- RustyPaste: https://$HOST_IP:8787

## Verification
After installation, visit https://$HOST_IP:3000 in your browser.
You should see a secure connection without any warnings.

## Troubleshooting

### Browser still shows warning
- Clear browser cache and restart
- Verify CA is installed in correct certificate store
- Check certificate validity: \`openssl x509 -in $CA_CERT_PATH -text -noout\`

### Mobile app doesn't trust certificate
- Some apps ignore system CA store
- Check app settings for custom CA trust options
- For Android, ensure app targets correct API level

## Security Notes
- This CA is only for local network use
- Keep \`rootCA-key.pem\` secure (stored in \`$CA_DIR/\`)
- Certificates valid for 825 days (mkcert default)
- Anyone with the CA key can create trusted certificates for your devices
EOF

echo -e "${GREEN}✓ Installation guide created${NC}"

################################################################################
# Summary
################################################################################
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}HTTPS Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Certificate Details:${NC}"
echo "  - CA: $CA_DIR/rootCA.pem"
echo "  - Certificate: $CERTS_DIR/cert.pem"
echo "  - Key: $CERTS_DIR/key.pem"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Read installation guide: ${YELLOW}cat traefik/INSTALL-CA.md${NC}"
echo "  2. Install CA on your devices (see guide above)"
echo "  3. Start the stack: ${YELLOW}make up${NC}"
echo "  4. Access services via HTTPS: ${YELLOW}https://$HOST_IP:3000${NC}"
echo ""
echo -e "${YELLOW}Note: Browser warnings will appear until you install the CA certificate on your devices.${NC}"
echo ""
