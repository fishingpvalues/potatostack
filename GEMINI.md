# GEMINI.md - PotatoStack v2.0

## Project Overview

This directory contains `PotatoStack v2.0`, a comprehensive and pre-configured Docker-based environment designed for the Le Potato (AML-S905X-CC) single-board computer. The stack is optimized for low-resource systems (2GB RAM) and provides a wide array of self-hosted services for media management, file storage, encrypted backups, and system monitoring.

The architecture is built around Docker and Docker Compose, with services isolated into logical networks (`vpn`, `monitoring`, `proxy`). Data persistence is handled by mounting volumes to two external hard drives: a main drive for long-term storage (`/mnt/seconddrive`) and a cache drive for high-I/O tasks like torrenting (`/mnt/cachehdd`).

### Key Technologies

*   **Containerization:** Docker & Docker Compose
*   **VPN & P2P:** Gluetun, qBittorrent, slskd
*   **Storage & Backup:** Nextcloud, Kopia
*   **Monitoring:** Prometheus, Grafana, Loki, Netdata, cAdvisor
*   **Management:** Portainer, Nginx Proxy Manager, Homepage, Diun
*   **CI/CD & Git:** Gitea

## Building and Running

The project is designed to be set up and run with minimal manual intervention.

### 1. Prerequisites

*   A Le Potato SBC (or similar ARM-based device).
*   Two external hard drives mounted at `/mnt/seconddrive` and `/mnt/cachehdd`.
*   Docker and Docker Compose installed.

### 2. Initial Setup

The primary setup is handled by the `setup.sh` script, which automates the following:
*   Dependency checks (Docker, Docker Compose).
*   Creation of the required directory structure on the external drives.
*   Generation of the `.env` file from `.env.example`.
*   Initialization of the Kopia backup repository.
*   Application of necessary system tweaks (e.g., `sysctl` settings).

To run the setup:
```bash
sudo ./setup.sh
```

### 3. Environment Configuration

All user-specific configurations (passwords, domain names, API keys) are managed in the `.env` file. After the initial setup, this file must be edited to replace placeholder values.

### 4. Running the Stack

The entire stack is managed via Docker Compose. The provided `Makefile` simplifies common commands:

*   **Start the stack:**
    ```bash
    make up
    # Equivalent to: docker-compose up -d
    ```

*   **Stop the stack:**
    ```bash
    make down
    # Equivalent to: docker-compose down
    ```

*   **View logs:**
    ```bash
    make logs
    # Equivalent to: docker-compose logs -f
    ```

*   **Pull the latest Docker images:**
    ```bash
    make pull
    # Equivalent to: docker-compose pull
    ```

### 5. Testing

The project includes a `preflight-check.sh` script that is run as part of `setup.sh` to validate the environment. For monitoring, the stack includes Uptime Kuma for service health checks and a full Prometheus/Grafana suite for observing metrics.

## Development Conventions

*   **Configuration as Code:** The entire stack is defined in `docker-compose.yml`. All service configurations are stored in the `config/` directory and version-controlled with Git.
*   **Secrets Management:** Secrets and environment-specific variables are managed in the `.env` file, which is excluded from Git. The `.env.example` file serves as a template.
*   **Resource Optimization:** All services in the `docker-compose.yml` have explicit memory and CPU limits (`mem_limit`, `cpus`) tailored for the Le Potato's hardware.
*   **Networking:** Services are segmented into different Docker networks for security and organization. P2P services are forced through a VPN container (`gluetun`) with a firewall-based killswitch.
*   **Homepage Dashboard:** The `homepage` service acts as a central dashboard. Services are automatically discovered and added to the dashboard via Docker labels in the `docker-compose.yml` file.
