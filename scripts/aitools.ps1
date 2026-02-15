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
    [switch]$SkipDriveDetection
)

$AITOOLS_INSTALLED_VERSION = "dev"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Write-Error "This script is for Windows. On macOS/Linux, use the bash 'aitools' command instead."
    exit 1
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

function Get-RepoVersion {
    param([string]$RepoPath)
    try {
        $log = git -C $RepoPath log -1 --format='%cd (%h)' --date=short 2>$null
        if ($log) { return $log } else { return "unknown" }
    } catch { return "unknown" }
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
  (none)               Pull latest and rebuild deploy scripts (self-update)
  install              Install/update all tools and deploy configurations
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
$doMcpStatus = $Command -eq "mcp"

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
# Verify repo exists
# ---------------------------------------------------------------------------

if (-not (Test-Path (Join-Path $repoPath ".git"))) {
    Write-Host "error: ai-tooling repo not found at $repoPath"
    Write-Host "Clone it first, then re-run the installer."
    exit 1
}

# ---------------------------------------------------------------------------
# Run update (pull + rebuild)
# ---------------------------------------------------------------------------

$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$env:AITOOLS_RUN_ID = -join ((1..6) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

Write-Host "aitools $AITOOLS_INSTALLED_VERSION"
Write-Host ""

if ($doInstall) {
    $steps = 3
} else {
    $steps = 2
}

# [1/N] Pull latest
Write-Host "[1/$steps] Pulling latest..."
$pulledUpdates = $false
Push-Location $repoPath
try {
    $pullOut = git pull origin main 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  error: git pull failed" -ForegroundColor Red
        Write-Host $pullOut
        exit 1
    }
    if ($pullOut -match "Already up to date") {
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
# build-deploy.sh is bash-only -- use Git Bash
$bashExe = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $bashExe)) {
    Write-Host "  error: Git Bash not found at $bashExe (required for build)" -ForegroundColor Red
    exit 1
}
$buildResult = & $bashExe "$repoPath/scripts/build-deploy.sh" 2>&1 | Out-String
Add-Content -Path $logFile -Value $buildResult
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Done."
} else {
    Write-Host "  error: build failed (see $logFile)" -ForegroundColor Red
    exit 1
}

if ($doInstall) {
    # [3/3] Run installer (output visible to user)
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
} else {
    Write-Host ""
    if ($pulledUpdates) {
        Write-Host "Updated. ($(Get-RepoVersion $repoPath))"
        # Show what changed
        Push-Location $repoPath
        git log --oneline ORIG_HEAD..HEAD 2>$null | ForEach-Object { Write-Host "  $_" }
        Pop-Location
        Write-Host ""
        Write-Host "Run 'aitools install' to apply changes."
    } else {
        Write-Host "Synced. ($(Get-RepoVersion $repoPath))"
        Write-Host "Run 'aitools install' to deploy configurations."
    }
}

# Self-update: bake version into installed copy AFTER installer
$aitoolsSrc = Join-Path $repoPath "scripts\aitools.ps1"
$aitoolsDst = Join-Path $env:USERPROFILE ".local\bin\aitools.ps1"
if (Test-Path $aitoolsSrc) {
    $newVersion = Get-RepoVersion $repoPath
    $srcContent = Get-Content $aitoolsSrc -Raw
    $stampedContent = $srcContent -replace '^\$AITOOLS_INSTALLED_VERSION = ".*"', "`$AITOOLS_INSTALLED_VERSION = `"$newVersion`""
    [System.IO.File]::WriteAllText($aitoolsDst, $stampedContent, [System.Text.UTF8Encoding]::new($false))
}

Remove-Item Env:\AITOOLS_RUN_ID -ErrorAction SilentlyContinue
