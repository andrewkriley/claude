# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A portable Claude resource library — skills, profile, MCP config, and scripts — synced via Git and applied to any machine running Claude Code. Canonical source of truth for `~/.claude/` across all workstations.

## Setup a new machine

```bash
git clone https://github.com/andrewkriley/claude.git ~/dev/claude
cd ~/dev/claude
./setup.sh
```

`setup.sh` supports macOS and Ubuntu. It will:
- Clone the blog repo to `~/dev/www-andrewriley-info`
- Symlink `skills/` → `~/.claude/skills/`
- Symlink `PROFILE.md` → `~/.claude/PROFILE.md`
- Generate `~/.claude/settings.json` from `settings.json.template`
- Create `~/.claude/env.sh` from `env.sh.template` (secrets, never committed)
- Add `env.sh` sourcing to `.zshrc` / `.bashrc`

After running setup, fill in `~/.claude/env.sh` with tokens. For LinkedIn and Webex, run:
```bash
./scripts/linkedin-oauth.sh
./scripts/webex-oauth.sh
```

## Keeping machines in sync

```bash
# On the machine where you made changes:
git add -A && git commit -m "..." && git push

# On other machines:
git pull && ./setup.sh
```

## Repository structure

```
claude/
├── setup.sh                        # Bootstrap script (macOS + Ubuntu)
├── PROFILE.md                      # Voice/identity profile for content skills
├── settings.json.template          # MCP server config + plugin marketplace template
├── env.sh.template                 # Secrets template (never commit populated version)
├── .claude/
│   └── settings.json               # Project-scoped plugin marketplace config
├── scripts/
│   ├── linkedin-oauth.sh           # One-time LinkedIn OAuth setup
│   └── webex-oauth.sh              # One-time Webex OAuth setup
└── skills/
    ├── new-post-andrewriley-info/  # Hugo blog post creation pipeline
    ├── linkedin-post/              # LinkedIn draft + publish
    ├── summarise-session/          # End-of-session summary
    ├── grill-me/                   # Deep design interview skill
    ├── webex-update/               # Send a session update to a Webex room
    └── skills/                     # List all available skills
```

## Path conventions

All skills use `$HOME`-relative paths. Every machine must follow this layout:

| Path | Contents |
|---|---|
| `~/dev/claude` | This repo |
| `~/dev/www-andrewriley-info` | Hugo blog repo |
| `~/.claude/skills/` | Symlink → `~/dev/claude/skills/` |
| `~/.claude/PROFILE.md` | Symlink → `~/dev/claude/PROFILE.md` |
| `~/.claude/env.sh` | Machine-specific secrets (gitignored) |

## GitHub PAT requirements

The `GITHUB_TOKEN` in `env.sh` must be a **fine-grained PAT** scoped to the `andrewkriley/claude` repository with the following permissions:

**Repository permissions:**

| Permission | Access | Reason |
|---|---|---|
| Contents | Read & Write | Clone, push, pull, read files |
| Administration | Read & Write | Branch protection rules |
| Workflows | Read & Write | Push `.github/workflows/` files |
| Metadata | Read | Required (auto-selected) |
| Pull requests | Read & Write | Review and merge PRs |

**Account permissions:**

| Permission | Access | Reason |
|---|---|---|
| Email addresses | Read | GitHub MCP server user lookups |

Generate at: `https://github.com/settings/personal-access-tokens/new`

## Plugins

Plugin marketplaces are registered in `settings.json.template` (user-level) and `.claude/settings.json` (project-level) via `extraKnownMarketplaces`. On a new machine, activate after `setup.sh`:

```bash
/plugin marketplace add cloudflare/skills
/plugin install cloudflare@cloudflare
/reload-plugins
```

### Plugin marketplaces

| Marketplace | GitHub source | Purpose |
|---|---|---|
| `cloudflare` | `cloudflare/skills` | Cloudflare platform skills and MCP servers |

## MCP servers

### Local (synced via this repo)

Configured in `settings.json.template`, applied by `setup.sh`:
- **filesystem** — access to `~/dev/`
- **github** — GitHub API access (requires `GITHUB_TOKEN` in `env.sh`)

### Plugin MCP servers

The `cloudflare` plugin ships MCP servers for Cloudflare documentation search and Pages → Workers migration guidance. Available after installing the plugin.

### claude.ai-managed (not syncable)

Gmail, Google Calendar, HuggingFace, and Slack MCP servers are authenticated via **claude.ai's cloud OAuth** and tied to the claude.ai account — not to individual machines. They are configured at claude.ai/settings and automatically available in every Claude Code session without any local setup. There is nothing to sync here.

## Skills quick reference

| Skill | Invoke | Purpose |
|---|---|---|
| `new-post-andrewriley-info` | `/new-post-andrewriley-info` | Write and publish a Hugo blog post |
| `linkedin-post` | `/linkedin-post [topic]` | Draft and publish a LinkedIn post |
| `summarise-session` | `/summarise-session` | Summarise the current session |
| `grill-me` | `/grill-me [topic]` | Deep design interview |
| `webex-update` | `/webex-update [topic]` | Send a session update to a Webex room |
| `skills` | `/skills` | List all available skills and configured MCP servers |
