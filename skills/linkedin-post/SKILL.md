---
name: linkedin-post
description: Draft and publish a LinkedIn post on behalf of Andrew Riley. Use when the user wants to share something on LinkedIn — a project, an insight, a win, a lesson learned, or a reaction to something in the industry.
argument-hint: [topic, project, or brief description]
---

You are drafting a LinkedIn post for Andrew Riley.

## Environment

Use the Bash tool to verify credentials are available:

```bash
source $HOME/.claude/env.sh 2>/dev/null
if [ -z "$LINKEDIN_TOKEN" ]; then echo "LINKEDIN_TOKEN=missing"; else echo "LINKEDIN_TOKEN=set"; fi
echo "LINKEDIN_PERSON_URN=$LINKEDIN_PERSON_URN"
```

If `LINKEDIN_TOKEN` is missing, stop and tell the user to run `$HOME/dev/claude/scripts/linkedin-oauth.sh` first to complete OAuth setup.

## Author profile

Read `$HOME/.claude/PROFILE.md` before writing. Key points for LinkedIn:
- **Name:** Andrew Riley, Tech Lead / Architect based in Sydney, Australia
- **Tone:** Enthusiastic and engaging — energetic, story-driven, opinionated. NOT corporate or stiff.
- **Voice:** First-person, authentic, personal. Writes like a peer sharing something cool, not a brand publishing content.
- **Themes:** Homelab, AI/LLMs, cloud infrastructure, GitOps, Home Assistant, DIY, family-driven motivation
- **Honest:** Shares what went wrong as readily as what went right
- **Ties personal projects to professional insight** — the homelab isn't just a hobby, it's a learning platform

## Topic

User's topic or description (if provided): $ARGUMENTS

If `$ARGUMENTS` is empty, ask the user **one question**: "What would you like to post about?"

## Your task

### Step 1 — Understand the angle

Identify the core insight, story, or value this post should convey. Good LinkedIn posts from Andrew have one of these angles:
- "Here's something I built and what I learned"
- "Here's a problem I solved (and it was messier than expected)"
- "Here's a hot take or strong opinion on [topic]"
- "Here's something I'm excited about right now"

### Step 2 — Draft the post

**Structure:**
1. **Hook** (1–2 lines) — grab attention; a bold statement, a question, or a surprising fact. No "I'm excited to announce" fluff.
2. **Story or context** (2–4 short paragraphs) — what happened, why it matters, what was hard or interesting
3. **Insight or takeaway** (1–2 lines) — the "so what"
4. **Optional call to action** — a question to spark discussion

**Formatting rules:**
- Short paragraphs — 1–3 lines each, blank lines between
- No bullet walls — prose first; bullets only for 3+ distinct items
- No em-dash overuse
- 2–4 relevant hashtags at the end only
- No buzzwords: "leverage", "synergy", "excited to share", "delighted to announce"
- **Length:** 150–300 words

### Step 3 — Review

Show the draft and ask:
- Does this capture the right angle?
- Any details to add, change, or cut?

Offer one round of revisions. Then ask the user to confirm publishing.

### Step 4 — Publish to LinkedIn

Once the user confirms, load credentials:
```bash
source $HOME/.claude/env.sh
```

Post to LinkedIn API:
```bash
source $HOME/.claude/env.sh && curl -s -o /tmp/li_response.json -w "%{http_code}" -X POST https://api.linkedin.com/v2/ugcPosts \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" \
  -H "X-Restli-Protocol-Version: 2.0.0" \
  -H "Content-Type: application/json" \
  -d "{
    \"author\": \"$LINKEDIN_PERSON_URN\",
    \"lifecycleState\": \"PUBLISHED\",
    \"specificContent\": {
      \"com.linkedin.ugc.ShareContent\": {
        \"shareCommentary\": { \"text\": \"POST_TEXT_HERE\" },
        \"shareMediaCategory\": \"NONE\"
      }
    },
    \"visibility\": {
      \"com.linkedin.ugc.MemberNetworkVisibility\": \"PUBLIC\"
    }
  }"
```

Replace `POST_TEXT_HERE` with the approved post text (escape any double quotes with `\"`).

Check the HTTP status code:
- `201` — success. Tell the user the post is live on LinkedIn.
- `401` — token expired. Tell the user to re-run `$HOME/dev/claude/scripts/linkedin-oauth.sh` to refresh.
- Any other error — show the response body from `/tmp/li_response.json` and stop.
