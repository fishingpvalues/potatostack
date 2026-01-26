.PHONY: help up down restart logs test test-quick clean ps services images config containers \
	containers-check containers-unhealthy containers-exited pull verify validate validate-compose validate-files \
	lint lint-compose lint-yaml lint-shell lint-dockerfiles lint-full format format-shell format-yaml \
	format-dockerfiles security health resources doctor fix init fix-permissions fix-configs startup \
	fix-docker harden recovery \
	firewall firewall-status firewall-install firewall-apply firewall-list firewall-reset firewall-allow firewall-deny \
	tailscale-https tailscale-https-setup tailscale-https-monitor

# Detect OS and set appropriate docker command
ifeq ($(shell test -d /data/data/com.termux && echo yes),yes)
    DOCKER_COMPOSE=proot-distro login debian --shared-tmp -- docker-compose -f /data/data/com.termux/files/home/workdir/potatostack/docker-compose.yml
    DOCKER_CMD=proot-distro login debian --shared-tmp -- docker
else
    DOCKER_COMPOSE=$(shell command -v docker-compose 2>/dev/null || echo "docker compose")
    DOCKER_CMD=docker
endif

COMPOSE_FILE=docker-compose.yml
YAML_FILES=$(shell find . -type f \( -name '*.yml' -o -name '*.yaml' \) -not -path './data/*' -not -path './deprecated/*' -not -path './.git/*')
SHELL_FILES=$(shell find scripts -type f -name '*.sh' 2>/dev/null)
DOCKERFILES=$(shell find . -type f -name 'Dockerfile*' -not -path './data/*' -not -path './deprecated/*' -not -path './.git/*' 2>/dev/null)
YAMLLINT_CONFIG=$(if $(wildcard .yamllint),-c .yamllint,)

help: ## Show this help message
	@echo "PotatoStack Makefile"
	@echo "===================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start all services (init containers always re-run)
	@echo "Running init containers..."
	@$(DOCKER_COMPOSE) rm -f storage-init tailscale-https-setup 2>/dev/null || true
	$(DOCKER_COMPOSE) up -d

init: ## Run init containers only (storage-init, tailscale-https-setup)
	@echo "Running init containers..."
	@$(DOCKER_COMPOSE) rm -f storage-init tailscale-https-setup 2>/dev/null || true
	$(DOCKER_COMPOSE) up -d storage-init tailscale-https-setup
	@echo "Waiting for init containers to complete..."
	@$(DOCKER_COMPOSE) logs -f storage-init 2>/dev/null || true

down: ## Stop all services
	$(DOCKER_COMPOSE) down

restart: ## Restart all services (init containers always re-run)
	@echo "Restarting stack with init containers..."
	@$(DOCKER_COMPOSE) rm -f storage-init tailscale-https-setup 2>/dev/null || true
	$(DOCKER_COMPOSE) up -d --force-recreate storage-init
	$(DOCKER_COMPOSE) restart

logs: ## View logs (use SERVICE=name for specific service)
ifdef SERVICE
	$(DOCKER_COMPOSE) logs -f $(SERVICE)
else
	$(DOCKER_COMPOSE) logs -f
endif

ps: ## List running containers
	$(DOCKER_CMD) ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

services: ## List services defined in docker-compose.yml
	$(DOCKER_COMPOSE) config --services

images: ## List images defined in docker-compose.yml
	$(DOCKER_COMPOSE) config --images

config: ## Render the full docker-compose config
	$(DOCKER_COMPOSE) config

containers: ## Show stack containers
	$(DOCKER_COMPOSE) ps

containers-unhealthy: ## List unhealthy containers
	@$(DOCKER_CMD) ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}" || true

containers-exited: ## List exited containers
	@$(DOCKER_CMD) ps --filter "status=exited" --format "table {{.Names}}\t{{.Status}}" || true

containers-check: ## Fail if containers are unhealthy or exited
	@unhealthy=$$($(DOCKER_CMD) ps --filter "health=unhealthy" --format "{{.Names}}"); \
	exited=$$($(DOCKER_CMD) ps --filter "status=exited" --format "{{.Names}}"); \
	if [ -n "$$unhealthy" ] || [ -n "$$exited" ]; then \
		echo "Unhealthy containers: $$unhealthy"; \
		echo "Exited containers: $$exited"; \
		exit 1; \
	fi; \
	echo "All containers healthy (no unhealthy/exited containers detected)."

doctor: ## Show tool availability and versions
	@echo "Tooling status:"
	@if command -v docker >/dev/null 2>&1; then \
		docker --version; \
	else \
		echo "  WARN: docker missing"; \
	fi
	@if command -v docker-compose >/dev/null 2>&1; then \
		printf "docker-compose: "; docker-compose version 2>/dev/null | head -1; \
	elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
		printf "docker compose: "; docker compose version 2>/dev/null | head -1; \
	else \
		echo "  WARN: docker compose missing"; \
	fi
	@for tool in yamllint shellcheck shfmt prettier yq dclint trivy hadolint dockfmt; do \
		if command -v $$tool >/dev/null 2>&1; then \
			printf "%s: " "$$tool"; $$tool --version 2>/dev/null | head -1 || echo "unknown version"; \
		else \
			echo "  WARN: $$tool missing"; \
		fi; \
	done

test: ## Run comprehensive integration tests
	@echo "Running comprehensive stack tests..."
	@chmod +x ./scripts/test/stack-test.sh
	@./scripts/test/stack-test.sh

test-quick: ## Run quick health check (no log analysis)
	@echo "Quick health check..."
	@$(DOCKER_CMD) ps
	@echo ""
	@echo "Checking for unhealthy containers..."
	@$(DOCKER_CMD) ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"

clean: ## Remove all containers, volumes, and networks (DANGEROUS)
	@echo "WARNING: This will remove all data!"
	@printf "Are you sure? [y/N] "; \
	read -r reply; \
	echo; \
	case "$$reply" in \
		[Yy]*) $(DOCKER_COMPOSE) down -v ;; \
		*) echo "Aborted."; ;; \
	esac

pull: ## Pull latest images
	$(DOCKER_COMPOSE) pull

fix-permissions: ## Fix named volume permissions (run if services fail with permission errors)
	@echo "Fixing named volume permissions..."
	@chmod +x ./scripts/init/fix-volume-permissions.sh
	@./scripts/init/fix-volume-permissions.sh

fix-configs: ## Fix service configs (Loki, Homarr, Grafana, Thanos)
	@echo "Running service configuration fixes..."
	@chmod +x ./scripts/init/fix-service-configs.sh
	@./scripts/init/fix-service-configs.sh

fix-docker: ## Fix corrupted Docker storage after crash (WARNING: removes all images)
	@echo "Running Docker storage recovery..."
	@chmod +x ./scripts/setup/fix-docker-storage.sh
	@sudo ./scripts/setup/fix-docker-storage.sh

harden: ## Run enterprise hardening script (watchdog, auto-recovery, etc.)
	@echo "Running enterprise hardening..."
	@chmod +x ./scripts/setup/enterprise-hardening.sh
	@sudo ./scripts/setup/enterprise-hardening.sh

recovery: fix-docker ## Full recovery after crash (fix Docker + start stack)
	@echo "Recovery complete. Run 'make health' to verify."

startup: ## Full startup sequence (use after reboot/crash)
	@echo "Running full startup sequence..."
	@chmod +x ./scripts/init/startup.sh
	@./scripts/init/startup.sh

verify: validate lint ## Run validate + lint

validate: validate-compose validate-files ## Run validation checks

fix: format ## Format all supported files

validate-compose: ## Validate docker-compose.yml syntax
	@$(DOCKER_COMPOSE) config > /dev/null

validate-files: ## Validate required repo files exist
	@missing=0; \
	for file in "$(COMPOSE_FILE)" Makefile .gitignore docs/README.md .env.example; do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$file"; \
		else \
			echo "  ✗ $$file (missing)"; \
			missing=$$((missing + 1)); \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo "Missing required files: $$missing"; \
		exit 1; \
	fi

lint: lint-compose lint-yaml lint-shell lint-dockerfiles ## Run SOTA 2025 linting (compose, YAML, shell, Dockerfiles)

lint-full: ## Run the full validation suite with reporting
	@echo "Running full validation suite..."
	@chmod +x ./scripts/validate/validate-stack.sh
	@./scripts/validate/validate-stack.sh

lint-compose: ## Lint docker-compose.yml
	@echo "Linting $(COMPOSE_FILE)..."
	@$(DOCKER_COMPOSE) config > /dev/null
	@if command -v dclint >/dev/null 2>&1; then \
		dclint -c .dclintrc.yaml "$(COMPOSE_FILE)"; \
	else \
		echo "  ⚠ dclint not installed (optional)"; \
	fi

lint-yaml: ## Lint YAML files with yamllint
	@echo "Linting YAML files..."
	@if [ -n "$(YAML_FILES)" ]; then \
		if command -v yamllint >/dev/null 2>&1; then \
			yamllint $(YAMLLINT_CONFIG) $(YAML_FILES); \
		else \
			echo "  ⚠ yamllint not installed (optional)"; \
		fi; \
	else \
		echo "  ⚠ No YAML files found"; \
	fi

lint-shell: ## Lint shell scripts with shellcheck and shfmt
	@echo "Linting shell scripts..."
	@if [ -n "$(SHELL_FILES)" ]; then \
		if command -v shellcheck >/dev/null 2>&1; then \
			shellcheck $(SHELL_FILES); \
		else \
			echo "  ⚠ shellcheck not installed (optional)"; \
		fi; \
		if command -v shfmt >/dev/null 2>&1; then \
			shfmt -d $(SHELL_FILES); \
		else \
			echo "  ⚠ shfmt not installed (optional)"; \
		fi; \
	else \
		echo "  ⚠ No shell scripts found"; \
	fi

lint-dockerfiles: ## Lint Dockerfiles with hadolint (optional)
	@echo "Linting Dockerfiles..."
	@if [ -n "$(DOCKERFILES)" ]; then \
		if command -v hadolint >/dev/null 2>&1; then \
			hadolint $(DOCKERFILES); \
		else \
			echo "  ⚠ hadolint not installed (optional)"; \
		fi; \
	else \
		echo "  ⚠ No Dockerfiles found"; \
	fi

security: ## Run security vulnerability scan
	@echo "Running security scan..."
	@chmod +x ./scripts/security/security-scan.sh
	@./scripts/security/security-scan.sh

################################################################################
# Firewall Management (UFW + Docker Integration)
################################################################################

firewall: firewall-status ## Show firewall status (default)

firewall-status: ## Show UFW firewall status
	@echo "Checking UFW firewall status..."
	@if command -v ufw >/dev/null 2>&1; then \
		sudo ufw status verbose; \
		echo ""; \
		echo "Docker-specific rules:"; \
		sudo ufw-docker list 2>/dev/null || echo "  ufw-docker not installed or no rules"; \
	else \
		echo "  ⚠ UFW not installed. Run: make firewall-install"; \
	fi

firewall-install: ## Install and configure UFW with Docker integration
	@echo "Installing UFW with Docker integration..."
	@chmod +x ./scripts/setup/setup-ufw-rules.sh
	@sudo ./scripts/setup/setup-ufw-rules.sh install

firewall-apply: ## Apply PotatoStack firewall rules
	@echo "Applying PotatoStack firewall rules..."
	@chmod +x ./scripts/setup/setup-ufw-rules.sh
	@sudo ./scripts/setup/setup-ufw-rules.sh apply

firewall-list: ## List Docker container firewall rules
	@echo "Listing Docker container firewall rules..."
	@if command -v ufw-docker >/dev/null 2>&1; then \
		sudo ufw-docker list; \
	else \
		echo "  ⚠ ufw-docker not installed. Run: make firewall-install"; \
	fi

firewall-reset: ## Reset UFW and reapply rules (WARNING: removes all rules!)
	@echo "WARNING: This will reset all firewall rules!"
	@printf "Are you sure? [y/N] "; \
	read -r reply; \
	case "$$reply" in \
		[Yy]*) \
			chmod +x ./scripts/setup/setup-ufw-rules.sh; \
			sudo ./scripts/setup/setup-ufw-rules.sh reset; \
			;; \
		*) echo "Aborted."; ;; \
	esac

firewall-allow: ## Allow a Docker container port (interactive)
	@echo "Allow Docker container port through firewall..."
	@chmod +x ./scripts/setup/setup-ufw-rules.sh
	@sudo ./scripts/setup/setup-ufw-rules.sh allow

firewall-deny: ## Deny a Docker container port (interactive)
	@echo "Deny Docker container port through firewall..."
	@chmod +x ./scripts/setup/setup-ufw-rules.sh
	@sudo ./scripts/setup/setup-ufw-rules.sh deny

################################################################################

format: format-shell format-yaml format-dockerfiles ## Format shell scripts and YAML files (SOTA 2025)

format-shell: ## Format shell scripts with shfmt
	@echo "Formatting shell scripts..."
	@if [ -n "$(SHELL_FILES)" ]; then \
		if command -v shfmt >/dev/null 2>&1; then \
			shfmt -w $(SHELL_FILES); \
			echo "  ✓ Shell scripts formatted"; \
		else \
			echo "  ⚠ shfmt not installed (optional)"; \
		fi; \
	else \
		echo "  ⚠ No shell scripts found"; \
	fi

format-yaml: ## Format YAML files with prettier or yq
	@echo "Formatting YAML files..."
	@if [ -n "$(YAML_FILES)" ]; then \
		if command -v prettier >/dev/null 2>&1; then \
			prettier --write $(YAML_FILES); \
			echo "  ✓ YAML files formatted with prettier"; \
		elif command -v yq >/dev/null 2>&1; then \
			for f in $(YAML_FILES); do yq eval -i '.' "$$f"; done; \
			echo "  ✓ YAML files formatted with yq"; \
		else \
			echo "  ⚠ No YAML formatter installed (optional)"; \
		fi; \
	else \
		echo "  ⚠ No YAML files found"; \
	fi

format-dockerfiles: ## Format Dockerfiles with dockfmt (optional)
	@echo "Formatting Dockerfiles..."
	@if [ -n "$(DOCKERFILES)" ]; then \
		if command -v dockfmt >/dev/null 2>&1; then \
			dockfmt -w $(DOCKERFILES); \
			echo "  ✓ Dockerfiles formatted with dockfmt"; \
		else \
			echo "  ⚠ dockfmt not installed (optional)"; \
		fi; \
	else \
		echo "  ⚠ No Dockerfiles found"; \
	fi

health: ## Check health of all services
	@echo "Service Health Status:"
	@$(DOCKER_CMD) ps --format "{{.Names}}" | while read container; do \
		health=$$($(DOCKER_CMD) inspect --format='{{.State.Health.Status}}' $$container 2>/dev/null || echo "no-healthcheck"); \
		status=$$($(DOCKER_CMD) inspect --format='{{.State.Status}}' $$container 2>/dev/null || echo "unknown"); \
		printf "%-30s Status: %-10s Health: %s\n" "$$container" "$$status" "$$health"; \
	done

resources: ## Check resource usage
	@echo "Resource Usage:"
	@$(DOCKER_CMD) stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

tailscale-https: ## Setup Tailscale HTTPS on all configured ports
	@echo "Setting up Tailscale HTTPS on ports: $(TAILSCALE_SERVE_PORTS)..."
	@if [ -z "$(TAILSCALE_SERVE_PORTS)" ]; then \
		echo "❌ TAILSCALE_SERVE_PORTS not set in .env"; \
		echo "Add TAILSCALE_SERVE_PORTS to your .env file"; \
		exit 1; \
	fi
	@PORTS=$$(echo $(TAILSCALE_SERVE_PORTS) | tr ',' ' '); \
	for port in $$PORTS; do \
		if [ -n "$$port" ]; then \
			echo "→ Enabling HTTPS on port $$port"; \
			docker exec tailscale tailscale serve --bg --https $$port 127.0.0.1:$$port || true; \
		fi; \
	done; \
	echo "✓ Tailscale HTTPS configured for: $(TAILSCALE_SERVE_PORTS)"

tailscale-https-monitor: ## Start Tailscale HTTPS monitor (re-applies every 5 min)
	@echo "Starting Tailscale HTTPS monitor..."
	@docker run -d --name tailscale-https-monitor --restart unless-stopped \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--network none \
		alpine:3.21 sh -c "apk add --no-cache docker-cli >/dev/null 2>&1; while true; do sleep 300; \
		PORTS=\$$(echo $(TAILSCALE_SERVE_PORTS) | tr ',' ' '); \
		for port in \$\$PORTS; do \
			if [ -n \"\$\$port\" ]; then \
				docker exec tailscale tailscale serve --https \$\$port 127.0.0.1:\$\$port --bg || true; \
			fi; \
		done; \
		done"

