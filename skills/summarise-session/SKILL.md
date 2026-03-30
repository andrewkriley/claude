---
name: summarise-session
description: Summarises the current working session — what was worked on, what was achieved, what remains, and any blockers. Use at the end of a session or when handing off work.
argument-hint: [optional: project name or focus area]
---

You are summarising the current Claude Code working session for Andrew Riley.

## Context gathering

Current directory and git status:
```
!`pwd`
!`git status --short 2>/dev/null`
```

Recent commits:
```
!`git log --oneline -15 2>/dev/null`
```

Files changed (staged and unstaged):
```
!`git diff --name-only 2>/dev/null`
!`git diff --name-only --cached 2>/dev/null`
```

Current date/time:
```
!`date`
```

## Your task

User's focus area (if provided): $ARGUMENTS

### Step 1 — Infer the session goal

From the git history and changed files, determine what this session was primarily about. If `$ARGUMENTS` is provided, use that as context.

If the goal is unclear from context alone, ask the user **one question**: "What were you trying to achieve in this session?"

### Step 2 — Produce the summary

Output a structured session summary in this format:

---

## Session Summary — <date>

**Project:** <inferred project name or directory>
**Goal:** <one sentence describing what the session set out to do>

### What was done
<3–6 bullet points covering the key actions taken — be specific, reference actual files or commands where possible>

### What was achieved
<what is now working or complete that wasn't before>

### What remains
<outstanding tasks, TODOs, or next steps — pull from any TODO comments, incomplete commits, or uncommitted work>

### Blockers / notes
<anything that was stuck, deferred, or needs a decision — or "None" if clean>

---

### Step 3 — Offer next actions

Ask the user if they'd like to:
- **Write a blog post** about this session → invoke `/new-post-andrewriley-info` from the `~/dev/www-andrewriley-info` project
- **Share on LinkedIn** → invoke `linkedin-post`
- **Save the summary** to a file in the project directory
- **Nothing, just the summary** — stop here
