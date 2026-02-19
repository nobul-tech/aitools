## Script Standards (this repo)

All setup scripts (`scripts/setup-*.sh` and `scripts/setup-*.ps1`) must follow these conventions.

### Block order (bash)

1. Shebang + header comment (name, purpose, "safe to re-run", platform, reference to `tool-install-sources.md`)
2. `set -euo pipefail`
3. Logging block: `LOG_DIR`, `LOG_FILE`, `SCRIPT_NAME`, `mkdir -p`, `display_path()`, `ERRORS=0`, logging helpers
4. OS guard (`case "$(uname -s)" in MINGW*...) exit 1`)
5. Script body
6. Exit footer (check `$ERRORS`, exit 1 on failure)

### Block order (PowerShell)

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

### Gold standard references

- Bash: `scripts/setup-user-mcp.sh`
- PS1: `scripts/setup-user-mcp.ps1`

When creating a new setup script, copy the logging block and exit footer from the gold standard.
