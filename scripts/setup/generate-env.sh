#!/bin/bash
set -euo pipefail
################################################################################
# PotatoStack Environment Generator
# Generates .env file with secure passwords and secrets for ALL services
################################################################################
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

################################################################################
# Helper Functions
################################################################################
print_header() {
	echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
	echo -e "${CYAN}  $1${NC}"
	echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}
print_step() {
	echo -e "${GREEN}▸${NC} $1"
}
print_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
}
print_error() {
	echo -e "${RED}✖${NC} $1"
}
print_success() {
	echo -e "${GREEN}✔${NC} $1"
}

# Generate random base64 secret
gen_base64() {
	local bytes="${1:-32}"
	openssl rand -base64 "$bytes" | tr -d '\n'
}
gen_hex() {
	local bytes="${1:-32}"
	openssl rand -hex "$bytes" | tr -d '\n'
}
gen_cookie_secret() {
	openssl rand -base64 32 | tr -d '\n'
}
gen_firefly_key() {
	echo -n "base64:$(gen_base64 32)"
}

validate_password() {
	local pw="$1"
	local min_len="${2:-12}"
	[[ ${#pw} -ge $min_len ]]
}

read_password() {
	local prompt="$1"
	local var_name="$2"
	local min_len="${3:-12}"
	local pw1 pw2
	while true; do
		echo -ne "${CYAN}$prompt${NC} (min $min_len chars): "
		read -rs pw1
		echo
		if ! validate_password "$pw1" "$min_len"; then
			print_error "Password must be at least $min_len characters"
			continue
		fi
		echo -ne "${CYAN}Confirm password:${NC} "
		read -rs pw2
		echo
		if [[ "$pw1" != "$pw2" ]]; then
			print_error "Passwords do not match. Try again."
			continue
		fi
		eval "$var_name=\"\$pw1\""
		break
	done
}

read_input() {
	local prompt="$1"
	local var_name="$2"
	local default="${3:-}"
	local value
	if [[ -n "$default" ]]; then
		echo -ne "${CYAN}$prompt${NC} [${default}]: "
	else
		echo -ne "${CYAN}$prompt${NC}: "
	fi
	read -r value
	if [[ -z "$value" && -n "$default" ]]; then
		value="$default"
	fi
	eval "$var_name=\"\$value\""
}

read_optional() {
	local prompt="$1"
	local var_name="$2"
	local value
	echo -ne "${CYAN}$prompt${NC} (optional, press Enter to skip): "
	read -r value
	eval "$var_name=\"\$value\""
}

################################################################################
# Main Script
################################################################################
main() {
	print_header "PotatoStack Environment Generator"

	if [[ -f "$ENV_FILE" ]]; then
		print_warning "Existing .env file found at $ENV_FILE"
		echo -ne "${YELLOW}Overwrite? (y/N):${NC} "
		read -r confirm
		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			print_error "Aborted. Existing .env preserved."
			exit 1
		fi
		cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
		print_step "Backed up existing .env"
	fi

	echo -e "\nThis script will generate a complete .env file with secure secrets."
	echo -e "You'll be asked for a few credentials.\n"

	############################################################################
	# Collect User Input
	############################################################################
	print_header "Network Configuration"
	read_input "Host IP address (bind address)" HOST_BIND "192.168.178.158"
	read_input "Local network subnet (CIDR)" LAN_NETWORK "192.168.178.0/24"
	read_input "Domain for services" HOST_DOMAIN "local.domain"
	read_input "Email for SSL certificates" ACME_EMAIL "admin@example.com"

	print_header "Master Credentials"
	echo -e "These credentials will be used for ALL services that require login.\n"
	read_input "Admin username" ADMIN_USER "admin"
	read_password "Admin password" ADMIN_PASSWORD 12

	print_header "File Sharing (Samba)"
	read_input "Samba username" SAMBA_USER "potato"
	echo -e "${CYAN}Using admin password for Samba${NC}"
	SAMBA_PASSWORD="$ADMIN_PASSWORD"

	print_header "VPN Configuration"
	read_input "VPN Provider" VPN_PROVIDER "surfshark"
	read_input "VPN Type" VPN_TYPE "wireguard"
	read_optional "WireGuard Private Key" WIREGUARD_PRIVATE_KEY
	read_input "WireGuard Addresses (client VPN IP)" WIREGUARD_ADDRESSES "10.64.222.21/16"
	read_input "VPN Country" VPN_COUNTRY "Germany"

	print_header "Tailscale (Optional)"
	read_optional "Tailscale Auth Key" TAILSCALE_AUTHKEY

	print_header "External Services (Optional)"
	read_optional "Soulseek Username" SLSKD_SOULSEEK_USERNAME
	read_optional "Soulseek Password" SLSKD_SOULSEEK_PASSWORD
	read_optional "FritzBox Username" FRITZ_USERNAME
	read_optional "FritzBox Password" FRITZ_PASSWORD
	read_input "FritzBox Hostname" FRITZ_HOSTNAME "fritz.box"

	print_header "Development (CI/CD)"
	read_input "Gitea Admin Username" WOODPECKER_ADMIN "$ADMIN_USER"

	print_header "SSH Server (Optional)"
	read_input "OpenSSH port" OPENSSH_PORT "2222"
	read_input "OpenSSH username" OPENSSH_USER "sshuser"
	echo -e "${CYAN}Using admin password for OpenSSH${NC}"
	OPENSSH_PASSWORD="$ADMIN_PASSWORD"

	############################################################################
	# Generate All Secrets
	############################################################################
	print_header "Generating Secure Secrets"
	print_step "Database passwords..."
	POSTGRES_SUPER_PASSWORD="$ADMIN_PASSWORD"
	MONGO_ROOT_PASSWORD="$ADMIN_PASSWORD"
	AUTHENTIK_DB_PASSWORD="$ADMIN_PASSWORD"
	FIREFLY_DB_PASSWORD="$ADMIN_PASSWORD"
	CALIBRE_DB_PASSWORD="$ADMIN_PASSWORD"
	SENTRY_DB_PASSWORD="$ADMIN_PASSWORD"

	print_step "Service passwords..."
	GRAFANA_PASSWORD="$ADMIN_PASSWORD"
	GRAFANA_ADMIN_PASSWORD="$ADMIN_PASSWORD"
	N8N_PASSWORD="$ADMIN_PASSWORD"
	LINKDING_ADMIN_PASSWORD="$ADMIN_PASSWORD"
	HEALTHCHECKS_ADMIN_PASSWORD="$ADMIN_PASSWORD"
	COUCHDB_PASSWORD="$ADMIN_PASSWORD"
	SLSKD_PASSWORD="$ADMIN_PASSWORD"
	PARSEABLE_PASSWORD="$ADMIN_PASSWORD"
	MINIFLUX_ADMIN_PASSWORD="$ADMIN_PASSWORD"
	CODE_SERVER_PASSWORD="$ADMIN_PASSWORD"
	CODE_SERVER_SUDO_PASSWORD="$ADMIN_PASSWORD"
	KOPIA_PASSWORD="$ADMIN_PASSWORD"
	KOPIA_SERVER_PASSWORD="$ADMIN_PASSWORD"
	VELLD_ADMIN_PASSWORD="$ADMIN_PASSWORD"
	ELASTIC_PASSWORD="$ADMIN_PASSWORD"
	PAPERLESS_ADMIN_PASSWORD="$ADMIN_PASSWORD"

	print_step "Base64 secrets..."
	AUTHENTIK_SECRET_KEY="$(gen_base64 48)"
	VAULTWARDEN_ADMIN_TOKEN="$(gen_base64 32)"
	OAUTH2_PROXY_CLIENT_SECRET="$(gen_base64 32)"
	OAUTH2_PROXY_COOKIE_SECRET="$(gen_cookie_secret)"
	HEALTHCHECKS_SECRET_KEY="$(gen_base64 32)"
	CALCOM_NEXTAUTH_SECRET="$(gen_base64 32)"
	CALCOM_ENCRYPTION_KEY="$(gen_base64 32)"
	WOODPECKER_AGENT_SECRET="$(gen_base64 32)"
	DRONE_RPC_SECRET="$(gen_base64 32)"
	SENTRY_SECRET_KEY="$(gen_base64 32)"
	OPEN_WEBUI_SECRET_KEY="$(gen_base64 32)"
	VELLD_JWT_SECRET="$(gen_base64 32)"
	PAPERLESS_SECRET_KEY="$(gen_base64 32)"
	MEALIE_SECRET_KEY="$(gen_base64 32)"
	INFISICAL_AUTH_SECRET="$(gen_base64 32)"
	INFISICAL_ENCRYPTION_KEY="$(gen_base64 32)"

	print_step "Hex secrets..."
	HOMARR_SECRET_KEY="$(gen_hex 32)"
	HUGINN_SECRET_TOKEN="$(gen_hex 32)"
	ARIA2_RPC_SECRET="$(gen_hex 16)"
	VELLD_ENCRYPTION_KEY="$(gen_hex 32)"
	CROWDSEC_BOUNCER_KEY="$(gen_hex 32)"

	print_step "Special format secrets..."
	FIREFLY_APP_KEY="$(gen_firefly_key)"
	HUGINN_INVITATION_CODE="$(gen_hex 8)"

	print_step "Placeholder tokens..."
	GITEA_RUNNER_TOKEN="get_from_gitea_after_setup"
	WOODPECKER_GITEA_CLIENT="get_from_gitea_oauth_app"
	WOODPECKER_GITEA_SECRET="get_from_gitea_oauth_app"
	DRONE_GITEA_CLIENT_ID="get_from_gitea_oauth_app"
	DRONE_GITEA_CLIENT_SECRET="get_from_gitea_oauth_app"
	OAUTH2_PROXY_CLIENT_ID="get_from_authentik_after_setup"
	FIREFLY_ACCESS_TOKEN="get_from_firefly_after_setup"
	SYNCTHING_API_KEY=""
	PORTAINER_API_KEY=""
	SLSKD_API_KEY=""

	print_success "All secrets generated!"

	############################################################################
	# Generate .env File
	############################################################################
	print_header "Writing .env File"
	cat >"$ENV_FILE" <<ENVFILE
################################################################################
# PotatoStack Main Environment Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# NEVER commit this file to git!
################################################################################

################################################################################
# NETWORK CONFIGURATION
################################################################################
HOST_BIND=${HOST_BIND}
LAN_NETWORK=${LAN_NETWORK}
HOST_DOMAIN=${HOST_DOMAIN}
ACME_EMAIL=${ACME_EMAIL}

################################################################################
# FILE SHARING (Samba)
################################################################################
SAMBA_USER=${SAMBA_USER}
SAMBA_PASSWORD=${SAMBA_PASSWORD}

################################################################################
# CORE DATABASES
################################################################################
POSTGRES_SUPER_PASSWORD=${POSTGRES_SUPER_PASSWORD}
POSTGRES_DATABASES=nextcloud,authentik,gitea,woodpecker,immich,calibre,linkding,n8n,healthchecks,stirlingpdf,atuin,homarr,paperless,openwebui,miniflux,grafana,infisical
MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD}

################################################################################
# VPN CONFIGURATION
################################################################################
VPN_PROVIDER=${VPN_PROVIDER}
VPN_TYPE=${VPN_TYPE}
WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}
VPN_COUNTRY=${VPN_COUNTRY}
VPN_LOG_LEVEL=info
VPN_INPUT_PORTS=51413,50000,6888
VPN_DNS=1.1.1.1
GLUETUN_CHECK_INTERVAL=10
TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY}
WIREGUARD_SERVERURL=auto
WIREGUARD_SERVERPORT=51820
WIREGUARD_PEERS=vps,android,laptop,tablet,raspberry
WIREGUARD_PEERDNS=auto
WIREGUARD_INTERNAL_SUBNET=10.13.13.0/24
WIREGUARD_ALLOWEDIPS=0.0.0.0/0
WIREGUARD_LOG_CONFS=true

################################################################################
# AUTHENTICATION & SECURITY
################################################################################
AUTHENTIK_DB_PASSWORD=${AUTHENTIK_DB_PASSWORD}
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}
CROWDSEC_BOUNCER_KEY=${CROWDSEC_BOUNCER_KEY}
VAULTWARDEN_ADMIN_TOKEN=${VAULTWARDEN_ADMIN_TOKEN}
VAULTWARDEN_SIGNUPS_ALLOWED=false
VAULTWARDEN_INVITATIONS_ALLOWED=true
INFISICAL_AUTH_SECRET=${INFISICAL_AUTH_SECRET}
INFISICAL_ENCRYPTION_KEY=${INFISICAL_ENCRYPTION_KEY}
OAUTH2_PROXY_OIDC_ISSUER_URL=https://auth.${HOST_DOMAIN}/application/o/oauth2-proxy/
OAUTH2_PROXY_CLIENT_ID=${OAUTH2_PROXY_CLIENT_ID}
OAUTH2_PROXY_CLIENT_SECRET=${OAUTH2_PROXY_CLIENT_SECRET}
OAUTH2_PROXY_COOKIE_SECRET=${OAUTH2_PROXY_COOKIE_SECRET}
OAUTH2_PROXY_REDIRECT_URL=https://auth.${HOST_DOMAIN}/oauth2/callback
OAUTH2_PROXY_EMAIL_DOMAINS=*
OAUTH2_PROXY_COOKIE_DOMAINS=.${HOST_DOMAIN}
OAUTH2_PROXY_WHITELIST_DOMAINS=.${HOST_DOMAIN}

################################################################################
# SSH SERVER
################################################################################
OPENSSH_PORT=${OPENSSH_PORT}
OPENSSH_USER=${OPENSSH_USER}
OPENSSH_PASSWORD=${OPENSSH_PASSWORD}
OPENSSH_PASSWORD_ACCESS=true
OPENSSH_SUDO_ACCESS=false
OPENSSH_PUBLIC_KEY=
OPENSSH_PUBLIC_KEY_FILE=
OPENSSH_PUBLIC_KEY_DIR=
OPENSSH_PUBLIC_KEY_URL=
OPENSSH_LOG_STDOUT=true
GITEA_SSH_PORT=2223

################################################################################
# MONITORING & HEALTHCHECK CONFIG
################################################################################
IMMICH_LOG_CHECK_INTERVAL=60
IMMICH_RESTART_COOLDOWN=300
IMMICH_LOG_PATTERNS=redis|Redis|ECONNREFUSED|Connection refused|connect ECONNREFUSED|socket hang up

GLUETUN_RESTART_ON_STOP=true
GLUETUN_RESTART_ON_FAILURE=true
GLUETUN_RESTART_COOLDOWN=120

DISK_MONITOR_PATHS=/mnt/storage /mnt/ssd /mnt/cachehdd
DISK_MONITOR_INTERVAL=300
DISK_MONITOR_WARN=80
DISK_MONITOR_CRIT=90

TRAEFIK_LOG_CHECK_INTERVAL=60
TRAEFIK_LOG_PATTERNS=acme|certificate|x509|tls
TRAEFIK_LOG_LEVEL_PATTERN=level=error
TRAEFIK_RESTART_ON_ERROR=false
TRAEFIK_RESTART_COOLDOWN=300

BACKUP_MONITOR_PATHS=/mnt/storage/kopia/stack-snapshot.log /mnt/storage/velld/backups
BACKUP_MAX_AGE_HOURS=48
BACKUP_MONITOR_INTERVAL=3600

DB_MONITOR_INTERVAL=30
DB_FAIL_THRESHOLD=3
DB_RESTART_COOLDOWN=180
DB_RESTART_ON_FAILURE=true
DB_CHECK_POSTGRES=true
DB_CHECK_REDIS=true
DB_CHECK_MONGO=false

TAILSCALE_PING_TARGET=
TAILSCALE_PING_INTERVAL=60
TAILSCALE_PING_FAIL_THRESHOLD=3
TAILSCALE_RESTART_COOLDOWN=300

NTFY_INTERNAL_URL=http://ntfy:80
NTFY_TOPIC=potatostack
NTFY_TOKEN=

################################################################################
# DASHBOARD & MANAGEMENT
################################################################################
HOMARR_SECRET_KEY=${HOMARR_SECRET_KEY}
HOMARR_LOG_LEVEL=info
HOMARR_DOCKER_HOSTNAMES=socket-proxy
HOMARR_DOCKER_PORTS=2375
SOCKET_PROXY_TAG=latest

################################################################################
# KNOWLEDGE MANAGEMENT
################################################################################
COUCHDB_USER=${ADMIN_USER}
COUCHDB_PASSWORD=${COUCHDB_PASSWORD}

# Recipe Management
MEALIE_SECRET_KEY=${MEALIE_SECRET_KEY}

################################################################################
# FINANCE
################################################################################
FIREFLY_DB_PASSWORD=${FIREFLY_DB_PASSWORD}
FIREFLY_APP_KEY=${FIREFLY_APP_KEY}
FIREFLY_ACCESS_TOKEN=${FIREFLY_ACCESS_TOKEN}
NORDIGEN_ID=
NORDIGEN_KEY=
SPECTRE_APP_ID=
SPECTRE_SECRET=

################################################################################
# DOWNLOAD CLIENTS
################################################################################
ARIA2_RPC_SECRET=${ARIA2_RPC_SECRET}
SLSKD_USER=${ADMIN_USER}
SLSKD_PASSWORD=${SLSKD_PASSWORD}
SLSKD_SOULSEEK_USERNAME=${SLSKD_SOULSEEK_USERNAME}
SLSKD_SOULSEEK_PASSWORD=${SLSKD_SOULSEEK_PASSWORD}
SLSKD_API_KEY=${SLSKD_API_KEY}

################################################################################
# MONITORING & OBSERVABILITY
################################################################################
GRAFANA_USER=${ADMIN_USER}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
GRAFANA_ADMIN_USER=${ADMIN_USER}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
GRAFANA_PLUGINS=
PROMETHEUS_RETENTION_DAYS=30d
PARSEABLE_USERNAME=${ADMIN_USER}
PARSEABLE_PASSWORD=${PARSEABLE_PASSWORD}
PARSEABLE_ADDR=0.0.0.0:8000
PARSEABLE_FS_DIR=/data
SCRUTINY_DEVICE_1=/dev/sda
FRITZ_USERNAME=${FRITZ_USERNAME}
FRITZ_PASSWORD=${FRITZ_PASSWORD}
FRITZ_HOSTNAME=${FRITZ_HOSTNAME}

################################################################################
# AUTOMATION & WORKFLOWS
################################################################################
N8N_USER=${ADMIN_USER}
N8N_PASSWORD=${N8N_PASSWORD}
HUGINN_SECRET_TOKEN=${HUGINN_SECRET_TOKEN}
HUGINN_INVITATION_CODE=${HUGINN_INVITATION_CODE}
HEALTHCHECKS_ADMIN_EMAIL=${ACME_EMAIL}
HEALTHCHECKS_ADMIN_PASSWORD=${HEALTHCHECKS_ADMIN_PASSWORD}
HEALTHCHECKS_SECRET_KEY=${HEALTHCHECKS_SECRET_KEY}

################################################################################
# DOCUMENT MANAGEMENT
################################################################################
PAPERLESS_SECRET_KEY=${PAPERLESS_SECRET_KEY}
PAPERLESS_ADMIN_PASSWORD=${PAPERLESS_ADMIN_PASSWORD}

################################################################################
# UTILITIES & TOOLS
################################################################################
LINKDING_ADMIN_USER=${ADMIN_USER}
LINKDING_ADMIN_PASSWORD=${LINKDING_ADMIN_PASSWORD}
CALCOM_NEXTAUTH_SECRET=${CALCOM_NEXTAUTH_SECRET}
CALCOM_ENCRYPTION_KEY=${CALCOM_ENCRYPTION_KEY}
ATUIN_HOST=0.0.0.0
ATUIN_PORT=8888
CODE_SERVER_PASSWORD=${CODE_SERVER_PASSWORD}
CODE_SERVER_SUDO_PASSWORD=${CODE_SERVER_SUDO_PASSWORD}

################################################################################
# DEVELOPMENT & GIT
################################################################################
GITEA_TAG=latest
GITEA_RUNNER_TOKEN=${GITEA_RUNNER_TOKEN}
WOODPECKER_GITEA_CLIENT=${WOODPECKER_GITEA_CLIENT}
WOODPECKER_GITEA_SECRET=${WOODPECKER_GITEA_SECRET}
WOODPECKER_AGENT_SECRET=${WOODPECKER_AGENT_SECRET}
WOODPECKER_ADMIN=${WOODPECKER_ADMIN}
WOODPECKER_MAX_WORKFLOWS=2
CALIBRE_DB_PASSWORD=${CALIBRE_DB_PASSWORD}
DRONE_GITEA_CLIENT_ID=${DRONE_GITEA_CLIENT_ID}
DRONE_GITEA_CLIENT_SECRET=${DRONE_GITEA_CLIENT_SECRET}
DRONE_RPC_SECRET=${DRONE_RPC_SECRET}
DRONE_ADMIN_USER=${WOODPECKER_ADMIN}
SENTRY_DB_PASSWORD=${SENTRY_DB_PASSWORD}
SENTRY_SECRET_KEY=${SENTRY_SECRET_KEY}

################################################################################
# AI & SPECIAL APPLICATIONS
################################################################################
OLLAMA_BASE_URL=http://host.docker.internal:11434
OPEN_WEBUI_SECRET_KEY=${OPEN_WEBUI_SECRET_KEY}

################################################################################
# ELASTICSEARCH STACK
################################################################################
ELASTIC_PASSWORD=${ELASTIC_PASSWORD}

################################################################################
# BACKUPS
################################################################################
KOPIA_PASSWORD=${KOPIA_PASSWORD}
KOPIA_SERVER_USER=${ADMIN_USER}
KOPIA_SERVER_PASSWORD=${KOPIA_SERVER_PASSWORD}
SNAPSHOT_CRON_SCHEDULE=0 3 * * *
SNAPSHOT_PATHS=/data
SNAPSHOT_LOG_FILE=/mnt/storage/kopia/stack-snapshot.log
VELLD_API_URL=http://${HOST_BIND}:8085
VELLD_JWT_SECRET=${VELLD_JWT_SECRET}
VELLD_ENCRYPTION_KEY=${VELLD_ENCRYPTION_KEY}
VELLD_ADMIN_USERNAME=${ADMIN_USER}
VELLD_ADMIN_PASSWORD=${VELLD_ADMIN_PASSWORD}
VELLD_ALLOW_REGISTER=false

################################################################################
# FILE SYNC & SHARING
################################################################################
SYNCTHING_HOSTNAME=potatostack-sync
SYNCTHING_API_KEY=${SYNCTHING_API_KEY}
PORTAINER_API_KEY=${PORTAINER_API_KEY}

################################################################################
# SYSTEM UTILITIES
################################################################################
DIUN_GOTIFY_ENDPOINT=
DIUN_GOTIFY_TOKEN=
DIUN_DISCORD_WEBHOOK=
DIUN_TELEGRAM_TOKEN=
DIUN_TELEGRAM_CHATIDS=

################################################################################
# RSS & NEWS
################################################################################
MINIFLUX_TAG=latest
MINIFLUX_ADMIN_USER=${ADMIN_USER}
MINIFLUX_ADMIN_PASSWORD=${MINIFLUX_ADMIN_PASSWORD}

################################################################################
# NETDATA
################################################################################
NETDATA_TAG=latest
NETDATA_CLAIM_TOKEN=
NETDATA_CLAIM_ROOMS=

################################################################################
# IMAGE TAGS (all required tags defined)
################################################################################
ALPINE_TAG=latest
POSTGRES_TAG=pg16
MONGO_TAG=8
REDIS_TAG=alpine
ADMINER_TAG=latest
TRAEFIK_TAG=latest
NPM_TAG=latest
AUTHENTIK_TAG=latest
VAULTWARDEN_TAG=latest
OAUTH2_PROXY_TAG=latest
GLUETUN_TAG=latest
TAILSCALE_TAG=latest
NEXTCLOUD_AIO_TAG=latest
SYNCTHING_TAG=latest
COUCHDB_TAG=latest
CURL_TAG=latest
FIREFLY_TAG=latest
FIREFLY_IMPORTER_TAG=latest
PROWLARR_TAG=latest
SONARR_TAG=latest
RADARR_TAG=latest
LIDARR_TAG=latest
READARR_TAG=develop
BAZARR_TAG=latest
MAINTAINERR_TAG=latest
JELLYFIN_TAG=latest
JELLYSEERR_TAG=latest
OVERSEERR_TAG=latest
AUDIOBOOKSHELF_TAG=latest
QBITTORRENT_TAG=latest
ARIA2_TAG=latest
ARIANG_TAG=latest
IMMICH_TAG=release
PROMETHEUS_TAG=latest
GRAFANA_TAG=latest
LOKI_TAG=latest
PROMTAIL_TAG=latest
NODE_EXPORTER_TAG=latest
CADVISOR_TAG=latest
FRITZBOX_EXPORTER_TAG=latest
UPTIME_KUMA_TAG=latest
PARSEABLE_TAG=latest
SCRUTINY_TAG=latest
N8N_TAG=latest
HUGINN_TAG=latest
HEALTHCHECKS_TAG=latest
SAMBA_TAG=latest
RUSTYPASTE_TAG=latest
STIRLING_PDF_TAG=latest
LINKDING_TAG=latest
CALCOM_TAG=latest
CODE_SERVER_TAG=latest
DRAWIO_TAG=latest
EXCALIDRAW_TAG=latest
ATUIN_TAG=latest
DUCKDB_TAG=latest
GITEA_TAG=latest
GITEA_RUNNER_TAG=latest
WOODPECKER_TAG=latest
WOODPECKER_AGENT_TAG=latest
DRONE_TAG=latest
DRONE_RUNNER_TAG=latest
SENTRY_TAG=latest
OPEN_WEBUI_TAG=latest
OCTOBOT_TAG=latest
PINCHFLAT_TAG=latest
ELASTICSEARCH_TAG=8
KIBANA_TAG=8
LOGSTASH_TAG=8
GLANCE_TAG=latest
THANOS_TAG=v0.37.2
DIUN_TAG=latest
AUTOHEAL_TAG=latest
PORTAINER_TAG=latest
DOCKER_CLI_TAG=27
WIREGUARD_TAG=latest
SLSKD_TAG=latest
KOPIA_TAG=latest
VELLD_API_TAG=latest
VELLD_WEB_TAG=latest

# Missing tags from compose.yml
PGBOUNCER_TAG=latest
POSTGRES_EXPORTER_TAG=latest
REDIS_EXPORTER_TAG=latest
MONGODB_EXPORTER_TAG=0.43
SMARTCTL_EXPORTER_TAG=latest
ALLOY_TAG=latest
FAIL2BAN_TAG=latest
TRIVY_TAG=latest
ALERTMANAGER_TAG=latest
NTFY_TAG=latest
OPENSSH_SERVER_TAG=latest
ACTUAL_TAG=latest
BOOKSHELF_TAG=hardcover
ENVFILE

	chmod 600 "$ENV_FILE"
	print_success ".env file created at $ENV_FILE"
	print_success "File permissions set to 600"

	############################################################################
	# Summary
	############################################################################
	print_header "Configuration Summary"
	echo -e "  ${GREEN}Network:${NC}    Host IP: ${HOST_BIND}   Domain: ${HOST_DOMAIN}"
	echo -e "  ${GREEN}Admin User:${NC} ${ADMIN_USER}"
	echo -e "  ${GREEN}Admin Password:${NC} [hidden]"
	echo -e "\n  ${GREEN}Generated Secrets:${NC}"
	echo -e "    • 6 database passwords (master)"
	echo -e "    • 15+ service passwords (master)"
	echo -e "    • 12+ base64/hex secrets"
	echo -e "    • All image tags & monitor config"

	echo -e "\n  ${YELLOW}Post-Setup Required:${NC}"
	echo -e "    • GITEA_RUNNER_TOKEN, WOODPECKER_GITEA_*, DRONE_GITEA_*, OAUTH2_PROXY_CLIENT_ID, SYNCTHING_API_KEY, PORTAINER_API_KEY"

	############################################################################
	# Launch Stack
	############################################################################
	print_header "Launch Stack"
	echo -ne "${CYAN}Pull images and start stack? (Y/n):${NC} "
	read -r launch_confirm
	if [[ ! "$launch_confirm" =~ ^[Nn]$ ]]; then
		print_step "Pulling Docker images..."
		cd "$PROJECT_ROOT"
		if docker compose pull --quiet; then
			print_success "Images pulled successfully!"
		else
			print_warning "Some images failed to pull. Continuing..."
		fi
		print_step "Starting stack..."
		if docker compose up -d; then
			print_success "Stack started successfully!"
			echo -e "\n${GREEN}PotatoStack is now running!${NC}"
			echo -e "Check status: ${CYAN}docker compose ps${NC}"
		else
			print_error "Failed to start stack. Check logs: docker compose logs"
			exit 1
		fi
	else
		echo -e "\n${YELLOW}Stack not started.${NC}"
		echo -e "To start manually: cd $PROJECT_ROOT && docker compose pull && docker compose up -d"
	fi

	print_header "Done!"
	echo -e "Your PotatoStack environment is fully configured."
	echo -e "Credentials: ${CYAN}$ENV_FILE${NC}"
	echo -e "\n${YELLOW}IMPORTANT:${NC} Never commit .env to git!"
}

main "$@"
