# Logging Standard (aitools)

**Intent**: **Purpose**: Single source of truth for the aitools logging
standard — where logs live, how they rotate, how paths are formed per
platform, and the log-line format. **Scope**: The decided standard and its
rationale. NOT the per-script logging-helper API (that lives in
`@.claude/rules/script-standards.md` + `@reference/script-standards-detail.md`,
which keep a directive + pointer here). NOT check-vs-setup semantics beyond
noting they share the directory. **Audience**: Every agent or script that
emits logs, and anyone changing the logging substrate (`aitools-lib.{sh,ps1}`,
`harness-db.py`, `ait-harvest.py`, hooks, check-lib).

> Ratified 2026-06-14 as part of the harvest/archive/logging plan
> (`plans/imperative-gliding-newell.md` §14). This doc consolidates logging
> decisions previously scattered across `script-standards.md`,
> `script-standards-detail.md`, `cross-platform.md`, and `hook-rollout.md`.

## Decisions

### 1. Location — one cross-platform directory: `~/.aitools/logs/`

ALL aitools logging goes to **`~/.aitools/logs/`** on macOS, Windows, Linux
(and future platforms). This **overrides** the previous deliberate 3-way
native-directory split:

| Platform | OLD path (superseded) | NEW path |
|----------|----------------------|----------|
| macOS    | `~/Library/Logs/aitools/` | `~/.aitools/logs/` |
| Linux/Win (bash) | `${XDG_STATE_HOME:-~/.local/state}/aitools/` | `~/.aitools/logs/` |
| Windows (PS1) | `%LOCALAPPDATA%\aitools\` | `~/.aitools/logs/` |

**Rationale.** aitools logs are internal diagnostics shipped to Datadog (via
the harness DB, not log tails) — they are not consumed by OS-native log
tooling, so the native-dir convention buys nothing here. Uniformity and
discoverability win, and the move **dissolves a latent Windows bug**: bash
(`~/.local/state`) and PS1 (`%LOCALAPPDATA%`) previously disagreed, splitting
logs by writer. `~/.aitools/` is already the user-scoped namespace (config,
deploy-state, proposed telemetry — see `@.claude/rules/aitools-workspace.md`),
so `logs/` joins it naturally.

### 2. Path separators — native per language

Form the path using each language's native idiom; never hardcode a separator:

- **bash**: `"$HOME/.aitools/logs"` — forward slashes are valid in Git Bash.
- **PowerShell**: `Join-Path $HOME ".aitools" "logs"` — yields backslashes on Windows.
- **Python**: `pathlib.Path.home() / ".aitools" / "logs"` — native per OS.

**Exception**: when a path is written **into a bash command string** (e.g. a
hook `command` in `settings.json`, which always runs in bash on every platform),
use forward slashes regardless of host OS.

### 3. Granularity — per-component log files

Each component writes its own file so "did hook X fire?" is answerable by
reading one file:

| File | Writer |
|------|--------|
| `deploy.log` | setup scripts (via `aitools-lib` `logging_init`/`Initialize-Logging`) |
| `ait-harvest.log` | `scripts/ait-harvest.py` |
| `session-archive.log` | `session-archive.sh` shim (bash-fallback branch only) |
| `session-catchup.log` | `session-catchup.sh` shim (bash-fallback branch only) |
| `harvest-session.log` | `harvest-session.sh` shim (bash-fallback branch only) |
| `harness-db.log` | `scripts/harness-db.py` (was `deploy.log`) |
| `checks.log` / `checks.jsonl` | check/audit scripts (via `check-lib`) |

Note: the SessionEnd/SessionStart shims pass raw stdin to the Python helper,
which logs to `ait-harvest.log`. The per-shim `*.log` files capture ONLY the
bash-fallback branches (no Python / no helper / non-zero exit) — see
plan §20.2 C3.

### 4. Rotation — size-based, 5 MB × 5 backups

No rotation existed before. Standard everywhere:

- **maxBytes = 5 MB**, **backupCount = 5** (`<name>.log` → `<name>.log.1` … `.5`).
- **Python**: `logging.handlers.RotatingFileHandler` (stdlib).
- **bash**: size check in `logging_init` (`stat` size via `uname -s` dispatch →
  `mv` chain). No perl.
- **PowerShell**: size check in `Initialize-Logging` (`.Length` → `Move-Item` chain).

Same maxBytes/backupCount in all three.

### 5. Format — unchanged

`[<utc-Z>] [<script>] [<level>] <msg>`

- Levels: `info | ok | warn | error | detail`.
- File output: plain text (no ANSI).
- Console output: ANSI color for `warn` (yellow) / `error` (red); plain otherwise.
- `detail` is file-only (never console).
- Timestamps: UTC with `Z` suffix.
- **Fail-safe**: logging must never crash the tool. A failed log write is
  swallowed (the only sanctioned silent-suppression in the harness), because a
  broken log must not break the operation it records.

### 6. Setup-vs-check separation preserved

Setup scripts (OK/WARN/ERROR semantics, `deploy.log`) and check scripts
(PASS/FAIL/WARN/SKIP semantics, `checks.log`/`checks.jsonl`) keep distinct
files and distinct vocabularies — now in the **same** directory. See
`@reference/script-standards-detail.md` "Logging architecture: setup vs check"
for the bridge pattern (`check_log_init`/`CheckLogInit`).

## Migration status

The location/rotation migration across `aitools-lib.{sh,ps1}`, `harness-db.py`,
hooks, `check-lib`, and `clip2md` is tracked in plan §14.3. After migration, a
repo-wide grep for the old literals (`.local/state`, `Library/Logs`,
`LOCALAPPDATA`) must return none outside this doc and the plan (§20.3 M4).

## Cross-references

- Per-script helper API + levels: `@.claude/rules/script-standards.md`
- Helper detail, check architecture, console colors: `@reference/script-standards-detail.md`
- User-scoped namespace (`~/.aitools/`): `@.claude/rules/aitools-workspace.md`
- Hook observe-mode logs: `@.claude/rules/hook-rollout.md`
- Plan: `plans/imperative-gliding-newell.md` §14
