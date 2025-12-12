.PHONY: help env setup preflight pull up down restart ps logs validate health health-quick health-security vpn-test backup-verify conftest secrets-init secrets-edit secrets-list

.DEFAULT_GOAL := help

## Detect docker compose binary or plugin
DC := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

help:
	@echo "PotatoStack Makefile Targets"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make env              Create .env from .env.example"
	@echo "  make preflight        Run pre-flight system checks"
	@echo "  make setup            Run full system setup (requires sudo)"
	@echo ""
	@echo "Docker Runtime:"
	@echo "  make up               Start all Docker services"
	@echo "  make down             Stop all Docker services"
	@echo "  make restart          Restart all Docker services"
	@echo "  make ps               List running containers"
	@echo "  make logs             Follow container logs"
	@echo "  make pull             Pull latest Docker images"
	@echo ""
	@echo "Health & Monitoring:"
	@echo "  make health           Full system health check"
	@echo "  make health-quick     Quick status check"
	@echo "  make health-security  Security audit"
	@echo "  make vpn-test         Verify VPN kill switch"
	@echo "  make backup-verify    Verify Kopia backups"
	@echo ""
	@echo "Secrets Management:"
	@echo "  make secrets-init     Initialize secrets store"
	@echo "  make secrets-edit     Edit encrypted secrets"
	@echo "  make secrets-list     List all encrypted secrets"
	@echo ""
	@echo "Code Quality:"
	@echo "  make validate         Validate docker-compose.yml"
	@echo "  make conftest         Run OPA policy tests"
	@echo ""
	@echo "Profiles:"
	@echo "  make up-cache         Start with Redis cache profile"

env:
	@test -f .env || cp .env.example .env
	@echo ".env ready. Edit as needed."

preflight:
	@sudo ./setup.sh --preflight

setup:
	@sudo ./setup.sh --non-interactive

pull:
	@$(DC) pull

up:
	@$(DC) up -d

up-cache:
	@COMPOSE_PROFILES=cache $(DC) up -d



down:
	@$(DC) down

restart:
	@$(DC) restart

ps:
	@$(DC) ps

logs:
	@$(DC) logs -f

validate:
	@$(DC) -f docker-compose.yml config -q

health:
	@./scripts/health-check.sh

health-quick:
	@./scripts/health-check.sh --quick

health-security:
	@./scripts/health-check.sh --security

vpn-test:
	@./scripts/verify-vpn-killswitch.sh

backup-verify:
	@./scripts/verify-kopia-backups.sh

secrets-init:
	@./scripts/secrets.sh init

secrets-edit:
	@./scripts/secrets.sh edit

secrets-list:
	@./scripts/secrets.sh list

conftest:
	@conftest test -p policy docker-compose.yml
