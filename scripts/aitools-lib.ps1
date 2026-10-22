# aitools-lib.ps1 -- shared helpers for all aitools PowerShell scripts
# Dot-sourced, not executed directly.
#
# Provides: platform and environment detection ($AitoolsPlatform,
# $AitoolsEnvironment, Test-ClaudeCodeWeb, Test-LocalEnvironment,
# Write-EnvironmentSkip), ReadConfigKey, Initialize-Logging,
# Log/LogOk/LogError/LogWarn/LogDetail, Invoke-AI, Write-Summary, Show-Summary,
# Refresh-Path, Log-WingetOutput, Repair-UvToolEnv, Remove-OrphanedPythonDirs,
# Normalize-JsonForComparison.
#
# Usage:
#   . (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
#   Initialize-Logging "script-name"
#
# Entry points (aitools.ps1, aitools-install.ps1) override log functions after
# sourcing for specialized logging (file-only, JSONL, etc.).
#
# Platform detection builds on the PS 7+ built-ins $IsWindows/$IsMacOS/$IsLinux.

# ---------------------------------------------------------------------------
# Platform and environment detection -- parity with the "aitools environment
# block" in aitools-lib.sh (.claude/rules/cross-platform.md "Environment
# branches"; reference/cross-platform-detail.md "Platform and environment API").
# Resolved once, when this library is dot-sourced.
#   $AitoolsPlatform     windows | macos | linux | unknown
#   $AitoolsEnvironment  claude-code-web | local
#     override: $env:AITOOLS_ENVIRONMENT = claude-code-web|local (case-sensitive)
#     detect:   $env:CLAUDE_CODE_REMOTE = "true" -> claude-code-web, else local
#     rule:     claude-code-web exists only on linux
# The resolvers are pure functions so tests can cover every platform (the
# $Is* automatic variables are read-only).
# ---------------------------------------------------------------------------
function Resolve-AitoolsPlatform {
    param([int]$PSMajor, [bool]$OnWindows, [bool]$OnMacOS, [bool]$OnLinux)
    # PS 5.1 runs only on Windows and has no $IsWindows.
    if ($PSMajor -lt 6 -or $OnWindows) { return "windows" }
    if ($OnMacOS) { return "macos" }
    if ($OnLinux) { return "linux" }
    return "unknown"
}

function Resolve-AitoolsEnvironment {
    param([string]$Platform, [string]$Requested, [string]$Remote)
    $resolved = "local"
    if ($Requested -ceq "claude-code-web" -or $Requested -ceq "local") {
        $resolved = $Requested
    } elseif ($Remote -ceq "true") {
        $resolved = "claude-code-web"
    }
    if ($Platform -ne "linux") { $resolved = "local" }
    return $resolved
}

$script:AitoolsEnvironmentRequested = "$env:AITOOLS_ENVIRONMENT"
$script:AitoolsPlatform = Resolve-AitoolsPlatform -PSMajor $PSVersionTable.PSVersion.Major `
    -OnWindows ([bool]$IsWindows) -OnMacOS ([bool]$IsMacOS) -OnLinux ([bool]$IsLinux)
$script:AitoolsEnvironment = Resolve-AitoolsEnvironment -Platform $script:AitoolsPlatform `
    -Requested $script:AitoolsEnvironmentRequested -Remote "$env:CLAUDE_CODE_REMOTE"
# Parity with bash: an exported override carries the resolved value to child scripts.
if ($env:AITOOLS_ENVIRONMENT) { $env:AITOOLS_ENVIRONMENT = $script:AitoolsEnvironment }

# Predicates for environment branches (below the OS guard only).
function Test-ClaudeCodeWeb   { return ($script:AitoolsEnvironment -eq "claude-code-web") }
function Test-LocalEnvironment { return ($script:AitoolsEnvironment -eq "local") }

# ---------------------------------------------------------------------------
# Config reader (PS 5.1 compatible)
# ---------------------------------------------------------------------------
function ReadConfigKey {
    param([string]$File, [string]$Key)
    if (-not (Test-Path $File)) { return $null }
    try {
        $json = Get-Content $File -Raw -ErrorAction Stop | ConvertFrom-Json
        $val = $json.$Key
        if ($val) { return $val }
    } catch {
        # File exists but is invalid JSON -- warn so callers know the null
        # return means "corrupt", not "missing key". Callers may run before
        # Initialize-Logging; without a log file, fall back to the warning stream.
        if ($script:logFile) { LogWarn "Could not parse $File" }
        else { Write-Warning "Could not parse $File" }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Logging init
# ---------------------------------------------------------------------------
# Sets $script:scriptName, $script:logDir, $script:logFile; resets
# $script:errors, $script:warnings. Creates log directory.
# Usage: Initialize-Logging "setup-foo"
# Log rotation (reference/logging.md §4): size-based, 5 MB x 5 backups.
# Fail-safe -- a broken rotate must never break the operation it records (§5).
$script:LogMaxBytes = 5242880   # 5 MB
$script:LogBackupCount = 5
function Rotate-Log {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $item = Get-Item $Path -ErrorAction SilentlyContinue
    if (-not $item -or $item.Length -lt $script:LogMaxBytes) { return }
    $n = $script:LogBackupCount
    Remove-Item "$Path.$n" -Force -ErrorAction SilentlyContinue
    for ($i = $n; $i -gt 1; $i--) {
        $prev = $i - 1
        Move-Item "$Path.$prev" "$Path.$i" -Force -ErrorAction SilentlyContinue
    }
    Move-Item $Path "$Path.1" -Force -ErrorAction SilentlyContinue
}

function Initialize-Logging {
    param([Parameter(Mandatory)][string]$Name)
    $script:scriptName = $Name
    # Unified cross-platform log dir (reference/logging.md §1): ~/.aitools/logs
    # on all platforms. Honors an explicit AITOOLS_LOG_DIR override (e.g. tests).
    if ($env:AITOOLS_LOG_DIR) {
        $script:logDir = $env:AITOOLS_LOG_DIR
    } else {
        $script:logDir = Join-Path $HOME ".aitools" "logs"
    }
    $script:logFile = Join-Path $script:logDir "deploy.log"
    if (-not (Test-Path $script:logDir)) {
        New-Item -ItemType Directory -Path $script:logDir -Force | Out-Null
    }
    Rotate-Log $script:logFile
    $script:errors = 0
    $script:warnings = 0
    Write-AitoolsEnvironmentLog
}

# Record the resolved platform/environment (file-only detail line); warn when an
# AITOOLS_ENVIRONMENT override was invalid or not possible on this platform.
function Write-AitoolsEnvironmentLog {
    LogDetail "platform=$($script:AitoolsPlatform) environment=$($script:AitoolsEnvironment) (AITOOLS_ENVIRONMENT='$($script:AitoolsEnvironmentRequested)' CLAUDE_CODE_REMOTE='$env:CLAUDE_CODE_REMOTE' type='$env:CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE')"
    if ($script:AitoolsEnvironmentRequested -and $script:AitoolsEnvironmentRequested -cne $script:AitoolsEnvironment) {
        LogWarn "AITOOLS_ENVIRONMENT='$($script:AitoolsEnvironmentRequested)' ignored (valid: local; claude-code-web on Linux only) -- environment is $($script:AitoolsEnvironment)"
    }
}

# ---------------------------------------------------------------------------
# Standard logging (console + log file, with [level] tag)
# ---------------------------------------------------------------------------
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    $resolvedLog = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logFile)
    [IO.File]::AppendAllText($resolvedLog, "$line`n", [System.Text.UTF8Encoding]::new($false))
    switch ($level) {
        "error" { Write-Host $line -ForegroundColor Red }
        "warn"  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line }
    }
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }
function LogDetail($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $resolvedLog = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logFile)
    [IO.File]::AppendAllText($resolvedLog, "[$ts] [$scriptName] [detail] $msg`n", [System.Text.UTF8Encoding]::new($false))
}

# ---------------------------------------------------------------------------
# Agentic AI invocation -- generalized wrapper for claude/agent CLI
# ---------------------------------------------------------------------------
# Purpose: Standardized AI CLI invocation with speed/permission tiers,
#   validation callbacks, automatic retry, and telemetry logging.
# Inputs: Prompt (pipeline), Speed, Permissions, ValidateFn, MaxRetries
# Expected output: AI-generated text string, or $null on failure.
# Validation: Caller-provided ValidateFn (function name); receives output as
#   positional arg, must return $true/$false and set $script:AIRejectReason.
# Known limitations: Agent CLI has no --model flag; speed is hint-only via
#   prompt prefix. Retry prepends rejection reason but may not fix structural
#   issues (e.g., model always wrapping in code fences).
$script:AIRejectReason = ""

function Invoke-AI {
    param(
        [Parameter(Mandatory, ValueFromPipeline)][string]$Prompt,
        [ValidateSet("fast","balanced","quality")][string]$Speed = "balanced",
        [ValidateSet("none","readonly","full","dangerous")][string]$Permissions = "none",
        [string]$ValidateFn = "",
        [int]$MaxRetries = 0
    )

    $script:AIRejectReason = ""

    # Detect backend
    # Get-Command exempt: command-existence check with explicit fallback chain
    $cliCmd = $null
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $cliCmd = "claude"
    } elseif (Get-Command agent -ErrorAction SilentlyContinue) {
        $cliCmd = "agent"
    }

    if (-not $cliCmd) {
        $script:AIRejectReason = "No AI CLI available (claude or agent)"
        Log "AI invocation: no CLI available (claude or agent)" "error"
        return $null
    }

    # Build CLI flags
    $flags = @()

    if ($cliCmd -eq "claude") {
        $flags += "-p", "--no-session-persistence"
        # Speed mapping (claude CLI: explicit model + effort)
        switch ($Speed) {
            "fast"     { $flags += "--model", "haiku", "--effort", "low" }
            "balanced" { $flags += "--model", "sonnet" }
            "quality"  { $flags += "--model", "opus", "--effort", "high" }
        }
        # Permission mapping
        switch ($Permissions) {
            "none"      { $flags += "--allowedTools", "" }
            "readonly"  { $flags += "--allowedTools", "Read Glob Grep" }
            "full"      { } # default -- no restriction
            "dangerous" { $flags += "--dangerously-skip-permissions" }
        }
        # System prompt hints for speed tiers
        switch ($Speed) {
            "fast"    { $flags += "--append-system-prompt", "Be concise and direct." }
            "quality" { $flags += "--append-system-prompt", "Take your time. Be thorough." }
        }
    } else {
        # Agent CLI -- no --model flag; speed via prompt prefix only
        $flags += "-p", "--trust"
        # Permission mapping
        switch ($Permissions) {
            "none"      { $flags += "--mode", "ask" }
            "readonly"  { $flags += "--mode", "plan" }
            "full"      { } # default
            "dangerous" { $flags += "--force" }
        }
    }

    # Speed prefix for agent CLI (no model flag available)
    $speedPrefix = ""
    if ($cliCmd -eq "agent") {
        switch ($Speed) {
            "fast"    { $speedPrefix = "Be concise and direct. Prioritize speed.`n`n" }
            "quality" { $speedPrefix = "Take your time. Be thorough and precise.`n`n" }
        }
    }

    # Retry loop
    $currentPrompt = $Prompt
    for ($attempt = 1; $attempt -le ($MaxRetries + 1); $attempt++) {
        Log "AI invocation: speed=$Speed backend=$cliCmd attempt=$attempt"

        $fullPrompt = "${speedPrefix}${currentPrompt}"

        $output = $null
        try {
            $output = $fullPrompt | & $cliCmd @flags 2>&1
            if ($LASTEXITCODE -ne 0) { $output = $null }
        } catch {
            # CLI invocation failed (e.g., binary not found despite Get-Command)
            Log "AI invocation error: $_" "warn"
            $output = $null
        }

        # Normalize array output to string
        if ($output -is [array]) { $output = $output -join "`n" }

        if ([string]::IsNullOrWhiteSpace($output)) {
            $script:AIRejectReason = "Empty output from $cliCmd"
            Log "AI invocation: speed=$Speed backend=$cliCmd attempt=$attempt result=empty" "warn"
            if ($attempt -le $MaxRetries) {
                $currentPrompt = "Your previous output was empty. Try again.`n`n$Prompt"
                continue
            }
            return $null
        }

        # Validate if function provided
        if ($ValidateFn) {
            $valid = & $ValidateFn $output
            if (-not $valid) {
                if (-not $script:AIRejectReason) { $script:AIRejectReason = "Validation failed" }
                Log "AI invocation: speed=$Speed backend=$cliCmd attempt=$attempt result=rejected reason=$($script:AIRejectReason)" "warn"
                foreach ($rejLine in ($output -split "`n")) {
                    LogDetail "ai-rejected: $rejLine"
                }
                if ($attempt -le $MaxRetries) {
                    $currentPrompt = "Your previous output was rejected: $($script:AIRejectReason). Try again.`n`n$Prompt"
                    continue
                }
                Log "AI invocation: speed=$Speed backend=$cliCmd exhausted after $attempt attempts" "warn"
                return $null
            }
        }

        # Success
        Log "AI invocation: speed=$Speed backend=$cliCmd attempt=$attempt result=accepted"
        return $output
    }

    return $null
}

# ---------------------------------------------------------------------------
# Summary writer (3-arg: category, tool, detail)
# ---------------------------------------------------------------------------
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) {
        # Auto-promote OK to WARN when warnings have been logged
        if ($cat -eq "OK" -and $script:warnings -gt 0) {
            $cat = "WARN"
        }
        $resolvedSummary = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:AITOOLS_SUMMARY_FILE)
        [IO.File]::AppendAllText($resolvedSummary, "${cat}|${tool}|${detail}`n", [System.Text.UTF8Encoding]::new($false))
    }
}

# ---------------------------------------------------------------------------
# Environment skip (parity with write_environment_skip in aitools-lib.sh): a
# step that does not apply in this environment reports one OK row
# "n/a (<environment>)" plus the reason in the log.
# ---------------------------------------------------------------------------
function Write-EnvironmentSkip {
    param([Parameter(Mandatory)][string]$Tool, [Parameter(Mandatory)][string]$Reason)
    Log "n/a in the $($script:AitoolsEnvironment) environment: $Reason"
    Write-Summary "OK" $Tool "n/a ($($script:AitoolsEnvironment))"
}

# ---------------------------------------------------------------------------
# Backup a file before overwriting. Keeps at most $MaxBackups copies.
# A failed copy is non-fatal here (warn, return) and sets
# $script:BackupFileOk = $false; callers that must not write without a backup
# check it (Write-ManagedFiles).
# ---------------------------------------------------------------------------
$script:BackupFileOk = $true
function Backup-File {
    param([string]$FilePath, [int]$MaxBackups = 20)
    $script:BackupFileOk = $true
    if (-not (Test-Path $FilePath)) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${FilePath}.bak.${ts}"
    # A failed backup is non-fatal (config-file-safety.md "Backup before overwrite"):
    # warn and let the caller proceed.
    try {
        Copy-Item -Path $FilePath -Destination $backupPath -ErrorAction Stop
    } catch {
        $script:BackupFileOk = $false
        LogWarn "Could not back up $FilePath -- proceeding without backup: $_"
        return
    }
    # Prune oldest beyond limit
    $backups = @(Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending)
    if ($backups.Count -gt $MaxBackups) {
        foreach ($old in ($backups | Select-Object -Skip $MaxBackups)) {
            try { Remove-Item $old.FullName -Force -ErrorAction Stop }
            catch { LogWarn "Could not prune old backup $($old.FullName)" }
        }
    }
    Log "Backed up $FilePath"
}

# ---------------------------------------------------------------------------
# Backup a directory before modifying managed files. Keeps at most $MaxBackups copies.
# ---------------------------------------------------------------------------
function Backup-Dir {
    param([string]$DirPath, [int]$MaxBackups = 5)
    if (-not (Test-Path $DirPath)) { return }
    $mdFiles = Get-ChildItem -Path $DirPath -Filter "*.md" -File -ErrorAction SilentlyContinue
    if (-not $mdFiles -or $mdFiles.Count -eq 0) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${DirPath}.bak.${ts}"
    try {
        Copy-Item -Path $DirPath -Destination $backupPath -Recurse -ErrorAction Stop
    } catch {
        LogWarn "Could not back up $DirPath -- proceeding without backup: $_"
        return
    }
    $parentDir = Split-Path $DirPath -Parent
    $dirName = Split-Path $DirPath -Leaf
    $backups = Get-ChildItem -Path $parentDir -Directory -Filter "${dirName}.bak.*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($backups -and $backups.Count -gt $MaxBackups) {
        $backups | Select-Object -Skip $MaxBackups | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force
            Log "Pruned old backup: $($_.FullName)"
        }
    }
    Log "Backed up $DirPath ($($mdFiles.Count) managed files)"
}

# ---------------------------------------------------------------------------
# Managed-file helpers for Deploy-ManagedFile, Review-JsonFields and the
# review prompts below. SOURCE is the source of truth; there is no deploy
# state (see the "Review choices" block above Prompt-DiffReview).
# ---------------------------------------------------------------------------

# [x]abort: log, then exit 2 (a bare exit 2 means user abort; commander
# decision 2026-10-21, D-TS13 reversed: no marker file). One helper for every
# review prompt. Parity: _managed_abort in aitools-lib.sh.
function Invoke-ManagedAbort {
    LogError "Aborted by user"
    exit 2
}

# Deploy state (~/.aitools/deploy-state/) is no longer used. Files from older
# versions are left on disk; say so once per script run (detail level).
$script:ManagedStateNoted = $false
function Write-ManagedStateNotice {
    if ($script:ManagedStateNoted) { return }
    $script:ManagedStateNoted = $true
    $homeDir = if ($IsWindows) { $env:USERPROFILE } else { $HOME }
    $stateDir = Join-Path (Join-Path $homeDir ".aitools") "deploy-state"
    if (Test-Path -LiteralPath $stateDir) {
        LogDetail "deploy state is no longer used (SOURCE is the source of truth); $stateDir left on disk"
    }
}

# Adopting into a protected file is allowed: it writes only the working tree.
# LogWarn, naming the file, when the adopt target is listed in the
# protected-files table (.claude/rules/sources-of-truth.md) of the git repo
# that contains it. Table entries are backticked paths in the first column;
# * matches within one path segment. Parity: _managed_protected_note.
function Write-ManagedProtectedNote {
    param([string]$Target)
    $dir = Split-Path -Parent $Target
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return }
    # 2>$null: git fails outside a repo; that means "not protected" ($LASTEXITCODE and the result are checked).
    $top = & git -C $dir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) { return }
    $prefix = & git -C $dir rev-parse --show-prefix 2>$null
    # 2>$null: same as above; an empty prefix is valid (file at the repo root).
    if ($LASTEXITCODE -ne 0) { return }
    $table = Join-Path $top ".claude/rules/sources-of-truth.md"
    if (-not (Test-Path -LiteralPath $table)) { return }
    $rel = "$prefix" + (Split-Path -Leaf $Target)
    try {
        $lines = [IO.File]::ReadAllLines($table, [Text.Encoding]::UTF8)
    } catch {
        LogDetail "Could not read $table for the protected-file check: $_"
        return
    }
    foreach ($line in $lines) {
        if ($line -match '^\|\s*`([^`]+)`') {
            $pat = [regex]::Escape($Matches[1]) -replace '\\\*', '[^/]*'
            if ($rel -match "^$pat$") {
                LogWarn "Adopted into protected file $Target -- working tree only; the review gate (.claude/rules/sources-of-truth.md) applies at commit"
                return
            }
        }
    }
}

# After adopt or merge: the library never commits or pushes. Say that the
# adopt target's repo has an uncommitted change to review, and WARN when the
# target is protected (Write-ManagedProtectedNote). Parity: _managed_adopt_notice.
function Write-ManagedAdoptNotice {
    param([string]$Target)
    Write-ManagedProtectedNote -Target $Target
    $dir = Split-Path -Parent $Target
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return }
    # 2>$null: outside a git repo there is nothing to commit ($LASTEXITCODE and the result are checked).
    $top = & git -C $dir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $top) {
        Log "Uncommitted change in ${top}: $(Split-Path -Leaf $Target) -- review and commit it (cd $top && git diff)"
    }
}

# ---------------------------------------------------------------------------
# Write LOCAL and/or the adopt target as one step (parity: _managed_write).
#   -LocalPath ("" = LOCAL not written) / -LocalContent
#   -AdoptPath ("" = adopt target not written) / -AdoptContent
# Content is written as UTF-8 (no BOM) with exactly one trailing newline.
# Before anything is written, each existing file is snapshotted (for restore)
# and backed up (Backup-File: rotated .bak.<ts>); a failed backup fails the
# step with nothing written. After writing, each file is validated: non-empty,
# and for a name ending in .json: valid JSON (node) that has every top-level
# key in -LocalRequiredKeys / -AdoptRequiredKeys (JSON arrays; "" = none). On
# any failure every file this call touched is restored from its snapshot (a
# file that did not exist is removed), $script:ManagedWriteError is set, and
# $false is returned. The caller logs the error with LogError.
# ---------------------------------------------------------------------------
$script:ManagedWriteError = ""
$script:ManagedJsonCheck = @'
// node check.js FILE REQUIRED_KEYS_FILE (argv[1] is this script's own path)
const fs = require('fs');
let v;
try { v = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); }
catch (e) { console.error('not valid JSON: ' + e.message); process.exit(1); }
const req = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
const isObj = v !== null && typeof v === 'object' && !Array.isArray(v);
const miss = isObj ? req.filter(k => !Object.prototype.hasOwnProperty.call(v, k)) : req;
if (miss.length) { console.error('missing required keys: ' + miss.join(', ')); process.exit(1); }
'@
function Write-ManagedFiles {
    param(
        [string]$LocalPath = "",
        [string]$LocalContent = "",
        [string]$AdoptPath = "",
        [string]$AdoptContent = "",
        [string]$LocalRequiredKeys = "",
        [string]$AdoptRequiredKeys = ""
    )
    $script:ManagedWriteError = ""
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($pair in @(@{ P = $LocalPath; C = $LocalContent; R = $LocalRequiredKeys },
                        @{ P = $AdoptPath; C = $AdoptContent; R = $AdoptRequiredKeys })) {
        if (-not $pair.P) { continue }
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($pair.P)
        $entries.Add([PSCustomObject]@{
            Path     = $resolved
            Content  = $pair.C
            Required = $(if ($pair.R) { $pair.R } else { "[]" })
            Existed  = (Test-Path -LiteralPath $resolved -PathType Leaf)
            Snapshot = $null
        })
    }

    $snapDir = Join-Path ([IO.Path]::GetTempPath()) ("aitools-mf-" + [guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $snapDir -Force -ErrorAction Stop | Out-Null
    } catch {
        $script:ManagedWriteError = "could not create a restore snapshot directory -- nothing written: $_"
        return $false
    }

    $n = 0
    foreach ($e in $entries) {
        $n++
        if (-not $e.Existed) { continue }
        $e.Snapshot = Join-Path $snapDir "s$n"
        try {
            Copy-Item -LiteralPath $e.Path -Destination $e.Snapshot -ErrorAction Stop
        } catch {
            $script:ManagedWriteError = "could not snapshot $($e.Path) for restore -- nothing written: $_"
            Remove-Item -LiteralPath $snapDir -Recurse -Force -ErrorAction SilentlyContinue
            # ErrorAction exempt: temp snapshot cleanup; the failure is already reported
            return $false
        }
        Backup-File -FilePath $e.Path
        if (-not $script:BackupFileOk) {
            $script:ManagedWriteError = "backup of $($e.Path) failed -- nothing written"
            Remove-Item -LiteralPath $snapDir -Recurse -Force -ErrorAction SilentlyContinue
            # ErrorAction exempt: temp snapshot cleanup; the failure is already reported
            return $false
        }
    }

    $ok = $true
    foreach ($e in $entries) {
        try {
            $dir = Split-Path -Parent $e.Path
            if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
            }
            [IO.File]::WriteAllText($e.Path, "$($e.Content)`n", [System.Text.UTF8Encoding]::new($false))
        } catch {
            $script:ManagedWriteError = "write failed for $($e.Path): $($_.Exception.Message)"
            $ok = $false
            break
        }
        if ((Get-Item -LiteralPath $e.Path).Length -eq 0) {
            $script:ManagedWriteError = "validation failed: $($e.Path) is empty after the write"
            $ok = $false
            break
        }
        if ($e.Path -like '*.json') {
            # Script and required keys go through files, not arguments (native
            # argument quoting differs across PowerShell versions on Windows).
            $checkJs = Join-Path $snapDir "check.js"
            $reqFile = Join-Path $snapDir "req.json"
            try {
                [IO.File]::WriteAllText($checkJs, $script:ManagedJsonCheck, [System.Text.UTF8Encoding]::new($false))
                [IO.File]::WriteAllText($reqFile, $e.Required, [System.Text.UTF8Encoding]::new($false))
            } catch {
                $script:ManagedWriteError = "validation failed: could not prepare the JSON check for $($e.Path): $_"
                $ok = $false
                break
            }
            $nodeOut = & node $checkJs $e.Path $reqFile 2>&1
            if ($LASTEXITCODE -ne 0) {
                $script:ManagedWriteError = "validation failed: $($e.Path): $nodeOut"
                $ok = $false
                break
            }
        }
    }

    if (-not $ok) {
        foreach ($e in $entries) {
            if ($e.Snapshot) {
                # Restore only what changed (a write refused at open changed nothing).
                $same = $false
                try {
                    $same = ([IO.File]::ReadAllText($e.Path) -ceq [IO.File]::ReadAllText($e.Snapshot))
                } catch {
                    LogDetail "Restore compare failed for $($e.Path) -- restoring: $_"
                    $same = $false
                }
                if (-not $same) {
                    try {
                        Copy-Item -LiteralPath $e.Snapshot -Destination $e.Path -Force -ErrorAction Stop
                        Log "Restored $($e.Path)"
                    } catch {
                        LogError "Restore failed for $($e.Path) -- its backup is next to it (.bak.*): $_"
                    }
                }
            } elseif (-not $e.Existed -and (Test-Path -LiteralPath $e.Path)) {
                try {
                    Remove-Item -LiteralPath $e.Path -Force -ErrorAction Stop
                    Log "Removed partial $($e.Path)"
                } catch {
                    LogError "Could not remove partial $($e.Path): $_"
                }
            }
        }
    }
    Remove-Item -LiteralPath $snapDir -Recurse -Force -ErrorAction SilentlyContinue
    # ErrorAction exempt: temp snapshot cleanup; nothing depends on it
    return $ok
}

# ---------------------------------------------------------------------------
# Merge file description lookup
# ---------------------------------------------------------------------------
# Purpose: Returns a human-readable description of a managed file for AI merge
#   prompts, providing context about the file's role in the config system.
function Get-MergeFileDescription {
    param([string]$FilePath)
    $name = Split-Path $FilePath -Leaf
    switch -Wildcard ($name) {
        "CLAUDE.md" { return "User-scope CLAUDE.md -- personal preferences and instructions for Claude Code" }
        "*.md"      { return "Configuration rule: $name" }
        "*.json"    { return "JSON config: $name" }
        default     { return "Managed file: $name" }
    }
}

# ---------------------------------------------------------------------------
# AI merge prompt builder (initial merge)
# ---------------------------------------------------------------------------
# Purpose: Builds a structured merge prompt following the Role/Context/Task/
#   Constraints/Format pattern for merging managed configuration files.
# Inputs: FilePath, SourceContent, LocalContent, DiffOutput
# Expected output: Complete prompt string suitable for Invoke-AI.
# Validation: Test-AiMergeOutput (5 checks: conversational, fences,
#   refusal, truncation, header preservation)
# Known limitations: Very large files may hit model context limits. Files with
#   no markdown headers rely on Check 4 (length) for rewrite detection.
function Get-AiMergePrompt {
    param(
        [string]$FilePath,
        [string]$SourceContent,
        [string]$LocalContent,
        [string]$DiffOutput
    )
    $fileDesc = Get-MergeFileDescription $FilePath
    return @"
You are merging a managed configuration file during automated deployment.

## What you are merging
$fileDesc

## Where changes come from
SOURCE: The canonical template, synced across machines -- the updated version being deployed
LOCAL: The user's current file on this machine, with their customizations

## What is happening
Updated configuration is being deployed. Source has changed and needs to be
incorporated without losing local customizations.

## Differences (unified diff: local vs source)
$DiffOutput

## Full local file (start from this)
<LOCAL>
$LocalContent
</LOCAL>

## Rules
1. Start with LOCAL as your base -- preserve all user customizations
2. Apply ONLY the changes shown in the diff
3. If a change conflicts with a local customization (contradicts its intent), keep local
4. If a change adds new content not in LOCAL, add it in the appropriate location
5. If a change updates content the user hasn't customized, apply it
6. CRITICAL: Do NOT wrap your output in markdown code fences (``````). Output raw file content ONLY
7. No commentary, no explanation, no preamble -- just the merged file content
"@
}

# ---------------------------------------------------------------------------
# AI merge prompt builder (refinement)
# ---------------------------------------------------------------------------
# Purpose: Builds a refinement prompt for iterating on a previous merge result
#   based on user feedback.
# Inputs: SourceContent, LocalContent, CurrentMerge, Feedback
# Validation: Same as initial merge (Test-AiMergeOutput).
function Get-AiMergeRefinePrompt {
    param(
        [string]$SourceContent,
        [string]$LocalContent,
        [string]$CurrentMerge,
        [string]$Feedback
    )
    return @"
You are refining a merged configuration file based on user feedback.

## Context
A previous merge produced CURRENT_MERGE from SOURCE + LOCAL. The user wants changes.

## SOURCE (original template)
<SOURCE>
$SourceContent
</SOURCE>

## LOCAL (original user file)
<LOCAL>
$LocalContent
</LOCAL>

## CURRENT MERGE (previous result)
<CURRENT_MERGE>
$CurrentMerge
</CURRENT_MERGE>

## User Feedback
$Feedback

## Rules
- Apply the user's feedback to CURRENT_MERGE
- Keep all content from CURRENT_MERGE not affected by the feedback
- Output the revised merged file content ONLY -- no preamble, no explanation, no markdown fences
"@
}

# Merge validation wrapper for Invoke-AI -- captures source/local context
# via script-level variables set by Invoke-AiMerge before calling Invoke-AI.
$script:_mergeValidateSource = ""
$script:_mergeValidateLocal = ""
function _MergeValidateWrapper {
    param([string]$Output)
    $result = Test-AiMergeOutput -Output $Output -SourceContent $script:_mergeValidateSource -LocalContent $script:_mergeValidateLocal
    $script:AIRejectReason = $script:MergeRejectReason
    return $result
}

$script:MergeRejectReason = ""

# ---------------------------------------------------------------------------
# Validate AI merge output before accepting it.
# Returns $true if valid, $false if invalid. Sets $script:MergeRejectReason.
# ---------------------------------------------------------------------------
function Test-AiMergeOutput {
    param(
        [string]$Output,
        [string]$SourceContent,
        [string]$LocalContent
    )
    $script:MergeRejectReason = ""

    # Check 1: conversational patterns (first non-empty line)
    $firstLine = ($Output -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if ($firstLine -and $firstLine -match '(?i)^(I |Here|Sure|Certainly|Let me)') {
        $truncated = $firstLine.Substring(0, [Math]::Min(60, $firstLine.Length))
        $script:MergeRejectReason = "AI responded conversationally instead of producing merged content"
        return $false
    }

    # Check 2: markdown code fences
    if ($Output -match '(?m)^```') {
        $script:MergeRejectReason = "AI wrapped output in code fences -- need raw content"
        return $false
    }

    # Check 3: conversational refusal patterns (not bare keywords -- content may
    # legitimately contain "permission", "access", etc.)
    if ($Output -match '(?i)(I don''t have permission|I cannot access|I''m not authorized|I need (your )?approval|permission denied|access denied|I''m unable to|I can''t (read|write|access|open|modify))') {
        $script:MergeRejectReason = "AI indicated it couldn't perform the merge"
        return $false
    }

    # Check 4: minimum length (output >= 50% of shorter input when shorter > 40 chars)
    $outLen = $Output.Length
    $minInputLen = [Math]::Min($SourceContent.Length, $LocalContent.Length)
    $threshold = [Math]::Floor($minInputLen / 2)
    if ($minInputLen -gt 40 -and $outLen -lt $threshold) {
        $script:MergeRejectReason = "Output too short ($outLen chars, expected ${threshold}+) -- likely truncated"
        return $false
    }

    # Check 5: header preservation -- deduplicated headers from source+local must
    # be >=60% preserved in output. Files with 0 headers pass (Check 4 handles truncation).
    $allHeaders = @()
    foreach ($line in (($SourceContent + "`n" + $LocalContent) -split "`n")) {
        if ($line -match '^#{1,6} ') { $allHeaders += $line }
    }
    $combinedHeaders = @($allHeaders | Sort-Object -Unique)
    $total = $combinedHeaders.Count
    if ($total -gt 0) {
        $preserved = 0
        foreach ($header in $combinedHeaders) {
            if ($Output.Contains($header)) { $preserved++ }
        }
        $threshold = [Math]::Ceiling($total * 60 / 100)
        if ($threshold -lt 1) { $threshold = 1 }
        if ($preserved -lt $threshold) {
            $script:MergeRejectReason = "Rewrote too much ($preserved/$total section headers preserved, need 60%+)"
            return $false
        }
    }

    return $true
}

# ---------------------------------------------------------------------------
# Spinner for AI operations (visual progress indicator)
# ---------------------------------------------------------------------------
$script:_aiSpinnerJob = $null

function Start-AiSpinner {
    param([string]$Message = "working...")
    $script:_aiSpinnerJob = Start-Job -ScriptBlock {
        param($msg)
        $chars = '/-\|'
        $i = 0
        while ($true) {
            $c = $chars[$i % 4]
            [Console]::Write("`r  $c $msg")
            $i++
            Start-Sleep -Milliseconds 200
        }
    } -ArgumentList $Message
}

function Stop-AiSpinner {
    if ($script:_aiSpinnerJob) {
        Stop-Job $script:_aiSpinnerJob -ErrorAction SilentlyContinue
        Remove-Job $script:_aiSpinnerJob -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: spinner cleanup; job may already be stopped
        $script:_aiSpinnerJob = $null
        [Console]::Write("`r  `e[K")  # clear spinner line
    }
}

# ---------------------------------------------------------------------------
# Prompt helpers (parity with aitools-lib.sh read_tty_choice / the /dev/tty check).
# Test-InteractiveConsole: one non-interactive test for every prompt -- a
# redirected stdin or a non-interactive session never prompts.
# Read-ConsoleChoice: [Console]::ReadLine() returns $null at EOF, and the
# callers' .ToLower() then threw. This logs and returns "" so each caller's
# default branch applies.
# ---------------------------------------------------------------------------
function Test-InteractiveConsole {
    return ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)
}

function Read-ConsoleChoice {
    param([string]$DefaultDesc)
    $line = [Console]::ReadLine()
    if ($null -eq $line) {
        [Console]::WriteLine("")
        LogWarn "No input at prompt (EOF) -- defaulting to $DefaultDesc"
        return ""
    }
    return $line
}

# ---------------------------------------------------------------------------
# Agentic merge via Invoke-AI with refinement loop ([m]erge & adopt).
# Uses structured prompts from Get-AiMergePrompt / Get-AiMergeRefinePrompt.
# Parity: _invoke_ai_merge in aitools-lib.sh. Returns:
#   "merge"  -- [y]es: $script:MergedContent holds the accepted merge
#   "menu"   -- [n]o: the preview was rejected; Prompt-DiffReview shows its
#               menu again (nothing written)
#   "failed" -- the AI merge produced no valid output; $script:ManagedMergeError
#               holds the reason (Deploy-ManagedFile logs it; nothing written)
# ---------------------------------------------------------------------------
$script:ManagedMergeError = ""
function Invoke-AiMerge {
    param(
        [string]$FilePath,
        [string]$SourceContent,
        [string]$LocalContent,
        [string]$DiffOutput = ""
    )

    $script:ManagedMergeError = ""

    # Detect backend for transparency display
    # Get-Command exempt: command-existence check with explicit fallback
    $aiBackend = "unknown"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $aiBackend = "claude"
    } elseif (Get-Command agent -ErrorAction SilentlyContinue) {
        $aiBackend = "agent"
    }
    $displayName = Split-Path -Leaf $FilePath
    [Console]::WriteLine("  >> AI merge: $aiBackend (balanced) -- merging $displayName...")

    # Set validation context for _MergeValidateWrapper
    $script:_mergeValidateSource = $SourceContent
    $script:_mergeValidateLocal = $LocalContent

    $currentMerge = ""
    $iteration = 0

    while ($true) {
        $iteration++

        if (-not $currentMerge) {
            $promptText = Get-AiMergePrompt -FilePath $FilePath -SourceContent $SourceContent `
                -LocalContent $LocalContent -DiffOutput $DiffOutput
        } else {
            [Console]::Write("  refinement feedback: ")
            $feedback = Read-ConsoleChoice "no feedback"
            $promptText = Get-AiMergeRefinePrompt -SourceContent $SourceContent `
                -LocalContent $LocalContent -CurrentMerge $currentMerge -Feedback $feedback
        }

        Start-AiSpinner "merging $displayName (attempt $iteration)..."
        $merged = $promptText | Invoke-AI -Speed "balanced" -Permissions "none" `
            -ValidateFn "_MergeValidateWrapper" -MaxRetries 1
        Stop-AiSpinner

        # Defense-in-depth: strip leading/trailing code fences if AI ignored instructions
        if ($merged) {
            $merged = $merged -replace '(?s)\A```[^\n]*\n', '' -replace '\n```\s*\z', ''
        }

        if (-not $merged) {
            $reason = if ($script:AIRejectReason) { $script:AIRejectReason } else { "unknown error" }
            $script:ManagedMergeError = "AI merge failed (iteration $iteration): $reason"
            [Console]::WriteLine("  >> $($script:ManagedMergeError) -- nothing written")
            return "failed"
        }

        # Show merge preview
        [Console]::WriteLine("")
        [Console]::WriteLine("  --- merged result preview (first 30 lines) ---")
        $mergedLines = $merged -split "`n"
        $previewCount = [Math]::Min(30, $mergedLines.Count)
        for ($i = 0; $i -lt $previewCount; $i++) {
            [Console]::WriteLine("  | $($mergedLines[$i])")
        }
        if ($mergedLines.Count -gt 30) {
            [Console]::WriteLine("  | ... ($($mergedLines.Count - 30) more lines)")
        }
        [Console]::WriteLine("")
        [Console]::Write("  [y]es accept / [r]efine / [n]o reject: ")
        $accept = Read-ConsoleChoice "reject the merge (back to the review menu)"
        switch ($accept.ToLower()) {
            "y" {
                $script:MergedContent = $merged
                [Console]::WriteLine("  >> merged: AI-merged content accepted (iteration $iteration)")
                return "merge"
            }
            "r" {
                $currentMerge = $merged
                [Console]::WriteLine("  >> refining merge (iteration $iteration)...")
                # continue loop
            }
            default {
                [Console]::WriteLine("  >> merge rejected -- back to the review menu")
                return "menu"
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Review choices -- what each one does. Applies to Prompt-DiffReview,
# Deploy-ManagedFile and Review-JsonFields below (bash twins:
# prompt_diff_review, deploy_managed_file, review_json_fields). Spec:
# reference/managed-file-deployment.md. Model and AI merge rules:
# .claude/rules/agentic-standards.md "Managed-file review choices and merge".
#
# Terms:
#   SOURCE       the content being deployed (repo or dotprofile); the source
#                of truth
#   LOCAL        the deployed file on disk
#   ADOPT TARGET the repo file SOURCE comes from (-AdoptPath). The caller
#                passes its path; this library writes it. "" = no adopt
#                target: adopt and merge are not offered.
# There is no ancestor and no deploy state: the only comparison is SOURCE
# against LOCAL (trailing newlines normalized, case-sensitive).
#
# No menu is shown when:
#   LOCAL missing                       -> SOURCE written, "created"
#   LOCAL == SOURCE                     -> nothing written, "verified"
#   no console, EOF, or AITOOLS_FORCE   -> SOURCE written (backup), "updated"
#
# Text files (DestPath not ending in .json), one review per file:
#   [o]verwrite      -> SOURCE written to LOCAL (backup kept); "updated"
#   [a]ccept & adopt -> LOCAL kept; LOCAL copied to the adopt target now;
#                       "accept & adopt"
#   [m]erge & adopt  -> AI merge (Invoke-AiMerge: Invoke-AI balanced/none,
#                       validated, previewed; [y]es / [r]efine / [n]o). [y]:
#                       the merge is written to LOCAL and to the adopt target
#                       now; "accept & adopt". [n]: back to this menu. No valid
#                       merge output: nothing written; "failed".
#   [s]kip           -> nothing written; "skipped"; reviewed again next run
#   [x]abort         -> LogError, exit 2: ends this script
# After adopt or merge, SOURCE, LOCAL and the adopt target agree, so the next
# run verifies the file and asks nothing. A caller whose adopt target is not a
# plain copy of LOCAL (CLAUDE.md: machine footer stripped, profile tokens
# restored) passes -AdoptFilter; the adopt target gets the filtered content.
#
# JSON files (DestPath ending in .json; Review-JsonFields): node compares
# SOURCE and LOCAL field by field (key path; a whole array is one field). Each
# differing field is one Prompt-JsonFieldReview: [o]verwrite (SOURCE value to
# LOCAL), [a]dopt (LOCAL value to the adopt target), [s]kip, [x]abort. No
# merge. A field only in LOCAL stays in LOCAL: with an adopt target and a
# console it gets [a]dopt / [s]kip / [x]abort (no overwrite); otherwise it is
# kept without a prompt. Key order is preserved in both files. One result per
# file, by precedence: failed > accept & adopt > skipped > updated > verified.
#
# Failure: every file a step writes (LOCAL, and the adopt target for adopt or
# merge) is snapshotted and backed up first (a failed backup of an existing
# file fails the step: nothing written) and validated after (non-empty; JSON
# parses and keeps SOURCE's top-level keys, except keys the review chose to
# leave absent). If a write, the merge or a validation fails, the files are
# restored, the reason is logged (LogError), the result is "failed" (the
# caller records it; Write-DeployTrackerSummary writes an ERROR row) and the
# run continues with the next file. An adopt target listed in its repo's
# protected-files table (.claude/rules/sources-of-truth.md) gets a WARN that
# names it: working tree only; the review gate applies at commit. The library
# never commits or pushes: after adopt or merge it logs that the adopt
# target's repo has an uncommitted change to review and ship.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Review diff shown by Prompt-DiffReview: LOCAL -> SOURCE, unified format.
# "-" lines are only on this machine, "+" lines only in the repo, so the diff
# reads as what [o]verwrite changes here. The hunks come from
# `git diff --no-index` (the same engine and options as _review_diff in
# aitools-lib.sh, so PS1 and bash print identical hunks); its own headers are
# replaced by:
#   --- this machine  <LOCAL path>
#   +++ repo          <SOURCE path, or "source (embedded)" when there is none>
# Spec: reference/managed-file-deployment.md "Diff Mechanism Detail".
# git's output is read as UTF-8 straight from the process stream (never
# through the PowerShell pipeline; see .claude/rules/interactive-menus.md
# "Encoding").
#
# Params: -LocalContent, -SourceContent, -LocalLabel (header), -SourceLabel
# (header; "" -> "source (embedded)").
# Sets $script:ReviewDiffLines (plain text, no colour; empty when git reports
# no line difference) and returns $true. Returns $false when the diff cannot
# be produced, with the reason in $script:ReviewDiffError; the caller logs it.
# ---------------------------------------------------------------------------
$script:ReviewDiffLines = @()
$script:ReviewDiffError = ""
function Get-ReviewDiff {
    param(
        [string]$LocalContent,
        [string]$SourceContent,
        [string]$LocalLabel,
        [string]$SourceLabel = ""
    )
    $script:ReviewDiffLines = @()
    $script:ReviewDiffError = ""
    if (-not $SourceLabel) { $SourceLabel = "source (embedded)" }

    $utf8 = [Text.UTF8Encoding]::new($false)
    $tmpDir = Join-Path ([IO.Path]::GetTempPath()) ("aitools-diff-" + [guid]::NewGuid().ToString("N"))
    $raw = ""
    try {
        New-Item -ItemType Directory -Path $tmpDir -ErrorAction Stop | Out-Null
        $localFile = Join-Path $tmpDir "local"
        $sourceFile = Join-Path $tmpDir "source"
        # Same bytes as the bash twin: trailing newlines normalized to one LF.
        [IO.File]::WriteAllText($localFile, (($LocalContent -replace '[\r\n]+$', '') + "`n"), $utf8)
        [IO.File]::WriteAllText($sourceFile, (($SourceContent -replace '[\r\n]+$', '') + "`n"), $utf8)

        $psi = [Diagnostics.ProcessStartInfo]::new("git")
        foreach ($a in @("-c", "core.quotePath=false", "diff", "--no-index", "--no-color",
                "--no-ext-diff", "--no-textconv", "--diff-algorithm=myers",
                "--indent-heuristic", "-U3", "--", $localFile, $sourceFile)) {
            $psi.ArgumentList.Add($a)
        }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = $utf8
        $psi.StandardErrorEncoding = $utf8
        $proc = [Diagnostics.Process]::Start($psi)
        $errTask = $proc.StandardError.ReadToEndAsync()
        $raw = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        $err = $errTask.Result
        # git diff exits 1 when the files differ (expected) and >1 on error.
        if ($proc.ExitCode -gt 1) {
            $detail = if ($err) { $err.Trim() } else { "no output" }
            $script:ReviewDiffError = "git diff failed (exit $($proc.ExitCode)): $detail"
            return $false
        }
    } catch {
        $script:ReviewDiffError = "git diff failed: $_"
        return $false
    } finally {
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: temp directory cleanup; nothing depends on it
    }

    # Drop git's own header lines (everything before the first hunk).
    $lines = @($raw -split "`n")
    if ($lines.Count -gt 0 -and $lines[-1] -eq "") { $lines = @($lines | Select-Object -SkipLast 1) }
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith("@@ ")) { $start = $i; break }
    }
    if ($start -lt 0) { return $true }
    $script:ReviewDiffLines = @("--- this machine  $LocalLabel", "+++ repo          $SourceLabel") + @($lines[$start..($lines.Count - 1)])
    return $true
}

# Colour for the review diff: on unless NO_COLOR is set or TERM is "dumb".
# Only called on an interactive console; the deploy log never gets colour.
function Test-ReviewColour {
    return (-not $env:NO_COLOR -and $env:TERM -ne "dumb")
}

# ---------------------------------------------------------------------------
# Show SOURCE against LOCAL and ask what to do ("Review choices" above).
#
# Params: -FilePath (LOCAL), -NewContent (SOURCE), -AdoptOffered ($true offers
# [a]ccept & adopt and [m]erge & adopt), -CurrentContent (optional; read from
# FilePath when empty).
# Returns "overwrite", "adopt", "merge", "skip" or "failed"; "merge" also sets
# $script:MergedContent; "failed" (the AI merge produced no valid output) sets
# $script:ManagedMergeError. Exits 2 on [x]abort (Invoke-ManagedAbort).
# Non-interactive, EOF at the prompt, -Force / AITOOLS_FORCE: "overwrite".
# ---------------------------------------------------------------------------
$script:MergedContent = $null
$script:PdrAdoptTarget = ""   # set by Deploy-ManagedFile; shown in the review header only
function Prompt-DiffReview {
    param(
        [string]$FilePath,
        [string]$NewContent,
        [bool]$AdoptOffered = $false,
        [string]$CurrentContent = ""
    )

    $script:MergedContent = $null

    # -Force or AITOOLS_FORCE: auto-overwrite
    if ($env:AITOOLS_FORCE -eq "1" -or $Force) {
        LogWarn "Diff in $FilePath -- overwriting (-Force)"
        return "overwrite"
    }

    # Non-interactive: auto-overwrite
    if (-not (Test-InteractiveConsole)) {
        LogWarn "Diff in $FilePath -- overwriting (non-interactive)"
        return "overwrite"
    }

    # Read current file if not provided
    if (-not $CurrentContent) {
        try {
            $CurrentContent = Get-Content $FilePath -Raw -ErrorAction Stop
        } catch {
            LogWarn "Cannot read $FilePath for diff: $_"
            return "overwrite"
        }
    }

    # Context header
    [Console]::WriteLine("")
    [Console]::WriteLine("[REVIEW] $FilePath differs from source.")
    [Console]::WriteLine("  source = the repo version (would deploy)")
    [Console]::WriteLine("  local  = current file on disk")
    if ($AdoptOffered -and $script:PdrAdoptTarget) {
        [Console]::WriteLine("  repo   = $($script:PdrAdoptTarget) (adopt target)")
    }
    [Console]::WriteLine("")

    # AI merge input ([m]erge & adopt): Compare-Object listing, unchanged from
    # before the display change; the display below does not use it.
    $srcLines = @($NewContent -split "`n")
    $curLines = @($CurrentContent -split "`n")
    $diffs = Compare-Object $srcLines $curLines -CaseSensitive
    $diffOutput = ""
    if ($diffs) {
        $diffLines = @()
        foreach ($d in $diffs) {
            $prefix = if ($d.SideIndicator -eq "=>") { "+ " } else { "- " }
            $diffLines += "${prefix}$($d.InputObject)"
        }
        $diffOutput = $diffLines -join "`n"
    }

    # Show the review diff: LOCAL -> SOURCE (Get-ReviewDiff). Parity:
    # prompt_diff_review in aitools-lib.sh prints the same lines.
    $esc = [char]27
    $useColour = Test-ReviewColour
    $adoptLabel = if ($script:PdrAdoptTarget) { $script:PdrAdoptTarget } else { "the repo" }
    $srcLabel = if ($script:PdrAdoptTarget) { $script:PdrAdoptTarget } else { "" }
    if ($useColour) {
        [Console]::WriteLine("  $esc[31mred -$esc[0m = only on this machine   $esc[32mgreen +$esc[0m = only in the repo")
    } else {
        [Console]::WriteLine("  red - = only on this machine   green + = only in the repo")
    }
    [Console]::WriteLine("")
    $leafName = Split-Path -Leaf $FilePath
    if (-not (Get-ReviewDiff -LocalContent $CurrentContent -SourceContent $NewContent -LocalLabel $FilePath -SourceLabel $srcLabel)) {
        LogWarn "Review diff unavailable for ${FilePath}: $($script:ReviewDiffError)"
        [Console]::WriteLine("  (diff unavailable -- see deploy log)")
    } elseif ($script:ReviewDiffLines.Count -eq 0) {
        [Console]::WriteLine("  (whitespace-only differences)")
    } else {
        $all = $script:ReviewDiffLines
        $shown = if ($all.Count -gt 40) { $all[0..29] } else { $all }
        foreach ($line in $shown) {
            if ($useColour -and $line.StartsWith("-")) {
                [Console]::WriteLine("$esc[31m$line$esc[0m")
            } elseif ($useColour -and $line.StartsWith("+")) {
                [Console]::WriteLine("$esc[32m$line$esc[0m")
            } else {
                [Console]::WriteLine($line)
            }
        }
        if ($all.Count -gt 40) {
            [Console]::WriteLine("  ... ($($all.Count - 30) more lines -- full diff in deploy log)")
        }
        # Full diff as [detail] records at every size, plain text (the console truncates at 30).
        foreach ($dl in $all) { LogDetail "diff ${leafName}: $dl" }
    }

    # Menu (parity: prompt_diff_review in aitools-lib.sh). Each line says what
    # the choice does to the lines shown. A rejected merge preview ("menu")
    # shows the menu again.
    while ($true) {
        [Console]::WriteLine("")
        [Console]::WriteLine("  [o]verwrite       : this machine gets the green + lines (backup kept)")
        if ($AdoptOffered) {
            [Console]::WriteLine("  [a]ccept & adopt  : the repo gets the red - lines (your version) -> $adoptLabel")
            [Console]::WriteLine("  [m]erge & adopt   : AI combines both; written to this machine and $adoptLabel")
        }
        [Console]::WriteLine("  [s]kip            : nothing written; asked again next run")
        [Console]::WriteLine("  [x]abort          : stop this script (exit 2)")
        if ($AdoptOffered) {
            [Console]::Write("  choice [o/a/m/s/x]: ")
        } else {
            [Console]::Write("  choice [o/s/x]: ")
        }

        $choice = Read-ConsoleChoice "overwrite"
        switch ($choice.ToLower()) {
            "a" {
                if ($AdoptOffered) {
                    [Console]::WriteLine("  >> accept & adopt: local kept, copied to the repo")
                    return "adopt"
                }
                [Console]::WriteLine("  >> overwritten: source deployed to local (backup kept)")
                return "overwrite"
            }
            "m" {
                if ($AdoptOffered) {
                    $mergeResult = Invoke-AiMerge -FilePath $FilePath -SourceContent $NewContent -LocalContent $CurrentContent -DiffOutput $diffOutput
                    if ($mergeResult -ne "menu") { return $mergeResult }
                } else {
                    [Console]::WriteLine("  >> overwritten: source deployed to local (backup kept)")
                    return "overwrite"
                }
            }
            "s" {
                [Console]::WriteLine("  >> skipped: local file unchanged")
                return "skip"
            }
            "x" {
                Invoke-ManagedAbort
            }
            default {
                [Console]::WriteLine("  >> overwritten: source deployed to local (backup kept)")
                return "overwrite"
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Deploy one managed file. SOURCE is the source of truth ("Review choices"
# above Prompt-DiffReview). Parity: deploy_managed_file in aitools-lib.sh.
#
# Params:
#   -Content      content to deploy (SOURCE)
#   -DestPath     deployed path (LOCAL). A name ending in .json is reviewed
#                 field by field (Review-JsonFields).
#   -ToolName     summary tool name (e.g. "claude rules")
#   -ItemName     item name for log lines (e.g. "concurrent-agents.md")
#   -AdoptPath    absolute path of the repo file that is the source of truth;
#                 "" = adopt and merge are not offered
#   -AdoptFilter  optional, text files only: scriptblock that takes LOCAL
#                 content and returns the content the adopt target gets
#                 (e.g. CLAUDE.md strips its machine footer). $null = copy.
#
# Returns "created", "updated", "verified", "accept & adopt", "skipped" or
# "failed". On "failed" nothing is left half-written (snapshots restored) and
# the reason is logged with LogError; the caller records the outcome
# (Record-DeployOutcome, or its own ERROR row). Exits 2 on [x]abort.
# Honors $DryRun (reports, writes nothing).
# ---------------------------------------------------------------------------
function Deploy-ManagedFile {
    param(
        [string]$Content,
        [string]$DestPath,
        [string]$ToolName,
        [string]$ItemName,
        [string]$AdoptPath = "",
        [scriptblock]$AdoptFilter = $null
    )

    Write-ManagedStateNotice

    # Normalize trailing newlines for a stable comparison (parity with the bash
    # twin); every write adds exactly one back.
    $Content = $Content -replace '[\r\n]+$', ''

    # Dry run: report what would happen without writing
    if ($DryRun) {
        if (Test-Path -LiteralPath $DestPath) {
            try {
                $existing = Get-Content -LiteralPath $DestPath -Raw -ErrorAction Stop
            } catch {
                LogWarn "Cannot read $DestPath for the dry-run comparison: $_"
                $existing = ""
            }
            $existing = "$existing" -replace '[\r\n]+$', ''
            if ($existing -ceq $Content) {
                Log "[DRY RUN] Unchanged: $ItemName"
            } else {
                Log "[DRY RUN] Would update: $ItemName -> $DestPath"
            }
        } else {
            Log "[DRY RUN] Would create: $ItemName -> $DestPath"
        }
        return "verified"
    }

    # JSON: field-by-field review
    if ($DestPath -like '*.json') {
        $srcTmp = $null
        try {
            $srcTmp = [IO.Path]::GetTempFileName()
            [IO.File]::WriteAllText($srcTmp, "$Content`n", [System.Text.UTF8Encoding]::new($false))
        } catch {
            LogError "Failed: ${ItemName}: could not write a temp file for the JSON review: $_"
            if ($srcTmp) {
                Remove-Item -LiteralPath $srcTmp -Force -ErrorAction SilentlyContinue
                # ErrorAction exempt: temp file cleanup; the failure is already reported
            }
            return "failed"
        }
        $jsonResult = Review-JsonFields -SourceFile $srcTmp -DestPath $DestPath -AdoptPath $AdoptPath
        Remove-Item -LiteralPath $srcTmp -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: temp file cleanup; nothing depends on it
        return $jsonResult
    }

    # New file: create
    if (-not (Test-Path -LiteralPath $DestPath -PathType Leaf)) {
        if (Write-ManagedFiles -LocalPath $DestPath -LocalContent $Content) {
            LogOk "Created: $ItemName -> $DestPath"
            return "created"
        }
        LogError "Failed: ${ItemName}: $($script:ManagedWriteError)"
        return "failed"
    }

    try {
        $existing = Get-Content -LiteralPath $DestPath -Raw -ErrorAction Stop
    } catch {
        LogError "Failed: ${ItemName}: cannot read ${DestPath}: $_"
        return "failed"
    }
    $existing = "$existing" -replace '[\r\n]+$', ''
    if ($existing -ceq $Content) {
        return "verified"
    }

    # LOCAL differs from SOURCE: review (non-interactive / EOF / -Force -> overwrite)
    $script:PdrAdoptTarget = $AdoptPath
    $choice = Prompt-DiffReview -FilePath $DestPath -NewContent $Content `
        -AdoptOffered ([bool]$AdoptPath) -CurrentContent $existing
    $script:PdrAdoptTarget = ""

    if ($choice -eq "skip") {
        LogWarn "Skipped: $ItemName (local differs from source; reviewed again next run)"
        return "skipped"
    }
    if ($choice -eq "failed") {
        $mergeReason = if ($script:ManagedMergeError) { $script:ManagedMergeError } else { "AI merge failed" }
        LogError "Failed: ${ItemName}: $mergeReason -- nothing written"
        return "failed"
    }

    $localPath = $DestPath
    $localOut = $Content
    $repoPath = ""
    $repoContent = ""
    if ($choice -eq "adopt") {
        $localPath = ""
        $localOut = ""
        $repoPath = $AdoptPath
        $repoContent = $existing
    } elseif ($choice -eq "merge") {
        $localOut = "$($script:MergedContent)" -replace '[\r\n]+$', ''
        $repoPath = $AdoptPath
        $repoContent = $localOut
    }

    # The adopt target gets LOCAL (or the merge), passed through the filter if any
    if ($repoPath -and $AdoptFilter) {
        try {
            $filtered = (& $AdoptFilter $repoContent) -join "`n"
        } catch {
            LogError "Failed: ${ItemName}: adopt filter failed -- nothing written: $_"
            return "failed"
        }
        if ([string]::IsNullOrEmpty($filtered)) {
            LogError "Failed: ${ItemName}: adopt filter returned nothing -- nothing written"
            return "failed"
        }
        $repoContent = $filtered -replace '[\r\n]+$', ''
    }

    if (-not (Write-ManagedFiles -LocalPath $localPath -LocalContent $localOut -AdoptPath $repoPath -AdoptContent $repoContent)) {
        LogError "Failed: ${ItemName}: $($script:ManagedWriteError) (files restored)"
        return "failed"
    }

    if ($repoPath) {
        LogOk "Accept & adopt: $ItemName -> $repoPath"
        Write-ManagedAdoptNotice -Target $repoPath
        return "accept & adopt"
    }
    LogOk "Updated: $ItemName -> $DestPath"
    return "updated"
}

# ---------------------------------------------------------------------------
# Review a JSON managed file field by field ("Review choices" above).
# Parity: review_json_fields in aitools-lib.sh (same embedded node script).
#
# Params: -SourceFile (file holding the SOURCE JSON), -DestPath (LOCAL JSON),
# -AdoptPath (repo JSON file that is the source of truth; "" = no adopt).
# Returns one result per file by precedence failed > accept & adopt > skipped
# > updated > verified: "created" (LOCAL was missing), "failed" (files
# restored, LogError), "accept & adopt" (a field was adopted into AdoptPath;
# overwrites chosen in the same run are written too), "skipped" (a field was
# left differing), "updated" (fields overwritten from SOURCE), "verified"
# (nothing written). Requires node. Exits 2 on [x]abort.
# ---------------------------------------------------------------------------
$script:ReviewJsonNode = @'
// review_json_fields / Review-JsonFields: SOURCE against LOCAL, field by field.
// The same text is embedded in aitools-lib.sh and aitools-lib.ps1: keep them identical.
//   plan  SRC LOCAL OUT_PLAN
//     OUT_PLAN: one line per differing field: idx<TAB>kind<TAB>key<TAB>local<TAB>source
//     kind: differ | source-only | local-only. A whole array is one field.
//   apply SRC LOCAL ADOPT CHOICES OUT_LOCAL OUT_ADOPT OUT_RESULT OUT_REQ_LOCAL OUT_REQ_ADOPT
//     ADOPT: the adopt target, or "-" for none.
//     CHOICES: idx<TAB>overwrite|adopt|skip|keep per field (missing = skip).
//     OUT_LOCAL / OUT_ADOPT: new file content, or empty when that file is unchanged.
//     OUT_RESULT: "over=N adopt=N skip=N kept=N".
//     OUT_REQ_LOCAL / OUT_REQ_ADOPT: JSON array of SOURCE's top-level keys the
//     written file must keep (keys the review chose to leave absent excluded).
//   keys  SRC OUT_KEYS
//     OUT_KEYS: JSON array of SOURCE's top-level keys ([] when not an object).
// Key order is preserved: existing keys keep their position, new keys are appended.
// Exit 3 with the reason on stderr when a file cannot be read or parsed.
const fs = require('fs');
const mode = process.argv[2];
function readJson(p, label) {
    let text;
    try { text = fs.readFileSync(p, 'utf8'); }
    catch (e) {
        if (e.code === 'ENOENT') return undefined;
        throw new Error(label + ': cannot read ' + p + ': ' + e.message);
    }
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
    try { return JSON.parse(text); }
    catch (e) { throw new Error(label + ': ' + p + ' is not valid JSON: ' + e.message); }
}
function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
function canon(v) {
    if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
    if (isObj(v)) return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
    return JSON.stringify(v);
}
function fields(src, loc) {
    const out = [];
    if (!isObj(src) || !isObj(loc)) {
        if (canon(src) !== canon(loc)) out.push({ path: [], kind: 'differ', s: src, l: loc });
        return out;
    }
    (function walk(s, l, path) {
        const keys = Object.keys(s).concat(Object.keys(l).filter(k => !has(s, k)));
        for (const k of keys) {
            const p = path.concat([k]);
            const inS = has(s, k), inL = has(l, k);
            if (inS && inL) {
                if (isObj(s[k]) && isObj(l[k])) walk(s[k], l[k], p);
                else if (canon(s[k]) !== canon(l[k])) out.push({ path: p, kind: 'differ', s: s[k], l: l[k] });
            } else if (inS) {
                out.push({ path: p, kind: 'source-only', s: s[k] });
            } else {
                out.push({ path: p, kind: 'local-only', l: l[k] });
            }
        }
    })(src, loc, []);
    return out;
}
function disp(v) {
    if (v === undefined) return '(absent)';
    let t = JSON.stringify(v);
    if (t.length > 200) t = t.slice(0, 197) + '...';
    return t;
}
function clean(t) { return String(t).replace(/[\t\r\n]/g, ' '); }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }
function setPath(obj, path, val) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) o[path[i]] = {};
        o = o[path[i]];
    }
    o[path[path.length - 1]] = val;
}
function delPath(obj, path) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) return;
        o = o[path[i]];
    }
    delete o[path[path.length - 1]];
}
function keptKeys(src, obj) {
    if (!isObj(src) || !isObj(obj)) return [];
    return Object.keys(src).filter(k => has(obj, k));
}
try {
    const src = readJson(process.argv[3], 'source');
    if (src === undefined) throw new Error('source: ' + process.argv[3] + ' not found');
    if (mode === 'keys') {
        fs.writeFileSync(process.argv[4], JSON.stringify(isObj(src) ? Object.keys(src) : []) + '\n');
        process.exit(0);
    }
    const loc = readJson(process.argv[4], 'local');
    if (loc === undefined) throw new Error('local: ' + process.argv[4] + ' not found');
    const list = fields(src, loc);
    if (mode === 'plan') {
        const lines = list.map((f, i) => [i, f.kind, f.path.length ? clean(f.path.join('.')) : '(document)',
            clean(disp(f.l)), clean(disp(f.s))].join('\t'));
        fs.writeFileSync(process.argv[5], lines.length ? lines.join('\n') + '\n' : '');
    } else if (mode === 'apply') {
        const adoptPath = (process.argv[5] && process.argv[5] !== '-') ? process.argv[5] : '';
        const choices = {};
        for (const line of fs.readFileSync(process.argv[6], 'utf8').split(/\r?\n/)) {
            const m = /^(\d+)\t(\w+)$/.exec(line);
            if (m) choices[m[1]] = m[2];
        }
        let newLocal = clone(loc);
        let adoptObj;
        if (adoptPath) {
            adoptObj = readJson(adoptPath, 'adopt target');
            if (adoptObj === undefined) adoptObj = clone(src);
        }
        let over = 0, adopt = 0, skip = 0, kept = 0;
        list.forEach((f, i) => {
            const c = choices[String(i)] || 'skip';
            if (c === 'adopt' && adoptPath) {
                adopt++;
                if (f.path.length === 0) adoptObj = clone(f.l);
                else if (f.kind === 'source-only') delPath(adoptObj, f.path);
                else setPath(adoptObj, f.path, clone(f.l));
            } else if (c === 'overwrite' && f.kind !== 'local-only') {
                over++;
                if (f.path.length === 0) newLocal = clone(f.s);
                else setPath(newLocal, f.path, clone(f.s));
            } else if (f.kind === 'local-only' && c !== 'skip') {
                kept++;
            } else {
                skip++;
            }
        });
        fs.writeFileSync(process.argv[7], over ? JSON.stringify(newLocal, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[8], adopt ? JSON.stringify(adoptObj, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[9], 'over=' + over + ' adopt=' + adopt + ' skip=' + skip + ' kept=' + kept + '\n');
        fs.writeFileSync(process.argv[10], JSON.stringify(keptKeys(src, newLocal)) + '\n');
        fs.writeFileSync(process.argv[11], JSON.stringify(adoptPath ? keptKeys(src, adoptObj) : []) + '\n');
    } else {
        throw new Error('unknown mode: ' + mode);
    }
} catch (e) {
    process.stderr.write(String((e && e.message) || e) + '\n');
    process.exit(3);
}
'@
function Review-JsonFields {
    param(
        [string]$SourceFile,
        [string]$DestPath,
        [string]$AdoptPath = ""
    )
    $item = Split-Path -Leaf $DestPath

    # Get-Command exempt: command-existence check with explicit failure branch
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        LogError "Failed: ${item}: node is required for the JSON field review"
        return "failed"
    }

    $work = Join-Path ([IO.Path]::GetTempPath()) ("aitools-jf-" + [guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $work -Force -ErrorAction Stop | Out-Null
        $js = Join-Path $work "review.js"
        [IO.File]::WriteAllText($js, $script:ReviewJsonNode, [System.Text.UTF8Encoding]::new($false))
    } catch {
        LogError "Failed: ${item}: could not create a work directory for the JSON review: $_"
        return "failed"
    }
    $destResolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestPath)

    # node writes every output file itself (UTF-8), so nothing passes through
    # the console encoding (cross-platform-detail.md "PowerShell pipeline encoding").
    if (-not (Test-Path -LiteralPath $DestPath -PathType Leaf)) {
        $keysFile = Join-Path $work "keys.json"
        $nodeErr = & node $js keys $SourceFile $keysFile 2>&1
        $keysRc = $LASTEXITCODE
        try {
            if ($keysRc -ne 0) { throw "node exit ${keysRc}: $nodeErr" }
            $srcJson = [IO.File]::ReadAllText($SourceFile, [Text.Encoding]::UTF8) -replace '[\r\n]+$', ''
            $reqKeys = [IO.File]::ReadAllText($keysFile, [Text.Encoding]::UTF8).Trim()
        } catch {
            LogError "Failed: ${item}: cannot read the source JSON: $_"
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
            # ErrorAction exempt: work directory cleanup; the failure is already reported
            return "failed"
        }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: work directory cleanup; nothing depends on it
        if (Write-ManagedFiles -LocalPath $DestPath -LocalContent $srcJson -LocalRequiredKeys $reqKeys) {
            LogOk "Created: $item -> $DestPath"
            return "created"
        }
        LogError "Failed: ${item}: $($script:ManagedWriteError)"
        return "failed"
    }

    $planFile = Join-Path $work "plan.tsv"
    $nodeErr = & node $js plan $SourceFile $destResolved $planFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        LogError "Failed: ${item}: field comparison failed (node exit $LASTEXITCODE): $nodeErr"
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: work directory cleanup; the failure is already reported
        return "failed"
    }
    $planLines = @([IO.File]::ReadAllLines($planFile, [Text.Encoding]::UTF8) | Where-Object { $_ })
    if ($planLines.Count -eq 0) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: work directory cleanup; nothing depends on it
        return "verified"
    }

    # One review per differing field
    $adoptOk = if ($AdoptPath) { "1" } else { "0" }
    $canPrompt = ($env:AITOOLS_FORCE -ne "1") -and (-not $Force) -and (Test-InteractiveConsole)
    $choices = [System.Collections.Generic.List[string]]::new()
    foreach ($pl in $planLines) {
        $f = $pl -split "`t"
        $idx = $f[0]; $kind = $f[1]; $key = $f[2]; $lDisp = $f[3]; $sDisp = $f[4]
        if ($kind -eq "local-only") {
            # A field only in LOCAL: [a]dopt / [s]kip / [x]abort, no overwrite.
            # Without an adopt target or a console it is kept, no prompt.
            if ($adoptOk -eq "1" -and $canPrompt) {
                $choice = Prompt-JsonFieldReview -Leaf $key -Current $lDisp -Proposed "(not in source)" `
                    -SourceLabel "source" -AdoptAllowed "1" -LocalLabel "local" -OverwriteAllowed "0"
            } else {
                LogDetail "${item}: $key only in local -- kept"
                $choice = "keep"
            }
        } else {
            $choice = Prompt-JsonFieldReview -Leaf $key -Current $lDisp -Proposed $sDisp `
                -SourceLabel "source" -AdoptAllowed $adoptOk -LocalLabel "local"
        }
        $choices.Add("$idx`t$choice")
    }
    $choicesFile = Join-Path $work "choices.tsv"
    $localOutFile = Join-Path $work "local.out"
    $adoptOutFile = Join-Path $work "adopt.out"
    $resultFile = Join-Path $work "result.txt"
    $reqLocalFile = Join-Path $work "req-local.json"
    $reqAdoptFile = Join-Path $work "req-adopt.json"
    try {
        [IO.File]::WriteAllText($choicesFile, (($choices -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
    } catch {
        LogError "Failed: ${item}: could not record the field choices: $_"
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: work directory cleanup; the failure is already reported
        return "failed"
    }

    # "-" = no adopt target (an empty argument can be dropped by native-argument passing)
    $adoptArg = if ($AdoptPath) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($AdoptPath) } else { "-" }
    $nodeErr = & node $js apply $SourceFile $destResolved $adoptArg $choicesFile $localOutFile $adoptOutFile $resultFile $reqLocalFile $reqAdoptFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        LogError "Failed: ${item}: applying the field choices failed (node exit $LASTEXITCODE): $nodeErr"
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: work directory cleanup; the failure is already reported
        return "failed"
    }
    try {
        $counts = [IO.File]::ReadAllText($resultFile, [Text.Encoding]::UTF8).Trim()
        $cLocal = [IO.File]::ReadAllText($localOutFile, [Text.Encoding]::UTF8) -replace '[\r\n]+$', ''
        $cAdopt = [IO.File]::ReadAllText($adoptOutFile, [Text.Encoding]::UTF8) -replace '[\r\n]+$', ''
        $rLocal = [IO.File]::ReadAllText($reqLocalFile, [Text.Encoding]::UTF8).Trim()
        $rAdopt = [IO.File]::ReadAllText($reqAdoptFile, [Text.Encoding]::UTF8).Trim()
    } catch {
        LogError "Failed: ${item}: could not read the field review result: $_"
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        # ErrorAction exempt: work directory cleanup; the failure is already reported
        return "failed"
    }
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    # ErrorAction exempt: work directory cleanup; nothing depends on it
    LogDetail "${item}: field review $counts"
    $nOver = 0; $nAdopt = 0; $nSkip = 0
    if ($counts -match 'over=(\d+)') { $nOver = [int]$Matches[1] }
    if ($counts -match 'adopt=(\d+)') { $nAdopt = [int]$Matches[1] }
    if ($counts -match 'skip=(\d+)') { $nSkip = [int]$Matches[1] }

    $pLocal = if ($cLocal) { $DestPath } else { "" }
    $pAdopt = if ($cAdopt) { $AdoptPath } else { "" }
    if ($pLocal -or $pAdopt) {
        if (-not (Write-ManagedFiles -LocalPath $pLocal -LocalContent $cLocal -AdoptPath $pAdopt -AdoptContent $cAdopt `
                -LocalRequiredKeys $rLocal -AdoptRequiredKeys $rAdopt)) {
            LogError "Failed: ${item}: $($script:ManagedWriteError) (files restored)"
            return "failed"
        }
    }
    if ($nOver -gt 0) {
        LogOk "Updated: $item -> $DestPath ($nOver field(s) from source)"
    }
    if ($nAdopt -gt 0) {
        LogOk "Accept & adopt: $item -> $AdoptPath ($nAdopt field(s))"
        Write-ManagedAdoptNotice -Target $AdoptPath
    }
    if ($nSkip -gt 0) {
        LogWarn "Skipped: $item ($nSkip field(s) differ from source; reviewed again next run)"
    }
    if ($nAdopt -gt 0) { return "accept & adopt" }
    if ($nSkip -gt 0) { return "skipped" }
    if ($nOver -gt 0) { return "updated" }
    return "verified"
}

# ---------------------------------------------------------------------------
# Write an adopted file back to its source-of-truth target(s).
#
# Companion to Deploy-ManagedFile: when the diff review returns "accept & adopt",
# the local (deployed) file won and must propagate back to every canonical
# source it was deployed from -- e.g. the dotprofile AND the shared/ template.
# Centralizes the backup+rotate+copy+log that callers used to hand-roll, so all
# adopt paths behave identically.
#
# For each target: rotate a timestamped backup of the existing target (via
# Backup-File -- keeps 20, prunes oldest), ensure its parent dir, then copy the
# adopted content over it. Empty/null targets are skipped so callers may pass an
# optional path without branching.
#
# Returns the count of targets written.
# ---------------------------------------------------------------------------
function Adopt-ManagedFile {
    param(
        [Parameter(Mandatory)][string]$SourceFile,
        [string[]]$Targets
    )

    if (-not (Test-Path $SourceFile)) {
        LogError "Adopt-ManagedFile: adopted source not found: $SourceFile"
        return 0
    }

    $written = 0
    foreach ($target in $Targets) {
        if (-not $target) { continue }
        Backup-File -FilePath $target          # rotation; no-op if target absent
        $targetDir = Split-Path -Parent $target
        if ($targetDir -and -not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        try {
            Copy-Item -Path $SourceFile -Destination $target -Force -ErrorAction Stop
            LogOk "Adopted -> $target"
            $written++
        } catch {
            LogError "Adopt-ManagedFile: failed to write ${target}: $_"
        }
    }

    return $written
}

# ---------------------------------------------------------------------------
# Deploy tracker: centralizes outcome counting and summary writing for
# loops that deploy multiple managed files (rules, skills, hooks).
# ---------------------------------------------------------------------------

$script:dtAdded = 0; $script:dtUpdated = 0; $script:dtVerified = 0
$script:dtAccepted = 0; $script:dtSkipped = 0; $script:dtPreserved = 0; $script:dtFailed = 0
$script:deployTrackerText = ""

function Initialize-DeployTracker {
    $script:dtAdded = 0; $script:dtUpdated = 0; $script:dtVerified = 0
    $script:dtAccepted = 0; $script:dtSkipped = 0; $script:dtPreserved = 0; $script:dtFailed = 0
    $script:deployTrackerText = ""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
function Record-DeployOutcome {
    param([string]$Outcome, [string]$ToolName, [string]$ItemName)
    switch ($Outcome) {
        { $_ -eq "added" -or $_ -eq "created" } { $script:dtAdded++;     Write-Summary "DETAIL" $ToolName "added: $ItemName" }
        "updated"   { $script:dtUpdated++;   Write-Summary "DETAIL" $ToolName "updated: $ItemName" }
        "accept & adopt" { $script:dtAccepted++;  Write-Summary "DETAIL" $ToolName "accept & adopt: $ItemName" }
        "skipped"   { $script:dtSkipped++;   Write-Summary "DETAIL" $ToolName "skipped: $ItemName" }
        "failed"    { $script:dtFailed++;    Write-Summary "DETAIL" $ToolName "failed: $ItemName" }
        "verified"  { $script:dtVerified++ }
        "preserved" { $script:dtPreserved++ }
    }
}

# Write aggregate summary for a deploy loop. Uses non-zero counts.
# ERROR when any file failed, WARN when any was skipped, else OK.
function Write-DeployTrackerSummary {
    param([string]$ToolName)
    $parts = @()
    if ($script:dtAdded -gt 0)     { $parts += "$($script:dtAdded) added" }
    if ($script:dtUpdated -gt 0)   { $parts += "$($script:dtUpdated) updated" }
    if ($script:dtAccepted -gt 0)  { $parts += "$($script:dtAccepted) accepted" }
    if ($script:dtVerified -gt 0)  { $parts += "$($script:dtVerified) verified" }
    if ($script:dtFailed -gt 0)    { $parts += "$($script:dtFailed) failed" }
    $text = if ($parts.Count -gt 0) { $parts -join ", " } else { "verified" }
    $script:deployTrackerText = $text

    if ($script:dtFailed -gt 0) {
        Write-Summary "ERROR" $ToolName "$($script:dtFailed) failed"
    } elseif ($script:dtSkipped -gt 0) {
        Write-Summary "WARN" $ToolName "$($script:dtSkipped) skipped (user review)"
    } else {
        Write-Summary "OK" $ToolName $text
    }
}

# ---------------------------------------------------------------------------
# Granular per-leaf review prompt for JSON settings sync (Sync-ManagedJson)
# and the JSON field review (Review-JsonFields). Mirror of
# prompt_json_field_review in aitools-lib.sh. One prompt per divergent
# setting/rule. overwrite/adopt/skip are per-leaf; abort (x) exits (code 2).
# -LocalLabel names the local file's side (default "settings.json").
# -OverwriteAllowed "0" (a field only in the local file): no [o]verwrite, and
# the default answer is skip.
# Returns "overwrite", "adopt", or "skip".
# -Force / AITOOLS_FORCE / non-interactive -> "overwrite" (source wins), or
# "skip" when overwrite is not allowed.
# ---------------------------------------------------------------------------
function Prompt-JsonFieldReview {
    param(
        [string]$Leaf,
        [string]$Current,
        [string]$Proposed,
        [string]$SourceLabel = "profile.json",
        [string]$AdoptAllowed = "1",
        [string]$LocalLabel = "settings.json",
        [string]$OverwriteAllowed = "1"
    )

    $defaultChoice = "overwrite"
    $defaultDesc = "overwriting from $SourceLabel"
    if ($OverwriteAllowed -ne "1") {
        $defaultChoice = "skip"
        $defaultDesc = "skipping (only in $LocalLabel)"
    }

    if ($env:AITOOLS_FORCE -eq "1" -or $Force) {
        Log "Divergence in $Leaf -- $defaultDesc (--force)"
        return $defaultChoice
    }
    if (-not (Test-InteractiveConsole)) {
        Log "Divergence in $Leaf -- $defaultDesc (non-interactive)"
        return $defaultChoice
    }

    [Console]::WriteLine("")
    [Console]::WriteLine("[REVIEW] $Leaf differs from $SourceLabel.")
    [Console]::WriteLine("  ${LocalLabel} : $Current")
    [Console]::WriteLine("  ${SourceLabel} : $Proposed")
    [Console]::WriteLine("")
    if ($OverwriteAllowed -eq "1") {
        [Console]::WriteLine("  [o]verwrite : $SourceLabel value -> $LocalLabel")
    }
    if ($AdoptAllowed -eq "1") {
        [Console]::WriteLine("  [a]dopt     : keep $LocalLabel value -> write to $SourceLabel")
    }
    [Console]::WriteLine("  [s]kip      : leave this setting unchanged")
    [Console]::WriteLine("  [x]abort    : stop the run")
    if ($OverwriteAllowed -ne "1") {
        [Console]::Write("  choice [a/s/x]: ")
    } elseif ($AdoptAllowed -eq "1") {
        [Console]::Write("  choice [o/a/s/x]: ")
    } else {
        [Console]::Write("  choice [o/s/x]: ")
    }

    $choice = Read-ConsoleChoice $defaultDesc
    switch ($choice.ToLower()) {
        "a" {
            if ($AdoptAllowed -eq "1") {
                [Console]::WriteLine("  >> adopted: $LocalLabel value kept -> $SourceLabel")
                return "adopt"
            }
            if ($OverwriteAllowed -eq "1") {
                [Console]::WriteLine("  >> overwritten from $SourceLabel")
                return "overwrite"
            }
            [Console]::WriteLine("  >> skipped: $Leaf unchanged")
            return "skip"
        }
        "s" { [Console]::WriteLine("  >> skipped: $Leaf unchanged"); return "skip" }
        "x" { Invoke-ManagedAbort }
        default {
            if ($OverwriteAllowed -eq "1") {
                [Console]::WriteLine("  >> overwritten from $SourceLabel")
                return "overwrite"
            }
            [Console]::WriteLine("  >> skipped: $Leaf unchanged")
            return "skip"
        }
    }
}

# ---------------------------------------------------------------------------
# Generic settings.json <-> profile.json sync engine (mirror of
# sync_managed_json in aitools-lib.sh). Embeds the SAME node script so the
# JSON classification/apply logic is byte-identical across platforms.
#
# profile.json (under $SubPath, e.g. "claude.settings") is the source of truth
# for the live JSON file, EXCLUDING harness-managed keys (e.g. "hooks"). For
# every managed leaf (arbitrary keys; permissions per-rule across allow/ask/
# deny): live-only -> auto-adopt; equal -> no-op; differ/live-missing ->
# granular per-leaf prompt. Deprecated rules stripped before scan. Writes
# preserve key order. Both files backed up before write and validated after.
#
# Sets $script:SyncManagedJsonResult to "unchanged"/"updated"/"created".
# Requires node. Honors $DryRun. Exits 2 on user abort.
# ---------------------------------------------------------------------------
$script:SyncManagedJsonResult = ""
function Sync-ManagedJson {
    param(
        [string]$LiveFile,
        [string]$ProfileFile,
        [string]$SubPath,
        [string]$ExcludeKeys = "hooks",
        [string]$DeprecatedRules = ""
    )

    $script:SyncManagedJsonResult = "unchanged"

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        LogError "Sync-ManagedJson: node required for JSON sync"
        return
    }

    $ns = [System.IO.Path]::GetTempFileName()
    $planJson = [System.IO.Path]::GetTempFileName()
    $choicesTsv = [System.IO.Path]::GetTempFileName()

    $nodeScript = @'
const fs = require('fs');
const mode = process.argv[2];
const PERM_CATS = ['allow', 'ask', 'deny'];

function readJson(p) {
    try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
    catch (e) { if (e.code === 'ENOENT') return null; throw e; }
}
function jeq(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
function getSub(obj, parts) { let o = obj; for (const k of parts) { if (o == null || typeof o !== 'object') return undefined; o = o[k]; } return o; }
function ensureSub(obj, parts) { let o = obj; for (const k of parts) { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; o = o[k]; } return o; }
function setPath(obj, parts, val) { let o = obj; for (let i = 0; i < parts.length - 1; i++) { if (o[parts[i]] == null || typeof o[parts[i]] !== 'object') o[parts[i]] = {}; o = o[parts[i]]; } o[parts[parts.length - 1]] = val; }
function delPath(obj, parts) { let o = obj; for (let i = 0; i < parts.length - 1; i++) { if (o[parts[i]] == null) return; o = o[parts[i]]; } delete o[parts[parts.length - 1]]; }
function disp(v) { return v === undefined ? '(not in settings.json)' : JSON.stringify(v); }

function buildPlan(live, profile, subParts, excludeKeys, deprecated) {
    live = live || {};
    const mirror = getSub(profile, subParts) || {};
    const deprecatedRemoved = [];
    if (live.permissions) {
        for (const cat of PERM_CATS) {
            if (Array.isArray(live.permissions[cat])) {
                for (const r of live.permissions[cat]) if (deprecated.includes(r)) deprecatedRemoved.push({ cat, rule: r });
                live.permissions[cat] = live.permissions[cat].filter(r => !deprecated.includes(r));
            }
        }
    }
    const decisions = {}; const autoAdopts = [];
    const keys = new Set([...Object.keys(live), ...Object.keys(mirror)]);
    for (const k of excludeKeys) keys.delete(k);
    for (const k of keys) {
        if (k === 'permissions') {
            const lp = live.permissions || {}; const mp = mirror.permissions || {};
            const lHas = Object.prototype.hasOwnProperty.call(lp, 'defaultMode');
            const mHas = Object.prototype.hasOwnProperty.call(mp, 'defaultMode');
            if (lHas && !mHas) autoAdopts.push({ kind: 'scalar', path: ['permissions', 'defaultMode'], value: lp.defaultMode });
            else if (mHas && !lHas) decisions['permissions.defaultMode'] = { type: 'permScalar', path: ['permissions', 'defaultMode'], kind: 'live-missing', currentDisplay: disp(undefined), proposedDisplay: disp(mp.defaultMode), profileValue: mp.defaultMode };
            else if (lHas && mHas && !jeq(lp.defaultMode, mp.defaultMode)) decisions['permissions.defaultMode'] = { type: 'permScalar', path: ['permissions', 'defaultMode'], kind: 'differ', currentDisplay: disp(lp.defaultMode), proposedDisplay: disp(mp.defaultMode), liveValue: lp.defaultMode, profileValue: mp.defaultMode };
            for (const cat of PERM_CATS) {
                const lr = Array.isArray(lp[cat]) ? lp[cat] : [];
                const mr = Array.isArray(mp[cat]) ? mp[cat] : [];
                for (const rule of new Set([...lr, ...mr])) {
                    const inL = lr.includes(rule), inM = mr.includes(rule);
                    if (inL && !inM) autoAdopts.push({ kind: 'permRule', cat, rule });
                    else if (inM && !inL) decisions['permissions.' + cat + ' ' + rule] = { type: 'permRule', cat, rule, kind: 'live-missing', currentDisplay: '(not in settings.json)', proposedDisplay: 'rule present in profile.json' };
                }
            }
        } else {
            const lHas = Object.prototype.hasOwnProperty.call(live, k);
            const mHas = Object.prototype.hasOwnProperty.call(mirror, k);
            if (lHas && !mHas) autoAdopts.push({ kind: 'scalar', path: [k], value: live[k] });
            else if (mHas && !lHas) decisions[k] = { type: 'scalar', path: [k], kind: 'live-missing', currentDisplay: disp(undefined), proposedDisplay: disp(mirror[k]), profileValue: mirror[k] };
            else if (lHas && mHas && !jeq(live[k], mirror[k])) decisions[k] = { type: 'scalar', path: [k], kind: 'differ', currentDisplay: disp(live[k]), proposedDisplay: disp(mirror[k]), liveValue: live[k], profileValue: mirror[k] };
        }
    }
    return { decisions, autoAdopts, deprecatedRemoved };
}

const subParts = process.argv[5] ? process.argv[5].split('.') : [];
const excludeKeys = process.argv[6] ? process.argv[6].split(',').filter(Boolean) : [];
const deprecated = process.argv[7] ? process.argv[7].split(',').filter(Boolean) : [];

if (mode === 'plan') {
    const livePath = process.argv[3], profilePath = process.argv[4], planOut = process.argv[8];
    const live = readJson(livePath) || {};
    const profile = readJson(profilePath) || {};
    const plan = buildPlan(live, profile, subParts, excludeKeys, deprecated);
    fs.writeFileSync(planOut, JSON.stringify(plan));
    const lines = [];
    for (const [id, d] of Object.entries(plan.decisions)) {
        lines.push([id, d.kind, d.currentDisplay, d.proposedDisplay, '1'].join('\t'));
    }
    process.stdout.write(lines.length ? lines.join('\n') + '\n' : '');
    process.stderr.write('adopts=' + plan.autoAdopts.length + ' deprecated=' + plan.deprecatedRemoved.length + ' decisions=' + Object.keys(plan.decisions).length + '\n');
} else if (mode === 'apply') {
    const livePath = process.argv[3], profilePath = process.argv[4];
    const planPath = process.argv[8], choicesPath = process.argv[9];
    const plan = readJson(planPath);
    const live = readJson(livePath) || {};
    const profile = readJson(profilePath) || {};
    const mirror = ensureSub(profile, subParts);
    const origLive = JSON.stringify(live), origProfile = JSON.stringify(profile);

    for (const d of plan.deprecatedRemoved) {
        if (live.permissions && Array.isArray(live.permissions[d.cat])) {
            live.permissions[d.cat] = live.permissions[d.cat].filter(r => r !== d.rule);
        }
    }
    for (const a of plan.autoAdopts) {
        if (a.kind === 'scalar') setPath(mirror, a.path, a.value);
        else if (a.kind === 'permRule') {
            if (!mirror.permissions || typeof mirror.permissions !== 'object') mirror.permissions = {};
            const arr = Array.isArray(mirror.permissions[a.cat]) ? mirror.permissions[a.cat] : [];
            if (!arr.includes(a.rule)) arr.push(a.rule);
            mirror.permissions[a.cat] = arr;
        }
    }
    const choices = {};
    try {
        const raw = fs.readFileSync(choicesPath, 'utf8');
        for (const ln of raw.split('\n')) { if (!ln) continue; const i = ln.indexOf('\t'); if (i < 0) continue; choices[ln.slice(0, i)] = ln.slice(i + 1); }
    } catch (e) { if (e.code !== 'ENOENT') throw e; }
    for (const [id, action] of Object.entries(choices)) {
        const d = plan.decisions[id]; if (!d || action === 'skip') continue;
        if (d.type === 'scalar' || d.type === 'permScalar') {
            if (action === 'overwrite') setPath(live, d.path, d.profileValue);
            else if (action === 'adopt') { if (d.kind === 'live-missing') delPath(mirror, d.path); else setPath(mirror, d.path, d.liveValue); }
        } else if (d.type === 'permRule') {
            if (action === 'overwrite') {
                if (!live.permissions || typeof live.permissions !== 'object') live.permissions = {};
                const arr = Array.isArray(live.permissions[d.cat]) ? live.permissions[d.cat] : [];
                if (!arr.includes(d.rule)) arr.push(d.rule);
                live.permissions[d.cat] = arr;
            } else if (action === 'adopt') {
                if (mirror.permissions && Array.isArray(mirror.permissions[d.cat])) mirror.permissions[d.cat] = mirror.permissions[d.cat].filter(r => r !== d.rule);
            }
        }
    }
    if (live.permissions && typeof live.permissions === 'object') {
        for (const cat of PERM_CATS) if (Array.isArray(live.permissions[cat]) && live.permissions[cat].length === 0) delete live.permissions[cat];
    }
    const liveChanged = JSON.stringify(live) !== origLive;
    const profileChanged = JSON.stringify(profile) !== origProfile;
    if (liveChanged) fs.writeFileSync(livePath, JSON.stringify(live, null, 2) + '\n');
    if (profileChanged) fs.writeFileSync(profilePath, JSON.stringify(profile, null, 2) + '\n');
    process.stdout.write((liveChanged ? 'live-changed' : 'live-unchanged') + ' ' + (profileChanged ? 'profile-changed' : 'profile-unchanged'));
}
'@
    [System.IO.File]::WriteAllText($ns, $nodeScript, [System.Text.UTF8Encoding]::new($false))

    $liveExisted = Test-Path $LiveFile

    # --- Plan pass --- (node stdout = decisions TSV; stderr = counts)
    $errFile = [System.IO.Path]::GetTempFileName()
    $decContent = & node $ns plan $LiveFile $ProfileFile $SubPath $ExcludeKeys $DeprecatedRules $planJson 2>$errFile
    $planStderr = (Get-Content $errFile -Raw -ErrorAction SilentlyContinue)
    if ($planStderr) { $planStderr = $planStderr.Trim() }
    Remove-Item $errFile -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) {
        LogError "Sync-ManagedJson: plan pass failed: $planStderr"
        Remove-Item $ns, $planJson, $choicesTsv -ErrorAction SilentlyContinue
        return
    }
    $decisions = @($decContent | Where-Object { $_ -ne "" })

    if ($DryRun) {
        Log "[DRY RUN] settings sync: $planStderr (would prompt for $($decisions.Count) divergent leaf/leaves)"
        Remove-Item $ns, $planJson, $choicesTsv -ErrorAction SilentlyContinue
        $script:SyncManagedJsonResult = "unchanged"
        return
    }

    # Nothing to adopt, purge, or decide -> no write, no backups (avoid churn).
    if ($planStderr -eq "adopts=0 deprecated=0 decisions=0") {
        LogOk "Settings unchanged: $LiveFile"
        Remove-Item $ns, $planJson, $choicesTsv -ErrorAction SilentlyContinue
        $script:SyncManagedJsonResult = "unchanged"
        return
    }

    # --- Prompt loop (granular, per leaf) ---
    $choiceLines = @()
    if (-not $liveExisted -and $decisions.Count -gt 0) {
        # No live file yet (fresh HOME): nothing local to protect, so every leaf is
        # created from the profile without prompting (#31).
        Log "No $LiveFile yet -- creating from profile ($($decisions.Count) setting(s))"
        $liveDir = Split-Path $LiveFile -Parent
        if (-not (Test-Path $liveDir)) { New-Item -ItemType Directory -Path $liveDir -Force | Out-Null }
    }
    foreach ($line in $decisions) {
        $cols = $line -split "`t"
        $id = $cols[0]; $cur = $cols[2]; $prop = $cols[3]; $adoptf = $cols[4]
        if ($liveExisted) {
            $action = Prompt-JsonFieldReview -Leaf $id -Current $cur -Proposed $prop -SourceLabel "profile.json" -AdoptAllowed $adoptf
        } else {
            $action = "overwrite"
        }
        $choiceLines += "$id`t$action"
    }
    [System.IO.File]::WriteAllText($choicesTsv, (($choiceLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

    # --- Backup before apply ---
    Backup-File -FilePath $LiveFile
    if (Test-Path $ProfileFile) { Backup-File -FilePath $ProfileFile }

    # --- Apply pass ---
    $applyOut = & node $ns apply $LiveFile $ProfileFile $SubPath $ExcludeKeys $DeprecatedRules $planJson $choicesTsv
    if ($LASTEXITCODE -ne 0) {
        LogError "Sync-ManagedJson: apply pass failed"
        Remove-Item $ns, $planJson, $choicesTsv -ErrorAction SilentlyContinue
        return
    }

    # --- Post-write validation ---
    if (Test-Path $LiveFile) {
        try { Get-Content $LiveFile -Raw | ConvertFrom-Json | Out-Null }
        catch { LogError "Sync-ManagedJson: $LiveFile is not valid JSON after write -- $_" ; Remove-Item $ns, $planJson, $choicesTsv -ErrorAction SilentlyContinue; return }
    }

    if ($applyOut -match 'live-changed') {
        LogOk "Settings synced: $LiveFile"
        $script:SyncManagedJsonResult = if ($liveExisted) { "updated" } else { "created" }
    } else {
        LogOk "Settings unchanged: $LiveFile"
        $script:SyncManagedJsonResult = "unchanged"
    }
    if ($applyOut -match 'profile-changed') { LogOk "Profile updated: $ProfileFile" }

    Remove-Item $ns, $planJson, $choicesTsv -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# PATH helpers
# ---------------------------------------------------------------------------

# Refresh-Path: Merge registry PATH entries into current PATH (additive).
# Preserves runtime additions from Ensure-ToolOnPath and entries inherited
# from the parent process (e.g., Git Bash usr/bin). Only ADDS directories
# found in registry but missing from current PATH.
# Call after winget install/upgrade to pick up PATH changes in same session.
function Refresh-Path {
    $registryPath = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [Environment]::GetEnvironmentVariable("Path", "User")
    $currentDirs = ($env:Path -split ';') | Where-Object { $_ }
    $currentSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$currentDirs, [System.StringComparer]::OrdinalIgnoreCase)
    $newDirs = ($registryPath -split ';') | Where-Object { $_ -and -not $currentSet.Contains($_) }
    if ($newDirs) {
        $env:Path = $env:Path + ";" + ($newDirs -join ';')
    }
}

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]"Administrator"
    )
}

# Log-WingetOutput: Filter and log captured winget command output.
# Strips spinner characters (- \ | /), download progress bars (KB/MB/GB),
# and empty lines. Remaining lines are logged at info level.
function Log-WingetOutput([string]$Output) {
    $Output.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$' -and $l -notmatch '\d+(\.\d+)?\s*(KB|MB|GB)\s*/\s*\d+') {
            Log $l
        }
    }
}

# ---------------------------------------------------------------------------
# Repair broken uv tool environment (cross-platform)
# ---------------------------------------------------------------------------
# When `uv tool upgrade <tool>` fails with "missing a valid environment",
# find a working Python via `uv python find` (fallback: system python/python3)
# and reinstall with --force --python <path>.
# Returns $true if repaired, $false if not applicable or failed.
function Repair-UvToolEnv {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [string]$UpgradeOutput = ""
    )

    if ($UpgradeOutput -notmatch 'missing a valid environment') { return $false }

    LogWarn "$ToolName uv environment is broken (Python removed?) -- repairing..."

    # Find a working Python -- uv's own Pythons first, then system
    # Get-Command exempt: command-existence check with fallback chain
    $workingPython = $null
    $uvPython = & uv python find 2>$null
    if ($LASTEXITCODE -eq 0 -and $uvPython -and (Test-Path $uvPython)) {
        $workingPython = $uvPython
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $workingPython = (Get-Command python).Source
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        $workingPython = (Get-Command python3).Source
    }

    if (-not $workingPython) {
        LogError "Cannot repair $ToolName -- no working Python found"
        return $false
    }

    Log "Repairing with: uv tool install --force --python $workingPython $ToolName"
    $repairOutput = & uv tool install --force --python $workingPython $ToolName 2>&1 | Out-String
    $repairOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd(); if ($l.Trim()) { Log $l }
    }

    if ($LASTEXITCODE -ne 0) {
        LogError "$ToolName environment repair failed (exit $LASTEXITCODE)"
        return $false
    }

    LogOk "Repaired $ToolName uv environment"
    return $true
}

# ---------------------------------------------------------------------------
# Remove orphaned Python directories (Windows only)
# ---------------------------------------------------------------------------
# Scans %LOCALAPPDATA%\Programs\Python\ for PythonXYZ\ directories where
# python.exe is gone (uninstalled). Removes the orphaned directory tree and
# cleans stale entries from User PATH.
# Returns count of directories removed (0 = nothing to clean).
function Remove-OrphanedPythonDirs {
    if (-not $IsWindows) { return 0 }

    $pythonBase = Join-Path $env:LOCALAPPDATA "Programs\Python"
    if (-not (Test-Path $pythonBase)) { return 0 }

    $removedCount = 0
    $candidates = Get-ChildItem -Path $pythonBase -Directory -ErrorAction SilentlyContinue
    if (-not $candidates) { return 0 }

    foreach ($dir in $candidates) {
        # Skip the Launcher directory (belongs to pymanager)
        if ($dir.Name -eq "Launcher") { continue }

        # Orphaned = python.exe is gone
        $pythonExe = Join-Path $dir.FullName "python.exe"
        if (Test-Path $pythonExe) { continue }

        # Log stale executables for visibility
        $scriptsDir = Join-Path $dir.FullName "Scripts"
        if (Test-Path $scriptsDir) {
            $staleExes = Get-ChildItem $scriptsDir -Filter "*.exe" -File -ErrorAction SilentlyContinue
            if ($staleExes) {
                $names = ($staleExes | Select-Object -First 5 | ForEach-Object { $_.Name }) -join ", "
                LogWarn "Orphaned Python dir with stale executables: $($dir.Name) ($names)"
            }
        }

        try {
            Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction Stop
            LogOk "Removed orphaned directory: $($dir.FullName)"
            $removedCount++
        } catch {
            LogError "Failed to remove $($dir.FullName): $_"
        }
    }

    # Clean stale User PATH entries pointing to removed Python dirs
    if ($removedCount -gt 0) {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath) {
            $entries = $userPath -split ";"
            $cleanEntries = @()
            $removedEntries = @()

            foreach ($entry in $entries) {
                $trimmed = $entry.TrimEnd("\", "/")
                if ($trimmed -match '\\Programs\\Python\\Python\d+' -and -not (Test-Path $trimmed)) {
                    $removedEntries += $trimmed
                } else {
                    $cleanEntries += $entry
                }
            }

            if ($removedEntries.Count -gt 0) {
                $newPath = $cleanEntries -join ";"
                [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                foreach ($re in $removedEntries) {
                    LogOk "Removed stale User PATH entry: $re"
                }
            }
        }

        Refresh-Path
    }

    return $removedCount
}

# ---------------------------------------------------------------------------
# PS 5.1 compatibility: ConvertFrom-Json -> Hashtable (recursive, array-aware)
# ---------------------------------------------------------------------------
function ConvertPSObjectToHashtable($obj) {
    if ($null -eq $obj) { return @{} }
    if ($obj -is [array]) {
        return ,@($obj | ForEach-Object { ConvertPSObjectToHashtable $_ })
    }
    if ($obj -isnot [System.Management.Automation.PSCustomObject]) { return $obj }
    $ht = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        $ht[$prop.Name] = ConvertPSObjectToHashtable $prop.Value
    }
    return $ht
}

# ---------------------------------------------------------------------------
# Emit DETAIL summary entries from a list of change descriptions.
# Usage: Emit-MergeDetails -Changes @("key: old -> new") -ToolName "tool_name"
# ---------------------------------------------------------------------------
function Emit-MergeDetails {
    param(
        [string[]]$Changes,
        [string]$ToolName
    )
    foreach ($change in $Changes) {
        Log "  $change"
        Write-Summary "DETAIL" $ToolName "$change"
    }
}

# ---------------------------------------------------------------------------
# JSON normalization for comparison (sorted keys, deterministic output)
# ---------------------------------------------------------------------------
# PowerShell hashtable key ordering is non-deterministic. ConvertTo-Json
# produces different strings for semantically identical objects, causing
# false-positive change detection. These functions recursively sort keys
# before serializing, ensuring identical content produces identical JSON.
#
# Usage:
#   $norm = Normalize-JsonForComparison $hashtable
#   $norm = Normalize-JsonForComparison $hashtable -Depth 5 -Compress
function ConvertTo-CanonicalObject($obj) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [array]) {
        return ,@($obj | ForEach-Object { ConvertTo-CanonicalObject $_ })
    }
    if ($obj -is [hashtable]) {
        $ordered = [ordered]@{}
        foreach ($key in ($obj.Keys | Sort-Object)) {
            $ordered[$key] = ConvertTo-CanonicalObject $obj[$key]
        }
        return [PSCustomObject]$ordered
    }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        $ordered = [ordered]@{}
        foreach ($prop in ($obj.PSObject.Properties | Sort-Object Name)) {
            $ordered[$prop.Name] = ConvertTo-CanonicalObject $prop.Value
        }
        return [PSCustomObject]$ordered
    }
    return $obj
}

function Normalize-JsonForComparison {
    param($Value, [int]$Depth = 10, [switch]$Compress)
    if ($null -eq $Value) { return "null" }
    $canonical = ConvertTo-CanonicalObject $Value
    $canonical | ConvertTo-Json -Depth $Depth -Compress:$Compress
}

# ---------------------------------------------------------------------------
# Go install provenance detection (Windows)
# Returns: "winget", "chocolatey", "scoop", "msi", "none", or "unknown"
# ---------------------------------------------------------------------------
function Get-GoProvenance {
    # Get-Command exempt: command-existence check with explicit fallback
    $goCmd = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmd) { return "none" }
    $goSource = $goCmd.Source
    if ($goSource -like '*\Program Files\Go\*') {
        $wingetCheck = winget list --id GoLang.Go --accept-source-agreements 2>&1 | Out-String
        if ($wingetCheck -match 'GoLang\.Go') { return "winget" }
        return "msi"
    }
    if ($goSource -like '*\chocolatey\*') { return "chocolatey" }
    if ($goSource -like '*\scoop\*') { return "scoop" }
    return "unknown"
}

# ---------------------------------------------------------------------------
# Ensure GOPATH\bin is on persistent User PATH (Windows)
# Returns $true if already present, $false if added
# ---------------------------------------------------------------------------
function Ensure-GopathBinOnPath {
    $gopath = $env:GOPATH
    if (-not $gopath) { $gopath = Join-Path $env:USERPROFILE "go" }
    $gopathBin = Join-Path $gopath "bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -like "*$gopathBin*") { return $true }
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$gopathBin", "User")
    Refresh-Path
    return $false
}

# ---------------------------------------------------------------------------
# Summary panel renderer
# ---------------------------------------------------------------------------
# Reads AITOOLS_SUMMARY_FILE, displays colored panel, cleans up.
# Silent no-op if file unset, missing, or empty.
function Show-Summary {
    $sfile = $env:AITOOLS_SUMMARY_FILE
    if (-not $sfile -or -not (Test-Path $sfile)) { return }
    # Read summary file; -ErrorAction SilentlyContinue checked on next line
    $lines = Get-Content $sfile -ErrorAction SilentlyContinue
    if (-not $lines) {
        # Summary file empty or unreadable; clean up and return
        try { Remove-Item $sfile -Force -ErrorAction Stop }
        catch { Write-Host "  note: could not remove empty summary file" -ForegroundColor Gray }
        return
    }

    # Dedup by tool name: highest severity wins (ERROR > WARN > OK).
    # ACTIONs (empty tool name) are never deduped. DETAIL lines collected separately.
    $rank = @{ 'OK' = 1; 'WARN' = 2; 'ERROR' = 3 }
    $order = [System.Collections.Generic.List[string]]::new()
    $best = @{}
    $bestDetail = @{}
    $detailMap = @{}
    $actions = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        $parts = $line -split '\|', 3
        $cat = $parts[0]
        $tool = $parts[1]
        $det = $parts[2]
        if ($cat -eq 'DETAIL') {
            if (-not $detailMap.ContainsKey($tool)) { $detailMap[$tool] = [System.Collections.Generic.List[string]]::new() }
            $detailMap[$tool].Add($det)
            continue
        }
        if ($cat -eq 'ACTION' -or $tool -eq '') {
            $actions.Add($line)
            continue
        }
        $r = if ($rank.ContainsKey($cat)) { $rank[$cat] } else { 0 }
        if (-not $best.ContainsKey($tool)) {
            $order.Add($tool)
            $best[$tool] = $cat
            $bestDetail[$tool] = $det
        } elseif ($r -gt $rank[$best[$tool]]) {
            $best[$tool] = $cat
            $bestDetail[$tool] = $det
        }
    }

    # Build deduped lines, pre-sorted: OK+details, WARN+details, ERROR+details, ACTIONs
    $deduped = [System.Collections.Generic.List[string]]::new()
    foreach ($sev in @('OK', 'WARN', 'ERROR')) {
        foreach ($t in $order) {
            if ($best[$t] -ne $sev) { continue }
            $deduped.Add("$sev|$t|$($bestDetail[$t])")
            if ($detailMap.ContainsKey($t)) {
                foreach ($d in $detailMap[$t]) { $deduped.Add("DETAIL|$t|$d") }
            }
        }
    }
    foreach ($a in $actions) { $deduped.Add($a) }

    # Color and tag maps for severity categories
    $colorMap = @{ 'OK' = 'Green'; 'WARN' = 'Yellow'; 'ERROR' = 'Red' }
    $tagMap = @{ 'OK' = '  [ok]  '; 'WARN' = '  [!]   '; 'ERROR' = '  [ERR] ' }

    # Single-pass display: deduped list is pre-sorted by severity.
    # DETAIL lines inherit the color of their preceding parent entry.
    Write-Host ""
    Write-Host "------------------------------------------------------------"
    $lastColor = 'Green'
    $firstAction = $true
    foreach ($line in $deduped) {
        $parts = $line -split '\|', 3
        $cat = $parts[0]
        if ($cat -eq 'DETAIL') {
            Write-Host ("                          {0}" -f $parts[2]) -ForegroundColor $lastColor
            continue
        }
        if ($colorMap.ContainsKey($cat)) {
            $lastColor = $colorMap[$cat]
            Write-Host ("{0}{1,-16} {2}" -f $tagMap[$cat], $parts[1], $parts[2]) -ForegroundColor $lastColor
            continue
        }
        if ($cat -eq 'ACTION') {
            if ($firstAction) {
                Write-Host ""
                Write-Host "  ACTION REQUIRED -- run before tools are ready:" -ForegroundColor Magenta
                $firstAction = $false
            }
            Write-Host "  >>  $($parts[2])" -ForegroundColor Magenta
        }
    }
    Write-Host "------------------------------------------------------------"

    # Preserve summary for log compliance checks
    if ($env:AITOOLS_PRESERVE_SUMMARY -eq "1") {
        $preserveDest = Join-Path $script:logDir "last-summary.txt"
        try { Copy-Item $sfile $preserveDest -Force -ErrorAction Stop }
        catch {
            # Non-blocking: summary already displayed; preservation is for compliance checks
            Write-Host "  warning: could not preserve summary: $_" -ForegroundColor Yellow
        }
    }
    # Summary file cleanup (already displayed; next run creates a fresh one)
    try { Remove-Item $sfile -Force -ErrorAction Stop }
    catch { Write-Host "  note: could not remove summary file" -ForegroundColor Gray }
}

# ---------------------------------------------------------------------------
# Build prerequisite checking
# ---------------------------------------------------------------------------

# Known build prerequisites by ecosystem.
# To add a new prerequisite: add an entry to the appropriate ecosystem array.
# Fields: Name (display), Check (scriptblock), Install (remediation), Platform (win/mac/all)
$script:BuildPrereqs = @{
    "cargo" = @(
        @{
            Name    = "MSVC Build Tools"
            Check   = {
                $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
                if (Test-Path $vsWhere) {
                    $installs = & $vsWhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
                    return [bool]$installs
                }
                return $false
            }
            Install = "winget install Microsoft.VisualStudio.2022.BuildTools (add 'Desktop Development with C++' workload)"
            Platform = "win"
        },
        @{
            Name       = "NASM"
            ToolName   = "nasm"
            # Get-Command exempt: command-existence check with explicit fallback
            Check      = { [bool](Get-Command nasm -ErrorAction SilentlyContinue) }
            # Verified: 2026-03-11 (winget NASM.NASM v3.01, per-user Nullsoft installer)
            KnownPaths = @("$env:LOCALAPPDATA\bin\NASM\nasm.exe", "$env:ProgramFiles\NASM\nasm.exe", "${env:ProgramFiles(x86)}\NASM\nasm.exe")
            Install    = "winget install NASM.NASM"
            Platform   = "win"
        },
        @{
            Name       = "CMake"
            ToolName   = "cmake"
            # Get-Command exempt: command-existence check with explicit fallback
            Check      = { [bool](Get-Command cmake -ErrorAction SilentlyContinue) }
            # Official: cmake.org/download lists pip, ZIP, MSI (not winget)
            # PyPI: cmake 4.2.3, maintained by Kitware (jcfr@kitware.com)
            # Source: https://cmake.org/download/ + https://pypi.org/project/cmake/
            # Verified source: 2026-03-12 via chrome-devtools
            KnownPaths = @(
                "$env:USERPROFILE\.local\bin\cmake.exe",       # Verified: 2026-03-12 (v4.2.3, uv tool install)
                "$env:APPDATA\Python\Scripts\cmake.exe",       # UNVERIFIED: pip install --user
                "$env:ProgramFiles\CMake\bin\cmake.exe"        # UNVERIFIED: MSI fallback
            )
            Install    = "uv tool install cmake"
            Platform   = "win"
        }
    )
}

# Ensure-ToolOnPath: Verify a tool is findable after installation.
# Tries: 1) Get-Command (current PATH), 2) Refresh-Path (registry reload),
# 3) KnownPaths fallback (filesystem check + session PATH update).
# Returns $true if tool is now on PATH, $false otherwise.
# Callers: setup scripts after winget install, Check-BuildPrereqs fallback.
function Ensure-ToolOnPath {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string[]]$KnownPaths
    )
    # Get-Command exempt: command-existence check with explicit fallback
    if (Get-Command $ToolName -ErrorAction SilentlyContinue) { return $true }

    # Reload PATH from registry (picks up changes from winget installers)
    Refresh-Path
    if (Get-Command $ToolName -ErrorAction SilentlyContinue) { return $true }

    # Fallback: check known install locations on disk
    foreach ($kp in $KnownPaths) {
        if (Test-Path $kp) {
            $parentDir = Split-Path $kp -Parent
            $env:Path = "$parentDir;$env:Path"
            Log "$ToolName found at $kp (added to session PATH)"
            return $true
        }
    }
    return $false
}

function Get-HarnessPython {
    # Resolve the harness-managed Python interpreter deterministically.
    # Prefers the uv shim under ~/.local\bin so the harness uses the managed
    # interpreter even in non-interactive contexts where login PATH order does
    # not apply. Returns the resolved path or command name; $null if none found.
    # UNTESTED on Windows -- mirrors harness_python in aitools-lib.sh.
    $localBin = Join-Path $HOME ".local\bin"
    foreach ($exe in @("python3.exe", "python.exe")) {
        $shim = Join-Path $localBin $exe
        if (Test-Path $shim) { return $shim }
    }
    # Get-Command exempt: command-existence check with explicit fallback
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
    if (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    return $null
}

function Check-BuildPrereqs {
    <#
    .SYNOPSIS
    Checks known build prerequisites for an ecosystem (cargo, pip, go).
    Returns array of missing prerequisites. Empty array = all present.
    Callers decide whether to abort or warn.

    Detection order per prerequisite:
    1. Run the Check scriptblock (typically Get-Command / PATH-based)
    2. If Check fails AND entry has KnownPaths + ToolName, call Ensure-ToolOnPath
       which tries Refresh-Path then filesystem fallback
    3. If still not found, add to missing array
    #>
    param(
        [Parameter(Mandatory)][string]$Ecosystem
    )

    $prereqs = $script:BuildPrereqs[$Ecosystem]
    if (-not $prereqs) { return @() }

    $missing = @()
    foreach ($p in $prereqs) {
        # Filter by platform
        if ($p.Platform -eq "win" -and -not $IsWindows) { continue }
        if ($p.Platform -eq "mac" -and $IsWindows) { continue }

        $present = & $p.Check
        if (-not $present -and $p.KnownPaths -and $p.ToolName) {
            $present = Ensure-ToolOnPath -ToolName $p.ToolName -KnownPaths $p.KnownPaths
        }
        if (-not $present) {
            $missing += $p
        }
    }
    return $missing
}

# ---------------------------------------------------------------------------
# Build failure diagnosis
# ---------------------------------------------------------------------------

# Known build failure signatures.
# To add a new signature: add an entry to this array.
# When a user reports a new build failure, add the error pattern + remedy here.
$script:BuildFailureSignatures = @(
    @{ Pattern = "NASM command not found";                Remedy = "winget install NASM.NASM";                     Name = "NASM (assembler)" }
    @{ Pattern = "linker.*not found|link\.exe.*not found"; Remedy = "Install MSVC Build Tools with C++ workload";  Name = "MSVC linker" }
    @{ Pattern = "cmake.*not found|Could not find cmake"; Remedy = "uv tool install cmake (or see cmake.org/download)"; Name = "CMake" }
    @{ Pattern = "pkg-config.*not found";                 Remedy = "Install pkg-config";                           Name = "pkg-config" }
    @{ Pattern = "Python\.h.*not found|python.*dev";      Remedy = "Install Python development headers";           Name = "Python headers" }
    @{ Pattern = "C compiler.*not found|cc.*not found";   Remedy = "Install a C compiler (MSVC/gcc/clang)";        Name = "C compiler" }
    @{ Pattern = "openssl.*not found|OPENSSL_DIR";        Remedy = "Install OpenSSL or set OPENSSL_DIR";           Name = "OpenSSL" }
)

function Diagnose-BuildFailure {
    <#
    .SYNOPSIS
    Scans build output for known failure signatures and returns actionable remediation.
    Call this after a build command fails to surface the real cause.
    Returns $null if no known signature matches (generic failure).
    #>
    param(
        [Parameter(Mandatory)][string]$Output
    )

    foreach ($sig in $script:BuildFailureSignatures) {
        if ($Output -match $sig.Pattern) {
            return $sig
        }
    }
    return $null
}
