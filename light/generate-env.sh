#!/bin/bash

################################################################################
# Generate Production .env File with Strong Passwords
# Run this on your Le Potato to create a secure .env.production file
################################################################################

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Production .env Generator for PotatoStack Light  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if .env.production already exists
if [ -f ".env.production" ]; then
    echo -e "${YELLOW}⚠ WARNING: .env.production already exists!${NC}"
    read -p "Overwrite existing file? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    echo ""
fi

# Generate strong passwords
echo -e "${CYAN}Generating strong passwords...${NC}"

POSTGRES_SUPER_PASSWORD=$(openssl rand -base64 32)
IMMICH_DB_PASSWORD=$(openssl rand -base64 32)
SEAFILE_DB_PASSWORD=$(openssl rand -base64 32)
SEAFILE_ADMIN_PASSWORD=$(openssl rand -base64 32)
VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)
KOPIA_PASSWORD=$(openssl rand -base64 32)
KOPIA_SERVER_PASSWORD=$(openssl rand -base64 32)
SLSKD_PASSWORD=$(openssl rand -base64 32)
TRANSMISSION_PASSWORD=$(openssl rand -base64 32)

echo -e "${GREEN}✓ Generated all passwords${NC}"
echo ""

# Get user input for network configuration
echo -e "${CYAN}Network Configuration:${NC}"
read -p "Enter your Le Potato IP address [192.168.178.40]: " HOST_BIND
HOST_BIND=${HOST_BIND:-192.168.178.40}

read -p "Enter your local network subnet [192.168.178.0/24]: " LAN_NETWORK
LAN_NETWORK=${LAN_NETWORK:-192.168.178.0/24}

read -p "Enter your domain name [lepotato.local]: " HOST_DOMAIN
HOST_DOMAIN=${HOST_DOMAIN:-lepotato.local}

echo ""

# Get VPN configuration
echo -e "${CYAN}Surfshark VPN Configuration:${NC}"
echo "Get credentials from: https://my.surfshark.com/vpn/manual-setup/main"
read -p "Surfshark Username: " SURFSHARK_USER
read -sp "Surfshark Password: " SURFSHARK_PASSWORD
echo ""
read -p "Surfshark Country [Netherlands]: " SURFSHARK_COUNTRY
SURFSHARK_COUNTRY=${SURFSHARK_COUNTRY:-Netherlands}
read -p "Surfshark City [Amsterdam]: " SURFSHARK_CITY
SURFSHARK_CITY=${SURFSHARK_CITY:-Amsterdam}

echo ""

# Get FritzBox configuration
echo -e "${CYAN}FritzBox Configuration (optional):${NC}"
read -p "FritzBox Username [leave empty for default]: " FRITZ_USERNAME
read -sp "FritzBox Password: " FRITZ_PASSWORD
echo ""
read -p "FritzBox Hostname [fritz.box]: " FRITZ_HOSTNAME
FRITZ_HOSTNAME=${FRITZ_HOSTNAME:-fritz.box}

echo ""

# Get email for Seafile
echo -e "${CYAN}Seafile Configuration:${NC}"
read -p "Seafile Admin Email [admin@$HOST_DOMAIN]: " SEAFILE_ADMIN_EMAIL
SEAFILE_ADMIN_EMAIL=${SEAFILE_ADMIN_EMAIL:-admin@$HOST_DOMAIN}

echo ""

# Create .env.production file
cat > .env.production << EOF
################################################################################
# PotatoStack Light - Production Environment Configuration
# Generated on: $(date)
# CRITICAL: Never commit this file to git - contains sensitive passwords!
################################################################################

################################################################################
# Network Configuration
################################################################################
LAN_NETWORK=$LAN_NETWORK
HOST_BIND=$HOST_BIND
HOST_DOMAIN=$HOST_DOMAIN

################################################################################
# VPN Configuration (Surfshark)
################################################################################
SURFSHARK_USER=$SURFSHARK_USER
SURFSHARK_PASSWORD=$SURFSHARK_PASSWORD
SURFSHARK_COUNTRY=$SURFSHARK_COUNTRY
SURFSHARK_CITY=$SURFSHARK_CITY
SURFSHARK_CONNECTION_TYPE=openvpn
VPN_DNS=1.1.1.1

################################################################################
# Transmission (Torrent Client)
################################################################################
TRANSMISSION_USER=admin
TRANSMISSION_PASSWORD=$TRANSMISSION_PASSWORD

################################################################################
# slskd (Soulseek Client)
################################################################################
SLSKD_USER=admin
SLSKD_PASSWORD=$SLSKD_PASSWORD

################################################################################
# PostgreSQL Database
################################################################################
POSTGRES_SUPER_PASSWORD=$POSTGRES_SUPER_PASSWORD
IMMICH_DB_PASSWORD=$IMMICH_DB_PASSWORD
SEAFILE_DB_PASSWORD=$SEAFILE_DB_PASSWORD

################################################################################
# Vaultwarden (Password Manager)
################################################################################
VAULTWARDEN_ADMIN_TOKEN=$VAULTWARDEN_ADMIN_TOKEN
VAULTWARDEN_SIGNUPS_ALLOWED=false
VAULTWARDEN_INVITATIONS_ALLOWED=true

################################################################################
# Kopia (Central Backup Server)
################################################################################
KOPIA_PASSWORD=$KOPIA_PASSWORD
KOPIA_SERVER_USER=admin
KOPIA_SERVER_PASSWORD=$KOPIA_SERVER_PASSWORD

################################################################################
# Seafile (File Sync & Share)
################################################################################
SEAFILE_ADMIN_EMAIL=$SEAFILE_ADMIN_EMAIL
SEAFILE_ADMIN_PASSWORD=$SEAFILE_ADMIN_PASSWORD

################################################################################
# Fritz!Box Router Monitoring
################################################################################
FRITZ_USERNAME=$FRITZ_USERNAME
FRITZ_PASSWORD=$FRITZ_PASSWORD
FRITZ_HOSTNAME=$FRITZ_HOSTNAME
FRITZ_PORT=49000
FRITZ_PROTOCOL=https

################################################################################
# Homepage Dashboard Configuration
################################################################################
HOMEPAGE_VAR_HOST_BIND=$HOST_BIND
HOMEPAGE_VAR_TRANSMISSION_USER=admin
HOMEPAGE_VAR_TRANSMISSION_PASSWORD=$TRANSMISSION_PASSWORD
HOMEPAGE_VAR_SLSKD_USER=admin
HOMEPAGE_VAR_SLSKD_PASSWORD=$SLSKD_PASSWORD
HOMEPAGE_VAR_IMMICH_API_KEY=
HOMEPAGE_VAR_PORTAINER_API_KEY=

################################################################################
# Watchtower (Automatic Updates)
################################################################################
WATCHTOWER_NOTIFICATION_URL=

################################################################################
# Docker Image Tags
################################################################################
HOMEPAGE_TAG=latest
WATCHTOWER_TAG=latest
AUTOHEAL_TAG=latest
GLUETUN_TAG=latest
TRANSMISSION_TAG=latest
SLSKD_TAG=0.21.1
POSTGRES_TAG=pg14-v0.2.0
REDIS_TAG=7-alpine
VAULTWARDEN_TAG=latest
PORTAINER_TAG=2.20.3
IMMICH_TAG=release
KOPIA_TAG=0.15.0
SEAFILE_TAG=latest
RUSTYPASTE_TAG=latest
FRITZBOX_EXPORTER_TAG=latest

################################################################################
# Service Access Ports (based on HOST_BIND)
################################################################################
# Homepage Dashboard:    http://$HOST_BIND:3000
# Gluetun Control:       http://$HOST_BIND:8000
# Transmission WebUI:    http://$HOST_BIND:9091
# slskd WebUI:          http://$HOST_BIND:2234
# Vaultwarden:          http://$HOST_BIND:8080
# Vaultwarden WebSocket: http://$HOST_BIND:3012
# Portainer:            https://$HOST_BIND:9443
# Immich:               http://$HOST_BIND:2283
# Kopia:                https://$HOST_BIND:51515
# Kopia Metrics:        http://$HOST_BIND:51516
# Seafile:              http://$HOST_BIND:8082
# Rustypaste:           http://$HOST_BIND:8001
# FritzBox Exporter:    http://$HOST_BIND:9042
EOF

chmod 600 .env.production

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ✓ .env.production file created successfully  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Save these credentials securely!${NC}"
echo ""
echo -e "${CYAN}Main Access Credentials:${NC}"
echo "  Transmission:   admin / $TRANSMISSION_PASSWORD"
echo "  slskd:          admin / $SLSKD_PASSWORD"
echo "  Seafile:        $SEAFILE_ADMIN_EMAIL / $SEAFILE_ADMIN_PASSWORD"
echo "  Vaultwarden:    (Set on first login)"
echo "  Portainer:      (Set on first login)"
echo ""
echo -e "${CYAN}Admin Tokens:${NC}"
echo "  Vaultwarden Admin: $VAULTWARDEN_ADMIN_TOKEN"
echo ""
echo -e "${CYAN}Database Passwords:${NC}"
echo "  PostgreSQL Super: $POSTGRES_SUPER_PASSWORD"
echo "  Immich DB:        $IMMICH_DB_PASSWORD"
echo "  Seafile DB:       $SEAFILE_DB_PASSWORD"
echo ""
echo -e "${CYAN}Backup Credentials:${NC}"
echo "  Kopia Password:        $KOPIA_PASSWORD"
echo "  Kopia Server User:     admin"
echo "  Kopia Server Password: $KOPIA_SERVER_PASSWORD"
echo ""
echo -e "${YELLOW}Save this output in your password manager!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Copy homepage config: cp -r homepage-config/* /path/to/homepage-volume/"
echo "  2. Start the stack: docker compose -f docker-compose.production.yml --env-file .env.production up -d"
echo "  3. Access Homepage at: http://$HOST_BIND:3000"
echo ""
