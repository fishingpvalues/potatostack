# Contributing to PotatoStack

Thanks for your interest in improving PotatoStack. This guide summarizes how to develop, validate, and submit changes in a clean, repeatable way.

## Workflow
- Fork and create a feature branch from `main`.
- Keep changes focused and small; separate unrelated changes.
- Prefer Conventional Commits for messages and PR titles:
  - `feat(qbittorrent): add mem_reservation`
  - `fix(nextcloud): reduce db memory footprint`
  - `docs(readme): add usb2 tuning`
- Open a PR with:
  - Clear summary and rationale
  - Validation steps (commands run, screenshots/logs if UI changes)
  - Linked issues (if any)

## Development
- Prereqs: Docker, Docker Compose, pre-commit.
- Setup/Run:
  - `make env && sudo make install`
  - `make up` then `make logs` / `make ps`
- Validate:
  - `make validate && make conftest` (compose + OPA)
  - `make check` (pre-commit: formatting/lint/security)
  - `make health && make vpn-test && make backup-verify`

## Coding & Config Style
- YAML: 2 spaces; lowercase service names; set `mem_limit`, `cpus`, `mem_reservation`.
- Shell: `#!/bin/bash`, `set -euo pipefail`, pass shellcheck.
- Images: pin tags in `.env` (avoid `latest` in production).
- Ports: bind via `HOST_BIND` and URLs via `HOST_ADDR` variables.

## Testing changes
- Prefer operational checks (compose up + health scripts).
- When adding services, include labels for Homepage and update Prometheus/Loki if metrics/logs needed.

## Security
- Do not commit secrets; `.env` is ignored.
- Keep Docker socket mounts read-only; do not broaden caps/devices without justification.

## Release hygiene
- Keep PRs green in CI (lint, OPA, compose validation, scans).
- Update docs/STACK_OVERVIEW.md or README when changing user-facing behavior.
