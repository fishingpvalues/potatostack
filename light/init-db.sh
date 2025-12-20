#!/bin/bash
# PostgreSQL initialization script for PotatoStack Light
# Creates databases and users for Immich and Seafile
set -e

# Validate environment variables
if [ -z "$IMMICH_DB_PASSWORD" ]; then
  echo "Error: IMMICH_DB_PASSWORD environment variable is not set"
  exit 1
fi

if [ -z "$SEAFILE_DB_PASSWORD" ]; then
  echo "Error: SEAFILE_DB_PASSWORD environment variable is not set"
  exit 1
fi

# Create Immich user and database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'immich') THEN
      CREATE ROLE immich LOGIN PASSWORD '$IMMICH_DB_PASSWORD';
    END IF;
  END
  \$\$;

  SELECT 'CREATE DATABASE immich OWNER immich'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'immich')\gexec

  \c immich
  CREATE EXTENSION IF NOT EXISTS vectors;
  CREATE EXTENSION IF NOT EXISTS cube;
  CREATE EXTENSION IF NOT EXISTS earthdistance;
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  GRANT USAGE ON SCHEMA vectors TO immich;
  GRANT ALL ON ALL TABLES IN SCHEMA vectors TO immich;
  GRANT ALL ON ALL SEQUENCES IN SCHEMA vectors TO immich;
  GRANT ALL ON ALL FUNCTIONS IN SCHEMA vectors TO immich;
  ALTER DATABASE immich OWNER TO immich;
  ALTER SCHEMA public OWNER TO immich;
EOSQL

# Create Seafile user and databases (Seafile requires 3 databases)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'seafile') THEN
      CREATE ROLE seafile LOGIN PASSWORD '$SEAFILE_DB_PASSWORD';
    END IF;
  END
  \$\$;

  SELECT 'CREATE DATABASE ccnet_db OWNER seafile'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ccnet_db')\gexec

  SELECT 'CREATE DATABASE seafile_db OWNER seafile'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'seafile_db')\gexec

  SELECT 'CREATE DATABASE seahub_db OWNER seafile'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'seahub_db')\gexec
EOSQL

echo "Database initialization completed successfully"
