#!/bin/bash
# Update .env with generated passwords

sed -i "s|^POSTGRES_SUPER_PASSWORD=.*|POSTGRES_SUPER_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^MONGO_ROOT_PASSWORD=.*|MONGO_ROOT_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^AUTHENTIK_DB_PASSWORD=.*|AUTHENTIK_DB_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$(openssl rand -hex 64)|" .env
sed -i "s|^VAULTWARDEN_ADMIN_TOKEN=.*|VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 32)|" .env
sed -i "s|^FIREFLY_DB_PASSWORD=.*|FIREFLY_DB_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^FIREFLY_APP_KEY=.*|FIREFLY_APP_KEY=base64:$(openssl rand -base64 32)|" .env
sed -i "s|^IMMICH_DB_PASSWORD=.*|IMMICH_DB_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^GRAFANA_PASSWORD=.*|GRAFANA_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^N8N_PASSWORD=.*|N8N_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^HUGINN_SECRET_TOKEN=.*|HUGINN_SECRET_TOKEN=$(openssl rand -hex 32)|" .env
sed -i "s|^HUGINN_INVITATION_CODE=.*|HUGINN_INVITATION_CODE=$(openssl rand -hex 16)|" .env
sed -i "s|^HEALTHCHECKS_SECRET_KEY=.*|HEALTHCHECKS_SECRET_KEY=$(openssl rand -hex 32)|" .env
sed -i "s|^HEALTHCHECKS_ADMIN_PASSWORD=.*|HEALTHCHECKS_ADMIN_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^LINKDING_ADMIN_PASSWORD=.*|LINKDING_ADMIN_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^CALCOM_NEXTAUTH_SECRET=.*|CALCOM_NEXTAUTH_SECRET=$(openssl rand -base64 32)|" .env
sed -i "s|^CALCOM_ENCRYPTION_KEY=.*|CALCOM_ENCRYPTION_KEY=$(openssl rand -base64 32)|" .env
sed -i "s|^CODE_SERVER_PASSWORD=.*|CODE_SERVER_PASSWORD=$(openssl rand -base64 16)|" .env
sed -i "s|^CODE_SERVER_SUDO_PASSWORD=.*|CODE_SERVER_SUDO_PASSWORD=$(openssl rand -base64 16)|" .env
sed -i "s|^DRONE_RPC_SECRET=.*|DRONE_RPC_SECRET=$(openssl rand -hex 32)|" .env
sed -i "s|^SENTRY_DB_PASSWORD=.*|SENTRY_DB_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^SENTRY_SECRET_KEY=.*|SENTRY_SECRET_KEY=$(openssl rand -hex 32)|" .env
sed -i "s|^OPEN_WEBUI_SECRET_KEY=.*|OPEN_WEBUI_SECRET_KEY=$(openssl rand -hex 32)|" .env
sed -i "s|^ELASTIC_PASSWORD=.*|ELASTIC_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^KOPIA_PASSWORD=.*|KOPIA_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^KOPIA_SERVER_PASSWORD=.*|KOPIA_SERVER_PASSWORD=$(openssl rand -base64 32)|" .env
sed -i "s|^ARIA2_RPC_SECRET=.*|ARIA2_RPC_SECRET=$(openssl rand -hex 32)|" .env
sed -i "s|^SLSKD_PASSWORD=.*|SLSKD_PASSWORD=$(openssl rand -base64 16)|" .env
sed -i "s|^COUCHDB_PASSWORD=.*|COUCHDB_PASSWORD=$(openssl rand -base64 32)|" .env

# Set VPN to empty for now (user can configure later)
sed -i "s|^VPN_USER=.*|VPN_USER=|" .env
sed -i "s|^VPN_PASSWORD=.*|VPN_PASSWORD=|" .env
sed -i "s|^TAILSCALE_AUTHKEY=.*|TAILSCALE_AUTHKEY=|" .env

echo "✓ Passwords generated and updated in .env"
