---
name: security-audit
description: Audits everything Claude has access to — MCP servers, API tokens, OAuth integrations, GitHub PAT scopes, and skills — checks live token validity, flags issues with remediation instructions, and produces a dated report.
argument-hint: [optional: focus area, e.g. "mcp", "tokens", "github"]
---

You are performing a security audit of Andrew's Claude environment. Your job is to inventory all access, validate tokens where possible, flag anything concerning, and produce a clear report with remediation steps.

## Step 1 — Collect local config

Run the following in a single Bash tool call:

```bash
echo "=DATE=$(date '+%Y-%m-%dT%H:%M:%S%z')"
echo "=CLAUDE_JSON="
cat ~/.claude.json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
servers = data.get('mcpServers', {})
for name, cfg in servers.items():
    print(f'  [{name}]')
    print(f'    command: {cfg.get(\"command\", \"\")} {\" \".join(cfg.get(\"args\", [])[:3])}')
    envkeys = list(cfg.get('env', {}).keys())
    if envkeys:
        print(f'    env keys: {envkeys}')
" 2>/dev/null || echo "(could not parse ~/.claude.json)"

echo "=ENV_KEYS="
grep -E '^[A-Z_]+=.' ~/.claude/env.sh 2>/dev/null | sed 's/=.*/=***REDACTED***/' || echo "(env.sh not found)"

echo "=SKILLS="
ls ~/dev/claude/skills/ 2>/dev/null

echo "=SETTINGS_PERMISSIONS="
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    d = json.load(f)
perms = d.get('permissions', {})
print('  allow:', perms.get('allow', []))
print('  deny:', perms.get('deny', []))
" 2>/dev/null || echo "(could not parse settings.json)"
```

Then read `~/.claude/env.sh` to get the list of token variable names (not values) that are set.

## Step 2 — Validate tokens

For each token found, test validity. Use Bash tool for each check — **never print token values**.

### GitHub PAT (`GITHUB_TOKEN`)
```bash
result=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user)
echo "GITHUB_TOKEN status: $result"
# Get scopes
curl -sI -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user 2>/dev/null | grep -i x-oauth-scopes || echo "(fine-grained PAT — scopes not exposed via header)"
# Get accessible repos
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/installation/repositories" -o /dev/null -w "%{http_code}" 2>/dev/null
```

### HuggingFace token (`HF_TOKEN`)
```bash
result=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $HF_TOKEN" https://huggingface.co/api/whoami)
echo "HF_TOKEN status: $result"
```

### LinkedIn token (`LINKEDIN_TOKEN`)
```bash
result=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LINKEDIN_TOKEN" "https://api.linkedin.com/v2/userinfo")
echo "LINKEDIN_TOKEN status: $result"
```

### Webex token (`WEBEX_TOKEN`)
```bash
result=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $WEBEX_TOKEN" "https://webexapis.com/v1/people/me")
echo "WEBEX_TOKEN status: $result"
```

### Splunk MCP token (`SPLUNK_TOKEN`)
```bash
result=$(curl -sk -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SPLUNK_TOKEN" "https://${SPLUNK_HOST}:8089/services/mcp" -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"audit","version":"1.0"}}}')
echo "SPLUNK_TOKEN status: $result"
```

### Splunk API token (`SPLUNK_API_TOKEN`)
```bash
result=$(curl -sk -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SPLUNK_API_TOKEN" "https://${SPLUNK_HOST}:8089/services/server/info")
echo "SPLUNK_API_TOKEN status: $result"
```

Skip any check where the variable is empty or unset. Record HTTP status codes:
- **200/201** — valid
- **401/403** — expired or invalid
- **0/000** — unreachable (network or host issue)

## Step 3 — Audit filesystem access

The `filesystem` MCP server grants Claude read/write access to `~/dev/`. Audit what is actually there.

Run the following in a single Bash tool call:

```bash
echo "=FILESYSTEM_ROOT="
ls ~/dev/

echo "=REPO_LIST="
for d in ~/dev/*/; do
  if [ -d "$d/.git" ]; then
    remote=$(git -C "$d" remote get-url origin 2>/dev/null || echo "(no remote)")
    echo "  GIT: $d → $remote"
  else
    echo "  DIR: $d"
  fi
done

echo "=SENSITIVE_FILES="
# Look for files that shouldn't be accessible: secrets, keys, certs, env files
find ~/dev -maxdepth 3 \( \
  -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" \
  -o -name ".env" -o -name ".env.*" -o -name "*.env" \
  -o -name "secrets.json" -o -name "credentials.json" \
  -o -name "*.secret" -o -name "id_rsa" -o -name "id_ed25519" \
\) 2>/dev/null | head -50

echo "=GITIGNORED_BUT_PRESENT="
# Check each git repo for files that are gitignored but exist (potential committed secrets)
for d in ~/dev/*/; do
  if [ -d "$d/.git" ]; then
    ignored=$(git -C "$d" ls-files --others --ignored --exclude-standard 2>/dev/null | grep -E "\.(env|pem|key|secret|token)$" | head -5)
    if [ -n "$ignored" ]; then
      echo "  $d: $ignored"
    fi
  fi
done

echo "=ENV_FILES_IN_DEV="
find ~/dev -maxdepth 3 -name "*.env" -o -name ".env" -o -name "env.sh" 2>/dev/null | grep -v ".git"

echo "=WORLD_READABLE_SECRETS="
# Check ~/.claude/env.sh permissions — should not be world-readable
ls -la ~/.claude/env.sh 2>/dev/null
ls -la ~/.claude.json 2>/dev/null
```

Assess the findings:
- **List all repos** under `~/dev/` — note any that seem unexpected or sensitive
- **Flag any sensitive files** (keys, certs, .env files) — these are readable by Claude via the filesystem MCP
- **Check file permissions** on `env.sh` and `.claude.json` — should be `600` (owner read/write only)
- **Note the blast radius** — if the filesystem MCP were misused, what could be read or modified?

## Step 4 — Audit Claude Code permissions

Claude Code's tool permissions are controlled by two files. Audit both.

Run the following in a single Bash tool call:

```bash
echo "=SETTINGS_JSON_PERMISSIONS="
python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
with open(path) as f:
    d = json.load(f)
perms = d.get('permissions', {})
allow = perms.get('allow', [])
deny = perms.get('deny', [])
print('allow rules:', len(allow))
for r in allow:
    print('  ALLOW:', r)
print('deny rules:', len(deny))
for r in deny:
    print('  DENY:', r)
" 2>/dev/null || echo "(could not parse ~/.claude/settings.json)"

echo "=PROJECT_SETTINGS="
# Check for project-scoped settings (can override global)
for f in \
  ~/dev/claude/.claude/settings.json \
  ~/dev/claude/.claude/settings.local.json; do
  if [ -f "$f" ]; then
    echo "--- $f ---"
    python3 -c "
import json
with open('$f') as f:
    d = json.load(f)
perms = d.get('permissions', {})
allow = perms.get('allow', [])
deny = perms.get('deny', [])
print('  allow:', allow)
print('  deny:', deny)
" 2>/dev/null
  fi
done

echo "=FILESYSTEM_MCP_ROOT="
python3 -c "
import json, os
with open(os.path.expanduser('~/.claude.json')) as f:
    d = json.load(f)
servers = d.get('mcpServers', {})
fs = servers.get('filesystem', {})
args = fs.get('args', [])
# The root path is the last non-flag argument
roots = [a for a in args if not a.startswith('-') and '/' in a]
print('filesystem MCP roots:', roots)
" 2>/dev/null || echo "(could not parse ~/.claude.json)"

echo "=CLAUDEMD_FILES="
# CLAUDE.md files provide project instructions — list all found in accessible paths
find ~/dev -maxdepth 3 -name "CLAUDE.md" 2>/dev/null
```

Assess the findings:

- **Global allow rules** (`~/.claude/settings.json`) — list each rule; flag any that are overly broad (e.g. `Bash(*:*)` allows all shell commands without prompting)
- **Global deny rules** — list each; note if no deny rules exist (means nothing is explicitly blocked)
- **Project-scoped settings** (`.claude/settings.json`, `.claude/settings.local.json`) — these override global settings for this project; flag any that expand permissions beyond the global config
- **Filesystem MCP root** — confirm the registered path matches what is documented; flag if it's broader than necessary (e.g. `~/` instead of `~/dev/`)
- **CLAUDE.md files** — list all found across accessible repos; these provide instructions loaded into Claude's context and could influence behaviour if a repo contains a malicious CLAUDE.md

Flag anything where:
- Allow rules grant unrestricted Bash execution (`Bash(*:*)` or similar)
- No deny rules exist and allow is also empty (fully permissive — prompts each time, no guardrails)
- Filesystem MCP root is broader than `~/dev/`
- Multiple CLAUDE.md files exist across repos (potential prompt injection surface)

## Step 5 — Audit MCP server access

For each registered MCP server, assess:

| Server | Transport | Access granted | Token required | Risk notes |
|--------|-----------|---------------|----------------|------------|

Flag anything where:
- A server has broad filesystem or network access beyond what skills need
- A token grants more permissions than necessary
- A server is registered but never used by any skill

## Step 6 — Audit claude.ai-managed integrations

List the known cloud OAuth integrations (these cannot be validated via token — note they require manual review at claude.ai/settings):

- **Gmail** — read/send email
- **Google Calendar** — read/write calendar events
- **HuggingFace** — model inference, Space invocation
- **Slack** — read/send messages across channels

For each, note: what access it has, whether it's used by any skill, and how to revoke it if needed (claude.ai/settings → Integrations).

## Step 7 — Audit skills

For each skill in `~/dev/claude/skills/`, read its `SKILL.md` and note:
- What external services it calls
- What tokens it requires
- Any shell commands it runs (Bash tool usage)
- Any potential for unintended data exfiltration (e.g. sends content to external APIs)

## Step 8 — Audit GitHub PAT permissions

Using the GitHub API response from Step 2, check:
- Is the PAT fine-grained (scoped to specific repos) or classic (broad)?
- Does it have more permissions than documented in CLAUDE.md?
- Is it set to expire, or does it have no expiry?

```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('login:', d.get('login'))
print('type:', d.get('type'))
"
```

## Step 9 — Produce the report

Write the report to `~/dev/claude/security-audit-<YYYYMMDD>.md`. Use the date from Step 1.

Report format:

```markdown
# Claude Security Audit
**Date:** <date>
**Audited by:** security-audit skill

---

## Summary

| Area | Status | Issues |
|------|--------|--------|
| MCP Servers | ✅/⚠️/❌ | <count> |
| Filesystem Access | ✅/⚠️/❌ | <count> |
| Claude Code Permissions | ✅/⚠️/❌ | <count> |
| API Tokens | ✅/⚠️/❌ | <count> |
| GitHub PAT | ✅/⚠️/❌ | <count> |
| Claude.ai Integrations | ℹ️ Manual review | — |
| Skills | ✅/⚠️/❌ | <count> |

---

## MCP Servers

<for each server: name, transport, access scope, token used, status, any flags>

---

## Filesystem Access

**Root:** `~/dev/`

### Repos and directories
<list all items under ~/dev/ — git repos with remote URLs, non-git dirs>

### Sensitive files found
<any .env, .pem, .key, credentials files found within ~/dev/ — or "None found">

### File permissions
<permissions on ~/.claude/env.sh and ~/.claude.json — flag if not 600>

### Blast radius assessment
<what could be read or modified if filesystem MCP were misused>

---

## Claude Code Permissions

### Global settings (`~/.claude/settings.json`)

**Allow rules:** <count — or "None (prompts for every tool use)">
<list each rule>

**Deny rules:** <count — or "None (nothing explicitly blocked)">
<list each rule>

### Project settings (`.claude/settings.json`, `.claude/settings.local.json`)
<list any overrides found, or "None">

### Filesystem MCP root
<registered path — flag if broader than ~/dev/>

### CLAUDE.md files in scope
<list all CLAUDE.md files found across ~/dev/ — note any in non-claude repos>

### Assessment
<are permissions appropriately scoped? any overly broad allow rules? any missing deny rules that should exist?>

---

## API Tokens

<for each token: name (not value), service, validity status, expiry if known, risk level>

---

## GitHub PAT

<PAT type, permissions, expiry, risk notes>

---

## Claude.ai-managed Integrations

<list with access description and revocation path>

---

## Skills

<for each skill: external services called, tokens required, risk notes>

---

## Findings

### ❌ Critical
<issues requiring immediate action>

### ⚠️ Warnings
<issues to address soon>

### ℹ️ Informational
<low-risk observations>

---

## Remediation checklist

- [ ] <specific action with instructions>

---

*Report generated by /security-audit skill. Review at: ~/dev/claude/security-audit-<date>.md*
```

After writing the file, tell the user:
> Security audit complete. Report written to `~/dev/claude/security-audit-<date>.md`.
>
> Summary: X critical, X warnings, X informational.

List the critical and warning findings inline so the user can act immediately without opening the file.

**Important:** Never print token values at any point. Only reference tokens by variable name.
