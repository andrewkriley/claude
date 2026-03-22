---
name: keep-current
description: Audits README.md, CLAUDE.md, and PROFILE.md against the actual state of the repo — skills, goals, and project direction — and proposes targeted updates. Also infers PROFILE.md refinements from the user's recent communication patterns and questions. Run periodically to keep docs in sync with the project.
argument-hint: [optional: focus area, e.g. "skills" or "profile"]
---

You are auditing the Claude resource library documentation to ensure it accurately reflects the current state of the project.

## Step 1 — Gather current state

Use the Bash tool to collect everything needed:

```bash
# Skills on disk
echo "=SKILLS_ON_DISK="
ls ~/dev/claude/skills/

# Recent git activity (last 20 commits)
echo "=RECENT_COMMITS="
git -C ~/dev/claude log --oneline -20

# Files changed in last 10 commits
echo "=RECENTLY_CHANGED="
git -C ~/dev/claude diff --name-only HEAD~10..HEAD 2>/dev/null

# Blog posts (most recent 5)
echo "=RECENT_POSTS="
ls -t ~/dev/www-andrewriley-info/content/post/2026/ 2>/dev/null | head -5
```

Then read the following files in parallel:
- `~/dev/claude/README.md`
- `~/dev/claude/CLAUDE.md`
- `~/dev/claude/PROFILE.md`
- Each `~/dev/claude/skills/<name>/SKILL.md` for every skill found on disk

## Step 2 — Audit README.md and CLAUDE.md

Check each of the following against the actual repo state:

### Skills table audit
- Are all skills in `skills/` listed in the README skills table and the CLAUDE.md skills quick reference?
- Are any skills listed in the docs but missing from disk?
- Are the descriptions accurate for each skill?

### MCP server audit
- Do the MCP server sections reflect the actual registered servers and their configuration?
- Is the Claude Desktop section present and accurate?

### Path conventions audit
- Do all documented paths still exist and match the repo structure?

### General staleness
- Are there any sections that reference old approaches, removed features, or outdated commands?
- Does the repo structure diagram match `skills/` and `scripts/` on disk?

## Step 3 — Audit PROFILE.md

Review the PROFILE.md against evidence of Andrew's actual communication style from:
- **Blog post topics and tone** (infer from recent post slugs and session context)
- **Skills built** (what problems he cares enough about to automate)
- **Questions asked in this session** (what he reaches for, how he frames problems)
- **MCP integrations in use** (Splunk, HuggingFace, GitHub, Slack, Gmail, Calendar — infer focus areas)

Look for gaps or updates worth making:
- Missing focus areas (e.g. Splunk/observability now prominent)
- Outdated role description or technical focus
- Communication style traits not yet captured
- Tools or workflows now central to his practice

Do NOT fabricate traits — only propose updates supported by observable evidence from the repo and session.

## Step 4 — Present proposed changes

For each document, present a clear diff-style summary of what you propose to change and **why**:

---

### README.md

**Proposed changes:**
- [ ] `<what>` — `<why>`

### CLAUDE.md

**Proposed changes:**
- [ ] `<what>` — `<why>`

### PROFILE.md

**Proposed changes:**
- [ ] `<what>` — `<why>`

**No changes needed:**
- `<section>` — already accurate

---

If nothing needs updating in a document, say so explicitly. Do not propose changes for the sake of it.

## Step 5 — Confirm and apply

Use the AskUserQuestion tool to ask:

> Here are the proposed updates across README.md, CLAUDE.md, and PROFILE.md.
> How would you like to proceed?

Options:
- **Apply all** — apply every proposed change
- **Review each** — walk through each change one at a time for approval
- **Apply docs only (skip PROFILE.md)** — apply README/CLAUDE changes, leave PROFILE untouched
- **Cancel** — make no changes

## Step 6 — Apply approved changes

For each approved change, use the Edit tool to make the update precisely — no rewrites of surrounding content.

After all edits are applied, run:

```bash
cd ~/dev/claude
git add README.md CLAUDE.md PROFILE.md
git status
```

Show the user what is staged, then ask:

> Changes staged. Commit and push to dev?

If confirmed:
```bash
cd ~/dev/claude && git commit -m "docs: keep-current audit — sync skills, MCP config, and profile updates" && git push
```

Tell the user what was updated and suggest running `/repo-status` to check overall sync state.
