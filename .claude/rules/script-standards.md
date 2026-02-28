## Script Standards (this repo)

All plans you propose and all reusable code you write must follow these conventions.
A plan that drafts code with violations is itself a violation. This covers: setup scripts
(`scripts/setup-*.sh/.ps1`), check/audit scripts (`scripts/check-*.sh/.ps1`), installer
scripts (`scripts/aitools-install.*`, `scripts/aitools.*`), deploy scripts
(`deploy/*.sh/.ps1`), hooks (`shared/hooks/*.sh`), and shell aliases (`shared/shell/*`).

### Block order (bash setup scripts)

1. Shebang + header comment (name, purpose, "safe to re-run", platform, reference to `tool-install-sources.md`)
2. `set -euo pipefail`
3. Logging block: `LOG_DIR`, `LOG_FILE`, `SCRIPT_NAME`, `mkdir -p`, `display_path()`, `ERRORS=0`, logging helpers
4. OS guard (`case "$(uname -s)" in MINGW*...) exit 1`)
5. Script body
6. Exit footer (check `$ERRORS`, exit 1 on failure)

### Block order (PowerShell setup scripts)

1. Header comment (name, purpose, "safe to re-run", platform, reference to `tool-install-sources.md`)
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

### Exit footer

Every setup script must end with an exit footer that checks the error counter:

```bash
# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
```

```powershell
# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
```

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
no null guard. This produces false passes (counts as 0 instead of erroring) or silently
skips work.

Example -- **wrong:**
```powershell
$files = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
foreach ($f in $files) { ... }  # silently iterates 0 items if $dir doesn't exist
```

Example -- **correct:**
```powershell
$files = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
if (-not $files) {
    LogError "Cannot read directory: $dir"
    # or StepFail for check scripts
}
```

### Check/audit script requirements

Scripts following the `check-*.sh/.ps1` pattern have additional requirements:

- Step functions (`StepPass`/`StepFail`/`StepWarn`) must handle internal errors -- a step
  that fails to execute is NOT a pass
- `Get-ChildItem`/`Get-Content` failures must produce `StepFail` or `StepWarn`, never a
  silent skip that counts as a pass
- When a step queries a directory or file, test for existence before processing; on failure,
  report it as the step result
- `StepPass` must accept and display a `$Detail` parameter, same as
  `StepFail`/`StepWarn`/`StepSkip`. Callers passing detail context must have that
  context displayed.

### Post-write validation

Setup scripts that generate files from templates must validate CONTENT correctness,
not just structural markers. If a file is assembled from template + footer, validate
that the template portion is non-empty, not just that the footer exists.

### Exemptions

Any script that intentionally suppresses errors without a result check must:
1. Document the exemption in its header comment with a reason
2. Be listed in the table below (protected -- requires user approval to modify)

| Script | Line(s) | Pattern | Reason |
|--------|---------|---------|--------|
| `setup-vercelcli.sh` | 69 | `2>/dev/null \|\| true` | Cleanup: npm uninstall may fail if not installed; brew install follows |
| `setup-pandoc.sh` | 68, 73, 77 | `2>/dev/null \|\| true` | Cleanup: non-preferred package managers may not be installed |
| `setup-rust.sh` | 44 | `2>/dev/null \|\| log_warn` | Cleanup: brew formula may not be fully installed; warned on failure |
| `aitools-install.sh` | 273 | `2>/dev/null \|\| true` | Update: apt-get may need sudo; gh already works at current version |
| `check-lib.ps1` | 110 | `2>$null` (InvokeGit) | Git stderr triggers PS ErrorActionPreference=Stop; caller checks result |
| `check-lib.ps1` | 79-81 | `try/catch` (ReadConfigKey) | Config parse: catch logs warning; callers handle null return via ResolveConfig |

### Gold standard references

- Setup (bash): `scripts/setup-user-mcp.sh`
- Setup (PS1): `scripts/setup-user-mcp.ps1`
- Check (PS1): `scripts/check-pre-commit.ps1`

When creating a new script, copy the logging block and exit footer from the appropriate gold standard.
