#!/bin/bash
################################################################################
# Add Hooks to Backrest Config (Simplified)
# Directly adds hooks to config.json
################################################################################

set -euo pipefail

CONFIG_FILE="/mnt/ssd/docker-data/backrest/config/config.json"
BACKUP_HOOK_SCRIPT="/hooks/backrest-notify.sh"
TEMP_CONFIG="/tmp/backrest_config_updated.json"

echo "=========================================="
echo "Adding Backrest Hooks to Config"
echo "=========================================="

if [ ! -f "$CONFIG_FILE" ]; then
	echo "❌ Config file not found: $CONFIG_FILE"
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "❌ jq is required"
	exit 1
fi

echo "✓ Found config: $CONFIG_FILE"

# Backup the original config
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backed up original config"

# Add hooks to Backup plan
jq '
  .plans |= map(
    if .id == "Backup" then
      . + {"hooks": [
        {
          "name": "Critical Error Alerts",
          "action": "/hooks/backrest-notify.sh",
          "conditions": ["CONDITION_SNAPSHOT_ERROR", "CONDITION_PRUNE_ERROR", "CONDITION_CHECK_ERROR", "CONDITION_FORGET_ERROR", "CONDITION_ANY_ERROR"],
          "onError": "ON_ERROR_IGNORE"
        },
        {
          "name": "Warning Alerts",
          "action": "/hooks/backrest-notify.sh",
          "conditions": ["CONDITION_SNAPSHOT_WARNING"],
          "onError": "ON_ERROR_IGNORE"
        },
        {
          "name": "Backup Success Alerts",
          "action": "/hooks/backrest-notify.sh",
          "conditions": ["CONDITION_SNAPSHOT_START", "CONDITION_SNAPSHOT_SUCCESS", "CONDITION_PRUNE_SUCCESS", "CONDITION_CHECK_SUCCESS", "CONDITION_FORGET_SUCCESS"],
          "onError": "ON_ERROR_IGNORE"
        }
      ]}
    else
      .
    end
  )
' "$CONFIG_FILE" >"$TEMP_CONFIG"

echo "✓ Added 3 hooks to 'Backup' plan"

# Replace original config
mv "$TEMP_CONFIG" "$CONFIG_FILE"
echo "✓ Config updated"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Restart backrest:"
echo "   docker compose restart backrest"
echo ""
echo "2. Verify in backrest UI:"
echo "   http://localhost:9898"
echo "   Check Plan → Backup → Hooks section"
echo ""
echo "3. Test by triggering a backup manually"
