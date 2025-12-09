#!/usr/bin/env bash
set -euo pipefail

# This script runs only on first init of the Postgres data directory.
# It creates application users and databases for Gitea and Immich.

echo "[init] Creating application roles and databases (gitea, immich)"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
DO

$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gitea') THEN
    CREATE ROLE gitea LOGIN PASSWORD '${GITEA_DB_PASSWORD}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gitea') THEN
    CREATE DATABASE gitea OWNER gitea;
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'immich') THEN
    CREATE ROLE immich LOGIN PASSWORD '${IMMICH_DB_PASSWORD}';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'immich') THEN
    CREATE DATABASE immich OWNER immich;
  END IF;
END
$$;
EOSQL

echo "[init] Completed app DB creation"

# Ensure pgvecto-rs extension exists for Immich
echo "[init] Ensuring pgvecto-rs extension in 'immich'"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "immich" -c "CREATE EXTENSION IF NOT EXISTS vectors;"

