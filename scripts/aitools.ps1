# aitools.ps1 -- pull latest ai-tooling scaffolding and manage dev tools
# Installed to ~/.local/bin/ by scripts/aitools-install.ps1
# Native PowerShell CLI -- Windows counterpart to scripts/aitools (bash).

param(
    [Parameter(Position = 0)]
    [string]$Command = "",
    [switch]$Version,
    [Alias("h")]
    [switch]$Help,
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

# Version string from a git repo using tag-based scheme.
# v2026-02-16.2.0           → 2026-02-16.2.0
# v2026-02-16.2.0-3-gabcdef → 2026-02-16.2.3
function Get-RepoVersion {
    param([string]$RepoPath)
    try {
        $desc = git -C $RepoPath describe --tags --match "v*" 2>$null
        if ($desc) {
            $base = $desc.TrimStart("v")
            if ($base -match '^(.+)-(\d+)-g[0-9a-f]+$') {
                # v2026-02-16.2.0-3-gabcdef → 2026-02-16.2.3
                $tagPart = $Matches[1]       # 2026-02-16.2.0
                $commits = $Matches[2]       # 3
                $prefix = $tagPart.Substring(0, $tagPart.LastIndexOf('.'))  # 2026-02-16.2
                return "${prefix}.${commits}"
            } else {
                return $base                 # 2026-02-16.2.0
            }
        }
        # No tags — fallback
        $log = git -C $RepoPath log -1 --format='%cd (%h)' --date=short 2>$null
        if ($log) { return $log } else { return "unknown" }
    } catch { return "unknown" }
}

# Deploy all config scripts from the repo's scripts/ directory.
function Deploy-Configs {
    param([string]$ScriptDir)
    $deployScripts = @("setup-user-claude.ps1", "setup-user-mcp.ps1", "setup-cursor-mcp.ps1", "setup-user-cursor.ps1")
    $errors = 0
    $env:AITOOLS_DEPLOY = "1"
    foreach ($script in $deployScripts) {
        $scriptPath = Join-Path $ScriptDir $script
        if (Test-Path $scriptPath) {
            # Validate PS1 syntax before executing
            $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $scriptPath, [ref]$null, [ref]$parseErrors)
            if ($parseErrors.Count -gt 0) {
                Write-Host "  warning: $script has parse errors -- skipping"
                $errors++
                continue
            }
            # Reset exit code before each script (prevents stale values from previous iteration)
            $global:LASTEXITCODE = 0
            try {
                & $scriptPath *> $null 2>> $logFile
            } catch {
                Write-Host "  error: $script failed (see $logFile)"
                $errors++
                continue
            }
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                Write-Host "  error: $script failed (see $logFile)"
                $errors++
            }
        } else {
            Write-Host "  warning: $script not found - skipping"
        }
    }
    Remove-Item Env:\AITOOLS_DEPLOY -ErrorAction SilentlyContinue
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

# ---------------------------------------------------------------------------
# Usage / flags
# ---------------------------------------------------------------------------

function Show-Usage {
    @"
Usage: aitools [COMMAND] [OPTIONS]

Commands:
  (none)               Sync configs: pull + rebuild + deploy all configurations
  gitpull              Update source: pull + rebuild + deploy + changelog + version tag
  install              Full setup: pull + rebuild + install tools + deploy configs
  mcp                  Show MCP server status for current project

Options:
  --addmcp <name...>   Enable MCP server(s) for current project (vercel, webflow)
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

# Reject unknown commands (typos like "installs", "mcpp", etc.)
if ($Command -and -not $doInstall -and -not $doGitpull -and -not $doMcpStatus) {
    Write-Host "error: unknown command '$Command'"
    Write-Host "Run 'aitools --help' for usage."
    exit 1
}

# Reject --addmcp with no server names
if ($PSBoundParameters.ContainsKey('AddMcp') -and $AddMcp.Count -eq 0) {
    Write-Host "error: --addmcp requires at least one server name (vercel, webflow)"
    exit 1
}

# ---------------------------------------------------------------------------
# Resolve repo path from config
# ---------------------------------------------------------------------------

$configFile = Join-Path $env:USERPROFILE ".config\ai-tooling\config.json"
$repoPath = ""

$raw = Read-ConfigKey -File $configFile -Key "aiToolingRepoPath"
if ($raw) { $repoPath = $raw }
if (-not $repoPath) { $repoPath = Join-Path $env:USERPROFILE "repos\ai-tooling" }

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
        Write-Host "error: node required for mcp status"
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
            Write-Host "error: unknown MCP server '$name'"
            Write-Host "Supported servers: vercel, webflow"
            exit 1
        }
    }

    # Warn if cwd doesn't look like a project
    if (-not (Test-Path ".git") -and -not (Test-Path "package.json") -and -not (Test-Path "pyproject.toml")) {
        Write-Host "warning: current directory doesn't look like a project root"
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
try { settings = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}
if (!settings.permissions) settings.permissions = {};
if (!Array.isArray(settings.permissions.allow)) settings.permissions.allow = [];
const rule = 'MCP($name)';
if (!settings.permissions.allow.includes(rule)) {
    settings.permissions.allow.push(rule);
}
fs.writeFileSync(f, JSON.stringify(settings, null, 2) + '\n');
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
try { cfg = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}
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
# Verify repo exists (or clone if gitpull)
# ---------------------------------------------------------------------------

if (-not (Test-Path (Join-Path $repoPath ".git"))) {
    if ($doGitpull) {
        Write-Host "Repo not found - cloning..."
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            gh repo clone nobul-jose/ai-tooling $repoPath
            if ($LASTEXITCODE -ne 0) {
                Write-Host "error: clone failed"
                exit 1
            }
        } else {
            Write-Host "error: gh CLI not found. Install GitHub CLI first."
            exit 1
        }
    } else {
        Write-Host "error: ai-tooling repo not found at $repoPath"
        Write-Host "Run 'aitools gitpull' to clone the repo first."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Run update (pull + rebuild + deploy/install)
# ---------------------------------------------------------------------------

$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$env:AITOOLS_RUN_ID = -join ((1..6) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

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
    if ($doGitpull) {
        $pullOut = git pull --tags origin main 2>&1 | Out-String
    } else {
        $pullOut = git pull origin main 2>&1 | Out-String
    }
    if ($LASTEXITCODE -ne 0) {
        if ($doGitpull) {
            Write-Host "  error: git pull failed" -ForegroundColor Red
            Write-Host $pullOut
            exit 1
        } else {
            Write-Host "  Could not reach remote - deploying from local checkout."
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

# [2/N] Rebuild deploy scripts
Write-Host "[2/$steps] Rebuilding deploy scripts..."
# build-deploy.sh is intentionally bash-only (text-processing-heavy, no .ps1 variant).
# Invoke via Git Bash, which is a prerequisite for Claude Code on Windows.
# See .claude/rules/cross-platform.md "Approved exceptions" for why.
$bashExe = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bashExe)) {
    Write-Host "  error: Git Bash not found at $bashExe (required for build)" -ForegroundColor Red
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
    Write-Host "  error: build failed (see $logFile)" -ForegroundColor Red
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
    $today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $existingTags = git -C $repoPath tag -l "v${today}.*" 2>$null
    $session = if ($existingTags) { @($existingTags).Count + 1 } else { 1 }
    $tag = "v${today}.${session}.0"
    git -C $repoPath tag $tag
    $pushResult = git -C $repoPath push origin $tag 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Tagged $tag"
    } else {
        Write-Host "  Tagged $tag (local only - push failed)"
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
        Write-Host "  warning: skipping PS1 self-update (new aitools.ps1 has parse errors on this PowerShell version)" -ForegroundColor Yellow
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

Remove-Item Env:\AITOOLS_RUN_ID -ErrorAction SilentlyContinue
