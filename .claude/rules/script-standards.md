## Script Standards (this repo)

All plans you propose and all reusable code you write must follow these conventions.
A plan that drafts code with violations is itself a violation. This covers all reusable scripts including: setup scripts
(`scripts/setup-*.sh/.ps1`), check/audit scripts (`scripts/check-*.sh/.ps1`), installer
scripts (`scripts/aitools-install.*`, `scripts/aitools*`), deploy scripts
(`deploy/*.sh/.ps1`), hooks (`shared/hooks/*.sh`), shell aliases (`shared/shell/*`),
pseudocode in `plans/*.md`, and any code you propose in conversation.

### Block order (bash reusable scripts)

1. Shebang + header comment (name, purpose, "safe to re-run", platform, reference to the `/tool-registry` skill)
2. `set -euo pipefail`
3. `source aitools-lib.sh` + `logging_init "script-name"` (provides platform detection, display_path, read_config_key, log/log_ok/log_error/log_warn, write_warn/write_action/write_error, error_reason, write_summary, backup_file, backup_dir, emit_merge_details, ERRORS/WARNINGS counters)
4. OS guard -- see `@.claude/rules/cross-platform.md` "OS guard patterns"
5. Script body
6. Exit footer (check `$ERRORS` + `$WARNINGS`, exit 1 on errors)

### Block order (PowerShell reusable scripts)

1. Header comment (name, purpose, "safe to re-run", platform, reference to the `/tool-registry` skill)
2. `. aitools-lib.ps1` + `Initialize-Logging "script-name"` (provides ReadConfigKey, Log/LogOk/LogError/LogWarn, Write-AitWarn/Write-AitAction/Write-AitError, Get-AitErrorReason, Write-Summary, Backup-File, Backup-Dir, ConvertPSObjectToHashtable, Emit-MergeDetails, $errors/$warnings counters)
3. OS guard -- see `@.claude/rules/cross-platform.md` "OS guard patterns"
4. Script body
5. Exit footer (check `$errors` + `$warnings`, exit 1 on errors)

### Block order (check/audit scripts)

Check scripts follow a variant. Key difference: they source `check-lib`
(which sources `aitools-lib`), then `init-logging` for the guard, then
`check_log_init`/`CheckLogInit` which overrides logging vars for
check-specific paths (checks.log, checks.jsonl).

**Bash:**

1. Shebang + header
2. `set -euo pipefail`
3. `source check-lib.sh` + `source init-logging.sh`
4. OS guard (uses `log_error`)
5. `resolve_config` + `check_log_init "NAME"`
6. Script body (steps)
7. `print_summary`

**PowerShell:**

1. Header
2. `. check-lib.ps1` + `. init-logging.ps1`
3. OS guard (uses `LogError`)
4. `ResolveConfig` + `CheckLogInit "NAME"`
5. Script body (steps)
6. `PrintSummary`

See `@reference/script-standards-detail.md` "Bridge pattern" for why the
double-init (init-logging → CheckLogInit) is safe.

### Error and warning tracking requirement

- Every warning goes through a warning helper (`log_warn`, `write_warn`, `write_action` /
  `LogWarn`, `Write-AitWarn`, `Write-AitAction`) and every error through an error helper
  (`log_error`, `write_error` / `LogError`, `Write-AitError`). One call logs, counts and
  records it once (`@reference/logging.md` 8.2); never raise `ERRORS` / `WARNINGS`
  (`$script:errors` / `$script:warnings`) or write a WARN or ERROR record by hand.
- Each script counts its own warnings; its error count also includes every child it
  relayed that failed. A relayed child's warnings are the child's, not the parent's
  (`@reference/logging.md` 8.3).
- Missing tracking is a bug: an uncounted error misreports the exit status, and an
  unrecorded warning or error is missing from the end-of-run panel.

### Log line format

Every log line must follow: `[timestamp] [script-name] [level] message`

Valid levels: `info`, `ok`, `warn`, `error`, `detail`

Console output uses ANSI colors: red for `[error]`, yellow for `[warn]`, plain for `[info]`/`[ok]`.
Log file output is plain text only (no ANSI codes).

Log location (`~/.aitools/logs`), size-based rotation (5 MB × 5 backups), and
per-component file names are the single source of truth in `@reference/logging.md`.

### Required logging helpers

This table says when to use each helper. What each one writes to deploy.log, counts and
records in the run summary file is specified in `@reference/logging.md` 8.2.

| Bash | PowerShell | Level | When to use |
|------|-----------|-------|-------------|
| `log` | `Log` | `info` | General info; also a step the user explicitly asked for in this run that completed as asked (not a warning: `@reference/logging.md` 8.3 "What is a warning") |
| `log_ok` | `LogOk` | `ok` | Success |
| `log_detail` | `LogDetail` | `detail` | Diagnostic content (file-only, no console): diffs, captured command output |
| `write_warn TOOL TEXT` | `Write-AitWarn` | `warn` | A warning about a known tool; TEXT says what is wrong |
| `write_action TOOL TEXT ACTION` | `Write-AitAction` | `warn` | A warning the user must act on; TEXT says what needs to be done (for a login: `not authenticated -- run: vercel login`), ACTION is the command or step |
| `log_warn TEXT` | `LogWarn` | `warn` | A warning when no tool is known (recorded under the script name) |
| `write_error TOOL WHAT REASON` | `Write-AitError` | `error` | An error: WHAT is the step that failed, REASON why |
| `log_error TEXT` | `LogError` | `error` | Only an error whose TEXT already states its cause: it records an empty reason |
| `error_reason OUTPUT EXIT_CODE` | `Get-AitErrorReason -Output -ExitCode [-ErrorRecord]` | `detail` (the output) | The REASON for a failed external command, from its captured output |
| `write_summary OK\|DETAIL\|ACTION` | `Write-Summary` | none | A tool's status, the items of its outcome, an ACTION with no warning of its own ("End-of-run summary") |

A warning reports something that is wrong, or that still needs the user; anything else is
logged at info (`@reference/logging.md` 8.3 "What is a warning").

All timestamps must be UTC with Z suffix (`date -u +%Y-%m-%dT%H:%M:%SZ` / `.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")`).

Logging framework is required -- raw `echo` or `Write-Host` without structured logging is not acceptable in reusable scripts.

All helpers are defined in `@scripts/aitools-lib.sh` (bash) / `.ps1`. Scripts source the lib and call `logging_init` / `Initialize-Logging`. Apart from the writers listed in `@reference/logging.md` 8.1 (the hooks, the Python tools, check-lib and the check scripts, among others), no script defines or overrides a logging function, or appends to a log or run summary file directly: a script that needs other behaviour sets a library option (the installers' jsonl option, the profile resolver's stderr console option: `@reference/logging.md` sections 3, 5 and 7). Do not define inline copies.

### Agentic invocation logging

Every `invoke_ai` / `Invoke-AI` call must log structured telemetry to deploy.log:

| Event | Level | Format |
|-------|-------|--------|
| Invocation start | `info` | `AI invocation: speed=TIER backend=CLI attempt=N` |
| Success | `info` | `AI invocation: speed=TIER backend=CLI attempt=N result=accepted` |
| Validation failure | `warn` | `AI invocation: speed=TIER backend=CLI attempt=N result=rejected reason=REASON` |
| Rejected output | `detail` | `ai-rejected: LINE` (per-line, file-only) |
| All retries exhausted | `warn` | `AI invocation: speed=TIER backend=CLI exhausted after N attempts` |
| Backend unavailable | `error` | `AI invocation: no CLI available (claude or agent)` |

This telemetry enables prompt iteration: read `[detail] ai-rejected:` lines
from deploy.log, identify the failure mode, update the prompt, re-test.

See `@.claude/rules/agentic-standards.md` for prompt design and evaluation rules.

### Agentic invocation

See `@.claude/rules/agentic-standards.md` for AI CLI invocation requirements,
prompt design standards, and evaluation lifecycle.

### Exit footer

Every setup script must end with an exit footer that checks both ERRORS and WARNINGS counters:
the script's own warnings, and its errors including every relayed child that failed
(`@reference/logging.md` 8.3). See `@reference/script-standards-detail.md` for exact code patterns.

### Cross-platform grep portability

Never use `grep -P` (Perl regex) in bash scripts -- macOS BSD `grep` doesn't support it.
Use `perl -ne` for Perl regex, `grep -E` for extended regex, or `grep -F` for literals.
See `@reference/script-standards-detail.md` for the full portability table.

Never end a pipeline in a reader that exits before its input ends, in a script
or test suite that runs under `pipefail` (or a library sourced by one): `grep -q`,
`grep -l` / `-L`, `grep -m`, `head`, or a perl `-n` / `-p` program that runs
`exit` or `last`. The reader stops reading, the writer dies of SIGPIPE (or,
where SIGPIPE is ignored, exits non-zero on the write error) and the pipeline
fails although the reader found what it wanted. Use a form that reads to the
end: `grep PATTERN >/dev/null`, `sed -n '1,Np'` for `head -n N`, perl
`next if $done; ...` or `END { exit(...) }`. `check-script-compliance` step 7
fails on all of them in `scripts/`, `shared/hooks/` and `tests/`.
Detail: `@reference/script-standards-detail.md` "Pipelines into grep -q under pipefail".

### Check script logging

Check/audit scripts (`check-*.sh/.ps1`) use a separate logging system from setup
scripts. They source `check-lib` (which sources `aitools-lib`), then source
`init-logging` to initialize structured logging before the OS guard. After the
guard, they call `CheckLogInit`/`check_log_init` which overrides logging vars
for check-specific paths (checks.log, checks.jsonl). This double-init is safe —
see `@reference/script-standards-detail.md` "Bridge pattern".

- **Step functions**: `StepPass`/`step_pass`, `StepFail`/`step_fail`, etc.
- **Destinations**: `checks.log` + `checks.jsonl` (not `deploy.log`)
- **Semantics**: PASS/FAIL/WARN/SKIP (not OK/WARN/ERROR)

`CheckLogInit`/`check_log_init` bridges the gap by also setting aitools-lib
logging variables, so lib functions called from check steps can write to
`deploy.log`. See `@reference/script-standards-detail.md` for details.

### End-of-run summary

Every setup script reports to the end-of-run panel through the `aitools-lib` helpers
(the run summary file: `@reference/logging.md` 8.4; the panel: 8.5):

```bash
write_summary OK     "tool_name" "version or status"
write_summary DETAIL "tool_name" "one item of the outcome"
write_warn   "tool_name" "what is wrong"
write_action "tool_name" "not authenticated -- run: tool login" "tool login -- authenticate tool"
write_error  "tool_name" "brew install failed" "$(error_reason "$out" "$rc")"
write_summary ACTION ""  "instruction for user"
```

```powershell
Write-Summary "OK"     "tool_name" "version or status"
Write-Summary "DETAIL" "tool_name" "one item of the outcome"
Write-AitWarn   "tool_name" "what is wrong"
Write-AitAction "tool_name" "not authenticated -- run: tool login" "tool login -- authenticate tool"
Write-AitError  "tool_name" "winget install failed" (Get-AitErrorReason -Output $out -ExitCode $rc)
Write-Summary "ACTION" ""  "instruction for user"
```

| Record | Meaning | Written by |
|--------|---------|------------|
| OK | The tool's status: installed and usable (a version, `verified`, `n/a (<reason>)`) | `write_summary OK` |
| DETAIL | One item of the tool's outcome | `write_summary DETAIL` |
| WARN | One warning: something is wrong, or still needs the user | `write_warn`, `write_action`, `log_warn` |
| ERROR | One error: what failed and why | `write_error`, `log_error`, the relay (a failed child) |
| ACTION | A command or step the user must take | `write_action`; `write_summary ACTION` for an instruction with no warning of its own |

A WARN or ERROR record is one warning or one error, never a tool's status:
`write_summary WARN` / `ERROR` are retired, and `write_summary` never changes a
record's category. A tool with a warning or an error is shown in yellow or red,
not in green (`@reference/logging.md` 8.5).

Every code path (success AND failure) must report: an OK record when the tool works,
and an error through `write_error` when it fails. A tool that fails must appear as
an error, not be silently absent.

See `@reference/script-standards-detail.md` "End-of-run summary" for the tool name
table, the severity decision guide and platform-specific patterns.

### Config and file update reporting

Setup scripts that write config files, .md files, hooks, or skills must follow the
three-outcome pattern (unchanged/updated/failed) with file-type-specific change logging;
a failed write is `write_error` with the write error as its reason.
The status text of OK records is max 30 chars; DETAIL, warning and error text is not held
to that limit (the panel cuts yellow and red lines at 70: `@reference/logging.md` 8.5).
JSON configs log changed keys and emit DETAIL summary lines; text files log diffs to deploy.log.
See `@reference/script-standards-detail.md` for patterns and examples.

For interactive managed file deployment (diff review + user choice), see
`@.claude/rules/interactive-menus.md` and `@reference/managed-file-deployment.md`.

### External command error handling

External install/upgrade commands (pip, npm, winget, brew, cargo, apt-get) MUST:

1. **Capture output** -- never fire-and-forget an install command
2. **Check exit codes** -- `$LASTEXITCODE` (PS1) or wrap to prevent `set -e` abort (bash)
3. **Distinguish "up to date" from failure** -- inspect output messages, not just exit codes
4. **Treat PATH issues as errors** -- tool installed but not on PATH = functional failure
5. **Report a failure with its reason** -- `write_error TOOL WHAT "$(error_reason "$out" "$rc")"` /
   `Write-AitError TOOL WHAT (Get-AitErrorReason -Output $out -ExitCode $rc)`. Output that is
   streamed (`| while read`) is captured or teed first, so there is output to take the reason from

See `@reference/script-standards-detail.md` for platform-specific code patterns and
anti-patterns.

### Post-install authentication check

Setup scripts for tools requiring authentication MUST check auth status on every run —
not just fresh installs. After successful install/upgrade:

1. Check auth using the tool's own command or config file presence
2. Not authenticated: `write_action TOOL TEXT ACTION` / `Write-AitAction` -- one warning whose
   TEXT says what needs to be done (`not authenticated -- run: vercel login`), and one ACTION
3. Authenticated: no extra output (silent success)

Auth check commands are documented per-tool in the tool registry (`/tool-registry` skill, `authentication` field).

| Tool | Check method | Type |
|------|-------------|------|
| Modal CLI | `$HOME/.modal.toml` exists | File presence |
| Datadog CLI | `pup auth status` output content | Command output |
| Vercel CLI | `vercel whoami` exit code | Command exit code |

See `@reference/script-standards-detail.md` for code patterns.

### Build prerequisite validation

Setup scripts that compile from source (`cargo install`, `pip install` with C extensions,
`go install` with cgo) MUST use the two-layer prerequisite framework:

**Layer 1 (preventive):** Call `Check-BuildPrereqs` / `check_build_prereqs` before the build.
If any prerequisites are missing, one `write_error` (the missing prerequisites as the reason),
one `write_summary ACTION` per install command, and skip the build.
Don't waste minutes on a doomed compilation.

**Layer 2 (diagnostic):** If the build fails, `write_error` with `error_reason` /
`Get-AitErrorReason` over the captured output: it tries the known signatures first
(`diagnose_build_failure` / `Diagnose-BuildFailure`) and returns `<NAME>: <REMEDY>`, else the
output's error line (`@reference/logging.md` 8.3). When a signature matches, also write its
remedy as an ACTION.

Both layers use centralized data tables in `aitools-lib.ps1`/`.sh`. Adding a new prerequisite
or failure signature = one entry in the table. See `@reference/script-standards-detail.md` for
the process.

Install fields in `BuildPrereqs` entries must reference methods derived from official
tool documentation. See `@shared/rules/tool-lifecycle.md` Install method discovery.

### KnownPaths empirical verification

All `KnownPaths` entries in `$script:BuildPrereqs`, `ensure_tool_on_path` calls,
and any other hardcoded install-path arrays MUST be empirically verified on the
actual platform before shipping. This applies to:

- **Directly managed tools** from the tool registry (`/tool-registry` skill)
- **Build dependencies** discovered during installation (NASM, CMake, etc.)
- **Any tool** where we specify filesystem paths for fallback detection

Verification process:

1. **Install the tool** via the documented method (winget, brew, etc.)
2. **Record the actual path** on disk -- do not guess from installer type
3. **Document verification** in code: `# Verified: YYYY-MM-DD (vX.Y.Z)`
4. **Unverified paths** must be marked `# UNVERIFIED` in code and docs

Guessing paths from installer type (e.g., "Nullsoft installs to Program Files")
is a process violation (#22). Check scripts (`check-prereq-detection`) enforce
this via empirical path matching and verification status audit.

### Error handling requirements

These apply to ALL reusable scripts in the repo, not just setup scripts.

Every error-suppression pattern must have an immediate result check that logs or fails:

| Pattern | Requirement |
|---------|-------------|
| `-ErrorAction SilentlyContinue` | Null/empty check within 3 lines |
| `2>/dev/null` | Comment explaining why + result check |
| `\|\| true` | Comment explaining why + result check |
| `try/catch` with empty catch | Catch must log or re-throw; empty `catch {}` is never acceptable |

**Acceptable exception:** Command-existence checks (`Get-Command`, `command -v`, `which`)
with an explicit fallback (e.g., if-else branch, default value assignment). These are
inherently expected to fail and the fallback IS the error handling.

**Anti-pattern:** Suppressed errors feeding into counts, loops, or conditional logic with
no null guard. This produces false passes or silently skips work.

**Missing error handling:** Critical operations (file reads that feed into output, config
parsing, template rendering) must have explicit error handling even when no suppression
pattern is present. Validate content is non-null/non-empty before writing to disk.

### Exemptions

Any script that intentionally suppresses errors without a result check must:
1. Document the exemption in its header comment with a reason
2. Be listed in `@reference/script-standards-detail.md` exemptions table (requires the commander's approval to modify)

### When analyzing code

1. **If a feature is a no-op due to a missing config key, say so at the top of any summary
   or plan** -- not buried in a table row. Use "FEATURE X IS CURRENTLY INACTIVE" framing.
2. **Do not describe a feature as "working" if it has never fired in production.** Distinguish
   "code is correct" from "feature is operational."
3. **Name the exact fix command** -- e.g., "run `aitools user init` to write userRepoPath" --
   not just "needs configuration."

Details: `@reference/script-standards-detail.md`
