---
name: new-post-andrewriley-info
description: Creates a new Hugo blog post from a recent coding session. Use when the user wants to document work they've done, write a technical how-to, or blog about a project. Invoke automatically when the user says things like "write a post about", "blog about what we did", "create a post from our session", or "document this".
argument-hint: [topic or brief description]
---

You are helping create a new Hugo blog post for andrewriley.info.

## Author profile

Read `$HOME/.claude/PROFILE.md` before writing. Use it to inform the writing voice, tone, and focus areas. Key points:
- First-person, conversational, enthusiastic — not formal or corporate
- Honest about imperfection; call out what's still broken or not ideal
- Practical focus: real commands, real config, real errors
- Creative formats are on-brand (e.g. narrative storytelling for technical topics)
- Family context matters — if the project solves a household problem, say so

## Current datetime

Use the Bash tool to get the current datetime with the correct local timezone offset:

```bash
date '+%Y-%m-%dT%H:%M:%S%z' | sed 's/\([+-][0-9][0-9]\)\([0-9][0-9]\)$/\1:\2/'
```

This produces RFC3339 format with the correct AEST (+10:00) or AEDT (+11:00) offset depending on daylight saving time. Use the exact output as the `date` field in the front matter. Do not round, adjust, or substitute a different time.

## Recent coding context

Recent git commits:
```
!`git log --oneline -20 2>/dev/null`
```

Files changed in the last 5 commits:
```
!`git diff --name-only HEAD~5..HEAD 2>/dev/null`
```

## Your task

User's topic/description (if provided): $ARGUMENTS

### Step 1 — Understand the session

Read the git history and changed files above to understand what was worked on.

If `$ARGUMENTS` is provided, use that as the primary focus.

Otherwise, infer the topic from recent commits. If the topic is still unclear, ask the user **one focused question**: "What was the main thing you worked on that you'd like to write about?"

Do NOT ask multiple questions. Infer as much as possible.

### Step 2 — Choose a slug and title

Pick a short, lowercase, hyphenated slug (2–4 words) that describes the topic well.
Examples: `nginx-reverse-proxy`, `docker-gpu-setup`, `traefik-tls-cert`

### Step 3 — Create the post file

Determine the current year from the system date context (e.g. if today is 2026-03-02, the year is `2026`).

The local blog repository is at `$HOME/dev/www-andrewriley-info`. All file operations and git commands in this skill must be run from that directory.

Use the Write tool to create the file at:
`$HOME/dev/www-andrewriley-info/content/post/<year>/<slug>/index.md`

Use this YAML front matter:

```yaml
---
title: <descriptive, human-readable title>
description: <one sentence summary of what the post covers>
slug: <the exact slug chosen in Step 2>
date: <current datetime in RFC3339 format, e.g. 2026-03-02T20:30:00+11:00>
tags:
    - <2-4 relevant lowercase tags>
categories:
    - technology
---
```

The `slug` field is required. Hugo derives the URL from it via the permalink rule `post = "/p/:slug/"`. Always set `slug` to the exact value chosen in Step 2.

### Step 4 — Write the post body

Follow the style described in the author profile. Keep it practical and useful.

Structure:
1. **Brief intro** — what the problem was or what you were trying to do, and why
2. **Sections with `## ` headings** — walk through what was done step by step
3. **Code blocks** — include actual commands, config snippets, and outputs where relevant
4. **Errors & fixes** — if troubleshooting was involved, document what went wrong and how it was resolved
5. **Resources** — links to docs or references used (optional but good)

Tone: follow the author's voice — conversational, first-person, enthusiastic, honest about trade-offs and rough edges.

Do NOT add a cover image line unless you know an image exists in the post directory.

### Step 5 — Commit to dev branch

Use the Bash tool to run all git commands from `$HOME/dev/www-andrewriley-info`:

1. Ensure you are on the `dev` branch:
   ```bash
   cd $HOME/dev/www-andrewriley-info && git checkout dev 2>/dev/null || git checkout -b dev origin/main 2>/dev/null || git checkout -b dev
   ```

2. Stage and commit:
   ```bash
   cd $HOME/dev/www-andrewriley-info && git add content/post/<year>/<slug>/ && git commit -m "Add post: <title>"
   ```

3. Push:
   ```bash
   cd $HOME/dev/www-andrewriley-info && git push -u origin dev
   ```

### Step 6 — Validate the post URL

Wait 2 minutes for the CI/CD pipeline to build:
```bash
sleep 120
```

Fetch `https://dev.andrewriley.info/p/<slug>/` with the WebFetch tool. Prompt: "Does this page exist and contain the blog post content? Return yes or no and a brief description."

- If found: tell the user the post is live on dev and show the URL.
- If 404: let the user know and suggest waiting for the build, then proceed to Step 7.

### Step 7 — Ask to merge into main

Ask the user:

> The post is committed to `dev` and available at `https://dev.andrewriley.info/p/<slug>/` for review.
>
> Would you like to merge it into `main` and publish it live?

Use the AskUserQuestion tool with options: **Yes, merge to main** / **No, leave it on dev for now**.

If confirmed:
```bash
cd $HOME/dev/www-andrewriley-info && git checkout main && git merge dev --no-ff -m "Merge post: <title> from dev" && git push origin main
```

Tell the user the post is now live at `https://andrewriley.info/p/<slug>/`.
