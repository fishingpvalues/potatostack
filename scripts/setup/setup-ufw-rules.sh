#!/bin/bash
################################################################################
# PotatoStack UFW Management Script
#
# Manages UFW firewall rules for Docker containers in PotatoStack.
# Integrates with ufw-docker for proper Docker container firewall management.
#
# Usage: sudo bash scripts/setup/setup-ufw-rules.sh [command]
#
# Commands:
#   install      - Install and configure UFW with Docker integration
#   apply        - Apply PotatoStack firewall rules
#   reset        - Reset UFW to defaults and reapply rules
#   status       - Show current firewall status
#   list         - List all Docker container rules
#   allow        - Allow a specific container/port (interactive)
#   deny         - Deny a specific container/port (interactive)
#   help         - Show this help message
################################################################################
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

check_ufw() {
  if ! command -v ufw &>/dev/null; then
    print_error "UFW not installed. Run setup-potatostack.sh first."
    exit 1
  fi
}

check_ufw_docker() {
  if ! command -v ufw-docker &>/dev/null; then
    print_error "ufw-docker not installed. Installing..."
    install_ufw_docker
  fi
}

################################################################################
# Installation Functions
################################################################################
install_ufw() {
  print_info "Installing UFW..."
  apt-get update -y
  apt-get install -y ufw
  print_success "UFW installed"
}

install_ufw_docker() {
  print_info "Installing ufw-docker..."
  wget -O /usr/local/bin/ufw-docker \
    https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
  chmod +x /usr/local/bin/ufw-docker
  ufw-docker install
  print_success "ufw-docker installed"
}

################################################################################
# Configuration Functions
################################################################################
configure_ufw() {
  print_header "Configuring UFW for PotatoStack"

  # Disable temporarily
  ufw --force disable

  # Set default policies
  print_info "Setting default policies..."
  ufw default deny incoming
  ufw default allow outgoing

  # Essential rules
  print_info "Adding essential rules..."

  # SSH - CRITICAL (don't lock yourself out!)
  ufw allow 22/tcp comment 'SSH'

  # HTTP/HTTPS for Traefik (reverse proxy)
  ufw allow 80/tcp comment 'HTTP - Traefik'
  ufw allow 443/tcp comment 'HTTPS - Traefik'

  # DNS for AdGuard Home
  ufw allow 53/tcp comment 'DNS - AdGuard Home'
  ufw allow 53/udp comment 'DNS - AdGuard Home'

  # Optional: WireGuard VPN (if exposing publicly)
  # Uncomment if you want to expose WireGuard
  # ufw allow 51820/udp comment 'WireGuard VPN'

  # Optional: Syncthing (if exposing publicly)
  # Uncomment if you want to expose Syncthing discovery
  # ufw allow 22000/tcp comment 'Syncthing'
  # ufw allow 22000/udp comment 'Syncthing'
  # ufw allow 21027/udp comment 'Syncthing Discovery'

  print_success "Essential rules configured"
}

apply_docker_rules() {
  print_header "Applying Docker Container Rules"

  check_ufw_docker

  print_info "Installing ufw-docker integration..."
  ufw-docker install

  # Allow Traefik container explicitly
  print_info "Allowing Traefik container..."
  ufw-docker allow traefik 80 || print_info "Traefik port 80 rule may already exist"
  ufw-docker allow traefik 443 || print_info "Traefik port 443 rule may already exist"

  # Allow AdGuard Home explicitly
  print_info "Allowing AdGuard Home container..."
  ufw-docker allow adguardhome 53 || print_info "AdGuard Home DNS rule may already exist"

  print_success "Docker container rules applied"
  print_info ""
  print_info "All other containers are protected and accessible only via:"
  echo "  • Traefik reverse proxy (https://service.yourdomain.com)"
  echo "  • Local network (HOST_BIND=${HOST_BIND:-192.168.178.158})"
}

enable_ufw() {
  print_info "Enabling UFW..."
  ufw --force enable
  ufw reload
  print_success "UFW enabled and rules applied"
}

################################################################################
# Management Functions
################################################################################
show_status() {
  print_header "UFW Firewall Status"
  ufw status verbose
  echo ""
  print_info "Docker-specific rules:"
  if command -v ufw-docker &>/dev/null; then
    ufw-docker list 2>/dev/null || echo "  No Docker-specific rules found"
  else
    echo "  ufw-docker not installed"
  fi
}

list_docker_rules() {
  print_header "Docker Container Firewall Rules"
  if command -v ufw-docker &>/dev/null; then
    ufw-docker list
  else
    print_error "ufw-docker not installed"
    exit 1
  fi
}

allow_container() {
  check_ufw_docker

  echo ""
  print_info "Allow Docker container port through firewall"
  read -rp "Container name: " container
  read -rp "Port: " port
  read -rp "Protocol (tcp/udp) [tcp]: " protocol
  protocol=${protocol:-tcp}

  print_info "Allowing ${container}:${port}/${protocol}..."
  ufw-docker allow "$container" "$port" "$protocol"
  print_success "Rule added for ${container}:${port}/${protocol}"
  ufw reload
}

deny_container() {
  check_ufw_docker

  echo ""
  print_info "Deny Docker container port through firewall"
  read -rp "Container name: " container
  read -rp "Port: " port

  print_info "Denying ${container}:${port}..."
  ufw-docker deny "$container" "$port"
  print_success "Rule removed for ${container}:${port}"
  ufw reload
}

reset_ufw() {
  print_header "Reset UFW Configuration"
  print_error "WARNING: This will reset all UFW rules!"
  read -rp "Are you sure? [y/N]: " confirm

  if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    print_info "Reset cancelled"
    exit 0
  fi

  ufw --force disable
  ufw --force reset
  print_success "UFW reset to defaults"

  print_info "Reapplying PotatoStack configuration..."
  configure_ufw
  apply_docker_rules
  enable_ufw
  print_success "Configuration reapplied"
}

show_help() {
  cat <<'EOF'
PotatoStack UFW Management Script

USAGE:
  sudo bash scripts/setup/setup-ufw-rules.sh [command]

COMMANDS:
  install      Install and configure UFW with Docker integration
  apply        Apply PotatoStack firewall rules
  reset        Reset UFW and reapply rules (WARNING: removes all rules!)
  status       Show current firewall status
  list         List all Docker container rules
  allow        Allow a container port (interactive)
  deny         Deny a container port (interactive)
  help         Show this help message

EXAMPLES:
  # Initial setup
  sudo bash scripts/setup/setup-ufw-rules.sh install

  # Check firewall status
  sudo bash scripts/setup/setup-ufw-rules.sh status

  # List Docker container rules
  sudo bash scripts/setup/setup-ufw-rules.sh list

  # Allow a container port interactively
  sudo bash scripts/setup/setup-ufw-rules.sh allow

  # Direct ufw-docker usage
  sudo ufw-docker allow traefik 80
  sudo ufw-docker allow adguardhome 53
  sudo ufw-docker list

POTATOSTACK FIREWALL ARCHITECTURE:
  1. Default Policy: Deny all incoming, allow outgoing
  2. Essential Services:
     • SSH (22/tcp)
     • HTTP (80/tcp) - Traefik reverse proxy
     • HTTPS (443/tcp) - Traefik reverse proxy
     • DNS (53/tcp+udp) - AdGuard Home

  3. Service Access:
     • Public services: Exposed via Traefik (ports 80/443)
     • Internal services: Accessible only from LAN (HOST_BIND)
     • Protected containers: All other containers blocked at firewall

  4. Security Layers:
     • UFW firewall (host-level)
     • ufw-docker (container-level)
     • Traefik routing (application-level)
     • CrowdSec IPS (threat intelligence)
     • Authentik SSO (authentication)

SECURITY NOTES:
  • All Docker containers are blocked by default
  • Only Traefik and AdGuard Home have public ports
  • Services use Traefik for SSL/TLS termination
  • CrowdSec blocks malicious IPs at Traefik level
  • Most services bound to HOST_BIND (LAN-only)

For more information, see:
  • docs/security.md
  • docs/networking.md
EOF
}

################################################################################
# Main Function
################################################################################
main() {
  check_root

  case "${1:-help}" in
  install)
    check_ufw || install_ufw
    check_ufw_docker || install_ufw_docker
    configure_ufw
    apply_docker_rules
    enable_ufw
    show_status
    ;;
  apply)
    check_ufw
    check_ufw_docker
    configure_ufw
    apply_docker_rules
    enable_ufw
    show_status
    ;;
  reset)
    check_ufw
    check_ufw_docker
    reset_ufw
    ;;
  status)
    check_ufw
    show_status
    ;;
  list)
    check_ufw
    check_ufw_docker
    list_docker_rules
    ;;
  allow)
    check_ufw
    check_ufw_docker
    allow_container
    ;;
  deny)
    check_ufw
    check_ufw_docker
    deny_container
    ;;
  help | --help | -h)
    show_help
    ;;
  *)
    print_error "Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
  esac
}

# Run main function
main "$@"
exit 0
