## Script Standards (this repo)

All plans you propose and all reusable code you write must follow these conventions.
A plan that drafts code with violations is itself a violation. This covers all reusable scripts including: setup scripts
(`scripts/setup-*.sh/.ps1`), check/audit scripts (`scripts/check-*.sh/.ps1`), installer
scripts (`scripts/aitools-install.*`, `scripts/aitools*`), deploy scripts
(`deploy/*.sh/.ps1`), hooks (`shared/hooks/*.sh`), shell aliases (`shared/shell/*`),
pseudocode in `plans/*.md`, and any code you propose in conversation.

### Block order (bash reusable scripts)

1. Shebang + header comment (name, purpose, "safe to re-run", platform, reference to `tool-registry.md`)
2. `set -euo pipefail`
3. `source aitools-lib.sh` + `logging_init "script-name"` (provides platform detection, display_path, read_config_key, log/log_ok/log_error/log_warn, write_summary, backup_file, backup_dir, emit_merge_details, ERRORS/WARNINGS counters)
4. OS guard (`case "$(uname -s)" in MINGW*...) exit 1`)
5. Script body
6. Exit footer (check `$ERRORS` + `$WARNINGS`, exit 1 on errors)

### Block order (PowerShell reusable scripts)

1. Header comment (name, purpose, "safe to re-run", platform, reference to `tool-registry.md`)
2. `. aitools-lib.ps1` + `Initialize-Logging "script-name"` (provides ReadConfigKey, Log/LogOk/LogError/LogWarn, Write-Summary, Backup-File, Backup-Dir, ConvertPSObjectToHashtable, Emit-MergeDetails, $errors/$warnings counters)
3. OS guard (`if $PSVersionTable... -and -not $IsWindows`)
4. Script body
5. Exit footer (check `$errors` + `$warnings`, exit 1 on errors)

### Error and warning tracking requirement

- Bash: `log_error()` MUST increment `ERRORS`; `log_warn()` MUST increment `WARNINGS`
- PS1: `LogError` MUST increment `$script:errors`; `LogWarn` MUST increment `$script:warnings`
- Missing tracking is a bug. Scripts that only log without counting silently misreport exit status.

### Log line format

Every log line must follow: `[timestamp] [script-name] [level] message`

Valid levels: `info`, `ok`, `warn`, `error`, `detail`

Console output uses ANSI colors: red for `[error]`, yellow for `[warn]`, plain for `[info]`/`[ok]`.
Log file output is plain text only (no ANSI codes).

### Required logging helpers

| Bash | PowerShell | Level | Purpose |
|------|-----------|-------|---------|
| `log` | `Log` | `info` | General info |
| `log_ok` | `LogOk` | `ok` | Success |
| `log_error` | `LogError` | `error` | Error (must increment ERRORS) |
| `log_warn` | `LogWarn` | `warn` | Warning (must increment WARNINGS) |
| `log_detail` | `LogDetail` | `detail` | Diagnostic content (file-only, no console) |

All timestamps must be UTC with Z suffix (`date -u +%Y-%m-%dT%H:%M:%SZ` / `.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")`).

Logging framework is required -- raw `echo` or `Write-Host` without structured logging is not acceptable in reusable scripts.

All helpers are defined in `scripts/aitools-lib.sh` (bash) / `.ps1`. Scripts source the lib and call `logging_init` / `Initialize-Logging`. Entry points with specialized logging override the functions after sourcing. Do not define inline copies.

### Agentic invocation logging

Every `invoke_ai` / `Invoke-AI` call must log structured telemetry to deploy.log:

| Event | Level | Format |
|-------|-------|--------|
| Invocation start | `info` | `AI: speed=TIER backend=CLI attempt=N` |
| Success | `info` | `AI: speed=TIER backend=CLI attempt=N result=accepted` |
| Validation failure | `warn` | `AI: speed=TIER backend=CLI attempt=N result=rejected reason=REASON` |
| Rejected output | `detail` | `ai-rejected: LINE` (per-line, file-only) |
| All retries exhausted | `warn` | `AI: speed=TIER backend=CLI exhausted after N attempts` |
| Backend unavailable | `error` | `AI: no CLI available (claude or agent)` |

This telemetry enables prompt iteration: read `[detail] ai-rejected:` lines
from deploy.log, identify the failure mode, update the prompt, re-test.

See `.claude/rules/agentic-standards.md` for prompt design and evaluation rules.

### Agentic invocation

See `.claude/rules/agentic-standards.md` for AI CLI invocation requirements,
prompt design standards, and evaluation lifecycle.

### Exit footer

Every setup script must end with an exit footer that checks both ERRORS and WARNINGS counters.
See `@reference/script-standards-detail.md` for exact code patterns.

### Cross-platform grep portability

Never use `grep -P` (Perl regex) in bash scripts -- macOS BSD `grep` doesn't support it.
Use `perl -ne` for Perl regex, `grep -E` for extended regex, or `grep -F` for literals.
See `@reference/script-standards-detail.md` for the full portability table.

### Standalone build logging

`build-deploy.sh` defines its own `blog`/`blog_ok`/`blog_error` (doesn't source aitools-lib.sh).
These must also follow the `[timestamp] [script] [level] message` format.
Documented as a logging override exception in `reference/script-standards-detail.md`.

### Check script logging

Check/audit scripts (`check-*.sh/.ps1`) use a separate logging system from setup
scripts. Check scripts source `check-lib` (which sources `aitools-lib`) and call
`CheckLogInit`/`check_log_init` — NOT `Initialize-Logging`/`logging_init`.

- **Step functions**: `StepPass`/`step_pass`, `StepFail`/`step_fail`, etc.
- **Destinations**: `checks.log` + `checks.jsonl` (not `deploy.log`)
- **Semantics**: PASS/FAIL/WARN/SKIP (not OK/WARN/ERROR)

`CheckLogInit`/`check_log_init` bridges the gap by also setting aitools-lib
logging variables, so lib functions called from check steps can write to
`deploy.log`. See `reference/script-standards-detail.md` for details.

### End-of-run summary

Every setup script MUST call `write_summary` / `Write-Summary` (3-arg, from `aitools-lib`) to contribute to the end-of-run panel:

```bash
write_summary OK    "tool_name" "version or status"
write_summary WARN  "tool_name" "advisory message"
write_summary ERROR "tool_name" "failure description"
write_summary ACTION ""         "instruction for user"
```

```powershell
Write-Summary "OK"     "tool_name" "version or status"
Write-Summary "WARN"   "tool_name" "advisory message"
Write-Summary "ERROR"  "tool_name" "failure description"
Write-Summary "ACTION" ""          "instruction for user"
```

| Category | Meaning |
|----------|---------|
| OK | Tool installed and usable |
| WARN | Advisory -- tool works but something is off |
| ERROR | Functional failure -- tool not usable |
| ACTION | User must act before tool is ready |

Every code path (success AND failure) must call `write_summary`. A tool that fails
must appear as ERROR, not be silently absent.

See `@reference/script-standards-detail.md` for severity definitions, renderer colors,
tool name table, function signatures, and platform-specific patterns.

### Config and file update reporting

Setup scripts that write config files, .md files, hooks, or skills must follow the
three-outcome pattern (unchanged/updated/failed) with file-type-specific change logging.
Summary detail text is max 30 chars. JSON configs log changed keys and emit DETAIL
summary lines; text files log diffs to deploy.log.
See `@reference/script-standards-detail.md` for patterns and examples.

### External command error handling

External install/upgrade commands (pip, npm, winget, brew, cargo, apt-get) MUST:

1. **Capture output** -- never fire-and-forget an install command
2. **Check exit codes** -- `$LASTEXITCODE` (PS1) or wrap to prevent `set -e` abort (bash)
3. **Distinguish "up to date" from failure** -- inspect output messages, not just exit codes
4. **Treat PATH issues as errors** -- tool installed but not on PATH = functional failure

See `@reference/script-standards-detail.md` for platform-specific code patterns and
anti-patterns.

### Post-install authentication check

Setup scripts for tools requiring authentication MUST check auth status on every run —
not just fresh installs. After successful install/upgrade:

1. Check auth using the tool's own command or config file presence
2. Not authenticated: `log_warn` + `write_summary WARN` + `write_summary ACTION`
3. Authenticated: no extra output (silent success)

Auth check commands are documented per-tool in `reference/tool-registry.md` (Authentication section).

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
If any prerequisites are missing, `log_error` + `write_summary ERROR/ACTION` and skip the build.
Don't waste minutes on a doomed compilation.

**Layer 2 (diagnostic):** If the build fails, call `Diagnose-BuildFailure` /
`diagnose_build_failure` on the captured output. If a known signature matches, surface the
specific remedy. If no signature matches, log the generic failure.

Both layers use centralized data tables in `aitools-lib.ps1`/`.sh`. Adding a new prerequisite
or failure signature = one entry in the table. See `reference/script-standards-detail.md` for
the process.

Install fields in `BuildPrereqs` entries must reference methods derived from official
tool documentation. See `.claude/rules/tool-lifecycle.md` Install method discovery.

### KnownPaths empirical verification

All `KnownPaths` entries in `$script:BuildPrereqs`, `ensure_tool_on_path` calls,
and any other hardcoded install-path arrays MUST be empirically verified on the
actual platform before shipping. This applies to:

- **Directly managed tools** from `reference/tool-registry.md`
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
2. Be listed in `@reference/script-standards-detail.md` exemptions table (protected -- requires user approval to modify)

### When analyzing code

1. **If a feature is a no-op due to a missing config key, say so at the top of any summary
   or plan** -- not buried in a table row. Use "FEATURE X IS CURRENTLY INACTIVE" framing.
2. **Do not describe a feature as "working" if it has never fired in production.** Distinguish
   "code is correct" from "feature is operational."
3. **Name the exact fix command** -- e.g., "run `aitools user init` to write userRepoPath" --
   not just "needs configuration."

Details: `@reference/script-standards-detail.md`
