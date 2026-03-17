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

A user working on the same project across multiple machines (macOS,
Windows) must be able to pick up where they left off. Project state
that carries forward between sessions — running estimates, consolidated
findings, harvested artifacts — MUST be tracked in git so it survives
machine switches via pull.

Session-ephemeral data (scratch files, in-flight channel messages)
is gitignored — it belongs to one session on one machine.

This principle governs every workspace design decision: if data
needs to survive a machine switch, it must be tracked.

### Workspace structure

Project-scoped (`<repo>/.aitools/`):

| Directory | Tracked | Purpose |
|-----------|---------|---------|
| `scratch/` | gitignored | Session-ephemeral working files |
| `channel/session-*/` | gitignored | Session-ephemeral messages (SITREPs, FINDINGs) |
| `channel/running-estimate.json` | tracked | Carry-forward state between sessions and machines |
| `harvesting/` | tracked | Artifact lifecycle — candidates for harness promotion |

User-scoped (`~/.aitools/`):

| Path | Purpose |
|------|---------|
| `config.json` | Machine identity, repo paths, Google Drive discovery |
| `deploy-state/` | Last-deployed file hashes for drift detection |
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

Planning brief decision #34 is superseded by this rule. The
namespace consolidation (`.scratch/` → `.aitools/scratch/`,
`harvesting/` → `.aitools/harvesting/`) and the cross-machine
carry-forward principle are the governing decisions.
