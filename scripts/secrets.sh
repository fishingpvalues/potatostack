#!/bin/bash

################################################################################
# PotatoStack Unified Secrets Manager
# Combines: setup-secrets.sh + edit-secrets.sh + setup-decrypt-service.sh
# Manages encrypted secrets using age encryption
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_ROOT/.secrets"
AGE_KEY_FILE="$HOME/.age/potatostack.key"
AGE_PUBLIC_KEY_FILE="$HOME/.age/potatostack.pub"

# Help message
show_help() {
    cat << EOF
PotatoStack Unified Secrets Manager

USAGE:
    ./scripts/secrets.sh <command> [options]

COMMANDS:
    init                Initialize secret store and generate age key pair
    edit [secret-name]  Edit an encrypted secret file
    decrypt [secret]    Decrypt a secret file to stdout
    encrypt [file]      Encrypt a file
    setup-service       Install systemd decrypt service
    list                List all encrypted secrets
    help                Show this help message

EXAMPLES:
    ./scripts/secrets.sh init                   # First-time setup
    ./scripts/secrets.sh edit .env              # Edit encrypted .env file
    ./scripts/secrets.sh decrypt .env           # Decrypt .env to stdout
    ./scripts/secrets.sh list                   # List all secrets
    ./scripts/secrets.sh setup-service          # Install systemd service

NOTES:
    - Secrets are encrypted using age (https://age-encryption.org/)
    - Private key is stored at: $AGE_KEY_FILE
    - Public key is stored at: $AGE_PUBLIC_KEY_FILE
    - Encrypted secrets are stored in: $SECRETS_DIR/
    - Original files are never modified

REQUIREMENTS:
    - age encryption tool (install: apt install age)
    - Editor (EDITOR env var, defaults to nano)
EOF
    exit 0
}

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if age is installed
check_age() {
    if ! command -v age &> /dev/null; then
        log_error "age encryption tool not found"
        log "Install with: sudo apt install age"
        log "Or download from: https://age-encryption.org/"
        exit 1
    fi
}

# Initialize secrets store
init_secrets() {
    log "Initializing PotatoStack secrets store..."

    check_age

    # Create directories
    mkdir -p "$SECRETS_DIR"
    mkdir -p "$(dirname "$AGE_KEY_FILE")"

    # Generate age key pair if not exists
    if [ -f "$AGE_KEY_FILE" ]; then
        log_warning "Age key pair already exists at $AGE_KEY_FILE"
        log "Skipping key generation"
    else
        log "Generating age key pair..."
        age-keygen -o "$AGE_KEY_FILE" 2>/dev/null

        # Extract public key
        grep "public key:" "$AGE_KEY_FILE" | awk '{print $NF}' > "$AGE_PUBLIC_KEY_FILE"

        # Secure the private key
        chmod 600 "$AGE_KEY_FILE"
        chmod 644 "$AGE_PUBLIC_KEY_FILE"

        log_success "Age key pair generated"
        log "Private key: $AGE_KEY_FILE"
        log "Public key:  $(cat "$AGE_PUBLIC_KEY_FILE")"
    fi

    # Create .gitignore in secrets directory
    cat > "$SECRETS_DIR/.gitignore" << 'EOF'
# Decrypted secrets (never commit)
*.decrypted
*.plain
*.tmp

# Only encrypted files (.age) should be committed
!*.age
EOF

    log_success "Secrets store initialized at $SECRETS_DIR"
    log ""
    log "Next steps:"
    log "  1. Edit a secret: ./scripts/secrets.sh edit .env"
    log "  2. Encrypt a file: ./scripts/secrets.sh encrypt myfile.txt"
    log "  3. Backup your private key: $AGE_KEY_FILE"
}

# Edit an encrypted secret
edit_secret() {
    local SECRET_NAME="${1:-.env}"
    local ENCRYPTED_FILE="$SECRETS_DIR/${SECRET_NAME}.age"
    local TEMP_FILE="$SECRETS_DIR/${SECRET_NAME}.tmp"

    check_age

    if [ ! -f "$AGE_KEY_FILE" ]; then
        log_error "Age key not found. Run: ./scripts/secrets.sh init"
        exit 1
    fi

    log "Editing secret: $SECRET_NAME"

    # Decrypt to temp file if exists
    if [ -f "$ENCRYPTED_FILE" ]; then
        log "Decrypting existing secret..."
        age -d -i "$AGE_KEY_FILE" -o "$TEMP_FILE" "$ENCRYPTED_FILE" 2>/dev/null || {
            log_error "Failed to decrypt $ENCRYPTED_FILE"
            exit 1
        }
    else
        log "Creating new secret file..."
        touch "$TEMP_FILE"
    fi

    # Secure temp file
    chmod 600 "$TEMP_FILE"

    # Edit the file
    ${EDITOR:-nano} "$TEMP_FILE"

    # Encrypt back
    log "Encrypting secret..."
    AGE_PUBLIC_KEY=$(cat "$AGE_PUBLIC_KEY_FILE")
    age -R "$AGE_PUBLIC_KEY_FILE" -o "$ENCRYPTED_FILE" "$TEMP_FILE" 2>/dev/null || {
        log_error "Failed to encrypt $TEMP_FILE"
        rm -f "$TEMP_FILE"
        exit 1
    }

    # Clean up temp file
    shred -u "$TEMP_FILE" 2>/dev/null || rm -f "$TEMP_FILE"

    log_success "Secret encrypted and saved: $ENCRYPTED_FILE"
    log ""
    log "To decrypt: ./scripts/secrets.sh decrypt $SECRET_NAME"
}

# Decrypt a secret to stdout
decrypt_secret() {
    local SECRET_NAME="${1:-.env}"
    local ENCRYPTED_FILE="$SECRETS_DIR/${SECRET_NAME}.age"

    check_age

    if [ ! -f "$AGE_KEY_FILE" ]; then
        log_error "Age key not found. Run: ./scripts/secrets.sh init"
        exit 1
    fi

    if [ ! -f "$ENCRYPTED_FILE" ]; then
        log_error "Encrypted secret not found: $ENCRYPTED_FILE"
        exit 1
    fi

    age -d -i "$AGE_KEY_FILE" "$ENCRYPTED_FILE" 2>/dev/null || {
        log_error "Failed to decrypt $ENCRYPTED_FILE"
        exit 1
    }
}

# Encrypt a file
encrypt_file() {
    local FILE="${1}"

    if [ -z "$FILE" ]; then
        log_error "Usage: ./scripts/secrets.sh encrypt <file>"
        exit 1
    fi

    if [ ! -f "$FILE" ]; then
        log_error "File not found: $FILE"
        exit 1
    fi

    check_age

    if [ ! -f "$AGE_KEY_FILE" ]; then
        log_error "Age key not found. Run: ./scripts/secrets.sh init"
        exit 1
    fi

    local BASENAME=$(basename "$FILE")
    local ENCRYPTED_FILE="$SECRETS_DIR/${BASENAME}.age"

    log "Encrypting: $FILE"
    age -R "$AGE_PUBLIC_KEY_FILE" -o "$ENCRYPTED_FILE" "$FILE" 2>/dev/null || {
        log_error "Failed to encrypt $FILE"
        exit 1
    }

    log_success "File encrypted: $ENCRYPTED_FILE"
    log ""
    log_warning "Remember to securely delete the original file if needed"
    log "  shred -u $FILE"
}

# List all encrypted secrets
list_secrets() {
    log "Encrypted secrets in $SECRETS_DIR:"
    echo ""

    if [ ! -d "$SECRETS_DIR" ]; then
        log_warning "Secrets directory not found. Run: ./scripts/secrets.sh init"
        exit 0
    fi

    local COUNT=0
    while IFS= read -r -d '' file; do
        local BASENAME=$(basename "$file" .age)
        local SIZE=$(du -h "$file" | cut -f1)
        local DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d':' -f1,2)
        echo "  - $BASENAME ($SIZE, modified: $DATE)"
        ((COUNT++))
    done < <(find "$SECRETS_DIR" -name "*.age" -type f -print0 2>/dev/null)

    echo ""
    if [ $COUNT -eq 0 ]; then
        log "No encrypted secrets found"
    else
        log "Total: $COUNT encrypted secret(s)"
    fi
}

# Setup systemd decrypt service
setup_decrypt_service() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This command must be run as root"
        log "Use: sudo ./scripts/secrets.sh setup-service"
        exit 1
    fi

    log "Installing PotatoStack decrypt service..."

    # Create decrypt script
    cat > /usr/local/bin/potatostack-decrypt-secrets.sh << 'EOF'
#!/bin/bash
# PotatoStack Secrets Decryption Service
# Decrypts encrypted secrets on boot

set -e

SECRETS_DIR="/opt/potatostack/.secrets"
AGE_KEY="/root/.age/potatostack.key"
POTATOSTACK_DIR="/opt/potatostack"

if [ ! -f "$AGE_KEY" ]; then
    echo "Age key not found at $AGE_KEY"
    exit 1
fi

# Decrypt .env if exists
if [ -f "$SECRETS_DIR/.env.age" ]; then
    age -d -i "$AGE_KEY" -o "$POTATOSTACK_DIR/.env" "$SECRETS_DIR/.env.age"
    chmod 600 "$POTATOSTACK_DIR/.env"
    echo "Decrypted .env"
fi

# Decrypt other secrets as needed
# Add more decryption commands here

echo "Secrets decryption complete"
EOF

    chmod +x /usr/local/bin/potatostack-decrypt-secrets.sh

    # Create systemd service
    cat > /etc/systemd/system/potatostack-decrypt.service << EOF
[Unit]
Description=PotatoStack Secrets Decryption Service
Before=docker.service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/potatostack-decrypt-secrets.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
    systemctl enable potatostack-decrypt.service

    log_success "Decrypt service installed"
    log ""
    log "The service will decrypt secrets on boot before Docker starts"
    log "To test: sudo systemctl start potatostack-decrypt"
    log "To check: sudo systemctl status potatostack-decrypt"
}

# Main
case "${1:-help}" in
    init)
        init_secrets
        ;;
    edit)
        edit_secret "${2:-}"
        ;;
    decrypt)
        decrypt_secret "${2:-}"
        ;;
    encrypt)
        encrypt_file "${2:-}"
        ;;
    list)
        list_secrets
        ;;
    setup-service)
        setup_decrypt_service
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        ;;
esac

exit 0
