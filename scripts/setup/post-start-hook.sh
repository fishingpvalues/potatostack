#!/bin/bash
################################################################################
# PotatoStack Post-Start Hook Script
# This script runs automatically after the stack starts
# It applies system-level fixes that cannot be done via docker-compose
################################################################################

set -euo pipefail

# Source environment
export $(grep -v '^#' /home/daniel/potatostack/.env | xargs) 2>/dev/null || true

# Run the fixes
/home/daniel/potatostack/scripts/setup/apply-log-fixes.sh

# Log completion
echo "$(date): PotatoStack post-start fixes completed" >>/var/log/potatostack-restarts.log
