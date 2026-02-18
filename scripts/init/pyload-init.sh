#!/bin/bash
################################################################################
# pyLoad Init Script - Configure user credentials from environment
################################################################################

PYLOAD_USER="${PYLOAD_USER:-pyload}"
PYLOAD_PASSWORD="${PYLOAD_PASSWORD:-}"
DB_FILE="/config/data/pyload.db"
REALDEBRID_API_KEY="${REALDEBRID_API_KEY:-}"
TORBOX_API_KEY="${TORBOX_API_KEY:-}"
NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-potatostack}"
NTFY_TOKEN="${NTFY_TOKEN:-}"
PYLOAD_ENABLE_NTFY_HOOKS="${PYLOAD_ENABLE_NTFY_HOOKS:-true}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                      pyLoad Init Script                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

setup_ntfy_hooks() {
	if [ "$PYLOAD_ENABLE_NTFY_HOOKS" != "true" ] || [ -z "$NTFY_TOPIC" ]; then
		return
	fi

	hook_dir="/config/scripts/download_finished"
	hook_script="${hook_dir}/ntfy.sh"
	mkdir -p "$hook_dir"

	cat >"$hook_script" <<EOF
#!/bin/sh
NTFY_INTERNAL_URL="${NTFY_INTERNAL_URL}"
NTFY_TOPIC="${NTFY_TOPIC}"
NTFY_TOKEN="${NTFY_TOKEN}"

title="PotatoStack - pyLoad download finished"
file_name="\${2:-unknown}"
file_path="\${3:-unknown}"
plugin="\${4:-unknown}"
url="\${5:-unknown}"
package="\${6:-unknown}"
message="File: \${file_name}\\nPackage: \${package}\\nPlugin: \${plugin}\\nPath: \${file_path}\\nURL: \${url}"

url_target="\${NTFY_INTERNAL_URL%/}/\${NTFY_TOPIC}"

if command -v curl >/dev/null 2>&1; then
    if [ -n "\$NTFY_TOKEN" ]; then
        curl -fsS -X POST "\$url_target" -H "Title: \$title" -H "Tags: pyload,download" -H "Priority: default" -H "Authorization: Bearer \$NTFY_TOKEN" -d "\$message" >/dev/null 2>&1 || true
    else
        curl -fsS -X POST "\$url_target" -H "Title: \$title" -H "Tags: pyload,download" -H "Priority: default" -d "\$message" >/dev/null 2>&1 || true
    fi
elif command -v wget >/dev/null 2>&1; then
    headers="--header=Title: \$title --header=Tags: pyload,download --header=Priority: default"
    if [ -n "\$NTFY_TOKEN" ]; then
        headers="\$headers --header=Authorization: Bearer \$NTFY_TOKEN"
    fi
    # shellcheck disable=SC2086
    wget -q --post-data "\$message" \$headers "\$url_target" >/dev/null 2>&1 || true
fi
EOF

	chmod +x "$hook_script"
	echo "✓ pyLoad ntfy hook installed: $hook_script"
}

# Install ntfy hook for download finished events
setup_ntfy_hooks

# Wait for initial setup to create database
MAX_WAIT=30
WAITED=0
while [ ! -f "$DB_FILE" ] && [ $WAITED -lt $MAX_WAIT ]; do
	echo "Waiting for pyLoad database to be created..."
	sleep 2
	WAITED=$((WAITED + 2))
done

if [ ! -f "$DB_FILE" ]; then
	echo "⚠ Database not found after ${MAX_WAIT}s, will configure on next restart"
	exec /init "$@"
fi

# Configure user if password is set
if [ -n "$PYLOAD_PASSWORD" ]; then
	echo "Configuring pyLoad user credentials..."

	# Generate PBKDF2-HMAC-SHA256 hash (pyload-ng format: 32-char salt hex + 64-char derived key hex)
	HASH=$(printf '%s' "$PYLOAD_PASSWORD" | python3 -c "
import hashlib, os, sys
password = sys.stdin.read()
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 100000)
print(salt.hex() + dk.hex())
" 2>/dev/null)

	if [ -n "$HASH" ]; then
		# Check if user exists
		USER_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE name='$PYLOAD_USER';" 2>/dev/null)

		if [ "$USER_EXISTS" = "0" ]; then
			# Create new user with admin role (role=0 is ADMIN in pyload-ng)
			sqlite3 "$DB_FILE" "INSERT INTO users (name, password, role, permission, template) VALUES ('$PYLOAD_USER', '$HASH', 0, 0, 'default');"
			echo "✓ Created user: $PYLOAD_USER (admin)"
		else
			# Update existing user password and ensure admin role
			sqlite3 "$DB_FILE" "UPDATE users SET password='$HASH', role=0, permission=0 WHERE name='$PYLOAD_USER';"
			echo "✓ Updated password for user: $PYLOAD_USER"
		fi

		# Also update default 'pyload' user if different
		if [ "$PYLOAD_USER" != "pyload" ]; then
			sqlite3 "$DB_FILE" "UPDATE users SET password='$HASH' WHERE name='pyload';" 2>/dev/null || true
		fi
	else
		echo "⚠ Failed to generate password hash"
	fi
else
	echo "⚠ PYLOAD_PASSWORD not set; keeping existing credentials"
	echo "  Default login: pyload / pyload"
fi

################################################################################
# Real-Debrid Plugin Patch
# The stock RealdebridCom plugin requires OAuth credentials (client_id/secret +
# refresh_token). We patch it to also accept a direct API token as the password,
# which is what the real-debrid.com account settings page provides.
################################################################################
install_realdebrid_plugin_patch() {
	PLUGIN_DIR="/config/plugins/accounts"
	PLUGIN_FILE="${PLUGIN_DIR}/RealdebridCom.py"
	mkdir -p "$PLUGIN_DIR"

	cat >"$PLUGIN_FILE" <<'PYEOF'
# -*- coding: utf-8 -*-
# Patched: supports direct API token (password) in addition to OAuth credentials.
import json
import time

import pycurl
from pyload.core.network.http.exceptions import BadHeader

from ..base.multi_account import MultiAccount


def args(**kwargs):
    return kwargs


class RealdebridCom(MultiAccount):
    __name__ = "RealdebridCom"
    __type__ = "account"
    __version__ = "0.63"
    __status__ = "testing"

    __config__ = [
        ("mh_mode", "all;listed;unlisted", "Filter downloaders to use", "all"),
        ("mh_list", "str", "Downloader list (comma separated)", ""),
        ("mh_interval", "int", "Reload interval in hours", 12),
    ]

    __description__ = """Real-Debrid.com account plugin (patched: direct API token support)"""
    __license__ = "GPLv3"
    __authors__ = [
        ("Devirex Hazzard", "naibaf_11@yahoo.de"),
        ("GammaC0de", "nitzo2001[AT]yahoo[DOT]com"),
    ]

    API_URL = "https://api.real-debrid.com"

    def api_request(self, api_type, method, get=None, post=None):
        if api_type == "rest":
            endpoint = "/rest/1.0"
        elif api_type == "oauth":
            endpoint = "/oauth/v2"
        else:
            raise ValueError("Illegal API call type")

        self.req.http.c.setopt(pycurl.USERAGENT, "pyLoad/{}".format(self.pyload.version))
        try:
            json_data = self.load(self.API_URL + endpoint + method, get=get, post=post)
        except BadHeader as exc:
            json_data = exc.content

        return json.loads(json_data)

    def _refresh_token(self, client_id, client_secret, refresh_token):
        res = self.api_request("oauth", "/token",
                               post=args(client_id=client_id,
                                         client_secret=client_secret,
                                         code=refresh_token,
                                         grant_type="http://oauth.net/grant_type/device/1.0"))
        if 'error' in res:
            self.log_error(self._("OAuth token refresh failed. For OAuth, use GetRealdebridToken.py. "
                                  "For direct token, just set password to the API token."))
            self.fail_login()

        return res['access_token'], res['expires_in']

    def grab_hosters(self, user, password, data):
        api_data = self.api_request("rest", "/hosts/status", args(auth_token=data['api_token']))
        hosters = [x[0] for x in api_data.items() if x[1]['supported'] == 1]
        return hosters

    def grab_info(self, user, password, data):
        api_data = self.api_request("rest", "/user", args(auth_token=data['api_token']))

        premium_remain = api_data["premium"]
        premium = premium_remain > 0
        validuntil = time.time() + premium_remain if premium else -1

        return {"validuntil": validuntil, "trafficleft": -1, "premium": premium}

    def signin(self, user, password, data):
        user_parts = user.split('/')

        if len(user_parts) == 2:
            # OAuth mode: username = "client_id/client_secret", password = refresh_token
            client_id, client_secret = user_parts
            if 'api_token' not in data:
                api_token, timeout = self._refresh_token(client_id, client_secret, password)
                data['api_token'] = api_token
                self.timeout = timeout - 5 * 60
        else:
            # Direct API token mode: password IS the API token
            data['api_token'] = password

        api_token = data['api_token']
        api_data = self.api_request("rest", "/user", args(auth_token=api_token))

        if api_data.get('error_code') == 8 and len(user_parts) == 2:
            # Access token expired — refresh (OAuth mode only)
            client_id, client_secret = user_parts
            api_token, timeout = self._refresh_token(client_id, client_secret, password)
            data['api_token'] = api_token
            self.timeout = timeout - 5 * 60
        elif 'error' in api_data:
            self.log_error(api_data['error'])
            self.fail_login()
PYEOF

	echo "✓ Real-Debrid plugin patch installed"
}

################################################################################
# Debrid Account Setup (Real-Debrid)
# Writes to accounts.cfg (not SQLite — pyload-ng stores accounts there)
################################################################################
setup_debrid_accounts() {
	ACCOUNTS_CFG="/config/settings/accounts.cfg"

	# Real-Debrid via direct API token
	if [ -n "$REALDEBRID_API_KEY" ]; then
		# Ensure accounts.cfg exists and has a RealdebridCom section
		if [ ! -f "$ACCOUNTS_CFG" ]; then
			printf 'version: 1\n\nRealdebridCom:\n\n' >"$ACCOUNTS_CFG"
		fi

		# Update or insert the api entry under RealdebridCom section using Python
		python3 - "$ACCOUNTS_CFG" "$REALDEBRID_API_KEY" <<'PYEOF'
import sys, re

cfg_path = sys.argv[1]
api_key = sys.argv[2]
account_line = f"    api:{api_key}"
limit_line   = "    @limit_dl 0"

with open(cfg_path, 'r') as f:
    content = f.read()

# Remove any existing RealdebridCom account lines (lines with api:... or @limit_dl under the section)
# Strategy: replace the whole RealdebridCom block's account lines
pattern = r'(RealdebridCom:\n)([^A-Z]*?(?=\n[A-Z]|\Z))'

def replace_section(m):
    return m.group(1) + "\n" + account_line + "\n" + limit_line + "\n\n"

new_content, count = re.subn(pattern, replace_section, content, flags=re.DOTALL)

if count == 0:
    # Section doesn't exist, append it
    new_content = content.rstrip() + "\n\nRealdebridCom:\n\n" + account_line + "\n" + limit_line + "\n"

with open(cfg_path, 'w') as f:
    f.write(new_content)

print("accounts.cfg updated")
PYEOF
		echo "✓ Real-Debrid account configured in accounts.cfg (api:<token>)"
	fi

	# Torbox: no pyload-ng plugin yet (https://github.com/pyload/pyload/issues/4578)
	if [ -n "$TORBOX_API_KEY" ]; then
		echo "⚠ Torbox: pyload-ng plugin not yet available (github.com/pyload/pyload/issues/4578)"
	fi
}

install_realdebrid_plugin_patch
setup_debrid_accounts

echo "✓ pyLoad configured"
echo "  WebUI: http://localhost:8000"
echo "  User: $PYLOAD_USER"
[ -n "$REALDEBRID_API_KEY" ] && echo "  Real-Debrid: enabled"
[ -n "$TORBOX_API_KEY" ] && echo "  Torbox: pending plugin support"

# Continue with normal startup
exec /init "$@"
