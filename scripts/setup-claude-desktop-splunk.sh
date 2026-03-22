#!/usr/bin/env bash
# setup-claude-desktop-splunk.sh
# Configures the Splunk MCP server in Claude Desktop on macOS.
#
# Claude Desktop uses a separate config from Claude Code and does not source
# your shell profile. This script writes the mcpServers block directly into
# ~/Library/Application Support/Claude/claude_desktop_config.json.
#
# Prerequisites:
#   - macOS only
#   - Node.js + npx installed
#   - SPLUNK_HOST and SPLUNK_TOKEN set (via ~/.claude/env.sh or env vars)
#
# Usage:
#   ./scripts/setup-claude-desktop-splunk.sh
#   SPLUNK_HOST=10.x.x.x SPLUNK_TOKEN=xxx ./scripts/setup-claude-desktop-splunk.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*"; exit 1; }

# ── macOS only ──────────────────────────────────────────────────────────────
if [[ "$OSTYPE" != "darwin"* ]]; then
  error "This script is macOS only. Claude Desktop is not available on other platforms."
fi

# ── Dependencies ────────────────────────────────────────────────────────────
if ! command -v npx &>/dev/null; then
  error "npx not found. Install Node.js first: brew install node"
fi

if ! command -v python3 &>/dev/null; then
  error "python3 not found. Required for JSON manipulation."
fi

# ── Load tokens ─────────────────────────────────────────────────────────────
ENV_FILE="$HOME/.claude/env.sh"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE" 2>/dev/null || true
fi

SPLUNK_HOST="${SPLUNK_HOST:-}"
SPLUNK_TOKEN="${SPLUNK_TOKEN:-}"

if [[ -z "$SPLUNK_HOST" ]]; then
  warn "SPLUNK_HOST not set."
  read -rp "    Enter Splunk host (hostname or IP, no port): " SPLUNK_HOST
fi

if [[ -z "$SPLUNK_TOKEN" ]]; then
  warn "SPLUNK_TOKEN not set."
  read -rsp "    Enter Splunk MCP token: " SPLUNK_TOKEN
  echo ""
fi

if [[ -z "$SPLUNK_HOST" || -z "$SPLUNK_TOKEN" ]]; then
  error "SPLUNK_HOST and SPLUNK_TOKEN are both required."
fi

# ── Claude Desktop config ───────────────────────────────────────────────────
DESKTOP_CONFIG_DIR="$HOME/Library/Application Support/Claude"
DESKTOP_CONFIG="$DESKTOP_CONFIG_DIR/claude_desktop_config.json"

mkdir -p "$DESKTOP_CONFIG_DIR"

# Create config file if it doesn't exist
if [[ ! -f "$DESKTOP_CONFIG" ]]; then
  echo '{}' > "$DESKTOP_CONFIG"
  info "Created $DESKTOP_CONFIG"
fi

info "Updating $DESKTOP_CONFIG..."

# Backup existing config
cp "$DESKTOP_CONFIG" "${DESKTOP_CONFIG}.bak"
info "Backed up existing config to ${DESKTOP_CONFIG}.bak"

# Merge mcpServers block into existing config using python3
python3 - "$DESKTOP_CONFIG" "$SPLUNK_HOST" "$SPLUNK_TOKEN" <<'PYEOF'
import sys, json

config_path = sys.argv[1]
splunk_host = sys.argv[2]
splunk_token = sys.argv[3]

with open(config_path, 'r') as f:
    config = json.load(f)

config.setdefault('mcpServers', {})
config['mcpServers']['splunk-mcp-server'] = {
    "command": "npx",
    "args": [
        "-y",
        "mcp-remote@0.1.38",
        f"https://{splunk_host}:8089/services/mcp",
        "--header",
        f"Authorization: Bearer {splunk_token}"
    ],
    "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
    }
}

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
PYEOF

info "splunk-mcp-server written to Claude Desktop config."

# ── Verify ───────────────────────────────────────────────────────────────────
echo ""
info "Result:"
python3 -c "
import json
with open('$DESKTOP_CONFIG') as f:
    d = json.load(f)
server = d.get('mcpServers', {}).get('splunk-mcp-server', {})
args = server.get('args', [])
# Redact token from output
sanitised = []
redact_next = False
for a in args:
    if redact_next:
        sanitised.append('<SPLUNK_TOKEN>')
        redact_next = False
    elif a.startswith('Authorization: Bearer'):
        sanitised.append('Authorization: Bearer <SPLUNK_TOKEN>')
    elif a == '--header':
        sanitised.append(a)
        redact_next = True
    else:
        sanitised.append(a)
print(json.dumps({'command': server.get('command'), 'args': sanitised, 'env': server.get('env')}, indent=2))
"

echo ""
warn "Restart Claude Desktop for the change to take effect."
warn "If the server doesn't connect, check logs at:"
warn "  ~/Library/Logs/Claude/mcp-server-splunk-mcp-server.log"
echo ""
info "Done."
