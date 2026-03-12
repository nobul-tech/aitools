# Script Standards -- Detail Reference

Comprehensive reference for `.claude/rules/script-standards.md`.
Defines exact specifications, code patterns, and exemptions.

## Log line format

Every log line must follow this format:

```
[timestamp] [script-name] [level] message
```

- **Timestamp**: UTC with Z suffix -- `date -u +%Y-%m-%dT%H:%M:%SZ` (bash) / `.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")` (PS1)
- **Script name**: set by `logging_init` / `Initialize-Logging`
- **Level**: one of `info`, `ok`, `warn`, `error`

### Console colors

| Level | Bash ANSI | PS1 `-ForegroundColor` |
|-------|-----------|----------------------|
| `error` | `\033[31m` (red) | `Red` |
| `warn` | `\033[33m` (yellow) | `Yellow` |
| `info` | (none) | (none) |
| `ok` | (none) | (none) |

### Log file

Log file output is plain text only -- no ANSI escape codes. The `log()` function writes
plain text to `$LOG_FILE` and colored text to the console separately.

## Exit footer

Every reusable script ends with an exit footer that checks both error and warning counters.

### Bash

```bash
# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
```

### PowerShell

```powershell
# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
```

## Shared library (`scripts/aitools-lib.sh` / `.ps1`)

Single source of truth for common helpers. Sourced by all scripts at dev time.
`build-deploy.sh` inlines the content into deploy/ scripts for self-containment.
Check scripts source `check-lib.sh`/`.ps1` which in turn sources `aitools-lib.sh`/`.ps1`.

### Contents

| Function | Bash | PowerShell | Purpose |
|----------|------|-----------|---------|
| Platform detection | `IS_MACOS`, `IS_WINDOWS` | (built-in) | OS branching |
| Log directory | `AITOOLS_LOG_DIR` | via `Initialize-Logging` | Platform-aware log path |
| `display_path` | `display_path()` | (not needed) | cygpath wrapper for Windows |
| Config reader | `read_config_key()` | `ReadConfigKey` | JSON key extraction (BOM-safe) |
| Module-level counters | `ERRORS=0`, `WARNINGS=0` | n/a (set in `Initialize-Logging`) | Safe defaults for scripts that source without `logging_init` |
| Logging init | `logging_init "name"` | `Initialize-Logging "name"` | Sets SCRIPT_NAME, LOG_DIR, LOG_FILE; resets ERRORS, WARNINGS |
| Standard logging | `log`/`log_ok`/`log_error`/`log_warn` | `Log`/`LogOk`/`LogError`/`LogWarn` | `[ts] [script] [level] msg` with console colors |
| Detail logging | `log_detail()` | `LogDetail` | File-only diagnostic logging (no console output) |
| Summary writer | `write_summary` | `Write-Summary` | 3-arg append to summary file |
| Summary renderer | `show_summary` | `Show-Summary` | Colored panel display |
| File backup | `backup_file()` | `Backup-File` | Timestamped backup with pruning |
| Dir backup | `backup_dir()` | `Backup-Dir` | Directory backup for managed files |
| JSON hashtable | n/a | `ConvertPSObjectToHashtable` | PSCustomObject to Hashtable (recursive, array-aware) |
| DETAIL emitter | `emit_merge_details()` | `Emit-MergeDetails` | Parse CHANGED: lines / emit DETAIL summary entries |
| JSON normalization | `SORT_KEYS_JS`, `normalize_json()` | `Normalize-JsonForComparison`, `ConvertTo-CanonicalObject` | Sorted-key JSON for deterministic comparison |
| Check logging init | `check_log_init()` | `CheckLogInit` | Sets check log paths + bridges aitools-lib logging vars |
| Check step functions | `step_pass`/`step_fail`/`step_warn`/`step_skip` | `StepPass`/`StepFail`/`StepWarn`/`StepSkip` | `[PASS]`/`[FAIL]`/`[WARN]`/`[SKIP]` with console colors |

### Usage

**Setup scripts** (standard):

Bash:
```bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-toolname"
```

PowerShell:
```powershell
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-toolname"
```

**Entry points** (override logging after sourcing):

Bash:
```bash
source "$repo_path/scripts/aitools-lib.sh"
logging_init "aitools"
# Override: file-only logging, errors/warns to stderr
log() {
    local level="${2:-info}"
    printf '[%s] [%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$level" "$1" >> "$LOG_FILE"
}
log_error() { log "$1" "error"; printf 'error: %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "$1" "warn"; printf 'warning: %s\n' "$1" >&2; WARNINGS=$((WARNINGS + 1)); }
```

PowerShell:
```powershell
. (Join-Path $repoPath "scripts" "aitools-lib.ps1")
Initialize-Logging "aitools"
# Override: file-only logging, errors/warns to stderr
function Log($msg, $level = "info") {
    Add-Content -Path $logFile -Value "[$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))] [aitools] [$level] $msg"
}
function LogError($msg) { Log $msg "error"; Write-Host "error: $msg" -ForegroundColor Red; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; Write-Host "warning: $msg" -ForegroundColor Yellow; $script:warnings++ }
```

### Logging overrides

Entry points override the lib's default logging functions after sourcing.
Setup scripts and check scripts use the defaults -- no overrides.

| Script | Bash overrides | PS1 overrides | Reason |
|--------|---------------|---------------|--------|
| `scripts/aitools` | `log`, `log_error`, `log_warn` | `Log`, `LogError`, `LogWarn` | File-only logging (no tee to stdout); errors/warns to stderr |
| `scripts/aitools-install` | `log`, `log_ok`, `log_error`, `log_warn` | `Log`, `LogOk`, `LogError`, `LogWarn` | JSONL dual-format (human-readable + structured JSON) |
| `scripts/build-deploy.sh` | `blog`, `blog_ok`, `blog_error` | n/a | Standalone build tool; doesn't source aitools-lib.sh; defines own logging functions |

**`log_detail` / `LogDetail`**: File-only logging for diagnostic content (rejected merge
output, verbose debugging). Not included in override tables -- entry points that override
`log`/`Log` do not need to override `log_detail`/`LogDetail` because it always writes
directly to `$LOG_FILE`/`$logFile` regardless of console routing.

## End-of-run summary

### Function definition

The canonical `write_summary` / `Write-Summary` definition lives in
`scripts/aitools-lib.sh` / `.ps1`. All scripts source the lib -- no inline copies.

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
| `python` | setup-python |
| `uv` | setup-uv |
| `go` | setup-go |
| `datadog cli` | setup-datadog |
| `cursor cli` | setup-user-cursor |

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

## Config and file update reporting

### Three outcomes

Every file write in a setup script must distinguish one of three outcomes:

| Outcome | Log level | Log message | Summary detail (max 30 chars) |
|---------|-----------|-------------|-------------------------------|
| **Unchanged** | `log_ok` / `LogOk` | `"Unchanged: <filepath>"` | `"unchanged"` |
| **Updated** | `log_ok` / `LogOk` | `"Updated: <filepath>"` + change detail | Concise description |
| **Failed** | `log_error` / `LogError` | `"Failed: <filepath>: <reason>"` | `"<failure reason>"` |

### Change detail by file type

| File type | Log detail | Summary detail example |
|-----------|-----------|----------------------|
| **Text files** (.md, .mdc, SKILL.md) | Unified diff to `$LOG_FILE` / `$logFile` | `"updated"`, `"2 added, 1 updated"` |
| **JSON config** | Log each changed key: `"  key: old -> new"` | `"effortLevel: high"` or `"3 keys updated"` |
| **Hook scripts** | Unified diff to `$LOG_FILE` / `$logFile` | `"hook updated"` or `"2 hooks updated"` |

### Summary detail text rules

- Max 30 characters (compliance-checked)
- No file paths (those go in log lines)
- Present tense: "updated", "unchanged", "failed", "created"
- Multi-item tools: counts (`"2 added, 1 updated"`)
- JSON configs: 0 keys changed -> `"unchanged"` / 1 key -> key + short value / 2-3 -> comma-joined names / 4+ -> `"N keys updated"`

### DETAIL lines in summary panel

When a config update changes keys, scripts write `DETAIL` entries after the main entry.
These render left-aligned with the detail column (position 25).

**Summary file format** -- new `DETAIL` category:

```
OK|claude hooks|3 keys updated
DETAIL|claude hooks|effortLevel: medium -> high
DETAIL|claude hooks|autoMemoryEnabled: false -> true
DETAIL|claude hooks|hooks: updated
```

**Rendered output:**

```
────────────────────────────────────────────────────────
  [ok]  claude hooks      3 keys updated
                          effortLevel: medium -> high
                          autoMemoryEnabled: false -> true
                          hooks: updated
  [ok]  claude.md         updated
  [ok]  claude rules      unchanged
────────────────────────────────────────────────────────
```

DETAIL lines:
- Follow their parent entry (same tool name)
- Left-aligned at position 25 (2 + tag(4) + 2 + tool(16) + 1)
- Inherit parent's color
- Never deduped, always shown
- Optional -- only emitted when there are specific changes to report

**write_summary / Write-Summary** -- no API change. DETAIL is a new category value:

Bash:
```bash
write_summary DETAIL "claude hooks" "effortLevel: medium -> high"
```

PowerShell:
```powershell
Write-Summary "DETAIL" "claude hooks" "effortLevel: medium -> high"
```

### Canonical patterns by file type

**Text files (.md, .mdc, SKILL.md):**

Bash:
```bash
if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    log_ok "Created: $(display_path "$dest")"
elif diff -q "$src" "$dest" >/dev/null 2>&1; then
    log_ok "Unchanged: $(display_path "$dest")"
else
    diff -u "$dest" "$src" \
        --label "deployed/$(basename "$dest")" --label "source/$(basename "$src")" \
        >> "$LOG_FILE" 2>&1 || true
    cp "$src" "$dest"
    log_ok "Updated: $(display_path "$dest")"
fi
```

PowerShell:
```powershell
if (-not (Test-Path $dest)) {
    Copy-Item -Path $src -Destination $dest -Force
    LogOk "Created: $dest"
} else {
    $srcContent = Get-Content $src -Raw -ErrorAction Stop
    $dstContent = Get-Content $dest -Raw -ErrorAction Stop
    if ($srcContent -eq $dstContent) {
        LogOk "Unchanged: $dest"
    } else {
        $srcLines = Get-Content $src -ErrorAction Stop
        $dstLines = Get-Content $dest -ErrorAction Stop
        $diffOutput = Compare-Object $dstLines $srcLines -PassThru | Out-String
        Add-Content -Path $logFile -Value "--- deployed/$(Split-Path $dest -Leaf)"
        Add-Content -Path $logFile -Value "+++ source/$(Split-Path $src -Leaf)"
        Add-Content -Path $logFile -Value $diffOutput
        Copy-Item -Path $src -Destination $dest -Force
        LogOk "Updated: $dest"
    }
}
```

**JSON config -- node.js merge blocks (used by .sh and .ps1 wrappers):**

```javascript
// sortKeys() from SORT_KEYS_JS (embedded via $SORT_KEYS_JS in node -e blocks)
// Ensures deterministic key ordering for comparison across runs.

// Before merge: snapshot managed keys (sorted for comparison)
const before = {};
for (const key of managedKeys) before[key] = JSON.stringify(sortKeys(settings[key]));
// ... merge logic ...
// After merge: detect changes (sorted for comparison)
const changed = [];
for (const key of managedKeys) {
    const oldVal = before[key];
    const newVal = JSON.stringify(sortKeys(settings[key]));
    if (oldVal !== newVal) changed.push(key + ': ' + (oldVal || '(unset)') + ' -> ' + newVal);
}
if (changed.length) {
    for (const c of changed) console.error('CHANGED:' + c);
    console.log('ok');
} else {
    console.log('unchanged');
}
```

Shell wrapper reads `CHANGED:` lines and writes DETAIL entries:

Bash:
```bash
MERGE_OUTPUT=$(node -e "..." "$@" 2>&1)
MERGE_RESULT=$(echo "$MERGE_OUTPUT" | tail -1)
CHANGED_KEYS=$(echo "$MERGE_OUTPUT" | perl -ne 'print "$1\n" if /^CHANGED:(.+)/')
# After write_summary OK:
if [ -n "$CHANGED_KEYS" ]; then
    while IFS= read -r key_change; do
        log "  $key_change"
        write_summary DETAIL "tool_name" "$key_change"
    done <<< "$CHANGED_KEYS"
fi
```

PowerShell:
```powershell
foreach ($change in $changedKeys) {
    Log "  $change"
    Write-Summary "DETAIL" "tool_name" "$change"
}
```

**Hook scripts:**

Bash:
```bash
if [ -f "$hook_dst" ] && diff -q "$hook_src" "$hook_dst" >/dev/null 2>&1; then
    log_ok "Unchanged: $hook_name"
else
    if [ -f "$hook_dst" ]; then
        diff -u "$hook_dst" "$hook_src" \
            --label "deployed/$hook_name" --label "source/$hook_name" \
            >> "$LOG_FILE" 2>&1 || true
    fi
    cp "$hook_src" "$hook_dst"
    chmod +x "$hook_dst"
    log_ok "Updated: $hook_name"
fi
```

PowerShell:
```powershell
$srcContent = Get-Content $src -Raw -ErrorAction Stop
$dstContent = if (Test-Path $dst) { Get-Content $dst -Raw -ErrorAction Stop } else { $null }
if ($srcContent -eq $dstContent) {
    LogOk "Unchanged: $hookName"
} else {
    if ($dstContent) {
        $srcLines = Get-Content $src -ErrorAction Stop
        $dstLines = Get-Content $dst -ErrorAction Stop
        $diffOutput = Compare-Object $dstLines $srcLines -PassThru | Out-String
        Add-Content -Path $logFile -Value "--- deployed/$hookName"
        Add-Content -Path $logFile -Value "+++ source/$hookName"
        Add-Content -Path $logFile -Value $diffOutput
    }
    Copy-Item -Path $src -Destination $dst -Force
    LogOk "Updated: $hookName"
}
```

### Logging-summary pairing rule

Every `log_error` / `LogError` for a file write failure MUST be paired with
`write_summary ERROR` / `Write-Summary "ERROR"` in the same code block.

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

## Python package install pattern (uv-first)

When installing Python packages, check for `uv` first, fall back to `pip`. This provides
faster installs when uv is available while maintaining compatibility.

### Bash

```bash
# Determine install command: uv (preferred) > pip3 > pip
INSTALL_CMD=""
INSTALL_FLAGS=""
if command -v uv >/dev/null 2>&1; then
    INSTALL_CMD="uv pip"
    INSTALL_FLAGS="--system"
    log "Using uv for package install"
elif command -v pip3 >/dev/null 2>&1; then
    INSTALL_CMD="pip3"
    log "Using pip3 for package install (uv not found)"
elif command -v pip >/dev/null 2>&1; then
    INSTALL_CMD="pip"
    log "Using pip for package install (uv not found)"
else
    log_error "No Python package installer found. Install uv or pip first."
fi

# Usage: $INSTALL_CMD install $INSTALL_FLAGS <package>
# --system is required for uv (installs into system Python, not a virtualenv)
```

### PowerShell

```powershell
# Determine install command: uv (preferred) > pip > pip3
$installCmd = $null
$installArgs = @()
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $installCmd = "uv"
    $installArgs = @("pip")
    $installFlags = @("--system")
    Log "Using uv for package install"
} elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    $installCmd = "pip"
    $installArgs = @()
    $installFlags = @()
    Log "Using pip for package install (uv not found)"
} elseif (Get-Command pip3 -ErrorAction SilentlyContinue) {
    $installCmd = "pip3"
    $installArgs = @()
    $installFlags = @()
    Log "Using pip3 for package install (uv not found)"
} else {
    LogError "No Python package installer found. Install uv or pip first."
}

# Usage: & $installCmd @installArgs install @installFlags <package>
# --system is required for uv (installs into system Python, not a virtualenv)
```

## Post-install authentication check

Setup scripts for tools requiring authentication must check auth status on every run,
not just fresh installs. This surfaces the ACTION line whenever auth is missing —
including after reinstalls, credential expiry, or machine migrations.

### Pattern: command exit code

Use when the tool's status command returns non-zero when not authenticated (e.g., `vercel whoami`).

**Bash:**

```bash
# --- Auth status check ---
if command -v toolname >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    AUTH_EC=0
    AUTH_OUTPUT=$(toolname auth status 2>&1) || AUTH_EC=$?
    if [ "$AUTH_EC" -ne 0 ]; then
        log_warn "Not authenticated: run 'toolname auth login' (one-time OAuth)"
        write_summary WARN "tool name" "not authenticated"
        write_summary ACTION "" "toolname auth login -- authenticate tool"
    fi
fi
```

**PowerShell:**

```powershell
# --- Auth status check ---
# Get-Command exempt: command-existence check with explicit fallback
if ((Get-Command toolname -ErrorAction SilentlyContinue) -and $errors -eq 0) {
    $authOutput = toolname auth status 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        LogWarn "Not authenticated: run 'toolname auth login' (one-time OAuth)"
        Write-Summary "WARN" "tool name" "not authenticated"
        Write-Summary "ACTION" "" "toolname auth login -- authenticate tool"
    }
}
```

### Pattern: command output content

Use when the tool's status command always exits 0 and reports auth state in output
(e.g., `pup auth status` prints `Not authenticated` or `"authenticated": false`).

**Bash:**

```bash
# --- Auth status check ---
# toolname auth status exits 0 regardless; check output content for auth state
if command -v toolname >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    AUTH_OUTPUT=$(toolname auth status 2>&1) || true
    if printf '%s\n' "$AUTH_OUTPUT" | grep -qi 'not authenticated'; then
        log_warn "Not authenticated: run 'toolname auth login' (one-time OAuth)"
        write_summary WARN "tool name" "not authenticated"
        write_summary ACTION "" "toolname auth login -- authenticate tool"
    fi
fi
```

**PowerShell:**

```powershell
# --- Auth status check ---
# toolname auth status exits 0 regardless; check output content for auth state
# Get-Command exempt: command-existence check with explicit fallback
if ((Get-Command toolname -ErrorAction SilentlyContinue) -and $errors -eq 0) {
    $authOutput = toolname auth status 2>&1 | Out-String
    if ($authOutput -match 'Not authenticated|"authenticated":\s*false') {
        LogWarn "Not authenticated: run 'toolname auth login' (one-time OAuth)"
        Write-Summary "WARN" "tool name" "not authenticated"
        Write-Summary "ACTION" "" "toolname auth login -- authenticate tool"
    }
}
```

### Pattern: config file presence

Use when the tool stores auth in a known file (e.g., `~/.modal.toml`) and has no status command.

**Bash:**

```bash
# --- Auth status check ---
if command -v toolname >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    if [ ! -f "$HOME/.toolname.toml" ]; then
        log_warn "Authentication required: run 'toolname setup' (browser flow)"
        write_summary WARN "tool name" "not authenticated"
        write_summary ACTION "" "toolname setup -- authenticate tool"
    fi
fi
```

**PowerShell:**

```powershell
# --- Auth status check ---
# Get-Command exempt: command-existence check with explicit fallback
if ((Get-Command toolname -ErrorAction SilentlyContinue) -and $errors -eq 0) {
    $authFile = Join-Path $HOME ".toolname.toml"
    if (-not (Test-Path $authFile)) {
        LogWarn "Authentication required: run 'toolname setup' (browser flow)"
        Write-Summary "WARN" "tool name" "not authenticated"
        Write-Summary "ACTION" "" "toolname setup -- authenticate tool"
    }
}
```

### Key rules

- Runs AFTER install/upgrade, BEFORE exit footer
- Only runs when `$ERRORS -eq 0` / `$errors -eq 0` (skip if install itself failed)
- Always pairs: `log_warn` + `write_summary WARN` + `write_summary ACTION`
- Prefer command exit code over file presence when the tool provides a status command
- Auth check method documented per-tool in `reference/tool-registry.md` (Authentication section)

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

## Logging architecture: setup vs check

The project maintains **two deliberately separated logging systems**. They must not
be unified -- each serves a distinct purpose with different semantics and audiences.

### Setup/deploy logging (aitools-lib)

- **Init**: `logging_init "name"` / `Initialize-Logging "name"`
- **Functions**: `log`/`log_ok`/`log_error`/`log_warn` (bash), `Log`/`LogOk`/`LogError`/`LogWarn` (PS1)
- **Destination**: `deploy.log`
- **Semantics**: Tool installation status (OK/WARN/ERROR)
- **Counters**: `ERRORS`/`WARNINGS` (bash), `$script:errors`/`$script:warnings` (PS1)
- **Summary**: `write_summary`/`Write-Summary` → end-of-run panel

### Check/audit logging (check-lib)

- **Init**: `check_log_init "name"` / `CheckLogInit "name"`
- **Functions**: `step_pass`/`step_fail`/`step_warn`/`step_skip` (bash), `StepPass`/`StepFail`/`StepWarn`/`StepSkip` (PS1)
- **Destination**: `checks.log` + `checks.jsonl`
- **Semantics**: Validation results (PASS/FAIL/WARN/SKIP)
- **Counters**: `PASS_COUNT`/`FAIL_COUNT`/`WARN_COUNT`/`SKIP_COUNT` (separate namespace)
- **Summary**: `print_summary`/`PrintSummary` → colored counters

### Bridge pattern (check scripts exercising lib functions)

Check scripts source `check-lib` which sources `aitools-lib`. When check steps
exercise lib functions (e.g., `Check-BuildPrereqs` → `Ensure-ToolOnPath` → `Log`),
those functions expect setup logging to be initialized.

`CheckLogInit`/`check_log_init` bridges this by also initializing the aitools-lib
logging variables (`logFile`/`LOG_FILE`, `scriptName`/`SCRIPT_NAME`, counters).
Operational messages from lib functions go to `deploy.log` — they're lib output,
not check step results.

**Why not call `Initialize-Logging`/`logging_init` directly?** Because check-lib
needs to control the init sequence (its own counters, log files, directory) and
adding a second init call would be fragile. The bridge sets only the variables
that lib log functions need.

## Cross-platform grep portability

macOS ships BSD `grep` which does not support `-P` (Perl-compatible regular expressions).
Linux `grep` (GNU) supports `-P` via libpcre. Scripts using `grep -P` fail on macOS
with `grep: invalid option -- P`.

### Rule: Never use `grep -P` in bash scripts

| Need | Portable alternative | Notes |
|------|---------------------|-------|
| Perl regex match | `perl -ne 'exit 0 if /pattern/; END { exit 1 }'` | Available on both platforms |
| Perl regex (multiline) | `perl -0777 -ne 'exit 0 if /pattern/; exit 1'` | `-0777` slurps entire file |
| Extended regex | `grep -E 'pattern'` | ERE works on both BSD and GNU grep |
| CRLF detection | `grep -rl $'\r' file` | Bash ANSI-C quoting; no `-P` needed |
| Fixed string | `grep -F 'literal'` | Fastest; no regex engine |

### Examples

**Wrong** -- fails on macOS:

```bash
grep -Pq '\$wingetOutput\.Trim\(\)' "$file"
grep -Prl '\r$' "$file"
```

**Correct** -- portable:

```bash
perl -0777 -ne 'exit 0 if /\$wingetOutput\.Trim\(\)/; exit 1' "$file"
grep -rl $'\r' "$file"
```

This aligns with the user-level USO "Perl for string manipulation" -- use `perl`
(not `sed`/`awk`/`grep -P`) for non-trivial string operations.

## Post-write validation

Setup scripts that generate files from templates must validate CONTENT correctness,
not just structural markers. If a file is assembled from template + footer, validate
that the template portion is non-empty, not just that the footer exists.

## Build prerequisite validation

### Two-layer framework

Setup scripts that compile from source must validate prerequisites before building:

**Layer 1 — preventive (fast, pre-flight):**
```powershell
# PowerShell
$missingPrereqs = Check-BuildPrereqs "cargo"
if ($missingPrereqs.Count -gt 0) {
    foreach ($p in $missingPrereqs) {
        LogError "$($p.Name) not installed -- required to build <tool> from source"
        LogError "Fix: $($p.Install)"
    }
    Write-Summary "ERROR" "<tool>" "missing build prereqs: $(($missingPrereqs | ForEach-Object { $_.Name }) -join ', ')"
    # Skip the build entirely
}
```

```bash
# Bash
PREREQ_MISSING=$(check_build_prereqs "cargo") || true
if [ -n "$PREREQ_MISSING" ]; then
    while IFS='|' read -r prereq_name prereq_install; do
        log_warn "$prereq_name not found -- $prereq_install"
    done <<< "$PREREQ_MISSING"
fi
```

**Layer 2 — diagnostic (after failure):**
```powershell
# PowerShell
$diagnosis = Diagnose-BuildFailure $cargoOutput
if ($diagnosis) {
    LogError "Build failed: $($diagnosis.Name) not available"
    LogError "Fix: $($diagnosis.Remedy)"
    Write-Summary "ERROR" "<tool>" "build failed: $($diagnosis.Name) missing"
    Write-Summary "ACTION" "" "$($diagnosis.Remedy) -- then re-run aitools install"
} else {
    LogError "cargo install <tool> failed (exit code $LASTEXITCODE)"
    Write-Summary "ERROR" "<tool>" "cargo install failed"
}
```

```bash
# Bash
DIAGNOSIS=$(diagnose_build_failure "$CARGO_OUTPUT") || true
if [ -n "$DIAGNOSIS" ]; then
    DIAG_NAME="${DIAGNOSIS%%|*}"
    DIAG_REMEDY="${DIAGNOSIS#*|}"
    log_error "Build failed: $DIAG_NAME not available"
    log_error "Fix: $DIAG_REMEDY"
    write_summary ERROR "<tool>" "build failed: $DIAG_NAME missing"
    write_summary ACTION "" "$DIAG_REMEDY -- then re-run"
else
    log_error "cargo install <tool> failed (exit code $CARGO_EC)"
    write_summary ERROR "<tool>" "install failed"
fi
```

### Anti-pattern: build first, diagnose after

Do NOT skip Layer 1 and rely only on Layer 2. Layer 1 catches known issues in milliseconds;
Layer 2 only fires after minutes of wasted compilation.

### Adding a new build prerequisite

When a user reports a new build failure:

1. **Read the tool's official documentation** (download page, install guide) to identify
   supported install methods. Choose method per `reference/tool-evaluation-playbook.md`.
   Do not choose from memory.
2. **File a GitHub issue** with the full error output
3. **Identify the error pattern** — the grep-able string from the build output
4. **Add to `aitools-lib.ps1`:**
   - Entry in `$script:BuildPrereqs` (if it's a checkable command)
   - Entry in `$script:BuildFailureSignatures` (the error pattern + remedy)
5. **Add to `aitools-lib.sh`:**
   - Entry in `check_build_prereqs()` case block
   - Entry in `diagnose_build_failure()` patterns array
6. **Document** in `reference/tool-registry.md` under the relevant tool's Prerequisites section
7. **Run** `bash scripts/build-deploy.sh` to propagate to deploy scripts
8. **Verify** with `check-pre-commit` (framework audit passes) and smoke test

### Ensure-ToolOnPath / ensure_tool_on_path

Reusable helper that verifies a tool is findable after installation. Three-step
detection: PATH check -> registry/cache refresh -> known filesystem paths fallback.

**When to use**: After any `winget install`, `brew install`, `cargo install`, or
similar command where the tool may not be immediately visible on PATH.

**PowerShell** (`Ensure-ToolOnPath` in `aitools-lib.ps1`):
```powershell
$knownPaths = @("$env:LOCALAPPDATA\bin\NASM\nasm.exe", "$env:ProgramFiles\NASM\nasm.exe")
if (Ensure-ToolOnPath -ToolName "nasm" -KnownPaths $knownPaths) {
    LogOk "NASM installed and on PATH"
} else {
    LogWarn "NASM not found"
}
```

**Bash** (`ensure_tool_on_path` in `aitools-lib.sh`):
```bash
if ensure_tool_on_path "nasm" /usr/local/bin/nasm /opt/homebrew/bin/nasm; then
    log_ok "NASM installed and on PATH"
else
    log_warn "NASM not found"
fi
```

### Known-paths fallback in Check-BuildPrereqs

When `Get-Command` / `command -v` fails (tool installed but not on PATH in current
session), the framework falls back to checking known filesystem install locations
via `Ensure-ToolOnPath` / `ensure_tool_on_path`.

**PowerShell**: Each entry in `$script:BuildPrereqs` may include `KnownPaths` (array
of absolute paths) and `ToolName` (executable name). `Check-BuildPrereqs` runs the
`Check` scriptblock first; if it fails, calls `Ensure-ToolOnPath` with the entry's
`KnownPaths`. If found, adds the parent directory to `$env:Path` for the session.

**Bash**: `check_build_prereqs()` calls `hash -r` to clear the shell command cache,
then uses `ensure_tool_on_path` with known paths if `command -v` fails.

**Adding known paths for a new prerequisite:**
1. Determine the standard install location(s) for the tool on each platform
2. PS1: add `ToolName` and `KnownPaths` to the `$script:BuildPrereqs` entry
3. Bash: add paths to the `ensure_tool_on_path` call in `check_build_prereqs()`
4. Document the paths in `reference/tool-registry.md` under the tool's Prerequisites section

**Standard install locations (Windows):**

| Tool | Install method | Install path | Verified |
|------|---------------|-------------|----------|
| NASM | winget (NASM.NASM) | `%LOCALAPPDATA%\bin\NASM\nasm.exe` | 2026-03-11 (v3.01) |
| CMake | uv tool install cmake | `%USERPROFILE%\.local\bin\cmake.exe` | 2026-03-12 (v4.2.3) |
| MSVC Build Tools | (detected via vswhere.exe) | N/A | N/A |

**Standard install locations (macOS/Linux):**

| Tool | Install paths |
|------|--------------|
| NASM | `/usr/local/bin/nasm`, `/opt/homebrew/bin/nasm`, `/usr/bin/nasm` |
| CMake | `/usr/local/bin/cmake`, `/opt/homebrew/bin/cmake`, `/usr/bin/cmake`, `/Applications/CMake.app/Contents/bin/cmake` |

**Empirical verification requirement:** All KnownPaths MUST be verified on an
actual machine with the tool installed. Document verification date and version.
Unverified paths must be marked `UNVERIFIED` in code comments and docs. This
applies to all tools and their build dependencies (e.g., NASM is a dependency
of Rust/cargo, not a directly managed tool -- same verification standard applies).

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
