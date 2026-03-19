---
name: worklab-scaffold
description: Scaffold a new work lab project — creates directory structure, base configuration, README, and infrastructure documentation. Similar to homelab-scaffold but for work-related lab infrastructure and tooling.
argument-hint: [project name or brief description]
---

You are scaffolding a new work lab project for Andrew Riley.

## Context

Current directory:
```
!`pwd`
```

Existing projects:
```
!`ls $HOME/dev/ 2>/dev/null`
```

## Your task

User's project description: $ARGUMENTS

### Step 1 — Gather requirements

Ask the user **one question at a time** until you have:
- **Project name** (lowercase, hyphens)
- **Project type**: Lab environment / Demo / PoC / Integration / Automation / Documentation / Other
- **Primary goal**: what does this demonstrate, test, or automate?
- **Technology stack**: key tools, platforms, or vendors involved
- **Audience**: internal team, customer demo, partner, self
- **Constraints**: any compliance, network, or access requirements

Infer from `$ARGUMENTS` where possible. Only ask about what's missing.

### Step 2 — Create directory structure

Based on project type, create under `$HOME/dev/<project-name>/`:

**Lab environment / PoC:**
```
<project-name>/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── setup.md
│   └── outcomes.md
├── config/
├── scripts/
└── .env.template
```

**Demo:**
```
<project-name>/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── script.md        ← demo walkthrough script
│   └── setup.md
├── config/
└── scripts/
    └── reset.sh         ← resets demo to clean state
```

**Automation:**
```
<project-name>/
├── README.md
├── docs/
│   └── architecture.md
├── scripts/
└── config/
```

### Step 3 — Generate base files

**README.md** — include:
- Project name and one-line description
- Goal and audience
- Technology stack
- Prerequisites
- Setup steps (placeholder)
- Known limitations (placeholder)

**docs/architecture.md** — structured template covering:
- Overview and purpose
- Technology stack detail
- Network / access requirements
- Data flow
- Dependencies
- Outcomes / success criteria

**docs/setup.md** — step-by-step setup guide template

**docs/outcomes.md** (PoC/demo) — template for recording:
- Test scenarios
- Results
- Observations
- Recommendations

**scripts/reset.sh** (demo type) — placeholder reset script with comments

**.env.template** (if applicable) — placeholder vars with comments

### Step 4 — Initialise git

```bash
cd $HOME/dev/<project-name> && git init && echo ".env" >> .gitignore && git add . && git commit -m "Initial scaffold: <project-name>"
```

### Step 5 — Summary

Tell the user what was created, the directory layout, and suggested next steps.
