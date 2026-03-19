---
name: homelab-scaffold
description: Scaffold a new homelab project — creates directory structure, base configuration, README, and infrastructure documentation. Use when starting a new homelab service, automation, or infrastructure component.
argument-hint: [project name or brief description]
---

You are scaffolding a new homelab project for Andrew Riley.

## Context

Current directory:
```
!`pwd`
```

Existing homelab projects:
```
!`ls $HOME/dev/ 2>/dev/null`
```

Homelab stack reference: Proxmox, Terraform, Ansible, Docker, LXC, K3s, GitLab CI/CD, Traefik, Home Assistant, UniFi.

## Your task

User's project description: $ARGUMENTS

### Step 1 — Gather requirements

Ask the user **one question at a time** until you have:
- **Project name** (lowercase, hyphens)
- **Project type**: Container service / VM config / Ansible role / Terraform module / Home Assistant integration / K3s workload / Other
- **Primary goal**: what does this run or automate?
- **Infrastructure target**: which part of the homelab does this live on?
- **Dependencies**: other services, volumes, networks it relies on

Infer from `$ARGUMENTS` where possible. Only ask about what's missing.

### Step 2 — Create directory structure

Based on project type, create under `$HOME/dev/<project-name>/`:

**Container service:**
```
<project-name>/
├── README.md
├── docker-compose.yml
├── .env.template
├── config/
└── docs/
    └── architecture.md
```

**Ansible role:**
```
<project-name>/
├── README.md
├── tasks/
│   └── main.yml
├── defaults/
│   └── main.yml
├── templates/
├── handlers/
│   └── main.yml
└── docs/
    └── architecture.md
```

**Terraform module:**
```
<project-name>/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.template
└── docs/
    └── architecture.md
```

**K3s workload:**
```
<project-name>/
├── README.md
├── manifests/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── docs/
    └── architecture.md
```

### Step 3 — Generate base files

**README.md** — include:
- Project name and one-line description
- What it runs and why
- Infrastructure target and dependencies
- Deployment steps (placeholder)
- Environment variables / configuration (placeholder)
- Known issues (placeholder)

**docker-compose.yml** (if container service) — a minimal skeleton with correct structure, image placeholder, and common patterns (restart policy, networks, volumes).

**.env.template** (if applicable) — placeholder vars with comments explaining each.

**docs/architecture.md** — structured template covering:
- Overview and purpose
- Network / VLAN placement
- Volumes and persistence
- Dependencies and integration points
- Backup considerations
- Known limitations

### Step 4 — Initialise git

```bash
cd $HOME/dev/<project-name> && git init && echo ".env" >> .gitignore && git add . && git commit -m "Initial scaffold: <project-name>"
```

### Step 5 — Summary

Tell the user what was created, the directory layout, and suggested next steps.
