# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run -- replaces existing file with latest version.
#
# Sources (in priority order):
#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
#   2. shared/claude-shared.md          (fallback template from ai-tooling repo)
#
# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
# machine's profile from profile.json. See reference/user-repo.md.
#
# Overwrites: yes (sole owner of ~/.claude/CLAUDE.md)

param(
    [string]$SharedPath = (Join-Path $PSScriptRoot "..\shared\claude-shared.md"),
    [switch]$DryRun,
    [switch]$Force
)

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

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

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

if (Test-Path $configFile) {
    try {
        $cfg = ConvertPSObjectToHashtable (Get-Content $configFile -Raw | ConvertFrom-Json)
        if ($cfg.ContainsKey("userRepoPath") -and $cfg["userRepoPath"]) {
            $userClaudeMd = Join-Path $cfg["userRepoPath"] "claude\CLAUDE.md"
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
    if (Test-Path $claudeMd) {
        Remove-Item $claudeMd
        Log "Removed existing $claudeMd"
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($claudeMd)
    [System.IO.File]::WriteAllText($resolvedPath, $content, [System.Text.UTF8Encoding]::new($false))

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

    LogOk "Wrote $claudeMd"
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
