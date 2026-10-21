# setup-user-config.ps1 -- the only writer of ~/.aitools/config.json (Windows)
#
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.js (dotprofile path, GitHub user, machine alias). NOT a writer
# of profile.json (machine registration is `aitools user init`). NOT an
# interactive prompt (callers prompt, then pass -MachineAlias). NOT the
# settings.json sync (setup-user-settings). Consumed by: aitools-install.ps1
# Step 5, `aitools user init` (aitools.ps1), and the `aitools` sync deploy list.
#
# Safe to re-run: unchanged inputs produce "verified" and no write.
# Platform: Windows. On macOS/Linux use setup-user-config.sh.
# Reference: reference/user-repo.md "Config Schema" and "Resolution".
#
# Managed fields: version, meta, reposPath, repoPath (from parameters; kept when not passed),
#   googleDrives (from -DrivesJson when it is a non-empty array; else kept, or @()),
#   githubUser, userRepoPath, machineAlias (derived; kept when derivation fails)
# Preserved: all other keys
# Write path: merge in memory -> temp file -> ValidateJsonConfig -> Backup-File -> move.
#   Bootstrap merge is native PowerShell (no node needed); derivation needs node.

param(
    [string]$ReposPath = "",
    [string]$RepoPath = "",
    [string]$DrivesJson = "[]",
    [string]$GithubUser = "",
    [string]$UserRepoPath = "",
    [string]$MachineAlias = "",
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Help
)

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-config"

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use setup-user-config.sh."
    exit 1
}

if ($Help) {
    [Console]::WriteLine(@"
setup-user-config.ps1 -- write ~/.aitools/config.json (the only writer)

  -ReposPath P      Base directory for repos (bootstrap; installer Step 3)
  -RepoPath P       Path to the aitools repo (bootstrap; installer)
  -DrivesJson JSON  Detected Google Drives, JSON array (installer Step 4)
  -GithubUser U     GitHub user; names the dotprofile aitools-<U> (user init)
  -UserRepoPath P   Dotprofile path chosen by user init
  -MachineAlias A   Profile alias chosen by user init (explicit choice)
  -DryRun           Show what would change; write nothing
  -Help             This text

Without parameters: re-derive userRepoPath / githubUser / machineAlias from profile.json.
"@)
    exit 0
}
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = $true }

$configDir = Join-Path $HOME ".aitools"
$configFile = Join-Path $configDir "config.json"
$configTmp = "$configFile.tmp.$PID"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

# --- 1. Derive values from profile.json (aitools-profile.js) ---
$derived = @{}
if ((Get-Command node -ErrorAction SilentlyContinue) -and (Get-AitoolsProfileJs)) {
    $deriveArgs = @("derive-config", "--config", $configFile, "--environment", $script:AitoolsEnvironment)
    if ($ReposPath) { $deriveArgs += @("--repos-path", $ReposPath) }
    if ($GithubUser) { $deriveArgs += @("--github-user", $GithubUser) }
    if ($UserRepoPath) { $deriveArgs += @("--user-repo-path", $UserRepoPath) }
    if ($MachineAlias) { $deriveArgs += @("--alias", $MachineAlias) }
    $r = Invoke-AitoolsProfileJs -Arguments $deriveArgs
    $d = $r.Data
    if (-not $d) {
        LogError "Failed: profile derivation produced no output (exit $($r.Code))"
        Write-Summary "ERROR" "aitools config" "derivation failed"
    } else {
        foreach ($w in @($d.warnings)) { if ($w) { LogWarn "config: $w" } }
        foreach ($e in @($d.errors)) { if ($e) { LogError "config: $e" } }
        if ($d.derived) {
            foreach ($p in $d.derived.PSObject.Properties) { if ($p.Value) { $derived[$p.Name] = "$($p.Value)" } }
        }
        $dp = if ($derived["userRepoPath"]) { $derived["userRepoPath"] } else { "none" }
        $ma = if ($derived["machineAlias"]) { $derived["machineAlias"] } else { "none" }
        Log "config: dotprofile=$dp via=$($d.userRepoVia) machineAlias=$ma via=$($d.via) company=$($d.company) id=$($d.machineId) hosts=$(@($d.hostnames) -join '/')"
        switch ($r.Code) {
            0 { }
            1 { Log "config: no dotprofile yet -- writing bootstrap keys only (shared-only mode)" }
            default {
                Write-Summary "ERROR" "machine profile" "no machine match"
                Write-Summary "ACTION" "" "Run: aitools user init (profiles: $(@($d.aliases) -join ', '))"
            }
        }
    }
} elseif (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    LogWarn "config: node not available -- profile derivation skipped (node arrives in installer Step 8)"
    Write-Summary "WARN" "aitools config" "derivation skipped (no node)"
} else {
    LogError "config: aitools-profile.js not found next to aitools-lib.ps1"
    Write-Summary "ERROR" "aitools config" "resolver missing"
}

# --- 2. Merge (read-then-merge; managed keys only) ---
$managedKeys = @("version", "meta", "reposPath", "repoPath", "googleDrives", "githubUser", "userRepoPath", "machineAlias")
$intent = [ordered]@{
    purpose  = "Per-machine pointers that let aitools find its repos and this machine profile, built from profile.json"
    scope    = "Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineAlias). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer"
    audience = "read_config_key/ReadConfigKey callers, resolve_user_repo_path/Resolve-UserRepoPath, ait-harvest.py, hh, check-lib; written by setup-user-config.sh/.ps1"
}

if ($DryRun) {
    Log "[DRY RUN] Would merge config into $configFile (derived: $(($derived.Keys | ForEach-Object { "$_=$($derived[$_])" }) -join ' '))"
    Write-Summary "OK" "aitools config" "dry run"
} else {
    $configState = "created"
    $configReadOk = $true
    $cfg = [pscustomobject]@{}
    if (Test-Path $configFile) {
        $rawConfig = $null
        try {
            $rawConfig = [System.IO.File]::ReadAllText($configFile)
        } catch {
            LogError "Failed: ${configFile}: could not read -- $_ -- existing file left untouched"
            Write-Summary "ERROR" "aitools config" "read failed"
            $configReadOk = $false
        }
        if ($configReadOk) {
            $rawConfig = $rawConfig.TrimStart([char]0xFEFF)  # PowerShell 5.x writes a BOM
            try {
                $parsed = $rawConfig | ConvertFrom-Json -ErrorAction Stop
                if ($parsed -isnot [System.Management.Automation.PSCustomObject]) { throw "top level is not an object" }
                $cfg = $parsed
                $configState = "updated"
            } catch {
                $corruptReason = "$_"
                $cfg = [pscustomobject]@{}
                foreach ($k in @("userRepoPath", "machineAlias", "githubUser", "reposPath", "repoPath")) {
                    $m = [regex]::Match($rawConfig, '"' + $k + '"\s*:\s*"((?:[^"\\]|\\.)*)"')
                    if ($m.Success) {
                        try {
                            $val = ('"' + $m.Groups[1].Value + '"') | ConvertFrom-Json -ErrorAction Stop
                            $cfg | Add-Member -NotePropertyName $k -NotePropertyValue $val -Force
                            Log "Recovered $k from the invalid config"
                        } catch {
                            LogWarn "Could not recover $k from the invalid config: $_"
                        }
                    }
                }
                $configState = "recovered"
            }
        }
    }

    $drives = @()
    try {
        $drives = @($DrivesJson | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        LogError "Failed: -DrivesJson is not valid JSON -- $_"
        Write-Summary "ERROR" "aitools config" "bad drives input"
        $configReadOk = $false
    }

    if ($configReadOk) {
        $beforeJson = @{}
        foreach ($k in $managedKeys) {
            $beforeJson[$k] = if ($cfg.PSObject.Properties.Name -contains $k) { ConvertTo-Json -InputObject $cfg.$k -Depth 10 -Compress } else { $null }
        }
        function Set-ConfigKey($Name, $Value) {
            if ($cfg.PSObject.Properties.Name -contains $Name) { $cfg.$Name = $Value }
            else { $cfg | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
        }
        Set-ConfigKey "version" 3
        if ($ReposPath) { Set-ConfigKey "reposPath" $ReposPath }
        if ($RepoPath) { Set-ConfigKey "repoPath" $RepoPath }
        if ($drives.Count -gt 0) {
            Set-ConfigKey "googleDrives" @($drives | ForEach-Object { [ordered]@{ path = $_.path; account = $_.account; label = $_.label } })
        } elseif (-not ($cfg.PSObject.Properties.Name -contains "googleDrives") -or $cfg.googleDrives -isnot [array]) {
            Set-ConfigKey "googleDrives" @()
        }
        foreach ($k in @("githubUser", "userRepoPath", "machineAlias")) {
            if ($derived.ContainsKey($k) -and $derived[$k]) { Set-ConfigKey $k $derived[$k] }
        }
        $derivedFrom = if ($cfg.PSObject.Properties.Name -contains "userRepoPath" -and $cfg.userRepoPath) { "profile.json" } else { "bootstrap only" }
        Set-ConfigKey "meta" ([ordered]@{ intent = $intent; writer = "setup-user-config"; derivedFrom = $derivedFrom })

        $configChanges = @()
        foreach ($k in $managedKeys) {
            $after = if ($cfg.PSObject.Properties.Name -contains $k) { ConvertTo-Json -InputObject $cfg.$k -Depth 10 -Compress } else { $null }
            if ($beforeJson[$k] -ne $after -and $k -ne "meta") {
                $old = if ($null -eq $beforeJson[$k]) { "(unset)" } else { $beforeJson[$k] }
                $configChanges += "${k}: $old -> $after"
            }
        }
        $metaChanged = ($beforeJson["meta"] -ne (ConvertTo-Json -InputObject $cfg.meta -Depth 10 -Compress))
        $missing = @("reposPath", "repoPath") | Where-Object { -not ($cfg.PSObject.Properties.Name -contains $_) -or -not $cfg.$_ }

        if ($missing) {
            LogError "Failed: ${configFile}: missing bootstrap $($missing -join ', ') (run aitools install)"
            Write-Summary "ERROR" "aitools config" "missing bootstrap values"
        } elseif ($configState -eq "updated" -and $configChanges.Count -eq 0 -and -not $metaChanged) {
            LogOk "Verified: $configFile (unchanged)"
            Write-Summary "OK" "aitools config" "verified"
        } else {
            $errorsBeforeWrite = $script:errors
            $configFailure = "write failed"
            try {
                $jsonContent = ConvertTo-Json -InputObject $cfg -Depth 10
                [System.IO.File]::WriteAllText($configTmp, $jsonContent + "`n", [System.Text.UTF8Encoding]::new($false))
            } catch {
                LogError "Failed: ${configFile}: could not write the merged config -- $_"
            }
            if ($script:errors -eq $errorsBeforeWrite) {
                $configFailure = "validation failed"
                ValidateJsonConfig -File $configTmp -RequiredKeys @("version", "reposPath", "repoPath")
            }
            if ($script:errors -eq $errorsBeforeWrite) {
                $configFailure = "write failed"
                Backup-File $configFile
                try {
                    Move-Item -Path $configTmp -Destination $configFile -Force -ErrorAction Stop
                } catch {
                    LogError "Failed: ${configFile}: could not replace the config file -- $_"
                }
            }
            if ($script:errors -gt $errorsBeforeWrite) {
                if (Test-Path $configTmp) {
                    try { Remove-Item $configTmp -Force -ErrorAction Stop }
                    catch { LogWarn "Could not remove temp file ${configTmp}: $_" }
                }
                Write-Summary "ERROR" "aitools config" $configFailure
            } else {
                switch ($configState) {
                    "recovered" {
                        LogWarn "$configFile was not valid JSON ($corruptReason) -- rebuilt; the invalid copy was backed up"
                        Write-Summary "WARN" "aitools config" "rebuilt (was invalid)"
                    }
                    "created" { LogOk "Created: $configFile"; Write-Summary "OK" "aitools config" "created" }
                    default   { LogOk "Updated: $configFile"; Write-Summary "OK" "aitools config" "updated" }
                }
                foreach ($c in $configChanges) {
                    Log "  $c"
                    Write-Summary "DETAIL" "aitools config" "$(($c -split ':')[0]) updated"
                }
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
