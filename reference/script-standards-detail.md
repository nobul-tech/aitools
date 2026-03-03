# Script Standards -- Detail Reference

Comprehensive reference for `.claude/rules/script-standards.md`.
Defines exact specifications, code patterns, and exemptions.

## Exit footer

Every reusable script ends with an exit footer that checks the error counter.

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

## End-of-run summary

### Function definition

The `write_summary` function appends a pipe-delimited line to `$AITOOLS_SUMMARY_FILE`.
When the env var is unset (standalone run), the function is a silent no-op.

**Bash** (3-arg):

```bash
write_summary() {
    [ -n "${AITOOLS_SUMMARY_FILE:-}" ] && printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
}
```

**PowerShell** (3-arg):

```powershell
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) { Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${tool}|${detail}" }
}
```

### Summary file format

Each line: `CATEGORY|tool_name|detail_text`

- Field 1: `OK`, `WARN`, `ERROR`, or `ACTION`
- Field 2: Tool name (lowercase, consistent -- see tool name table below)
- Field 3: Detail text (version, status, error description, or action instruction)

The renderer reads this file and displays columns: `[tag]  tool_name  detail_text`,
left-aligned, grouped by severity (OK first, then WARN, ERROR, ACTION last).

### Tool name table

These are the canonical tool names for field 2. Always use these exact strings.

| Tool name | Script(s) |
|-----------|-----------|
| `vercel cli` | setup-vercelcli |
| `modal cli` | setup-modal |
| `gh cli` | setup-gh-cli |
| `node.js` | aitools-install |
| `claude code` | aitools-install |
| `rust/cargo` | setup-rust |
| `typst` | setup-typst |
| `pandoc` | setup-pandoc |
| `claude.md` | setup-user-claude |
| `claude rules` | setup-user-claude |
| `claude hooks` | setup-user-hooks |
| `claude mcp` | setup-user-mcp |
| `claude skills` | setup-user-mcp |
| `cursor rules` | setup-user-cursor |
| `cursor skills` | setup-user-mcp |
| `cursor ide mcp` | setup-cursor-ide-mcp |

### Severity categories

| Category | Tag | Color | Meaning | When to use |
|----------|-----|-------|---------|-------------|
| `OK` | `[ok]` | Green (`\033[32m`) | Tool installed and usable | Tool verified on PATH at expected version |
| `WARN` | `[!]` | Yellow (`\033[33m`) | Advisory -- tool works but something is off | Upgrade check failed, optional dependency missing, restart suggested |
| `ERROR` | `[ERR]` | Red (`\033[31m`) | Functional failure -- tool not usable | Install failed, not on PATH, dependency conflict, validation failed |
| `ACTION` | `>>` | Bold magenta (`\033[1;35m`) | User must do something before tool is ready | Auth required, PATH needs manual fix, manual install needed |

**Key distinction**: WARN means the tool itself works; ERROR means it doesn't.
A tool that installed but isn't on persistent PATH is ERROR (Claude Code can't find it).
A tool where `brew upgrade` returned unexpected output but the existing version works is WARN.

### Severity decision guide

- `log_ok` + `write_summary OK` -- tool verified present and functional
- `log_warn` + `write_summary WARN` -- tool works but with a caveat (disclose the caveat)
- `log_error` + `write_summary ERROR` -- tool not functional (install failed, not on PATH, dependency broken)
- `log_warn` + `write_summary ACTION` -- user action required; always pair ACTION with a log_warn carrying the same instruction

### Summary coverage rule

Every code path through a setup script -- success, partial failure, and full failure --
must produce at least one `write_summary` call. A tool that fails to install must appear
in the end-of-run panel as ERROR or WARN, not be silently absent.

### ACTION items

ACTION entries appear in a separate block at the bottom of the summary panel with the
header "ACTION REQUIRED -- run before tools are ready:". The tool field is empty for
ACTION entries (field 2 = ""). Always pair with a `log_warn` carrying the same text.

```bash
write_summary ACTION "" "modal setup -- authenticate modal (browser flow)"
```

```powershell
Write-Summary "ACTION" "" "modal setup -- authenticate modal (browser flow)"
```

## External command error handling

Setup scripts invoke external package managers (pip, npm, winget, brew, cargo, apt-get,
curl). These commands can fail silently if output and exit codes are not checked.

### Standard 1: Capture output from install/upgrade commands

Never fire-and-forget an install command. Capture output, log it, then check the result.

**Bash:**

```bash
INSTALL_OUTPUT=$(brew install tool 2>&1) || true
printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do log "$line"; done
```

**PowerShell:**

```powershell
$installOutput = winget install --id Some.Tool 2>&1 | Out-String
$installOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
```

### Standard 2: Check exit codes after external commands

**Bash** -- `set -euo pipefail` kills the script on failure before `write_summary` runs.
Wrap install commands to catch failure without hard-aborting:

```bash
if ! brew install tool 2>&1 | while IFS= read -r line; do log "$line"; done; then
    log_error "brew install tool failed"
    write_summary ERROR "tool" "install failed"
fi
```

**PowerShell** -- external command failures set `$LASTEXITCODE` but don't stop execution.
Always check after piping through `Out-String` or `ForEach-Object`:

```powershell
if ($LASTEXITCODE -ne 0) {
    LogError "install failed (exit code $LASTEXITCODE)"
    Write-Summary "ERROR" "tool" "install failed (exit $LASTEXITCODE)"
}
```

### Standard 3: Distinguish "already up to date" from real failures

`brew upgrade` exits non-zero for both "already up to date" and real errors.
Capture output and check the message:

```bash
UPGRADE_OUTPUT=$(brew upgrade tool 2>&1) || true
if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date'; then
    log_ok "tool already up to date"
    write_summary OK "tool" "$version"
else
    printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
    if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
        log_warn "brew upgrade returned unexpected output"
        write_summary WARN "tool" "$version (upgrade check failed)"
    fi
fi
```

### Standard 4: PATH verification is an error, not a warning

If a tool installs but isn't in persistent PATH, Claude Code (which reads PATH from
the registry/shell profile) will never find it. This is a functional failure.

```powershell
LogError "tool install dir not in persistent PATH: $dir"
Write-Summary "ERROR" "tool" "installed but not on PATH"
LogWarn "Add $dir to PATH -- tool not accessible to Claude Code"
Write-Summary "ACTION" "" "Add $dir to PATH -- tool not accessible"
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
}
```

**Wrong** -- `|| log_ok` catches all failures:

```bash
brew upgrade tool 2>/dev/null || log_ok "already up to date"
```

**Correct** -- output captured, message inspected:

```bash
UPGRADE_OUTPUT=$(brew upgrade tool 2>&1) || true
# ... inspect $UPGRADE_OUTPUT for "already installed" vs real error
```

**Wrong** -- install with no exit code check (PS1):

```powershell
& $pipCmd install modal
# execution continues even if pip failed
```

**Correct** -- output captured, exit code checked:

```powershell
$output = & $pipCmd install modal 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { LogError "pip install failed (exit $LASTEXITCODE)" }
```

**Wrong** -- `set -e` hard-abort with no summary:

```bash
brew install tool  # script dies here, no write_summary, tool vanishes from panel
```

**Correct** -- wrapped to catch failure:

```bash
if ! brew install tool 2>&1 | while IFS= read -r line; do log "$line"; done; then
    log_error "brew install tool failed"
    write_summary ERROR "tool" "install failed"
fi
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
