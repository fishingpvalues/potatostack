.PHONY: help env setup pull up down restart ps logs validate health vpn-test backup-verify check conftest systemd install all fmt

.DEFAULT_GOAL := help

## Detect docker compose binary or plugin
DC := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

help:
	@echo "PotatoStack targets:"
	@echo "  Setup:    make env | make install | make systemd"
	@echo "  Runtime:  make up | make down | make restart | make ps | make logs"
	@echo "  Quality:  make validate | make conftest | make check | make health | make vpn-test | make backup-verify | make fmt"
	@echo "  Profiles: make up-cache   (Redis for Nextcloud)"

env:
	@test -f .env || cp .env.example .env
	@echo ".env ready. Edit as needed."

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

vpn-test:
	@./scripts/verify-vpn-killswitch.sh

backup-verify:
	@./scripts/verify-kopia-backups.sh

check:
	@pre-commit run --all-files

fmt:
	@markdownlint **/*.md || true
	@yamllint -c .yamllint.yaml **/*.yml **/*.yaml || true

conftest:
	@conftest test -p policy docker-compose.yml

systemd:
	@cd systemd && sudo ./install-systemd-services.sh

install: env setup up systemd
	@echo "Install complete. Access Homepage or services per README."

all: install
	@true
