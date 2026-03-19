#!/usr/bin/env bash
# webex-oauth.sh — One-time Webex OAuth setup
# Obtains an access token and refresh token, writes them to ~/.claude/env.sh
# Requires: curl, python3
# Run once per machine, or re-run if the refresh token is revoked

set -euo pipefail

ENV_FILE="$HOME/.claude/env.sh"
REDIRECT_URI="http://localhost:8765/callback"
SCOPE="spark:messages_write spark:people_read spark:rooms_read"

echo ""
echo "=== Webex OAuth Setup ==="
echo ""
echo "Before running this script:"
echo "  1. Go to https://developer.webex.com/my-apps"
echo "  2. Create an Integration with redirect URI: $REDIRECT_URI"
echo "  3. Enable scopes: spark:messages_write, spark:people_read, spark:rooms_read"
echo ""

# Load existing credentials from env.sh if present
source "$ENV_FILE" 2>/dev/null || true

# Use stored values as defaults if already set
DEFAULT_CLIENT_ID="${WEBEX_CLIENT_ID:-}"
DEFAULT_CLIENT_SECRET="${WEBEX_CLIENT_SECRET:-}"

if [[ -n "$DEFAULT_CLIENT_ID" ]]; then
  read -rp "Enter your Webex Integration Client ID [$DEFAULT_CLIENT_ID]: " INPUT_CLIENT_ID
  CLIENT_ID="${INPUT_CLIENT_ID:-$DEFAULT_CLIENT_ID}"
else
  read -rp "Enter your Webex Integration Client ID: " CLIENT_ID
fi

if [[ -n "$DEFAULT_CLIENT_SECRET" ]]; then
  read -rsp "Enter your Webex Integration Client Secret [stored]: " INPUT_CLIENT_SECRET
  echo ""
  CLIENT_SECRET="${INPUT_CLIENT_SECRET:-$DEFAULT_CLIENT_SECRET}"
else
  read -rsp "Enter your Webex Integration Client Secret: " CLIENT_SECRET
  echo ""
fi

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  echo "Error: Client ID and Client Secret are required."
  exit 1
fi

# Build the auth URL
ENCODED_REDIRECT=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REDIRECT_URI'))")
ENCODED_SCOPE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SCOPE'))")
AUTH_URL="https://webexapis.com/v1/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${ENCODED_REDIRECT}&scope=${ENCODED_SCOPE}&state=claude_setup"

echo ""
echo "Opening Webex authorization in your browser..."
echo "If it doesn't open automatically, visit this URL:"
echo ""
echo "$AUTH_URL"
echo ""

# Open browser (macOS or Linux)
if command -v open &>/dev/null; then
  open "$AUTH_URL"
elif command -v xdg-open &>/dev/null; then
  xdg-open "$AUTH_URL" 2>/dev/null &
fi

echo "Waiting for Webex to redirect back (listening on port 8765)..."
echo ""

AUTH_CODE=$(python3 - <<'PYEOF'
import http.server
import urllib.parse

class CallbackHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        if 'code' in params:
            self.server.auth_code = params['code'][0]
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<html><body><h2>Authorisation successful!</h2><p>You can close this tab and return to the terminal.</p></body></html>')
        else:
            error = params.get('error', ['unknown'])[0]
            self.server.auth_code = None
            self.send_response(400)
            self.end_headers()
            self.wfile.write(f'<html><body><h2>Error: {error}</h2></body></html>'.encode())
    def log_message(self, format, *args):
        pass

server = http.server.HTTPServer(('localhost', 8765), CallbackHandler)
server.auth_code = None
server.handle_request()
print(server.auth_code or '', end='')
PYEOF
)

if [[ -z "$AUTH_CODE" ]]; then
  echo "Error: Failed to capture authorisation code. Did you approve the request?"
  exit 1
fi

echo "Authorisation code received. Exchanging for tokens..."

# Exchange code for access + refresh tokens
TOKEN_RESPONSE=$(curl -s -X POST "https://webexapis.com/v1/access_token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "code=${AUTH_CODE}" \
  --data-urlencode "redirect_uri=${REDIRECT_URI}" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))")
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('refresh_token',''))")

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Error: Failed to obtain access token. Response:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

# Write to env.sh — update existing values or append
update_or_append() {
  local key="$1"
  local value="$2"
  local file="$3"
  if grep -q "^export ${key}=" "$file" 2>/dev/null; then
    local tmp
    tmp=$(mktemp)
    sed "s|^export ${key}=.*|export ${key}=\"${value}\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    echo "export ${key}=\"${value}\"" >> "$file"
  fi
}

touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

update_or_append "WEBEX_CLIENT_ID" "$CLIENT_ID" "$ENV_FILE"
update_or_append "WEBEX_CLIENT_SECRET" "$CLIENT_SECRET" "$ENV_FILE"
update_or_append "WEBEX_TOKEN" "$ACCESS_TOKEN" "$ENV_FILE"
[[ -n "$REFRESH_TOKEN" ]] && update_or_append "WEBEX_REFRESH_TOKEN" "$REFRESH_TOKEN" "$ENV_FILE"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Credentials written to: $ENV_FILE"
echo "Webex access tokens expire after 14 days but refresh tokens last 90 days."
echo "The /webex-update skill will auto-refresh using the refresh token."
echo "Re-run this script only if the refresh token is revoked."
echo ""
echo "You can now use the /webex-update skill in Claude Code."
