# aitools-lib.ps1 -- shared helpers for all aitools PowerShell scripts
# Dot-sourced, not executed directly.
#
# Provides: ReadConfigKey, Initialize-Logging, Log/LogOk/LogError/LogWarn,
# Write-Summary, Show-Summary, Refresh-Path, Log-WingetOutput,
# Repair-UvToolEnv, Remove-OrphanedPythonDirs, Normalize-JsonForComparison.
#
# Usage:
#   . (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
#   Initialize-Logging "script-name"
#
# Entry points (aitools.ps1, aitools-install.ps1) override log functions after
# sourcing for specialized logging (file-only, JSONL, etc.).
#
# Platform detection uses PS 7+ built-in $IsMacOS/$IsWindows -- no custom variables.

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
        # return means "corrupt", not "missing key"
        Write-Host "      WARN: could not parse $File" -ForegroundColor Yellow
    }
    return $null
}

# ---------------------------------------------------------------------------
# Logging init
# ---------------------------------------------------------------------------
# Sets $script:scriptName, $script:logDir, $script:logFile; resets
# $script:errors, $script:warnings. Creates log directory.
# Usage: Initialize-Logging "setup-foo"
function Initialize-Logging {
    param([Parameter(Mandatory)][string]$Name)
    $script:scriptName = $Name
    if ($IsWindows -or (-not (Test-Path variable:IsMacOS))) {
        # Windows (PS 7+) or PS 5.1 (always Windows)
        $script:logDir = Join-Path $env:LOCALAPPDATA "aitools"
    } else {
        # macOS/Linux
        $script:logDir = Join-Path $HOME "Library/Logs/aitools"
    }
    $script:logFile = Join-Path $script:logDir "deploy.log"
    if (-not (Test-Path $script:logDir)) {
        New-Item -ItemType Directory -Path $script:logDir -Force | Out-Null
    }
    $script:errors = 0
    $script:warnings = 0
}

# ---------------------------------------------------------------------------
# Standard logging (console + log file, with [level] tag)
# ---------------------------------------------------------------------------
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    Add-Content -Path $logFile -Value $line
    switch ($level) {
        "error" { Write-Host $line -ForegroundColor Red }
        "warn"  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line }
    }
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }

# ---------------------------------------------------------------------------
# Summary writer (3-arg: category, tool, detail)
# ---------------------------------------------------------------------------
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) {
        # Auto-promote OK to WARN when warnings have been logged
        if ($cat -eq "OK" -and $script:warnings -gt 0) {
            $cat = "WARN"
        }
        Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${tool}|${detail}"
    }
}

# ---------------------------------------------------------------------------
# Backup a file before overwriting. Keeps at most $MaxBackups copies.
# ---------------------------------------------------------------------------
function Backup-File {
    param([string]$FilePath, [int]$MaxBackups = 20)
    if (-not (Test-Path $FilePath)) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${FilePath}.bak.${ts}"
    Copy-Item -Path $FilePath -Destination $backupPath
    # Prune oldest beyond limit
    $backups = Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending
    if ($backups.Count -gt $MaxBackups) {
        $backups | Select-Object -Skip $MaxBackups | Remove-Item -Force
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
# PATH helpers
# ---------------------------------------------------------------------------

# Refresh-Path: Reload $env:Path from Machine + User registry values.
# Call after winget install/upgrade to pick up PATH changes in same session.
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
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
