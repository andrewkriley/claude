#!/usr/bin/env bash
# release.sh — Bump SemVer version, commit, tag, and push.
#
# Usage:
#   ./scripts/release.sh patch    # 0.1.0 → 0.1.1
#   ./scripts/release.sh minor    # 0.1.1 → 0.2.0
#   ./scripts/release.sh major    # 0.2.0 → 1.0.0
#
# Prerequisites:
#   - Clean working tree (no uncommitted changes)
#   - On the 'main' branch
#   - Remote 'origin' must be reachable

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_DIR/VERSION"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

# ── Validate arguments ────────────────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  error "Usage: $(basename "$0") <patch|minor|major>"
fi

BUMP_TYPE="$1"
case "$BUMP_TYPE" in
  patch|minor|major) ;;
  *) error "Invalid bump type '$BUMP_TYPE'. Must be patch, minor, or major." ;;
esac

# ── Validate environment ──────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  error "git is required but not found."
fi

if ! git -C "$REPO_DIR" rev-parse --git-dir &>/dev/null; then
  error "Not inside a git repository."
fi

CURRENT_BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  error "Releases must be made from 'main'. Currently on '$CURRENT_BRANCH'."
fi

if ! git -C "$REPO_DIR" diff --quiet || ! git -C "$REPO_DIR" diff --cached --quiet; then
  error "Working tree is not clean. Commit or stash changes before releasing."
fi

git -C "$REPO_DIR" fetch origin main --quiet
LOCAL_SHA="$(git -C "$REPO_DIR" rev-parse HEAD)"
REMOTE_SHA="$(git -C "$REPO_DIR" rev-parse origin/main)"
if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  error "Local 'main' is not in sync with 'origin/main'. Run: git pull"
fi

# ── Read and parse current version ───────────────────────────────────────────
if [[ ! -f "$VERSION_FILE" ]]; then
  error "VERSION file not found at $VERSION_FILE"
fi

CURRENT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  error "VERSION file contains invalid SemVer: '$CURRENT_VERSION'"
fi

MAJOR="$(echo "$CURRENT_VERSION" | cut -d. -f1)"
MINOR="$(echo "$CURRENT_VERSION" | cut -d. -f2)"
PATCH="$(echo "$CURRENT_VERSION" | cut -d. -f3)"

# ── Compute new version ───────────────────────────────────────────────────────
case "$BUMP_TYPE" in
  major)
    MAJOR=$(( MAJOR + 1 ))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$(( MINOR + 1 ))
    PATCH=0
    ;;
  patch)
    PATCH=$(( PATCH + 1 ))
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
TAG="v${NEW_VERSION}"

info "Bumping: $CURRENT_VERSION → $NEW_VERSION ($BUMP_TYPE)"
echo ""
echo "  Version:  $CURRENT_VERSION → $NEW_VERSION"
echo "  Tag:      $TAG"
echo "  Branch:   $CURRENT_BRANCH"
echo ""
read -r -p "Proceed? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  warn "Aborted."
  exit 0
fi

# ── Write new VERSION ─────────────────────────────────────────────────────────
printf '%s\n' "$NEW_VERSION" > "$VERSION_FILE"
info "VERSION updated to $NEW_VERSION"

# ── Commit and tag ────────────────────────────────────────────────────────────
git -C "$REPO_DIR" add "$VERSION_FILE"
git -C "$REPO_DIR" commit -m "chore: release $TAG"
info "Committed: chore: release $TAG"

git -C "$REPO_DIR" tag -a "$TAG" -m "Release $TAG"
info "Tagged: $TAG"

# ── Push commit and tag ───────────────────────────────────────────────────────
git -C "$REPO_DIR" push origin main
git -C "$REPO_DIR" push origin "$TAG"
info "Pushed commit and tag to origin"

echo ""
info "Release $TAG created. GitHub Actions will build the release notes."
info "Monitor at: https://github.com/andrewkriley/claude/actions"
