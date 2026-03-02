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
3. Logging block: `LOG_DIR`, `LOG_FILE`, `SCRIPT_NAME`, `mkdir -p`, `display_path()`, `ERRORS=0`, logging helpers
4. OS guard (`case "$(uname -s)" in MINGW*...) exit 1`)
5. Script body
6. Exit footer (check `$ERRORS`, exit 1 on failure)

### Block order (PowerShell reusable scripts)

1. Header comment (name, purpose, "safe to re-run", platform, reference to `tool-registry.md`)
2. Logging block: `$logDir`, `$logFile`, `$scriptName`, dir creation, `Log`/`LogOk`/`LogError`/`LogWarn`, `$errors = 0`
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

### Exit footer

Every setup script must end with an exit footer that checks the error counter.
See `@reference/script-standards-detail.md` for exact code patterns.

### End-of-run summary

Every setup script MUST call `write_summary` to contribute to the end-of-run panel:

- `write_summary OK "tool    version"` — tool verified installed / config deployed
- `write_summary WARN "message"` — non-fatal issue, PATH warning, migration
- `write_summary ACTION "command -- description"` — required user action post-install

For ACTION items: always pair with a `log_warn` carrying the same text.
When `AITOOLS_SUMMARY_FILE` is not set (standalone run), `write_summary` is a no-op.

See `@reference/script-standards-detail.md` for code patterns.

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
