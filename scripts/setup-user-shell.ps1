# setup-user-shell.ps1 -- Owns the aitools blocks in the PowerShell profile (Windows)
# Safe to re-run -- idempotent: a profile whose blocks are current is not rewritten.
# Platform: Windows (OS guard). Twin: setup-user-shell.sh (macOS/Linux).
# Tool context: /tool-registry skill; design: reference/ait-shellintegration.md.
#
# The single owner of the aitools lines in $PROFILE. It writes two marked blocks:
#
#   # >>> aitools managed >>>            PATH block: prepends $HOME\.local\bin (the
#   ...                                  aitools/uv bin dir) so managed tools win.
#   # <<< aitools managed <<<            Identical on every machine.
#
#   # >>> aitools shell integration >>>  Shell integration: dot-sources
#   ...                                  shared\shell\aliases.ps1 of this aitools
#   # <<< aitools shell integration <<<  clone and defines `aitools` and `hh`.
#
# Why two blocks: the integration block holds a machine-specific absolute path
# (this aitools clone) and needs a file the MDM deploy/ copy does not ship, while
# the PATH block is identical everywhere and always written. Separate markers let
# each be refreshed, or left alone, on its own. (aitools-install.ps1 Step 7 wrote
# the integration lines itself until incident #173; it now only runs this script.)
#
# Owns:      every line between our markers (replaced in place); our marker lines.
# Preserves: every other line of the profile, byte for byte.
# Overwrites: no (rewrites only our blocks; the profile is backed up first).
#
# Repair (incident #172): duplicate blocks collapse to one at the first block's
# position; a marker line with no partner (a stray start or end marker) is
# removed. Damage this script does not guess at -- parse errors, or stray lines
# of our block outside the markers (a line containing "_aitoolsLocalBin" or
# "Owned by aitools (scripts/setup-user-shell.") -- is left in place and reported
# as WARN + ACTION naming the newest clean "<profile>.bak.<UTC>" backup (at most
# one block of each kind, no parse errors, no stray lines), or "repair by hand"
# when none qualifies. A write that would add parse errors is refused (ERROR).
#
# Legacy migration: "# aitools shell integration" and "# ai-tooling shell
# integration" blocks (written by aitools-install.ps1 Step 7) are removed: the
# marker line, the lines right after it that have a known legacy shape (a
# dot-source of a path ending in aliases.ps1, `function aitools {...}`,
# `function hh {...}`), and at most one blank line right above the marker. The
# first line that is not of a legacy shape ends the block and is kept. The new
# integration block takes the first legacy block's place.
#
# MDM: when aliases.ps1 is absent (the deploy/ copy), no integration block is
# written and an existing one (new or legacy) is left as it is: WARN row.
#
# Testing: $env:AITOOLS_PROFILE_PATH targets a scratch profile instead of
# $PROFILE; $env:AITOOLS_ALIASES_PATH overrides the aliases.ps1 path (absolute;
# a missing file exercises the MDM path).
#
# See plans/tooling-resolution-and-artifact-registry.md (Workstream A).

# --- Shared library ---
. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "setup-user-shell"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Target profile (overridable for testing) ---
$profilePath = if ($env:AITOOLS_PROFILE_PATH) { $env:AITOOLS_PROFILE_PATH } else { $PROFILE }
# Absolute: the [IO.File] calls below resolve relative paths against the .NET
# working directory, not the PowerShell location (cross-platform.md gotchas).
$profilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($profilePath)

$pathStart = "# >>> aitools managed >>>"
$pathEnd = "# <<< aitools managed <<<"
$integStart = "# >>> aitools shell integration >>>"
$integEnd = "# <<< aitools shell integration <<<"
$legacyMarkers = @("# aitools shell integration", "# ai-tooling shell integration")
$ownedComment = "# Owned by aitools (scripts/setup-user-shell.ps1). Edit via the script, not by hand."
# Stray-line set (identical in setup-user-shell.sh): text of our blocks that must
# never appear outside the markers.
$strayTokens = @("_aitoolsLocalBin", "Owned by aitools (scripts/setup-user-shell.")
# Placeholder line for the first legacy block's position (never written to disk).
$slot = [string][char]0 + "aitools-integration-slot" + [string][char]0 + "`n"

# --- The PATH block (identical across machines) ---
$pathBlock = (@(
    $pathStart,
    $ownedComment,
    '$__aitoolsLocalBin = Join-Path $HOME ".local\bin"',
    'if ((Test-Path $__aitoolsLocalBin) -and ($env:PATH -split '';'')[0] -ne $__aitoolsLocalBin) {',
    '    $env:PATH = "$__aitoolsLocalBin;$env:PATH"',
    '}',
    $pathEnd
) -join "`n") + "`n"

# --- The integration block (machine-specific: absolute aliases.ps1 path) ---
$aliasesPath = if ($env:AITOOLS_ALIASES_PATH) { $env:AITOOLS_ALIASES_PATH } else { Join-Path $PSScriptRoot "..\shared\shell\aliases.ps1" }
$aliasesAbs = $null
if (Test-Path -LiteralPath $aliasesPath -PathType Leaf) {
    $aliasesAbs = (Resolve-Path -LiteralPath $aliasesPath).ProviderPath
}
$integBlock = $null
if ($aliasesAbs) {
    $integBlock = (@(
        $integStart,
        $ownedComment,
        (". '" + $aliasesAbs.Replace("'", "''") + "'"),
        'function aitools { & "$HOME\.local\bin\aitools.ps1" @args }',
        'function hh { & "$HOME\.local\bin\hh.ps1" @args }',
        $integEnd
    ) -join "`n") + "`n"
}

# ---------------------------------------------------------------------------
# Helpers (line-based; a line keeps its own "\n" or "\r\n")
# ---------------------------------------------------------------------------
function Split-Lines([string]$Text) {
    $list = [System.Collections.Generic.List[string]]::new()
    if ($Text.Length -gt 0) {
        foreach ($l in [regex]::Split($Text, '(?<=\n)')) { if ($l.Length -gt 0) { $list.Add($l) } }
    }
    return ,$list
}

function Add-AtEnd([System.Collections.Generic.List[string]]$Out, [string]$Block) {
    if ($Out.Count -gt 0 -and -not $Out[$Out.Count - 1].EndsWith("`n")) { $Out[$Out.Count - 1] += "`n" }
    $Out.Add($Block)
}

# Replace the marked blocks Start..End (start line to the first end line after
# it) with one Block at the first block's position; drop later blocks and stray
# marker lines. No block: Block goes to the Slot line when there is one, else at
# the end. Returns @{ Text; Blocks; Orphans; Unchanged }.
function Update-MarkedBlock([string]$Text, [string]$Start, [string]$End, [string]$Block, [string]$Slot) {
    $lines = Split-Lines $Text
    $out = [System.Collections.Generic.List[string]]::new()
    $blocks = 0; $orphans = 0; $oldText = $null
    $i = 0
    while ($i -lt $lines.Count) {
        $key = $lines[$i].Trim()
        if ($key -ceq $Start) {
            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j].Trim() -cne $End) { $j++ }
            if ($j -lt $lines.Count) {
                $blocks++
                if ($blocks -eq 1) {
                    $oldText = -join $lines.GetRange($i, $j - $i + 1)
                    $out.Add($Block)
                } else {
                    LogDetail "removed duplicate block $Start (profile lines $($i + 1)-$($j + 1))"
                }
                $i = $j + 1
                continue
            }
            $orphans++
            LogDetail "removed stray marker line $($i + 1): $key"
            $i++
            continue
        }
        if ($key -ceq $End) {
            $orphans++
            LogDetail "removed stray marker line $($i + 1): $key"
            $i++
            continue
        }
        $out.Add($lines[$i])
        $i++
    }
    $slotIndex = if ($Slot) { $out.IndexOf($Slot) } else { -1 }
    if ($blocks -eq 0) {
        if ($slotIndex -ge 0) { $out[$slotIndex] = $Block } else { Add-AtEnd $out $Block }
    }
    if ($Slot) { while ($out.Remove($Slot)) { } }
    return @{
        Text      = (-join $out)
        Blocks    = $blocks
        Orphans   = $orphans
        Unchanged = (($blocks -eq 1) -and ($orphans -eq 0) -and ($oldText -ceq $Block))
    }
}

function Test-LegacyShape([string]$Line) {
    return ($Line -match '^\s*\.\s+["'']?[^"''\r\n]*aliases\.ps1["'']?\s*$') -or
        ($Line -match '^\s*function\s+aitools\s*\{.*\}\s*$') -or
        ($Line -match '^\s*function\s+hh\s*\{.*\}\s*$')
}

# Remove legacy integration blocks (see header); the first one's place gets
# the Slot line. Returns @{ Text; Count }.
function Remove-LegacyIntegration([string]$Text, [string]$Slot) {
    $lines = Split-Lines $Text
    $out = [System.Collections.Generic.List[string]]::new()
    $count = 0
    $i = 0
    while ($i -lt $lines.Count) {
        $key = $lines[$i].Trim()
        if ($legacyMarkers -ccontains $key) {
            $count++
            LogDetail "removed legacy line $($i + 1): $key"
            if ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq "" -and $out[$out.Count - 1] -cne $Slot) {
                $out.RemoveAt($out.Count - 1)
                LogDetail "removed the blank line above legacy line $($i + 1)"
            }
            if ($count -eq 1) { $out.Add($Slot) }
            $i++
            while ($i -lt $lines.Count -and (Test-LegacyShape $lines[$i])) {
                LogDetail "removed legacy line $($i + 1): $($lines[$i].Trim())"
                $i++
            }
            continue
        }
        $out.Add($lines[$i])
        $i++
    }
    return @{ Text = (-join $out); Count = $count }
}

function Get-ParseErrorCount([string]$Text) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$null, [ref]$errs)
    return @($errs).Count
}

# Lines outside our marked blocks that hold stray block text or a marker.
function Get-StrayLineCount([string]$Text) {
    $count = 0
    $closeWith = $null
    foreach ($line in (Split-Lines $Text)) {
        $key = $line.Trim()
        if ($closeWith) { if ($key -ceq $closeWith) { $closeWith = $null }; continue }
        if ($key -ceq $pathStart) { $closeWith = $pathEnd; continue }
        if ($key -ceq $integStart) { $closeWith = $integEnd; continue }
        $isStray = ($key -ceq $pathEnd) -or ($key -ceq $integEnd)
        foreach ($t in $strayTokens) { if ($line.Contains($t)) { $isStray = $true } }
        if ($isStray) { $count++ }
    }
    return $count
}

function Get-MarkerCount([string]$Text, [string]$Marker) {
    return @((Split-Lines $Text) | Where-Object { $_.Trim() -ceq $Marker }).Count
}

# Exactly one Start line and one End line, Start first.
function Test-OneBlock([string]$Text, [string]$Start, [string]$End) {
    $lines = Split-Lines $Text
    $s = @(); $e = @()
    for ($k = 0; $k -lt $lines.Count; $k++) {
        $key = $lines[$k].Trim()
        if ($key -ceq $Start) { $s += $k }
        if ($key -ceq $End) { $e += $k }
    }
    return (($s.Count -eq 1) -and ($e.Count -eq 1) -and ($s[0] -lt $e[0]))
}

# Newest <profile>.bak.<UTC> among Candidates (names sort by timestamp) with at
# most one block of each kind, no parse errors and no stray lines; $null if none.
function Find-CleanBackup([string[]]$Candidates) {
    foreach ($b in ($Candidates | Sort-Object -Descending)) {
        try { $t = [IO.File]::ReadAllText($b) } catch { LogDetail "backup unreadable: $b"; continue }
        $ps = Get-MarkerCount $t $pathStart; $pe = Get-MarkerCount $t $pathEnd
        $is = Get-MarkerCount $t $integStart; $ie = Get-MarkerCount $t $integEnd
        if ($ps -gt 1 -or $ps -ne $pe -or $is -gt 1 -or $is -ne $ie) { continue }
        if ((Get-ParseErrorCount $t) -gt 0) { continue }
        if ((Get-StrayLineCount $t) -gt 0) { continue }
        return $b
    }
    return $null
}

function Get-BackupList([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $dir = [IO.Path]::GetDirectoryName($full)
    $prefix = [IO.Path]::GetFileName($full) + ".bak."
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $dir -File |
        Where-Object { $_.Name.StartsWith($prefix, [StringComparison]::Ordinal) } |
        ForEach-Object { $_.FullName })
}

# ---------------------------------------------------------------------------
# Read the profile (strict UTF-8: a profile in another encoding is not rewritten)
# ---------------------------------------------------------------------------
$profileExists = Test-Path -LiteralPath $profilePath -PathType Leaf
$content = ""
$hasBom = $false
if ($profileExists) {
    try {
        $bytes = [IO.File]::ReadAllBytes($profilePath)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $offset = if ($hasBom) { 3 } else { 0 }
        $content = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes, $offset, $bytes.Length - $offset)
    } catch {
        LogError "Cannot read $profilePath as UTF-8 -- left unchanged: $_"
        Write-Summary "ERROR" "shell" "profile not readable as UTF-8"
        exit 1
    }
}
$backupsBefore = Get-BackupList $profilePath

# ---------------------------------------------------------------------------
# Compute the new profile: PATH block, then legacy migration + integration block
# ---------------------------------------------------------------------------
$pathResult = Update-MarkedBlock $content $pathStart $pathEnd $pathBlock $null
$newContent = $pathResult.Text
$legacyCount = 0
$integResult = $null
if ($integBlock) {
    $legacy = Remove-LegacyIntegration $newContent $slot
    $legacyCount = $legacy.Count
    $integResult = Update-MarkedBlock $legacy.Text $integStart $integEnd $integBlock $slot
    $newContent = $integResult.Text
}

# --- Never write a profile that parses worse than the one it replaces ---
$parseErrorsBefore = Get-ParseErrorCount $content
$parseErrorsAfter = Get-ParseErrorCount $newContent
Log "Profile $profilePath : parse errors before $parseErrorsBefore, after $parseErrorsAfter"

# Damage left in place: reported after the outcome rows (WARN + ACTION).
function Write-DamageReport([string]$Text, [int]$ParseErrors) {
    $stray = Get-StrayLineCount $Text
    if ($ParseErrors -eq 0 -and $stray -eq 0) { return }
    LogWarn "$profilePath is damaged ($ParseErrors parse error(s), $stray stray aitools line(s) outside the blocks) -- left in place, not guessed at"
    Write-Summary "WARN" "shell" "profile damage left in place"
    $clean = Find-CleanBackup $backupsBefore
    if ($clean) {
        Write-Summary "ACTION" "" "Restore $profilePath from $clean"
    } else {
        Write-Summary "ACTION" "" "Repair $profilePath by hand (no clean backup)"
    }
}

if ($parseErrorsAfter -gt $parseErrorsBefore) {
    LogError "Managed block splice would add parse errors to $profilePath -- left unchanged"
    Write-Summary "ERROR" "shell" "managed block splice failed parse check"
    Write-DamageReport $content $parseErrorsBefore
    exit 1
}

# ---------------------------------------------------------------------------
# Write (only when something changed), then validate
# ---------------------------------------------------------------------------
if ($profileExists -and ($newContent -ceq $content)) {
    Log "Profile unchanged: $profilePath"
} else {
    $profileDir = Split-Path $profilePath -Parent
    if ($profileDir -and -not (Test-Path -LiteralPath $profileDir)) {
        try {
            New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop | Out-Null
        } catch {
            LogError "Cannot create $profileDir : $_"
            Write-Summary "ERROR" "shell" "profile directory not created"
            exit 1
        }
    }
    Backup-File $profilePath
    try {
        [IO.File]::WriteAllText($profilePath, $newContent, [System.Text.UTF8Encoding]::new($hasBom))
    } catch {
        LogError "Failed to write $profilePath : $_"
        Write-Summary "ERROR" "shell" "managed block write failed"
        exit 1
    }
    $written = [IO.File]::ReadAllText($profilePath)
    $ok = ($written -ceq $newContent) -and (Test-OneBlock $written $pathStart $pathEnd)
    if ($integBlock) { $ok = $ok -and (Test-OneBlock $written $integStart $integEnd) }
    if (-not $ok) {
        LogError "Profile check after write failed (content or block markers) -- $profilePath"
        Write-Summary "ERROR" "shell" "managed block markers missing"
        exit 1
    }
    LogOk "Wrote $profilePath"
}

# ---------------------------------------------------------------------------
# Outcome rows (OK rows first: a warning promotes later OK rows to WARN)
# ---------------------------------------------------------------------------
if ($pathResult.Blocks -eq 0) {
    LogOk "Added managed block to $profilePath"
    Write-Summary "OK" "shell" "managed block added"
} elseif ($pathResult.Blocks -gt 1) {
    LogOk "Collapsed $($pathResult.Blocks) managed blocks to 1 in $profilePath"
    Write-Summary "OK" "shell" "collapsed $($pathResult.Blocks) blocks to 1"
} elseif ($pathResult.Unchanged) {
    Log "Managed block unchanged in $profilePath"
    Write-Summary "OK" "shell" "managed block unchanged"
} else {
    LogOk "Refreshed managed block in $profilePath"
    Write-Summary "OK" "shell" "managed block refreshed"
}

if ($integResult) {
    if ($legacyCount -gt 0) {
        LogOk "Migrated $legacyCount legacy shell integration block(s) in $profilePath"
        Write-Summary "OK" "shell" "legacy integration migrated"
    } elseif ($integResult.Blocks -eq 0) {
        LogOk "Added shell integration block to $profilePath"
        Write-Summary "OK" "shell" "integration added"
    } elseif ($integResult.Blocks -gt 1) {
        LogOk "Collapsed $($integResult.Blocks) shell integration blocks to 1 in $profilePath"
        Write-Summary "OK" "shell" "integration collapsed to 1"
    } elseif ($integResult.Unchanged) {
        Log "Shell integration block unchanged in $profilePath"
        Write-Summary "OK" "shell" "integration unchanged"
    } else {
        LogOk "Refreshed shell integration block in $profilePath"
        Write-Summary "OK" "shell" "integration refreshed"
    }
} else {
    LogWarn "aliases.ps1 not found ($aliasesPath) -- skipping shell integration (MDM deploy)"
    Write-Summary "WARN" "shell" "aliases.ps1 not found"
}

Write-DamageReport $newContent $parseErrorsAfter

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s)" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
