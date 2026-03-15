# Managed File Deployment

Specification for the interactive file deployment system used by setup scripts
(`setup-user-claude`, `setup-user-mcp`, `setup-user-hooks`).

## Overview

When `aitools install` deploys a managed file (CLAUDE.md, rules, skills,
hooks, MCP configs), it compares source content against the local file. If
they differ, the user is shown a diff preview and menu to choose an action.

## Functions

| Function (PS1) | Function (bash) | Purpose |
|----------------|----------------|---------|
| `Prompt-DiffReview` | `prompt_diff_review` | Show diff + menu, return user's choice |
| `Deploy-ManagedFile` | `deploy_managed_file` | Orchestrate: compare, review, write |
| `Record-DeployOutcome` | `deploy_tracker_record` | Count outcomes for summary panel |
| `Try-AutoMerge` | `try_auto_merge` | 3-way merge via `git merge-file` |

## State Machine

```
Source content
    |
    +-- File doesn't exist --> write --> "created"
    |
    +-- Content identical --> "verified"
    |
    +-- Content differs
         |
         +-- Deploy state: user didn't edit --> auto-deploy --> "updated"
         |
         +-- User edited + source changed
              |
              +-- Ancestor available (deploy state)
              |    |
              |    +-- Auto-merge succeeds --> Auto-Merge Menu
              |    |    |
              |    |    +-- [a]ccept & adopt (AdoptLabel)  --> write + sync  --> "accept & adopt"
              |    |    +-- [a]ccept & adopt (no label)    --> write         --> "updated"
              |    |    +-- [o]verwrite                    --> write source  --> "updated"
              |    |    +-- [s]kip                         -->               --> "skipped"
              |    |    +-- [x]abort                       --> exit 2
              |    |
              |    +-- Auto-merge conflicts --> Merge-Conflict Menu
              |
              +-- No ancestor --> Merge-Conflict Menu
                   |
                   +-- [o]verwrite                    --> write source  --> "updated"
                   +-- [a]ccept & adopt (AdoptLabel)  --> keep + sync   --> "accept & adopt"
                   +-- [m]erge                        --> AI merge      --> "updated"
                   +-- [s]kip                         -->               --> "skipped"
                   +-- [x]abort                       --> exit 2
```

## Menus

### Auto-Merge Menu (clean 3-way merge available)

With AdoptLabel:
```
  [a]ccept & adopt : deploy merge + sync to <AdoptLabel>
  [o]verwrite      : deploy source (discard merge)
  [s]kip
  [x]abort
  choice [a/o/s/x]:
```

Without AdoptLabel:
```
  [a]ccept   : deploy merge
  [o]verwrite
  [s]kip
  [x]abort
  choice [a/o/s/x]:
```

### Merge-Conflict Menu (no ancestor or merge conflicts)

With AdoptLabel:
```
  [o]verwrite      : source wins --> deploy to local (backup kept)
  [a]ccept & adopt : local wins --> sync to <AdoptLabel>
  [m]erge          : AI-assisted merge of source + local
  [s]kip           : keep local as-is (no changes)
  [x]abort         : stop deployment
  choice [o/a/m/s/x]:
```

Without AdoptLabel:
```
  [o]verwrite : source wins --> deploy to local (backup kept)
  [m]erge     : AI-assisted merge of source + local
  [s]kip      : keep local as-is (no changes)
  [x]abort    : stop deployment
  choice [o/m/s/x]:
```

### Non-Interactive Behavior

When `AITOOLS_FORCE` is set or stdin is not a terminal:
- Auto-select `overwrite` (no menu shown)
- Log the forced decision to deploy.log

## Return Values

### prompt_diff_review / Prompt-DiffReview

| Value | Menu | Meaning |
|-------|------|---------|
| `"accept-adopt"` | Both (with AdoptLabel) | Accept & adopt — content approved + synced to adopt target |
| `"merge"` | Auto-merge (no label) | Accept merge (no adopt target) |
| `"overwrite"` | Both | Source wins (deploy to local) |
| `"skip"` | Both | Keep local unchanged |
| (exit 2) | Both | User aborted |

### deploy_managed_file / Deploy-ManagedFile

| Value | Meaning | File written? | Adopt target updated? |
|-------|---------|--------------|----------------------|
| `"created"` | New file | Yes | No |
| `"updated"` | Content changed | Yes | No |
| `"verified"` | Content identical — actively confirmed correct | No | No |
| `"accept & adopt"` | User accepted content + synced to adopt target | Yes (auto-merge) or No (merge-conflict) | Yes |
| `"skipped"` | User chose skip | No | No |

## Caller Responsibilities

Every caller of `deploy_managed_file` MUST handle all return values:

| Return value | Validation? | Adopt flow? | Tracker? |
|-------------|-------------|-------------|----------|
| `created` | Yes | If applicable | Yes |
| `updated` | Yes | If applicable | Yes |
| `verified` | No | No | Yes |
| `accept & adopt` | Yes | Adopt done by caller | Yes |
| `skipped` | No | No | Yes |

## Deploy State (Shadow System)

`Update-DeployState` / `_update_deploy_state` stores the deployed content hash.
On next run, this becomes the "ancestor" for 3-way merge. Stored in
`~/.aitools/deploy-state/` as SHA256 hashes with a manifest.

## Normalization

Before comparing source and existing content, both are normalized:
- Trailing whitespace: collapse `[\r\n]+$` to single `\n`
- Prevents round-trip diff noise (deploy --> adopt strips blanks --> deploy
  sees diff)

## Encoding (PS1)

`Try-AutoMerge` uses in-place `git merge-file` (no `-p` flag) and reads the
result via `[IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)`. This avoids
PowerShell's OEM codepage mangling UTF-8 from external commands.

---

## Deployment Types

Setup scripts deploy three types of managed files. Every type has the
same correctness requirements (backup, logging, validation). They differ
in merge strategy, not in importance or priority. See
`@.claude/rules/managed-file-deployment.md` for the concise rule.

### Markdown files

**Files**: CLAUDE.md, `~/.claude/rules/*.md`, skill `SKILL.md` files.

**Pattern**: `deploy_managed_file` / `Deploy-ManagedFile` in
`@scripts/aitools-lib.sh` / `@scripts/aitools-lib.ps1`.
Backup → compare → diff review menu → write. Full state machine above.

**Content source**: CLAUDE.md and rules from dotprofile repo (primary) or
`shared/claude-shared.md` (fallback). Skills from `shared/skills/`.
Template tokens (`{{PLACEHOLDER}}`) interpolated from `profile.json`.
See `@reference/user-repo.md` "Template Resolution" and "User Rules
Deployment".

**Scripts**:
- `setup-user-claude.sh/.ps1` — CLAUDE.md + rules
- `setup-user-mcp.sh/.ps1` — skill SKILL.md files (4 targets)

### JSON config files

**Files**: `~/.claude/settings.json`, `~/.cursor/cli-config.json`,
`~/.cursor/mcp.json`.

**Pattern**: Read existing JSON → set managed fields only → preserve all
other fields → validate → write. Implemented as inline Node.js
(settings.json) or PowerShell/bash merge logic.

**Content source**: Field values from `profile.json` (e.g., Claude
preferences, Cursor CLI settings) or hardcoded in the script (e.g., MCP
server URLs, `--isolated` flag). Platform-specific values (e.g.,
`cmd /c npx` vs `npx`) are dispatched by OS guards — see "Platform-
Specific Config Values" below.

**Scripts**:
- `setup-user-hooks.sh/.ps1` — settings.json (hooks, preferences from
  `profile.json` `claude` section)
- `setup-user-mcp.sh/.ps1` — settings.json (deny rules)
- `setup-user-cursor.sh/.ps1` — cli-config.json (preferences from
  `profile.json` `cursor.cli` section)
- `setup-cursor-ide-mcp.sh/.ps1` — mcp.json (MCP server configs)

### Shell scripts

**Files**: Hook scripts (`~/.claude/hooks/*.sh`).

**Pattern**: Uses `deploy_managed_file` — same as markdown type. Hook
scripts are text files and benefit from the same diff review, merge,
and adopt flow.

**Content source**: `shared/hooks/` in the aitools repo. Hook scripts
are bash-only on both platforms (Claude Code runs hooks in bash on all
platforms). No platform-specific variants needed.

**Scripts**:
- `setup-user-hooks.sh/.ps1` — session-archive.sh, standing-order-guard.sh

## Content Sources

Deployed content originates from two repos. The dotprofile repo takes
priority when present; the aitools `shared/` directory is the fallback.

| Content | Primary source | Merge-Conflict |
|---------|---------------|----------|
| CLAUDE.md template | `<userRepoPath>/claude/CLAUDE.md` | `shared/claude-shared.md` |
| User rules | `<userRepoPath>/claude/rules/*.md` | (none — no rules deployed) |
| Claude preferences | `<userRepoPath>/profile.json` `claude` section | defaults (autoMemory: true, alwaysThinking: true) |
| Cursor preferences | `<userRepoPath>/profile.json` `cursor.cli` section | defaults (vimMode: false, model: auto) |
| Identity (git name/email) | `<userRepoPath>/profile.json` `identity` section | (required — no fallback) |
| Machine profile | `<userRepoPath>/profile.json` `profiles[machineAlias]` section | hostname match, then first profile |
| Hook scripts | `shared/hooks/*.sh` | (required — no fallback) |
| Skills | `shared/skills/*/SKILL.md` | (required — no fallback) |
| MCP server configs | hardcoded in setup scripts | (required — no fallback) |

**`userRepoPath` resolution**: read from `~/.aitools/config.json`. Set by
`aitools user init`. If not configured, dotprofile features are skipped
and shared fallbacks are used.

Full spec: `@reference/user-repo.md`

## Platform-Specific Config Values

JSON config files may contain values that differ by platform. OS guards
in setup scripts ensure the correct variant is deployed. Never run a
`.sh` setup script on Windows or a `.ps1` on macOS — cross-platform
dispatch rules in `@.claude/rules/cross-platform.md` prevent this.

| Config file | Field | Windows | macOS |
|-------------|-------|---------|-------|
| `mcp.json` | chrome-devtools command | `"cmd", "/c", "npx", "-y", "chrome-devtools-mcp@latest", "--isolated"` | `"npx", "-y", "chrome-devtools-mcp@latest", "--isolated"` |
| `settings.json` | hook command paths | `bash "C:/Users/<user>/.claude/hooks/<hook>.sh"` | `bash "/Users/<user>/.claude/hooks/<hook>.sh"` |
| `cli-config.json` | (no platform differences) | identical | identical |

**`--isolated` flag**: platform-independent, MUST be present on both
platforms. Enables throwaway temp Chrome profiles for concurrent Claude
Code + Cursor sessions. See `@reference/tool-registry.md` "Chrome DevTools
MCP" and `@.claude/rules/tool-lifecycle.md` "MCP server isolation".

**Path format in settings.json hooks**: PowerShell setup converts
backslash paths to forward slashes (`-replace '\\', '/'`) for bash
compatibility. This is intentional — Claude Code always runs hooks via
bash, even on Windows.

## Shell Script Deployment Detail

Shell scripts (hooks) use `deploy_managed_file` with the same state
machine as markdown files. The adopt label points to the repo source
(`shared/hooks/<filename>`) rather than the dotprofile repo, since hooks
are framework code maintained in the aitools repo.

When a user adopts a local hook, the modified hook is copied back to
`shared/hooks/` in the aitools repo. This is a local repo change — the
user decides whether to commit it.

## JSON Config Review Detail

JSON config files use field-level review rather than text diff review.
Each managed field is displayed with its current and proposed value.
Only managed fields are shown; preserved fields are never displayed.

**Diff source resolution per config:**

| Config file | Managed field source | Adopt target |
|-------------|---------------------|--------------|
| `settings.json` (hooks) | `profile.json` `claude` section + hardcoded hook commands | `profile.json` `claude` section (preference fields only) |
| `settings.json` (deny rules) | hardcoded deny list in script | (not adoptable — script-owned) |
| `cli-config.json` | `profile.json` `cursor.cli` section | `profile.json` `cursor.cli` section |
| `mcp.json` | hardcoded server configs in script | (not adoptable — script-owned) |

**Adopt limitations**: Only fields sourced from `profile.json` can be
adopted — the local value is written back to `profile.json` so future
deploys use the adopted value. Fields hardcoded in scripts (deny rules,
MCP server URLs, `--isolated` flag) cannot be adopted.

**When adopt is not available**: If all changed managed fields are
script-owned (no profile.json source), the adopt option is omitted:
```
  [o]verwrite  [s]kip  [x]abort
```

## Diff Mechanism Detail

**Bash** (text types): `diff -u` via process substitution:
```bash
diff -u <(printf '%s' "$new_content") <(printf '%s' "$cur_content") \
    --label "source (would deploy)" --label "local (on disk)"
```
Unified format. Full diff written to deploy.log. Terminal shows first
30–40 lines with truncation message.

**PowerShell** (text types): `Compare-Object` line-by-line:
```powershell
$diffs = Compare-Object ($NewContent -split "`n") ($CurrentContent -split "`n")
```
Custom prefixes (`+ local`, `- source`). Full diff written to deploy.log.
Terminal shows first 30–40 entries.

**JSON configs** (field-level): Per-field old → new display. Changed
fields shown with source attribution (profile.json or script). Unchanged
managed fields shown as confirmation. Full field list written to
deploy.log via `Emit-MergeDetails` / `emit_merge_details` in
`@scripts/aitools-lib.sh` / `@scripts/aitools-lib.ps1`.

## AI-Assisted Merge Detail

The `[m]erge` option uses the agentic invocation framework
(`invoke_ai` / `Invoke-AI` in `@scripts/aitools-lib.sh` /
`@scripts/aitools-lib.ps1`). Available for text types (markdown, shell
scripts) only — not for JSON config field-level review.

**Invocation parameters:**
- Speed tier: `balanced` (Sonnet)
- Permission tier: `none` (text-only, no file/shell access)
- Validation: `_merge_validate` / `_MergeValidateWrapper`
- Max retries: 1

**Prompt structure** (RCFT pattern per `@.claude/rules/agentic-standards.md`):
1. Role: "You are merging a managed configuration file"
2. Context: file description, SOURCE/LOCAL content in XML delimiters
3. Task: merge preserving local customizations
4. Constraints: 6 rules including anti-code-fence rule
5. Output format: raw content only, no preamble

**Validation checks** (5-check framework):

| # | Check | Rejects when |
|---|-------|-------------|
| 1 | Conversational | First line matches `^(I |Here|Sure|Certainly|Let me)` |
| 2 | Code fences | Output contains ` ``` ` at start of line |
| 3 | Refusal | Contains "I don't have permission", "I cannot access", etc. |
| 4 | Truncation | Output < 50% of shorter input length |
| 5 | Headers | < 60% of expected headers preserved |

**Post-merge flow:**
1. Defense-in-depth: strip code fences even if validation passed
2. Preview first 30 lines in terminal
3. User chooses: `[y]es` accept, `[r]efine` with feedback, `[n]o` reject
4. Refine: user provides feedback → refinement prompt → re-validate →
   preview again
5. On all failures: fallback to `[o]verwrite` / `[s]kip`

**Telemetry**: every invocation logged to deploy.log per
`@.claude/rules/script-standards.md` "Agentic invocation logging".
Rejected output logged line-by-line via `log_detail` for post-mortem.

See `@.claude/rules/agentic-standards.md` for the full prompt design,
evaluation lifecycle, and speed/permission tier definitions.

## Backup Policy

All file deployment (all types) MUST call `backup_file` / `Backup-File`
before writing to an existing file.

- **Location**: `<file>.bak.<TIMESTAMP>` (same directory as target)
- **Retention**: max 20 per file, auto-prune oldest
- **Directory backups**: `<dir>.bak.<TIMESTAMP>/`, max 5, auto-prune
- **Skip**: Only when target does not yet exist (nothing to back up)
- **Failure**: Non-fatal (warn and proceed)

See `@reference/known-gaps.md` Gap 5 for the backup proliferation issue
with directory backups.

## Environment Variable Deployment

Some tools require environment variables for correct operation. These
are NOT deployed to persistent shell profiles unless explicitly approved.

| Variable | Set by | Scope | Purpose |
|----------|--------|-------|---------|
| `PERLIO=:perlio` | `build-deploy.sh` | Build-time | Disable Strawberry Perl CRLF text mode; prevents double-CR in `extract_between --crlf` output. No-op for Git's bundled perl. See `@reference/tool-registry.md` "Perl > PERLIO Deployment". |
| `DD_SITE` | `shared/shell/aliases.sh` | Shell profile (persistent) | Datadog region |
| `AITOOLS_FORCE` | Caller | Script invocation | Force non-interactive mode (auto-select overwrite) |
| `AITOOLS_DRY_RUN` | `aitools-install` | Script invocation | Preview changes without writing |

When adding a new env var:
1. Document in this table
2. Choose scope: build-time, script-invocation, or shell-profile
3. Shell-profile vars require deployment in both `aliases.sh` and `aliases.ps1`
4. Build-time vars live in the script that needs them

## Authentication File Policy

Aitools setup scripts NEVER write, modify, or delete authentication
files. Auth configs are tool-owned and user-managed.

Setup scripts only CHECK auth status and report:
- Authenticated: silent (no output)
- Not authenticated: `log_warn` + `write_summary WARN` + `write_summary ACTION`

| Tool | Auth check | Method |
|------|-----------|--------|
| Modal CLI | `~/.modal.toml` exists | File presence |
| Datadog CLI | `pup auth status` | Command output |
| Vercel CLI | `vercel whoami` | Command exit code |
| GitHub CLI | `gh auth status` | Command exit code |

Auth files are excluded from backup, deployment, and merge operations.
