---
name: repo-status
description: Checks the sync status of a git repository — local vs remote branches, commits ahead/behind, open PRs, and working tree state. Works across any project. Use when the user asks "what's the status of the repo", "are local and remote in sync", "check the branches", or "what's the state of dev and main".
argument-hint: [optional: path to repo, defaults to current working directory]
---

You are checking the full sync status of a git repository and producing a clear summary.

## Step 1 — Identify the repo

If `$ARGUMENTS` is provided, use it as the repo path. Otherwise use the current working directory.

Use the Bash tool to confirm it is a git repo and get its remote URL:

```bash
REPO="${ARGUMENTS:-$(pwd)}"
cd "$REPO"
git rev-parse --show-toplevel 2>/dev/null || echo "NOT A GIT REPO"
git remote get-url origin 2>/dev/null
```

If it is not a git repo, tell the user and stop.

## Step 2 — Fetch and collect status

Run all of the following in a single Bash tool call:

```bash
cd "${ARGUMENTS:-$(pwd)}"

# Fetch silently to update remote-tracking refs
git fetch --all --quiet 2>/dev/null

# Repo identity
echo "=REPO=$(git rev-parse --show-toplevel)"
echo "=REMOTE=$(git remote get-url origin 2>/dev/null)"
echo "=CURRENT_BRANCH=$(git branch --show-current)"

# All local branches with tracking info
echo "=LOCAL_BRANCHES="
git branch -v

# All remote branches
echo "=REMOTE_BRANCHES="
git branch -rv

# Working tree
echo "=STATUS="
git status --short

# Stash
echo "=STASH_COUNT=$(git stash list | wc -l | tr -d ' ')"

# Commits on dev not in main (if both exist)
echo "=DEV_AHEAD_MAIN="
git log main..dev --oneline 2>/dev/null || echo "(branches not found)"

# Commits on main not in dev (if both exist)
echo "=MAIN_AHEAD_DEV="
git log dev..main --oneline 2>/dev/null || echo "(branches not found)"

# Open PRs (requires gh CLI)
echo "=OPEN_PRS="
gh pr list --state open --json number,title,headRefName,baseRefName,url \
  --template '{{range .}}#{{.number}} [{{.headRefName}}→{{.baseRefName}}] {{.title}} {{.url}}{{"\n"}}{{end}}' 2>/dev/null || echo "(gh CLI not available)"
```

## Step 3 — Produce the summary

Analyse the output and present a clean, structured summary. Use this format:

---

**Repo:** `<repo name>` (`<remote URL>`)
**Current branch:** `<branch>`

### Branch alignment

For each branch that exists both locally and remotely, state clearly whether it is:
- ✅ **In sync** — local and remote at the same commit
- ⬆️ **Local ahead** — N commits not yet pushed
- ⬇️ **Local behind** — N commits to pull
- ↕️ **Diverged** — both sides have commits the other doesn't

Focus on `main` and `dev` first, then any other active branches.

### Commits: dev vs main

List commits that are on `dev` but not `main` (pending merge). If none, say so.
List any commits on `main` not yet in `dev` (needs a merge-back), if any.

### Open PRs

List any open PRs with number, title, branch direction, and URL.
If none, say so.

### Working tree

State whether the working tree is clean or has uncommitted changes/untracked files. If dirty, briefly describe what is modified.

### Stash

If stash entries exist, note the count.

### Overall assessment

One or two sentences on the overall state — e.g. "Branches are fully aligned, no outstanding work." or "dev is 2 commits ahead of main with PR #8 open and ready to merge."

---

Keep the summary factual and concise. Do not reproduce raw git output.
