---
name: webex-update
description: Sends a short session update message to a Webex room. Searches for the room by name, confirms with the user, then posts a concise paragraph summarising what was worked on. Use at the end of a coding session to share progress with a team or channel.
argument-hint: [optional: topic or session focus]
---

You are sending a Webex session update message on behalf of Andrew Riley.

## Environment check

```
!`source $HOME/.claude/env.sh 2>/dev/null; echo "WEBEX_TOKEN=${WEBEX_TOKEN:+set}"`
```

If `WEBEX_TOKEN` is not set, stop and tell the user to add it to `~/.claude/env.sh`.

## Step 1 — Find the target room

Ask the user: "Which Webex room would you like to send this to? Give me part of the room name to search."

Once they respond, use the Bash tool to search for matching rooms:

```bash
source $HOME/.claude/env.sh
curl -s -H "Authorization: Bearer $WEBEX_TOKEN" \
  "https://webexapis.com/v1/rooms?max=100" | \
  jq --arg q "<search term>" '[.items[] | select(.title | ascii_downcase | contains($q | ascii_downcase)) | {id, title, type}]'
```

Present the matching rooms as a numbered list and ask the user to pick one. If no rooms match, ask for a different search term.

## Step 2 — Gather session context

Use the Bash tool to gather context from the current repo:

```bash
pwd
git log --oneline -10 2>/dev/null
git diff --name-only 2>/dev/null
git diff --name-only --cached 2>/dev/null
```

User's session focus (if provided): $ARGUMENTS

## Step 3 — Draft the message

Write a short-medium Webex message (1–2 paragraphs) summarising the session. Style:
- Conversational and direct — written as Andrew talking to teammates
- Lead with what was accomplished, not what was attempted
- Mention specific files, features, or fixes where relevant
- Close with what's next or what's pending if applicable
- No bullet points — flowing prose only
- No markdown headers — Webex supports **bold** and `code` only

Show the draft to the user and ask: "Happy with this? I'll send it to **<room name>**."

## Step 4 — Send the message

Once confirmed, send using the Bash tool:

```bash
source $HOME/.claude/env.sh
curl -s -X POST \
  -H "Authorization: Bearer $WEBEX_TOKEN" \
  -H "Content-Type: application/json" \
  https://webexapis.com/v1/messages \
  -d "{\"roomId\": \"<room_id>\", \"markdown\": \"<message>\"}"
```

Confirm success with: "Sent to **<room name>**."

If the API returns an error, show the error message and stop.
