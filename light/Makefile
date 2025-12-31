.PHONY: help up down restart logs test test-quick clean status ps lint format validate resources

# Detect OS and set appropriate docker command
ifeq ($(shell test -d /data/data/com.termux && echo yes),yes)
    DOCKER_COMPOSE=proot-distro login debian --shared-tmp -- docker-compose -f /data/data/com.termux/files/home/workdir/potatostack/light/docker-compose.yml
    DOCKER_CMD=proot-distro login debian --shared-tmp -- docker
else
    DOCKER_COMPOSE=$(shell command -v docker-compose 2>/dev/null || echo "docker compose")
    DOCKER_CMD=docker
endif

help: ## Show this help message
	@echo "PotatoStack Light Makefile (2GB RAM)"
	@echo "====================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start all services
	$(DOCKER_COMPOSE) up -d

down: ## Stop all services
	$(DOCKER_COMPOSE) down

restart: ## Restart all services
	$(DOCKER_COMPOSE) restart

logs: ## View logs (use SERVICE=name for specific service)
ifdef SERVICE
	$(DOCKER_COMPOSE) logs -f $(SERVICE)
else
	$(DOCKER_COMPOSE) logs -f
endif

ps: ## List running containers
	$(DOCKER_CMD) ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

status: ## Show container status with health
	$(DOCKER_CMD) ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}"

test: ## Run comprehensive integration tests (SOTA 2025)
	@echo "Running comprehensive light stack tests..."
	@chmod +x ./stack-test-light.sh
	@./stack-test-light.sh

test-quick: ## Run quick health check
	@echo "Quick health check..."
	@$(DOCKER_CMD) ps
	@echo ""
	@echo "Checking for unhealthy containers..."
	@$(DOCKER_CMD) ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"

clean: ## Remove all containers, volumes, and networks (DANGEROUS)
	@echo "WARNING: This will remove all data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DOCKER_COMPOSE) down -v; \
	fi

pull: ## Pull latest images
	$(DOCKER_COMPOSE) pull

validate: ## Validate docker-compose.yml syntax (basic)
	@$(DOCKER_COMPOSE) config > /dev/null

lint: ## Run SOTA 2025 comprehensive validation (YAML, shell, compose)
	@echo "Running SOTA 2025 validation suite for light stack..."
	@chmod +x ./validate-stack.sh
	@./validate-stack.sh

format: ## Format shell scripts and YAML files (SOTA 2025)
	@echo "Formatting files with SOTA 2025 tools..."
	@echo "1. Formatting shell scripts with shfmt..."
	@if command -v shfmt &> /dev/null; then \
		shfmt -w *.sh 2>/dev/null || true; \
		echo "  ✓ Shell scripts formatted"; \
	else \
		echo "  ✗ shfmt not installed (install: pkg install shfmt)"; \
	fi
	@echo "2. Formatting YAML files with prettier..."
	@if command -v prettier &> /dev/null; then \
		prettier --write *.yml *.yaml .*.yaml 2>/dev/null || true; \
		echo "  ✓ YAML files formatted with prettier"; \
	elif command -v yq &> /dev/null; then \
		find . -maxdepth 1 -name "*.yml" -o -name "*.yaml" | while read f; do yq eval -i '.' "$$f" 2>/dev/null || true; done; \
		echo "  ✓ YAML files formatted with yq"; \
	else \
		echo "  ⚠ No YAML formatter installed (install: npm install -g prettier OR pkg install yq)"; \
	fi
	@echo "✓ Formatting complete"

health: ## Check health of all services
	@echo "Service Health Status:"
	@$(DOCKER_CMD) ps --format "{{.Names}}" | while read container; do \
		health=$$($(DOCKER_CMD) inspect --format='{{.State.Health.Status}}' $$container 2>/dev/null || echo "no-healthcheck"); \
		status=$$($(DOCKER_CMD) inspect --format='{{.State.Status}}' $$container 2>/dev/null || echo "unknown"); \
		printf "%-30s Status: %-10s Health: %s\n" "$$container" "$$status" "$$health"; \
	done

resources: ## Check resource usage (2GB RAM monitoring)
	@echo "Resource Usage (2GB RAM limit):"
	@$(DOCKER_CMD) stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
