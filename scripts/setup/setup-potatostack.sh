#!/bin/bash
################################################################################
# PotatoStack Docker Compose - Debian 13 Complete Setup Script
#
# This script performs a complete setup for running the PotatoStack
# Docker Compose stack on a fresh Debian 13 (Trixie) installation.
#
# Hardware-optimized for:
# - Intel Twin Lake N150 (up to 3.6GHz)
# - 16GB RAM
# - 512GB SSD
#
# Usage: sudo bash scripts/setup/setup-potatostack.sh
# Or run without sudo and enter password when prompted
#
# Prerequisites:
# - Debian 13 (Trixie) minimal installation
# - Sudo access or root password
# - Internet connection (for package downloads)
################################################################################
set -euo pipefail # Exit on error, undefined variables, pipe failures
# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
# Variables
DOCKER_USER="${DOCKER_USER:-${SUDO_USER:-$(whoami)}}"
SETUP_ROOTLESS="${SETUP_ROOTLESS:-false}"
SETUP_AUTOSTART="${SETUP_AUTOSTART:-true}"
SETUP_GENERATE_ENV="${SETUP_GENERATE_ENV:-true}"
SETUP_SOULSEEK_SYMLINKS="${SETUP_SOULSEEK_SYMLINKS:-false}"
HARDWARE_CPU="Intel Twin Lake N150"
HARDWARE_RAM="16GB"
HARDWARE_STORAGE="512GB SSD"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
################################################################################
# Helper Functions
################################################################################
print_header() {
	echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
	echo -e "${BLUE}$1${NC}"
	echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}
print_success() {
	echo -e "${GREEN}✓ $1${NC}"
}
print_error() {
	echo -e "${RED}✗ $1${NC}"
}
print_info() {
	echo -e "${YELLOW}ℹ $1${NC}"
}
check_root() {
	if [[ $EUID -ne 0 ]]; then
		print_error "This script must be run with sudo or as root"
		exit 1
	fi
}
check_debian() {
	if ! grep -q "Debian GNU/Linux" /etc/os-release; then
		print_error "This script is designed for Debian Linux only"
		exit 1
	fi
	VERSION=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
	# shellcheck disable=SC1091
	VERSION_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
	if [[ ! "$VERSION" =~ ^13 ]]; then
		print_error "This script requires Debian 13 (Trixie). Current version: $VERSION"
		print_info "You can still try to proceed at your own risk"
		read -r -p "Continue anyway? [y/N] " response
		if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
			exit 1
		fi
	fi
}
################################################################################
# Step 1: System Update
################################################################################
step_system_update() {
	print_header "Step 1: System Update and Dependencies"
	# Clean up any broken apt repos before update
	rm -f /etc/apt/sources.list.d/trivy.list 2>/dev/null || true
	print_info "Updating package lists..."
	apt-get update -y
	print_info "Installing base system utilities..."
	apt-get install -y \
		ca-certificates \
		curl \
		gnupg \
		lsb-release \
		apt-transport-https \
		git \
		wget \
		nano \
		vim \
		htop \
		btop \
		net-tools \
		uidmap \
		slirp4netns \
		unzip \
		build-essential \
		python3 \
		python3-pip \
		openssl \
		rsync \
		logrotate \
		cron \
		bash-completion \
		jq \
		bat \
		fd-find \
		ripgrep \
		delta \
		zoxide \
		starship \
		tmux \
		neovim \
		lazygit \
		atuin \
		eza \
		imagemagick \
		ffmpeg \
		poppler-utils \
		unar \
		exiftool \
		libsqlite3-0 \
		sqlite3 \
		tree \
		ncurses-term \
		fastfetch \
		zsh
	print_info "Installing monitoring, storage, and diagnostics tools..."
	apt-get install -y \
		glances \
		sysstat \
		nmon \
		atop \
		smartmontools \
		hdparm \
		btrfs-progs \
		tshark \
		multitail \
		logwatch \
		p7zip-full \
		fzf \
		tealdeer \
		silversearcher-ag \
		pv \
		screen \
		mediainfo \
		nfs-common \
		samba

	# Install tools not in Debian repos via binary downloads
	print_info "Installing additional CLI tools (binary downloads)..."

	# dive (Docker image explorer)
	if ! command -v dive &>/dev/null; then
		print_info "Installing dive..."
		DIVE_VERSION=$(curl -s https://api.github.com/repos/wagoodman/dive/releases/latest | jq -r '.tag_name' | tr -d 'v')
		curl -fsSL "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.tar.gz" | tar xzf - -C /usr/local/bin dive
		chmod +x /usr/local/bin/dive
		print_success "dive installed"
	fi

	# ctop (container top)
	if ! command -v ctop &>/dev/null; then
		print_info "Installing ctop..."
		CTOP_VERSION=$(curl -s https://api.github.com/repos/bcicen/ctop/releases/latest | jq -r '.tag_name' | tr -d 'v')
		curl -fsSL "https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-amd64" -o /usr/local/bin/ctop
		chmod +x /usr/local/bin/ctop
		print_success "ctop installed"
	fi

	# lazydocker (Docker TUI)
	if ! command -v lazydocker &>/dev/null; then
		print_info "Installing lazydocker..."
		LAZYDOCKER_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | jq -r '.tag_name' | tr -d 'v')
		curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" | tar xzf - -C /usr/local/bin lazydocker
		chmod +x /usr/local/bin/lazydocker
		print_success "lazydocker installed"
	fi

	# yazi (file manager)
	if ! command -v yazi &>/dev/null; then
		print_info "Installing yazi..."
		YAZI_VERSION=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | jq -r '.tag_name' | tr -d 'v')
		curl -fsSL "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip" -o /tmp/yazi.zip
		unzip -q -o /tmp/yazi.zip -d /tmp/yazi
		mv /tmp/yazi/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/
		chmod +x /usr/local/bin/yazi
		rm -rf /tmp/yazi /tmp/yazi.zip
		print_success "yazi installed"
	fi

	# zellij (terminal multiplexer)
	if ! command -v zellij &>/dev/null; then
		print_info "Installing zellij..."
		ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | jq -r '.tag_name' | tr -d 'v')
		curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" | tar xzf - -C /usr/local/bin
		chmod +x /usr/local/bin/zellij
		print_success "zellij installed"
	fi

	# helix (editor)
	if ! command -v hx &>/dev/null; then
		print_info "Installing helix..."
		HELIX_VERSION=$(curl -s https://api.github.com/repos/helix-editor/helix/releases/latest | jq -r '.tag_name')
		curl -fsSL "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-x86_64-linux.tar.xz" -o /tmp/helix.tar.xz
		tar xJf /tmp/helix.tar.xz -C /opt/
		ln -sf /opt/helix-${HELIX_VERSION}-x86_64-linux/hx /usr/local/bin/hx
		rm /tmp/helix.tar.xz
		print_success "helix installed (as 'hx')"
	fi

	print_success "System dependencies installed"
}
################################################################################
# Step 2: Docker Installation
################################################################################
step_docker_installation() {
	print_header "Step 2: Docker Installation"
	# Remove conflicting packages
	print_info "Removing conflicting Docker packages..."
	apt-get remove -y docker.io docker-compose docker-doc podman-docker \
		containerd runc 2>/dev/null || true
	# Add Docker's GPG key
	print_info "Adding Docker GPG key..."
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/debian/gpg \
		-o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc
	# Add Docker repository
	print_info "Adding Docker repository..."
	echo "Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc" | tee /etc/apt/sources.list.d/docker.sources >/dev/null
	apt-get update -y
	# Install Docker Engine, CLI, and Compose
	print_info "Installing Docker Engine and Compose..."
	apt-get install -y \
		docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin
	# Verify installation
	if docker --version >/dev/null; then
		print_success "Docker installed: $(docker --version)"
	else
		print_error "Docker installation failed"
		exit 1
	fi
	if docker compose version >/dev/null 2>&1; then
		print_success "Docker Compose installed: $(docker compose version)"
	else
		print_error "Docker Compose installation failed"
		exit 1
	fi
}
################################################################################
# Step 3: Docker Post-Installation (Non-root access)
################################################################################
step_docker_postinstall() {
	print_header "Step 3: Docker Post-Installation Setup"
	# Create docker group
	if ! getent group docker >/dev/null; then
		print_info "Creating docker group..."
		groupadd docker
		print_success "Docker group created"
	else
		print_info "Docker group already exists"
	fi
	# Add current user to docker group
	print_info "Adding $DOCKER_USER to docker group..."
	usermod -aG docker "$DOCKER_USER"
	print_info "Docker group permissions configured for user: $DOCKER_USER"
	print_info "You may need to log out and log back in for group changes to take effect"
	# Start Docker service
	print_info "Starting Docker service..."
	systemctl start docker
	systemctl enable docker
	print_success "Docker service enabled and started"
}
################################################################################
# Step 4: Docker Rootless Mode (Optional)
################################################################################
step_docker_rootless() {
	if [[ "$SETUP_ROOTLESS" != "true" ]]; then
		print_info "Skipping Rootless mode setup (optional). To enable, run: SETUP_ROOTLESS=true sudo bash scripts/setup/setup-potatostack.sh"
		return 0
	fi
	print_header "Step 4: Docker Rootless Mode (Optional)"
	print_info "Setting up Docker Rootless mode for user: $DOCKER_USER"
	# Configure subordinate UIDs/GIDs
	if ! grep -q "^$DOCKER_USER:" /etc/subuid; then
		print_info "Configuring subordinate UIDs/GIDs..."
		echo "$DOCKER_USER:100000:65536" >>/etc/subuid
		echo "$DOCKER_USER:100000:65536" >>/etc/subgid
		print_success "Subordinate UIDs/GIDs configured"
	else
		print_info "Subordinate UIDs/GIDs already configured"
	fi
	# Install rootless mode
	print_info "Installing Docker Rootless components..."
	apt-get install -y docker-ce-rootless-extras
	print_info "To finalize rootless setup, run as the target user:"
	echo "    dockerd-rootless-setuptool.sh install"
	print_success "Rootless mode components installed"
}
################################################################################
# Step 5: Install Development and Validation Tools
################################################################################
step_dev_tools_installation() {
	print_header "Step 5: Installing Development and Validation Tools"
	# Install yamllint (YAML validation)
	if ! command -v yamllint &>/dev/null; then
		print_info "Installing yamllint (YAML validation)..."
		apt-get install -y yamllint
		print_success "yamllint installed"
	else
		print_info "yamllint already installed"
	fi
	# Install shellcheck (Shell script linting)
	if ! command -v shellcheck &>/dev/null; then
		print_info "Installing shellcheck (Shell script linting)..."
		apt-get install -y shellcheck
		print_success "shellcheck installed"
	else
		print_info "shellcheck already installed"
	fi
	# Install shfmt (Shell script formatting)
	if ! command -v shfmt &>/dev/null; then
		print_info "Installing shfmt (Shell script formatting)..."
		SHFMT_VERSION="v3.7.0"
		ARCH=$(dpkg --print-architecture)
		case $ARCH in
		amd64) SHFMT_ARCH="amd64" ;;
		arm64) SHFMT_ARCH="arm64" ;;
		armhf) SHFMT_ARCH="arm" ;;
		*) SHFMT_ARCH="amd64" ;;
		esac
		curl -fsSL "https://github.com/mvdan/sh/releases/download/$SHFMT_VERSION/shfmt_${SHFMT_VERSION}_linux_${SHFMT_ARCH}" \
			-o /usr/local/bin/shfmt
		chmod +x /usr/local/bin/shfmt
		print_success "shfmt $SHFMT_VERSION installed"
	else
		print_info "shfmt already installed: $(shfmt --version)"
	fi
	# Install jq (JSON processor)
	if ! command -v jq &>/dev/null; then
		print_info "Installing jq (JSON processor)..."
		apt-get install -y jq
		print_success "jq installed"
	else
		print_info "jq already installed"
	fi
	# Install yq (YAML processor)
	if ! command -v yq &>/dev/null; then
		print_info "Installing yq (YAML processor)..."
		YQ_VERSION="v4.40.5"
		ARCH=$(dpkg --print-architecture)
		case $ARCH in
		amd64) YQ_ARCH="amd64" ;;
		arm64) YQ_ARCH="arm64" ;;
		*) YQ_ARCH="amd64" ;;
		esac
		curl -fsSL "https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_linux_${YQ_ARCH}" \
			-o /usr/local/bin/yq
		chmod +x /usr/local/bin/yq
		print_success "yq $YQ_VERSION installed"
	else
		print_info "yq already installed: $(yq --version)"
	fi
	# Install prettier (Code formatter, via npm)
	if ! command -v prettier &>/dev/null; then
		print_info "Installing prettier (Code formatter)..."
		apt-get install -y nodejs npm
		npm install -g prettier
		print_success "prettier installed"
	else
		print_info "prettier already installed: $(prettier --version)"
	fi
	# Install trivy (Security scanner) via binary download
	if ! command -v trivy &>/dev/null; then
		print_info "Installing trivy (Security scanner)..."
		# Clean up any broken trivy apt repo
		rm -f /etc/apt/sources.list.d/trivy.list 2>/dev/null || true
		TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r '.tag_name' | tr -d 'v')
		curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" | tar xzf - -C /usr/local/bin trivy
		chmod +x /usr/local/bin/trivy
		print_success "trivy installed: $(trivy --version)"
	else
		print_info "trivy already installed: $(trivy --version)"
	fi
	# Install Python tools for YAML validation
	print_info "Installing Python YAML parsing library..."
	pip3 install pyyaml --break-system-packages || true
	# Install monitoring tools
	print_info "Installing monitoring and debugging tools..."
	apt-get install -y \
		dnsutils \
		iputils-ping \
		telnet \
		nmap \
		tcpdump \
		iotop \
		nethogs \
		iftop \
		strace \
		lsof \
		ncdu
	print_success "Development and validation tools installed"
}
################################################################################
# Step 6: System Optimization for Docker
################################################################################
step_system_optimization() {
	print_header "Step 6: System Optimization for Docker Workloads"
	print_info "Optimizing for Intel Twin Lake N150, 16GB RAM, 512GB SSD..."
	# Increase file descriptor limits (optimized for 16GB RAM)
	print_info "Optimizing system limits..."
	if ! grep -q "docker" /etc/security/limits.conf; then
		cat >>/etc/security/limits.conf <<EOF
# Docker optimization - N150/16GB RAM optimized
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 32768
* hard nproc 32768
docker soft nofile 1048576
docker hard nofile 1048576
docker soft nproc 32768
docker hard nproc 32768
EOF
		print_success "File descriptor limits configured"
	fi
	# Optimize sysctl for Docker (N150 low-power optimized)
	# Create sysctl.conf if it doesn't exist
	touch /etc/sysctl.conf
	if ! grep -q "POTATOSTACK_OPTIMIZATIONS" /etc/sysctl.conf; then
		# Load br_netfilter module for bridge settings (required for Docker)
		modprobe br_netfilter 2>/dev/null || true
		# Ensure br_netfilter loads on boot
		echo "br_netfilter" >/etc/modules-load.d/br_netfilter.conf 2>/dev/null || true
		cat >>/etc/sysctl.conf <<EOF
# POTATOSTACK_OPTIMIZATIONS - N150/16GB RAM optimized
# Docker networking optimization
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
# Network optimizations for better performance
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
# VM optimizations for 16GB RAM
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
# Memory management for N150 low-power CPU
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
# Container runtime optimizations
net.ipv4.ip_local_port_range = 1024 65535
EOF
		# Apply sysctl settings (ignore bridge errors if module not loaded)
		sysctl -p 2>/dev/null || sysctl --system
		print_success "Sysctl parameters optimized for N150/16GB RAM"
	fi
	# Create docker data directory structure
	print_info "Creating Docker data directories..."
	mkdir -p /var/lib/docker
	mkdir -p /docker-data
	chmod 755 /docker-data
	print_success "Docker directories created"
	# Optimize SSD for better Docker performance
	print_info "Optimizing SSD performance for Docker..."
	if ! grep -q "/var/lib/docker" /etc/fstab; then
		cat >>/etc/fstab <<EOF
# Docker SSD optimization
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=8G 0 0
tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=4G 0 0
EOF
		print_success "SSD optimization configured"
		print_info "Reboot or run 'mount -a' (carefully) to apply tmpfs mounts"
	fi
}
################################################################################
# Step 6b: Host-Level Optimization (zram, fstrim, journald)
################################################################################
step_host_tuning() {
	print_header "Step 6b: Host-Level Optimization (zram, fstrim, journald)"
	# ZRAM swap for Debian 13
	print_info "Configuring zram swap..."
	if command -v apt-get >/dev/null 2>&1; then
		apt-get install -y zram-tools || true
		if [ -f /etc/default/zramswap ]; then
			cat >/etc/default/zramswap <<'EOF'
# Potatostack zram configuration
ALGO=lz4
PERCENT=25
PRIORITY=100
EOF
			systemctl enable --now zramswap.service || true
			print_success "zram swap configured"
		else
			print_info "zram-tools not available, skipping zram setup"
		fi
	else
		print_info "apt-get not available, skipping zram setup"
	fi
	# Enable periodic SSD trim
	print_info "Enabling fstrim timer..."
	if systemctl list-unit-files | grep -q "^fstrim.timer"; then
		systemctl enable --now fstrim.timer || true
		print_success "fstrim timer enabled"
	else
		print_info "fstrim.timer not available, skipping"
	fi
	# Journald limits to reduce disk churn
	print_info "Tuning journald retention..."
	mkdir -p /etc/systemd/journald.conf.d
	cat >/etc/systemd/journald.conf.d/potatostack.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemMaxFileSize=50M
RuntimeMaxUse=100M
Compress=yes
EOF
	systemctl restart systemd-journald || true
	print_success "journald limits configured"
	# Extra sysctl for watchers/limits
	print_info "Applying additional sysctl tuning..."
	cat >/etc/sysctl.d/99-potatostack.conf <<'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
fs.inotify.max_queued_events = 16384
fs.file-max = 2097152
EOF
	sysctl --system || true
	print_success "Additional sysctl tuning applied"
}
################################################################################
# Step 7: Storage Setup (for PotatoStack)
################################################################################
step_storage_setup() {
	print_header "Step 7: Storage Directory Setup (PotatoStack - N150/16GB/512GB SSD)"
	print_info "Ensuring base mount points exist..."
	mkdir -p /mnt/storage /mnt/cachehdd /mnt/ssd/docker-data /docker-data
	if [ -f "${SCRIPT_DIR}/../init/init-storage.sh" ]; then
		print_info "Running init-storage.sh for SOTA directory structure..."
		local docker_uid
		local docker_gid
		docker_uid=$(id -u "$DOCKER_USER")
		docker_gid=$(id -g "$DOCKER_USER")
		PUID="$docker_uid" PGID="$docker_gid" bash "${SCRIPT_DIR}/../init/init-storage.sh"
	else
		print_info "init-storage.sh not found, creating minimal structure..."
		mkdir -p /mnt/storage/syncthing /mnt/storage/downloads
		mkdir -p /mnt/cachehdd /mnt/ssd/docker-data
	fi
	print_success "Storage directories created and validated"
}
################################################################################
# Step 7b: Generate Environment File (.env)
################################################################################
step_generate_env() {
	print_header "Step 7b: Generate Environment Configuration (.env)"

	if [[ "$SETUP_GENERATE_ENV" != "true" ]]; then
		print_info "Skipping .env generation (SETUP_GENERATE_ENV=false)"
		return 0
	fi

	local project_root
	project_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
	local env_file="$project_root/.env"

	# Check if .env already exists
	if [[ -f "$env_file" ]]; then
		print_info ".env file already exists at $env_file"
		echo -ne "  ${YELLOW}Skip generation? [Y/n]:${NC} "
		read -r skip_confirm
		if [[ ! "$skip_confirm" =~ ^[Nn]$ ]]; then
			print_info "Keeping existing .env file"
			return 0
		fi
	fi

	if [[ -f "${SCRIPT_DIR}/generate-env.sh" ]]; then
		print_info "Running generate-env.sh to create .env with secure secrets..."
		# Run as non-root user if possible for proper file ownership
		if [[ -n "$DOCKER_USER" && "$DOCKER_USER" != "root" ]]; then
			su - "$DOCKER_USER" -c "cd '$project_root' && bash '${SCRIPT_DIR}/generate-env.sh'"
		else
			bash "${SCRIPT_DIR}/generate-env.sh"
		fi
		print_success "Environment configuration generated"
	else
		print_error "generate-env.sh not found at ${SCRIPT_DIR}/generate-env.sh"
		print_info "You can generate .env manually later with: ./scripts/setup/generate-env.sh"
	fi
}
################################################################################
# Step 7c: Soulseek Symlinks (Optional)
################################################################################
step_soulseek_symlinks() {
	print_header "Step 7c: Soulseek Symlinks (Optional)"

	if [[ "$SETUP_SOULSEEK_SYMLINKS" != "true" ]]; then
		print_info "Skipping Soulseek symlinks (SETUP_SOULSEEK_SYMLINKS=false)"
		print_info "To enable, run: SETUP_SOULSEEK_SYMLINKS=true sudo bash scripts/setup/setup-potatostack.sh"
		return 0
	fi

	if [[ -f "${SCRIPT_DIR}/setup-soulseek-symlinks.sh" ]]; then
		print_info "Creating Soulseek shared folder symlinks..."
		bash "${SCRIPT_DIR}/setup-soulseek-symlinks.sh"
		print_success "Soulseek symlinks created"
	else
		print_info "setup-soulseek-symlinks.sh not found, skipping."
	fi
}
################################################################################
# Step 8: Autostart & Security Hardening
################################################################################
step_autostart_hardening() {
	print_header "Step 8: Autostart & Security Hardening"
	if [[ "$SETUP_AUTOSTART" != "true" ]]; then
		print_info "Skipping autostart/hardening (SETUP_AUTOSTART=false)"
		return 0
	fi
	if [ -f "${SCRIPT_DIR}/setup-autostart.sh" ]; then
		print_info "Running setup-autostart.sh..."
		bash "${SCRIPT_DIR}/setup-autostart.sh"
	else
		print_info "setup-autostart.sh not found, skipping."
	fi
}
################################################################################
# Step 9: Additional Utilities
################################################################################
step_additional_tools() {
	print_header "Step 9: Installing Additional Utilities"
	# Install Make (for running make commands)
	if ! command -v make &>/dev/null; then
		print_info "Installing make..."
		apt-get install -y make
		print_success "make installed"
	else
		print_info "make already installed"
	fi
	print_success "Additional utilities installed"
}
################################################################################
# Step 10: Firewall Configuration
################################################################################
step_firewall_setup() {
	print_header "Step 10: Firewall Configuration (UFW + ufw-docker + Traefik)"

	# Install UFW
	if ! command -v ufw &>/dev/null; then
		print_info "Installing UFW (Uncomplicated Firewall)..."
		apt-get install -y ufw
	fi

	print_info "Configuring UFW for PotatoStack..."

	# Disable UFW temporarily to configure rules
	ufw --force disable

	# Reset UFW to defaults (only on fresh install)
	if ! grep -q "POTATOSTACK_UFW_CONFIGURED" /etc/ufw/before.rules; then
		print_info "Resetting UFW to defaults..."
		ufw --force reset
	fi

	# Set default policies
	ufw default deny incoming
	ufw default allow outgoing

	# Allow SSH (CRITICAL - don't lock yourself out!)
	print_info "Allowing SSH (port 22)..."
	ufw allow 22/tcp comment 'SSH'

	# Allow HTTP and HTTPS for Traefik (public-facing)
	print_info "Allowing HTTP/HTTPS for Traefik..."
	ufw allow 80/tcp comment 'HTTP - Traefik'
	ufw allow 443/tcp comment 'HTTPS - Traefik'

	# Allow DNS for AdGuard Home (if exposing publicly)
	print_info "Allowing DNS for AdGuard Home..."
	ufw allow 53/tcp comment 'DNS - AdGuard Home'
	ufw allow 53/udp comment 'DNS - AdGuard Home'

	# Install ufw-docker for proper Docker integration
	print_info "Installing ufw-docker for Docker integration..."
	if [ ! -f /usr/local/bin/ufw-docker ]; then
		wget -O /usr/local/bin/ufw-docker \
			https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
		chmod +x /usr/local/bin/ufw-docker
	fi

	# Install ufw-docker rules
	print_info "Installing ufw-docker rules..."
	ufw-docker install

	# Mark as configured
	if ! grep -q "POTATOSTACK_UFW_CONFIGURED" /etc/ufw/before.rules; then
		echo "# POTATOSTACK_UFW_CONFIGURED" >>/etc/ufw/before.rules
	fi

	# Enable UFW
	print_info "Enabling UFW..."
	ufw --force enable

	# Reload UFW
	ufw reload

	print_success "UFW configured with Docker integration"
	print_info "Firewall status:"
	ufw status numbered | head -20

	print_info ""
	print_info "UFW Configuration Complete:"
	echo "  ✓ SSH (22/tcp) - ALLOWED"
	echo "  ✓ HTTP (80/tcp) - ALLOWED for Traefik"
	echo "  ✓ HTTPS (443/tcp) - ALLOWED for Traefik"
	echo "  ✓ DNS (53/tcp+udp) - ALLOWED for AdGuard Home"
	echo "  ✓ ufw-docker integration - ENABLED"
	echo ""
	echo "IMPORTANT - Docker Container Firewall Rules:"
	echo "  All other Docker containers are protected by UFW and accessible only:"
	echo "  1. Through Traefik reverse proxy (ports 80/443)"
	echo "  2. From localhost/LAN (HOST_BIND=${HOST_BIND:-192.168.178.158})"
	echo ""
	echo "To expose additional Docker container ports:"
	echo "  sudo ufw-docker allow <container-name> <port>/<protocol>"
	echo ""
	echo "Example commands:"
	echo "  sudo ufw-docker list          # List all rules"
	echo "  sudo ufw-docker check          # Check rules"
	echo ""
}
################################################################################
# Step 11: Verification and Testing
################################################################################
step_verification() {
	print_header "Step 11: Verification and Testing"
	print_info "Running Docker verification tests..."
	# Test Docker socket
	if docker ps >/dev/null 2>&1; then
		print_success "Docker daemon is running"
	else
		print_error "Docker daemon test failed"
		return 1
	fi
	# Test Docker Compose
	if docker compose version >/dev/null 2>&1; then
		print_success "Docker Compose is functional"
	else
		print_error "Docker Compose test failed"
		return 1
	fi
	# Test Docker image pull
	print_info "Testing image pull (hello-world)..."
	if docker pull hello-world >/dev/null 2>&1; then
		print_success "Docker image pull successful"
		docker run --rm hello-world >/dev/null 2>&1 && print_success "Docker container execution successful"
	else
		print_error "Docker image pull/run failed"
	fi
	# Verify development tools
	print_info "Verifying development and validation tools..."
	local tools_ok=0
	local tools_total=0
	tools_total=$((tools_total + 1))
	if command -v yamllint &>/dev/null; then
		print_success "yamllint installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "yamllint not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v shellcheck &>/dev/null; then
		print_success "shellcheck installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "shellcheck not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v shfmt &>/dev/null; then
		print_success "shfmt installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "shfmt not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v prettier &>/dev/null; then
		print_success "prettier installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "prettier not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v trivy &>/dev/null; then
		print_success "trivy installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "trivy not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v jq &>/dev/null; then
		print_success "jq installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "jq not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v yq &>/dev/null; then
		print_success "yq installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "yq not found"
	fi
	tools_total=$((tools_total + 1))
	if command -v make &>/dev/null; then
		print_success "make installed"
		tools_ok=$((tools_ok + 1))
	else
		print_error "make not found"
	fi
	print_info "Tools verified: $tools_ok/$tools_total"
	# Show system info
	print_info "System Information:"
	echo "  Hardware: $HARDWARE_CPU, $HARDWARE_RAM, $HARDWARE_STORAGE"
	echo "  Debian Version: $(lsb_release -ds)"
	echo "  Kernel: $(uname -r)"
	echo "  Docker Version: $(docker version --format '{{.Server.Version}}')"
	echo "  Docker Compose Version: $(docker compose version --short)"
}
################################################################################
# Step 12: Shell Configuration (Zsh, Oh-My-Zsh, Powerlevel10k)
################################################################################
step_shell_configuration() {
	print_header "Step 12: Shell Configuration (Zsh + Oh-My-Zsh + P10k)"
	# Install Oh-My-Zsh
	print_info "Installing Oh-My-Zsh..."
	if [[ ! -d "/home/$DOCKER_USER/.oh-my-zsh" ]]; then
		su - "$DOCKER_USER" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
		print_success "Oh-My-Zsh installed"
	else
		print_info "Oh-My-Zsh already installed"
	fi
	# Install Powerlevel10k theme
	print_info "Installing Powerlevel10k theme..."
	if [[ ! -d "/home/$DOCKER_USER/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
		su - "$DOCKER_USER" -c 'git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k'
		print_success "Powerlevel10k theme installed"
	else
		print_info "Powerlevel10k already installed"
	fi
	# Configure .zshrc to use Powerlevel10k
	print_info "Configuring .zshrc for Powerlevel10k..."
	ZSHRC_FILE="/home/$DOCKER_USER/.zshrc"
	if [[ -f "$ZSHRC_FILE" ]]; then
		if ! grep -q "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" "$ZSHRC_FILE"; then
			sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC_FILE"
			print_success ".zshrc configured for Powerlevel10k"
		else
			print_info ".zshrc already configured for Powerlevel10k"
		fi
	else
		print_info ".zshrc not found, skipping configuration"
	fi
	# Change default shell to zsh
	print_info "Changing default shell to zsh for $DOCKER_USER..."
	if [[ "$(getent passwd "$DOCKER_USER" | cut -d: -f7)" != "/bin/zsh" ]]; then
		chsh -s /bin/zsh "$DOCKER_USER"
		print_success "Default shell changed to zsh"
	else
		print_info "Default shell already set to zsh"
	fi
	# Configure fastfetch with essential SOTA info
	print_info "Configuring fastfetch..."
	FASTFETCH_CONFIG_DIR="/home/$DOCKER_USER/.config/fastfetch"
	mkdir -p "$FASTFETCH_CONFIG_DIR"
	cat >"$FASTFETCH_CONFIG_DIR/config.jsonc" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "display": {
    "separator": " -> "
  },
  "modules": [
    "title",
    "datetime",
    "uptime",
    "os",
    "kernel",
    "cpu",
    "memory",
    "disk",
    "localip"
  ]
}
EOF
	chown -R "$DOCKER_USER:$DOCKER_USER" "$FASTFETCH_CONFIG_DIR"
	print_success "Fastfetch configured with essential SOTA info"
	print_info "Shell configuration complete. You may need to log out and log back in for changes to take effect."
	print_info "To configure Powerlevel10k interactively, run: p10k configure"
}
################################################################################
# Step 13: Final Instructions
################################################################################
step_final_instructions() {
	print_header "Step 13: Post-Installation Instructions"
	cat <<'EOF'
✓ PotatoStack Setup Complete!
Hardware Optimizations Applied:
  • Intel Twin Lake N150 CPU optimizations (BBR congestion control)
  • 16GB RAM memory tuning (swappiness=10, vfs_cache_pressure=50)
  • 512GB SSD performance optimization (tmpfs, noatime)
Development & Validation Tools Installed:
  • yamllint - YAML syntax validation
  • shellcheck - Shell script linting
  • shfmt - Shell script formatting
  • prettier - Code formatter for YAML/JSON/JS
  • trivy - Security vulnerability scanner
  • jq - JSON processor
  • yq - YAML processor
  • htop/btop - System monitoring
  • nmap/tcpdump - Network debugging
  • iotop/nethogs/iftop - Performance monitoring
NEXT STEPS:
1. Log out and log back in for group permissions to take effect:
    $ logout
    # Then log back in
2. Navigate to the PotatoStack directory:
    $ cd ~/potatostack  # or wherever you cloned the repo
3. If .env was not generated during setup, create it now:
    $ ./scripts/setup/generate-env.sh
4. Start PotatoStack:
    $ docker compose up -d
5. Verify services are running:
    $ docker compose ps
    $ docker compose logs -f
6. Optional: Enable autostart/hardening later (if skipped):
    $ sudo ./scripts/setup/setup-autostart.sh
7. Optional: Create Soulseek symlinks for sharing:
    $ sudo ./scripts/setup/setup-soulseek-symlinks.sh
VALIDATION COMMANDS:
  • make validate  - Validate docker-compose.yml syntax
  • make lint      - Run comprehensive validation (YAML, shell, compose)
  • make format    - Format shell scripts and YAML files
  • make security  - Run security vulnerability scan
  • make test      - Run full integration tests
  • make test-quick - Quick health check
IMPORTANT NOTES:
• Storage Paths: Ensure /mnt/storage, /mnt/cachehdd, and /mnt/ssd exist
  and have proper permissions for your user
• Security: Review docker-compose.yml for passwords and secrets
  Consider using Docker Secrets or environment files
• Firewall: UFW + ufw-docker + Traefik integration configured
  ✓ Public ports: SSH (22), HTTP (80), HTTPS (443), DNS (53)
  ✓ All other ports: BLOCKED at firewall level
  ✓ Traefik is the ONLY public-facing service (defense-in-depth)
  ✓ Services accessible via: https://service.yourdomain.com (Traefik)

  Quick commands:
    make firewall-status    # Check firewall status
    make firewall-list      # List Docker container rules
    sudo ufw-docker allow <container> <port>  # Expose container port

  Full documentation: docs/firewall-security.md
  Quick reference: docs/FIREWALL-QUICKSTART.md
• Monitoring: Access Grafana, Prometheus, and other services at:
  https://your-domain/grafana
  https://your-domain/prometheus
  etc.
• Backup: Regularly backup /docker-data and /mnt/storage
• Logs: Check Docker logs with:
  $ docker compose logs <service-name>
  $ docker compose logs -f --tail=100
OPTIONAL FLAGS:
  • SETUP_AUTOSTART=false       # Skip autostart/hardening step
  • SETUP_ROOTLESS=true         # Enable rootless Docker setup
  • SETUP_GENERATE_ENV=false    # Skip .env generation (if already exists)
  • SETUP_SOULSEEK_SYMLINKS=true # Create Soulseek shared folder symlinks
USEFUL COMMANDS:
  # View running containers
  docker compose ps

  # View logs
  docker compose logs -f

  # Execute command in container
  docker compose exec <service> <command>

  # Update images
  docker compose pull
  docker compose up -d

  # Stop stack
  docker compose down

  # Restart service
  docker compose restart <service>

  # Format shell script
  shfmt -w script.sh

  # Check shell script
  shellcheck script.sh

  # Validate YAML file
  yamllint docker-compose.yml
DOCUMENTATION:
  - Docker: https://docs.docker.com
  - Docker Compose: https://docs.docker.com/compose
  - Your Stack Components: Check README in your compose directory
SUPPORT:
  For issues, check:
  1. Docker logs: docker compose logs <service>
  2. Service health: docker compose ps
  3. System resources: free -h && df -h
═══════════════════════════════════════════════════════════════════════
EOF
	print_success "Setup script completed successfully!"
}
################################################################################
# Main Execution
################################################################################
main() {
	print_header "PotatoStack Docker Compose - Debian 13 Setup"
	print_info "Hardware: $HARDWARE_CPU, $HARDWARE_RAM, $HARDWARE_STORAGE"
	print_info "This script will set up Docker and Docker Compose on Debian 13"
	print_info "for running PotatoStack Docker Compose deployment"
	# Check prerequisites
	check_root
	check_debian
	# Execute setup steps
	step_system_update
	step_docker_installation
	step_docker_postinstall
	step_docker_rootless
	step_dev_tools_installation
	step_system_optimization
	step_host_tuning
	step_storage_setup
	step_generate_env
	step_soulseek_symlinks
	step_autostart_hardening
	step_additional_tools
	step_firewall_setup
	step_verification
	step_shell_configuration
	step_final_instructions
}
# Run main function
main "$@"
exit 0
