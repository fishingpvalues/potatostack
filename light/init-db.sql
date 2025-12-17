-- PostgreSQL initialization script for PotatoStack Light
-- Creates databases and users for Immich and Seafile
-- Environment variables IMMICH_DB_PASSWORD and SEAFILE_DB_PASSWORD must be set

-- Create Immich user
DO $$
DECLARE
    immich_password text := nullif(current_setting('IMMICH_DB_PASSWORD', true), '');
BEGIN
  IF immich_password IS NULL THEN
    RAISE EXCEPTION 'IMMICH_DB_PASSWORD environment variable is not set';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'immich') THEN
    EXECUTE format('CREATE ROLE immich LOGIN PASSWORD %L', immich_password);
  END IF;
END
$$;

-- Create Immich database
SELECT 'CREATE DATABASE immich OWNER immich'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'immich')\gexec

-- Create Seafile user
DO $$
DECLARE
    seafile_password text := nullif(current_setting('SEAFILE_DB_PASSWORD', true), '');
BEGIN
  IF seafile_password IS NULL THEN
    RAISE EXCEPTION 'SEAFILE_DB_PASSWORD environment variable is not set';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'seafile') THEN
    EXECUTE format('CREATE ROLE seafile LOGIN PASSWORD %L', seafile_password);
  END IF;
END
$$;

-- Create Seafile databases (Seafile needs 3 databases)
SELECT 'CREATE DATABASE ccnet_db OWNER seafile'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ccnet_db')\gexec

SELECT 'CREATE DATABASE seafile_db OWNER seafile'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'seafile_db')\gexec

SELECT 'CREATE DATABASE seahub_db OWNER seafile'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'seahub_db')\gexec

-- Enable pgvecto.rs extension for Immich (vector search for photos)
\connect immich;
CREATE EXTENSION IF NOT EXISTS vectors;
