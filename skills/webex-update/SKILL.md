---
name: webex-update
description: Sends a short session update message to a Webex room. Searches for the room by name, confirms with the user, then posts a concise paragraph summarising what was worked on. Use at the end of a coding session to share progress with a team or channel.
argument-hint: [optional: topic or session focus]
---

You are sending a Webex session update message on behalf of Andrew Riley.

## Environment check

Use the Bash tool to verify credentials and refresh the token if needed:

```bash
source $HOME/.claude/env.sh 2>/dev/null
if [ -z "$WEBEX_TOKEN" ]; then echo "WEBEX_TOKEN=missing"; else echo "WEBEX_TOKEN=set"; fi
if [ -z "$WEBEX_REFRESH_TOKEN" ]; then echo "WEBEX_REFRESH_TOKEN=missing"; else echo "WEBEX_REFRESH_TOKEN=set"; fi
```

If `WEBEX_TOKEN` is missing, stop and tell the user to run `$HOME/dev/claude/scripts/webex-oauth.sh` first.

If the token is set but an API call later returns a 401, use the Bash tool to refresh it:

```bash
source $HOME/.claude/env.sh
RESPONSE=$(curl -s -X POST "https://webexapis.com/v1/access_token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=refresh_token" \
  --data-urlencode "client_id=$WEBEX_CLIENT_ID" \
  --data-urlencode "client_secret=$WEBEX_CLIENT_SECRET" \
  --data-urlencode "refresh_token=$WEBEX_REFRESH_TOKEN")
NEW_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
NEW_REFRESH=$(echo "$RESPONSE" | jq -r '.refresh_token')
echo "new_token=$NEW_TOKEN"
echo "new_refresh=$NEW_REFRESH"
```

Then update `~/.claude/env.sh` with the new tokens using sed, and retry the failed request.

## Step 1 — Find the target

Ask the user: "Who or which room would you like to send this to? Give me part of a name to search."

Once they respond, search both rooms and people in parallel using the Bash tool:

**Rooms** (spaces the bot is a member of):
```bash
source $HOME/.claude/env.sh
curl -s -H "Authorization: Bearer $WEBEX_TOKEN" \
  "https://webexapis.com/v1/rooms?max=100" | \
  jq --arg q "<search term>" '[.items[] | select(.title | ascii_downcase | contains($q | ascii_downcase)) | {target: .title, id: .id, type: "room"}]'
```

**People** (Webex directory search):
```bash
source $HOME/.claude/env.sh
curl -s -H "Authorization: Bearer $WEBEX_TOKEN" \
  "https://webexapis.com/v1/people?displayName=<search term>&max=10" | \
  jq '[.items[] | {target: .displayName, id: .id, email: .emails[0], type: "person"}]'
```

Combine the results and present as a numbered list, labelling each as **room** or **person**. Ask the user to pick one. If nothing matches, ask for a different search term.

When sending to a **person**, use `toPersonId` instead of `roomId` in the message payload.

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

Once confirmed, send using the Bash tool.

For a **room**:
```bash
source $HOME/.claude/env.sh
curl -s -X POST \
  -H "Authorization: Bearer $WEBEX_TOKEN" \
  -H "Content-Type: application/json" \
  https://webexapis.com/v1/messages \
  -d "{\"roomId\": \"<room_id>\", \"markdown\": \"<message>\"}"
```

For a **person**:
```bash
source $HOME/.claude/env.sh
curl -s -X POST \
  -H "Authorization: Bearer $WEBEX_TOKEN" \
  -H "Content-Type: application/json" \
  https://webexapis.com/v1/messages \
  -d "{\"toPersonId\": \"<person_id>\", \"markdown\": \"<message>\"}"
```

Confirm success with: "Sent to **<room name>**."

If the API returns an error, show the error message and stop.
