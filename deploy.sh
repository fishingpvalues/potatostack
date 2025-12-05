#!/bin/bash

################################################################################
# PotatoStack Deployment Script
# This script deploys PotatoStack to a target server via SSH
# Usage: ./deploy.sh [environment]
# Environment can be: staging, production
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-staging}"
TARGET_SERVER=""
TARGET_USER="root"
TARGET_DIR="/opt/potatostack"
SSH_KEY_PATH="~/.ssh/id_rsa"
DRY_RUN=false

# Parse command line arguments
show_help() {
    echo "Usage: $0 [OPTIONS] [environment]"
    echo ""
    echo "Deploy PotatoStack to target server."
    echo ""
    echo "Arguments:"
    echo "  environment    Target environment: staging, production (default: staging)"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -s, --server   Target server hostname/IP"
    echo "  -u, --user     Target server user (default: root)"
    echo "  -d, --dir      Target directory (default: /opt/potatostack)"
    echo "  --ssh-key      SSH key path (default: ~/.ssh/id_rsa)"
    echo "  --dry-run      Show what would be done without actually doing it"
    echo ""
    echo "Examples:"
    echo "  $0 staging"
    echo "  $0 production --server lepotato.local --user admin"
    echo "  $0 staging --dry-run"
}

# Function to log messages
log() {
    echo -e "${BLUE}[INFO]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

# Function to log success messages
log_success() {
    echo -e "${GREEN}[SUCCESS]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

# Function to log error messages
log_error() {
    echo -e "${RED}[ERROR]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

# Function to log warning messages
log_warning() {
    echo -e "${YELLOW}[WARNING]$(date '+%Y-%m-%d %H:%M:%S')${NC} $1"
}

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--server)
            TARGET_SERVER="$2"
            shift 2
            ;;
        -u|--user)
            TARGET_USER="$2"
            shift 2
            ;;
        -d|--dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            log_error "Unknown option $1"
            show_help
            exit 1
            ;;
        *)
            ENVIRONMENT="$1"
            shift
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    log_error "Environment must be 'staging' or 'production'. Got: $ENVIRONMENT"
    exit 1
fi

# Validate that TARGET_SERVER is provided
if [[ -z "$TARGET_SERVER" ]]; then
    log_error "Target server must be provided using --server option"
    show_help
    exit 1
fi

# Validate that this script is run from the project root
if [[ ! -f "docker-compose.yml" || ! -f ".env.example" ]]; then
    log_error "This script must be run from the PotatoStack project root directory"
    exit 1
fi

# Check if SSH key exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    log_error "SSH key not found at $SSH_KEY_PATH"
    exit 1
fi

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    log_warning ".env file not found. You may want to copy .env.example and customize it."
fi

# Function to run command locally or remotely based on DRY_RUN
run_command() {
    local command="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} $description"
        echo -e "  Command: $command"
        return 0
    fi
    
    log "$description"
    eval "$command"
}

# Function to determine if we should prompt for confirmation
should_prompt_confirmation() {
    if [[ "$DRY_RUN" == true ]]; then
        return 1  # Don't prompt in dry run
    elif [[ "$ENVIRONMENT" == "production" ]]; then
        return 0  # Always prompt for production
    fi
    return 1  # Don't prompt for staging
}

# Confirmation for production
if [[ "$ENVIRONMENT" == "production" ]]; then
    if should_prompt_confirmation; then
        read -p "$(echo -e "${RED}⚠️  YOU ARE ABOUT TO DEPLOY TO PRODUCTION!${NC} Are you sure? (yes/no): ")" -r
        echo
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_error "Production deployment cancelled"
            exit 1
        fi
    fi
fi

log "Starting $ENVIRONMENT deployment to $TARGET_SERVER"

# Create deployment package
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEPLOYMENT_PACKAGE="potatostack-${ENVIRONMENT}-${TIMESTAMP}.tar.gz"

log "Creating deployment package: $DEPLOYMENT_PACKAGE"

# Create a temporary directory to prepare the deployment
DEPLOY_DIR=$(mktemp -d)

# Copy all necessary files to the deployment directory
cp docker-compose.yml "$DEPLOY_DIR/"
cp -r config/ "$DEPLOY_DIR/" 2>/dev/null || true  # Ignore if config doesn't exist
cp -r scripts/ "$DEPLOY_DIR/" 2>/dev/null || true  # Copy any scripts directory if it exists
cp .env.example "$DEPLOY_DIR/" 2>/dev/null || true  # Copy example .env file
cp setup.sh "$DEPLOY_DIR/" 2>/dev/null || true  # Copy setup script if it exists
cp preflight-check.sh "$DEPLOY_DIR/" 2>/dev/null || true  # Copy preflight check if it exists
cp README.md "$DEPLOY_DIR/" 2>/dev/null || true  # Copy README if it exists

# Handle .env file - copy if it exists in the current directory
if [[ -f ".env" ]]; then
    log_warning "Copying .env file to deployment package. Make sure it's properly configured for $ENVIRONMENT!"
    cp .env "$DEPLOY_DIR/"
fi

# Create the deployment package
tar -czf "$DEPLOY_DIR/$DEPLOYMENT_PACKAGE" -C "$DEPLOY_DIR" .

log_success "Deployment package created: $DEPLOY_DIR/$DEPLOYMENT_PACKAGE"

# Test SSH connection first
if [[ "$DRY_RUN" != true ]]; then
    log "Testing SSH connection to $TARGET_USER@$TARGET_SERVER..."
    if ! ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o BatchMode=yes "$TARGET_USER@$TARGET_SERVER" "exit 0"; then
        log_error "Cannot connect to $TARGET_SERVER via SSH. Check the server address, credentials, and SSH key."
        exit 1
    fi
    log_success "SSH connection successful"
fi

# Upload deployment package
UPLOAD_COMMAND="scp -i '$SSH_KEY_PATH' '$DEPLOY_DIR/$DEPLOYMENT_PACKAGE' '$TARGET_USER@$TARGET_SERVER:/tmp/'"
run_command "$UPLOAD_COMMAND" "Uploading deployment package to $TARGET_SERVER"

# Create target directory and extract package
EXTRACT_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'mkdir -p $TARGET_DIR && cd $TARGET_DIR && rm -rf * && tar -xzf /tmp/$DEPLOYMENT_PACKAGE && rm /tmp/$DEPLOYMENT_PACKAGE'"
run_command "$EXTRACT_COMMAND" "Extracting deployment package to $TARGET_DIR"

# Verify Docker is installed on target server (if not installed, install it)
DOCKER_CHECK_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'command -v docker &> /dev/null && echo \"installed\" || echo \"missing\"'"
if [[ "$DRY_RUN" != true ]]; then
    DOCKER_STATUS=$(eval "$DOCKER_CHECK_COMMAND")
    if [[ "$DOCKER_STATUS" == "missing" ]]; then
        log_warning "Docker not found on target server. Installing Docker..."
        INSTALL_DOCKER_COMMAND="
            ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' '
                curl -fsSL https://get.docker.com -o get-docker.sh && 
                sh get-docker.sh && 
                usermod -aG docker $TARGET_USER && 
                rm get-docker.sh
            '"
        run_command "$INSTALL_DOCKER_COMMAND" "Installing Docker on $TARGET_SERVER"
    else
        log "Docker already installed on target server"
    fi
fi

# Verify Docker Compose is installed
COMPOSE_CHECK_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'command -v docker-compose &> /dev/null && echo \"installed\" || echo \"missing\"'"
if [[ "$DRY_RUN" != true ]]; then
    COMPOSE_STATUS=$(eval "$COMPOSE_CHECK_COMMAND")
    if [[ "$COMPOSE_STATUS" == "missing" ]]; then
        log_warning "Docker Compose not found. Installing Docker Compose plugin..."
        INSTALL_COMPOSE_COMMAND="
            ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' '
                apt-get update && 
                apt-get install -y docker-compose-plugin
            '"
        run_command "$INSTALL_COMPOSE_COMMAND" "Installing Docker Compose on $TARGET_SERVER"
    else
        log "Docker Compose already installed on target server"
    fi
fi

# Setup script execution (if available)
if [[ -f "$DEPLOY_DIR/setup.sh" ]]; then
    SETUP_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && chmod +x setup.sh && ./setup.sh'"
    run_command "$SETUP_COMMAND" "Running setup script on $TARGET_SERVER"
fi

# If .env file exists in the package, ensure it's properly configured
if [[ -f ".env" ]]; then
    log "Verifying .env file exists on target server"
    if [[ "$DRY_RUN" != true ]]; then
        ENV_CHECK_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && test -f .env && echo \"exists\" || echo \"missing\"'"
        ENV_EXISTS=$(eval "$ENV_CHECK_COMMAND")
        if [[ "$ENV_EXISTS" == "missing" ]]; then
            log_error ".env file not found on target server after deployment"
            exit 1
        fi
    fi
fi

# Pull latest images
PULL_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && docker-compose pull'"
run_command "$PULL_COMMAND" "Pulling latest Docker images on $TARGET_SERVER"

# Start the stack
DEPLOY_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && docker-compose up -d'"
run_command "$DEPLOY_COMMAND" "Starting PotatoStack services on $TARGET_SERVER"

# Wait for services to start
if [[ "$DRY_RUN" != true ]]; then
    log "Waiting for services to start..."
    sleep 30
    
    # Check service status
    STATUS_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && docker-compose ps --format \"table {{.Names}}\t{{.Status}}\"'"
    log "Checking service status on $TARGET_SERVER:"
    eval "$STATUS_COMMAND"
fi

# Run post-deployment validation
if [[ "$DRY_RUN" != true ]]; then
    log "Running post-deployment validation..."
    
    # Wait a bit more for services to be fully ready
    sleep 30
    
    # Check if docker-compose is reporting any errors
    LOGS_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && docker-compose ps'"
    SERVICES_STATUS=$(eval "$LOGS_COMMAND")
    
    if echo "$SERVICES_STATUS" | grep -q "Exit"; then
        log_error "Some services failed to start. Check the output above for details."
        # Show logs for failed services
        FAILED_SERVICES=$(echo "$SERVICES_STATUS" | grep "Exit" | awk '{print $1}')
        for service in $FAILED_SERVICES; do
            log "Logs for failed service $service:"
            LOG_COMMAND="ssh -i '$SSH_KEY_PATH' '$TARGET_USER@$TARGET_SERVER' 'cd $TARGET_DIR && docker-compose logs -n 20 $service'"
            eval "$LOG_COMMAND"
        done
        exit 1
    else
        log_success "All services appear to be running successfully"
    fi
fi

# Clean up
if [[ "$DRY_RUN" != true ]]; then
    rm -rf "$DEPLOY_DIR"
fi

log_success "✅ PotatoStack successfully deployed to $ENVIRONMENT environment on $TARGET_SERVER"
log "Deployment package: $DEPLOYMENT_PACKAGE"
log "Target directory: $TARGET_DIR"

if [[ "$ENVIRONMENT" == "production" ]]; then
    log_warning "⚠️  Remember to configure Nginx Proxy Manager for HTTPS and proper reverse proxy on production"
    log_warning "⚠️  Check that all services are accessible and properly secured"
fi

log "Access your services at the addresses configured in your docker-compose.yml file"