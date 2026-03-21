#!/usr/bin/env bash
# setup.sh — Bootstrap Claude resources on a new machine
# Supports: macOS, Ubuntu
# Run from: $HOME/dev/claude (this repo)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DEV_DIR="$HOME/dev"
ENV_FILE="$CLAUDE_DIR/env.sh"

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*"; exit 1; }
ask()     { echo -e "${YELLOW}[?]${NC} $*"; }

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ -f /etc/os-release ]] && grep -qi ubuntu /etc/os-release; then
  OS="ubuntu"
fi
info "Detected OS: $OS"

echo ""
echo "=== Claude Resources Setup ==="
echo "Repo: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# ── Step 1: Dependencies ───────────────────────────────────────────────────
info "Checking dependencies..."

if ! command -v node &>/dev/null; then
  warn "Node.js not found — required for MCP servers."
  if [[ "$OS" == "macos" ]]; then
    warn "Install with: brew install node"
  else
    warn "Install with: sudo apt install nodejs npm"
  fi
fi

if ! command -v npx &>/dev/null; then
  warn "npx not found — required for MCP servers."
fi

if ! command -v python3 &>/dev/null; then
  warn "python3 not found — required for LinkedIn OAuth script."
fi

if ! command -v git &>/dev/null; then
  error "git is required but not found."
fi

# ── Step 2: Directory layout ───────────────────────────────────────────────
info "Creating directory layout..."
mkdir -p "$DEV_DIR"
mkdir -p "$CLAUDE_DIR"

# ── Step 3: Clone blog repo ────────────────────────────────────────────────
BLOG_DIR="$DEV_DIR/www-andrewriley-info"
if [[ -d "$BLOG_DIR/.git" ]]; then
  info "Blog repo already cloned at $BLOG_DIR — pulling latest..."
  git -C "$BLOG_DIR" pull --ff-only 2>/dev/null || warn "Could not auto-pull blog repo (uncommitted changes?)"
else
  info "Cloning blog repo to $BLOG_DIR..."
  git clone https://github.com/andrewkriley/www-andrewriley-info.git "$BLOG_DIR" || \
    warn "Could not clone blog repo — check your GitHub access and try manually: git clone https://github.com/andrewkriley/www-andrewriley-info.git $BLOG_DIR"
fi

# ── Step 4: Symlink skills ─────────────────────────────────────────────────
SKILLS_TARGET="$CLAUDE_DIR/skills"
SKILLS_SOURCE="$REPO_DIR/skills"

info "Linking skills..."
if [[ -L "$SKILLS_TARGET" ]]; then
  rm "$SKILLS_TARGET"
elif [[ -d "$SKILLS_TARGET" ]]; then
  warn "$SKILLS_TARGET exists as a real directory — backing up to ${SKILLS_TARGET}.bak"
  mv "$SKILLS_TARGET" "${SKILLS_TARGET}.bak"
fi
ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
info "Skills linked: $SKILLS_SOURCE → $SKILLS_TARGET"

# ── Step 5: Symlink PROFILE.md ─────────────────────────────────────────────
PROFILE_TARGET="$CLAUDE_DIR/PROFILE.md"
PROFILE_SOURCE="$REPO_DIR/PROFILE.md"

info "Linking PROFILE.md..."
if [[ -L "$PROFILE_TARGET" ]]; then
  rm "$PROFILE_TARGET"
elif [[ -f "$PROFILE_TARGET" ]]; then
  warn "$PROFILE_TARGET exists — backing up to ${PROFILE_TARGET}.bak"
  mv "$PROFILE_TARGET" "${PROFILE_TARGET}.bak"
fi
ln -s "$PROFILE_SOURCE" "$PROFILE_TARGET"
info "PROFILE.md linked: $PROFILE_SOURCE → $PROFILE_TARGET"

# ── Step 6: Generate settings.json ────────────────────────────────────────
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SETTINGS_TEMPLATE="$REPO_DIR/settings.json.template"

info "Generating $SETTINGS_FILE from template..."
cp "$SETTINGS_TEMPLATE" "$SETTINGS_FILE"
info "settings.json written."

# ── Step 7: env.sh setup ──────────────────────────────────────────────────
info "Setting up $ENV_FILE..."

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$REPO_DIR/env.sh.template" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  info "Created $ENV_FILE from template."
else
  info "$ENV_FILE already exists — not overwriting."
fi

# Source env.sh so tokens are available for MCP registration below
set +u
# shellcheck disable=SC1090
source "$ENV_FILE" 2>/dev/null || true
set -u

# ── Step 8: Register MCP servers via claude CLI ────────────────────────────
# Claude Code v2.x reads local MCP servers from ~/.claude.json (managed by
# `claude mcp add`). The mcpServers key in ~/.claude/settings.json is ignored.
info "Registering local MCP servers via claude CLI..."

if ! command -v claude &>/dev/null; then
  warn "claude CLI not found — skipping MCP server registration."
  warn "Install Claude Code, then re-run setup.sh to register MCP servers."
else
  # Re-registers a server: removes existing entry (if any) then re-adds.
  # This ensures tokens and config are always current after re-running setup.sh.
  register_mcp() {
    local name="$1"; shift
    if claude mcp get "$name" &>/dev/null 2>&1; then
      claude mcp remove "$name" --scope user &>/dev/null 2>&1 || true
    fi
    if claude mcp add --scope user "$name" "$@" &>/dev/null 2>&1; then
      info "  Registered: $name"
    else
      warn "  Failed to register: $name (check token/host and re-run setup.sh)"
    fi
  }

  # filesystem — no secrets required
  register_mcp filesystem \
    -- npx -y @modelcontextprotocol/server-filesystem "$HOME/dev"

  # github — requires GITHUB_TOKEN
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    register_mcp github \
      -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN" \
      -- npx -y @modelcontextprotocol/server-github
  else
    warn "  Skipping github MCP — GITHUB_TOKEN not set in $ENV_FILE"
  fi

  # splunk-mcp-server — requires SPLUNK_HOST and SPLUNK_TOKEN
  # IMPORTANT: Must use stdio + mcp-remote (not --transport http).
  # Claude Code's HTTP transport cannot disable TLS cert verification.
  # mcp-remote with NODE_TLS_REJECT_UNAUTHORIZED=0 is the only supported
  # approach for Splunk's self-signed cert.
  if [[ -n "${SPLUNK_HOST:-}" && -n "${SPLUNK_TOKEN:-}" ]]; then
    register_mcp splunk-mcp-server \
      -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
      -- npx -y mcp-remote@0.1.38 "https://${SPLUNK_HOST}:8089/services/mcp" \
      --header "Authorization: Bearer ${SPLUNK_TOKEN}"
  else
    warn "  Skipping splunk-mcp-server — SPLUNK_HOST or SPLUNK_TOKEN not set in $ENV_FILE"
  fi
fi

MISSING=()
[[ -z "${GITHUB_TOKEN:-}" ]]          && MISSING+=("GITHUB_TOKEN (required for GitHub MCP)")
[[ -z "${LINKEDIN_TOKEN:-}" ]]        && MISSING+=("LINKEDIN_TOKEN (run scripts/linkedin-oauth.sh)")
[[ -z "${LINKEDIN_PERSON_URN:-}" ]]   && MISSING+=("LINKEDIN_PERSON_URN (run scripts/linkedin-oauth.sh)")
[[ -z "${SPLUNK_HOST:-}" ]]           && MISSING+=("SPLUNK_HOST (required for Splunk MCP, e.g. 10.66.121.3)")
[[ -z "${SPLUNK_TOKEN:-}" ]]          && MISSING+=("SPLUNK_TOKEN (required for Splunk MCP)")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  warn "The following credentials are not yet configured in $ENV_FILE:"
  for m in "${MISSING[@]}"; do
    echo "    - $m"
  done
  echo ""
  warn "Edit $ENV_FILE to fill in missing values."
  warn "For LinkedIn credentials, run: $REPO_DIR/scripts/linkedin-oauth.sh"
fi

# ── Step 9: Shell integration ──────────────────────────────────────────────
SOURCE_LINE="[ -f \"\$HOME/.claude/env.sh\" ] && source \"\$HOME/.claude/env.sh\""
SHELL_RC=""
if [[ "$OS" == "macos" ]]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -f "$SHELL_RC" ]] && ! grep -qF "claude/env.sh" "$SHELL_RC"; then
  echo "" >> "$SHELL_RC"
  echo "# Claude environment" >> "$SHELL_RC"
  echo "$SOURCE_LINE" >> "$SHELL_RC"
  info "Added env.sh source to $SHELL_RC"
else
  info "env.sh already sourced in $SHELL_RC (or file not found)"
fi

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo ""
info "Skills available:    $SKILLS_TARGET"
info "Profile:             $PROFILE_TARGET"
info "MCP config:          $SETTINGS_FILE"
info "Secrets:             $ENV_FILE"
info "Blog repo:           $BLOG_DIR"
echo ""
info "Restart Claude Code for MCP and skill changes to take effect."
echo ""
