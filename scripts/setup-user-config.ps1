# setup-user-config.ps1 -- the only writer of ~/.aitools/config.json (Windows)
#
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.ps1 (dotprofile path, GitHub user, this machine's profile key --
# machineId -- with its display alias, and how they were chosen). NOT a writer of
# profile.json (machine registration is `aitools user init`). NOT an interactive
# prompt (callers prompt, then pass -MachineId, or -NoMachine when they leave
# this machine unregistered).
# NOT the settings.json sync (setup-user-settings). Consumed by: aitools-install.ps1
# Step 5, `aitools user init`, and deploy-harness.ps1 (first in the `aitools` sync
# deploy list; skipped with -SkipConfig when the installer's Step 5 ran it).
#
# Safe to re-run: unchanged inputs produce "verified" and no write.
# Platform: Windows. On macOS/Linux use setup-user-config.sh.
# Reference: reference/user-repo.md "Config Schema" and "Resolution".
# Needs: PowerShell 7 (aitools-json.ps1, aitools-profile.ps1); no node (P-Q3).
#
# Managed fields: version, meta, reposPath, repoPath (from parameters; kept when not passed),
#   googleDrives (from -DrivesJson when it is a non-empty array; else kept, or []),
#   githubUser, userRepoPath, machineId, machineAlias (derived; kept when
#   derivation is unavailable or fails, or does not yield the value).
#   machineId: the matched profiles key, only for this machine's id-keyed profile
#   (profile.json revision 2.2). machineAlias: display only (the profile's alias),
#   kept for one release for 2.1 readers; the legacy cache for an alias-keyed profile.
#   With -NoMachine, machineId and machineAlias are preserved as they are (never
#   set, never removed): machine registration and its advice belong to the caller.
# Preserved: all other keys, in place (key order kept)
# Write path: merge to temp -> validate -> Backup-File -> move.
#   A read, merge or validation failure leaves the existing file untouched.
#   -DryRun merges into a system temp file: nothing under ~/.aitools is created or
#   changed (deploy.log still records the run).
# Tests only: AITOOLS_PROFILE_TEST_ANY_OS=1 lets the parity tests run this file
#   with pwsh on macOS/Linux.
#
# Usage: setup-user-config.ps1 [-ReposPath P] [-RepoPath P] [-DrivesJson JSON]
#          [-GithubUser U] [-UserRepoPath P] [-MachineId ID | -NoMachine]
#          [-DryRun] [-Help]
#   -MachineAlias A is still accepted for one release (deprecated; logged at detail).
#   -NoMachine (user init, when it leaves this machine unregistered): the caller owns
#   machine registration and reports it. The writer writes every other field, leaves
#   machineId / machineAlias untouched, and adds no machine-profile ERROR or ACTION row
#   for an unregistered machine (no profile matches; no machine profiles) and no
#   registration ACTION; it logs one info line saying so. Other derivation errors
#   (invalid profile.json, a missing dotprofile path, an ambiguous match) are still
#   reported. With -MachineId or -MachineAlias: bad arguments. Pass it only for a
#   machine the caller has concluded is unregistered: the writer does not check, and
#   every warning naming aitools user init / aitools-profile migrate goes to detail.
# Exit: 0 done (warnings possible), 1 any error. Never prompts, never exits 2.

[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ReposPath = "",
    [string]$RepoPath = "",
    [string]$DrivesJson = "[]",
    [string]$GithubUser = "",
    [string]$UserRepoPath = "",
    [string]$MachineId = "",
    [string]$MachineAlias = "",   # deprecated (one release): use -MachineId
    [switch]$NoMachine,           # machine registration left to the caller (user init)
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
  -MachineId ID      This machine's profile key chosen by user init (explicit choice)
  -MachineAlias A    Deprecated (one release): a profile alias or key; use -MachineId
  -NoMachine         Machine registration is left to the caller (user init): keep
                     machineId / machineAlias as they are; no ERROR or ACTION row for
                     an unregistered machine. Only for a machine the caller found
                     unregistered. Not with -MachineId / -MachineAlias
  -DryRun            Show what would change; write nothing
  -Help              This text

Without parameters: re-derive userRepoPath / githubUser / machineId / machineAlias from profile.json.
Exit: 0 done (warnings possible), 1 any error.
'@ -split "`n" | ForEach-Object { Write-Output ($_ -replace "`r$", "") }
    exit 0
}
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = $true }
if ($Rest -and $Rest.Count -gt 0) {
    LogError "Unknown option: $($Rest[0]) (see -Help)"
    Write-Summary "ERROR" "aitools config" "bad arguments"
    exit 1
}
foreach ($v in @($ReposPath, $RepoPath, $DrivesJson, $GithubUser, $UserRepoPath, $MachineAlias, $MachineId)) {
    if ($v -match "[`t`r`n]") {
        LogError "option values must be one line (no tab or newline)"
        Write-Summary "ERROR" "aitools config" "bad arguments"
        exit 1
    }
}
$deprecatedAlias = $PSBoundParameters.ContainsKey("MachineAlias")
if ($MachineId -and $deprecatedAlias) {
    LogError "pass -MachineId or -MachineAlias, not both (see -Help)"
    Write-Summary "ERROR" "aitools config" "bad arguments"
    exit 1
}
if ($NoMachine -and ($MachineId -or $deprecatedAlias)) {
    LogError "-NoMachine leaves the machine to the caller: not with -MachineId or -MachineAlias (see -Help)"
    Write-Summary "ERROR" "aitools config" "bad arguments"
    exit 1
}
if ($NoMachine) {
    Log "config: -NoMachine: machine registration is left to the caller -- machineId / machineAlias kept as they are; no machine-profile ERROR or ACTION from this writer"
}
# The profile choice goes to the resolver as an override (a key, ignoring case, else an alias)
$choiceArg = $MachineId
if ($deprecatedAlias) {
    LogDetail "deprecated flag: -MachineAlias (use -MachineId; accepted for one release)"
    $choiceArg = $MachineAlias
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
# The merge result goes next to config.json (same volume, so the move replaces it in
# one step); a dry run merges into a system temp file and never touches ~/.aitools.
$configTmp = "$configFile.tmp.$PID"
if ($DryRun) { $configTmp = Join-Path ([IO.Path]::GetTempPath()) "aitools-config.$PID.json" }
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
if (-not $DryRun -and -not (Test-Path -LiteralPath $configDir)) {
    try { New-Item -ItemType Directory -Path $configDir -Force -ErrorAction Stop | Out-Null }
    catch {
        LogError "Failed: could not create ${configDir}: $($_.Exception.Message) -- config.json not written"
        Write-Summary "ERROR" "aitools config" "write failed"
        exit 1
    }
}

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
if ($choiceArg) { $deriveArgs += @("--alias", $choiceArg) }
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
$d = @{ gh = ""; urp = ""; mid = ""; alias = ""; uvia = "none"; mvia = "none"; company = ""; id = ""; host = ""; aliases = "" }
$seen = $false
$script:NeedInit = $false
$script:NeedMigrate = $false
$script:NeedUpdate = $false
$script:ProfileBad = $false
# Route one resolver warning (the resolver returns its warnings; this caller logs
# them at their level and owns the rows):
#   handled  -- about the cached config.json or the expected shared-only state; this
#               write corrects or records it: info, so a successful write stays OK (D-TS12)
#   advisory -- this machine's values are right and the only follow-up is the command
#               that the single ACTION row (section 3) names: info here; section 3 logs
#               one warning with the ACTION
#   real     -- something is off for this run (a clone, a duplicate alias, a hostname
#               guess, an undetectable id): LogWarn, counted; the config row becomes WARN
#   caller   -- -NoMachine only: advice whose follow-up is machine registration (it
#               names aitools user init or aitools-profile migrate) belongs to the
#               caller: detail only, not counted, no ACTION
$script:NmUnreg = $false      # -NoMachine: the resolver reported this machine as unregistered
$script:NmOtherErr = $false   # -NoMachine: the resolver reported another error (still an ERROR)
function Write-DeriveWarning([string]$w) {
    if ($w.StartsWith("config.json ") -or $w.Contains("not saved to config.json") -or $w.StartsWith("no dotprofile found") -or $w.StartsWith("githubUser unknown")) {
        Log "config: $w (handled by this write)"
    } elseif ($NoMachine -and ($w.Contains("run: aitools user init") -or $w.Contains("run: aitools-profile migrate"))) {
        LogDetail "config: $w (-NoMachine: left to the caller)"
    } elseif ($w.Contains("has no machine.id -- run: aitools user init")) {
        Log "config: $w (see ACTION)"
        $script:NeedInit = $true
    } elseif ($w.Contains("run: aitools-profile migrate")) {
        Log "config: $w (see ACTION)"
        $script:NeedMigrate = $true
    } else {
        LogWarn "config: $w"
        if ($w.Contains("renamed (run: aitools user init")) { $script:NeedUpdate = $true }
        elseif ($w.Contains("run: aitools user init")) { $script:NeedInit = $true }
    }
}
# One resolver error. With -NoMachine, "this machine is not registered" (no profile
# matches it; profile.json has no machine profiles) is the caller's to report: detail
# only. Every other error stays an error.
function Write-DeriveError([string]$e) {
    if ($NoMachine) {
        if ($e.StartsWith("no profile matches this machine") -or $e.StartsWith("profile.json has no machine profiles")) {
            LogDetail "config: $e (-NoMachine: left to the caller)"
            $script:NmUnreg = $true
            return
        }
        $script:NmOtherErr = $true
    }
    LogError "config: $e"
    # profile.json itself is unusable: invalid JSON, not version 2, or no profiles object
    if ($e.Contains("is invalid JSON") -or $e.Contains("is not v2") -or $e.Contains("has no profiles object")) { $script:ProfileBad = $true }
}
foreach ($line in $deriveOut) {
    $kv = ([string]$line) -split "`t", 2
    if ($kv.Count -lt 2) { continue }
    switch -CaseSensitive ($kv[0]) {
        "derived.githubUser" { $d.gh = $kv[1]; $seen = $true }
        "derived.userRepoPath" { $d.urp = $kv[1] }
        "derived.machineId" { $d.mid = $kv[1] }
        "derived.machineAlias" { $d.alias = $kv[1] }
        "userRepoVia" { $d.uvia = $kv[1] }
        "via" { $d.mvia = $kv[1] }
        "company" { $d.company = $kv[1] }
        "machineId" { $d.id = $kv[1] }
        "hostname" { $d.host = $kv[1] }
        "aliases" { $d.aliases = $kv[1] }
        "warn" { Write-DeriveWarning $kv[1] }
        "error" { Write-DeriveError $kv[1] }
    }
}
if (-not $seen -or $deriveRc -gt 2) {
    LogError "Failed: profile derivation produced no result (exit $deriveRc) -- see $($script:logFile)"
    Write-Summary "ERROR" "aitools config" "derivation failed"
    $d.gh = ""; $d.urp = ""; $d.mid = ""; $d.alias = ""; $deriveRc = 2
} else {
    $show = { param($v, $dflt) if ($v) { $v } else { $dflt } }
    Log "config: dotprofile=$(& $show $d.urp 'none') via=$($d.uvia) machineId=$(& $show $d.mid 'none') machineAlias=$(& $show $d.alias 'none') via=$($d.mvia) company=$($d.company) id=$(& $show $d.id 'unavailable') host=$(& $show $d.host 'unavailable')"
    if ($deriveRc -eq 1) {
        Log "config: no dotprofile yet -- writing bootstrap keys only (shared-only mode)"
    } elseif ($deriveRc -ne 0) {
        # Each ACTION has a log line that names its row and carries the instruction,
        # at the row's level (error; audit A-10)
        if ($script:ProfileBad) {
            $rowAdvice = "Fix profile.json in the dotprofile (details in deploy.log)"
            LogError "config: profile.json invalid -- $rowAdvice"
            Write-Summary "ERROR" "profile.json" "invalid (see log)"
            Write-Summary "ACTION" "" $rowAdvice
        } elseif ($NoMachine -and $script:NmUnreg -and -not $script:NmOtherErr) {
            LogDetail "config: no machine match not reported (-NoMachine: the caller reports registration)"
        } else {
            $rowAdvice = "Run: aitools user init (profiles: $(& $show $d.aliases 'none'))"
            LogError "config: machine profile: no machine match -- $rowAdvice"
            Write-Summary "ERROR" "machine profile" "no machine match"
            Write-Summary "ACTION" "" $rowAdvice
        }
    }
}

# --- 2. Merge (read-then-merge; managed keys only) ---
$configIntentJson = '{"purpose":"Per-machine pointers that let aitools find its repos and this machine profile, built from profile.json","scope":"Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineId, and machineAlias as a display value). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer","audience":"read_config_key/ReadConfigKey callers, resolve_user_repo_path/Resolve-UserRepoPath, ait-harvest.py, hh, check-lib; written by setup-user-config.sh/.ps1"}'

$configState = "updated"; $corruptReason = ""; $midHad = ""
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
    foreach ($k in @("reposPath", "repoPath", "githubUser", "userRepoPath", "machineId", "machineAlias")) {
        $m = [regex]::Match($rawConfig, '"' + [regex]::Escape($k) + '"\s*:\s*"((?:[^"\\\n]|\\.)*)"')
        if ($m.Success) {
            $sv = [regex]::Replace($m.Groups[1].Value, '\\(["\\/])', '$1')
            if ($sv) {
                Set-JValue $cfg $sv @($k); Log "Recovered $k from the invalid config"
                if ($k -ceq "machineId") { $midHad = $sv }
            }
        }
    }
}
$existingUrp = if ($old) { Get-JText $old @("userRepoPath") } else { "" }
if ($old) { $midHad = Get-JText $old @("machineId") }
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
    if ($NoMachine) {
        # -NoMachine: machineId / machineAlias are the caller's; kept exactly as they are
        $d.mid = ""; $d.alias = ""
    }
    if ($d.mid) { Set-JValue $cfg $d.mid @("machineId") }
    elseif ($d.alias -and $midHad) {
        # The derivation matched a profile that is not this machine's id-keyed one (a 2.1
        # alias-keyed profile, or a choice of another profile): a cached machineId is stale.
        # Removing it keeps resolver step 4L (the machineAlias cache) usable.
        $cfg.PSObject.Properties.Remove("machineId")
        Log "config: cached machineId `"$midHad`" removed (the matched profile `"$($d.alias)`" is not keyed by this machine's id)"
    }
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
    # A key that differs only in case from a managed key (the JSON engines refuse to add
    # its twin, aitools-json.ps1): name both keys, so the user knows what to fix (PR #108 n-2)
    $mergeWhy = ""
    $twin = [regex]::Match([string]$_.Exception.Message, "set: '(.*?)' differs only in case from existing key '(.*)'")
    if ($twin.Success) {
        $mergeWhy = " -- key `"$($twin.Groups[2].Value)`" differs only in case from the managed key `"$($twin.Groups[1].Value)`": rename or remove it"
    }
    LogError "Failed: ${configFile}: config merge failed$mergeWhy -- existing file left untouched"
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
    foreach ($k in @("version", "reposPath", "repoPath", "googleDrives", "githubUser", "userRepoPath", "machineId", "machineAlias")) {
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

# --- 3. One ACTION for the advice. It must stay after the config row: Write-Summary
# promotes an OK row to WARN once a warning is counted, and the LogWarn paired with
# the ACTION (script-standards-detail "Severity decision guide") is counted. The row
# reports the write; the footer still counts this warning. ---
# The re-key advice assumes user init calls aitools-profile migrate (re-key batch 5).
# -NoMachine: no Need* flag is set (the advice is the caller's), so no ACTION.
if ($deriveRc -eq 0) {
    $advice = ""
    if ($script:NeedInit) { $advice = "Run: aitools user init (registers this machine)" }
    elseif ($script:NeedMigrate) { $advice = "Run: aitools user init (re-keys machine profiles by machine id)" }
    elseif ($script:NeedUpdate) { $advice = "Run: aitools user init (updates this machine's profile)" }
    if ($advice) {
        LogWarn "config: $advice"
        Write-Summary "ACTION" "" $advice
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
