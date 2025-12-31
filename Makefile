.PHONY: help up down restart logs test test-quick clean status ps

# Detect OS and set appropriate docker command
ifeq ($(shell test -d /data/data/com.termux && echo yes),yes)
    DOCKER_COMPOSE=proot-distro login debian --shared-tmp -- docker-compose
    DOCKER_CMD=proot-distro login debian --shared-tmp -- docker
else
    DOCKER_COMPOSE=$(shell command -v docker-compose 2>/dev/null || echo "docker compose")
    DOCKER_CMD=docker
endif

help: ## Show this help message
	@echo "PotatoStack Makefile"
	@echo "===================="
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

test: ## Run comprehensive integration tests
	@echo "Running comprehensive stack tests..."
	@chmod +x ./stack-test.sh
	@./stack-test.sh

test-quick: ## Run quick health check (no log analysis)
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

validate: ## Validate docker-compose.yml syntax
	$(DOCKER_COMPOSE) config

health: ## Check health of all services
	@echo "Service Health Status:"
	@$(DOCKER_CMD) ps --format "{{.Names}}" | while read container; do \
		health=$$($(DOCKER_CMD) inspect --format='{{.State.Health.Status}}' $$container 2>/dev/null || echo "no-healthcheck"); \
		status=$$($(DOCKER_CMD) inspect --format='{{.State.Status}}' $$container 2>/dev/null || echo "unknown"); \
		printf "%-30s Status: %-10s Health: %s\n" "$$container" "$$status" "$$health"; \
	done
