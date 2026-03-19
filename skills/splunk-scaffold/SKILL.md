---
name: splunk-scaffold
description: Scaffold a new Splunk project — creates directory structure, base configuration, README, and initial documentation. Use when starting a new Splunk app, dashboard, alert set, or search library.
argument-hint: [project name or brief description]
---

You are scaffolding a new Splunk project for Andrew Riley.

## Context

Current directory:
```
!`pwd`
```

Existing Splunk projects:
```
!`find $HOME/dev -maxdepth 3 -name "default" -path "*/splunk/*" 2>/dev/null | head -10 || echo "(none found)"`
```

## Your task

User's project description: $ARGUMENTS

### Step 1 — Gather requirements

Ask the user **one question at a time** until you have:
- **Project name** (will become the app/directory name — lowercase, hyphens)
- **Project type**: App / Dashboard collection / Alert library / Search library / Other
- **Data sources**: what indexes or sourcetypes will this work with?
- **Primary goal**: what problem does this solve?
- **Deployment target**: Splunk Cloud / Splunk Enterprise / Splunk Free / SIEM integration

Infer from `$ARGUMENTS` where possible. Only ask about what's missing.

### Step 2 — Create directory structure

Based on the project type, create the appropriate structure under `$HOME/dev/<project-name>/`:

**For an App:**
```
<project-name>/
├── README.md
├── default/
│   ├── app.conf
│   ├── transforms.conf
│   ├── props.conf
│   └── savedsearches.conf
├── lookups/
├── dashboards/
├── searches/
└── docs/
    └── architecture.md
```

**For a Dashboard collection:**
```
<project-name>/
├── README.md
├── dashboards/
├── searches/
└── docs/
    └── architecture.md
```

**For an Alert library:**
```
<project-name>/
├── README.md
├── alerts/
├── searches/
└── docs/
    └── architecture.md
```

### Step 3 — Generate base files

**README.md** — include:
- Project name and one-line description
- Purpose and problem it solves
- Data sources (indexes, sourcetypes)
- Deployment target
- Getting started steps (placeholder)
- Known limitations (placeholder)

**default/app.conf** (if App type):
```ini
[launcher]
author = Andrew Riley
description = <project description>
version = 0.1.0

[ui]
is_visible = 1
label = <Project Name>

[package]
id = <project-name>
```

**docs/architecture.md** — structured template covering:
- Overview
- Data flow
- Key searches / alerts
- Dependencies
- Deployment notes

### Step 4 — Initialise git

```bash
cd $HOME/dev/<project-name> && git init && git add . && git commit -m "Initial scaffold: <project-name>"
```

### Step 5 — Summary

Tell the user what was created, the directory layout, and suggested next steps (e.g. add real searches, connect to data source, deploy to Splunk instance).
