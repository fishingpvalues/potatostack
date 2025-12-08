# POTATOSTACK - Optimized for Le Potato (2GB RAM)

## Summary of Changes

### Database Consolidation
✅ **Redis**: Consolidated 3 instances → 1 shared instance (saves ~256MB)
- DB 0: Nextcloud & Gitea
- DB 1: Firefly III
- DB 2: Immich

✅ **MariaDB**: Consolidated 2 instances → 1 shared instance (saves ~256MB)
- `nextcloud` database
- `firefly` database

✅ **PostgreSQL**: Kept separate (2 instances)
- Gitea (standard PostgreSQL)
- Immich (requires pgvecto-rs extension)

**Total Memory Saved**: ~512MB

### Resource Optimization
- Reduced memory limits across ALL services by ~40-60%
- Added Docker Compose profiles for optional services:
  - `apps`: Vaultwarden password manager
  - `monitoring-extra`: Netdata, Uptime Kuma, Speedtest, Fritzbox, Blackbox
  - `heavy`: Immich, Firefly III, Authelia (NOT recommended for 2GB)

### New Grafana Dashboards
✅ Speedtest Exporter - Internet speed monitoring
✅ Fritzbox Exporter - Router & DSL health monitoring

## Deployment Profiles

### Default (Core Services) - ~1.6GB RAM
```bash
docker compose up -d
```
Includes: VPN, P2P, Nextcloud, Gitea, Kopia, Prometheus/Grafana, Management tools

### With Password Manager - ~1.7GB RAM
```bash
docker compose --profile apps up -d
```
Adds: Vaultwarden

### With Extended Monitoring - ~2GB RAM
```bash
docker compose --profile apps --profile monitoring-extra up -d
```
Adds: All monitoring exporters

## Migration Guide

1. **Backup Everything**
   ```bash
   docker compose exec mariadb mysqldump -u root -p --all-databases > backup_mariadb.sql
   docker compose exec gitea-db pg_dumpall -U gitea > backup_postgres.sql
   ```

2. **Stop Services**
   ```bash
   docker compose down
   ```

3. **Update Environment Variables**
   - Set `MARIADB_ROOT_PASSWORD` (replaces individual DB passwords)
   - Update `.env` with new consolidated database credentials

4. **Start with Default Profile**
   ```bash
   docker compose up -d
   ```

5. **Verify**
   ```bash
   docker stats  # Check memory usage
   docker compose ps  # Verify all services are healthy
   ```

## Prometheus Targets Updated
- Removed old separate database targets
- Updated to consolidated `mariadb:3306` and shared `redis:6379`

## Database Init Script
Created: `config/mariadb/init/01-init-databases.sql`
- Auto-creates `nextcloud` and `firefly` databases on first run
- Sets up users with proper permissions

## Resource Summary

| Profile | Services | RAM Usage | Recommended |
|---------|----------|-----------|-------------|
| Default | Core only | ~1.6GB | ✅ Yes |
| + apps | + Vaultwarden | ~1.7GB | ✅ Yes |
| + monitoring-extra | + All exporters | ~2GB | ⚠️ Tight fit |
| + heavy | + Immich/Firefly | ~3GB+ | ❌ Needs 4GB+ |

## Next Steps

1. Test with default profile first
2. Monitor with `docker stats` for 24h
3. Enable additional profiles if you have headroom
4. Configure Grafana dashboards (now includes Speedtest & Fritzbox)

