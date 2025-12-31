#!/bin/sh
set -e

SSL_DIR="/ssl"
CERT_FILE="$SSL_DIR/cert.pem"
KEY_FILE="$SSL_DIR/key.pem"

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Generate self-signed certificate if it doesn't exist
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
	echo "Generating self-signed SSL certificate for vaultwarden..."

	# Get IP address from HOST_BIND or use default
	IP_ADDR="${HOST_BIND:-192.168.178.40}"

	openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
		-keyout "$KEY_FILE" \
		-out "$CERT_FILE" \
		-subj "/C=DE/ST=Local/L=Local/O=PotatoStack/CN=$IP_ADDR" \
		-addext "subjectAltName=IP:$IP_ADDR,DNS:localhost,DNS:*.local"

	chmod 644 "$CERT_FILE"
	chmod 600 "$KEY_FILE"

	echo "SSL certificate generated successfully"
else
	echo "SSL certificate already exists"
fi

# Start vaultwarden
exec /start.sh
