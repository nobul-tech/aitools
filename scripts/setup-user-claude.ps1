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

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-claude"
$errors = 0
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg"; $script:errors++ }
function LogWarn($msg)  { Log "WARN: $msg" }
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) { Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${tool}|${detail}" }
}

# Backup a file before overwriting. Keeps at most $MaxBackups copies.
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

# --- BEGIN Backup-Dir (extracted by build-deploy) ---
function Backup-Dir {
    param([string]$DirPath, [int]$MaxBackups = 5)
    if (-not (Test-Path $DirPath)) { return }
    # Count managed files; skip if none
    $mdFiles = Get-ChildItem -Path $DirPath -Filter "*.md" -File -ErrorAction Stop
    if (-not $mdFiles -or $mdFiles.Count -eq 0) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${DirPath}.bak.${ts}"
    try {
        Copy-Item -Path $DirPath -Destination $backupPath -Recurse -ErrorAction Stop
    } catch {
        LogWarn "Could not back up $DirPath -- proceeding without backup: $_"
        return
    }
    # Prune old backups beyond limit
    $parentDir = Split-Path $DirPath -Parent
    $dirName = Split-Path $DirPath -Leaf
    $backups = Get-ChildItem -Path $parentDir -Directory -Filter "${dirName}.bak.*" -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending
    if ($backups.Count -gt $MaxBackups) {
        $backups | Select-Object -Skip $MaxBackups | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force
            Log "Pruned old backup: $($_.FullName)"
        }
    }
    Log "Backed up $DirPath ($($mdFiles.Count) managed files)"
}
# --- END Backup-Dir (extracted by build-deploy) ---

# --- PS 5.1 compatibility helper ---
function ConvertPSObjectToHashtable($obj) {
    if ($null -eq $obj) { return @{} }
    $ht = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
            $ht[$prop.Name] = ConvertPSObjectToHashtable $prop.Value
        } else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- PS 7 version guard ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: This script requires PowerShell 7+. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "Install: winget install --id Microsoft.PowerShell --source winget" -ForegroundColor Yellow
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# --- END preamble (extracted by build-deploy) ---

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Log "Created $claudeDir"
    }
}

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
$sourcePath = ""
$sourceLabel = ""
$userRepoPath = ""

if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $userRepoPath = $cfg["userRepoPath"]
            $userClaudeMd = Join-Path $userRepoPath "claude\CLAUDE.md"
            if (Test-Path $userClaudeMd) {
                $sourcePath = $userClaudeMd
                $sourceLabel = "user repo"
            }
        }
    } catch {
        LogWarn "Could not read config: $_"
    }
}

if (-not $sourcePath) {
    if (Test-Path $SharedPath) {
        $sourcePath = $SharedPath
        $sourceLabel = "shared template"
    } else {
        LogError "No template found. Checked user repo and $SharedPath"
        exit 1
    }
}

Log "Template source: $sourcePath ($sourceLabel)"

# --- Read template content ---
try {
    $sharedContent = Get-Content -Path $sourcePath -Raw -ErrorAction Stop
} catch {
    LogError "Cannot read template: $sourcePath ($_)"
    exit 1
}
if (-not $sharedContent) {
    LogError "Template is empty: $sourcePath"
    exit 1
}

# --- Profile interpolation ---
# Read profile.json and replace {{PLACEHOLDER}} tokens.
$profileName = ""
$profileCompany = ""
$identityGitName = ""
$identityGitEmail = ""

if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $profilePath = Join-Path $cfg["userRepoPath"] "profile.json"
            if (Test-Path $profilePath) {
                $pf = ConvertPSObjectToHashtable (Get-Content $profilePath -Raw | ConvertFrom-Json)
                $alias = ""
                if ($cfg.ContainsKey("machineAlias")) { $alias = $cfg["machineAlias"] }

                $prof = $null
                $ident = $null
                if ($pf.ContainsKey("version") -and $pf["version"] -eq 2) {
                    # v2: profiles + identity
                    if ($pf.ContainsKey("profiles")) {
                        $profiles = $pf["profiles"]
                        if ($alias -and $profiles.ContainsKey($alias)) {
                            $prof = $profiles[$alias]
                        } else {
                            # Fallback: hostname match, then first profile
                            $hn = $env:COMPUTERNAME
                            foreach ($key in $profiles.Keys) {
                                $p = $profiles[$key]
                                if ($p.ContainsKey("machine") -and $p["machine"].ContainsKey("hostname")) {
                                    $phn = ($p["machine"]["hostname"] -split '\.')[0]
                                    if ($phn -eq $hn) { $prof = $p; break }
                                }
                            }
                            if (-not $prof) {
                                $firstKey = @($profiles.Keys)[0]
                                if ($firstKey) { $prof = $profiles[$firstKey] }
                            }
                        }
                    }
                    if ($pf.ContainsKey("identity")) { $ident = $pf["identity"] }
                } else {
                    # v1: flat schema
                    $prof = @{}
                    if ($pf.ContainsKey("name")) { $prof["name"] = $pf["name"] }
                    if ($pf.ContainsKey("company")) { $prof["company"] = $pf["company"] }
                    $ident = @{ git = @{} }
                    if ($pf.ContainsKey("git")) {
                        $ident["git"] = $pf["git"]
                    } else {
                        if ($pf.ContainsKey("name")) { $ident["git"]["name"] = $pf["name"] }
                        if ($pf.ContainsKey("email")) { $ident["git"]["email"] = $pf["email"] }
                    }
                }

                if ($prof -and $prof.ContainsKey("name")) { $profileName = $prof["name"] }
                if ($prof -and $prof.ContainsKey("company")) { $profileCompany = $prof["company"] }
                if ($ident -and $ident.ContainsKey("git")) {
                    $gitIdent = $ident["git"]
                    if ($gitIdent.ContainsKey("name")) { $identityGitName = $gitIdent["name"] }
                    if ($gitIdent.ContainsKey("email")) { $identityGitEmail = $gitIdent["email"] }
                }
            }
        }
    } catch {
        LogWarn "Could not read profile: $_"
    }
}

if ($profileName) {
    $sharedContent = $sharedContent -replace [regex]::Escape('{{PROFILE_NAME}}'), $profileName
    $sharedContent = $sharedContent -replace [regex]::Escape('{{PROFILE_COMPANY}}'), $profileCompany
    $sharedContent = $sharedContent -replace [regex]::Escape('{{IDENTITY_GIT_NAME}}'), $identityGitName
    $sharedContent = $sharedContent -replace [regex]::Escape('{{IDENTITY_GIT_EMAIL}}'), $identityGitEmail
    Log "Profile interpolation: name=$profileName company=$profileCompany"
} else {
    LogWarn "Profile not available -- {{PLACEHOLDER}} tokens will not be resolved"
    Write-Summary "WARN" "claude.md" "template tokens unresolved"
}

# --- Write or preview CLAUDE.md ---
$osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
$hostname = $env:COMPUTERNAME

$content = @"
$sharedContent

## Machine-Specific

- Machine: $osInfo ($hostname)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

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
        $existingContent = Get-Content $claudeMd -Raw
        if ($existingContent -eq $content) {
            Log "[DRY RUN] Content unchanged"
        } else {
            Log "[DRY RUN] Content differs -- would overwrite"
        }
    } else {
        Log "[DRY RUN] File does not exist -- would create"
    }
} else {
    # Backup and remove existing file so we always write the latest version
    Backup-File -FilePath $claudeMd
    # Capture existing content for post-write comparison
    $oldContent = ""
    if (Test-Path $claudeMd) {
        try {
            $oldContent = Get-Content $claudeMd -Raw -ErrorAction Stop
        } catch {
            LogWarn "Cannot read existing CLAUDE.md for comparison: $_"
        }
    }
    if (Test-Path $claudeMd) {
        Remove-Item $claudeMd
        Log "Removed existing $claudeMd"
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($claudeMd)
    [System.IO.File]::WriteAllText($resolvedPath, $content, [System.Text.UTF8Encoding]::new($false))

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

    LogOk "Wrote $claudeMd"
    Write-Summary "OK" "claude.md" "deployed"
    # Log whether content actually changed
    if (-not $oldContent) {
        Log "Content: new file"
    } elseif ($oldContent -eq $content) {
        Log "Content unchanged (no differences)"
    } else {
        Log "Content updated"
        # Log diff to deploy log (not console)
        $oldLines = @($oldContent -split "`n")
        $newLines = @($content -split "`n")
        $diffResult = Compare-Object $oldLines $newLines -PassThru
        if ($diffResult) {
            Add-Content -Path $logFile -Value "  --- previous/CLAUDE.md"
            Add-Content -Path $logFile -Value "  +++ new/CLAUDE.md"
            foreach ($line in $diffResult) {
                $side = if ($line.SideIndicator -eq '<=') { '-' } else { '+' }
                Add-Content -Path $logFile -Value "  $side $line"
            }
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
            New-Item -ItemType Directory -Path $rulesDest -Force | Out-Null
        }

        $added = 0; $updated = 0; $unchanged = 0
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if (Test-Path $destFile) {
                try {
                    $oldContent = Get-Content $destFile -Raw -ErrorAction Stop
                    $newContent = Get-Content $rf.FullName -Raw -ErrorAction Stop
                } catch {
                    LogWarn "Cannot read files for comparison ($($rf.Name)): $_"
                    # Proceed with overwrite since we can't compare
                    Log "Updating: $($rf.Name) (comparison failed, overwriting)"
                    $updated++
                    Copy-Item -Path $rf.FullName -Destination $destFile -Force -ErrorAction Stop
                    continue
                }
                if ($oldContent -eq $newContent) {
                    Log "Unchanged: $($rf.Name) (no differences)"
                    $unchanged++
                    continue
                }
                # Log diff before overwriting
                Log "Updating: $($rf.Name)"
                $oldLines = @($oldContent -split "`n")
                $newLines = @($newContent -split "`n")
                $diffResult = Compare-Object $oldLines $newLines -PassThru
                if ($diffResult) {
                    foreach ($line in $diffResult) {
                        $side = if ($line.SideIndicator -eq '<=') { '-' } else { '+' }
                        Add-Content -Path $logFile -Value "  $side $line"
                    }
                }
                $updated++
            } else {
                Log "Adding: $($rf.Name) (new)"
                $added++
            }
            Copy-Item -Path $rf.FullName -Destination $destFile -Force -ErrorAction Stop
        }

        # Log preserved files (in target but not in source)
        $preserved = 0
        if (Test-Path $rulesDest) {
            $existingFiles = Get-ChildItem -Path $rulesDest -Filter "*.md" -File -ErrorAction Stop
            foreach ($ef in $existingFiles) {
                $srcMatch = Join-Path $rulesSrc $ef.Name
                if (-not (Test-Path $srcMatch)) {
                    Log "Preserved unmanaged rule: $($ef.Name)"
                    $preserved++
                }
            }
        }

        # Post-write validation: each deployed file is non-empty
        foreach ($rf in $sourceRules) {
            $destFile = Join-Path $rulesDest $rf.Name
            if ((Test-Path $destFile) -and (Get-Item $destFile).Length -eq 0) {
                LogError "Validation failed: $($rf.Name) is empty after deploy"
            }
        }

        LogOk "Rules: $added added, $updated updated, $unchanged unchanged, $preserved preserved in $rulesDest"
        Write-Summary "OK" "claude rules" "$added added, $updated updated, $unchanged unchanged"
    }
} else {
    Log "No user rules to deploy (no claude/rules/ in user repo)"
}
# --- END rules deploy logic (extracted by build-deploy) ---
# --- END rules deployment (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
