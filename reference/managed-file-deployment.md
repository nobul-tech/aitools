# Managed File Deployment

Specification for the interactive file deployment system used by setup scripts
(`deploy-harness`, `setup-user-claude`, `setup-user-cursor`, `setup-user-skills`
(fallback), `setup-user-hooks`, the library's skills fan-out, and the skill
blocks that `build-deploy.sh` generates).

## Overview

When `aitools install` deploys a managed file (CLAUDE.md, rules, skills,
hooks, deployed JSON), it compares SOURCE against LOCAL:

- **SOURCE**: the file in the repo (aitools or dotprofile) being deployed. It
  is the source of truth.
- **LOCAL**: the deployed copy on disk.

There is no ancestor and no deploy state: the only comparison is SOURCE
against LOCAL. When they differ in an interactive run, the user sees a diff
and one review menu. Accept & adopt and merge & adopt copy the result into
the repo file (the adopt target) in the same step, so the next run finds
SOURCE, LOCAL and the repo identical and asks nothing.

The choices, their effects and the failure handling are governed by
`@.claude/rules/agentic-standards.md` "Managed-file review choices and
merge". This file is the implementation detail.

## Functions

| Function (PS1) | Function (bash) | Purpose |
|----------------|----------------|---------|
| `Deploy-ManagedFile` | `deploy_managed_file` | Orchestrate one file: compare, review, back up, write LOCAL and the adopt target, validate, restore on failure |
| `Prompt-DiffReview` | `prompt_diff_review` | Text files: show the diff and the review menu, return the choice (and the merged content for merge) |
| `Review-JsonFields` | `review_json_fields` | JSON files: review field by field; SOURCE owns every field; write adopted values into the adopt target |
| `Initialize-DeployTracker` | `deploy_tracker_init` | Reset the outcome counters before a deploy loop |
| `Record-DeployOutcome` | `deploy_tracker_record` | Count one outcome (including `failed`, and `removed` for a deployed copy a fan-out consumer backed up and deleted) and write its DETAIL row; an unknown outcome is logged with `log_error` and counted as `failed` (outcomes are matched case-sensitively) |
| `Write-DeployTrackerSummary` | `deploy_tracker_summary` | Write the loop's summary row: ERROR `N failed` when any file failed, WARN `N skipped (user review)` when any was skipped, else OK with the non-zero counts `N added, N updated, N accepted, N removed, N verified, N failed` |
| `Read-HarnessManifest` | `read_harness_manifest` | Read the rules or skills manifest (`-Kind` / KIND `rules` or `skills`): each name's source or `retired`, invalid lines reported, a bad header reported as `header-bad`; `Read-RulesManifest` / `read_rules_manifest` wrap it for rules |
| `Get-RuleNameKind` | `rule_name_kind` | Classify a name in `~/.aitools/rules`, case-insensitively: `hidden`, `backup` (`*.bak.*`), `rule` (`*.md`), `other` |
| `Get-SkillNameKind` | `skill_name_kind` | Classify a name in `~/.aitools/skills`, case-insensitively: `hidden`, `backup` (`*.bak.*`), `skill` |
| `Test-FanoutTextEqual` | `fanout_text_equal` | 0 equal ignoring trailing CR/LF, 1 differ, 2 unreadable |
| `Test-FanoutDirMatches` | `fanout_dir_matches` | 0 when every file of a deployed skill directory matches a harness copy (`*.bak.*` ignored, symlinks and special files rejected), 1 otherwise, 2 unreadable |
| `Backup-Dir` | `backup_dir` | Copy a directory to `<dir>.bak.<UTC>` and keep the newest 5; reports `BACKUP_DIR_OK` / `$script:BackupDirOk`, the path and the reason. Skips a directory with no top-level `*.md` (so it never copies `~/.claude/skills`, `~/.cursor/skills` or `~/.cursor/rules`) |
| `Invoke-HarnessSkillsFanout` | `fanout_harness_skills` | Fan `~/.aitools/skills` out to one tool's skills directory (`claude skills`, `cursor skills`): deploy every file of every non-retired skill, adopt target from the manifest, retired prune, summary row (`@reference/skills.md` section 6) |
| `Adopt-ManagedFile` | `adopt_managed_file` | Back up and write an adopt target. Used inside `deploy_managed_file` for review adopts; called directly only by reverse discovery of user-created hooks and skills (no SOURCE; see "Shell Script Deployment Detail") |
| `Sync-ManagedJson` | `sync_managed_json` | Profile-mirror regime for `settings.json` (see "JSON Config Review Detail"); unchanged |
| `Prompt-JsonFieldReview` | `prompt_json_field_review` | Per-leaf prompt used by `sync_managed_json`; unchanged |

Removed 2026-10-21: `Try-AutoMerge` / `try_auto_merge`, the deploy-state
helpers (`Initialize-DeployState`, `Get-DeployState`, `Update-DeployState`,
`Get-DeployShadow` and their bash twins), and the auto-merge menu.

### Signatures

bash:

```
deploy_managed_file SRC_CONTENT DEST TOOL_NAME ITEM_NAME [ADOPT_PATH]
    reads ADOPT_TRANSFORM when set; sets MANAGED_FILE_RESULT
prompt_diff_review DEST NEW_CONTENT ADOPT_OFFERED(0|1) [CUR_CONTENT]
    sets DIFF_REVIEW_RESULT (and MERGED_CONTENT for merge)
review_json_fields SRC_FILE DEST ADOPT_PATH
```

PowerShell:

```
Deploy-ManagedFile -Content -DestPath -ToolName -ItemName [-AdoptPath] [-AdoptTransform]
Prompt-DiffReview -FilePath -NewContent -AdoptOffered [-CurrentContent]
Review-JsonFields -SourceFile -DestPath -AdoptPath
Record-DeployOutcome -Outcome failed -ToolName <tool> -ItemName <item>
Write-DeployTrackerSummary -ToolName <tool>
```

- `ADOPT_PATH` / `-AdoptPath` is the absolute path of the repo file that is
  the source of truth for this LOCAL. Empty means adopt and merge are not
  offered.
- `ADOPT_TRANSFORM` (bash, a function name, optional) / `-AdoptTransform`
  (PS1, a scriptblock, optional) turns LOCAL content into adopt-target
  content before the write (used for the CLAUDE.md template; see
  "Markdown files").
- A `DEST` ending in `.json` is reviewed field by field (`review_json_fields`);
  anything else is text (`prompt_diff_review`).

## State Machine

Target model, approved 2026-10-21 (`.claude/rules/agentic-standards.md`
"Managed-file review choices and merge"). SOURCE is the source of truth;
there is no ancestor and no deploy state. The code implements it in mission
SOURCE-TRUTH (`scripts/aitools-lib.sh`, `.ps1`).

```
Source content
    |
    +-- LOCAL missing          --> write SOURCE --> "created"
    +-- LOCAL == SOURCE        --> "verified"
    +-- LOCAL differs
         +-- non-interactive / EOF / --force --> write SOURCE (backup) --> "updated"
         +-- interactive --> Review Menu
              +-- [o]verwrite       --> write SOURCE (backup)                 --> "updated"
              +-- [a]ccept & adopt  --> keep LOCAL + copy to repo now (backup) --> "accept & adopt"
              +-- [m]erge & adopt   --> AI merge (text only) --> write LOCAL
              |                         + copy to repo now (backups)          --> "accept & adopt"
              +-- [s]kip            --> nothing written                       --> "skipped"
              +-- [x]abort          --> log error, exit 2
    Any write/merge/validation failure --> restore backups, log, ERROR row, continue
JSON files: the same choices per differing field (no [m]erge); SOURCE owns every field.
```

## Menus

There is one review menu. It appears only when LOCAL differs from SOURCE in
an interactive run. The options and their order are normative; the exact
wording is set by the implementation (mission SOURCE-TRUTH; diff display
and menu text, mission DIFF-UX, 2026-10-21), identical in
bash and PS1 (`check-post-push` step 29).

### Text files (`prompt_diff_review`)

The diff is shown first, LOCAL -> SOURCE, under a one-line legend (see
"Diff Mechanism Detail"): `-` lines are only on this machine, `+` lines
only in the repo, so the diff reads as what `[o]verwrite` changes here. The
menu says what each choice does to those lines. With an adopt target
(`ADOPT_OFFERED=1`; `<adopt path>` is the adopt target's path). The
`[REVIEW]` line is the only text above the legend; the diff headers name
both files:

```
[REVIEW] <LOCAL path> differs from source.

  red - = only on this machine   green + = only in the repo

--- this machine  <LOCAL path>
+++ repo          <adopt path>
@@ -1,3 +1,3 @@
 # Title
-my local line
+repo line
 end

  [o]verwrite       : this machine gets the green + lines (backup kept)
  [a]ccept & adopt  : the repo gets the red - lines (your version) -> <adopt path>
  [m]erge & adopt   : AI combines both; written to this machine and <adopt path>
  [s]kip            : nothing written; asked again next run
  [x]abort          : stop this script (exit 2)
  choice [o/a/m/s/x]:
```

Without an adopt target (`ADOPT_OFFERED=0`), adopt and merge are not
offered, and the `+++` header reads `source (embedded)`:

```
--- this machine  <LOCAL path>
+++ repo          source (embedded)
...
  [o]verwrite       : this machine gets the green + lines (backup kept)
  [s]kip            : nothing written; asked again next run
  [x]abort          : stop this script (exit 2)
  choice [o/s/x]:
```

An unrecognised answer selects `overwrite`, as today.

### JSON files (`review_json_fields`)

One review per differing field (key path; a whole array is one field),
showing the LOCAL and SOURCE values. With an adopt target:

```
  [o]verwrite      : source value -> local
  [a]ccept & adopt : keep the local value -> write it to the repo now
  [s]kip           : leave this field unchanged; asked again next run
  [x]abort         : stop this script (exit 2)
```

Without an adopt target, `[a]` is not offered. There is no `[m]erge` for
JSON. Overwrite, adopt and skip apply to one field; abort applies to the
script.

### [x]abort

`[x]abort` logs an error and exits 2. A bare exit 2 is a user abort
(D-TS13 as decided 2026-10-21). Abort ends this setup
script (exit 2); the installer continues with the next script. (Today the
installer records any non-zero exit as an ERROR row, `aitools-install.sh`
`validate_and_run`.)

## Non-Interactive Behavior

The run is non-interactive when any of these holds:

- `AITOOLS_FORCE=1` (`--force` / `-Force` on `aitools` and `aitools install`)
- stdin is not a terminal, or the controlling terminal cannot be opened
  (`tty_interactive` / `Test-InteractiveConsole`)
- EOF at a prompt (input ended): a warning is logged

Then no menu is shown and `overwrite` is selected: SOURCE is written to LOCAL
(backup kept) and the result is `updated`. No AI merge runs. The decision is
logged to deploy.log. For JSON, each differing field takes the SOURCE value;
a field only in LOCAL stays in LOCAL.

`DRY_RUN=true` (`AITOOLS_DRY_RUN`) logs what would happen, writes nothing,
and reports the file as `verified`.

## Return Values

### prompt_diff_review / Prompt-DiffReview

| Value | Offered when | Meaning |
|-------|-------------|---------|
| `"overwrite"` | Always; also every non-interactive case | Write SOURCE to LOCAL |
| `"adopt"` | `ADOPT_OFFERED=1` | Keep LOCAL; copy LOCAL to the adopt target |
| `"merge"` | `ADOPT_OFFERED=1` | AI merge accepted; `MERGED_CONTENT` holds it. Written to LOCAL and to the adopt target |
| `"skip"` | Always | Write nothing |
| `"failed"` | `ADOPT_OFFERED=1` | Merge attempted, no valid output after the retry. Mapped to `MANAGED_FILE_RESULT` `failed`; nothing written |
| (exit 2) | Always | User aborted |

### deploy_managed_file / Deploy-ManagedFile

Sets `MANAGED_FILE_RESULT` (bash) / returns (PS1) one of:

| Value | Meaning | LOCAL written? | Adopt target written? |
|-------|---------|---------------|----------------------|
| `"created"` | LOCAL did not exist | Yes (SOURCE) | No |
| `"updated"` | Overwrite chosen, or non-interactive | Yes (SOURCE) | No |
| `"verified"` | LOCAL equals SOURCE | No | No |
| `"accept & adopt"` | Accept & adopt, or merge & adopt (text). JSON: see "File-level result for JSON" below | Adopt: no. Merge: yes (merged content) | Yes |
| `"skipped"` | Skip chosen | No | No |
| `"failed"` | A write, the AI merge or a validation failed | No: backups restored | No: backups restored |
| (exit 2) | User aborted | No | No |

**File-level result for JSON** (approved 2026-10-21, S3-SpecRewrite Q5): a
JSON file reviewed field by field reports one value, by precedence `failed` >
`accept & adopt` (any field adopted: the repo was written) > `skipped` (any
field skipped) > `updated` (any field overwritten) > `verified`. Each
field's choice is logged to deploy.log.

On `failed` the library has already restored every file it backed up and
written a `log_error` with the reason. The caller records the outcome
(`deploy_tracker_record failed ...` / `Record-DeployOutcome failed ...`) and
continues with the next file.

## Caller Responsibilities

- **Pass the adopt target.** Every caller passes `ADOPT_PATH` / `-AdoptPath`:
  the absolute path of the repo file the SOURCE content came from, or `""`
  when there is none (no dotprofile configured, or a source that must not be
  adopted into). The library performs the repo write-back itself. Callers
  never copy LOCAL back to a repo themselves.
- **Handle every return value** at every call site
  (`@.claude/rules/interactive-menus.md` "Return value contract"):

| Return value | Caller-specific validation? | Tracker / summary |
|-------------|-----------------------------|-------------------|
| `created` | Yes (e.g. CLAUDE.md sections, hook executable bit) | Record |
| `updated` | Yes | Record |
| `verified` | No | Record |
| `accept & adopt` | Yes when LOCAL was written (merge) | Record |
| `skipped` | No | Record (summary WARN) |
| `failed` | No (library restored and logged) | Record (summary ERROR) |

`removed` is not a `deploy_managed_file` value: a fan-out consumer records it
itself after it backed up its own copy of a retired rule or skill (the backup
verified) and deleted it.

- **Single-file callers** without a tracker loop (CLAUDE.md) write the
  equivalent `write_summary` row themselves; `failed` is an ERROR row.
- **Dotprofile writes are committed and pushed** (N-Q2, approved
  2026-10-21). An adopt or merge whose adopt target is in the dotprofile
  repo is committed and pushed to the dotprofile's main automatically (the
  library does it, `dotprofile_commit_push`; PR #103). An
  adopt target in the aitools repo is a working-tree change only: no
  commit, no push; the user ships it through a PR.
- **Several LOCALs for one SOURCE** (a harness rule or skill file and its
  Claude Code and Cursor copies): each LOCAL goes through
  `deploy_managed_file` in its own fan-out (`setup-user-claude`,
  `setup-user-cursor`). Only the Claude Code fan-out offers adopt; it writes
  the repo source, and `~/.aitools` keeps the old copy until the next
  `deploy-harness` run, so the Cursor copy follows one run later. In the
  fallback (`setup-user-skills`, no `~/.aitools/skills`) the old rule holds:
  after an adopt into the first LOCAL the caller reads SOURCE again for the
  next, which then verifies. Callers do not copy one LOCAL to another.
- **Adopting into a protected file** (any path in the
  `.claude/rules/sources-of-truth.md` table) is allowed; the library writes
  the working tree and logs a WARN naming the file. The library knows the
  protected files from a path list it holds, kept in sync with the
  sources-of-truth table by a pre-commit step (Q14, approved 2026-10-21;
  the list and the step are implemented in mission SOURCE-TRUTH).
- **CLAUDE.md** passes an adopt transform: see "Markdown files".
- **Exit 2** is not trapped by the caller: it ends the script.

## Deploy State

Removed 2026-10-21: there is no ancestor and no deploy state. See
`@.claude/rules/agentic-standards.md` "Managed-file review choices and merge".

## Normalization

Before comparing SOURCE and LOCAL, both are normalized:
- Trailing whitespace: collapse `[\r\n]+$` to single `\n`
- Prevents round-trip diff noise (deploy --> adopt strips blanks --> deploy
  sees diff)

JSON files are compared after parsing, field by field; formatting and key
order do not create a difference.

## Encoding (PS1)

Content displayed in a menu that comes from an external command (diff,
git) is read via a temp file and `[IO.File]::ReadAllText($path,
[Text.Encoding]::UTF8)`, never captured through the PowerShell pipeline.
This avoids PowerShell's OEM codepage mangling UTF-8
(`@reference/cross-platform-detail.md` "PowerShell pipeline encoding").

---

## Deployment Types

Setup scripts deploy three types of managed files. Every type has the
same correctness requirements (backup, logging, validation). They differ
in review strategy, not in importance or priority. See
`@.claude/rules/managed-file-deployment.md` for the concise rule.

### Markdown files

**Files**: CLAUDE.md, `~/.claude/rules/*.md`, `~/.cursor/rules/*.mdc`, every file of a skill directory.

**Pattern**: `deploy_managed_file` / `Deploy-ManagedFile` in
`@scripts/aitools-lib.sh` / `@scripts/aitools-lib.ps1`.
Compare → review menu → backup → write → validate. Full state machine above.

**Content source**: CLAUDE.md from dotprofile repo (primary) or
`shared/claude-shared.md` (fallback); rules from `~/.aitools/rules/` and
skills from `~/.aitools/skills/` (the fan-outs; first source wins there:
`shared/`, then `.claude/`, then the dotprofile). Without `~/.aitools/skills`
the fallback `setup-user-skills` deploys `shared/skills/`, or the dotprofile's
`claude/skills/` when it has the skill. Template tokens
(`{{PLACEHOLDER}}`) interpolated from `profile.json`. See
`@reference/user-repo.md` "Template Resolution", "User Rules Deployment" and
`@reference/skills.md`.

**Adopt target**: the file the content was read from (dotprofile or
`shared/`); for a rule or skill file from the fan-out, the source file the
manifest names (none without a manifest, none for Cursor, none when the
script does not run from a git checkout). Adopting into `shared/claude-shared.md` (a protected file) is
allowed: it writes the working tree only and logs a WARN naming the file;
the review gate applies at commit and PR.

**CLAUDE.md is a template** (S3-SpecRewrite Q1, approved 2026-10-21):
LOCAL is the template with `{{PLACEHOLDER}}` tokens interpolated plus a
generated `## Machine-Specific` footer. Adopting it into the template must
strip the footer and reverse the interpolation, not copy LOCAL verbatim.
`setup-user-claude` therefore passes an adopt transform with the template as
`ADOPT_PATH` (bash: the function name in `ADOPT_TRANSFORM`; PS1:
`-AdoptTransform` scriptblock; today's logic is `adopt_claude_md`). The
library applies the transform to the content before writing `ADOPT_PATH`,
and compares the adopt target after the transform.

**Scripts**:
- `setup-user-claude.sh/.ps1` — CLAUDE.md, the rules fan-out (`claude rules`), the skills fan-out (`claude skills`)
- `setup-user-cursor.sh/.ps1` — the rules fan-out (converted `.mdc`, `cursor rules`), the skills fan-out (`cursor skills`)
- `setup-user-skills.sh/.ps1` — fallback skill deployer (SKILL.md only) when `~/.aitools/skills` does not exist; reverse discovery
- `deploy-harness.sh/.ps1` — `~/.aitools/**` (`harness files`)

### JSON config files

**Files**: `~/.claude/settings.json`, `~/.cursor/cli-config.json`,
`~/.cursor/mcp.json`, and any JSON file deployed through
`deploy_managed_file`.

**Pattern**: two regimes; see "JSON Config Review Detail". Read existing
JSON → set managed fields only → preserve all other fields → validate →
write.

**Content source**: field values from `profile.json` (e.g., Claude
preferences, Cursor CLI settings), a JSON file in the repo (deployed JSON),
or hardcoded in the script (e.g., MCP server URLs, `--isolated` flag).
Platform-specific values (e.g., `cmd /c npx` vs `npx`) are dispatched by OS
guards — see "Platform-Specific Config Values" below.

**Scripts**:
- `setup-user-settings.sh/.ps1` — settings.json (`sync_managed_json`,
  mirror at `profile.json` `claude.settings`)
- `setup-user-hooks.sh/.ps1` — settings.json `hooks` (harness-managed,
  reconciled without review)
- `setup-user-mcp.sh/.ps1` — MCP server registration in `~/.claude.json`
  via `claude mcp add` (the CLI writes the file; no review)
- `setup-user-cursor.sh/.ps1` — cli-config.json (preferences from
  `profile.json` `cursor.cli` section)
- `setup-cursor-ide-mcp.sh/.ps1` — mcp.json (MCP server configs)

### Shell scripts

**Files**: Hook scripts (`~/.claude/hooks/*.sh`).

**Pattern**: `deploy_managed_file` — same as the markdown type, with the full
menu including merge & adopt.

**Content source**: `shared/hooks/` in the aitools repo (SD-2: one hook
version, in `shared/hooks`). Hook scripts are bash-only on both platforms
(Claude Code runs hooks in bash on all platforms). No platform-specific
variants needed.

**Scripts**:
- `setup-user-hooks.sh/.ps1` — every hook in the hook manifest

## Content Sources

Deployed content originates from two repos. For templates and profile
values the dotprofile repo takes priority when present and the aitools
`shared/` directory is the fallback. Rules and skills are the exception:
they go through `~/.aitools`, where the first source wins (`shared/`, then
`.claude/`, then the dotprofile).

| Content | Primary source | Fallback |
|---------|---------------|----------|
| CLAUDE.md template | `<userRepoPath>/claude/CLAUDE.md` | `shared/claude-shared.md` |
| User rules | `~/.aitools/rules/*.md` (deploy-harness fills it from `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/`, first source wins); `setup-user-claude` and `setup-user-cursor` take every non-retired rule | (none — `~/.aitools/rules` absent: no rules deployed, target untouched) |
| Claude preferences | `<userRepoPath>/profile.json` `claude` section | defaults (autoMemory: true, alwaysThinking: true) |
| Cursor preferences | `<userRepoPath>/profile.json` `cursor.cli` section | defaults (vimMode: false, model: auto) |
| Identity (git name/email) | `<userRepoPath>/profile.json` `identity` section | (required — no fallback) |
| Machine profile | `<userRepoPath>/profile.json` `profiles[machineAlias]` section | hostname match, then first profile |
| Hook scripts | `shared/hooks/*.sh` | (required — no fallback) |
| Skills | `~/.aitools/skills/<name>/**` (deploy-harness fills it from `shared/skills/`, `.claude/skills/` and `<userRepoPath>/claude/skills/`, first source wins); `setup-user-claude` and `setup-user-cursor` take every non-retired skill | `setup-user-skills` when `~/.aitools/skills` is absent: `<userRepoPath>/claude/skills/*/SKILL.md` when present, else `shared/skills/*/SKILL.md` |
| MCP server configs | hardcoded in setup scripts | (required — no fallback) |

The adopt target for a file is the primary or fallback source it was
actually read from.

### Deployed harness (`~/.aitools`)

`deploy-harness.sh` / `.ps1` copies harness content into `~/.aitools`
(Windows `%USERPROFILE%\.aitools`). Each file goes through
`deploy_managed_file` / `Deploy-ManagedFile` with the tool name
`harness files`; the adopt target is the repo file it was read from. Only
git-tracked files are deployed. On a name conflict the first source wins
and each skipped duplicate is a `log_error` plus an ERROR row.

| Deployed to | Sources, in order |
|-------------|-------------------|
| `~/.aitools/reference/**` | `reference/**` |
| `~/.aitools/registries/**` | `registries/**` |
| `~/.aitools/hooks/` (flat) | `shared/hooks/`, `.claude/hooks/` |
| `~/.aitools/skills/<name>/` (+ `.aitools-skills-manifest`) | `shared/skills/`, `.claude/skills/`, `<userRepoPath>/claude/skills/` |
| `~/.aitools/rules/` (flat, `*.md`; + `.aitools-rules-manifest`) | `shared/rules/`, `.claude/rules/`, `<userRepoPath>/claude/rules/` |
| `~/.aitools/bin/` | `scripts/harness-db.py`, `scripts/read-session.py`, `scripts/read-session-full.py` |
| `~/.aitools/config.json` | generated from `profile.json` by `setup-user-config` (called by deploy-harness) |

Rules and skills reach the tools from here: `setup-user-claude` fans them out
to `~/.claude/rules/` and `~/.claude/skills/`, `setup-user-cursor` to
`~/.cursor/rules/` (converted to `.mdc`) and `~/.cursor/skills/`, every name
except the retired ones. Conflict handling and its assumptions:
`@reference/harness.md` "Deployed harness (`~/.aitools`)".

**`userRepoPath` resolution**: read from `~/.aitools/config.json`. Set by
`aitools user init`. If not configured, dotprofile features are skipped
and shared fallbacks are used.

Full spec: `@reference/user-repo.md`

## Platform-Specific Config Values

JSON config files may contain values that differ by platform. OS guards
in setup scripts ensure the correct variant is deployed. Never run a
`.sh` setup script on Windows or a `.ps1` on macOS — cross-platform
dispatch rules in `@.claude/rules/cross-platform.md` prevent this.
A few values also differ by environment; the `.sh` setup script selects
them through the environment API (`@.claude/rules/cross-platform.md`
"Environment branches").

| Config file | Field | Windows | macOS | Linux |
|-------------|-------|---------|-------|-------|
| `mcp.json` | chrome-devtools command | `"cmd", "/c", "npx", "-y", "chrome-devtools-mcp@latest", "--isolated"` | `"npx", "-y", "chrome-devtools-mcp@latest", "--isolated"` | same as macOS |
| `mcp.json` (Cursor), `~/.claude.json` (Claude Code) | chrome-devtools command, Claude Code web environment (D-CHR2) | n/a | n/a | `"npx", "-y", "chrome-devtools-mcp@latest", "--isolated", "--headless", "--chromeArg=--no-sandbox"` |
| `settings.json` | hook command paths | `bash "C:/Users/<user>/.claude/hooks/<hook>.sh"` | `bash "/Users/<user>/.claude/hooks/<hook>.sh"` | `bash "/home/<user>/.claude/hooks/<hook>.sh"` (`/root/...` as root) |
| `cli-config.json` | (no platform differences) | identical | identical | identical |

**Claude Code web environment args**: `--headless` because the container
has no display; `--chromeArg=--no-sandbox` because the agent runs as root
and Chrome refuses to start as root with its sandbox on. Written by
`setup-user-mcp.sh` and `setup-cursor-ide-mcp.sh` only when the
environment is `claude-code-web`. Detail and security note:
`@reference/tool-ops-google-chrome.md`.

**`--isolated` flag**: platform-independent, MUST be present on every
platform and environment. Enables throwaway temp Chrome profiles for concurrent Claude
Code + Cursor sessions. See `@reference/tool-registry.md` "Chrome DevTools
MCP".

**Path format in settings.json hooks**: PowerShell setup converts
backslash paths to forward slashes (`-replace '\\', '/'`) for bash
compatibility. This is intentional — Claude Code always runs hooks via
bash, even on Windows.

## Shell Script Deployment Detail

Shell scripts (hooks) use `deploy_managed_file` with the same state
machine as markdown files. The adopt target is the repo source,
`shared/hooks/<filename>` in the aitools repo (absolute path), never the
dotprofile repo: hooks are framework code maintained in the aitools repo,
and a dotprofile copy would be ignored (SD-2, incident #80).

On accept & adopt or merge & adopt, the library writes the result to
`shared/hooks/<filename>` itself. This is a working-tree change in the
aitools repo; the user decides whether to commit it. When
`shared/hooks/` is not present (MDM path without the aitools repo), the
caller passes `""` and adopt and merge are not offered.

After `created`, `updated`, or a merge & adopt (LOCAL written), the caller
sets the executable bit on LOCAL.

**Reverse discovery** (S3-SpecRewrite Q2: kept, 2026-10-21): `setup-user-hooks`
also finds user-created hooks, a `*.sh` in `~/.claude/hooks/` with no SOURCE
(in neither `shared/hooks/` nor `<userRepoPath>/claude/hooks/`), and offers
`[a]dopt to dotprofile  [s]kip`. `[a]dopt` copies the hook into
`<userRepoPath>/claude/hooks/` through the library helper
`adopt_managed_file` / `Adopt-ManagedFile` (backup, checked copy). It is
outside the review-menu model: there is no SOURCE to compare. It does not
conflict with SD-2, which covers manifest hooks only. `setup-user-skills`
does the same for user-created skills (target
`<userRepoPath>/claude/skills/<name>/SKILL.md`); a name in `~/.aitools/skills`
or its manifest is never treated as user-created (FD-9). Prompts, non-interactive
and EOF behavior: user rule `hook-lifecycle.md` "User-created hooks" and
"Prompts in the hook deploy".

## JSON Config Review Detail

JSON config files use field-level review rather than text diff review.
There are two regimes.

### Regime 1: SOURCE owns every field (`review_json_fields`)

For a JSON file deployed from a JSON SOURCE through `deploy_managed_file`.

- Node compares SOURCE and LOCAL field by field (key path; a whole array is
  one field). Each differing field is one review (menu above).
- **SOURCE owns every field.** A field in SOURCE whose LOCAL value differs,
  or that LOCAL lacks, is a differing field.
- **A field only in LOCAL** is kept in LOCAL and never written to SOURCE
  without a review. With an adopt target it gets its own review (Q7,
  approved 2026-10-21): `[a]ccept & adopt` (write the field to the repo
  now) / `[s]kip` (keep it in LOCAL only) / `[x]abort`. There is no
  overwrite: it would delete user data. Non-interactive keeps it in LOCAL.
- **Adopted values** are written into `ADOPT_PATH` immediately, before the
  next file is reviewed. The field choices for one file are applied after
  its last field is reviewed; `[x]abort` on any field writes nothing.
- **Key order is preserved** in both files; no sorting.
- **No text or AI merge.**
- Both files are backed up before writing and validated after writing:
  each parses, and each still has every top-level key of SOURCE (the
  required keys; Q8, approved 2026-10-21). On failure both are restored
  (`failed`).
- Non-interactive: every differing field takes the SOURCE value; LOCAL-only
  fields stay in LOCAL.

### Regime 2: profile mirror (`sync_managed_json`), unchanged

`settings.json` is mirrored at `profile.json` `claude.settings`
(`setup-user-settings`), excluding harness-managed keys (`hooks`), which
`setup-user-hooks` reconciles without review.

- A leaf only in the live file auto-adopts into `profile.json` (no prompt).
- A leaf that differs, or that the live file lacks, gets one per-leaf prompt
  (`prompt_json_field_review`); per rule string for
  `permissions.{allow,ask,deny}`. Deprecated permission rules are stripped
  from the live file first and never adopted.
- Menu: `[o]verwrite` (profile.json value → settings.json) / `[a]dopt`
  (settings.json value → profile.json) / `[s]kip` / `[x]abort` (exit 2;
  ends the script, nothing applied: prompts run before the apply pass).
- Writes preserve key order. Both files are backed up before write and
  validated after.

### Script-owned JSON (no review)

`cli-config.json` (`setup-user-cursor`) and `mcp.json`
(`setup-cursor-ide-mcp`) set script-owned managed fields by read-then-merge
(`@.claude/rules/config-file-safety.md`) with no review menu and no adopt.
Their values come from `profile.json` (cursor.cli) or are hardcoded. They
refuse to write a corrupt file, or a merge that would lose fields, without
`--force`.

| Config file | Regime | Managed field source | Adopt target |
|-------------|--------|---------------------|--------------|
| `settings.json` (non-hook keys) | Profile mirror | `profile.json` `claude.settings` | `profile.json` `claude.settings` |
| `settings.json` (`hooks`) | Harness-managed | hook manifest | (not adoptable) |
| `cli-config.json` | Script-owned | `profile.json` `cursor.cli` | (not adoptable) |
| `mcp.json` | Script-owned | hardcoded server configs | (not adoptable) |
| JSON deployed via `deploy_managed_file` | SOURCE owns every field | the repo JSON file | `ADOPT_PATH` |

**Script-owned text: the rules manifest and the skills manifest.**
deploy-harness writes `~/.aitools/rules/.aitools-rules-manifest` and
`~/.aitools/skills/.aitools-skills-manifest` on every run without review
(it is their sole owner; temp file then move; a failure is `log_error` + an
ERROR row). They are not deployed through `deploy_managed_file`: they are
generated, not copied from a source. Each lists a name's source or
`retired`; retired rules and skill directories are backed up and removed by
deploy-harness and by the fan-out consumers. Format and rules:
`@reference/harness.md` "Rules manifest and retired rules", "Skills manifest
and retired skills".

## Diff Mechanism Detail

**Text types (review display)**: `_review_diff` in `@scripts/aitools-lib.sh`
/ `Get-ReviewDiff` in `@scripts/aitools-lib.ps1`. Both write LOCAL and
SOURCE (trailing newlines normalized to one LF, UTF-8) to temp files and run
the same command, so bash and PS1 print identical hunks:

```
git -c core.quotePath=false -c diff.suppressBlankEmpty=false \
    -c diff.interHunkContext=0 diff --no-index --no-color --no-ext-diff \
    --no-textconv --text --diff-algorithm=myers --indent-heuristic -U3 \
    -- <local> <source>
```

`GIT_DIFF_OPTS` is removed from git's environment and the `-c` settings
are pinned, so user git config cannot change the hunks.

- **Direction**: LOCAL -> SOURCE. `-` = only on this machine, `+` = only in
  the repo.
- **Headers**: git's own header lines are dropped and replaced by
  `--- this machine  <LOCAL path>` and `+++ repo          <SOURCE path>`
  (labels padded to equal width). The SOURCE path is the adopt target;
  without one it reads `source (embedded)`.
- **Legend**: `  red - = only on this machine   green + = only in the repo`
  above the diff.
- **Colour**: `-` lines and the `---` header red, `+` lines and the `+++`
  header green, unless `NO_COLOR` is set or `TERM=dumb`
  (`_review_colour` / `Test-ReviewColour`). The diff is only shown on an
  interactive terminal; the deploy log is always plain text.
- **Truncation**: over 40 diff lines (headers included), the terminal shows
  the first 30 and `  ... (N more lines -- full diff in deploy log)`. The
  full diff goes to deploy.log at every size, one `[detail] diff <file>:`
  line each.
- **Failure**: if git cannot produce the diff (exit above 1, not found),
  a warning is logged (`Review diff unavailable for <path>: <reason>`), the
  terminal shows `  (diff unavailable -- see deploy log)`, and the menu is
  shown as usual. No line difference from git shows
  `  (whitespace-only differences)`.

PS1 reads git's output as UTF-8 straight from the process stream, never
through the PowerShell pipeline (see "Encoding (PS1)").

**AI merge input** (`[m]erge & adopt`) is not the review display: bash
passes the `diff -u` SOURCE -> LOCAL diff (labels `source (would deploy)` /
`local (on disk)`), PS1 a `Compare-Object` listing, both unchanged by the
display change (see "AI-Assisted Merge Detail").

**JSON configs** (field-level): Per-field old → new display with source
attribution. Full field list written to deploy.log via `Emit-MergeDetails`
/ `emit_merge_details` in `@scripts/aitools-lib.sh` /
`@scripts/aitools-lib.ps1`.

## AI-Assisted Merge Detail

`[m]erge & adopt` uses the agentic invocation framework (`invoke_ai` /
`Invoke-AI` in `@scripts/aitools-lib.sh` / `@scripts/aitools-lib.ps1`). It
applies to text types (markdown, shell scripts) only, and only when an
adopt target exists: an accepted merge is written to LOCAL and copied to
the adopt target. Merge is adopt.

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
2. Preview first 30 lines in terminal (preview before write)
3. User chooses: `[y]es` accept, `[r]efine` with feedback, `[n]o` reject
4. Refine: user provides feedback → refinement prompt → re-validate →
   preview again
5. `[y]es`: `prompt_diff_review` returns `merge` with `MERGED_CONTENT`;
   `deploy_managed_file` backs up LOCAL and the adopt target, writes the
   merge to both, validates, and returns `accept & adopt`
6. The AI merge fails (no valid output after the retry): no file is
   written; the outcome is `failed` (log_error with the reject reason,
   ERROR row) and the run continues with the next file
7. `[n]o`: no file is written and the review menu is shown again for the
   same file (Q4, approved 2026-10-21; today the code falls back to
   overwrite)

**Telemetry**: every invocation logged to deploy.log per
`@.claude/rules/script-standards.md` "Agentic invocation logging".
Rejected output logged line-by-line via `log_detail` for post-mortem.

See `@.claude/rules/agentic-standards.md` for the full prompt design,
evaluation lifecycle, and speed/permission tier definitions.

## Backup Policy

All file deployment (all types) MUST call `backup_file` / `Backup-File`
before writing to an existing file. For a managed file the library backs up
every file the step will write: LOCAL, and the adopt target for an adopt
or merge (JSON: LOCAL and `ADOPT_PATH`).

- **Location**: `<file>.bak.<TIMESTAMP>` (same directory as target)
- **Retention**: max 20 per file, auto-prune oldest
- **Directory backups**: `<dir>.bak.<TIMESTAMP>/`, max 5, auto-prune
- **Skip**: Only when target does not yet exist (nothing to back up)
- **Failure to back up**: inside `deploy_managed_file` / `Deploy-ManagedFile`,
  a failed backup of an existing file makes the step `failed` with nothing
  written, so a later failure can always be restored (Q13, approved
  2026-10-21). Other writers: non-fatal (warn and proceed;
  `@.claude/rules/config-file-safety.md`)
- **Restore on failure**: when a write, the AI merge or a validation fails,
  the library restores each file from the backup it just took (a file that
  did not exist before is removed), logs the error with its reason, and
  returns `failed`. A failure never leaves a half-written file.

See `/incident` skill (incident #5) for the backup proliferation issue
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
