---
name: skills
description: Lists all available Claude Code skills with descriptions and usage hints. Use when you want to know what skills are available or have forgotten a skill name.
argument-hint: [optional: filter keyword]
---

You are listing all available Claude Code skills for Andrew Riley.

## Available skills

```
!`ls $HOME/.claude/skills/ 2>/dev/null | sort`
```

## Skill details

```
!`for skill_dir in $HOME/.claude/skills/*/; do skill=$(basename "$skill_dir"); skill_file="$skill_dir/SKILL.md"; if [ -f "$skill_file" ]; then name=$(grep '^name:' "$skill_file" | head -1 | sed 's/name: //'); desc=$(grep '^description:' "$skill_file" | head -1 | sed 's/description: //'); hint=$(grep '^argument-hint:' "$skill_file" | head -1 | sed 's/argument-hint: //'); echo "/$name — $desc"; [ -n "$hint" ] && echo "  Usage: /$name $hint"; echo; fi; done`
```

## Filter

User filter (if provided): $ARGUMENTS

If `$ARGUMENTS` is provided, only show skills whose name or description contains that keyword (case-insensitive).

## Output

Present the skills as a clean formatted list. Group them by category if there are more than 6:
- **Content** — blog/LinkedIn/writing skills
- **Scaffold** — project creation skills
- **Workflow** — session and productivity skills

If `$ARGUMENTS` was provided and no skills match, say so and suggest the closest match.
