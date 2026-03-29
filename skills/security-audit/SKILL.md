---
name: security-audit
description: Audits everything Claude has access to — MCP servers, tokens, filesystem permissions, and cloud integrations — and identifies risks, stale credentials, and unnecessary access. Produces a risk-rated report with remediation options. Run periodically or before sharing your machine.
argument-hint: [optional: focus area, e.g. "tokens" or "mcp" or "permissions"]
---

You are performing a security audit of Andrew Riley's Claude Code environment — every service, token, and permission Claude currently has access to.

## Step 1 — Collect raw access data

Run all of the following in a single Bash tool call:

```bash
echo "=ENV_TOKENS="
# Check which tokens are populated (value presence only — never print values)
source ~/.claude/env.sh 2>/dev/null || true
for var in GITHUB_TOKEN HF_TOKEN LINKEDIN_TOKEN LINKEDIN_CLIENT_ID LINKEDIN_CLIENT_SECRET LINKEDIN_PERSON_URN \
           WEBEX_TOKEN WEBEX_CLIENT_ID WEBEX_CLIENT_SECRET WEBEX_REFRESH_TOKEN \
           SPLUNK_HOST SPLUNK_TOKEN SPLUNK_API_TOKEN SPLUNK_USER SPLUNK_PASS; do
  if [[ -n "${!var:-}" ]]; then
    echo "$var=SET"
  else
    echo "$var=EMPTY"
  fi
done

echo "=MCP_SERVERS="
# List registered MCP servers (name + command only)
claude mcp list 2>/dev/null || echo "(claude CLI not available)"

echo "=SETTINGS_PERMISSIONS="
# Extract allowedTools, deniedTools, and hooks from settings.json
cat ~/.claude/settings.json 2>/dev/null || echo "(not found)"

echo "=FILESYSTEM_SCOPE="
# Find all filesystem MCP server path arguments in ~/.claude.json
python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.claude.json')) as f:
        data = json.load(f)
    servers = data.get('mcpServers', {})
    for name, cfg in servers.items():
        if 'filesystem' in name:
            args = cfg.get('args', [])
            print(f'{name}: args={args}')
except Exception as e:
    print(f'(could not parse ~/.claude.json: {e})')
" 2>/dev/null

echo "=TLS_BYPASS="
# Check if any MCP server disables TLS verification
python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.claude.json')) as f:
        data = json.load(f)
    servers = data.get('mcpServers', {})
    for name, cfg in servers.items():
        env = cfg.get('env', {})
        if env.get('NODE_TLS_REJECT_UNAUTHORIZED') == '0':
            print(f'{name}: NODE_TLS_REJECT_UNAUTHORIZED=0')
except Exception as e:
    print(f'(could not parse: {e})')
" 2>/dev/null

echo "=CLAUDE_JSON_SUMMARY="
# Show all registered MCP servers with their commands (no secret values)
python3 -c "
import json, os, re
try:
    with open(os.path.expanduser('~/.claude.json')) as f:
        data = json.load(f)
    servers = data.get('mcpServers', {})
    for name, cfg in servers.items():
        cmd = cfg.get('command', '?')
        args = cfg.get('args', [])
        # Redact anything after 'Bearer '
        safe_args = [re.sub(r'(Bearer\s+)\S+', r'\1[REDACTED]', a) for a in args]
        env_keys = list(cfg.get('env', {}).keys())
        print(f'{name}: {cmd} {\" \".join(safe_args)} | env_keys={env_keys}')
except Exception as e:
    print(f'(could not parse ~/.claude.json: {e})')
" 2>/dev/null

echo "=ENV_SH_PERMS="
stat -c '%a %n' ~/.claude/env.sh 2>/dev/null || stat -f '%A %N' ~/.claude/env.sh 2>/dev/null || echo "(cannot stat)"

echo "=CLAUDE_JSON_PERMS="
stat -c '%a %n' ~/.claude.json 2>/dev/null || stat -f '%A %N' ~/.claude.json 2>/dev/null || echo "(cannot stat)"

echo "=SETTINGS_JSON_PERMS="
stat -c '%a %n' ~/.claude/settings.json 2>/dev/null || stat -f '%A %N' ~/.claude/settings.json 2>/dev/null || echo "(cannot stat)"

echo "=SHELL_RC_SOURCE="
# Check whether env.sh is sourced from the shell RC
for rc in ~/.zshrc ~/.bashrc; do
  if [[ -f "$rc" ]]; then
    if grep -q "claude/env.sh" "$rc" 2>/dev/null; then
      echo "$rc: sources env.sh ✓"
    else
      echo "$rc: does NOT source env.sh"
    fi
  fi
done
```

## Step 2 — Filter (if $ARGUMENTS provided)

If `$ARGUMENTS` is set, focus the report on that area only:
- `tokens` — environment variables and credentials only
- `mcp` — MCP server configuration only
- `permissions` — settings.json permissions and hooks only
- `files` — file permission and filesystem scope only

Otherwise, audit all areas.

## Step 3 — Analyse and rate each finding

For each item in the audit, classify it using this risk framework:

| Rating | Meaning |
|--------|---------|
| 🔴 High | Broad write access, TLS bypass, secrets in shell history, world-readable secrets |
| 🟡 Medium | Unnecessary registered server, unused token with active scope, missing token rotation |
| 🟢 Low | Expected/intentional access that is correctly scoped |
| ℹ️ Info | Not a risk, but worth being aware of |

### Areas to assess:

**Tokens (from `~/.claude/env.sh`)**
- For each SET token: note the service it authenticates, what write access it grants, and when it was last rotated (if known from session context).
- For each EMPTY token with a corresponding registered MCP server: flag as misconfigured — server is registered but cannot authenticate.
- LinkedIn/Webex tokens expire and need periodic refresh — flag as 🟡 if the user has not confirmed recent rotation.
- HF_TOKEN: read-only inference token has limited blast radius — 🟢. Write-capable tokens are 🟡.

**MCP servers (from `~/.claude.json`)**
- For each registered server: what does it give Claude access to, and is that access still needed?
- `filesystem` scoped to `~/dev/`: 🟢 if expected, 🔴 if scoped to `~` or `/`.
- `github` with write permissions: 🟡 — note which repos are in scope.
- `splunk-mcp-server` with `NODE_TLS_REJECT_UNAUTHORIZED=0`: 🟡 — necessary workaround but worth flagging.
- `huggingface` local: 🟢 — required for image generation, bypasses claude.ai's restricted version.

**Cloud-managed integrations (always present, authenticated via claude.ai OAuth)**
Always list these as known access (cannot be audited locally — they are tied to the claude.ai account):
- **Gmail** — read/write access to email. 🟡 (broad, even if scoped by OAuth)
- **Google Calendar** — read/write access to calendar. 🟢
- **HuggingFace** (cloud-managed) — model/dataset search. 🟢
- **Slack** — read/write messages to accessible workspaces. 🟡

**Permissions in `~/.claude/settings.json`**
- Are `allowedTools` or `deniedTools` configured? If not, all tools are permitted by default — flag as ℹ️.
- Are hooks defined? Review them for any that run external processes.

**File permissions**
- `~/.claude/env.sh` should be `600` — flag 🔴 if world-readable (`644`, `664`, `666`, etc.)
- `~/.claude.json` and `~/.claude/settings.json` should be owner-readable only — flag 🟡 if group/world-readable.

## Step 4 — Present the audit report

Present a clean, structured audit report in this format:

---

## 🔐 Claude Security Audit — `<date>`

### Access inventory

**Local MCP servers** (registered via `claude mcp add`):

For each server: `**name** — what it accesses | Status: ✅/⚠️`

**Cloud-managed integrations** (via claude.ai OAuth — cannot be changed locally):
- Gmail — read/write email ⚠️
- Google Calendar — manage events ✅
- HuggingFace — model search ✅
- Slack — messages in accessible workspaces ⚠️

**Active credentials** (populated in `~/.claude/env.sh`):
- List each SET token by service name — do NOT show values

---

### Findings

For each finding:

> **[RISK LEVEL] Finding title**
> What: `<what was found>`
> Why it matters: `<security implication>`
> Remediation: `<specific action to take>`

---

### Summary

| Risk | Count |
|------|-------|
| 🔴 High | N |
| 🟡 Medium | N |
| 🟢 Low / Expected | N |
| ℹ️ Info | N |

Overall posture: `<one sentence assessment>`

---

## Step 5 — Offer remediations

After presenting the report, ask:

> Would you like to act on any of these findings?
> Options:
> - **Rotate a token** — I'll guide you to the right service settings page and update `env.sh`
> - **Remove an MCP server** — I'll run `claude mcp remove <name> --scope user`
> - **Tighten filesystem scope** — I'll update the filesystem server path in `~/.claude.json`
> - **Fix file permissions** — I'll run `chmod 600 ~/.claude/env.sh`
> - **Review a specific finding** — tell me which one

## Step 6 — Apply remediations

For each approved remediation:

### Rotate a token
Tell the user where to generate a new token (URL or app path), wait for them to confirm they have it, then update `~/.claude/env.sh`. Substitute the actual variable name (e.g. `GITHUB_TOKEN`) and the value the user provides:
```bash
# Replace TOKEN_NAME with the actual variable name, e.g. GITHUB_TOKEN
# Replace NEW_TOKEN_VALUE with the value provided by the user
sed -i "s|^export TOKEN_NAME=.*|export TOKEN_NAME=\"NEW_TOKEN_VALUE\"|" ~/.claude/env.sh
```
After updating, re-run `setup.sh` if the token is used by an MCP server:
```bash
cd ~/dev/claude && ./setup.sh
```

### Remove an MCP server
```bash
claude mcp remove <name> --scope user
```
Then remove the corresponding token from `~/.claude/env.sh` if it is exclusively used by that server.

### Fix filesystem scope
Use the Edit tool to update the filesystem server args in `~/.claude.json`. Narrow the path if overly broad.

### Fix file permissions
```bash
chmod 600 ~/.claude/env.sh
chmod 600 ~/.claude/settings.json
```

After all remediations are complete, confirm what was changed and suggest running `/security-audit` again to verify the updated posture.
