## aitools Workspace (this repo)

**Intent**: **Purpose**: Govern the `.aitools/` workspace namespace —
project-scoped harness capabilities that persist across sessions and
machines. **Scope**: Workspace structure, scope boundaries (project
vs user), cross-machine carry-forward principle. NOT individual
capability specs (see their respective skills/rules). **Audience**:
Every agent, every session.

### Governing principle

Channel, scratch, harvesting, and operational learning are harness
capabilities. The harness (aitools + Claude Code) provides these to
every project it works on. Any project aitools touches gets these
capabilities.

### Cross-machine carry-forward principle

A user working on the same project across multiple machines or
environments (any supported platform or hosted environment:
`@reference/cross-platform-detail.md` "Supported platforms and
environments") must be able to pick up where they left off. Project state
that carries forward between sessions — running estimates, consolidated
findings, harvested artifacts — MUST be tracked in git so it survives
machine switches via pull.

Session-ephemeral data (scratch files, in-flight channel messages)
is gitignored — it belongs to one session on one machine.

This principle governs every workspace design decision: if data
needs to survive a machine switch, it must be tracked.

### Workspace structure

Project-scoped (`<repo>/.aitools/`, plus two directories at the repo root):

| Directory | Tracked | Purpose |
|-----------|---------|---------|
| `<repo>/.scratch/` (repo root) | gitignored | Session-ephemeral working files; one `session-<id>/` per session, path in `.scratch/.current-session` (`scratch-init.sh`) |
| `channel/session-*/` | gitignored | Session-ephemeral messages (SITREPs, FINDINGs) |
| `channel/running-estimate.json` | tracked | Carry-forward state between sessions and machines |
| `channel/handoffs/` | tracked | Handoff prompts from completed sessions (see `/handoff` skill) |
| `<repo>/harvesting/` (repo root) | tracked | Artifact lifecycle — candidates for harness promotion; manifest `harvest-manifest.json` (`ait-harvest.py`) |

User-scoped (`~/.aitools/`):

| Path | Purpose |
|------|---------|
| `config.json` | Machine identity, repo paths, Google Drive discovery |
| `deploy-state/` | Retired: older versions kept last-deployed hashes here; the managed-file model keeps no deploy state (SOURCE is the source of truth). Left on disk, unused |
| `reference/` | Copy of the aitools repo `reference/` tree (git-tracked files, same relative paths) — deployed by `deploy-harness` |
| `registries/` | Copy of the aitools repo `registries/` (the registries stay in the repo; SD-8-reg) — deployed by `deploy-harness` |
| `hooks/` | Hook scripts from `shared/hooks/` and `.claude/hooks/`, one flat directory — deployed by `deploy-harness` (settings.json still points at `~/.claude/hooks`) |
| `rules/` | Rules from `shared/rules/`, `.claude/rules/` and the dotprofile `claude/rules/`, one flat directory, plus `.aitools-rules-manifest` (each rule's source, or `retired`) — deployed by `deploy-harness`; every non-retired rule is copied to `~/.claude/rules/` by `setup-user-claude` and converted into `~/.cursor/rules/*.mdc` by `setup-user-cursor` |
| `skills/` | Skill directories from `shared/skills/`, `.claude/skills/` and the dotprofile `claude/skills/`, plus `.aitools-skills-manifest` (each skill's source, or `retired`) — deployed by `deploy-harness`; every non-retired skill is copied to `~/.claude/skills/` by `setup-user-claude` and to `~/.cursor/skills/` by `setup-user-cursor` |
| `bin/` | Deployed harness Python CLIs (`harness-db.py`, `read-session.py`, `read-session-full.py`) — deployed by `deploy-harness` (installer Step 8b), called by hooks via absolute path so every project resolves them |
| `logs/` | Unified component logs (`deploy.log`, `checks.log`, `ait-harvest.log`, `harness-db.log`), 5 MB × 5 rotation — see `@reference/logging.md` |
| `auth/` | Per-user credentials (proposed) |
| `telemetry/` | SQLite KPI aggregation across all projects (proposed) |

### Scope boundary

- **Project-scoped** (`.aitools/` at repo root): data about THIS
  project's sessions, artifacts, and operational state
- **User-scoped** (`~/.aitools/`): data about THIS user's identity,
  machines, credentials, and cross-project telemetry
- These never mix: project data never goes to `~/.aitools/`,
  user identity never goes to `<repo>/.aitools/`

### Decision #34 status

Planning brief decision #34 is superseded by this rule for the
cross-machine carry-forward principle. The namespace consolidation it
proposed (`.scratch/` → `.aitools/scratch/`, `harvesting/` →
`.aitools/harvesting/`) is **not implemented**: the hooks and
`ait-harvest.py` use `.scratch/` and `harvesting/` at the repo root.
Treat the root paths as current until a plan moves them.
