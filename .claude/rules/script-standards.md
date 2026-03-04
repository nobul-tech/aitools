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
3. `source aitools-lib.sh` + `logging_init "script-name"` (provides platform detection, display_path, read_config_key, log/log_ok/log_error/log_warn, write_summary, ERRORS counter)
4. OS guard (`case "$(uname -s)" in MINGW*...) exit 1`)
5. Script body
6. Exit footer (check `$ERRORS`, exit 1 on failure)

### Block order (PowerShell reusable scripts)

1. Header comment (name, purpose, "safe to re-run", platform, reference to `tool-registry.md`)
2. `. aitools-lib.ps1` + `Initialize-Logging "script-name"` (provides ReadConfigKey, Log/LogOk/LogError/LogWarn, Write-Summary, $errors counter)
3. OS guard (`if $PSVersionTable... -and -not $IsWindows`)
4. Script body
5. Exit footer (check `$errors`, exit 1 on failure)

### Error tracking requirement

- Bash: `log_error()` MUST increment `ERRORS` -- i.e., `ERRORS=$((ERRORS + 1))`
- PS1: `LogError` MUST increment `$script:errors` -- i.e., `$script:errors++`
- Missing error tracking is a bug. Scripts that only log errors without counting them silently exit 0 on failure.

### Required logging helpers

| Bash | PowerShell | Purpose |
|------|-----------|---------|
| `log` | `Log` | General info |
| `log_ok` | `LogOk` | Success |
| `log_error` | `LogError` | Error (must increment counter) |
| `log_warn` | `LogWarn` | Warning (non-fatal) |

All timestamps must be UTC with Z suffix (`date -u +%Y-%m-%dT%H:%M:%SZ` / `.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")`).

Logging framework is required -- raw `echo` or `Write-Host` without structured logging is not acceptable in reusable scripts.

All helpers are defined in `scripts/aitools-lib.sh` (bash) / `.ps1`. Scripts source the lib and call `logging_init` / `Initialize-Logging`. Entry points with specialized logging override the functions after sourcing. Do not define inline copies.

### Exit footer

Every setup script must end with an exit footer that checks the error counter.
See `@reference/script-standards-detail.md` for exact code patterns.

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

### External command error handling

External install/upgrade commands (pip, npm, winget, brew, cargo, apt-get) MUST:

1. **Capture output** -- never fire-and-forget an install command
2. **Check exit codes** -- `$LASTEXITCODE` (PS1) or wrap to prevent `set -e` abort (bash)
3. **Distinguish "up to date" from failure** -- inspect output messages, not just exit codes
4. **Treat PATH issues as errors** -- tool installed but not on PATH = functional failure

See `@reference/script-standards-detail.md` for platform-specific code patterns and
anti-patterns.

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
