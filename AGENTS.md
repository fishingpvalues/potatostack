# Repository Guidelines

## Project Structure & Module Organization
- Root: `docker-compose.yml`, `.env.example`, `README.md`.
- Config: `config/` (Prometheus, Grafana, Loki, Alertmanager, Homepage).
- Scripts: `scripts/` (e.g., `health-check.sh`, `verify-vpn-killswitch.sh`, `verify-kopia-backups.sh`, `run_checks.sh`).
- Systemd helpers: `systemd/`.
- Policy: `policy/docker-compose.rego` (security/resource rules).
- Docs: `docs/` (deployment, security, quickstart).
- Data disks: `/mnt/seconddrive` (14TB, persistent data), `/mnt/cachehdd` (500GB, high‑IO cache).

## Build, Test, and Development Commands
- Make targets (preferred): `make install`, `make up`, `make logs`, `make health`, `make vpn-test`, `make backup-verify`, `make conftest`.
- Profiles: `make up-cache` (Redis for Nextcloud).
- Bootstrap: `sudo ./setup.sh` (use `--non-interactive` for unattended install).
- Run stack: `docker-compose up -d` (or `docker compose up -d`); inspect with `docker-compose ps` and `docker-compose logs -f`.
- Health checks: `./scripts/health-check.sh` (system + services), `./scripts/verify-vpn-killswitch.sh`, `./scripts/verify-kopia-backups.sh`.
- Lint/format: `pre-commit install` then `./scripts/run_checks.sh` or `pre-commit run --all-files`.
- Validate compose: `docker-compose config -q`.
- Deploy remote: `./deploy.sh --server <host> [--user <user>] staging|production [--dry-run]`.

## Coding Style & Naming Conventions
- EditorConfig: LF, UTF-8, final newline, trim whitespace. Indent 2 spaces project-wide; `*.sh` and `*.py` use 4 spaces.
- Shell: `#!/bin/bash`, `set -euo pipefail`, lowercase-hyphen filenames under `scripts/`, keep `shellcheck` clean.
- YAML: 2-space indent; lowercase service names; always set `mem_limit`, `cpus`, and `mem_reservation` for services.
- Images: prefer pinned tags over `latest` (e.g., `grafana/grafana:10.4.x`). Use digests in production.
- Ports: use `HOST_BIND` and `HOST_ADDR` from `.env` (already wired in compose) rather than hardcoding IPs in labels/ports.
 - Profiles: optional `cache` (Redis) and `longterm-metrics` (Thanos). Keep defaults lean for Le Potato.
- Python (if added): format with Black; lint/fix with Ruff; add type hints (mypy enabled via pre-commit).

## Testing Guidelines
- Prefer operational checks over unit tests: run `scripts/health-check.sh` locally after changes.
- VPN/P2P: ensure qBittorrent and slskd remain behind Surfshark via `scripts/verify-vpn-killswitch.sh`.
- Backups: verify with `scripts/verify-kopia-backups.sh` (optional restore prompt).
- When changing `docker-compose.yml`, respect `policy/docker-compose.rego` rules (VPN dependency, resource limits, no excessive privileges). Document any port exposure on LAN vs WAN.

## Commit & Pull Request Guidelines
- Use clear, imperative messages (prefer Conventional Commits). Examples:
  - `feat(qbittorrent): add mem_limit and reservation`
  - `fix(deploy): handle missing docker-compose plugin`
  - `docs: update service ports table`
- PRs should include: summary, services/files touched, manual validation steps (commands run, key logs), and updates to `.env.example`, `docs/`, or dashboards when applicable.
- Avoid committing secrets; never add `.env`. Update `.gitignore` if new secret files appear.

## Security & Configuration Tips
- Keep all writable mounts under `/mnt/` to protect the SD card.
- P2P services must use `network_mode: service:surfshark` and depend on `surfshark` health.
- Do not broaden capabilities/devices without limits; follow Rego policy denials/warnings.
