# GEMINI.md - PotatoStack

## Project Overview

This project, "PotatoStack," is a comprehensive, self-hosted infrastructure stack designed for low-power hardware, such as an Intel N250 Mini PC with 16GB of RAM. It is built using Docker and Docker Compose, and it includes a wide array of over 100 services for various purposes, including:

*   **Core Infrastructure:** PostgreSQL, MongoDB, Redis, Traefik
*   **Security:** CrowdSec, Authentik, Vaultwarden, Fail2Ban
*   **Media Management:** Jellyfin, Sonarr, Radarr, and other *arr stack services
*   **Monitoring & Observability:** Prometheus, Grafana, Loki, Thanos
*   **Applications:** Nextcloud, Immich, Paperless-ngx, Gitea
*   **And many more utilities and services.**

The stack is highly optimized for resource efficiency, with a focus on database consolidation, smart storage strategies, and resource limits on all services. It is pre-configured with detailed settings, health checks, and a comprehensive monitoring setup.

## Building and Running

The primary way to interact with the PotatoStack is through the provided `Makefile`, which simplifies the use of `docker-compose`.

### Key Commands

*   `make help`: Show a list of all available commands.
*   `make up`: Start all services in the background.
*   `make down`: Stop all services.
*   `make restart`: Restart all services.
*   `make logs`: View the logs of all services.
    *   To view logs for a specific service: `make logs SERVICE=<service_name>`
*   `make ps`: List all running containers.
*   `make pull`: Pull the latest Docker images for all services.
*   `make test`: Run comprehensive integration tests for the stack.
*   `make clean`: **DANGEROUS** - Remove all containers, volumes, and networks. This will delete all your data.

All `make` commands are essentially wrappers around `docker-compose` commands. For more advanced use cases, you can use `docker-compose` directly.

## Development Conventions

The project has a strong focus on code quality and consistency, enforced by a suite of linting and formatting tools.

*   **Validation & Linting:** The `make lint` command runs a series of checks on the codebase:
    *   `dclint`: Lints the `docker-compose.yml` file.
    *   `yamllint`: Lints all YAML files.
    *   `shellcheck`: Lints all shell scripts.
    *   `hadolint`: Lints Dockerfiles.
*   **Formatting:** The `make format` command automatically formats the code:
    *   `shfmt`: Formats shell scripts.
    *   `prettier` or `yq`: Formats YAML files.
    *   `dockfmt`: Formats Dockerfiles.

The CI/CD pipeline likely enforces these checks, so it's recommended to run `make verify` before committing any changes.

## Key Files

*   `docker-compose.yml`: This is the heart of the project. It defines all the services, networks, volumes, and configurations for the entire stack. It is extensively documented with comments and labels.
*   `docs/README.md`: The main documentation file for the project. It provides a high-level overview, quick stats, core components, setup instructions, and architecture highlights. It is the best place to start to understand the project.
*   `Makefile`: This file provides a convenient way to manage the stack with simple commands. It abstracts away the complexity of the underlying `docker-compose` commands.
*   `.env.example`: An example environment file. You should copy this to `.env` and customize it with your own settings.

## Usage

This is a pre-configured, self-hosted infrastructure stack. The primary usage is to deploy and manage a wide range of services on a single machine. The intended workflow is:

1.  Copy `.env.example` to `.env` and fill in the required values.
2.  Use `make up` to start the entire stack.
3.  Use the various services through their web interfaces, which are exposed via the Traefik reverse proxy.
4.  Use `make logs`, `make ps`, and the Grafana dashboards to monitor the health and status of the services.
5.  Use `make down` to stop the stack.
