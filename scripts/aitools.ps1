# aitools.ps1 -- pull latest ai-tooling scaffolding and manage dev tools
# Installed to ~/.local/bin/ by scripts/aitools-install.ps1
# Native PowerShell CLI -- Windows counterpart to scripts/aitools (bash).

param(
    [Parameter(Position = 0)]
    [string]$Command = "",
    [switch]$Version,
    [Alias("h")]
    [switch]$Help,
    [switch]$Patch,
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
    $deployScripts = @("setup-user-claude.ps1", "setup-user-mcp.ps1", "setup-cursor-mcp.ps1", "setup-user-cursor.ps1", "setup-user-hooks.ps1")
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
# Migrate config directory: ~\.config\ai-tooling\ -> ~\.aitools\
# ---------------------------------------------------------------------------

$oldConfigDir = Join-Path $env:USERPROFILE ".config\ai-tooling"
$newConfigDir = Join-Path $env:USERPROFILE ".aitools"

if ((Test-Path $oldConfigDir) -and -not (Test-Path $newConfigDir)) {
    Move-Item -Path $oldConfigDir -Destination $newConfigDir
} elseif ((Test-Path $oldConfigDir) -and (Test-Path $newConfigDir)) {
    Write-Host "warning: both $oldConfigDir and $newConfigDir exist -- using $newConfigDir"
}

# ---------------------------------------------------------------------------
# Resolve repo path from config
# ---------------------------------------------------------------------------

$configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
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
                Write-Host "error: GitHub username required"
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

            } elseif ((Get-Command gh -ErrorAction SilentlyContinue) -and
                      ((gh repo view "$ghUser/$repoName" --json name 2>$null) -ne $null)) {
                # --- Path 2: GitHub repo exists, no local clone ---
                Write-Host "GitHub repo exists. Cloning to $userRepoDir..."
                gh repo clone "$ghUser/$repoName" $userRepoDir

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
} catch {}
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

                # Create README
                [System.IO.File]::WriteAllText(
                    (Join-Path $userRepoDir "README.md"),
                    "# $repoName`n`nPrivate user repo for session archives and profile data.`nSee [ai-tooling](https://github.com/$ghUser/ai-tooling) for details.`n",
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

            # Write userRepoPath and machineAlias to config
            if (Get-Command node -ErrorAction SilentlyContinue) {
                node -e @"
const fs = require('fs');
const f = process.argv[1];
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}
cfg.userRepoPath = process.argv[2];
if (process.argv[3]) cfg.machineAlias = process.argv[3];
fs.writeFileSync(f, JSON.stringify(cfg, null, 2) + '\n');
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
            Write-Host "error: missing subcommand"
            Write-Host "Usage: aitools user init"
            exit 1
        }
        default {
            Write-Host "error: unknown subcommand 'user $subCmd'"
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
        Write-Host "error: user repo not configured. Run 'aitools user init' first."
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
                Write-Host "error: session ID required"
                Write-Host "Usage: aitools sessions archive <session-id>"
                exit 1
            }

            # Search for matching session
            $claudeProjects = Join-Path $env:USERPROFILE ".claude\projects"
            if (-not (Test-Path $claudeProjects)) {
                Write-Host "error: no Claude Code sessions found at $claudeProjects"
                exit 1
            }

            $matches = Get-ChildItem -Path $claudeProjects -Filter "${sessionId}*.jsonl" -Recurse -File
            if ($matches.Count -eq 0) {
                Write-Host "error: no session found matching '$sessionId'"
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
                Write-Host "error: source file and destination project required"
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
                Write-Host "error: session file not found: $src"
                exit 1
            }

            $destDir = Join-Path $sessionsDir $destProject
            $destFile = Join-Path $destDir (Split-Path $srcFile -Leaf)
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Move-Item -Path $srcFile -Destination $destFile
            Write-Host "Moved: $(Split-Path $srcFile -Leaf) -> $destProject/"

            # Clean up empty source directory
            $oldDir = Split-Path $srcFile -Parent
            if ((Test-Path $oldDir) -and (Get-ChildItem $oldDir | Measure-Object).Count -eq 0) {
                Remove-Item $oldDir
            }
        }
        "" {
            Write-Host "error: missing subcommand"
            Write-Host "Usage: aitools sessions list|archive|move"
            exit 1
        }
        default {
            Write-Host "error: unknown subcommand 'sessions $subCmd'"
            Write-Host "Usage: aitools sessions list|archive|move"
            exit 1
        }
    }
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

$logDir = Join-Path $env:LOCALAPPDATA "aitools"
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
    # Reset generated deploy/ files before pull (may have line-ending diffs)
    git checkout -- "deploy/" 2>$null
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
            if ($pullOut -match "(?i)(could not resolve|unable to access|connection refused|connection timed out|no route to host)") {
                Write-Host "  Could not reach remote - deploying from local checkout."
            } else {
                Write-Host "  warning: git pull failed - deploying from local checkout." -ForegroundColor Yellow
                $pullOut.Trim().Split("`n") | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" }
            }
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
        # Session archive hint (after final status line)
        $userRepo = Read-ConfigKey -File $configFile -Key "userRepoPath"
        if (-not $userRepo) {
            Write-Host "hint: To archive sessions across machines, run 'aitools user init'." -ForegroundColor Yellow
        }
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
        git -C $repoPath tag $tag
        $pushResult = git -C $repoPath push origin $tag 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Tagged $tag"
        } else {
            Write-Host "  Tagged $tag (local only -- push failed)"
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
