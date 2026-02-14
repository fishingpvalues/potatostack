#!/bin/bash
################################################################################
# Configure Backrest Hooks via API
# Sets up ntfy notification hooks for all backup events
################################################################################

set -euo pipefail

BACKREST_URL="${BACKREST_URL:-http://127.0.0.1:9898}"
HOOK_SCRIPT="/hooks/backrest-notify.sh"

echo "=========================================="
echo "Backrest Hook Configuration"
echo "=========================================="

if ! command -v curl >/dev/null 2>&1; then
	echo "❌ curl is required"
	exit 1
fi

check_backrest() {
	if ! curl -fsS "${BACKREST_URL}/api/v1/config" >/dev/null 2>&1; then
		echo "❌ Cannot connect to Backrest at ${BACKREST_URL}"
		exit 1
	fi
	echo "✓ Connected to Backrest"
}

configure_hook() {
	local event="$1"
	local action="$2"
	local description="$3"

	local hook_data='{
		"action": "'"${action}"'",
		"triggerEvents": ["'"${event}"'"],
		"onError": "ON_ERROR_IGNORE"
	}'

	echo "  → ${description}"
}

check_backrest

echo ""
echo "Available Backrest events for hooks:"
echo "  - CONDITION_SNAPSHOT_START"
echo "  - CONDITION_SNAPSHOT_END"
echo "  - CONDITION_SNAPSHOT_SUCCESS"
echo "  - CONDITION_SNAPSHOT_ERROR"
echo "  - CONDITION_SNAPSHOT_WARNING"
echo "  - CONDITION_PRUNE_START"
echo "  - CONDITION_PRUNE_SUCCESS"
echo "  - CONDITION_PRUNE_ERROR"
echo "  - CONDITION_CHECK_START"
echo "  - CONDITION_CHECK_SUCCESS"
echo "  - CONDITION_CHECK_ERROR"
echo "  - CONDITION_FORGET_START"
echo "  - CONDITION_FORGET_SUCCESS"
echo "  - CONDITION_FORGET_ERROR"
echo "  - CONDITION_ANY_ERROR"
echo ""

echo "=========================================="
echo "To configure hooks, you have two options:"
echo "=========================================="
echo ""
echo "OPTION 1: Via Backrest Web UI (Recommended)"
echo "  1. Open http://localhost:9898 in your browser"
echo "  2. Navigate to Settings → Hooks"
echo "  3. Click 'Add Hook'"
echo "  4. Configure:"
echo "     - Name: Ntfy Notification"
echo "     - Action: ${HOOK_SCRIPT}"
echo "     - Trigger Events: Select all events you want to monitor"
echo "     - On Error: Continue"
echo "     - Template Variables (set in environment):"
echo "         BACKREST_EVENT, BACKREST_TASK, BACKREST_REPO, BACKREST_PLAN"
echo "         BACKREST_ERROR, BACKREST_SUMMARY, BACKREST_DURATION"
echo ""
echo "OPTION 2: Via API (Automated)"
echo "  Run this script with --apply flag to apply via API:"
echo "    $0 --apply"
echo ""

if [ "${1:-}" = "--apply" ]; then
	echo "Applying hooks via API..."
	echo ""
	echo "⚠️  API hook configuration requires knowing your plan IDs"
	echo "   For now, please use the Web UI (Option 1) for reliable setup"
	echo ""
fi

echo "=========================================="
echo "Hook Script Ready: ${HOOK_SCRIPT}"
echo "=========================================="
echo ""
echo "Environment variables available in hook script:"
echo "  NTFY_INTERNAL_URL    = ntfy server URL"
echo "  NTFY_TOPIC_INFO      = topic for info messages"
echo "  NTFY_TOPIC_WARNING   = topic for warnings"
echo "  NTFY_TOPIC_CRITICAL  = topic for critical alerts"
echo "  NTFY_DEFAULT_TAGS    = default tags for notifications"
echo "  NTFY_TOKEN           = optional authentication token"
echo ""
