# aitools.ps1 -- pull latest aitools scaffolding and manage dev tools
# Installed to ~/.local/bin/ by scripts/aitools-install.ps1
# Native PowerShell CLI -- Windows counterpart to scripts/aitools (bash).

param(
    [Parameter(Position = 0)]
    [string]$Command = "",
    [switch]$Version,
    [Alias("h")]
    [switch]$Help,
    [switch]$Patch,
    [switch]$DryRun,
    [switch]$Force,
    [string[]]$AddMcp,
    [switch]$SkipGhAuth,
    [string]$ReposPath,
    [switch]$SkipDriveDetection,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Remaining
)

$AITOOLS_INSTALLED_VERSION = "dev"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Write-Error "This script is for Windows. On macOS/Linux, use the bash 'aitools' command instead."
    exit 1
}

# --- PS 5.1 compat: --flag arrives as positional $Command since PS 5.1 doesn't support -- prefix ---
if ($Command -eq "--addmcp" -or $Command -eq "-addmcp") {
    $AddMcp = $Remaining
    $Command = ""
}
if ($Command -eq "--version" -or $Command -eq "-v") {
    $Version = $true
    $Command = ""
}
if ($Command -eq "--help" -or $Command -eq "-h") {
    $Help = $true
    $Command = ""
}
if ($Command -eq "--dry-run" -or $Command -eq "-dry-run") {
    $DryRun = [switch]::Present
    $Command = ""
}
if ($Command -eq "--force" -or $Command -eq "-force") {
    $Force = [switch]::Present
    $Command = ""
}
# Also check Remaining for --dry-run / --force (may come after a command)
if ($Remaining -and $Remaining -contains "--dry-run") {
    $DryRun = [switch]::Present
    $Remaining = @($Remaining | Where-Object { $_ -ne "--dry-run" })
}
if ($Remaining -and $Remaining -contains "--force") {
    $Force = [switch]::Present
    $Remaining = @($Remaining | Where-Object { $_ -ne "--force" })
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Read-ConfigKey {
    param([string]$File, [string]$Key)
    if (-not (Test-Path $File)) { return $null }
    $content = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }
    # Remove UTF-8 BOM if present
    $content = $content -replace '^\xEF\xBB\xBF', ''
    if ($content -match "`"$Key`"\s*:\s*`"([^`"]*)`"") {
        return $Matches[1] -replace '\\\\', '\'
    }
    return $null
}

# ---------------------------------------------------------------------------
# Logging (bootstrap -- overridden after lib is sourced below)
# ---------------------------------------------------------------------------

$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$script:errors = 0
$script:warnings = 0

function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -Path $logFile -Value "[$ts] [aitools] [$level] $msg"
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; Write-Host "error: $msg" -ForegroundColor Red; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; Write-Host "warning: $msg" -ForegroundColor Yellow; $script:warnings++ }

# Check profile.json for issues and optionally prompt for fixes.
# Usage: Invoke-ProfileCheck -Mode "warn" or "interactive"
# Requires: node, $repoPath, $configFile
function Invoke-ProfileCheck {
    param([string]$Mode = "warn")
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return }
    if (-not (Test-Path $repoPath)) { return }

    $checkScript = Join-Path $repoPath "scripts\profile-check.js"
    if (-not (Test-Path $checkScript)) { return }

    try {
        $resultJson = node $checkScript --config $configFile 2>$null
    } catch { return }
    if (-not $resultJson) { return }

    try {
        $result = $resultJson | ConvertFrom-Json
    } catch { return }

    switch ($result.status) {
        "ok" { return }
        "unconfigured" { return }
        "error" {
            $msg = if ($result.issues -and $result.issues.Count -gt 0) { $result.issues[0].message } else { "profile.json has issues" }
            Write-Host "profile: $msg" -ForegroundColor Yellow
        }
        "warn" {
            foreach ($issue in $result.issues) {
                Write-Host "profile: $($issue.message)" -ForegroundColor Yellow
            }
            if ($Mode -eq "interactive" -and [Environment]::UserInteractive) {
                Write-Host "Run 'aitools user init' to fix." -ForegroundColor Yellow
            }
        }
        "migrate" {
            Write-Host "profile: profile.json is v1 (legacy). Migration to v2 recommended." -ForegroundColor Yellow
            if ($Mode -eq "interactive" -and [Environment]::UserInteractive) {
                $answer = Read-Host "Migrate profile.json to v2 now? [y/N]"
                if ($answer -match '^[Yy]') {
                    Invoke-ProfileMigration -CheckResult $result
                }
            }
        }
    }
}

# Migrate a v1 profile.json to v2 format.
# Prompts for machineAlias. Preserves non-v1 sections (e.g., cursor).
# Commits + pushes user repo.
function Invoke-ProfileMigration {
    param($CheckResult)

    $migData = $CheckResult.migrationData
    if (-not $migData) {
        Write-Host "profile: no migration data available" -ForegroundColor Yellow
        return
    }

    $profilePath = $CheckResult.profilePath
    if (-not $profilePath -or -not (Test-Path $profilePath)) {
        Write-Host "profile: cannot locate profile.json for migration" -ForegroundColor Yellow
        return
    }

    $userRepoDir = Split-Path $profilePath -Parent
    $machAlias = Read-Host "Machine alias for this machine (e.g., laptop, workstation)"
    if (-not $machAlias) {
        Write-Host "Migration cancelled (alias required)."
        return
    }

    $migName = if ($migData.name) { $migData.name } else { "" }
    $migEmail = if ($migData.email) { $migData.email } else { "" }
    $migGithub = if ($migData.github) { $migData.github } else { "" }
    $migCompany = if ($migData.company) { $migData.company } else { "" }

    # Write v2 profile, preserving non-v1 sections
    node -e @"
const fs = require('fs'), os = require('os');
const profilePath = process.argv[1];
const alias = process.argv[2];
const migName = process.argv[3];
const migEmail = process.argv[4];
const migGithub = process.argv[5];
const migCompany = process.argv[6];

let old = {};
try { old = JSON.parse(fs.readFileSync(profilePath, 'utf8')); } catch {}

const v2 = {
    version: 2,
    identity: {
        github: migGithub,
        email: migEmail,
        git: { name: migName, email: migEmail }
    },
    profiles: {}
};

v2.profiles[alias] = {
    name: migName,
    company: migCompany,
    machine: {
        hostname: os.hostname(),
        os: process.platform,
        arch: process.arch,
        shell: 'powershell'
    }
};

// Preserve non-v1 sections (e.g., cursor)
const v1Keys = ['name', 'email', 'github', 'company', 'git', 'machines', 'version'];
for (const key of Object.keys(old)) {
    if (!v1Keys.includes(key) && !(key in v2)) {
        v2[key] = old[key];
    }
}

// Handle multiple machines from v1
if (Array.isArray(old.machines)) {
    const currentHost = os.hostname().split('.')[0];
    let counter = 1;
    for (const m of old.machines) {
        const mHost = (m.hostname || '').split('.')[0];
        if (mHost === currentHost) continue;
        const mAlias = 'machine' + counter;
        counter++;
        if (!v2.profiles[mAlias]) {
            v2.profiles[mAlias] = {
                name: migName,
                company: migCompany,
                machine: m
            };
        }
    }
}

fs.writeFileSync(profilePath, JSON.stringify(v2, null, 2) + '\n');
console.log('Migrated profile.json to v2 (alias: ' + alias + ')');
"@ $profilePath $machAlias $migName $migEmail $migGithub $migCompany

    # Update machineAlias in config.json
    node -e @"
const fs = require('fs');
const f = process.argv[1];
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { if (e.code !== 'ENOENT') console.error('Warning: ' + f + ' is invalid JSON, starting with empty config'); }
cfg.machineAlias = process.argv[2];
fs.writeFileSync(f, JSON.stringify(cfg, null, 2) + '\n');
"@ $configFile $machAlias

    # Commit and push user repo
    if (Test-Path (Join-Path $userRepoDir ".git")) {
        $status = git -C $userRepoDir status --porcelain 2>$null
        if ($status) {
            $gitName = node -e "try{const p=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(p.identity.git.name||'')}catch{}" $profilePath 2>$null
            $gitEmail = node -e "try{const p=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(p.identity.git.email||'')}catch{}" $profilePath 2>$null
            if ($gitName) { $gitName = $gitName.Trim() }
            if ($gitEmail) { $gitEmail = $gitEmail.Trim() }
            if ($gitName -and $gitEmail) {
                git -C $userRepoDir config user.name $gitName
                git -C $userRepoDir config user.email $gitEmail
            }
            git -C $userRepoDir add -A
            git -C $userRepoDir commit -m "Migrate profile.json from v1 to v2"
            $pushResult = git -C $userRepoDir push 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  (push failed -- run 'git push' manually in $userRepoDir)"
            }
            Write-Host "Profile migrated and committed."
        }
    }
}

# Version string from a git repo using tag-based scheme.
# v0.14.0              -> 0.14.0       (on tag exactly)
# v0.14.0-5-gabcdef    -> 0.14.0+5    (5 commits ahead of tag)
# The +N suffix indicates unreleased commits; it is never a real version.
function Get-RepoVersion {
    param([string]$RepoPath)
    try {
        $desc = git -C $RepoPath describe --tags --match "v*" 2>$null
        if ($desc) {
            $base = $desc.TrimStart("v")
            if ($base -match '^(.+)-(\d+)-g[0-9a-f]+$') {
                $tagPart = $Matches[1]       # 0.14.0
                $commits = $Matches[2]       # 5
                return "${tagPart}+${commits}"
            } else {
                return $base                 # 0.14.0
            }
        }
        # No tags -- fallback
        $log = git -C $RepoPath log -1 --format='%cd (%h)' --date=short 2>$null
        if ($log) { return $log } else { return "unknown" }
    } catch { return "unknown" }
}

# Deploy all config scripts from the repo's scripts/ directory.
function Deploy-Configs {
    param([string]$ScriptDir)
    $deployScripts = @("setup-user-claude.ps1", "setup-user-mcp.ps1", "setup-cursor-ide-mcp.ps1", "setup-user-cursor.ps1", "setup-user-hooks.ps1")
    $errors = 0
    $env:AITOOLS_DEPLOY = "1"
    if ($DryRun) { $env:AITOOLS_DRY_RUN = "1" }
    if ($Force) { $env:AITOOLS_FORCE = "1" }
    foreach ($script in $deployScripts) {
        $scriptPath = Join-Path $ScriptDir $script
        if (Test-Path $scriptPath) {
            # Validate PS1 syntax before executing
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $scriptPath, [ref]$null, [ref]$parseErrors)
            if ($parseErrors.Count -gt 0) {
                LogWarn "$script has parse errors -- skipping"
                $errors++
                continue
            }
            # Reset exit code before each script (prevents stale values from previous iteration)
            $global:LASTEXITCODE = 0
            try {
                & $scriptPath *> $null 2>> $logFile
            } catch {
                LogError "$script failed (see $logFile)"
                $errors++
                continue
            }
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                LogError "$script failed (see $logFile)"
                $errors++
            }
        } else {
            LogWarn "$script not found -- skipping"
        }
        # Show cloud MCP status after setup-user-mcp
        if ($script -eq "setup-user-mcp.ps1") {
            Show-CloudMcp -Context "install" -ScriptName "setup-user-mcp"
        }
    }
    Remove-Item Env:\AITOOLS_DEPLOY -ErrorAction SilentlyContinue
    Remove-Item Env:\AITOOLS_DRY_RUN -ErrorAction SilentlyContinue
    Remove-Item Env:\AITOOLS_FORCE -ErrorAction SilentlyContinue
    return $errors
}

# ---------------------------------------------------------------------------
# MCP server registry
# ---------------------------------------------------------------------------

function Get-McpServerUrl {
    param([string]$Name)
    switch ($Name) {
        "vercel"  { return "https://mcp.vercel.com" }
        "webflow" { return "https://mcp.webflow.com/mcp" }
        default   { return "" }
    }
}

# Display cloud MCP servers from claude.ai configuration.
# Usage: Show-CloudMcp -Context "mcp" or "install" [-ScriptName "setup-user-mcp"]
# When ScriptName is provided, uses structured logging format for deploy sequence.
# Silent no-op if claude CLI unavailable or no cloud servers found.
function Show-CloudMcp {
    param(
        [string]$Context = "mcp",
        [string]$ScriptName = ""
    )
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { return }

    $savedClaudeCode = $env:CLAUDECODE
    Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue

    try {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = claude mcp list 2>$null
        [Console]::OutputEncoding = $savedEncoding
    } catch {
        $raw = $null
    }

    if ($savedClaudeCode) {
        $env:CLAUDECODE = $savedClaudeCode
    }

    if (-not $raw) { return }

    $entries = @()
    foreach ($line in $raw) {
        $clean = $line -replace '\e\[[0-9;]*m', ''
        if ($clean -match '^claude\.ai\s+(.+?):\s+.+\s+-\s+(.+)$') {
            $name = $Matches[1].Trim()
            $status = $Matches[2].Trim()
            $entries += [PSCustomObject]@{ Name = $name; Status = $status }
        }
    }

    if ($entries.Count -eq 0) { return }

    if ($ScriptName) {
        # Structured logging for deploy sequence
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        Write-Host "[$ts] [$ScriptName] Cloud MCP servers (configured at claude.ai):"
        foreach ($entry in $entries) {
            if ($entry.Name.Length -lt 24) {
                $pad = " " * (24 - $entry.Name.Length)
            } else {
                $pad = " "
            }
            $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            Write-Host "[$ts] [$ScriptName]   $($entry.Name)$pad$($entry.Status)"
        }
    } else {
        Write-Host ""
        Write-Host "Cloud (claude.ai):"
        foreach ($entry in $entries) {
            if ($entry.Name.Length -lt 24) {
                $pad = " " * (24 - $entry.Name.Length)
            } else {
                $pad = " "
            }
            Write-Host "  $($entry.Name)$pad$($entry.Status)"
        }
    }
}

# ---------------------------------------------------------------------------
# Usage / flags
# ---------------------------------------------------------------------------

function Show-Usage {
    @"
Usage: aitools [COMMAND] [OPTIONS]

Commands:
  (none)               Sync configs: pull + rebuild + deploy all configurations
  gitpull [--patch]    Update source: pull + rebuild + deploy + changelog + version tag
                       --patch: bump patch (v0.14.0 -> v0.14.1) instead of minor
  install              Full setup: pull + rebuild + install tools + deploy configs
  mcp                  Show MCP server status for current project
  user init            Set up user repo and configure session archiving hook
  sessions list [proj] List archived sessions (optionally filter by project)
  sessions archive ID  Manually archive a session by ID (full or prefix)
  sessions move F proj Refile an archived session under a different project

Options:
  --addmcp <name...>   Enable MCP server(s) for current project (vercel, webflow)
  --dry-run            Preview what would change without writing any files
  --force              Overwrite all files without prompting for review
  --version, -v        Show installed and repo version
  --help, -h           Show this help

Install flags (passed through to installer):
  --skip-gh-auth       Skip GitHub CLI authentication
  --repos-path PATH    Set repos directory without prompting
  --skip-drive-detection  Skip Google Drive auto-detection
"@
}

if ($Help) {
    Show-Usage
    exit 0
}

# Handle positional command
$doInstall = $Command -eq "install"
$doGitpull = $Command -eq "gitpull"
$doMcpStatus = $Command -eq "mcp"
$doUser = $Command -eq "user"
$doSessions = $Command -eq "sessions"

# --patch flag for gitpull (may come via -Patch switch or positional $Remaining)
$gitpullPatch = $false
if ($doGitpull) {
    if ($Patch) { $gitpullPatch = $true }
    if ($Remaining -and $Remaining -contains "--patch") {
        $gitpullPatch = $true
        $Remaining = @($Remaining | Where-Object { $_ -ne "--patch" })
    }
}

# Extract subcommand and remaining args for user/sessions
$subCmd = ""
$subArgs = @()
if ($doUser -or $doSessions) {
    if ($Remaining -and $Remaining.Count -gt 0) {
        $subCmd = $Remaining[0]
        if ($Remaining.Count -gt 1) {
            $subArgs = $Remaining[1..($Remaining.Count - 1)]
        }
    }
}

# Reject unknown commands (typos like "installs", "mcpp", etc.)
$knownCommands = @("install", "gitpull", "mcp", "user", "sessions", "")
if ($Command -and $Command -notin $knownCommands) {
    LogError "unknown command '$Command'"
    Write-Host "Run 'aitools --help' for usage."
    exit 1
}

# Reject --addmcp with no server names
if ($PSBoundParameters.ContainsKey('AddMcp') -and $AddMcp.Count -eq 0) {
    LogError "--addmcp requires at least one server name (vercel, webflow)"
    exit 1
}

# ---------------------------------------------------------------------------
# Migrate config directory: ~\.config\ai-tooling\ -> ~\.aitools\
# ---------------------------------------------------------------------------

$oldConfigDir = Join-Path $env:USERPROFILE ".config\ai-tooling"
$newConfigDir = Join-Path $env:USERPROFILE ".aitools"

if ((Test-Path $oldConfigDir) -and -not (Test-Path $newConfigDir)) {
    Move-Item -Path $oldConfigDir -Destination $newConfigDir
} elseif ((Test-Path $oldConfigDir) -and (Test-Path $newConfigDir)) {
    LogWarn "both $oldConfigDir and $newConfigDir exist -- using $newConfigDir"
}

# ---------------------------------------------------------------------------
# Resolve repo path from config
# ---------------------------------------------------------------------------

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
$repoPath = ""

$raw = Read-ConfigKey -File $configFile -Key "repoPath"
if (-not $raw) { $raw = Read-ConfigKey -File $configFile -Key "aiToolingRepoPath" }
if ($raw) { $repoPath = $raw }
if (-not $repoPath) { $repoPath = Join-Path $env:USERPROFILE "repos\aitools" }

# Auto-migrate: aiToolingRepoPath -> repoPath (repo renamed ai-tooling -> aitools)
$oldKey = Read-ConfigKey -File $configFile -Key "aiToolingRepoPath"
if ($oldKey) {
    try {
        $cfgObj = Get-Content $configFile -Raw | ConvertFrom-Json
        if (-not $cfgObj.repoPath -and $cfgObj.aiToolingRepoPath) {
            $newVal = $cfgObj.aiToolingRepoPath -replace 'ai-tooling', 'aitools'
            $cfgObj | Add-Member -NotePropertyName "repoPath" -NotePropertyValue $newVal -Force
        }
        $cfgObj.PSObject.Properties.Remove("aiToolingRepoPath")
        $json = $cfgObj | ConvertTo-Json -Depth 10
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($configFile)
        [System.IO.File]::WriteAllText($resolved, $json + "`n", [System.Text.UTF8Encoding]::new($false))
        Log "Migrated config: aiToolingRepoPath -> repoPath"
        # Re-read after migration
        $repoPath = Read-ConfigKey -File $configFile -Key "repoPath"
    } catch {
        LogWarn "Config key migration failed: $_"
        # Non-fatal: continue with whatever repoPath was already resolved
    }
}

# ---------------------------------------------------------------------------
# --version
# ---------------------------------------------------------------------------

if ($Version) {
    Write-Host "aitools $AITOOLS_INSTALLED_VERSION"
    if (Test-Path (Join-Path $repoPath ".git")) {
        Write-Host "  repo: $(Get-RepoVersion $repoPath) @ $repoPath"
    }
    exit 0
}

# ---------------------------------------------------------------------------
# mcp -- show MCP server status
# ---------------------------------------------------------------------------

if ($doMcpStatus) {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        LogError "node required for mcp status"
        exit 1
    }

    node -e @'
const fs = require("fs");
const path = require("path");
const os = require("os");

const home = os.homedir();
const cwd = process.cwd();

function readJson(f) {
    try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return null; }
}

// --- Claude Code ---
const claudeJson = readJson(path.join(home, ".claude.json"));
const claudeSettings = readJson(path.join(home, ".claude", "settings.json"));
const projectSettings = readJson(path.join(cwd, ".claude", "settings.json"));
const projectLocalSettings = readJson(path.join(cwd, ".claude", "settings.local.json"));

const claudeDeny = claudeSettings?.permissions?.deny || [];
const projectAllow = [
    ...(projectSettings?.permissions?.allow || []),
    ...(projectLocalSettings?.permissions?.allow || []),
];

console.log("MCP Server Status (" + cwd + ")\n");

if (claudeJson?.mcpServers) {
    console.log("Claude Code:");
    const servers = claudeJson.mcpServers;
    for (const [name, cfg] of Object.entries(servers)) {
        const transport = cfg.type === "http" || cfg.url ? "http" : "stdio";
        const denyPattern = "MCP(" + name + ")";
        const denied = claudeDeny.includes(denyPattern);
        const allowed = projectAllow.includes(denyPattern);
        const status = denied && !allowed ? "disabled" : "enabled";
        const pad = name.length < 16 ? " ".repeat(16 - name.length) : " ";
        console.log("  " + name + pad + status.padEnd(10) + "(user)   " + transport);
    }

    // Show project overrides if any
    const overrides = [];
    for (const rule of projectAllow) {
        const match = rule.match(/^MCP\((.+)\)$/);
        if (match) {
            const source = projectLocalSettings?.permissions?.allow?.includes(rule)
                ? ".claude/settings.local.json"
                : ".claude/settings.json";
            overrides.push({ name: match[1], source });
        }
    }
    if (overrides.length > 0) {
        console.log("  Project overrides:");
        for (const o of overrides) {
            const pad = o.name.length < 16 ? " ".repeat(16 - o.name.length) : " ";
            console.log("    " + o.name + pad + "enabled   (" + o.source + ")");
        }
    }
} else {
    console.log("Claude Code: no user-level MCP config found (~/.claude.json)");
}

console.log("");

// --- Cursor ---
const cursorJson = readJson(path.join(home, ".cursor", "mcp.json"));
const projectCursorJson = readJson(path.join(cwd, ".cursor", "mcp.json"));

if (cursorJson?.mcpServers) {
    console.log("Cursor:");
    const servers = cursorJson.mcpServers;
    for (const [name, cfg] of Object.entries(servers)) {
        const transport = cfg.url ? "http" : "stdio";
        const pad = name.length < 16 ? " ".repeat(16 - name.length) : " ";
        console.log("  " + name + pad + "(user)   " + transport);
    }
    if (projectCursorJson?.mcpServers) {
        console.log("  Project overrides (.cursor/mcp.json):");
        for (const [name, cfg] of Object.entries(projectCursorJson.mcpServers)) {
            const transport = cfg.url ? "http" : "stdio";
            const pad = name.length < 16 ? " ".repeat(16 - name.length) : " ";
            console.log("    " + name + pad + "enabled   " + transport);
        }
    }
} else {
    console.log("Cursor: no user-level MCP config found (~/.cursor/mcp.json)");
}
'@
    Show-CloudMcp -Context "mcp"
    exit 0
}

# ---------------------------------------------------------------------------
# --addmcp -- enable MCP server(s) for current project
# ---------------------------------------------------------------------------

if ($AddMcp -and $AddMcp.Count -gt 0) {
    # Validate all server names first
    foreach ($name in $AddMcp) {
        $url = Get-McpServerUrl $name
        if (-not $url) {
            LogError "unknown MCP server '$name'"
            Write-Host "Supported servers: vercel, webflow"
            exit 1
        }
    }

    # Warn if cwd doesn't look like a project
    if (-not (Test-Path ".git") -and -not (Test-Path "package.json") -and -not (Test-Path "pyproject.toml")) {
        LogWarn "current directory doesn't look like a project root"
        Write-Host "  cwd: $(Get-Location)"
        Write-Host ""
    }

    foreach ($name in $AddMcp) {
        $url = Get-McpServerUrl $name
        Write-Host "Enabling $name for this project..."

        # --- Claude Code: .claude/settings.local.json (allow override) ---
        $settingsLocal = ".claude\settings.local.json"
        if (Get-Command node -ErrorAction SilentlyContinue) {
            if (-not (Test-Path ".claude")) { New-Item -ItemType Directory -Path ".claude" -Force | Out-Null }
            node -e @"
const fs = require('fs');
const f = process.argv[1];
let settings = {};
try { settings = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { if (e.code !== 'ENOENT') console.error('Warning: ' + f + ' is invalid JSON, starting with empty config'); }
if (!settings.permissions) settings.permissions = {};
if (!Array.isArray(settings.permissions.allow)) settings.permissions.allow = [];
const rule = 'MCP($name)';
if (!settings.permissions.allow.includes(rule)) {
    settings.permissions.allow.push(rule);
}
fs.writeFileSync(f, JSON.stringify(settings, null, 2) + '\n');

// Post-write validation
const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
if (!_v.permissions) { console.error('Validation failed: missing permissions'); process.exit(1); }
"@ "$settingsLocal"
            Write-Host "  Claude Code: $name enabled in $settingsLocal"
        } else {
            Write-Host "  Claude Code: skipped (node not found)"
        }

        # --- Cursor: try agent mcp enable, fall back to project .cursor/mcp.json ---
        $cursorDone = $false
        if (Get-Command agent -ErrorAction SilentlyContinue) {
            $result = agent mcp enable $name 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Cursor CLI: $name enabled (agent mcp enable)"
                $cursorDone = $true
            }
        }
        if (-not $cursorDone -and (Get-Command node -ErrorAction SilentlyContinue)) {
            $cursorMcp = ".cursor\mcp.json"
            if (-not (Test-Path ".cursor")) { New-Item -ItemType Directory -Path ".cursor" -Force | Out-Null }
            node -e @"
const fs = require('fs');
const f = process.argv[1];
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { if (e.code !== 'ENOENT') console.error('Warning: ' + f + ' is invalid JSON, starting with empty config'); }
if (!cfg.mcpServers) cfg.mcpServers = {};
cfg.mcpServers['$name'] = { url: '$url' };
fs.writeFileSync(f, JSON.stringify(cfg, null, 2) + '\n');
"@ "$cursorMcp"
            Write-Host "  Cursor: $name added to $cursorMcp"
        }
        if (-not $cursorDone -and -not (Get-Command node -ErrorAction SilentlyContinue)) {
            Write-Host "  Cursor: skipped (neither agent nor node found)"
        }

        Write-Host ""
    }

    Write-Host "Done. MCP servers enabled for project at $(Get-Location)"
    exit 0
}

# ---------------------------------------------------------------------------
# user -- user repo management
# ---------------------------------------------------------------------------

if ($doUser) {
    switch ($subCmd) {
        "init" {
            # Detect GitHub username
            $ghUser = ""
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                try { $ghUser = gh api user --jq '.login' 2>$null } catch {}
            }
            if (-not $ghUser) {
                $ghUser = Read-Host "GitHub username"
            } else {
                Write-Host "Detected GitHub user: $ghUser"
            }

            if (-not $ghUser) {
                LogError "GitHub username required"
                exit 1
            }

            $repoName = "aitools-$ghUser"
            $machineAlias = ""

            # Determine repos directory from config
            $reposDir = Read-ConfigKey -File $configFile -Key "reposPath"
            if (-not $reposDir) { $reposDir = Join-Path $env:USERPROFILE "repos" }

            $userRepoDir = Join-Path $reposDir $repoName

            if (Test-Path (Join-Path $userRepoDir ".git")) {
                # --- Path 1: local repo already exists ---
                Write-Host "User repo already exists: $userRepoDir"

                # Detect machineAlias from profile.json by hostname match
                $profilePath = Join-Path $userRepoDir "profile.json"
                if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $profilePath)) {
                    $machineAlias = node -e @"
const fs = require('fs'), os = require('os');
try {
    const p = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    if (p.version === 2 && p.profiles) {
        const host = os.hostname().split('.')[0];
        for (const [alias, prof] of Object.entries(p.profiles)) {
            if (prof.machine && prof.machine.hostname.split('.')[0] === host) {
                console.log(alias);
                break;
            }
        }
    }
} catch {}
"@ $profilePath 2>$null
                    if ($machineAlias) { $machineAlias = $machineAlias.Trim() }
                }

                # Detect v1 profile and offer migration
                $profilePath = Join-Path $userRepoDir "profile.json"
                if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $profilePath)) {
                    $profVersion = node -e "try{const p=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(p.version||'')}catch{}" $profilePath 2>$null
                    if ($profVersion) { $profVersion = $profVersion.Trim() }
                    if ($profVersion -ne "2") {
                        Write-Host "profile.json is v1 (legacy). Migrating to v2..."
                        $checkScript = Join-Path $repoPath "scripts\profile-check.js"
                        if (Test-Path $checkScript) {
                            $checkResult = node $checkScript --config $configFile 2>$null
                            if ($checkResult) {
                                $parsed = $checkResult | ConvertFrom-Json
                                Invoke-ProfileMigration -CheckResult $parsed
                            }
                        }
                    }
                }

            } elseif ((Get-Command gh -ErrorAction SilentlyContinue) -and
                      ((gh repo view "$ghUser/$repoName" --json name 2>$null) -ne $null)) {
                # --- Path 2: GitHub repo exists, no local clone ---
                Write-Host "GitHub repo exists. Cloning to $userRepoDir..."
                gh repo clone "$ghUser/$repoName" $userRepoDir

                # Detect v1 profile and offer migration
                $profilePath = Join-Path $userRepoDir "profile.json"
                if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $profilePath)) {
                    $profVersion = node -e "try{const p=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(p.version||'')}catch{}" $profilePath 2>$null
                    if ($profVersion) { $profVersion = $profVersion.Trim() }
                    if ($profVersion -ne "2") {
                        Write-Host "profile.json is v1 (legacy). Migrating to v2..."
                        $checkScript = Join-Path $repoPath "scripts\profile-check.js"
                        if (Test-Path $checkScript) {
                            $checkResult = node $checkScript --config $configFile 2>$null
                            if ($checkResult) {
                                $parsed = $checkResult | ConvertFrom-Json
                                Invoke-ProfileMigration -CheckResult $parsed
                            }
                        }
                    }
                }

                # Check if machine profile needs adding (v2 schema)
                $profilePath = Join-Path $userRepoDir "profile.json"
                if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $profilePath)) {
                    # Read defaults from existing profile
                    $profileDefaults = node -e @"
const fs = require('fs');
try {
    const p = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    const ident = p.identity || {};
    const firstProf = Object.values(p.profiles || {})[0] || {};
    console.log((ident.git && ident.git.name) || firstProf.name || '');
    console.log(firstProf.company || '');
    console.log((ident.git && ident.git.email) || '');
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read profile: ' + e.message); }
"@ $profilePath 2>$null
                    $defaultLines = @($profileDefaults -split "`n")
                    $defaultName = if ($defaultLines.Count -ge 1) { $defaultLines[0].Trim() } else { "" }
                    $defaultCompany = if ($defaultLines.Count -ge 2) { $defaultLines[1].Trim() } else { "" }
                    $defaultEmail = if ($defaultLines.Count -ge 3) { $defaultLines[2].Trim() } else { "" }

                    $machineAlias = Read-Host "Machine alias (e.g., laptop, workstation)"

                    if ($machineAlias) {
                        $namePrompt = "Display name"
                        if ($defaultName) { $namePrompt = "Display name [$defaultName]" }
                        $profName = Read-Host $namePrompt
                        if (-not $profName) { $profName = if ($defaultName) { $defaultName } else { $env:USERNAME } }

                        $companyPrompt = "Company"
                        if ($defaultCompany) { $companyPrompt = "Company [$defaultCompany]" }
                        $profCompany = Read-Host $companyPrompt
                        if (-not $profCompany) { $profCompany = $defaultCompany }

                        node -e @"
const fs = require('fs'), os = require('os');
const pf = process.argv[1], alias = process.argv[2];
try {
    const p = JSON.parse(fs.readFileSync(pf, 'utf8'));
    if (p.version === 2 && !p.profiles[alias]) {
        p.profiles[alias] = {
            name: process.argv[3],
            company: process.argv[4],
            machine: {
                hostname: os.hostname(),
                os: process.platform,
                arch: process.arch,
                shell: 'powershell'
            }
        };
        fs.writeFileSync(pf, JSON.stringify(p, null, 2) + '\n');
        console.log('Added machine profile: ' + alias);
    } else if (p.version === 2 && p.profiles[alias]) {
        console.log('Machine profile already exists: ' + alias);
    }
} catch(e) { console.error('warning: could not update profile: ' + e.message); }
"@ $profilePath $machineAlias $profName $profCompany
                    }

                    # Set git identity from profile
                    if ($defaultName -and $defaultEmail) {
                        git -C $userRepoDir config user.name $defaultName
                        git -C $userRepoDir config user.email $defaultEmail
                    }

                    # Commit and push if profile was modified
                    $status = git -C $userRepoDir status --porcelain 2>$null
                    if ($status) {
                        git -C $userRepoDir add -A
                        git -C $userRepoDir commit -m "Add machine profile: $machineAlias"
                        git -C $userRepoDir push
                        Write-Host "Profile updated and pushed."
                    }
                }

            } else {
                # --- Path 3: fresh setup ---
                Write-Host "Creating user repo: $userRepoDir"
                New-Item -ItemType Directory -Path (Join-Path $userRepoDir "sessions") -Force | Out-Null

                # Prompt for profile info
                $profName = Read-Host "Display name [$env:USERNAME]"
                if (-not $profName) { $profName = $env:USERNAME }
                $profEmail = Read-Host "Email"
                $profCompany = Read-Host "Company"
                $machineAlias = Read-Host "Machine alias (e.g., laptop, workstation)"

                # Create v2 profile.json
                node -e @"
const fs = require('fs'), os = require('os');
const profile = {
    version: 2,
    identity: {
        github: process.argv[3],
        email: process.argv[2],
        git: { name: process.argv[1], email: process.argv[2] }
    },
    profiles: {}
};
const alias = process.argv[6] || 'default';
profile.profiles[alias] = {
    name: process.argv[1],
    company: process.argv[4],
    machine: {
        hostname: os.hostname(),
        os: process.platform,
        arch: process.arch,
        shell: 'powershell'
    }
};
fs.writeFileSync(process.argv[7], JSON.stringify(profile, null, 2) + '\n');
"@ "$profName" "$profEmail" "$ghUser" "$profCompany" "powershell" $machineAlias (Join-Path $userRepoDir "profile.json")

                # Create .gitattributes
                [System.IO.File]::WriteAllText(
                    (Join-Path $userRepoDir ".gitattributes"),
                    "* text=auto eol=lf`n*.jsonl text eol=lf`n",
                    [System.Text.UTF8Encoding]::new($false))

                # Create .gitignore
                [System.IO.File]::WriteAllText(
                    (Join-Path $userRepoDir ".gitignore"),
                    ".scratch/`n*.bak.*`n.DS_Store`n",
                    [System.Text.UTF8Encoding]::new($false))

                # Create README
                [System.IO.File]::WriteAllText(
                    (Join-Path $userRepoDir "README.md"),
                    "# $repoName`n`nPrivate user repo for session archives and profile data.`nSee [aitools](https://github.com/$ghUser/aitools) for details.`n",
                    [System.Text.UTF8Encoding]::new($false))

                # Git init
                git -C $userRepoDir init -b main
                git -C $userRepoDir config user.name $profName
                git -C $userRepoDir config user.email $profEmail
                git -C $userRepoDir add -A
                git -C $userRepoDir commit -m "Initial commit: profile and session archive structure"

                Write-Host "User repo created."

                # Offer to create GitHub repo
                if (Get-Command gh -ErrorAction SilentlyContinue) {
                    $createGh = Read-Host "Create private GitHub repo '$repoName'? [y/N]"
                    if ($createGh -match '^[Yy]') {
                        gh repo create $repoName --private --source $userRepoDir --push
                        Write-Host "GitHub repo created and pushed."
                    }
                }
            }

            # Scaffold claude/CLAUDE.md in user repo if missing
            $claudeMdDest = Join-Path $userRepoDir "claude\CLAUDE.md"
            $sharedTemplate = Join-Path $repoPath "shared\claude-shared.md"
            if (-not (Test-Path $claudeMdDest) -and (Test-Path $sharedTemplate)) {
                $claudeDestDir = Join-Path $userRepoDir "claude"
                if (-not (Test-Path $claudeDestDir)) {
                    New-Item -ItemType Directory -Path $claudeDestDir -Force | Out-Null
                }
                Copy-Item -Path $sharedTemplate -Destination $claudeMdDest
                Write-Host "Created claude/CLAUDE.md in user repo (template with placeholders)"
                if (Test-Path (Join-Path $userRepoDir ".git")) {
                    git -C $userRepoDir add "claude/CLAUDE.md"
                    $status = git -C $userRepoDir status --porcelain 2>$null
                    if ($status) {
                        git -C $userRepoDir commit -m "Add claude/CLAUDE.md template"
                        git -C $userRepoDir push 2>$null
                    }
                }
            }

            # Write userRepoPath and machineAlias to config
            if (Get-Command node -ErrorAction SilentlyContinue) {
                node -e @"
const fs = require('fs');
const f = process.argv[1];
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { if (e.code !== 'ENOENT') console.error('Warning: ' + f + ' is invalid JSON, starting with empty config'); }
cfg.userRepoPath = process.argv[2];
if (process.argv[3]) cfg.machineAlias = process.argv[3];
fs.writeFileSync(f, JSON.stringify(cfg, null, 2) + '\n');

// Post-write validation
const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
const _missing = ['version','reposPath','userRepoPath'].filter(k => !(k in _v));
if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }
"@ "$configFile" "$userRepoDir" "$machineAlias"
                Write-Host "Config updated: userRepoPath = $userRepoDir"
                if ($machineAlias) {
                    Write-Host "Config updated: machineAlias = $machineAlias"
                }
            }

            # Deploy session archive hook
            $hookSetup = Join-Path $repoPath "scripts\setup-user-hooks.ps1"
            if (Test-Path $hookSetup) {
                Write-Host ""
                Write-Host "Deploying session archive hook..."
                & $hookSetup
            }

            Write-Host ""
            Write-Host "Done. Sessions will be archived to $userRepoDir\sessions\"
        }
        "" {
            LogError "missing subcommand"
            Write-Host "Usage: aitools user init"
            exit 1
        }
        default {
            LogError "unknown subcommand 'user $subCmd'"
            Write-Host "Usage: aitools user init"
            exit 1
        }
    }
    exit 0
}

# ---------------------------------------------------------------------------
# sessions -- session archive management
# ---------------------------------------------------------------------------

if ($doSessions) {
    # Resolve user repo path
    $userRepo = Read-ConfigKey -File $configFile -Key "userRepoPath"
    if (-not $userRepo -or -not (Test-Path $userRepo)) {
        LogError "user repo not configured. Run 'aitools user init' first."
        exit 1
    }
    $sessionsDir = Join-Path $userRepo "sessions"

    switch ($subCmd) {
        "list" {
            $filter = if ($subArgs.Count -gt 0) { $subArgs[0] } else { "" }
            if (-not (Test-Path $sessionsDir)) {
                Write-Host "No sessions archived yet."
                exit 0
            }
            $files = Get-ChildItem -Path $sessionsDir -Filter "*.jsonl" -Recurse -File | Sort-Object FullName
            $found = $false
            foreach ($file in $files) {
                $rel = $file.FullName.Substring($sessionsDir.Length + 1) -replace '\\', '/'
                $project = $rel.Split('/')[0]
                if ($filter -and $project -ne $filter) { continue }
                $size = if ($file.Length -ge 1MB) {
                    "{0:N1}M" -f ($file.Length / 1MB)
                } elseif ($file.Length -ge 1KB) {
                    "{0:N0}K" -f ($file.Length / 1KB)
                } else {
                    "{0}B" -f $file.Length
                }
                Write-Host "$rel  ($size)"
                $found = $true
            }
            if (-not $found) {
                if ($filter) {
                    Write-Host "No sessions found for project '$filter'."
                } else {
                    Write-Host "No sessions archived yet."
                }
            }
        }
        "archive" {
            $sessionId = if ($subArgs.Count -gt 0) { $subArgs[0] } else { "" }
            if (-not $sessionId) {
                LogError "session ID required"
                Write-Host "Usage: aitools sessions archive <session-id>"
                exit 1
            }

            # Search for matching session
            $claudeProjects = Join-Path $env:USERPROFILE ".claude\projects"
            if (-not (Test-Path $claudeProjects)) {
                LogError "no Claude Code sessions found at $claudeProjects"
                exit 1
            }

            $matches = Get-ChildItem -Path $claudeProjects -Filter "${sessionId}*.jsonl" -Recurse -File
            if ($matches.Count -eq 0) {
                LogError "no session found matching '$sessionId'"
                exit 1
            }
            if ($matches.Count -gt 1) {
                Write-Host "Multiple sessions match '$sessionId':"
                foreach ($m in $matches) { Write-Host "  $($m.BaseName)" }
                Write-Host "Provide a longer prefix to disambiguate."
                exit 1
            }

            $transcript = $matches[0]
            $fullId = $transcript.BaseName

            # Derive project name from CWD recorded in the JSONL transcript
            # Uses node (already required by other aitools commands)
            $sessionCwd = node -e @"
const fs = require('fs'), readline = require('readline');
const rl = readline.createInterface({ input: fs.createReadStream(process.argv[1]) });
rl.on('line', line => {
    try {
        const d = JSON.parse(line);
        if (d.cwd) { process.stdout.write(d.cwd); rl.close(); }
    } catch {}
});
"@ $transcript.FullName 2>$null

            if ($sessionCwd) {
                # Use same derivation logic as the hook
                $cwdRepo = ""
                if (Test-Path $sessionCwd) {
                    try {
                        Push-Location $sessionCwd
                        $cwdRepo = git rev-parse --show-toplevel 2>$null
                    } finally {
                        Pop-Location
                    }
                }
                if ($cwdRepo) {
                    $project = Split-Path $cwdRepo -Leaf
                } else {
                    $project = (Split-Path $sessionCwd -Leaf).ToLower() -replace '[^a-z0-9-]', '-'
                }
            } else {
                # Last resort: basename of the Claude projects directory
                # Lossy for project names with hyphens (e.g., ai-tooling -> tooling)
                $projectDir = $transcript.Directory.Name
                $project = $projectDir.Split('-')[-1]
            }

            $archiveDate = $transcript.CreationTime.ToUniversalTime().ToString("yyyy-MM-dd")
            $prefix = $fullId.Substring(0, [Math]::Min(8, $fullId.Length))
            $destDir = Join-Path $sessionsDir $project
            $destFile = Join-Path $destDir "${archiveDate}_${prefix}.jsonl"

            if (Test-Path $destFile) {
                Write-Host "Already archived: $($destFile.Substring($userRepo.Length + 1))"
                exit 0
            }

            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Copy-Item -Path $transcript.FullName -Destination $destFile
            Write-Host "Archived: $($destFile.Substring($userRepo.Length + 1))"
        }
        "move" {
            $src = if ($subArgs.Count -gt 0) { $subArgs[0] } else { "" }
            $destProject = if ($subArgs.Count -gt 1) { $subArgs[1] } else { "" }
            if (-not $src -or -not $destProject) {
                LogError "source file and destination project required"
                Write-Host "Usage: aitools sessions move <file> <project>"
                exit 1
            }

            # Resolve source path
            if ([System.IO.Path]::IsPathRooted($src)) {
                $srcFile = $src
            } else {
                $srcFile = Join-Path $sessionsDir $src
            }

            if (-not (Test-Path $srcFile)) {
                LogError "session file not found: $src"
                exit 1
            }

            $destDir = Join-Path $sessionsDir $destProject
            $destFile = Join-Path $destDir (Split-Path $srcFile -Leaf)
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Move-Item -Path $srcFile -Destination $destFile
            Write-Host "Moved: $(Split-Path $srcFile -Leaf) -> $destProject/"
            Write-Host "Note: Claude Code sessions are tied to the original working directory and cannot be moved."

            # Clean up empty source directory
            $oldDir = Split-Path $srcFile -Parent
            if ((Test-Path $oldDir) -and (Get-ChildItem $oldDir | Measure-Object).Count -eq 0) {
                Remove-Item $oldDir
            }
        }
        "" {
            LogError "missing subcommand"
            Write-Host "Usage: aitools sessions list|archive|move"
            exit 1
        }
        default {
            LogError "unknown subcommand 'sessions $subCmd'"
            Write-Host "Usage: aitools sessions list|archive|move"
            exit 1
        }
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Verify repo exists (clone fresh if missing)
# ---------------------------------------------------------------------------

if (-not (Test-Path (Join-Path $repoPath ".git"))) {
    LogWarn "Repo not found at $repoPath -- cloning fresh..."
    $reposDir = Split-Path $repoPath -Parent
    if (-not (Test-Path $reposDir)) { New-Item -ItemType Directory -Path $reposDir -Force | Out-Null }
    git clone https://github.com/nobul-jose/aitools.git $repoPath
    if ($LASTEXITCODE -ne 0) {
        LogError "Failed to clone repo to $repoPath"
        exit 1
    }
    LogOk "Clone successful"
}

# ---------------------------------------------------------------------------
# Run update (pull + rebuild + deploy/install)
# ---------------------------------------------------------------------------

$env:AITOOLS_RUN_ID = -join ((1..6) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

# Init summary file for this run; child scripts append via AITOOLS_SUMMARY_FILE.
# SUPPRESS=1 tells aitools-install.ps1 not to display it (we display after it returns).
$env:AITOOLS_SUMMARY_FILE = Join-Path $env:USERPROFILE ".aitools\run-summary.txt"
Remove-Item $env:AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force | Out-Null
$env:AITOOLS_SUPPRESS_SUMMARY_DISPLAY = "1"

# Source shared lib (provides Write-Summary, Show-Summary)
. (Join-Path $repoPath "scripts" "aitools-lib.ps1")
Initialize-Logging "aitools"
# Override: file-only logging, errors/warns to stderr (no console echo)
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Add-Content -Path $logFile -Value "[$ts] [aitools] [$level] $msg"
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; Write-Host "error: $msg" -ForegroundColor Red; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; Write-Host "warning: $msg" -ForegroundColor Yellow; $script:warnings++ }

Write-Host "aitools $AITOOLS_INSTALLED_VERSION"
Write-Host ""

if ($doInstall) {
    $steps = 3
} elseif ($doGitpull) {
    $steps = 4
} else {
    # no-args: quiet pull + rebuild + deploy
    $steps = 3
}

# [1/N] Pull latest
Write-Host "[1/$steps] Pulling latest..."
$pulledUpdates = $false
Push-Location $repoPath
try {
    # Reset generated files before pull (line-ending diffs, mode changes)
    git checkout HEAD -- "deploy/" 2>$null
    if ($doGitpull) {
        $pullOut = git pull --tags origin main 2>&1 | Out-String
    } else {
        $pullOut = git pull origin main 2>&1 | Out-String
    }
    if ($LASTEXITCODE -ne 0) {
        if ($doGitpull) {
            LogError "git pull failed"
            Write-Host $pullOut
            exit 1
        } else {
            if ($pullOut -match "(?i)(could not resolve|unable to access|connection refused|connection timed out|no route to host)") {
                Write-Host "  Could not reach remote - deploying from local checkout."
            } else {
                LogWarn "git pull failed -- deploying from local checkout."
                $pullOut.Trim().Split("`n") | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" }
            }
            Write-Summary "WARN" "source" "stale local checkout (git pull failed)"
        }
    } elseif ($pullOut -match "Already up to date") {
        Write-Host "  Already up to date."
    } else {
        $pulledUpdates = $true
        Write-Host "  Updated."
    }
} finally {
    Pop-Location
}

# Pull user repo (quiet, non-blocking -- stale local data is better than failing)
$userRepoPath = Read-ConfigKey -File $configFile -Key "userRepoPath"
if ($userRepoPath -and (Test-Path (Join-Path $userRepoPath ".git"))) {
    $urPull = git -C $userRepoPath pull --ff-only --quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        LogWarn "user repo pull failed -- using local copy."
        LogDetail "user-repo-pull: $($urPull.Trim())"
    }
}

# [2/N] Rebuild deploy scripts
Write-Host "[2/$steps] Rebuilding deploy scripts..."
# build-deploy.sh is intentionally bash-only (text-processing-heavy, no .ps1 variant).
# Invoke via Git Bash, which is a prerequisite for Claude Code on Windows.
# See .claude/rules/cross-platform.md "Approved exceptions" for why.
$bashExe = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bashExe)) {
    LogError "Git Bash not found at $bashExe (required for build)"
    exit 1
}
# Convert Windows path to Unix-style for Git Bash (C:\repos\... → /c/repos/...)
$unixRepoPath = $repoPath -replace '^([A-Za-z]):\\', '/$1/' -replace '\\', '/'
if ($unixRepoPath -match '^/([A-Za-z])/') {
    $unixRepoPath = '/' + $Matches[1].ToLower() + $unixRepoPath.Substring(2)
}
$buildResult = & $bashExe "$unixRepoPath/scripts/build-deploy.sh" 2>&1 | Out-String
Add-Content -Path $logFile -Value $buildResult
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Done."
} else {
    LogError "build failed (see $logFile)"
    exit 1
}

if ($doInstall) {
    # --- install: pull + rebuild + run installer (includes deploy) ---
    Write-Host "[3/$steps] Running installer..."
    Write-Host ""
    $installerArgs = @()
    if ($SkipGhAuth) { $installerArgs += "-SkipGhAuth" }
    if ($SkipDriveDetection) { $installerArgs += "-SkipDriveDetection" }
    if ($ReposPath) { $installerArgs += "-ReposPath"; $installerArgs += $ReposPath }
    & "$repoPath\scripts\aitools-install.ps1" @installerArgs
    $installerRc = $LASTEXITCODE
    Write-Host ""
    if ($installerRc -eq 0) {
        Write-Host "All up to date. ($(Get-RepoVersion $repoPath))"
        # Session archive hint (after final status line)
        $userRepo = Read-ConfigKey -File $configFile -Key "userRepoPath"
        if (-not $userRepo) {
            Write-Host "hint: To archive sessions across machines, run 'aitools user init'." -ForegroundColor Yellow
        }
        Invoke-ProfileCheck -Mode "interactive"
    } else {
        Write-Host "Completed with errors (see $logFile)."
    }

} elseif ($doGitpull) {
    # --- gitpull: pull + rebuild + deploy + changelog + version tag ---
    Write-Host "[3/$steps] Deploying configurations..."
    $deployRc = Deploy-Configs (Join-Path $repoPath "scripts")
    if ($deployRc -eq 0) {
        Write-Host "  Done."
    } else {
        Write-Host "  Completed with $deployRc error(s)."
    }

    Write-Host "[4/$steps] Tagging version..."
    # Skip if HEAD already has a tag (e.g., re-running gitpull without new commits)
    $existing = git -C $repoPath describe --tags --match "v*" --exact-match HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing) {
        Write-Host "  HEAD already tagged ($existing) -- skipping"
        $tag = $existing
    } else {
        $latestTag = git -C $repoPath describe --tags --match "v*" --abbrev=0 2>$null
        if (-not $latestTag) { $latestTag = "v0.0.0" }
        if ($gitpullPatch) {
            # Patch bump: v0.14.0 -> v0.14.1
            $parts = $latestTag.TrimStart("v").Split(".")
            $parts[2] = [string]([int]$parts[2] + 1)
            $tag = "v" + ($parts -join ".")
        } else {
            # Minor bump: v0.14.0 -> v0.15.0 (existing default)
            $latestMinor = [int](($latestTag -replace '^v0\.(\d+)\..*', '$1'))
            $nextMinor = $latestMinor + 1
            $tag = "v0.${nextMinor}.0"
        }
        # Release notes gate: require a matching entry before tagging
        $tagShort = $tag -replace '\.0$', ''  # v0.18.0 -> v0.18, v0.18.1 stays v0.18.1
        $rnFile = Join-Path $repoPath "RELEASE_NOTES.md"
        $tagEsc = [regex]::Escape($tag)
        $tagShortEsc = [regex]::Escape($tagShort)
        $rnMatch = $false
        if (Test-Path $rnFile) {
            $rnMatch = (Select-String -Path $rnFile -Pattern "^## $tagEsc |^## $tagShortEsc " -Quiet) -eq $true
        }
        if (-not $rnMatch) {
            $today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
            Write-Host "  RELEASE_NOTES.md has no entry for $tag -- skipping tag." -ForegroundColor Yellow
            Write-Host "  Add a '## $tag -- Title ($today)' section first."
            $tag = "(skipped)"
        } else {
            git -C $repoPath tag $tag
            $pushResult = git -C $repoPath push origin $tag 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Tagged $tag"
            } else {
                Write-Host "  Tagged $tag (local only -- push failed)"
            }
        }
    }

    Write-Host ""
    if ($pulledUpdates) {
        Write-Host "Updated and deployed. ($tag)"
        # Show date-formatted changelog (no hashes)
        Push-Location $repoPath
        git log --format='  %ad  %s' --date=short ORIG_HEAD..HEAD 2>$null | ForEach-Object { Write-Host $_ }
        Pop-Location
    } else {
        Write-Host "Deployed. ($tag)"
    }

} else {
    # --- no-args: quiet pull + rebuild + deploy ---
    Write-Host "[3/$steps] Deploying configurations..."
    $deployRc = Deploy-Configs (Join-Path $repoPath "scripts")
    if ($deployRc -eq 0) {
        Write-Host "  Done."
    } else {
        Write-Host "  Completed with $deployRc error(s)."
    }

    Write-Host ""
    Write-Host "Configs deployed. ($(Get-RepoVersion $repoPath))"

    Invoke-ProfileCheck -Mode "interactive"

    # Session archive hint (after final status line)
    $settingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
    $hookInstalled = $false
    if (Test-Path $settingsFile) {
        $settingsContent = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
        if ($settingsContent -and $settingsContent -match "session-archive\.sh") {
            $hookInstalled = $true
        }
    }
    if ($hookInstalled) {
        $userRepo = Read-ConfigKey -File $configFile -Key "userRepoPath"
        if (-not $userRepo) {
            Write-Host "WARNING: session archive hook installed but inactive -- userRepoPath not configured. Run 'aitools user init'." -ForegroundColor Yellow
        }
    } else {
        Write-Host "hint: session archive hook not installed. Run 'aitools user init' to set up." -ForegroundColor Yellow
    }
}

# Self-update: bake version into installed copy AFTER installer
$newVersion = Get-RepoVersion $repoPath

# Update PS1 copy (validate syntax on current PS version before overwriting)
$aitoolsSrc = Join-Path $repoPath "scripts\aitools.ps1"
$aitoolsDst = Join-Path $env:USERPROFILE ".local\bin\aitools.ps1"
if (Test-Path $aitoolsSrc) {
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($aitoolsSrc, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        LogWarn "skipping PS1 self-update (new aitools.ps1 has parse errors on this PowerShell version)"
    } else {
        $srcContent = Get-Content $aitoolsSrc -Raw
        $stampedContent = $srcContent -replace '^\$AITOOLS_INSTALLED_VERSION = ".*"', "`$AITOOLS_INSTALLED_VERSION = `"$newVersion`""
        [System.IO.File]::WriteAllText($aitoolsDst, $stampedContent, [System.Text.UTF8Encoding]::new($false))
    }
}

# Update bash copy (keeps both in sync when PS1 is invoked directly)
$bashSrc = Join-Path $repoPath "scripts\aitools"
$bashDst = Join-Path $env:USERPROFILE ".local\bin\aitools"
if (Test-Path $bashSrc) {
    $bashContent = Get-Content $bashSrc -Raw
    $bashStamped = $bashContent -replace '^AITOOLS_INSTALLED_VERSION=".*"', "AITOOLS_INSTALLED_VERSION=`"$newVersion`""
    [System.IO.File]::WriteAllText($bashDst, $bashStamped, [System.Text.UTF8Encoding]::new($false))
}

Show-Summary

Remove-Item Env:\AITOOLS_RUN_ID -ErrorAction SilentlyContinue
Remove-Item Env:\AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
Remove-Item Env:\AITOOLS_SUPPRESS_SUMMARY_DISPLAY -ErrorAction SilentlyContinue
