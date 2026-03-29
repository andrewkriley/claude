# Claude Security Audit
**Date:** 2026-03-30T08:27:25+1100
**Audited by:** security-audit skill

---

## Summary

| Area | Status | Issues |
|------|--------|--------|
| MCP Servers | ⚠️ | 2 |
| Filesystem Access | ⚠️ | 2 |
| Claude Code Permissions | ⚠️ | 2 |
| API Tokens | ⚠️ | 2 |
| GitHub PAT | ✅ | 0 |
| Claude.ai Integrations | ℹ️ Manual review | — |
| Skills | ✅ | 0 |

---

## MCP Servers

| Server | Transport | Access granted | Token | Status | Risk notes |
|--------|-----------|---------------|-------|--------|------------|
| filesystem | stdio (npx) | Read/write `~/dev/` | None | ✅ Active | Broad scope — 10 projects including sensitive .env files |
| github | stdio (npx) | GitHub API | `GITHUB_PERSONAL_ACCESS_TOKEN` (env key) | ✅ Active | ⚠️ Env key name differs from `env.sh` export (`GITHUB_TOKEN`) |
| huggingface | stdio via mcp-remote | HuggingFace inference at `huggingface.co/mcp` | PATH only | ⚠️ Token invalid | HF_TOKEN not injected into MCP env block; cloud endpoint |
| splunk-mcp-server | stdio via mcp-remote | Splunk search at `10.66.121.3:8089` | NODE_TLS_REJECT_UNAUTHORIZED=0 | ❓ Unreachable | TLS verification disabled; host unreachable on current network |

---

## Filesystem Access

**Root:** `/Users/<user>/dev` — full read/write via filesystem MCP

### Repos and directories

| Path | Type | Remote |
|------|------|--------|
| `ansible/` | Directory (no git) | — |
| `claude/` | Git repo | github.com/andrewkriley/claude |
| `claude-created-dashboards/` | Directory (no git) | — |
| `cloudflare-dns-cloudflared-mcp/` | Git repo | github.com/andrewkriley/cloudflare-dns-cloudflared-mcp (SSH) |
| `customer-hw-sw-lifecycle-strategy/` | Directory (no git) | — |
| `labaigitops/` | Git repo | gitlab.com/riles-public/labaigitops (SSH) |
| `netaigitops/` | Git repo | gitlab.com/cisco-anz-se/netaigitops (SSH) |
| `splunk/` | Directory (no git) | — |
| `splunk-lab/` | Git repo | github.com/andrewkriley/splunk-lab (SSH) |
| `www-andrewriley-info/` | Git repo | github.com/andrewkriley/www-andrewriley-info |

### Sensitive files found

| File | Keys present | Risk |
|------|-------------|------|
| `cloudflare-dns-cloudflared-mcp/.env` | `CF_API_TOKEN`, `CF_ACCOUNT_ID`, `MCP_BEARER_TOKEN` | ⚠️ High — Cloudflare DNS/account token |
| `netaigitops/.env` | `PVE_TOKEN_SECRET`, `GITLAB_RUNNER_TOKEN_*`, Proxmox infra config | ⚠️ High — Proxmox + GitLab runner tokens |
| `splunk-lab/.env` | `SPLUNK_PASSWORD`, `SPLUNK_HEC_TOKEN` | ⚠️ Medium |
| `customer-hw-sw-lifecycle-strategy/.env` | `WEBEX_TOKEN`, `WEBEX_ROOM` | ⚠️ Medium |
| `labaigitops/.env` | (empty) | ✅ Low |

### File permissions

| File | Permissions | Status |
|------|------------|--------|
| `~/.claude/env.sh` | `-rw-------` (600) | ✅ OK |
| `~/.claude.json` | `-rw-------` (600) | ✅ OK |

### Blast radius assessment

All `.env` files across 10 projects are readable. A misused filesystem MCP could read Cloudflare DNS credentials, Proxmox infrastructure tokens, GitLab runner tokens, Splunk credentials, and all source code across every project. Write access means any file could be modified — including skill files, git configs, and code.

---

## Claude Code Permissions

### Global settings (`~/.claude/settings.json`)

**Allow rules:** 0 — None. Claude prompts for every tool use globally.

**Deny rules:** 0 — None explicitly blocked globally.

### Project settings

**`~/dev/claude/.claude/settings.json`** — allow: none, deny: none

**`~/dev/claude/.claude/settings.local.json`** — ⚠️ Contains 12 allow rules:

| Rule | Notes |
|------|-------|
| `WebFetch(domain:github.com)` | ✅ Expected |
| `WebFetch(domain:raw.githubusercontent.com)` | ✅ Expected |
| `Bash(ssh:*)` | ✅ Expected |
| `mcp__splunk-mcp-server__splunk_run_query` | ✅ Expected |
| `mcp__splunk-mcp-server__splunk_get_index_info` | ✅ Expected |
| `mcp__splunk-mcp-server__splunk_get_indexes` | ✅ Expected |
| `mcp__claude_ai_Hugging_Face__dynamic_space` | ✅ Expected |
| `mcp__huggingface__gr1_z_image_turbo_generate` | ✅ Expected |
| `Bash(source "$HOME/.claude/env.sh")` | ✅ Expected |
| `Bash(echo $SPLUNK_HOST)` | ✅ Expected |
| `Bash(source $HOME/.claude/env.sh)` | ✅ Expected (duplicate of above) |
| `Bash(curl -s -o /tmp/li_img_upload.txt ... -H "Authorization: Bearer $LINKEDIN_TOKEN" ...)` | ⚠️ **Stale hardcoded curl** — leftover from a previous LinkedIn image upload. Contains a specific LinkedIn upload URL and a reference to `$HOME/dev/meraki_connected.png`. Should be removed. |

### Filesystem MCP root

`/Users/<user>/dev` — matches documented scope. No broader than expected.

### CLAUDE.md files in scope

8 CLAUDE.md files are present across `~/dev/` and are loaded when Claude Code operates in those directories:

| File | Notes |
|------|-------|
| `claude/CLAUDE.md` | ✅ Canonical — this repo |
| `www-andrewriley-info/CLAUDE.md` | ✅ Expected — blog repo |
| `customer-hw-sw-lifecycle-strategy/CLAUDE.md` | ℹ️ Verify contents are trusted |
| `cloudflare-dns-cloudflared-mcp/CLAUDE.md` | ℹ️ Verify contents are trusted |
| `splunk-lab/CLAUDE.md` | ℹ️ Verify contents are trusted |
| `splunk/CLAUDE.md` | ℹ️ Verify contents are trusted |
| `netaigitops/CLAUDE.md` | ℹ️ Verify contents are trusted |
| `labaigitops/CLAUDE.md` | ℹ️ Verify contents are trusted |

Any of these files could inject instructions into Claude's context when that repo is the working directory.

### Assessment

Global permissions are appropriately conservative (all prompts). Project-local settings are mostly well-scoped. One stale hardcoded curl allow rule in `settings.local.json` should be cleaned up.

---

## API Tokens

| Token | Service | Validity | Expiry | Risk |
|-------|---------|----------|--------|------|
| `GITHUB_TOKEN` | GitHub API | ✅ 200 | 2026-06-26 | Low |
| `HF_TOKEN` | HuggingFace | ❌ 401 | Unknown | Medium — image gen broken |
| `LINKEDIN_TOKEN` | LinkedIn API | ✅ 200 | Unknown | Low |
| `LINKEDIN_CLIENT_ID/SECRET` | LinkedIn OAuth | N/A | N/A | Low |
| `WEBEX_TOKEN` | Webex API | ✅ 200 | Unknown | Low |
| `WEBEX_CLIENT_ID/SECRET/REFRESH_TOKEN` | Webex OAuth | N/A | N/A | Low |
| `SPLUNK_TOKEN` | Splunk MCP | ❓ 000 | Unknown | Medium — unreachable |
| `SPLUNK_API_TOKEN` | Splunk REST | ❓ 000 | Unknown | Medium — unreachable |
| `SPLUNK_USER/PASS` | Splunk basic auth | N/A | N/A | Medium — plaintext, local only |

---

## GitHub PAT

- **Type:** Fine-grained PAT
- **Account:** andrewkriley
- **Expiry:** 2026-06-26
- **Risk:** Low. Fine-grained, expiring.
- **Note:** MCP server registers token as `GITHUB_PERSONAL_ACCESS_TOKEN`; `env.sh` exports `GITHUB_TOKEN`. Verify mapping in `~/.claude.json`.

---

## Claude.ai-managed Integrations

| Integration | Access | Used by skill | Revoke at |
|-------------|--------|---------------|-----------|
| Gmail | Read/send email | None | claude.ai/settings → Integrations |
| Google Calendar | Read/write events | None | claude.ai/settings → Integrations |
| HuggingFace (cloud) | Model inference, Spaces | `splunk-dashboard-gen`, `linkedin-post` | claude.ai/settings → Integrations |
| Slack | Read/send messages | None | claude.ai/settings → Integrations |

---

## Skills

| Skill | External services | Tokens required | Risk |
|-------|------------------|-----------------|------|
| `grill-me` | None | None | ✅ |
| `keep-current` | None | git only | ✅ |
| `linkedin-post` | LinkedIn API, HuggingFace | `LINKEDIN_TOKEN`, `HF_TOKEN` | ✅ Expected |
| `new-post-andrewriley-info` | git push | implicit | ✅ |
| `repo-status` | GitHub via gh CLI | `GITHUB_TOKEN` | ✅ Read-only |
| `security-audit` | All services | All tokens | ✅ Read-only |
| `skills` | None | None | ✅ |
| `splunk-dashboard-gen` | Splunk REST, HuggingFace | `SPLUNK_API_TOKEN`, `HF_TOKEN` | ✅ Expected |
| `summarise-session` | None | git only | ✅ |
| `webex-update` | Webex API | `WEBEX_TOKEN` | ✅ Expected |

---

## Findings

### ❌ Critical

None.

### ⚠️ Warnings

**W1 — Stale hardcoded curl in settings.local.json**
`settings.local.json` contains a specific LinkedIn image upload curl command that was auto-approved during a past session. It references a hardcoded upload URL and `$HOME/dev/meraki_connected.png`. This should be removed — auto-approving arbitrary curl commands with bearer tokens is a security risk if the URL or payload were to change unexpectedly.
*Fix:* Edit `~/dev/claude/.claude/settings.local.json` and remove the stale curl allow rule.

**W2 — Live .env files readable across all projects**
4 projects contain populated `.env` files with live credentials (Cloudflare API token, Proxmox tokens, GitLab runner tokens, Splunk credentials) — all readable via the filesystem MCP.
*Fix:* Narrow the filesystem MCP root to only repos Claude actively needs, or move secrets out of `~/dev/`.

**W3 — HF_TOKEN expired (401)**
Image generation broken. Regenerate at huggingface.co/settings/tokens, update `~/.claude/env.sh`, re-run `./setup.sh`.

**W4 — GitHub MCP token env key mismatch**
`GITHUB_PERSONAL_ACCESS_TOKEN` (in `~/.claude.json`) vs `GITHUB_TOKEN` (in `env.sh`). Verify with `claude mcp get github`.

### ℹ️ Informational

**I1 — GitHub PAT expires 2026-06-26** — rotate before this date.

**I2 — 8 CLAUDE.md files in filesystem MCP scope** — loaded as project instructions when Claude operates in those directories. Review each for unexpected or conflicting instructions.

**I3 — Gmail + Google Calendar OAuth connected but unused** — consider revoking.

**I4 — Splunk tokens unvalidated** — host unreachable; re-run on VPN/internal network.

**I5 — Duplicate Bash allow rule** in `settings.local.json` — `source $HOME/.claude/env.sh` appears twice. Minor cleanup opportunity.

---

## Remediation checklist

- [ ] **W1 — Remove stale curl allow rule** from `~/dev/claude/.claude/settings.local.json`
- [ ] **W2 — Narrow filesystem MCP root** — update `setup.sh` to register only `~/dev/claude` and `~/dev/www-andrewriley-info`, or accept current scope knowingly
- [ ] **W3 — Refresh HF_TOKEN** — huggingface.co/settings/tokens → update `env.sh` → `./setup.sh`
- [ ] **W4 — Fix GitHub MCP env mapping** — run `claude mcp get github`; re-run `./setup.sh` if misconfigured
- [ ] **I1 — Rotate GITHUB_TOKEN before 2026-06-26**
- [ ] **I2 — Review non-claude CLAUDE.md files** in `~/dev/` for unexpected instructions
- [ ] **I3 — Revoke unused Gmail/Google Calendar OAuth** at claude.ai/settings → Integrations
- [ ] **I4 — Revalidate Splunk tokens on-network**
- [ ] **I5 — Remove duplicate `source env.sh` allow rule** from `settings.local.json`

---

*Report generated by /security-audit skill. Saved to: ~/dev/claude/security-audit-20260330.md*
