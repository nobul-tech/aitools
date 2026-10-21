# --- DRAFT: insert into scripts/aitools-lib.ps1 directly after function ReadConfigKey ---
# (Also add "Resolve-UserRepoPath, Resolve-MachineProfile" to the "Provides:" header.)

# ---------------------------------------------------------------------------
# Dotprofile and machine-profile resolution (reference/user-repo.md "Resolution")
# Intent: give every PowerShell consumer the same answer as the bash lib to
# "where is the dotprofile" and "which profile is this machine", with the reason
# ("via") logged to deploy.log. Logic lives in aitools-profile.js (one definition).
# NOT a writer of config.json (only setup-user-config.ps1 writes it). NOT a writer
# of profile.json. Consumed by: setup-user-*.ps1, aitools.ps1, aitools-install.ps1,
# setup-user-config.ps1, generated deploy/*.ps1 (lib inlined; they set
# $env:AITOOLS_PROFILE_JS to their embedded copy).
# ---------------------------------------------------------------------------
function Get-AitoolsProfileJs {
    if ($env:AITOOLS_PROFILE_JS -and (Test-Path -LiteralPath $env:AITOOLS_PROFILE_JS)) { return $env:AITOOLS_PROFILE_JS }
    if ($PSScriptRoot) {
        $candidate = Join-Path $PSScriptRoot "aitools-profile.js"
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

# Invoke aitools-profile.js with --json; returns @{ Code = <exit>; Data = <object or $null> }.
function Invoke-AitoolsProfileJs {
    param([string[]]$Arguments)
    $js = Get-AitoolsProfileJs
    if (-not $js) { return @{ Code = 2; Data = $null; Missing = $true } }
    $outFile = [System.IO.Path]::GetTempFileName()
    try {
        # Output goes through a temp file read as UTF-8 (cross-platform.md: pipeline encoding)
        & node $js @Arguments > $outFile
        $code = $LASTEXITCODE
        $raw = [System.IO.File]::ReadAllText($outFile, [System.Text.Encoding]::UTF8)
    } finally {
        Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $outFile) { LogWarn "Could not remove temp file $outFile" }
    }
    $data = $null
    if ($raw -and $raw.Trim()) {
        try { $data = $raw | ConvertFrom-Json -ErrorAction Stop }
        catch { LogError "aitools-profile.js returned invalid JSON: $_"; return @{ Code = 2; Data = $null } }
    }
    # No JSON plus a non-zero exit is a crash (node's own exit 1), never "not found".
    if (-not $data -and $code -ne 0) {
        LogError "aitools-profile.js $($Arguments[0]) failed (exit $code) with no result"
        return @{ Code = 2; Data = $null }
    }
    if ($data -and $data.PSObject.Properties.Name -contains "error" -and $data.error) {
        LogError "aitools-profile.js: $($data.error)"
    }
    return @{ Code = $code; Data = $data }
}

# Resolve-UserRepoPath -- sets $script:UserRepoPath (native) and $script:UserRepoVia.
# Returns 0 found, 1 no dotprofile (shared-only), 2 error (logged).
function Resolve-UserRepoPath {
    $script:UserRepoPath = ""
    $script:UserRepoVia = "none"
    $cfg = Join-Path (Join-Path $HOME ".aitools") "config.json"
    if ((Get-Command node -ErrorAction SilentlyContinue) -and (Get-AitoolsProfileJs)) {
        $r = Invoke-AitoolsProfileJs -Arguments @("user-repo-path", "--config", $cfg, "--json")
        if ($r.Data) {
            foreach ($w in @($r.Data.warnings)) { if ($w) { LogWarn "dotprofile: $w" } }
            foreach ($e in @($r.Data.errors)) { if ($e) { LogError "dotprofile: $e" } }
        }
        if ($r.Code -eq 0 -and $r.Data -and $r.Data.path) {
            $script:UserRepoPath = $r.Data.path
            $script:UserRepoVia = $r.Data.via
            LogDetail "dotprofile=$($script:UserRepoPath) via=$($script:UserRepoVia)"
            return 0
        }
        if ($r.Code -ge 2) {
            if (-not ($r.Data -and @($r.Data.errors).Count -gt 0)) { LogError "dotprofile: resolver failed (exit $($r.Code))" }
            Write-Summary "ERROR" "dotprofile" "resolver failed"
            return 2
        }
        LogDetail "dotprofile: none found (shared-only mode)"
        return 1
    }
    # Degraded path (node absent, e.g. installer before Step 8): the cached pointer only.
    $raw = ReadConfigKey -File $cfg -Key "userRepoPath"
    if ($raw -and (Test-Path -LiteralPath $raw -PathType Container)) {
        $script:UserRepoPath = $raw
        $script:UserRepoVia = "config-nonode"
        LogDetail "dotprofile=$raw via=config-nonode (node not available)"
        return 0
    }
    LogDetail "dotprofile: none found (node not available; config.json has no valid userRepoPath)"
    return 1
}

# Resolve-MachineProfile -- sets $script:MachineAlias, $script:MachineVia,
# $script:ProfileFile, $script:ProfileName, $script:ProfileCompany,
# $script:IdentityGitName, $script:IdentityGitEmail, $script:IdentityGithub.
# Returns 0 resolved, 1 no dotprofile (shared-only), 2 no match or error
# (LogError + Write-Summary ERROR/ACTION already emitted).
function Resolve-MachineProfile {
    $script:MachineAlias = ""; $script:MachineVia = "none"; $script:ProfileFile = ""
    $script:ProfileName = ""; $script:ProfileCompany = ""
    $script:IdentityGitName = ""; $script:IdentityGitEmail = ""; $script:IdentityGithub = ""
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        LogWarn "machine profile: node not available -- profile values not resolved"
        Write-Summary "WARN" "machine profile" "node missing"
        return 1
    }
    if (-not (Get-AitoolsProfileJs)) {
        LogError "machine profile: aitools-profile.js not found next to aitools-lib.ps1 (and AITOOLS_PROFILE_JS unset)"
        Write-Summary "ERROR" "machine profile" "resolver missing"
        return 2
    }
    $cfg = Join-Path (Join-Path $HOME ".aitools") "config.json"
    $r = Invoke-AitoolsProfileJs -Arguments @("resolve", "--config", $cfg, "--environment", $script:AitoolsEnvironment)
    $d = $r.Data
    $hosts = ""; $mid = ""
    if ($d) {
        foreach ($w in @($d.warnings)) { if ($w) { LogWarn "machine profile: $w" } }
        foreach ($e in @($d.errors)) { if ($e) { LogError "machine profile: $e" } }
        if ($d.hostnames) { $hosts = (@($d.hostnames) -join "/") }
        if ($d.machineId) { $mid = $d.machineId }
        if ($d.profileFile) { $script:ProfileFile = $d.profileFile }
        # On no match the resolver still reports identity-level (machine-independent) values.
        if ($d.profile) {
            $script:ProfileName = "$($d.profile.name)"
            $script:ProfileCompany = "$($d.profile.company)"
            $script:IdentityGitName = "$($d.profile.gitName)"
            $script:IdentityGitEmail = "$($d.profile.gitEmail)"
            $script:IdentityGithub = "$($d.profile.github)"
        }
    }
    if ($r.Code -eq 0 -and $d -and $d.alias) {
        $script:MachineAlias = $d.alias
        $script:MachineVia = $d.via
        Log "machine profile: alias=$($script:MachineAlias) via=$($script:MachineVia) company=$($script:ProfileCompany) hosts=$hosts id=$mid"
        return 0
    }
    if ($r.Code -eq 1) { Log "machine profile: no dotprofile -- shared-only mode"; return 1 }
    LogError "machine profile: unresolved (via=none hosts=$hosts id=$mid) -- no other machine's values will be used"
    Write-Summary "ERROR" "machine profile" "no machine match"
    Write-Summary "ACTION" "" "Run: aitools user init (pick or register this machine's profile)"
    return 2
}
