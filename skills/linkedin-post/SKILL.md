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

### Step 3 — Review & image option

Show the draft and ask:
- Does this capture the right angle?
- Any details to add, change, or cut?

Also ask: **"Would you like to include an image with this post?"** Offer three options:
1. **AI-generated** — Claude generates one via HuggingFace based on the post topic
2. **Provide your own** — user supplies a local file path
3. **No image** — text-only post

Offer one round of revisions on the post text. Then ask the user to confirm publishing.

### Step 4 — Prepare image (if requested)

#### Option 1 — AI-generated image

Write a short image generation prompt (under 70 words) that visually represents the post topic. Requirements:
- Dark, clean background — works as a standalone visual without competing with text
- No circuit board traces, no text or labels, no holographic grids
- Prefer real-world photography styles: dramatic landscapes, dark server room ambiance, macro textures, abstract smooth gradients
- Cinematic quality — wide depth of field, subtle dramatic lighting

Use the `mcp__huggingface__gr1_z_image_turbo_generate` tool:
- `prompt`: the prompt above
- `resolution`: `"1024x1024 ( 1:1 )"` (square works best for LinkedIn feed images)
- `random_seed`: `true`
- `steps`: `8`

Download the returned image URL to a temp file:
```bash
curl -sL "<image_url>" -o /tmp/li_post_image.png
```

Show the user what prompt was used and confirm they're happy with the image before proceeding.

#### Option 2 — User-provided image

Use the path the user supplied. If it's a relative path, resolve it against `$HOME`. Confirm the file exists:
```bash
ls -lh <image_path>
```

Set `IMAGE_PATH=<image_path>` for use in Step 5.

For Option 1, set `IMAGE_PATH=/tmp/li_post_image.png`.

### Step 5 — Publish to LinkedIn

#### With image (3-step upload)

**Step 5a — Register the upload:**
```bash
source $HOME/.claude/env.sh && curl -s -X POST \
  "https://api.linkedin.com/v2/assets?action=registerUpload" \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" \
  -H "X-Restli-Protocol-Version: 2.0.0" \
  -H "Content-Type: application/json" \
  -d "{
    \"registerUploadRequest\": {
      \"recipes\": [\"urn:li:digitalmediaRecipe:feedshare-image\"],
      \"owner\": \"$LINKEDIN_PERSON_URN\",
      \"serviceRelationships\": [{
        \"relationshipType\": \"OWNER\",
        \"identifier\": \"urn:li:userGeneratedContent\"
      }]
    }
  }"
```

Extract `uploadUrl` and `asset` URN from the response.

**Step 5b — Upload the image binary:**
```bash
source $HOME/.claude/env.sh && curl -s -o /dev/null -w "%{http_code}" -X PUT \
  "<uploadUrl>" \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" \
  -H "media-type-family: STILLIMAGE" \
  -H "Content-Type: image/png" \
  --data-binary "@<IMAGE_PATH>"
```

Expect HTTP `201`. If not, stop and report the error.

**Step 5c — Publish the post with image:**
```bash
source $HOME/.claude/env.sh && curl -s -D /tmp/li_headers.txt -o /tmp/li_response.json -w "%{http_code}" -X POST \
  "https://api.linkedin.com/v2/ugcPosts" \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" \
  -H "X-Restli-Protocol-Version: 2.0.0" \
  -H "Content-Type: application/json" \
  -d "{
    \"author\": \"$LINKEDIN_PERSON_URN\",
    \"lifecycleState\": \"PUBLISHED\",
    \"specificContent\": {
      \"com.linkedin.ugc.ShareContent\": {
        \"shareCommentary\": { \"text\": \"POST_TEXT_HERE\" },
        \"shareMediaCategory\": \"IMAGE\",
        \"media\": [{
          \"status\": \"READY\",
          \"description\": { \"text\": \"POST_IMAGE_ALT_TEXT\" },
          \"media\": \"ASSET_URN_HERE\",
          \"title\": { \"text\": \"POST_IMAGE_TITLE\" }
        }]
      }
    },
    \"visibility\": {
      \"com.linkedin.ugc.MemberNetworkVisibility\": \"PUBLIC\"
    }
  }"
```

Replace `POST_TEXT_HERE`, `ASSET_URN_HERE`, `POST_IMAGE_ALT_TEXT`, and `POST_IMAGE_TITLE` with appropriate values. Escape any double quotes in the post text with `\"`.

#### Without image (text-only)

```bash
source $HOME/.claude/env.sh && curl -s -D /tmp/li_headers.txt -o /tmp/li_response.json -w "%{http_code}" -X POST \
  "https://api.linkedin.com/v2/ugcPosts" \
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

### Step 6 — Confirm result

Check the HTTP status code from the publish step:
- `201` — success. Extract the post URN and construct the URL:

```bash
# Extract the post URN from the X-Restli-Id response header
POST_URN=$(grep -i "x-restli-id:" /tmp/li_headers.txt | tr -d '\r' | awk '{print $2}')
echo "Post URN: $POST_URN"
# Construct the post URL
echo "Post URL: https://www.linkedin.com/feed/update/${POST_URN}/"
```

Tell the user the post is live and show the direct URL:
> Post published! View it at: `https://www.linkedin.com/feed/update/<URN>/`

- `401` — token expired. Tell the user to re-run `$HOME/dev/claude/scripts/linkedin-oauth.sh` to refresh.
- Any other error — show the response body from `/tmp/li_response.json` and stop.
