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
# Managed: ~/.claude/rules/*.md fanned out from ~/.aitools/rules (additive; the
#   copy of a rule the rules manifest retires is backed up and removed)
# Preserved: ~/.claude/rules/ files not in ~/.aitools/rules
# Managed: ~/.claude/skills/<name>/** fanned out from ~/.aitools/skills (additive;
#   the copy of a skill the skills manifest retires is backed up to
#   ~/.claude/skills.bak.<UTC>/ and removed)
# Preserved: ~/.claude/skills/ directories and symlinks not deployed from ~/.aitools/skills
# Rules and skills come from ~/.aitools only (deploy-harness fills it: run it
# first); the dotprofile's claude/rules and claude/skills reach Claude Code through it.

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
# The directory this script runs from (aitools scripts/ on the dev path, the
# dotprofile's deploy/ for the generated copy): the rules fan-out derives the
# aitools checkout from it (SCRIPT_DIR in setup-user-claude.sh)
$claudeScriptDir = $PSScriptRoot

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
# Rules fan-out: .aitools\rules -> .claude\rules. deploy-harness fills
# .aitools\rules from aitools shared/rules, aitools .claude/rules and the
# dotprofile's claude/rules (first source wins) and writes its rules manifest
# (PR #100 contract). Claude Code gets every rule there except the ones the
# manifest retires (commander decisions 2026-10-22): *.md only, *.bak.* and
# hidden files skipped, names compared case-insensitively. The dotprofile's
# claude/rules is not read here. Additive: managed files updated, unmanaged
# files preserved; the copy of a retired rule is backed up and removed when it
# matches a harness copy. Adopt target: the repo file the manifest names as the
# rule's source, when it is on this machine. Parity: setup-user-claude.sh.
$rulesSrc = Join-Path (Join-Path $env:USERPROFILE ".aitools") "rules"
$rulesDest = Join-Path $claudeDir "rules"
$rulesManifest = Join-Path $rulesSrc ".aitools-rules-manifest"
# The aitools checkout this script runs from: adopt targets of shared and
# aitools rules. Only a git checkout counts: the generated deploy/ copy runs
# from the dotprofile's deploy/ directory, and a package payload (git archive,
# read-only) has no .git; adopt is then offered for dotprofile rules only.
$rulesAitoolsRepo = ""
if ($claudeScriptDir) {
    $rulesRepoCand = Split-Path -Parent $claudeScriptDir
    if ((Test-Path -LiteralPath (Join-Path (Join-Path $rulesRepoCand "scripts") "aitools-lib.ps1") -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path (Join-Path $rulesRepoCand "shared") "claude-shared.md") -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $rulesRepoCand ".git"))) {
        $rulesAitoolsRepo = $rulesRepoCand
    }
}

# --- BEGIN rules deploy logic (extracted by build-deploy) ---
# The repo file that a rule from Source (a rules manifest source) came from, or
# "" when that file is not on this machine (adopt and merge are then not
# offered). A dotprofile adopt target is committed and pushed by the library
# (N-Q2); an aitools one is a working-tree change. Parity: rule_adopt_target in
# setup-user-claude.sh.
function Get-RuleAdoptTarget([string]$Name, [string]$Source) {
    $target = ""
    if ($Source -ceq "shared" -and $rulesAitoolsRepo) {
        $target = Join-Path (Join-Path (Join-Path $rulesAitoolsRepo "shared") "rules") $Name
    } elseif ($Source -ceq "aitools" -and $rulesAitoolsRepo) {
        $target = Join-Path (Join-Path (Join-Path $rulesAitoolsRepo ".claude") "rules") $Name
    } elseif ($Source -ceq "dotprofile" -and $userRepoPath) {
        $target = Join-Path (Join-Path (Join-Path $userRepoPath "claude") "rules") $Name
    }
    if ($target -and (Test-Path -LiteralPath $target -PathType Leaf)) { return $target }
    return ""
}

# Byte comparison of a retired rule's copy with its harness copies and
# backups: the lib's Test-FanoutTextEqual (0 equal apart from trailing CR/LF,
# 1 differ, 2 unreadable; parity fanout_text_equal).

$rulesGo = $false
$rulesEntries = @()
if (-not (Test-Path -LiteralPath $rulesSrc -PathType Container)) {
    Log "No harness rules at $rulesSrc (deploy-harness has not run) -- skipping"
    Write-Summary "OK" "claude rules" "n/a (no harness rules)"
} else {
    try {
        $rulesEntries = @(Get-ChildItem -LiteralPath $rulesSrc -ErrorAction Stop | Sort-Object Name)
        $rulesGo = $true
    } catch {
        LogError "Cannot list $rulesSrc -- $_"
        Write-Summary "ERROR" "claude rules" "cannot read harness rules"
    }
}

# Rules manifest: each rule's source (adopt target) and the retired names.
# Without one (deploy-harness before PR #100) every rule is fanned out, none
# is retired and adopt is not offered.
$manifestOk = $false
$manifestFailed = $false   # unreadable: counted as a failed item, so the final row is ERROR
$ruleSourceOf = @{}   # name -> source; PowerShell hashtable keys are case-insensitive
$retiredNames = New-Object System.Collections.Generic.List[string]
$retiredSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
if ($rulesGo) {
    if (-not (Test-Path -LiteralPath $rulesManifest -PathType Leaf)) {
        Log "No rules manifest at $rulesManifest -- every rule fanned out, none retired, adopt not offered"
    } else {
        $manifest = $null
        try {
            $manifest = Read-RulesManifest $rulesManifest
        } catch {
            LogError "Cannot read the rules manifest ${rulesManifest}: $_ -- every rule fanned out, none retired"
            Write-Summary "ERROR" "claude rules" "cannot read rules manifest"
            $manifestFailed = $true
        }
        if ($manifest -and $manifest.Status -eq "header-bad") {
            LogWarn "Rules manifest ${rulesManifest}: the first line is not `"$rulesManifestHeader`" -- every rule fanned out, none retired, adopt not offered"
            Write-Summary "ACTION" "" "Run aitools to rebuild ~/.aitools/rules and its manifest"
        } elseif ($manifest) {
            $manifestOk = $true
            foreach ($bad in $manifest.Invalid) { LogWarn "Rules manifest ${rulesManifest}: line ignored: $bad" }
            foreach ($r in $manifest.Rules) {
                if ($r.Source -ceq "retired") {
                    $retiredNames.Add($r.Name); [void]$retiredSet.Add($r.Name)
                } else {
                    $ruleSourceOf[$r.Name] = $r.Source
                }
            }
        }
    }
}

# Source files: every *.md in .aitools\rules (flat, the deploy-harness
# contract) that the manifest does not retire. Hidden files are skipped.
$ruleSources = @()
$ruleBroken = @()   # dangling symlinks: failed in the deploy loop
if ($rulesGo) {
    foreach ($entry in $rulesEntries) {
        $kind = Get-RuleNameKind $entry.Name
        if ($kind -eq "backup" -or $kind -eq "hidden") { continue }
        if ($kind -ne "rule") {
            Log "Ignoring non-rule file in harness rules: $($entry.Name) (only *.md is fanned out)"
            continue
        }
        if ($retiredSet.Contains($entry.Name)) {
            Log "Not fanned out: $($entry.Name) (retired in the rules manifest)"
            continue
        }
        if ($entry.LinkType) {
            # Test-Path is true for a dangling link on pwsh 7; check the final target
            $linkOk = $false
            try {
                $linkOk = [bool]$entry.ResolveLinkTarget($true).Exists
            } catch {
                LogDetail "claude rules: cannot resolve the link $($entry.FullName): $_"
                $linkOk = $false
            }
            if (-not $linkOk) { $ruleBroken += $entry.Name; continue }
        }
        if ($entry.PSIsContainer) { Log "Ignoring non-file in harness rules: $($entry.Name)"; continue }
        $ruleSources += $entry
    }

    if ($ruleSources.Count -eq 0 -and $ruleBroken.Count -eq 0 -and $retiredNames.Count -eq 0) {
        Log "No rules in $rulesSrc -- skipping"
        # An unreadable manifest already wrote this tool's ERROR row
        if (-not $manifestFailed) { Write-Summary "OK" "claude rules" "n/a (no harness rules)" }
        $rulesGo = $false
    } elseif (-not $DryRun) {
        Backup-Dir -DirPath $rulesDest
        if (-not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
            $mkdirError = ""
            try {
                New-Item -ItemType Directory -Path $rulesDest -Force -ErrorAction Stop | Out-Null
            } catch {
                $mkdirError = "$_"
            }
            # New-Item -Force can return without an error when a file is in
            # the way: check the result (parity with mkdir -p in the .sh)
            if (-not (Test-Path -LiteralPath $rulesDest -PathType Container)) {
                if (-not $mkdirError) { $mkdirError = "not a directory" }
                LogError "Cannot create $rulesDest ($mkdirError)"
                Write-Summary "ERROR" "claude rules" "cannot create rules dir"
                $rulesGo = $false
            }
        }
    }
}

if ($rulesGo) {
    Initialize-DeployTracker
    $errorsBefore = $errors
    if ($manifestFailed) {
        Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName ".aitools-rules-manifest"
    }
    foreach ($brokenName in $ruleBroken) {
        LogError "Failed: ${brokenName}: dangling symlink in $rulesSrc"
        Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $brokenName
    }

    # Deploy loop. [x]abort exits 2 from the library here: no "claude rules" row
    # is written, and the calling installer or aitools loop records
    # "script failed (exit 2)".
    $ruleDests = New-Object System.Collections.Generic.List[string]   # deployed names
    $ruleDestsLc = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($src in $ruleSources) {
        $ruleName = $src.Name
        # Two harness rules whose names differ only in case (possible on a
        # case-sensitive file system) map to one file here: the first wins
        if ($ruleDestsLc.Contains($ruleName)) {
            LogError "Skipped duplicate: $ruleName (a harness rule whose name differs only in case was already deployed)"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $ruleName
            continue
        }
        $ruleDests.Add($ruleName); [void]$ruleDestsLc.Add($ruleName)
        $ruleSource = ""
        $ruleAdoptPath = ""
        if ($manifestOk -and $ruleSourceOf.ContainsKey($ruleName)) {
            $ruleSource = $ruleSourceOf[$ruleName]
            $ruleAdoptPath = Get-RuleAdoptTarget $ruleName $ruleSource
        }
        $ruleSourceShown = if ($ruleSource) { $ruleSource } else { "unknown" }
        $ruleAdoptShown = if ($ruleAdoptPath) { $ruleAdoptPath } else { "none" }
        LogDetail "claude rules: $ruleName source=$ruleSourceShown adopt=$ruleAdoptShown"
        try {
            $ruleContent = [System.IO.File]::ReadAllText($src.FullName, [System.Text.UTF8Encoding]::new($false))
        } catch {
            LogError "Cannot read harness rule $($src.FullName): $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $ruleName
            continue
        }
        $ruleResult = Deploy-ManagedFile -Content $ruleContent -DestPath (Join-Path $rulesDest $ruleName) -ToolName "claude rules" -ItemName $ruleName -AdoptPath $ruleAdoptPath
        switch ($ruleResult) {
            { $_ -in @("created", "updated", "verified", "accept & adopt", "skipped", "failed") } {
                # The library wrote LOCAL and the adopt target itself (it commits
                # and pushes a dotprofile adopt target, N-Q2); the tracker records
                # every outcome (failed -> ERROR row, skipped -> WARN row).
            }
            default {
                LogError "Unexpected deploy result for ${ruleName}: $ruleResult"
                $ruleResult = "failed"
            }
        }
        Record-DeployOutcome -Outcome $ruleResult -ToolName "claude rules" -ItemName $ruleName
    }

    # Retired rules: the copy in .claude\rules is backed up and removed when it
    # is this fan-out's copy -- the same text as the harness copy or as a backup
    # deploy-harness made when it retired the rule. Any other file of that name
    # may be the user's own: kept, with a warning.
    $rmKept = New-Object System.Collections.Generic.List[string]
    foreach ($rmName in $retiredNames) {
        # Deployed this run under a name that differs only in case
        if ($ruleDestsLc.Contains($rmName)) { continue }
        # The copy in .claude\rules, found case-insensitively (a case-sensitive
        # file system may hold it as Gone.md for the manifest's gone.md)
        $rmPath = ""
        if (Test-Path -LiteralPath $rulesDest -PathType Container) {
            try {
                foreach ($f in @([System.IO.Directory]::GetFiles($rulesDest) | Sort-Object -CaseSensitive)) {
                    if ([string]::Equals([System.IO.Path]::GetFileName($f), $rmName, [System.StringComparison]::OrdinalIgnoreCase)) { $rmPath = $f; break }
                }
            } catch {
                LogWarn "Cannot list $rulesDest for retired rule $rmName -- $_"
            }
        }
        if (-not $rmPath) { continue }
        $rmFile = [System.IO.Path]::GetFileName($rmPath)
        try {
            $null = [System.IO.File]::ReadAllBytes($rmPath)
        } catch {
            LogError "Cannot read $rmPath -- retired rule not removed: $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        $rmCands = New-Object System.Collections.Generic.List[string]
        $rmCands.Add((Join-Path $rulesSrc $rmName))
        try {
            $rmBaks = @([System.IO.Directory]::GetFiles($rulesSrc) |
                Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmName.bak.", [System.StringComparison]::Ordinal) } |
                Sort-Object -Property { [System.IO.Path]::GetFileName($_) } -CaseSensitive)
            foreach ($b in $rmBaks) { $rmCands.Add($b) }
        } catch {
            LogWarn "Cannot list the backups of $rmName in ${rulesSrc}: $_"
        }
        $rmWhy = ""
        foreach ($rmCand in $rmCands) {
            if (-not (Test-Path -LiteralPath $rmCand -PathType Leaf)) { continue }
            $rmRc = Test-FanoutTextEqual $rmPath $rmCand
            if ($rmRc -eq 0) {
                $rmWhy = "same text as $([System.IO.Path]::GetFileName($rmCand))"
                break
            }
            if ($rmRc -ne 1) { LogWarn "Cannot compare $rmPath with $rmCand" }
        }
        if (-not $rmWhy) {
            LogWarn "Kept ${rmFile}: the rules manifest retires $rmName, but this file matches no harness copy (it may be your own) -- Claude Code still loads it; delete it if it is an old fan-out copy"
            $rmKept.Add($rmFile)
            continue
        }
        if ($DryRun) {
            Log "[DRY RUN] Would back up and remove $rmFile (retired rule; $rmWhy)"
            continue
        }
        Backup-File -FilePath $rmPath
        # Belt and braces: remove only when a backup with the same text exists
        # beside it (a backup step that reports success without a copy must not
        # lose the file)
        $rmBacked = $false
        if ($script:BackupFileOk) {
            try {
                foreach ($b in @([System.IO.Directory]::GetFiles($rulesDest) |
                        Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$rmFile.bak.", [System.StringComparison]::Ordinal) })) {
                    if ((Test-FanoutTextEqual $rmPath $b) -eq 0) { $rmBacked = $true; break }
                }
            } catch {
                LogWarn "Cannot list the backups of $rmFile in ${rulesDest}: $_"
            }
        }
        if (-not $rmBacked) {
            LogError "Not removed: $rmFile (retired rule): backup failed"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        try {
            Remove-Item -LiteralPath $rmPath -Force -ErrorAction Stop
        } catch {
            LogError "Cannot remove $rmPath (retired rule) -- $_"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        if (Test-Path -LiteralPath $rmPath) {
            LogError "Cannot remove $rmPath (retired rule): still present"
            Record-DeployOutcome -Outcome "failed" -ToolName "claude rules" -ItemName $rmFile
            continue
        }
        Log "Removed $rmFile (retired rule; $rmWhy; backup kept)"
        Record-DeployOutcome -Outcome "removed" -ToolName "claude rules" -ItemName $rmFile
    }
    if ($rmKept.Count -gt 0) {
        Write-Summary "ACTION" "" "Claude Code still loads retired rules in ~/.claude/rules: $($rmKept -join ', ') -- delete them unless you wrote them"
    }

    if ($DryRun) {
        if ($script:dtFailed -gt 0) {
            Write-Summary "ERROR" "claude rules" "$($script:dtFailed) failed (dry run)"
        } else {
            Write-Summary "OK" "claude rules" "dry run (no files written)"
        }
    } else {
        # Preserved: rules in .claude\rules not fanned out this run
        $destEntries = @()
        try {
            $destEntries = @(Get-ChildItem -LiteralPath $rulesDest -File -ErrorAction Stop | Sort-Object Name)
        } catch {
            LogWarn "Cannot list $rulesDest for the preserved report -- $_"
        }
        foreach ($existing in $destEntries) {
            if ((Get-RuleNameKind $existing.Name) -ne "rule") { continue }
            if (-not $ruleDestsLc.Contains($existing.Name)) {
                Log "Preserved unmanaged rule: $($existing.Name)"
                Record-DeployOutcome -Outcome "preserved" -ToolName "claude rules" -ItemName $existing.Name
            }
        }

        # Post-write validation: each deployed file is non-empty (a file whose
        # deploy failed is already reported; the library left it as it was)
        foreach ($ruleName in $ruleDests) {
            $destFile = Join-Path $rulesDest $ruleName
            if ((Test-Path -LiteralPath $destFile -PathType Leaf) -and (Get-Item -LiteralPath $destFile).Length -eq 0) {
                LogError "Validation failed: $ruleName is empty after deploy"
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
}
# --- END rules deploy logic (extracted by build-deploy) ---
# --- END rules deployment (extracted by build-deploy) ---

# --- BEGIN skills fan-out (extracted by build-deploy) ---
# Skills fan-out: .aitools\skills -> .claude\skills (lib
# Invoke-HarnessSkillsFanout; plans/skills-and-rules-fanout.md section 3.4).
# Every skill deploy-harness collected there except the retired ones; a user's
# own skill (a directory or symlink the fan-out did not deploy) is never
# touched. Adopt targets: this aitools checkout ($rulesAitoolsRepo, a git
# checkout only) and the dotprofile. Parity: setup-user-claude.sh.
Invoke-HarnessSkillsFanout -ToolName "claude skills" -DestDir (Join-Path $claudeDir "skills") -AitoolsRepo $rulesAitoolsRepo -Dotprofile $userRepoPath
# --- END skills fan-out (extracted by build-deploy) ---

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
