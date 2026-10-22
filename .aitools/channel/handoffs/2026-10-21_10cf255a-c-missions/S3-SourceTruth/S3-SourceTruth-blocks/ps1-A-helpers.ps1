# ---------------------------------------------------------------------------
# Managed-file helpers for Deploy-ManagedFile, Review-JsonFields and the
# review prompts below. SOURCE is the source of truth; there is no deploy
# state (see the "Review choices" block above Prompt-DiffReview).
# ---------------------------------------------------------------------------

# [x]abort (D-TS13): log, append the abort marker when the runner asked for one
# ($env:AITOOLS_ABORT_FILE set and non-empty), then exit 2. A failed marker
# write is logged; the exit code stays 2. Parity: _managed_abort in aitools-lib.sh.
function Invoke-ManagedAbort {
    LogError "Aborted by user"
    if ($env:AITOOLS_ABORT_FILE) {
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $name = if ($script:scriptName) { $script:scriptName } else { "unknown" }
        try {
            $abortPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:AITOOLS_ABORT_FILE)
            [IO.File]::AppendAllText($abortPath, "abort $name $ts`n", [System.Text.UTF8Encoding]::new($false))
        } catch {
            LogError "Could not write the abort marker to $($env:AITOOLS_ABORT_FILE): $_"
        }
    }
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
const fs = require('fs');
let v;
try { v = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); }
catch (e) { console.error('not valid JSON: ' + e.message); process.exit(1); }
const req = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
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
