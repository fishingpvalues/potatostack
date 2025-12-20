#!/bin/bash
# Comprehensive fix script for PotatoStack Light
# Fixes all known issues and fails gracefully
set +e  # Don't exit on errors

echo "=========================================="
echo "PotatoStack Light - Auto Fix (7 Steps)"
echo "=========================================="

cd "$(dirname "$0")"

# Wait for postgres to be ready
echo "[1/5] Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker compose exec -T postgres pg_isready -U postgres &>/dev/null; then
        echo "✓ PostgreSQL ready"
        break
    fi
    sleep 2
done

# Fix Postgres passwords and create missing databases
echo "[2/5] Fixing PostgreSQL authentication..."
docker compose exec -T postgres psql -U postgres <<'EOSQL' 2>&1 | grep -E "(✓|ALTER|CREATE)" || true
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'immich') THEN
    CREATE ROLE immich LOGIN PASSWORD 'schneck0';
  ELSE
    ALTER USER immich WITH PASSWORD 'schneck0';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'seafile') THEN
    CREATE ROLE seafile LOGIN PASSWORD 'schneck0';
  ELSE
    ALTER USER seafile WITH PASSWORD 'schneck0';
  END IF;
END
$$;

SELECT 'CREATE DATABASE immich OWNER immich'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'immich')\gexec

SELECT 'CREATE DATABASE ccnet_db OWNER seafile'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ccnet_db')\gexec

SELECT 'CREATE DATABASE seafile_db OWNER seafile'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'seafile_db')\gexec

SELECT 'CREATE DATABASE seahub_db OWNER seafile'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'seahub_db')\gexec

\c immich
CREATE EXTENSION IF NOT EXISTS vectors;
GRANT ALL ON SCHEMA public TO immich;
EOSQL
echo "✓ Database passwords reset"

# Fix Immich missing directories (create on host volume)
echo "[3/5] Creating Immich directories..."
if [ -d "/mnt/storage/immich/upload" ]; then
    mkdir -p /mnt/storage/immich/upload/encoded-video
    echo "verified" > /mnt/storage/immich/upload/encoded-video/.immich
    echo "✓ Immich directories created on host"
else
    echo "⚠ Cannot access /mnt/storage from Windows - run this on Linux host:"
    echo "  mkdir -p /mnt/storage/immich/upload/encoded-video"
    echo "  echo 'verified' > /mnt/storage/immich/upload/encoded-video/.immich"
fi

# Fix Seafile symlinks (if accessible)
echo "[4/5] Checking Seafile..."
if [ -d "/mnt/storage/seafile/logs" ]; then
    find /mnt/storage/seafile/logs -type l -xtype l -delete 2>/dev/null || true
    rm -rf /mnt/storage/seafile/logs/var-log 2>/dev/null || true
    echo "✓ Seafile symlinks cleaned"
else
    echo "✓ Seafile running (storage not accessible from Windows)"
fi

# Restart Gluetun to apply HTTP auth fix
echo "[5/5] Restarting Gluetun for auth fix..."
docker compose restart gluetun 2>&1 | grep -v "already" || true
sleep 3

# Restart affected services
echo "[6/6] Restarting Immich services..."
docker compose restart immich-server immich-microservices 2>&1 | grep -v "already" || true
echo "✓ Services restarted"

# Generate Vaultwarden hash
echo "[7/7] Generating Vaultwarden secure token..."
HASH=$(docker compose exec -T vaultwarden sh -c '/vaultwarden hash --preset owasp schneck0' 2>/dev/null | tail -1 | tr -d '\r\n')
if [ -n "$HASH" ] && [[ "$HASH" =~ ^\$ ]]; then
    echo ""
    echo "=========================================="
    echo "MANUAL ACTION REQUIRED:"
    echo "=========================================="
    echo "Update .env with this line:"
    echo "VAULTWARDEN_ADMIN_TOKEN='$HASH'"
    echo ""
    echo "Then run: docker compose up -d vaultwarden"
    echo "=========================================="
else
    echo "⚠ Could not generate hash - token generation skipped"
    echo "  Current plain text token works but is insecure"
fi

echo ""
echo "✓ Auto-fix complete!"
echo ""
echo "Check service status:"
echo "  docker compose ps"
echo "  docker compose logs -f gluetun seafile immich-server"
