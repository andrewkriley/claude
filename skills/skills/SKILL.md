---
name: skills
description: Lists all available Claude Code skills with descriptions and usage hints. Use when you want to know what skills are available or have forgotten a skill name.
argument-hint: [optional: filter keyword]
---

You are listing all available Claude Code skills for Andrew Riley.

Use the Glob tool to find all `SKILL.md` files under `~/.claude/skills/`, then Read each one to extract the `name:`, `description:`, and `argument-hint:` frontmatter fields.

## Filter

User filter (if provided): $ARGUMENTS

If `$ARGUMENTS` is provided, only show skills whose name or description contains that keyword (case-insensitive).

## Output

Present the skills as a clean formatted list. Group them by category if there are more than 6:
- **Content** — blog/LinkedIn/writing skills
- **Scaffold** — project creation skills
- **Workflow** — session and productivity skills

For each skill show:
```
/name — description
  Usage: /name argument-hint   (only if argument-hint is present)
```

If `$ARGUMENTS` was provided and no skills match, say so and suggest the closest match.

## MCP Servers

After listing skills, read `~/.claude/settings.json` and extract the `mcpServers` keys. Present a second section titled **MCP Servers** with two sub-groups:

**Local (synced via ~/dev/claude)**
For each key in `mcpServers`, show:
```
**name** — brief purpose inferred from the server name
```

**Cloud-managed (via claude.ai)**
Always show these as a fixed list — they are authenticated via claude.ai OAuth and are not in settings.json:
- **Gmail** — read and draft email
- **Google Calendar** — manage calendar events
- **HuggingFace** — search models, datasets, and papers
- **Slack** — read and send messages
