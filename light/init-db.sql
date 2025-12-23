-- PostgreSQL initialization script for PotatoStack Light
-- Creates databases and users for Immich
-- Environment variable IMMICH_DB_PASSWORD must be set

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

-- Enable pgvecto.rs extension for Immich (vector search for photos)
\connect immich;
CREATE EXTENSION IF NOT EXISTS vectors;
