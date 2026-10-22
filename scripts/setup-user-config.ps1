# setup-user-config.ps1 -- the only writer of ~/.aitools/config.json (Windows)
#
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.ps1 (dotprofile path, GitHub user, machine alias and how it was
# chosen). NOT a writer of profile.json (machine registration is `aitools user
# init`). NOT an interactive prompt (callers prompt, then pass -MachineAlias).
# NOT the settings.json sync (setup-user-settings). Consumed by: aitools-install.ps1
# Step 5, `aitools user init`, and the `aitools` sync deploy list (first entry).
#
# Safe to re-run: unchanged inputs produce "verified" and no write.
# Platform: Windows. On macOS/Linux use setup-user-config.sh.
# Reference: reference/user-repo.md "Config Schema" and "Resolution".
# Needs: PowerShell 7 (aitools-json.ps1, aitools-profile.ps1); no node (P-Q3).
#
# Managed fields: version, meta, reposPath, repoPath (from parameters; kept when not passed),
#   googleDrives (from -DrivesJson when it is a non-empty array; else kept, or []),
#   githubUser, userRepoPath, machineAlias (derived; kept when
#   derivation is unavailable or fails)
# Preserved: all other keys, in place (key order kept)
# Write path: merge to temp -> validate -> Backup-File -> move.
#   A read, merge or validation failure leaves the existing file untouched.
# Tests only: AITOOLS_PROFILE_TEST_ANY_OS=1 lets the parity tests run this file
#   with pwsh on macOS/Linux.
#
# Usage: setup-user-config.ps1 [-ReposPath P] [-RepoPath P] [-DrivesJson JSON]
#          [-GithubUser U] [-UserRepoPath P] [-MachineAlias A] [-DryRun] [-Help]

[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ReposPath = "",
    [string]$RepoPath = "",
    [string]$DrivesJson = "[]",
    [string]$GithubUser = "",
    [string]$UserRepoPath = "",
    [string]$MachineAlias = "",
    [switch]$DryRun,
    [switch]$Force,   # accepted for deploy-list parity; this script has no review menu
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "setup-user-config"

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows -and $env:AITOOLS_PROFILE_TEST_ANY_OS -ne "1") {
    LogError "This script is for Windows. On macOS/Linux, use setup-user-config.sh."
    exit 1
}

if ($Help) {
    @'
setup-user-config.ps1 -- write ~/.aitools/config.json (the only writer)

Parameters:
  -ReposPath P       Base directory for repos (bootstrap; installer Step 3)
  -RepoPath P        Path to the aitools repo (bootstrap; installer)
  -DrivesJson JSON   Detected Google Drives, JSON array (installer Step 4)
  -GithubUser U      GitHub user; names the dotprofile aitools-<U> (user init)
  -UserRepoPath P    Dotprofile path chosen by user init
  -MachineAlias A    Profile alias chosen by user init (explicit choice)
  -DryRun            Show what would change; write nothing
  -Help              This text

Without parameters: re-derive userRepoPath / githubUser / machineAlias from profile.json.
'@ -split "`n" | ForEach-Object { Write-Output ($_ -replace "`r$", "") }
    exit 0
}
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = $true }
if ($Rest -and $Rest.Count -gt 0) {
    LogError "Unknown option: $($Rest[0]) (see -Help)"
    Write-Summary "ERROR" "aitools config" "bad arguments"
    exit 1
}
foreach ($v in @($ReposPath, $RepoPath, $DrivesJson, $GithubUser, $UserRepoPath, $MachineAlias)) {
    if ($v -match "[`t`r`n]") {
        LogError "option values must be one line (no tab or newline)"
        Write-Summary "ERROR" "aitools config" "bad arguments"
        exit 1
    }
}
foreach ($v in @($ReposPath, $RepoPath, $UserRepoPath)) {
    if ($v -and -not [IO.Path]::IsPathRooted($v)) {
        LogError "paths must be absolute: $v (see -Help)"
        Write-Summary "ERROR" "aitools config" "bad arguments"
        exit 1
    }
}

$configDir = Join-Path $HOME ".aitools"
$configFile = Join-Path $configDir "config.json"
$configTmp = "$configFile.tmp.$PID"
$profilePs1 = Join-Path $PSScriptRoot "aitools-profile.ps1"
$jsonPs1 = Join-Path $PSScriptRoot "aitools-json.ps1"
foreach ($f in @($profilePs1, $jsonPs1)) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
        LogError "Failed: $f not found next to setup-user-config.ps1 -- config.json not written"
        Write-Summary "ERROR" "aitools config" "resolver missing"
        exit 1
    }
}
. $jsonPs1
if (-not (Test-Path -LiteralPath $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

function Remove-ConfigTmp {
    if (Test-Path -LiteralPath $configTmp) {
        try { Remove-Item -LiteralPath $configTmp -Force -ErrorAction Stop }
        catch { LogWarn "Could not remove temp file ${configTmp}: $($_.Exception.Message)" }
    }
}

# --- 1. Derive values from profile.json (aitools-profile.ps1 derive-config) ---
$deriveArgs = @("derive-config", "--config", $configFile)
if ($ReposPath) { $deriveArgs += @("--repos-path", $ReposPath) }
if ($GithubUser) { $deriveArgs += @("--github-user", $GithubUser) }
if ($UserRepoPath) { $deriveArgs += @("--user-repo-path", $UserRepoPath) }
if ($MachineAlias) { $deriveArgs += @("--alias", $MachineAlias) }
$global:LASTEXITCODE = 0
$deriveOut = @()
try {
    # In-process: the resolver writes data to the success stream, logs to stderr
    $deriveOut = @(& $profilePs1 @deriveArgs)
    $deriveRc = $LASTEXITCODE
} catch {
    LogDetail "derive-config threw: $($_.Exception.Message)"
    $deriveRc = 99
}
$d = @{ gh = ""; urp = ""; alias = ""; uvia = "none"; mvia = "none"; company = ""; id = ""; host = ""; aliases = "" }
$seen = $false
$script:NeedInit = $false
$profileBad = $false
# Resolver warnings about the cached config.json (or the expected shared-only
# state) are corrected or recorded by this write: info, so a successful write
# stays OK (D-TS12). The rest are real warnings.
function Write-DeriveWarning([string]$w) {
    if ($w.StartsWith("config.json ") -or $w.Contains("not saved to config.json") -or $w.StartsWith("no dotprofile found") -or $w.StartsWith("githubUser unknown")) {
        Log "config: $w (handled by this write)"
    } else {
        LogWarn "config: $w"
        if ($w.Contains("run: aitools user init")) { $script:NeedInit = $true }
    }
}
foreach ($line in $deriveOut) {
    $kv = ([string]$line) -split "`t", 2
    if ($kv.Count -lt 2) { continue }
    switch -CaseSensitive ($kv[0]) {
        "derived.githubUser" { $d.gh = $kv[1]; $seen = $true }
        "derived.userRepoPath" { $d.urp = $kv[1] }
        "derived.machineAlias" { $d.alias = $kv[1] }
        "userRepoVia" { $d.uvia = $kv[1] }
        "via" { $d.mvia = $kv[1] }
        "company" { $d.company = $kv[1] }
        "machineId" { $d.id = $kv[1] }
        "hostname" { $d.host = $kv[1] }
        "aliases" { $d.aliases = $kv[1] }
        "warn" { Write-DeriveWarning $kv[1] }
        "error" {
            LogError "config: $($kv[1])"
            if ($kv[1].Contains("is invalid JSON") -or $kv[1].Contains("is not v2")) { $profileBad = $true }
        }
    }
}
if (-not $seen -or $deriveRc -gt 2) {
    LogError "Failed: profile derivation produced no result (exit $deriveRc) -- see $($script:logFile)"
    Write-Summary "ERROR" "aitools config" "derivation failed"
    $d.gh = ""; $d.urp = ""; $d.alias = ""; $deriveRc = 2
} else {
    $show = { param($v, $dflt) if ($v) { $v } else { $dflt } }
    Log "config: dotprofile=$(& $show $d.urp 'none') via=$($d.uvia) machineAlias=$(& $show $d.alias 'none') via=$($d.mvia) company=$($d.company) id=$(& $show $d.id 'unavailable') host=$(& $show $d.host 'unavailable')"
    if ($deriveRc -eq 1) {
        Log "config: no dotprofile yet -- writing bootstrap keys only (shared-only mode)"
    } elseif ($deriveRc -ne 0) {
        if ($profileBad) {
            Write-Summary "ERROR" "profile.json" "invalid (see log)"
            Write-Summary "ACTION" "" "Fix profile.json in the dotprofile (details in deploy.log)"
        } else {
            Write-Summary "ERROR" "machine profile" "no machine match"
            Write-Summary "ACTION" "" "Run: aitools user init (profiles: $(& $show $d.aliases 'none'))"
        }
    }
    if ($deriveRc -eq 0 -and $script:NeedInit) {
        Write-Summary "ACTION" "" "Run: aitools user init (registers this machine)"
    }
}

# --- 2. Merge (read-then-merge; managed keys only) ---
$configIntentJson = '{"purpose":"Per-machine pointers that let aitools find its repos and this machine profile, built from profile.json","scope":"Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineAlias). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer","audience":"read_config_key/ReadConfigKey callers, resolve_user_repo_path/Resolve-UserRepoPath, ait-harvest.py, hh, check-lib; written by setup-user-config.sh/.ps1"}'

$configState = "updated"; $corruptReason = ""
$old = $null
$r = Read-JsonFile $configFile
if ($r.State -eq "valid") {
    $old = $r.Value
    $cfg = ConvertFrom-Json -InputObject (ConvertTo-NodeJson $old) -Depth 64 @script:JsonDateKind   # working copy
} elseif ($r.State -eq "missing") {
    $configState = "created"
    $cfg = [PSCustomObject]@{}
} else {
    # Invalid JSON: rebuild from managed fields, salvaging known keys by pattern
    $configState = "recovered"; $corruptReason = $r.Message
    $cfg = [PSCustomObject]@{}
    $rawConfig = ""
    try { $rawConfig = [IO.File]::ReadAllText($configFile) } catch { LogDetail "could not read the invalid config: $($_.Exception.Message)" }
    foreach ($k in @("reposPath", "repoPath", "githubUser", "userRepoPath", "machineAlias")) {
        $m = [regex]::Match($rawConfig, '"' + [regex]::Escape($k) + '"\s*:\s*"((?:[^"\\\n]|\\.)*)"')
        if ($m.Success) {
            $sv = [regex]::Replace($m.Groups[1].Value, '\\(["\\/])', '$1')
            if ($sv) { Set-JValue $cfg $sv @($k); Log "Recovered $k from the invalid config" }
        }
    }
}
$existingUrp = if ($old) { Get-JText $old @("userRepoPath") } else { "" }
$failed = $false
try {
    Set-JValue $cfg 3 @("version")
    if ($ReposPath) { Set-JValue $cfg $ReposPath @("reposPath") }
    if ($RepoPath) { Set-JValue $cfg $RepoPath @("repoPath") }
    if ($DrivesJson -match '\A\s*\[\s*[^\]\s]') {
        $drives = ConvertFrom-Json -InputObject $DrivesJson -Depth 64 -NoEnumerate -ErrorAction Stop
        Set-JValue $cfg $drives @("googleDrives")
    } elseif ((Get-JType $cfg @("googleDrives")) -ne "array") {
        Set-JValue $cfg @() @("googleDrives")
    }
    if ($d.gh) { Set-JValue $cfg $d.gh @("githubUser") }
    if ($d.urp) { Set-JValue $cfg $d.urp @("userRepoPath") }
    if ($d.alias) { Set-JValue $cfg $d.alias @("machineAlias") }
    $derivedFrom = if ($d.urp -or $existingUrp) { "profile.json" } else { "bootstrap only" }
    $meta = [PSCustomObject]@{}
    $meta | Add-Member -NotePropertyName intent -NotePropertyValue (ConvertFrom-Json -InputObject $configIntentJson -ErrorAction Stop)
    $meta | Add-Member -NotePropertyName writer -NotePropertyValue "setup-user-config"
    $meta | Add-Member -NotePropertyName derivedFrom -NotePropertyValue $derivedFrom
    Set-JValue $cfg $meta @("meta")
    [IO.File]::WriteAllText($configTmp, (ConvertTo-NodeJson $cfg) + "`n", $script:Utf8NoBom)
} catch {
    LogDetail "merge: $($_.Exception.Message)"
    LogError "Failed: ${configFile}: config merge failed -- existing file left untouched"
    Write-Summary "ERROR" "aitools config" "merge failed"
    Remove-ConfigTmp
    $failed = $true
}

if (-not $failed) {
    $v = Read-JsonFile $configTmp
    $missing = @()
    if ($v.State -ne "valid") { $missing = @("version", "reposPath", "repoPath") }
    else { $missing = @(@("version", "reposPath", "repoPath") | Where-Object { -not (Get-JType $v.Value @($_)) }) }
    # Changed keys (meta excluded: it describes the file, not the machine)
    $changes = @()
    foreach ($k in @("version", "reposPath", "repoPath", "googleDrives", "githubUser", "userRepoPath", "machineAlias")) {
        $a = ""; $b = ""
        if ($old) { $n = Get-JNode $old @($k); if ($n.Found) { $a = ConvertTo-NodeJson $n.Value -Compress } }
        if ($v.State -eq "valid") { $n = Get-JNode $v.Value @($k); if ($n.Found) { $b = ConvertTo-NodeJson $n.Value -Compress } }
        if ($a -cne $b) {
            $aa = if ($a) { $a } else { "(unset)" }; $bb = if ($b) { $b } else { "(unset)" }
            $changes += "${k}: $aa -> $bb"
        }
    }
    $same = $configState -eq "updated" -and $v.State -eq "valid" -and ((ConvertTo-NodeJson $old -Compress) -ceq (ConvertTo-NodeJson $v.Value -Compress))
    # No "//" inside a path value (protocol prefixes excepted), as ValidateJsonConfig
    $tmpText = ""
    try { $tmpText = [IO.File]::ReadAllText($configTmp) } catch { LogDetail "could not re-read ${configTmp}: $($_.Exception.Message)" }
    $double = [regex]::Match($tmpText, '"[^"]*(?<!http:)(?<!https:)//[^"]*"')
    if ($double.Success) {
        LogError "Failed: ${configFile}: double slash in a path value: $($double.Value) -- existing file left untouched"
        Write-Summary "ERROR" "aitools config" "validation failed"
        Remove-ConfigTmp
    } elseif ($missing.Count -gt 0) {
        LogError "Failed: ${configFile}: missing bootstrap $($missing -join ', ') (run aitools install) -- existing file left untouched"
        Write-Summary "ERROR" "aitools config" "missing bootstrap values"
        Remove-ConfigTmp
    } elseif ($same) {
        LogOk "Verified: $configFile (unchanged)"
        Write-Summary "OK" "aitools config" "verified"
        Remove-ConfigTmp
    } elseif ($DryRun) {
        Log "[DRY RUN] Would write $configFile ($configState)"
        foreach ($c in $changes) { Log "[DRY RUN]   $c" }
        Write-Summary "OK" "aitools config" "dry-run: would update"
        Remove-ConfigTmp
    } else {
        Backup-File $configFile
        $moved = $true
        try { Move-Item -LiteralPath $configTmp -Destination $configFile -Force -ErrorAction Stop }
        catch { $moved = $false; LogDetail "move: $($_.Exception.Message)" }
        if (-not $moved) {
            LogError "Failed: ${configFile}: could not replace the config file"
            Write-Summary "ERROR" "aitools config" "write failed"
            Remove-ConfigTmp
        } else {
            switch ($configState) {
                "recovered" {
                    LogWarn "$configFile was not valid JSON ($corruptReason) -- rebuilt; the invalid copy was backed up"
                    Write-Summary "WARN" "aitools config" "rebuilt (was invalid)"
                }
                "created" { LogOk "Created: $configFile"; Write-Summary "OK" "aitools config" "created" }
                default { LogOk "Updated: $configFile"; Write-Summary "OK" "aitools config" "updated" }
            }
            foreach ($c in $changes) {
                Log "  $c"
                Write-Summary "DETAIL" "aitools config" "$(($c -split ':')[0]) updated"
            }
        }
    }
}

# --- Exit footer ---
if ($script:errors -gt 0) {
    Log "FAILED with $($script:errors) error(s)" "error"
    exit 1
} elseif ($script:warnings -gt 0) {
    Log "COMPLETED with $($script:warnings) warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
