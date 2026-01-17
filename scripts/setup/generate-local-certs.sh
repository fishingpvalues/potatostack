#!/bin/bash
set -euo pipefail

# Generate self-signed certificates for local homelab HTTPS
# Usage: ./generate-local-certs.sh [domain]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CERT_DIR="$PROJECT_ROOT/config/traefik/certs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load domain from .env or use default
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    HOST_DOMAIN=$(grep -E "^HOST_DOMAIN=" "$PROJECT_ROOT/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi
DOMAIN="${1:-${HOST_DOMAIN:-danielhomelab.local}}"

echo -e "${GREEN}Generating self-signed certificates for *.${DOMAIN}${NC}"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA key and certificate
if [[ ! -f "ca.key" ]]; then
    echo -e "${YELLOW}Creating local CA...${NC}"
    openssl genrsa -out ca.key 4096
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
        -subj "/C=DE/ST=Local/L=Homelab/O=PotatoStack CA/CN=PotatoStack Local CA"
    echo -e "${GREEN}CA created: ca.crt${NC}"
else
    echo -e "${YELLOW}Using existing CA${NC}"
fi

# Generate wildcard certificate
echo -e "${YELLOW}Generating wildcard certificate for *.${DOMAIN}${NC}"

# Create certificate config
cat > cert.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = DE
ST = Local
L = Homelab
O = PotatoStack
CN = *.${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

# Generate private key
openssl genrsa -out local.key 2048

# Generate CSR
openssl req -new -key local.key -out local.csr -config cert.conf

# Create extension config for SAN
cat > ext.conf << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

# Sign the certificate with CA
openssl x509 -req -in local.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out local.crt -days 825 -sha256 -extfile ext.conf

# Cleanup temp files
rm -f cert.conf ext.conf local.csr

echo -e "${GREEN}Certificates generated:${NC}"
echo "  - CA Certificate: $CERT_DIR/ca.crt"
echo "  - Server Certificate: $CERT_DIR/local.crt"
echo "  - Server Key: $CERT_DIR/local.key"
echo ""
echo -e "${YELLOW}To trust these certificates on your devices:${NC}"
echo "  1. Copy ca.crt to your device"
echo "  2. Import it as a trusted CA certificate"
echo "     - Linux: sudo cp ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates"
echo "     - macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt"
echo "     - Windows: certutil -addstore -f \"ROOT\" ca.crt"
echo ""
echo -e "${GREEN}Done! Restart Traefik to use the new certificates.${NC}"
