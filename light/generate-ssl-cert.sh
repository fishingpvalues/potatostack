#!/bin/bash
set -euo pipefail

################################################################################
# Generate self-signed SSL certificate for RustyPaste
################################################################################

CERT_DIR="/mnt/storage/rustypaste/ssl"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"

mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Generating self-signed certificate for RustyPaste..."
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$CERT_DIR/key.pem" \
        -out "$CERT_DIR/cert.pem" \
        -days 3650 \
        -subj "/CN=192.168.178.40" \
        -addext "subjectAltName=IP:192.168.178.40"
fi
