-- PostgreSQL initialization script for PotatoStack Light
-- Creates databases and users for Immich and Seafile

-- Create Immich user
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'immich') THEN
    EXECUTE format('CREATE ROLE immich LOGIN PASSWORD %L', current_setting('IMMICH_DB_PASSWORD', true));
  END IF;
END
$$;

-- Create Immich database
SELECT 'CREATE DATABASE immich OWNER immich'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'immich')\gexec

-- Create Seafile user
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'seafile') THEN
    EXECUTE format('CREATE ROLE seafile LOGIN PASSWORD %L', current_setting('SEAFILE_DB_PASSWORD', true));
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
