## Cursor Cloud specific instructions

This is a configuration-as-code repo (Claude Code resource library), not a traditional application with running services. There is no backend, frontend, or database to start.

### What "running the application" means

The primary executable is `setup.sh`, which bootstraps `~/.claude/` by symlinking skills/profile, generating config, creating `env.sh`, and (when `claude` CLI is available) registering MCP servers. Running `setup.sh` from the repo root is the equivalent of "starting the app."

### Lint

```bash
shellcheck -S warning setup.sh scripts/*.sh
```

This mirrors the CI ShellCheck job in `.github/workflows/security.yml`.

### Build / validation checks

```bash
VERSION="$(tr -d '[:space:]' < VERSION)" && [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
```

This mirrors the CI version-check job.

### Key caveats

- `setup.sh` expects to run from the repo root and writes to `~/.claude/`. It is safe to re-run (idempotent).
- MCP server registration (Step 7 in `setup.sh`) requires the `claude` CLI (`npm install -g @anthropic-ai/claude-code`). In Cloud Agent VMs the CLI is typically unavailable; `setup.sh` gracefully skips registration and prints a warning.
- All secrets live in `~/.claude/env.sh` (generated from `env.sh.template`, mode 600). External API integrations (LinkedIn, Webex, Splunk, HuggingFace, GitHub) are optional and require tokens filled into that file.
- The repo expects to live at `~/dev/claude` on real workstations; in Cloud Agent VMs `/workspace` is fine since skills are symlinked by `setup.sh`.
