# Repository Guidelines

## Build, Test, and Development Commands
- Make targets: `make install|up|logs|health|vpn-test|backup-verify|conftest|check|fmt`
- Single test: `make health` (system), `make vpn-test` (VPN), `make backup-verify` (backups)
- Lint/format: `make check` (pre-commit), `make fmt` (yamllint/markdownlint), `make validate` (compose)
- Run stack: `make up` or `docker-compose up -d`; inspect with `make ps` and `make logs`

## Code Style Guidelines
- EditorConfig: LF, UTF-8, final newline, trim whitespace. 2-space indent (4 for *.sh, *.py)
- Shell: `#!/bin/bash`, `set -euo pipefail`, lowercase-hyphen filenames, shellcheck clean
- YAML: 2-space indent, lowercase service names, always set `mem_limit`, `cpus`, `mem_reservation`
- Python: Black formatting, Ruff linting, type hints (mypy enabled)
- Images: pinned tags over `latest` (e.g., `grafana/grafana:10.4.x`), use digests in production
- Error handling: prefer operational checks over unit tests; validate with `scripts/health-check.sh`

## Security & Architecture
- P2P services: `network_mode: service:surfshark` with health dependency
- Writable mounts: under `/mnt/` only (protect SD card)
- Policy compliance: respect `policy/docker-compose.rego` rules
- No secrets in repo; never commit `.env`
