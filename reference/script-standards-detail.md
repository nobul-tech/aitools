# Script Standards -- Detail Reference

Detailed examples, code patterns, and exemptions table for `.claude/rules/script-standards.md`.

## Exit footer code patterns

### Bash

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

### PowerShell

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

## End-of-run summary patterns

### Bash

```bash
write_summary() {
    local cat="$1" msg="$2"
    [ -n "${AITOOLS_SUMMARY_FILE:-}" ] && printf '%s|%s\n' "$cat" "$msg" >> "$AITOOLS_SUMMARY_FILE"
}
```

### PowerShell

```powershell
function Write-Summary($cat, $msg) {
    if ($env:AITOOLS_SUMMARY_FILE) { Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${msg}" }
}
```

Call at the point where the tool/config is verified present:

```bash
write_summary OK "pandoc    $(pandoc --version | head -1)"
write_summary WARN "MSVC Build Tools not detected -- cargo build will fail"
write_summary ACTION "modal setup -- authenticate modal (browser flow)"
```

## Anti-pattern examples

**Wrong** -- suppressed error feeds into loop with no guard:
```powershell
$files = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
foreach ($f in $files) { ... }  # silently iterates 0 items if $dir doesn't exist
```

**Correct** -- result checked immediately:
```powershell
$files = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
if (-not $files) {
    LogError "Cannot read directory: $dir"
    # or StepFail for check scripts
}
```

## Check/audit script requirements

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

## Post-write validation

Setup scripts that generate files from templates must validate CONTENT correctness,
not just structural markers. If a file is assembled from template + footer, validate
that the template portion is non-empty, not just that the footer exists.

## Exemptions table

Protected -- requires user approval to modify.

| Script | Line(s) | Pattern | Reason |
|--------|---------|---------|--------|
| `setup-vercelcli.sh` | 69 | `2>/dev/null \|\| true` | Cleanup: npm uninstall may fail if not installed; brew install follows |
| `setup-pandoc.sh` | 68, 73, 77 | `2>/dev/null \|\| true` | Cleanup: non-preferred package managers may not be installed |
| `setup-rust.sh` | 44 | `2>/dev/null \|\| log_warn` | Cleanup: brew formula may not be fully installed; warned on failure |
| `aitools-install.sh` | 273 | `2>/dev/null \|\| true` | Update: apt-get may need sudo; gh already works at current version |
| `check-lib.ps1` | 110 | `2>$null` (InvokeGit) | Git stderr triggers PS ErrorActionPreference=Stop; caller checks result |
| `check-lib.ps1` | 79-81 | `try/catch` (ReadConfigKey) | Config parse: catch logs warning; callers handle null return via ResolveConfig |
| `setup-typst.sh` | 38, 43 | `2>/dev/null \|\| true` | Cleanup: cargo/npm may not have typst installed; Homebrew install follows |
| `setup-typst.ps1` | 45, 53 | `2>$null` | Cleanup: cargo/npm stderr noise; non-blocking, winget install follows |

## Reference examples

When creating a new script, copy the logging block and exit footer from an existing
script that follows the conventions above. Do not assume existing scripts are
violation-free -- always verify the copied code against these rules.
