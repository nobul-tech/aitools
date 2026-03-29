# Investigation: What Does aitools Actually Do?

Investigated by reading actual code in scripts/, shared/hooks/, shared/skills/, deploy/, and scripts/harness-db.py. No documentation files were consulted.

---

## 1. The Entry Point: `scripts/aitools` (bash) and `scripts/aitools.ps1` (PowerShell)

The `aitools` command is a bash script installed to `~/.local/bin/aitools`. There is a parallel PowerShell version (`aitools.ps1`) for Windows. Both do the same thing.

### Subcommands (from the actual argument parser)

| Command | What it does |
|---------|-------------|
| `aitools` (no args) | **Sync**: git pull the aitools repo (quiet, non-fatal on failure) + pull user repo + rebuild deploy/ scripts + run all config deployment scripts |
| `aitools install` | **Full setup**: same as sync, but also runs `aitools-install.sh` which installs CLI tools (gh, vercel, pandoc, rust, typst, python, uv, modal, go, datadog, perl, bash config) and deploys configs |
| `aitools gitpull` | **Release flow**: git pull with tags + rebuild + deploy configs + auto-tag a new version (minor or patch bump) with release notes gate |
| `aitools mcp` | **Status display**: reads `~/.claude.json`, `~/.claude/settings.json`, project settings, and `~/.cursor/mcp.json` to show which MCP servers are enabled/disabled |
| `aitools --addmcp <name>` | **Enable MCP**: writes to `.claude/settings.local.json` (permissions.allow) and `.cursor/mcp.json` to enable named MCP servers (vercel, webflow) for the current project |
| `aitools user init` | **User repo setup**: detects GitHub user, clones/creates `aitools-<username>` companion repo, writes `~/.aitools/config.json` with paths, handles profile.json v1-to-v2 migration |
| `aitools sessions list` | Lists archived session transcripts from user repo |
| `aitools sessions archive <ID>` | Manually archives a Claude Code session transcript |
| `aitools sessions move <file> <proj>` | Refiles an archived session under a different project |
| `aitools dashboard` | Starts/stops/snapshots a live mission control dashboard (delegates to `aitools-dashboard.sh`) |

### The Sync Flow (default, no args)

1. **Step 1**: `git pull origin main` on the aitools repo (non-fatal on failure -- continues from local)
2. Also `git pull --ff-only` on the user repo (non-fatal)
3. **Step 2**: Runs `build-deploy.sh` to regenerate `deploy/` from `scripts/` + `shared/`
4. Self-update check: if the deploy script list changed in the pulled code, it re-execs itself
5. **Step 3**: Runs `deploy_configs()` which executes these setup scripts in order:
   - `setup-user-claude.sh` (deploys `~/.claude/CLAUDE.md` + user rules to `~/.claude/rules/`)
   - `setup-user-mcp.sh` (deploys MCP server configs to `~/.claude.json`)
   - `setup-user-skills.sh` (deploys skills to `~/.claude/skills/`)
   - `setup-cursor-ide-mcp.sh` (deploys MCP config to `~/.cursor/mcp.json`)
   - `setup-user-cursor.sh` (deploys Cursor rules/settings)
   - `setup-user-hooks.sh` (deploys Claude Code hooks to `~/.claude/hooks/` and settings to `~/.claude/settings.json`)

### Config File

`~/.aitools/config.json` stores: `repoPath` (aitools repo location), `userRepoPath` (dotprofile companion repo), `reposPath` (general repos directory), `machineAlias`, `googleDrives` array.

---

## 2. The Build System: `scripts/build-deploy.sh`

This is a bash-only script that generates the `deploy/` directory. Here is what it actually does:

1. Reads all shared content: `shared/claude-shared.md`, all hook scripts from `shared/hooks/`, all skill files from `shared/skills/*/SKILL.md`, user rules from the user repo, and shared libraries (`aitools-lib.sh`, `aitools-lib.ps1`).
2. Reads `profile.json` from the user repo and interpolates `{{PLACEHOLDER}}` tokens (name, company, git identity, Cursor/Claude preferences).
3. Deletes and recreates `deploy/`.
4. For each setup script in `scripts/`, it generates a self-contained version in `deploy/` by:
   - Extracting the script body between sentinel markers (using Perl)
   - **Inlining** the entire `aitools-lib.sh`/`.ps1` shared library (replacing the `source aitools-lib.sh` line with the lib contents)
   - **Embedding** content that the script would normally read from files (hooks, CLAUDE.md template, skills, user rules)
5. The deploy/ scripts have zero runtime dependency on the repo. They can run standalone via MDM (Jamf, Intune).

The relationship: `scripts/` are the source. `deploy/` are generated, self-contained versions with all dependencies baked in. `deploy/` is committed to git but is ephemeral -- it is regenerated on every `aitools` run and reset to HEAD before every git pull.

---

## 3. The Hooks: `shared/hooks/`

These are Claude Code hooks -- shell scripts that fire at specific lifecycle points during Claude Code AI sessions. They are deployed to `~/.claude/hooks/` by `setup-user-hooks.sh`.

### SessionStart hooks (fire when a Claude Code session begins)

| Hook | What it does |
|------|-------------|
| `scratch-init.sh` | Creates a unique `.scratch/session-<prefix>/` directory for the session. Logs stale session dirs older than 24h. Writes `.scratch/.current-session` so other hooks can find it. Discovers unconsumed handoff files at `.aitools/channel/handoffs/`. Registers the session in the harness SQLite DB. |
| `dashboard-serve.sh` | Delegates to `aitools dashboard --background` to start a live HTML dashboard server. Falls back to direct Python launch if aitools CLI is not installed. |
| `harness-db-sessionstart.sh` | Initializes the harness SQLite databases (session DB + harness DB) via `harness-db.py init` and registers the session via `harness-db.py session start`. |

### SessionEnd hooks (fire when a Claude Code session ends)

| Hook | What it does |
|------|-------------|
| `session-archive.sh` | Copies the Claude Code session transcript (JSONL file) to the user's companion repo under `sessions/<project>/YYYY-MM-DD_<session-id>.jsonl`. Auto-commits and pushes (best-effort). Uses the transcript file's birth time for the date. Pure bash, no jq. |
| `harvest-session.sh` | Classifies files in the session scratch directory by extension (code/scripts = artifact, logs/msgs = ephemeral). Copies artifacts to `harvesting/` with session-prefixed filenames. Updates `harvesting/harvest-manifest.json` via node. Marks session as ended in harness DB. Exports DB to JSON for git carry-forward. Does NOT delete scratch dirs (learned the hard way after losing 30 artifacts). |
| `tool-ops-session-audit.sh` | Reads `reference/tool-ops.json` and runs contract tests against deployed hook scripts. For example, it verifies that `block-claude-code-guide.sh` correctly denies the `claude-code-guide` subagent. Logs results to `tool-ops-audit.jsonl`. |
| `harness-db-sessionend.sh` | Marks the session as complete in the harness SQLite DB and exports the DB contents to `.aitools/channel/running-estimate.json` (tracked in git for cross-machine carry-forward). |

### PreToolUse hooks (fire before Claude uses a specific tool)

| Hook | Matcher | What it does |
|------|---------|-------------|
| `standing-order-guard.sh` | Bash | Inspects every Bash command Claude tries to run. Blocks `&&`, `||`, `;`, `$(...)`, backticks, and glob patterns in destructive commands. Tells Claude which tool to use instead (e.g., "Use Read instead of cat"). Has per-check enforce/observe modes with rollout tracking. Emits telemetry to `events.jsonl`. |
| `glossary-skill-guard.sh` | Read, Grep | Fires when Claude tries to read glossary files directly. Returns a JSON reminder to use the `/glossary` skill instead (governed data access enforcement). |
| `block-claude-code-guide.sh` | Agent | Blocks Claude Code's built-in `claude-code-guide` subagent (Haiku model) and injects corrective harness context. Returns a JSON deny with a `permissionDecisionReason` containing accurate harness information. |
| `delegation-duty-guard.sh` | Agent | Checks subagent delegation prompts for 6 required "duty elements" (identity, rules, skills, operational learning, WRITE_BLOCKED signal, access workaround). Currently in OBSERVE mode -- warns on gaps via stderr but does not block. |

### PostToolUse hooks (fire after Claude uses a specific tool)

| Hook | Matcher | What it does |
|------|---------|-------------|
| `sh-file-fixup.sh` | Write, Edit | Auto-fixes `.sh` files after creation/modification: converts CRLF to LF, sets chmod +x on disk, and runs `git update-index --chmod=+x` if the git index has the wrong mode. |

---

## 4. The Skills: `shared/skills/`

These are Claude Code "skills" -- SKILL.md files that provide specialized capabilities. Deployed to `~/.claude/skills/` by `setup-user-skills.sh`.

| Skill | One-line description |
|-------|---------------------|
| `scratch` | Ephemeral session scratch files -- session directories, naming conventions, commit message pattern |
| `handoff` | End a session by producing a verified handoff prompt for the accepting session |
| `mission-control` | Monitor running missions -- process health, activity, work products, deliverable validation |
| `chrome-devtools` | Uses Chrome DevTools via MCP for debugging, troubleshooting, and browser automation |
| `a11y-debugging` | Uses Chrome DevTools MCP for accessibility debugging and auditing based on web.dev guidelines |
| `investigate` | Investigate when something went wrong -- triage, RCA, remediation, corrective actions |
| `planning` | Session and plan strategy for Claude Code sessions -- batch sizing, session flow, subagent parallelization |
| `optimize-plan` | Review and improve an existing plan file -- detects stale sections, dependency issues, scope drift |
| `aitool-ops` | Read-only reference card for tool-ops operational knowledge -- deny rules, hooks, CC version deps |
| `aitool-eval` | Read-only reference card for tool evaluation methodology -- hard blocks, yellow flags, discovery playbook |
| `aitool-continue` | Continuous self-learning initialization -- loads operational learning, delegation principles, project state |
| `intent-writing` | Writing intent statements for markdown files, code files, and sections |
| `intent-audit` | Audit a file against its intent statement |

---

## 5. `scripts/harness-db.py`

A Python CLI (stdlib only -- sqlite3, argparse, json) that manages two SQLite databases:

- **Session DB** (`.aitools/sessions/<prefix>.db`): Per-session state with tables for: `session`, `missions`, `decisions`, `observations`, `messages`, `delegation_log`, `deviations`, `hard_requirements`, `completed_work`, `events`, `version_history`. Also has a provenance/knowledge graph layer: `knowledge_items`, `knowledge_edges`, `nogood_sets` (for tracking contradictions).
- **Harness DB** (`.aitools/harness.db`): Cross-session state with `session_index` and `kpi_events` tables.

### Subcommands

- `init` -- Create/migrate both databases
- `session start/end` -- Register session lifecycle
- `mission start/end` -- Track missions (with parent/child hierarchy)
- `log` -- Log SITREPs and FINDINGs with severity
- `export` -- Export DB to JSON (for git carry-forward)
- `process-events` -- Ingest `events.jsonl` telemetry from hooks
- `ship` -- Ship KPI events to Datadog (via HTTP API)
- `status` -- Show database status summary
- `knowledge add/invalidate/verify/list` -- Knowledge graph items with trust levels and staleness tracking
- `edge add/list` -- Provenance edges between knowledge items
- `nogood add/list/check` -- Track contradictory knowledge item sets
- `provenance-export` -- Export the full provenance graph to JSON
- `ol add/list` -- Quick operational learning entries
- `decision add/list` -- Quick decision entries
- `incident add/list` -- Quick incident entries
- `observation add/list` -- Quick observation entries
- `search` -- Full-text search across all session tables

The DB follows "Option B" architecture: SQLite is the runtime format (gitignored), and JSON exports are the archive format (tracked in git for cross-machine carry-forward).

---

## 6. Supporting Scripts

### Tool installers (`scripts/setup-*.sh` + `.ps1` pairs)
Each installs/updates one tool: `setup-gh-cli`, `setup-vercelcli`, `setup-pandoc`, `setup-rust`, `setup-typst`, `setup-python`, `setup-uv`, `setup-modal`, `setup-go`, `setup-datadog`, `setup-perl`, `setup-bash`. All follow the same pattern: source aitools-lib, OS guard, check if installed, install/upgrade, verify, log summary.

### Config deployers (`scripts/setup-user-*.sh` + `.ps1` pairs)
Deploy AI tool configurations: `setup-user-claude` (CLAUDE.md + rules), `setup-user-mcp` (MCP servers), `setup-user-skills` (skills), `setup-user-cursor` (Cursor rules/settings), `setup-user-hooks` (hooks + settings.json), `setup-cursor-ide-mcp` (Cursor MCP).

### Check scripts (`scripts/check-*.sh` + `.ps1` pairs)
Verification checklists: `check-pre-commit`, `check-pre-push`, `check-post-push`, `check-prereq-detection`, `check-script-compliance`. These run audit steps and report PASS/FAIL/WARN/SKIP.

### Shared library (`scripts/aitools-lib.sh` + `.ps1`)
Provides: platform detection, logging (with UTC timestamps), config reading, `invoke_ai` (wraps `claude` or `agent` CLI with speed/permission tiers and retry), `write_summary` / `show_summary` (end-of-run panel), `deploy_managed_file` (interactive diff review deployment), JSON normalization, `backup_file`, `backup_dir`.

### Dashboard (`scripts/generate-dashboard.py` + `scripts/aitools-dashboard.sh`)
Python script that reads a `running-estimate.json` file and generates a self-contained HTML dashboard showing session state, missions, decisions, findings. Supports static mode (embeds JSON into HTML) and live mode (HTTP server with polling). Multi-mission mode scans directories for multiple running estimates.

---

## Summary

**This system is a cross-platform developer environment manager that does three things:**

1. **Tool lifecycle management**: Installs, updates, and configures a set of developer CLI tools (gh, vercel, pandoc, rust, typst, python, uv, modal, go, datadog, perl) on both macOS and Windows. One command (`aitools install`) sets everything up. One command (`aitools`) keeps it current.

2. **AI tool configuration orchestration**: Deploys and manages configuration for Claude Code and Cursor -- CLAUDE.md files, rules, skills, MCP server connections, and hooks. The build system bakes everything into self-contained deploy scripts that can run standalone via MDM without the repo present.

3. **Session state tracking and governance**: An extensive hook system fires during Claude Code sessions to: create scratch directories, archive transcripts, harvest reusable artifacts, enforce coding conventions (block dangerous bash patterns, enforce tool usage, check delegation quality), track sessions in SQLite databases, generate live dashboards, and export state to JSON for cross-machine carry-forward.

**The entry point** is `aitools` (installed to `~/.local/bin/`). With no arguments, it syncs. With `install`, it does full setup. With `gitpull`, it releases.

**The hooks** are the enforcement layer -- they intercept Claude Code's tool usage in real-time to enforce standing orders, redirect to proper skills, auto-fix shell scripts, archive sessions, harvest artifacts, and track everything in SQLite.

**The build system** (`build-deploy.sh`) turns `scripts/` (source, with external dependencies) into `deploy/` (generated, self-contained, no dependencies). This is how the system achieves MDM-readiness.

**harness-db.py** is a SQLite-backed session state tracker with a knowledge graph layer (items, edges, nogood sets) and telemetry shipping to Datadog.

### Things That Look Incomplete or Aspirational

- The `ship` command in harness-db.py sends KPIs to Datadog, but the `DD_API_KEY` is read from environment -- it is unclear if this is actually configured in production.
- The `delegation-duty-guard.sh` is in OBSERVE mode (warns but does not block).
- Several KPI definitions in hook comments are marked "aspirational until decision #32 ships."
- The `tool-ops-session-audit.sh` runs contract tests against hooks but only tests `block-claude-code-guide.sh` in the code I read.
- The `dashboard-serve.sh` hook has a fallback codepath for when aitools is not installed, suggesting the dashboard feature is relatively new.
