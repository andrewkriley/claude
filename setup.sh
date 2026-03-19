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

# Load existing GITHUB_TOKEN from env.sh if available
GITHUB_TOKEN_VALUE=""
if [[ -f "$ENV_FILE" ]]; then
  GITHUB_TOKEN_VALUE=$(grep '^export GITHUB_TOKEN=' "$ENV_FILE" 2>/dev/null | sed 's/export GITHUB_TOKEN="//;s/"//' || echo "")
fi

# Replace placeholders in template
sed \
  -e "s|HOMEDIR|$HOME|g" \
  -e "s|GITHUB_TOKEN_PLACEHOLDER|${GITHUB_TOKEN_VALUE:-YOUR_GITHUB_TOKEN}|g" \
  "$SETTINGS_TEMPLATE" > "$SETTINGS_FILE"

info "settings.json written."
if [[ -z "$GITHUB_TOKEN_VALUE" ]]; then
  warn "GITHUB_TOKEN not set — edit $ENV_FILE and re-run setup.sh to apply it to settings.json."
fi

# ── Step 7: env.sh setup ──────────────────────────────────────────────────
info "Setting up $ENV_FILE..."

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$REPO_DIR/env.sh.template" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  info "Created $ENV_FILE from template."
else
  info "$ENV_FILE already exists — not overwriting."
fi

# Source env.sh and check what's missing
set +u
# shellcheck disable=SC1090
source "$ENV_FILE" 2>/dev/null || true
set -u

MISSING=()
[[ -z "${GITHUB_TOKEN:-}" ]]          && MISSING+=("GITHUB_TOKEN (required for GitHub MCP)")
[[ -z "${LINKEDIN_TOKEN:-}" ]]        && MISSING+=("LINKEDIN_TOKEN (run scripts/linkedin-oauth.sh)")
[[ -z "${LINKEDIN_PERSON_URN:-}" ]]   && MISSING+=("LINKEDIN_PERSON_URN (run scripts/linkedin-oauth.sh)")

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

# ── Step 8: Shell integration ──────────────────────────────────────────────
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
