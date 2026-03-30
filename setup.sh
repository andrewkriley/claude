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

if [[ "$OS" == "unknown" ]]; then
  warn "Unrecognised OS — automatic dependency installation will be skipped."
  warn "Ensure git, curl, python3, and Node.js >= 20 are installed before continuing."
fi

echo ""
echo "=== Claude Resources Setup ==="
echo "Repo: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# ── Step 1: Dependencies ───────────────────────────────────────────────────
info "Checking dependencies..."

# Track whether apt-get update has been run to avoid repeating it
APT_UPDATED=false
apt_install() {
  if [[ "$APT_UPDATED" == false ]]; then
    sudo apt-get update -qq
    APT_UPDATED=true
  fi
  sudo apt-get install -y "$@"
}

# curl — required for nvm install and OAuth scripts
if ! command -v curl &>/dev/null; then
  if [[ "$OS" == "ubuntu" ]]; then
    info "Installing curl via apt..."
    apt_install curl
  elif [[ "$OS" == "macos" ]]; then
    # curl ships with macOS; its absence likely means Xcode CLT not installed
    warn "curl not found — install Xcode Command Line Tools: xcode-select --install"
    error "curl is required but not found."
  else
    error "curl is required but not found. Install it manually."
  fi
fi

# git — required for cloning repos
if ! command -v git &>/dev/null; then
  if [[ "$OS" == "ubuntu" ]]; then
    info "Installing git via apt..."
    apt_install git
  elif [[ "$OS" == "macos" ]]; then
    # git triggers the Xcode CLT install prompt on macOS when invoked interactively,
    # but not from a script — guide the user instead.
    if command -v brew &>/dev/null; then
      info "Installing git via Homebrew..."
      brew install git
    else
      warn "git not found. Install Xcode Command Line Tools (xcode-select --install) or Homebrew (https://brew.sh), then re-run setup.sh."
      error "git is required but not found."
    fi
  else
    error "git is required but not found. Install it manually."
  fi
fi
info "git $(git --version | awk '{print $3}') — OK"

NODE_MIN_VERSION=20

ensure_node() {
  local major

  # Try loading nvm in case it's installed but not yet sourced in this shell
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

  # Check if a sufficiently new Node is already present
  if command -v node &>/dev/null; then
    major=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ -n "$major" && "$major" -ge "$NODE_MIN_VERSION" ]]; then
      info "Node.js $(node --version) — OK"
      return 0
    fi
    warn "Node.js $(node --version) found but >= v${NODE_MIN_VERSION} is required — upgrading via nvm..."
  else
    warn "Node.js not found — installing via nvm..."
  fi

  # Install nvm if not yet available
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    info "Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
  fi

  info "Installing Node.js LTS v${NODE_MIN_VERSION} via nvm..."
  nvm install "${NODE_MIN_VERSION}"
  nvm alias default "${NODE_MIN_VERSION}"
  nvm use "${NODE_MIN_VERSION}"
  info "Node.js $(node --version) installed and set as default."
}

ensure_node

# Capture the Node bin directory after ensure_node so MCP servers that use
# mcp-remote inherit a Node >= 20 path even when the system default is older.
NODE_BIN_DIR="$(dirname "$(command -v node)")"

if ! command -v npx &>/dev/null; then
  warn "npx not found — this is unexpected if Node installed correctly."
fi

# python3 — required for LinkedIn OAuth script
if ! command -v python3 &>/dev/null; then
  if [[ "$OS" == "ubuntu" ]]; then
    info "Installing python3 via apt..."
    apt_install python3
  elif [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      info "Installing python3 via Homebrew..."
      brew install python3
    else
      warn "python3 not found — required for LinkedIn OAuth script."
      warn "Install via Homebrew (brew install python3) or Xcode CLT (xcode-select --install)."
    fi
  else
    warn "python3 not found — required for LinkedIn OAuth script. Install it manually."
  fi
else
  info "python3 $(python3 --version | awk '{print $2}') — OK"
fi

# claude CLI — required for MCP server registration (Step 8)
if ! command -v claude &>/dev/null; then
  warn "claude CLI not found — install it, then re-run setup.sh to register MCP servers."
  warn "Install: npm install -g @anthropic-ai/claude-code"
fi

# ── Step 2: Directory layout ───────────────────────────────────────────────
info "Creating directory layout..."
mkdir -p "$DEV_DIR"
mkdir -p "$CLAUDE_DIR"

# ── Step 3: Symlink skills ─────────────────────────────────────────────────
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

# ── Step 4: Symlink PROFILE.md ─────────────────────────────────────────────
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

# ── Step 5: Generate settings.json ────────────────────────────────────────
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SETTINGS_TEMPLATE="$REPO_DIR/settings.json.template"

info "Generating $SETTINGS_FILE from template..."
cp "$SETTINGS_TEMPLATE" "$SETTINGS_FILE"
info "settings.json written."

# ── Step 6: env.sh setup ──────────────────────────────────────────────────
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

# ── Step 7: Register MCP servers via claude CLI ────────────────────────────
# Claude Code v2.x reads local MCP servers from ~/.claude.json (managed by
# `claude mcp add`). The mcpServers key in ~/.claude/settings.json is ignored.
info "Registering local MCP servers via claude CLI..."

if ! command -v claude &>/dev/null; then
  warn "Skipping MCP server registration — claude CLI not found (see above)."
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

  # huggingface — requires HF_TOKEN
  # Registered locally (without gradio=none) to enable dynamic_space invoke.
  # The claude.ai-managed HF server uses gradio=none which blocks invoke.
  # NODE_BIN_DIR is injected so Claude Code uses Node >= 20 — mcp-remote@0.1.38
  # requires Node 20+ (uses the File global absent from Node 18).
  if [[ -n "${HF_TOKEN:-}" ]]; then
    register_mcp huggingface \
      -e "PATH=${NODE_BIN_DIR}:${PATH}" \
      -- npx -y mcp-remote@0.1.38 "https://huggingface.co/mcp" \
      --header "Authorization: Bearer ${HF_TOKEN}"
  else
    warn "  Skipping huggingface MCP — HF_TOKEN not set in $ENV_FILE"
  fi

  # splunk-mcp-server — requires SPLUNK_HOST and SPLUNK_TOKEN
  # IMPORTANT: Must use stdio + mcp-remote (not --transport http).
  # Claude Code's HTTP transport cannot disable TLS cert verification.
  # mcp-remote with NODE_TLS_REJECT_UNAUTHORIZED=0 is the only supported
  # approach for Splunk's self-signed cert.
  if [[ -n "${SPLUNK_HOST:-}" && -n "${SPLUNK_TOKEN:-}" ]]; then
    register_mcp splunk-mcp-server \
      -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
      -e "PATH=${NODE_BIN_DIR}:${PATH}" \
      -- npx -y mcp-remote@0.1.38 "https://${SPLUNK_HOST}:8089/services/mcp" \
      --header "Authorization: Bearer ${SPLUNK_TOKEN}"
  else
    warn "  Skipping splunk-mcp-server — SPLUNK_HOST or SPLUNK_TOKEN not set in $ENV_FILE"
  fi
fi

MISSING=()
[[ -z "${GITHUB_TOKEN:-}" ]]          && MISSING+=("GITHUB_TOKEN (required for GitHub MCP)")
[[ -z "${HF_TOKEN:-}" ]]              && MISSING+=("HF_TOKEN (required for Hugging Face MCP — https://huggingface.co/settings/tokens)")
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

# ── Step 8: Shell integration ──────────────────────────────────────────────
SOURCE_LINE="[ -f \"\$HOME/.claude/env.sh\" ] && source \"\$HOME/.claude/env.sh\""

# Detect the user's login shell RC file
SHELL_RC=""
case "${SHELL:-}" in
  */zsh)  SHELL_RC="$HOME/.zshrc" ;;
  */bash) SHELL_RC="$HOME/.bashrc" ;;
  *)
    # Fallback: macOS default is zsh (since Catalina), Linux default is bash
    if [[ "$OS" == "macos" ]]; then
      SHELL_RC="$HOME/.zshrc"
    else
      SHELL_RC="$HOME/.bashrc"
    fi
    ;;
esac

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
echo ""
info "Restart Claude Code for MCP and skill changes to take effect."
echo ""
