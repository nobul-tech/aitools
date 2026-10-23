# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run -- replaces existing file with latest version.
#
# Sources (in priority order):
#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
#   2. shared/claude-shared.md          (fallback template from aitools repo)
#
# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
# machine's profile from profile.json. See reference/user-repo.md.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/ (additive deploy)
# Preserved: ~/.claude/rules/ files not in user repo source

param(
    [string]$SharedPath = (Join-Path $PSScriptRoot "..\shared\claude-shared.md"),
    [switch]$DryRun,
    [switch]$Force
)

# --- BEGIN preamble (extracted by build-deploy) ---

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-claude"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- PS 7 version guard ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    LogError "This script requires PowerShell 7+. Current: $($PSVersionTable.PSVersion)"
    LogWarn "Install: winget install --id Microsoft.PowerShell --source winget"
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- END preamble (extracted by build-deploy) ---

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        try {
            New-Item -ItemType Directory -Path $claudeDir -Force -ErrorAction Stop | Out-Null
        } catch {
            LogError "Cannot create $claudeDir ($_)"
            Write-Summary "ERROR" "claude.md" "cannot create ~/.claude"
            exit 1
        }
        Log "Created $claudeDir"
    }
}

# --- Dotprofile and this machine's profile: one resolver (reference/user-repo.md
# "Resolution"). This script reads only the wrapper results (PR #80 contract),
# never profile.json or config.json itself: no alias lookup, no hostname or
# first-profile fallback. A miss never takes another machine's values: on no
# match the profile/identity values are identity-level only. The wrappers write
# the ERROR row and ACTION for their own failures; this script adds none. ---
$urpRc = Resolve-UserRepoPath       # 1 = shared-only (expected); 3 = logged error + ERROR row
$userRepoPath = $script:AitLibUserRepoPath
$userRepoVia = $script:AitLibUserRepoVia
if ($urpRc -eq 3) {
    # A dotprofile error is not "no dotprofile": deploying the shared template
    # would replace the personal CLAUDE.md and rules. The wrapper wrote the
    # ERROR "dotprofile" row; this is the claude.md outcome row (no ACTION).
    LogError "CLAUDE.md and rules not deployed: the dotprofile could not be resolved"
    Write-Summary "ERROR" "claude.md" "not deployed: dotprofile unresolved"
    exit 1
}
$profileRc = Resolve-MachineProfile # 1 = shared-only; 3 = no match / error (logged + ERROR row + ACTION)
$machineAlias = $script:AitLibMachineAlias
$machineVia = $script:AitLibMachineVia
$profileName = $script:AitLibProfileName
$profileCompany = $script:AitLibProfileCompany
$identityGitName = $script:AitLibIdentityGitName
$identityGitEmail = $script:AitLibIdentityGitEmail
LogDetail "setup-user-claude: dotprofile rc=$urpRc via=$userRepoVia; machine profile rc=$profileRc"
$userRepoDisplay = ""
if ($userRepoPath) {
    $userRepoDisplay = $userRepoPath
    $up = $env:USERPROFILE
    if ($up -and ($userRepoDisplay -eq $up -or $userRepoDisplay.StartsWith($up + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
        $userRepoDisplay = '%USERPROFILE%' + $userRepoDisplay.Substring($up.Length)
    }
}

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
$sourcePath = ""
$sourceLabel = ""
if ($userRepoPath) {
    $userClaudeMd = Join-Path $userRepoPath "claude\CLAUDE.md"
    if (Test-Path $userClaudeMd) {
        $sourcePath = $userClaudeMd
        $sourceLabel = "user repo"
    }
}

if (-not $sourcePath) {
    if (Test-Path $SharedPath) {
        $sourcePath = $SharedPath
        $sourceLabel = "shared template"
    } else {
        LogError "No template found. Checked user repo and $SharedPath"
        Write-Summary "ERROR" "claude.md" "no template found"
        exit 1
    }
}

Log "Template source: $sourcePath ($sourceLabel)"

# --- Read template content ---
try {
    $sharedContent = Get-Content -Path $sourcePath -Raw -ErrorAction Stop
} catch {
    LogError "Cannot read template: $sourcePath ($_)"
    Write-Summary "ERROR" "claude.md" "template unreadable"
    exit 1
}
if (-not $sharedContent) {
    LogError "Template is empty: $sourcePath"
    Write-Summary "ERROR" "claude.md" "template empty"
    exit 1
}

# --- Profile interpolation ---
# Values come from Resolve-MachineProfile above. String.Replace is literal ("$" in
# a value is not a regex group: the evaluator returns it as is). An empty value
# leaves its token in place. One pass: a value that contains token text is not
# substituted again (parity with setup-user-claude.sh).
$tokens = @{
    "PROFILE_NAME" = $profileName; "PROFILE_COMPANY" = $profileCompany
    "IDENTITY_GIT_NAME" = $identityGitName; "IDENTITY_GIT_EMAIL" = $identityGitEmail
    "USER_REPO_PATH" = $userRepoDisplay
}
$sharedContent = [regex]::Replace($sharedContent,
    '\{\{(PROFILE_NAME|PROFILE_COMPANY|IDENTITY_GIT_NAME|IDENTITY_GIT_EMAIL|USER_REPO_PATH)\}\}',
    [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $v = [string]$tokens[$m.Groups[1].Value]
        if ($v) { $v } else { $m.Value }
    })
if ($profileRc -eq 0) {
    Log "Profile interpolation: alias=$machineAlias via=$machineVia name=$profileName company=$profileCompany"
} elseif ($profileRc -eq 1) {
    LogWarn "No dotprofile -- {{PLACEHOLDER}} tokens will not be resolved"
    Write-Summary "WARN" "claude.md" "template tokens unresolved"
} else {
    Log "Profile interpolation: identity-level values only (no machine profile) -- machine-specific tokens may stay unresolved"
}

# --- Write or preview CLAUDE.md ---
try {
    $osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
} catch {
    LogDetail "footer OS: Get-CimInstance Win32_OperatingSystem failed ($_) -- using 'Windows'"
    $osInfo = ""
}
if (-not $osInfo) { $osInfo = "Windows" }
# Footer hostname: the resolver's (P-Q5, one hostname source: COMPUTERNAME,
# short, lower-case), read from Resolve-MachineProfile above. "unknown" when the
# resolver gave none (the resolver says why in a warning, logged as a detail line).
$machineHost = [string]$script:AitLibMachineHostname
if (-not $machineHost) { $machineHost = "unknown" }
$profileShown = if ($machineAlias) { $machineAlias } else { "unresolved" }

$content = @"
$sharedContent

## Machine-Specific

- Machine: $osInfo ($machineHost; profile $profileShown)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

# ---------------------------------------------------------------------------
# Adopt filter for CLAUDE.md (Deploy-ManagedFile -AdoptFilter): takes LOCAL
# content, returns the dotprofile template. Strips the machine-specific footer
# and reverse-tokenizes profile values, so the next run rebuilds the same
# CLAUDE.md from the template and verifies it. Empty profile values are never
# substituted (an empty pattern would match everywhere).
# ---------------------------------------------------------------------------
$claudeMdAdoptFilter = {
    param([string]$Deployed)
    # Everything before ## Machine-Specific; trailing newlines removed (parity
    # with claude_md_adopt_filter in setup-user-claude.sh)
    $m = [regex]::Match($Deployed, '(?m)^## Machine-Specific')
    if ($m.Success) {
        $Deployed = $Deployed.Substring(0, $m.Index)
    }
    $Deployed = $Deployed -replace '[\r\n]+$', ''
    # One pass over all values, longest first: a value inside a longer one
    # (company "nobul.tech" in email "jose@nobul.tech") never breaks the longer
    # one's token. Equal text keeps the first token in this order, so
    # {{PROFILE_NAME}} wins over {{IDENTITY_GIT_NAME}} (P-Q13). Case-sensitive,
    # like setup-user-claude.sh.
    $tok = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $vals = [System.Collections.Generic.List[object]]::new()
    $i = 0
    foreach ($pair in @(
            @($userRepoDisplay, 'USER_REPO_PATH'),
            @($profileName, 'PROFILE_NAME'),
            @($profileCompany, 'PROFILE_COMPANY'),
            @($identityGitName, 'IDENTITY_GIT_NAME'),
            @($identityGitEmail, 'IDENTITY_GIT_EMAIL'))) {
        $i++
        $v = [string]$pair[0]
        if (-not $v -or $tok.ContainsKey($v)) { continue }
        $tok[$v] = $pair[1]
        $vals.Add([pscustomobject]@{ V = $v; I = $i })
    }
    if ($vals.Count -eq 0) { return $Deployed }
    $ordered = $vals | Sort-Object @{ Expression = { $_.V.Length }; Descending = $true }, @{ Expression = { $_.I } }
    $pattern = ($ordered | ForEach-Object { [regex]::Escape($_.V) }) -join '|'
    return [regex]::Replace($Deployed, $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) '{{' + $tok[$m.Value] + '}}' })
}

if ($DryRun) {
    $existingLines = 0
    if (Test-Path $claudeMd) {
        $existingLines = (Get-Content $claudeMd).Count
    }
    $newLines = ($content -split "`n").Count
    Log "[DRY RUN] $claudeMd`: overwrite (sole owner)"
    Log "  Template source: $sourcePath ($sourceLabel)"
    if ($profileName) {
        Log "  Profile interpolation: name=$profileName company=$profileCompany"
    } else {
        Log "  Profile interpolation: none (tokens unresolved)"
    }
    Log "  Existing: $existingLines lines"
    Log "  New: $newLines lines"
    if (Test-Path $claudeMd) {
        try {
            $existingContent = Get-Content -LiteralPath $claudeMd -Raw -ErrorAction Stop
        } catch {
            LogWarn "Cannot read $claudeMd for the dry-run comparison: $_"
            $existingContent = ""
        }
        # Compared as Deploy-ManagedFile compares (trailing newlines removed,
        # case-sensitive; parity with setup-user-claude.sh)
        if (("$existingContent" -replace '[\r\n]+$', '') -ceq ($content -replace '[\r\n]+$', '')) {
            Log "[DRY RUN] Content unchanged"
            Write-Summary "OK" "claude.md" "verified"
        } else {
            Log "[DRY RUN] Content differs -- would overwrite"
            Write-Summary "OK" "claude.md" "dry-run: would update"
        }
    } else {
        Log "[DRY RUN] File does not exist -- would create"
        Write-Summary "OK" "claude.md" "dry-run: would create"
    }
} else {
    # --- Deploy CLAUDE.md via managed-file flow ---
    # Adopt target: the dotprofile template (the source of truth when a user
    # repo is configured). The library writes it, through $claudeMdAdoptFilter.
    $claudeAdoptPath = ""
    if ($userRepoPath) { $claudeAdoptPath = Join-Path $userRepoPath "claude\CLAUDE.md" }
    $claudeResult = Deploy-ManagedFile -Content $content -DestPath $claudeMd -ToolName "claude.md" -ItemName "CLAUDE.md" `
        -AdoptPath $claudeAdoptPath -AdoptFilter $claudeMdAdoptFilter

    switch ($claudeResult) {
        { $_ -eq "created" -or $_ -eq "updated" -or $_ -eq "accept & adopt" } {
            # Errors logged before this point (e.g. the machine-profile resolver)
            # are not validation failures
            $claudeErrsBefore = $errors
            # --- BEGIN post-write validation (extracted by build-deploy) ---
            # Post-write validation: check structure AND content (not just a marker)
            if (-not (Test-Path $claudeMd) -or (Get-Item $claudeMd).Length -eq 0) {
                LogError "Validation failed: $claudeMd is empty or missing"
            } else {
                $written = Get-Content $claudeMd -Raw
                if ($written -notmatch '## Machine-Specific') {
                    LogError "Validation failed: $claudeMd missing Machine-Specific section"
                }
                # Template body must be present -- a file with only the footer is corrupt
                if ($written -notmatch '## Coaching|## Code Style|## Tool') {
                    LogError "Validation failed: $claudeMd missing template body (only footer present?)"
                }
            }
            # --- END post-write validation (extracted by build-deploy) ---
            if ($errors -ne $claudeErrsBefore) {
                Write-Summary "ERROR" "claude.md" "validation failed"
            } elseif ($claudeResult -eq "accept & adopt") {
                Write-Summary "OK" "claude.md" "accepted to profile"
            } else {
                Write-Summary "OK" "claude.md" "$claudeResult"
            }
        }
        "skipped" {
            Write-Summary "WARN" "claude.md" "skipped (user review)"
        }
        "verified" {
            Log "CLAUDE.md verified (no differences)"
            Write-Summary "OK" "claude.md" "verified"
        }
        "failed" {
            # The library restored the files and logged the reason (LogError).
            Write-Summary "ERROR" "claude.md" "deploy failed"
        }
    }
}

# --- BEGIN rules deployment (extracted by build-deploy) ---
# Deploy user rules: additive (add/update managed, preserve unmanaged, log diffs).
$rulesSrc = ""
if ($userRepoPath) {
    $candidateRules = Join-Path $userRepoPath "claude\rules"
    if (Test-Path $candidateRules) {
        $rulesSrc = $candidateRules
    }
}

$rulesDest = Join-Path $claudeDir "rules"

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
if ($rulesSrc) {
    $sourceRules = Get-ChildItem -Path $rulesSrc -Filter "*.md" -File -ErrorAction Stop
    if (-not $sourceRules -or $sourceRules.Count -eq 0) {
        Log "User repo claude/rules/ exists but has no .md files -- skipping"
    } elseif ($DryRun) {
        $existingCount = 0
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            if ($existingFiles) { $existingCount = $existingFiles.Count }
        }
        Log "[DRY RUN] $rulesDest`: additive deploy"
        Log "  Source: $rulesSrc ($($sourceRules.Count) rule files)"
        Log "  Existing: $existingCount rule files"
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if (Test-Path $destFile) {
                try {
                    $oldContent = Get-Content $destFile -Raw -ErrorAction Stop
                    $newContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
                } catch {
                    LogWarn "Cannot compare $($rf.Name): $_"
                    Log "  Would update (cannot compare): $($rf.Name)"
                    continue
                }
                if ($oldContent -eq $newContent) {
                    Log "  Would skip (unchanged): $($rf.Name)"
                } else {
                    Log "  Would update (changed): $($rf.Name)"
                }
            } else {
                Log "  Would add (new): $($rf.Name)"
            }
        }
        # Show preserved files
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "  Would preserve (unmanaged): $($ef.Name)"
                }
            }
        }
    } else {
        Backup-Dir -DirPath $rulesDest
        if (-not (Test-Path $rulesDest)) {
            try {
                New-Item -ItemType Directory -Path $rulesDest -Force -ErrorAction Stop | Out-Null
            } catch {
                LogError "Cannot create $rulesDest ($_)"
                Write-Summary "ERROR" "claude rules" "cannot create rules dir"
                exit 1
            }
        }

        Initialize-DeployTracker
        $errorsBefore = $errors
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            # Adopt target: the dotprofile rule (the file deployed from). Empty
            # in the MDM deploy script (no user repo): adopt and merge not offered.
            $ruleAdoptPath = ""
            if ($userRepoPath) { $ruleAdoptPath = Join-Path (Join-Path $userRepoPath "claude\rules") $rf.Name }

            try {
                $ruleContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
            } catch {
                LogError "Cannot read source rule $($rf.Name): $_"
                Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rf.Name
                continue
            }
            $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath $destFile -ToolName "claude rules" -ItemName $rf.Name -AdoptPath $ruleAdoptPath

            if ($ruleResult -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed")) {
                # The library wrote LOCAL and the adopt target itself; the
                # tracker records every outcome (failed -> ERROR row).
            }
            Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $rf.Name
            # After accept & adopt or merge & adopt the library commits that one
            # dotprofile rule and pushes it (Invoke-DotprofileCommitPush, N-Q2;
            # commander confirmed 2026-10-21, contract item #11). No commit here.
        }

        # Log preserved files (in target but not in source)
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "Preserved unmanaged rule: $($ef.Name)"
                    Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $ef.Name
                }
            }
        }

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if ((Test-Path $destFile) -and (Get-Item $destFile).Length -eq 0) {
                LogError "Validation failed: $($rf.Name) is empty after deploy"
            }
        }

        if ($script:dtFailed -gt 0) {
            # Write-DeployTrackerSummary writes the ERROR row ("N failed")
            Write-DeployTrackerSummary -ToolName "claude rules"
            Log "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } elseif ($errors -eq $errorsBefore) {
            Write-DeployTrackerSummary -ToolName "claude rules"
            LogOk "Rules: $($script:deployTrackerText), $($script:dtPreserved) preserved in $rulesDest"
        } else {
            Write-Summary "ERROR" "claude rules" "validation failed"
        }
    }
} else {
    Log "No user rules to deploy (no claude/rules/ in user repo)"
}
# --- END rules deploy logic (extracted by build-deploy) ---
# --- END rules deployment (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
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
# --- END exit (extracted by build-deploy) ---
