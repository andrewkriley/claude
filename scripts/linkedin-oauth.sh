#!/usr/bin/env bash
# linkedin-oauth.sh — One-time LinkedIn OAuth setup
# Obtains an access token and Person URN, writes them to ~/.claude/env.sh
# Requires: curl, python3
# Run once per machine, or re-run when the token expires (~60 days)

set -euo pipefail

ENV_FILE="$HOME/.claude/env.sh"
REDIRECT_URI="http://localhost:8080/callback"
SCOPE="openid profile w_member_social"

echo ""
echo "=== LinkedIn OAuth Setup ==="
echo ""
echo "Before running this script:"
echo "  1. Go to https://www.linkedin.com/developers/ and create an app"
echo "  2. Under Products, add 'Share on LinkedIn' and 'Sign In with LinkedIn using OpenID Connect'"
echo "  3. Under Auth, add this Redirect URL: $REDIRECT_URI"
echo ""

# Prompt for app credentials
read -rp "Enter your LinkedIn App Client ID: " CLIENT_ID
read -rsp "Enter your LinkedIn App Client Secret: " CLIENT_SECRET
echo ""

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  echo "Error: Client ID and Client Secret are required."
  exit 1
fi

# Build the auth URL
AUTH_URL="https://www.linkedin.com/oauth/v2/authorization?response_type=code&client_id=${CLIENT_ID}&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REDIRECT_URI'))")&scope=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SCOPE'))")&state=claude_setup"

echo ""
echo "Opening LinkedIn authorization in your browser..."
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

# Start local HTTP server to capture the callback
echo "Waiting for LinkedIn to redirect back (listening on port 8080)..."
echo ""

AUTH_CODE=$(python3 - <<'PYEOF'
import http.server
import urllib.parse
import sys

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

server = http.server.HTTPServer(('localhost', 8080), CallbackHandler)
server.auth_code = None
server.handle_request()
print(server.auth_code or '', end='')
PYEOF
)

if [[ -z "$AUTH_CODE" ]]; then
  echo "Error: Failed to capture authorisation code. Did you approve the request?"
  exit 1
fi

echo "Authorisation code received. Exchanging for access token..."

# Exchange code for token
TOKEN_RESPONSE=$(curl -s -X POST "https://www.linkedin.com/oauth/v2/accessToken" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))")
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('refresh_token',''))" 2>/dev/null || echo "")

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Error: Failed to obtain access token. Response:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "Access token obtained. Fetching your LinkedIn Person URN..."

# Get Person URN
USERINFO=$(curl -s "https://api.linkedin.com/v2/userinfo" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

PERSON_ID=$(echo "$USERINFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sub',''))")

if [[ -z "$PERSON_ID" ]]; then
  echo "Error: Failed to fetch Person ID. Response:"
  echo "$USERINFO"
  exit 1
fi

PERSON_URN="urn:li:person:${PERSON_ID}"
echo "Person URN: $PERSON_URN"

# Write to env.sh — update existing values or append
update_or_append() {
  local key="$1"
  local value="$2"
  local file="$3"
  if grep -q "^export ${key}=" "$file" 2>/dev/null; then
    # Use a temp file for compatibility with both macOS and Linux sed
    local tmp
    tmp=$(mktemp)
    sed "s|^export ${key}=.*|export ${key}=\"${value}\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    echo "export ${key}=\"${value}\"" >> "$file"
  fi
}

# Ensure env.sh exists
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

update_or_append "LINKEDIN_CLIENT_ID" "$CLIENT_ID" "$ENV_FILE"
update_or_append "LINKEDIN_CLIENT_SECRET" "$CLIENT_SECRET" "$ENV_FILE"
update_or_append "LINKEDIN_TOKEN" "$ACCESS_TOKEN" "$ENV_FILE"
update_or_append "LINKEDIN_PERSON_URN" "$PERSON_URN" "$ENV_FILE"
[[ -n "$REFRESH_TOKEN" ]] && update_or_append "LINKEDIN_REFRESH_TOKEN" "$REFRESH_TOKEN" "$ENV_FILE"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Credentials written to: $ENV_FILE"
echo "LinkedIn token is valid for approximately 60 days."
echo "Re-run this script when it expires."
echo ""
echo "You can now use the /linkedin-post skill in Claude Code."
