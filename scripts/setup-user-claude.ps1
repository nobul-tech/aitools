# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run -- replaces existing file with latest version.
#
# Sources (in priority order):
#   1. <userRepoPath>/claude/CLAUDE.md  (user's personal template from dotfile repo)
#   2. shared/claude-shared.md          (fallback template from ai-tooling repo)
#
# {{PLACEHOLDER}} tokens are interpolated at deploy time using the current
# machine's profile from profile.json. See reference/tool-install-sources.md.
#
# Overwrites: yes (sole owner of ~/.claude/CLAUDE.md)

param(
    [string]$SharedPath = (Join-Path $PSScriptRoot "..\shared\claude-shared.md")
)

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

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    Log "Created $claudeDir"
}

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
$sourcePath = ""
$sourceLabel = ""

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ((Test-Path $configFile) -and $nodeCmd) {
    $userRepoPath = node -e @'
try {
    const cfg = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    if (cfg.userRepoPath) console.log(cfg.userRepoPath);
} catch {}
'@ $configFile 2>$null
    if ($userRepoPath) { $userRepoPath = $userRepoPath.Trim() }

    if ($userRepoPath) {
        $userClaudeMd = Join-Path $userRepoPath "claude\CLAUDE.md"
        if (Test-Path $userClaudeMd) {
            $sourcePath = $userClaudeMd
            $sourceLabel = "user repo"
        }
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
$sharedContent = Get-Content -Path $sourcePath -Raw

# --- Profile interpolation ---
# Read profile.json and replace {{PLACEHOLDER}} tokens.
# Reuses the same pattern as build-deploy.sh.
$profileName = ""
$profileCompany = ""
$identityGitName = ""
$identityGitEmail = ""

if ((Test-Path $configFile) -and $nodeCmd) {
    $profileVals = node -e @'
const fs = require('fs'), path = require('path'), os = require('os');
try {
    const cfg = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    const repo = cfg.userRepoPath;
    const alias = cfg.machineAlias || '';
    if (!repo) throw new Error('no userRepoPath');
    const pf = path.join(repo, 'profile.json');
    const p = JSON.parse(fs.readFileSync(pf, 'utf8'));
    let prof, ident;
    if (p.version === 2) {
        prof = p.profiles[alias]
            || Object.values(p.profiles).find(pr => pr.machine && pr.machine.hostname.split('.')[0] === os.hostname().split('.')[0])
            || Object.values(p.profiles)[0];
        ident = p.identity;
    } else {
        prof = { name: p.name, company: p.company || '' };
        ident = { git: { name: (p.git && p.git.name) || p.name, email: (p.git && p.git.email) || p.email } };
    }
    console.log(prof.name);
    console.log(prof.company);
    console.log(ident.git.name);
    console.log(ident.git.email);
} catch(e) { process.exit(1); }
'@ $configFile 2>$null
    if ($LASTEXITCODE -eq 0 -and $profileVals) {
        $lines = @($profileVals -split "`n")
        $profileName = if ($lines.Count -ge 1) { $lines[0].Trim() } else { "" }
        $profileCompany = if ($lines.Count -ge 2) { $lines[1].Trim() } else { "" }
        $identityGitName = if ($lines.Count -ge 3) { $lines[2].Trim() } else { "" }
        $identityGitEmail = if ($lines.Count -ge 4) { $lines[3].Trim() } else { "" }
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

# Backup and remove existing file so we always write the latest version
Backup-File -FilePath $claudeMd
if (Test-Path $claudeMd) {
    Remove-Item $claudeMd
    Log "Removed existing $claudeMd"
}

# --- Write CLAUDE.md ---
$osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
$hostname = $env:COMPUTERNAME

$content = @"
$sharedContent

## Machine-Specific

- Machine: $osInfo ($hostname)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

[System.IO.File]::WriteAllText($claudeMd, $content, [System.Text.UTF8Encoding]::new($false))

# Post-write validation
if (-not (Test-Path $claudeMd) -or (Get-Item $claudeMd).Length -eq 0) {
    LogError "Validation failed: $claudeMd is empty or missing"
} elseif (-not ((Get-Content $claudeMd -Raw) -match '## Machine-Specific')) {
    LogError "Validation failed: $claudeMd missing Machine-Specific section"
}

LogOk "Wrote $claudeMd"

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
