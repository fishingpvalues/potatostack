#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

usage() {
	echo "Usage: $0 <path-to-wireguard-conf>"
	echo ""
	echo "Example: $0 ~/Downloads/surfshark-frankfurt.conf"
	echo ""
	echo "This script parses a Surfshark WireGuard configuration file"
	echo "and updates the .env file with the correct Gluetun VPN parameters."
	exit 1
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	usage
fi

WG_CONF_FILE="$1"

if [ ! -f "$WG_CONF_FILE" ]; then
	echo -e "${RED}Error: Configuration file not found: $WG_CONF_FILE${NC}"
	exit 1
fi

echo -e "${BLUE}Parsing WireGuard configuration from: $WG_CONF_FILE${NC}"
echo ""

WG_PRIVATE_KEY=""
WG_ADDRESSES=""
WG_PUBLIC_KEY=""
WG_ENDPOINT=""
WG_DNS=""

while IFS='=' read -r key value; do
	key=$(echo "$key" | xargs)
	value=$(echo "$value" | xargs)

	case "$key" in
	\#*)
		continue
		;;
	\[*\])
		continue
		;;
	PrivateKey)
		WG_PRIVATE_KEY="$value"
		;;
	Address)
		if [ -z "$WG_ADDRESSES" ]; then
			WG_ADDRESSES="$value"
		fi
		;;
	PublicKey)
		WG_PUBLIC_KEY="$value"
		;;
	Endpoint)
		WG_ENDPOINT="$value"
		;;
	DNS)
		WG_DNS="$value"
		;;
	esac
done <"$WG_CONF_FILE"

if [ -z "$WG_PRIVATE_KEY" ]; then
	echo -e "${RED}Error: PrivateKey not found in configuration file${NC}"
	exit 1
fi

if [ -z "$WG_ADDRESSES" ]; then
	echo -e "${RED}Error: Address not found in configuration file${NC}"
	exit 1
fi

if [ -z "$WG_PUBLIC_KEY" ]; then
	echo -e "${RED}Error: PublicKey not found in configuration file${NC}"
	exit 1
fi

if [ -z "$WG_ENDPOINT" ]; then
	echo -e "${RED}Error: Endpoint not found in configuration file${NC}"
	exit 1
fi

echo -e "${GREEN}Found values:${NC}"
echo "  PrivateKey: ${WG_PRIVATE_KEY:0:10}..."
echo "  Address: $WG_ADDRESSES"
echo "  PublicKey: $WG_PUBLIC_KEY"
echo "  Endpoint: $WG_ENDPOINT"
if [ -n "$WG_DNS" ]; then
	echo "  DNS: $WG_DNS"
fi
echo ""

if [ ! -f "$ENV_FILE" ]; then
	echo -e "${YELLOW}Warning: .env file not found at $ENV_FILE${NC}"
	echo -e "${YELLOW}Please copy .env.example to .env first${NC}"
	exit 1
fi

BACKUP_FILE="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$ENV_FILE" "$BACKUP_FILE"
echo -e "${BLUE}Backup created: $BACKUP_FILE${NC}"
echo ""

VPN_PROVIDER="surfshark"
VPN_TYPE="wireguard"

extract_country() {
	local endpoint="$1"

	case "$endpoint" in
	*de-* | *german* | *frankfurt*)
		echo "Germany"
		;;
	*us-* | *united* | *america*)
		echo "United States"
		;;
	*uk-* | *united*kingdom* | *british*)
		echo "United Kingdom"
		;;
	*nl-* | *nether*)
		echo "Netherlands"
		;;
	*ch-* | *switzer*)
		echo "Switzerland"
		;;
	*fr-* | *french*)
		echo "France"
		;;
	*it-* | *italy*)
		echo "Italy"
		;;
	*es-* | *spain*)
		echo "Spain"
		;;
	*pl-* | *poland*)
		echo "Poland"
		;;
	*jp-* | *japan*)
		echo "Japan"
		;;
	*au-* | *australia*)
		echo "Australia"
		;;
	*ca-* | *canada*)
		echo "Canada"
		;;
	*br-* | *brazil*)
		echo "Brazil"
		;;
	*)
		echo "Germany"
		;;
	esac
}

extract_endpoint_ip() {
	local endpoint="$1"
	nslookup "$endpoint" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || echo ""
}

VPN_COUNTRY=$(extract_country "$WG_ENDPOINT")

echo -e "${BLUE}Updating .env file...${NC}"

sed -i.tmp "s|^VPN_PROVIDER=.*|VPN_PROVIDER=$VPN_PROVIDER|" "$ENV_FILE"
sed -i.tmp "s|^VPN_TYPE=.*|VPN_TYPE=$VPN_TYPE|" "$ENV_FILE"
sed -i.tmp "s|^WIREGUARD_PRIVATE_KEY=.*|WIREGUARD_PRIVATE_KEY=$WG_PRIVATE_KEY|" "$ENV_FILE"
sed -i.tmp "s|^WIREGUARD_ADDRESSES=.*|WIREGUARD_ADDRESSES=$WG_ADDRESSES|" "$ENV_FILE"
sed -i.tmp "s|^SERVER_COUNTRIES=.*|SERVER_COUNTRIES=$VPN_COUNTRY|" "$ENV_FILE"

if [ -n "$WG_DNS" ]; then
	DNS_PRIMARY=$(echo "$WG_DNS" | cut -d',' -f1 | xargs)
	sed -i.tmp "s|^VPN_DNS=.*|VPN_DNS=$DNS_PRIMARY|" "$ENV_FILE"
fi

rm -f "${ENV_FILE}.tmp"

echo -e "${GREEN}Successfully updated .env file with:${NC}"
echo "  VPN_PROVIDER: $VPN_PROVIDER"
echo "  VPN_TYPE: $VPN_TYPE"
echo "  WIREGUARD_PRIVATE_KEY: ${WG_PRIVATE_KEY:0:10}..."
echo "  WIREGUARD_ADDRESSES: $WG_ADDRESSES"
echo "  SERVER_COUNTRIES: $VPN_COUNTRY"
if [ -n "$WG_DNS" ]; then
	echo "  VPN_DNS: $DNS_PRIMARY"
fi
echo ""

echo -e "${YELLOW}To apply changes, restart gluetun:${NC}"
echo "  cd $PROJECT_ROOT && docker compose restart gluetun"
echo ""
echo -e "${YELLOW}To check VPN status:${NC}"
echo "  docker logs -f gluetun"
echo "  curl http://192.168.178.158:8008/v1/vpn/status"
