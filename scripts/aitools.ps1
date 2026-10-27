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
    [string]$Alias,
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
# Bootstrap helper -- needed to find aitools-lib.ps1 (repoPath in config.json).
# Everything else (logging, Write-Summary, ...) comes from the lib, which is
# dot-sourced as soon as repoPath is known (see "Load aitools-lib" below).
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
            if ($Mode -eq "interactive" -and (Test-UiCanAsk)) {
                [Console]::Write("Migrate profile.json to v2 now? [y/N]: ")
                $answer = Read-ConsoleChoice "no"
                if ($answer -match '^[Yy]' -and $result.profilePath) {
                    $null = Invoke-UiV1Migrate (Split-Path $result.profilePath -Parent)
                }
            }
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

# Invoke-DeployAbort SCRIPT -- deploy-harness exited 2: the user chose [x]abort at a
# review menu (D-TS13; abort ends the whole run, T-Q3). The remaining deploy steps
# are not run; the caller shows the summary and exits 2. Parity: deploy_abort in
# scripts/aitools.
function Invoke-DeployAbort([string]$AbortedScript) {
    # Not $ScriptName: it would hide the lib's $scriptName, the [script] field Log writes
    $script:deployAborted = $true
    Log "${AbortedScript}: aborted by user at a review menu -- remaining deploy steps not run"
    Write-Summary "WARN" "harness files" "aborted by user"
}

# Deploy all config scripts from the repo's scripts/ directory.
function Deploy-Configs {
    param([string]$ScriptDir)
    # deploy-harness first: it fills .aitools and runs the config writer
    # (setup-user-config) itself, so the writer is not in this list (once per run)
    $deployScripts = @("deploy-harness.ps1", "setup-user-claude.ps1", "setup-user-mcp.ps1", "setup-user-skills.ps1", "setup-cursor-ide-mcp.ps1", "setup-user-cursor.ps1", "setup-user-settings.ps1", "setup-user-hooks.ps1")
    $errors = 0
    $script:deployAborted = $false   # the caller reads it (Invoke-DeployAbort sets it)
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
                foreach ($err in $parseErrors) {
                    LogDetail "$script parse: line $($err.Extent.StartLineNumber): $($err.Message)"
                }
                LogError "$script has parse errors -- skipped (see $logFile)"
                Write-Summary "ERROR" ($script -replace '\.ps1$', '') "parse errors -- skipped"
                $errors++
                continue
            }
            if ($script -eq "deploy-harness.ps1") {
                # In-process and relayed to deploy.jsonl (aitools-lib Invoke-ChildRelayed);
                # the review menu reads and writes the console directly. The lib logs
                # the error for a failed run (and the ERROR row for a throw).
                $harnessRc = Invoke-ChildRelayed $script $scriptPath @{} "harness files"
                if ($script:AitLibChildRc -eq 2) {
                    Invoke-DeployAbort $script
                    break
                }
                if ($harnessRc -ne 0) {
                    # Exit 0 with error lines: the lib logged them and returned 1
                    $harnessExit = if ($script:AitLibChildRc -eq 0) { 1 } else { $script:AitLibChildRc }
                    Write-Summary "ERROR" "harness files" "script failed (exit $harnessExit)"
                    $errors++
                }
                continue
            }
            # Reset exit code before each script (prevents stale values from previous iteration)
            $global:LASTEXITCODE = 0
            # Run script without output redirection -- child scripts log to
            # deploy.log via aitools-lib. PowerShell's 2>> holds a file lock
            # that blocks the child's [IO.File]::AppendAllText on the same file.
            try {
                & $scriptPath
            } catch {
                LogError "$script failed: $_"
                Write-Summary "ERROR" ($script -replace '\.ps1$', '') "script failed (exception)"
                $errors++
                continue
            }
            $scriptRc = $LASTEXITCODE
            if ($scriptRc -and $scriptRc -ne 0) {
                LogError "$script failed (exit $scriptRc) -- see $logFile"
                Write-Summary "ERROR" ($script -replace '\.ps1$', '') "script failed (exit $scriptRc)"
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

    # [x]abort in deploy-harness: the run stops here (the caller exits 2)
    if ($script:deployAborted) {
        if (Test-Path Env:\AITOOLS_DEPLOY) { Remove-Item Env:\AITOOLS_DEPLOY }
        if (Test-Path Env:\AITOOLS_DRY_RUN) { Remove-Item Env:\AITOOLS_DRY_RUN }
        if (Test-Path Env:\AITOOLS_FORCE) { Remove-Item Env:\AITOOLS_FORCE }
        return $errors
    }

    # Best-effort: mirror relay.md into ~/.cursor/AGENTS.md (same as scripts/aitools bash).
    Sync-RelayToCursorAgents -ScriptDir $ScriptDir

    Remove-Item Env:\AITOOLS_DEPLOY -ErrorAction SilentlyContinue
    Remove-Item Env:\AITOOLS_DRY_RUN -ErrorAction SilentlyContinue
    Remove-Item Env:\AITOOLS_FORCE -ErrorAction SilentlyContinue
    return $errors
}

# Mirror .aitools/channel/relay.md into user Cursor AGENTS.md (non-fatal).
# Parity with scripts/aitools deploy_configs tail + aitools-install.ps1 Step 22.
function Sync-RelayToCursorAgents {
    param([string]$ScriptDir)
    $syncPy = Join-Path $ScriptDir "sync-relay-to-cursor-agents.py"
    if (-not (Test-Path $syncPy)) {
        LogWarn "sync-relay-to-cursor-agents.py not found -- skipping relay→AGENTS sync"
        return
    }
    if (-not $DryRun) { $env:AITOOLS_SYNC_DEPLOY_LOG = "1" }
    $target = Join-Path $env:USERPROFILE ".cursor\AGENTS.md"
    $syncArgs = @($syncPy, "--target", $target)
    if ($DryRun) { $syncArgs += "--dry-run" }
    $exitCode = -1
    try {
        if (Get-Command python3 -ErrorAction SilentlyContinue) {
            $out = & python3 @syncArgs 2>&1
            $exitCode = $LASTEXITCODE
        } elseif (Get-Command py -ErrorAction SilentlyContinue) {
            $pyArgs = @("-3") + $syncArgs
            $out = & py @pyArgs 2>&1
            $exitCode = $LASTEXITCODE
        } else {
            LogWarn "Python not found -- skipping relay→AGENTS sync"
            Remove-Item Env:\AITOOLS_SYNC_DEPLOY_LOG -ErrorAction SilentlyContinue
            return
        }
        if ($null -ne $out) {
            $out | Add-Content -Path $logFile -Encoding utf8
        }
        if ($exitCode -eq 0) {
            if ($DryRun) { LogOk "relay→AGENTS sync (dry-run)" }
        } else {
            LogWarn "sync-relay-to-cursor-agents.py failed (non-fatal, exit $exitCode)"
        }
    } catch {
        LogWarn "relay→AGENTS sync failed (non-fatal): $_"
    }
    Remove-Item Env:\AITOOLS_SYNC_DEPLOY_LOG -ErrorAction SilentlyContinue
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
  user init            Set up user repo, register this machine's profile, configure session archiving hook
  user init --alias A  Same, registering this machine as profile A without a prompt
  sessions list [proj] List archived sessions (optionally filter by project)
  sessions archive ID  Manually archive a session by ID (full or prefix)
  sessions move F proj Refile an archived session under a different project
  dashboard            Start the live mission control dashboard server
                       --stop: stop the server  --status: show server status
                       --snapshot: generate static HTML  --background: for hooks

Options:
  --addmcp <name...>   Enable MCP server(s) for current project (vercel, webflow)
  --dry-run            Preview what would change without writing any files
  --force              No prompts: managed files take the source version (backups
                       kept); with install, also skips gh login and path prompts
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
$doDashboard = $Command -eq "dashboard"

# --patch flag for gitpull (may come via -Patch switch or positional $Remaining)
$gitpullPatch = $false
if ($doGitpull) {
    if ($Patch) { $gitpullPatch = $true }
    if ($Remaining -and $Remaining -contains "--patch") {
        $gitpullPatch = $true
        $Remaining = @($Remaining | Where-Object { $_ -ne "--patch" })
    }
}

# aitools user init --alias <alias> / -Alias <alias>: register this machine without a
# prompt (P-Q12). PowerShell binds --alias to -Alias itself under pwsh -File
# (Review3 #82 minor 7: the former scan of $Remaining for --alias never ran).
$script:UserAlias = $Alias

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

# Warnings and notes found before the lib is loaded (it holds the logging); logged right after.
$preLibWarnings = @()
$preLibNotes = @()

# ---------------------------------------------------------------------------
# Migrate config directory: ~\.config\ai-tooling\ -> ~\.aitools\
# ---------------------------------------------------------------------------

$oldConfigDir = Join-Path $env:USERPROFILE ".config\ai-tooling"
$newConfigDir = Join-Path $env:USERPROFILE ".aitools"

if ((Test-Path $oldConfigDir) -and -not (Test-Path $newConfigDir)) {
    Move-Item -Path $oldConfigDir -Destination $newConfigDir
} elseif ((Test-Path $oldConfigDir) -and (Test-Path $newConfigDir)) {
    $preLibWarnings += "both $oldConfigDir and $newConfigDir exist -- using $newConfigDir"
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
        $preLibNotes += "Migrated config: aiToolingRepoPath -> repoPath"
        # Re-read after migration
        $repoPath = Read-ConfigKey -File $configFile -Key "repoPath"
    } catch {
        $preLibWarnings += "Config key migration failed: $_"
        # Non-fatal: continue with whatever repoPath was already resolved
    }
}

# ---------------------------------------------------------------------------
# Verify repo exists (clone fresh if missing). Runs before the lib is loaded --
# the lib lives in the repo -- so status goes to the console directly and the
# event is logged as a warning once the lib is up.
# ---------------------------------------------------------------------------

if (-not (Test-Path (Join-Path $repoPath ".git")) -and -not $Version) {
    Write-Host "aitools: repo not found at $repoPath -- cloning fresh..."
    $reposDir = Split-Path $repoPath -Parent
    if (-not (Test-Path $reposDir)) { New-Item -ItemType Directory -Path $reposDir -Force | Out-Null }
    git clone https://github.com/nobul-tech/aitools.git $repoPath
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("error: failed to clone the aitools repo to $repoPath")
        exit 1
    }
    $preLibWarnings += "Repo was not found at $repoPath -- cloned fresh"
}

# ---------------------------------------------------------------------------
# Load aitools-lib (logging, Write-Summary, ...) for every command.
# Without the repo nothing below can run; -Version still answers.
# ---------------------------------------------------------------------------

$aitoolsLib = Join-Path $repoPath "scripts" "aitools-lib.ps1"
if (-not (Test-Path $aitoolsLib)) {
    if ($Version) {
        Write-Host "aitools $AITOOLS_INSTALLED_VERSION"
        Write-Host "  repo: not found at $repoPath"
        exit 0
    }
    [Console]::Error.WriteLine("error: aitools-lib.ps1 not found at $aitoolsLib -- check repoPath in $configFile")
    exit 1
}
. $aitoolsLib
$aitoolsJson = Join-Path $repoPath "scripts" "aitools-json.ps1"
if (Test-Path $aitoolsJson) { . $aitoolsJson }
Initialize-Logging "aitools"
foreach ($note in $preLibNotes) { Log $note }
foreach ($w in $preLibWarnings) { LogWarn $w }

# Reject unknown commands (typos like "installs", "mcpp", etc.)
$knownCommands = @("install", "gitpull", "mcp", "user", "sessions", "dashboard", "")
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
# dashboard -- mission control dashboard lifecycle
# ---------------------------------------------------------------------------

if ($doDashboard) {
    # Dashboard is a standalone script that handles its own logging and summary.
    $dashboardScript = Join-Path $repoPath "scripts\aitools-dashboard.ps1"
    if (-not (Test-Path $dashboardScript)) {
        LogError "aitools-dashboard.ps1 not found at $dashboardScript"
        exit 1
    }
    # Forward all remaining args to the dashboard script
    $dashArgs = @()
    if ($Remaining) { $dashArgs = $Remaining }
    & $dashboardScript @dashArgs
    exit $LASTEXITCODE
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

# --- BEGIN user init ---
# ---------------------------------------------------------------------------
# aitools user init: this machine's profile (reference/user-repo.md
# "Registration"; re-key design S3-M3-Register-keydesign.md sections b, c, f, g;
# PR #86 batch 5). Machine profiles are keyed by this machine's id
# (profiles.<machine id, lower-cased>); the human-readable name is the profile's
# alias field. The native resolver (aitools-profile.ps1) decides which profile
# this machine is, writes only this machine's key (register, to a temp file that
# is validated, backed up and moved here) and re-keys alias-keyed revision 2.1
# profiles (migrate). Only profile.json is committed and pushed (N-Q2). Menus,
# prompts, summary rows and exit codes are identical in scripts/aitools
# (interactive-menus.md). Without a terminal, with -Force or AITOOLS_FORCE=1,
# nothing prompts: the default applies, or the step reports ERROR + ACTION.
# This block (BEGIN/END markers) holds every user-init function; the parity
# tests (tests/profile/test-user-init.sh) run it on macOS/Linux. Functions
# return only their declared value; console output uses [Console].
# ---------------------------------------------------------------------------

# Decision 2 (PENDING with the commander -- S3-M3Lead plan section 2 item 2; re-key
# design (b) step 4L): config.json's cached machineAlias names an alias-keyed
# profile without machine.id (resolver via=alias). $false = today's behaviour: ask
# on a terminal (that profile suggested), ERROR + ACTION without one. $true =
# claim that profile for this machine without asking. Flipping the decision is
# this one line (and AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY in scripts/aitools).
$script:RegisterCachedAliasSilently = $false

# Test-UiCanAsk -- $true when user init may prompt: a console, and neither -Force
# nor AITOOLS_FORCE=1 (interactive-menus.md "Non-interactive fallback")
function Test-UiCanAsk {
    if ($Force -or $env:AITOOLS_FORCE -eq "1") { return $false }
    return (Test-InteractiveConsole)
}

# machine.shell (Review3 #82 minor 6): one stable value per platform, so the two
# Windows entry points (Git Bash aitools and aitools.ps1) do not rewrite it on
# alternate runs. Windows: pwsh, the managed shell there; scripts/aitools records
# the login shell on macOS/Linux.
$script:UiMachineShell = "pwsh"

# Write-UiLogLines PREFIX TEXT -- each non-empty line of TEXT as a detail line
function Write-UiLogLines([string]$Prefix, [string]$Text) {
    foreach ($l in ($Text -split "`r?`n")) { if ($l) { LogDetail "$Prefix$l" } }
}

# Write-UiAction TEXT -- one ACTION row TEXT per run (Show-Summary does not dedupe
# ACTIONs). The caller's LogWarn / LogError line carries the same instruction.
function Write-UiAction([string]$Text) {
    if ($env:AITOOLS_SUMMARY_FILE -and (Test-Path -LiteralPath $env:AITOOLS_SUMMARY_FILE -PathType Leaf)) {
        $have = $false
        try {
            $have = @([IO.File]::ReadAllLines($env:AITOOLS_SUMMARY_FILE, [System.Text.UTF8Encoding]::new($false)) | Where-Object { $_ -ceq "ACTION||$Text" }).Count -gt 0
        } catch {
            LogDetail "run summary unreadable ($($_.Exception.Message)) -- ACTION written without the duplicate check"
        }
        if ($have) { LogDetail "ACTION already in the run summary: $Text"; return }
    }
    Write-Summary "ACTION" "" $Text
}

# Remove-UiTmp FILE -- remove a temp file; a failure is a warning, never silent
function Remove-UiTmp([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
        catch { LogWarn "could not remove $Path" }
    }
}

# Invoke-UiProfile ARGS -- run the resolver through the lib runner
# (Invoke-AitLibProfile in aitools-lib.ps1: aitools-profile.ps1, in-process) and
# copy its results right after the call (the lib's result-variable contract):
# $script:UiProfOut (key<TAB>value lines; for hostname the bare value) and
# $script:UiProfRc (0 ok, 1 nothing found, 2 error -- also no resolver, a throw,
# or an exit 0/1 without result lines -- 3 refused, 4 alias in use). The
# resolver's own log lines become detail lines. AITOOLS_PROFILE_PS1 overrides the
# resolver, as for every lib caller (register and migrate then write through it).
# Returns nothing.
function Invoke-UiProfile([string[]]$Arguments) {
    # $false = no resolver: AitLibProfileRc is then 2 with an "error" line naming
    # it, which every caller reads (UiProfRc, Get-UiLines): the result check
    $null = Invoke-AitLibProfile $Arguments
    $script:UiProfOut = @($script:AitLibProfileOut); $script:UiProfRc = $script:AitLibProfileRc
}

function Get-UiTag([string]$Key) {
    foreach ($l in $script:UiProfOut) {
        $kv = $l -split "`t", 2
        if ($kv.Count -eq 2 -and $kv[0] -ceq $Key) { return $kv[1] }
    }
    return ""
}
function Get-UiLines([string]$Kind) {
    return @($script:UiProfOut | ForEach-Object { $kv = $_ -split "`t", 2; if ($kv.Count -eq 2 -and $kv[0] -ceq $Kind) { $kv[1] } })
}
function Get-UiFirstError {
    $found = @(Get-UiLines "error" | Where-Object { $_ -match '\S' })
    if ($found.Count -gt 0) { return $found[0] }
    return ""
}

# Test-UiHandled MSG -- $true when MSG is a resolver warning or error that user
# init resolves itself (it registers, claims, re-keys or refreshes the profile);
# those are logged at info, every other one at its own level (the resolver's
# library-style contract -- re-key design (j) finding 1, Review3 #82 M2)
function Test-UiHandled([string]$Msg) {
    foreach ($p in @("*keyed by alias -- run: aitools-profile migrate*", "*has no machine.id -- run: aitools user init*",
            "*has no machine.id -- left as is*", "*matched by hostname only*", "*no profile matches this machine*",
            "*profile.json has no machine profiles*", "*was registered with hostname*")) {
        if ($Msg -clike $p) { return $true }
    }
    return $false
}

# Write-UiResolverWarnings -- log the last resolver call's warn lines (handled: info)
function Write-UiResolverWarnings {
    foreach ($w in (Get-UiLines "warn")) {
        if (-not $w) { continue }
        if (Test-UiHandled $w) { Log "machine profile: $w (user init handles this)" }
        else { LogWarn "machine profile: $w" }
    }
}

# Write-UiPushAction DIR -- the ACTION for a commit or push the resolver reported
# as failed (its warning, logged by Write-UiResolverWarnings, says why)
function Write-UiPushAction([string]$Dir) {
    if ((Get-UiTag "committed") -cne "true") { Write-UiAction "commit and push profile.json in $Dir" }
    elseif (@(Get-UiLines "warn" | Where-Object { $_ -like "*pull --rebase*" }).Count -gt 0) { Write-UiAction "git pull --rebase, then git push in $Dir" }
    else { Write-UiAction "run git push in $Dir" }
}

# Invoke-UiPush DIR -- push DIR. Without a console git may not prompt
# (GIT_TERMINAL_PROMPT=0; ssh BatchMode unless GIT_SSH_COMMAND is set). A push the
# remote rejected (it has newer commits) is told to pull --rebase first (Review3
# #82 minor 4). Returns $true pushed, $false not pushed (LogWarn + ACTION).
function Invoke-UiPush([string]$Dir) {
    $prevPrompt = $env:GIT_TERMINAL_PROMPT
    $prevSsh = $env:GIT_SSH_COMMAND
    $ask = Test-UiCanAsk
    try {
        if (-not $ask) {
            $env:GIT_TERMINAL_PROMPT = "0"
            if (-not $env:GIT_SSH_COMMAND) { $env:GIT_SSH_COMMAND = "ssh -o BatchMode=yes" }
        }
        $out = (& git -C $Dir push 2>&1 | Out-String)
        $rc = $LASTEXITCODE
    } finally {
        $env:GIT_TERMINAL_PROMPT = $prevPrompt
        $env:GIT_SSH_COMMAND = $prevSsh
    }
    Write-UiLogLines "git push: " $out
    if ($rc -eq 0) { return $true }
    if ($out -match 'rejected|non-fast-forward|fetch first') {
        LogWarn "dotprofile push rejected (exit $rc): the remote has newer commits -- run git pull --rebase, then git push in $Dir"
        Write-UiAction "git pull --rebase, then git push in $Dir"
    } else {
        LogWarn "dotprofile push failed (exit $rc) -- run git push in $Dir"
        Write-UiAction "run git push in $Dir"
    }
    return $false
}

# Invoke-UiCommit DIR MESSAGE FILE... -- commit only FILE... in DIR, then push
# (N-Q2). No git identity on this machine yet: commits as the profile's
# identity.git. Returns 0 committed and pushed, 1 commit failed, 2 committed but
# not pushed; each failure is a LogWarn + one ACTION.
function Invoke-UiCommit([string]$Dir, [string]$Message, [string[]]$Files) {
    $who = @()
    $curName = (& git -C $Dir config user.name 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $curName = "" }   # unset = exit 1
    $curMail = (& git -C $Dir config user.email 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $curMail = "" }   # unset = exit 1
    if ((-not $curName -or -not $curMail) -and (Test-Path -LiteralPath (Join-Path $Dir "profile.json"))) {
        $r = Read-JsonFile (Join-Path $Dir "profile.json")
        if ($r.State -eq "valid") {
            $gname = Get-JText $r.Value @("identity", "git", "name")
            $gmail = Get-JText $r.Value @("identity", "git", "email")
            if ($gname -and $gmail) { $who = @("-c", "user.name=$gname", "-c", "user.email=$gmail") }
        }
    }
    $out = (& git -C $Dir add -- @Files 2>&1 | Out-String)
    $rc = $LASTEXITCODE
    if ($rc -eq 0) {
        $out = (& git -C $Dir @who commit -m $Message -- @Files 2>&1 | Out-String)
        $rc = $LASTEXITCODE
    }
    Write-UiLogLines "git commit: " $out
    $fileList = $Files -join " "
    if ($rc -ne 0) {
        LogWarn "dotprofile commit failed (exit $rc) -- commit and push $fileList in $Dir by hand"
        Write-UiAction "commit and push $fileList in $Dir"
        return 1
    }
    if (-not (Invoke-UiPush $Dir)) { return 2 }
    LogOk "machine profile: $fileList committed and pushed ($Message)"
    return 0
}

# Test-UiProfileDirty DIR -- $true when DIR/profile.json is tracked and has
# uncommitted changes (Review3 #82 minor 5); $false when clean, untracked, or DIR
# is not a git repository
function Test-UiProfileDirty([string]$Dir) {
    $null = & git -C $Dir rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -ne 0) { return $false }   # not a repository: nothing is committed there
    $null = & git -C $Dir ls-files --error-unmatch -- profile.json 2>&1
    if ($LASTEXITCODE -ne 0) { return $false }   # untracked: no committed version to protect
    $null = & git -C $Dir diff --quiet -- profile.json 2>&1
    if ($LASTEXITCODE -ne 0) { return $true }
    $null = & git -C $Dir diff --cached --quiet -- profile.json 2>&1
    return ($LASTEXITCODE -ne 0)
}

# Get-UiEntries PF THIS_ID -- the profiles in PF, in file order: @{ Key; Alias
# (alias field, else the key); Owner (this | other | unregistered: whose profile it
# is, by machine.id / machine.environment -- the resolver's owner rule) }
function Get-UiEntries([string]$Pf, [string]$ThisId) {
    $list = @()
    $r = Read-JsonFile $Pf
    if ($r.State -ne "valid") { return @() }
    $tid = $ThisId.ToLowerInvariant()
    foreach ($k in (Get-JKeys $r.Value @("profiles"))) {
        if ((Get-JType $r.Value @("profiles", $k)) -cne "object") { continue }
        $al = Get-JText $r.Value @("profiles", $k, "alias")
        $mid = Get-JText $r.Value @("profiles", $k, "machine", "id")
        $menv = Get-JText $r.Value @("profiles", $k, "machine", "environment")
        $kl = $k.ToLowerInvariant()
        if ($kl.StartsWith("environment:")) {
            $owner = if ($kl -ceq "environment:$($script:AitoolsEnvironment)") { "this" } else { "other" }
        } elseif ($menv) {
            $owner = if ($menv -ceq $script:AitoolsEnvironment) { "this" } else { "other" }
        } elseif (-not $mid) {
            $owner = if ($tid -and $kl -ceq $tid) { "this" } else { "unregistered" }
        } elseif (-not $tid) {
            $owner = "unknown"   # this machine's id is unknown (review n4)
        } elseif ($mid.ToLowerInvariant() -ceq $tid) {
            $owner = "this"
        } else {
            $owner = "other"
        }
        $shown = if ($al) { $al } else { $k }
        $list += @{ Key = $k; Alias = $shown; Owner = $owner }
    }
    return $list
}

# Read-UiChoose PF SUGGESTED_KEY THIS_ID -- ask which profile this machine is
# (parity: ui_choose). Sets $script:UiChoiceKind (claim | new) and
# $script:UiChoice. Returns 0 chosen; 1 no console to ask (LogError + ERROR row +
# ACTION); 2 skipped at the prompt (LogWarn; the caller writes the row).
function Read-UiChoose([string]$Pf, [string]$Suggested, [string]$ThisId) {
    $script:UiChoiceKind = ""; $script:UiChoice = ""
    if (-not (Test-UiCanAsk)) {
        LogError "machine profile: this machine has no profile and there is no terminal to ask -- run: aitools user init --alias <name> (or aitools user init on a terminal)"
        Write-Summary "ERROR" "machine profile" "not registered (no terminal)"
        Write-UiAction "Run: aitools user init --alias <name> (or on a terminal)"
        return 1
    }
    $entries = @(Get-UiEntries $Pf $ThisId)
    $nums = @()
    [Console]::WriteLine("Which profile is this machine?")
    foreach ($en in $entries) {
        $label = $en.Alias
        if ($en.Owner -ceq "unregistered") {
            $nums += $en.Key
            if ($en.Key -ceq $Suggested) { $label = "$label (suggested)" }
            [Console]::WriteLine("  [$($nums.Count)] $label")
        } elseif ($en.Owner -ceq "other") {
            if ($en.Key -ceq $Suggested) { $label = "$label (suggested, registered to another machine)" }
            else { $label = "$label (registered to another machine)" }
            [Console]::WriteLine("  [-] $label")
        } elseif ($en.Owner -ceq "unknown") {
            [Console]::WriteLine("  [-] $label (owner unknown: this machine's id cannot be detected)")
        }
    }
    [Console]::WriteLine("  [n] new profile for this machine")
    [Console]::WriteLine("  [s] skip")
    [Console]::Write("Choice: ")
    $choice = Read-ConsoleChoice "skip"
    if (-not $choice -or $choice -match '^[sS]$') {
        LogWarn "machine profile: registration skipped -- deploys will report no machine match"
        return 2
    }
    if ($choice -match '^[nN]$') {
        [Console]::Write("New alias (e.g., laptop, workstation): ")
        $script:UiChoice = Read-ConsoleChoice "skip"
        if (-not $script:UiChoice) {
            LogWarn "machine profile: no alias entered -- registration skipped"
            return 2
        }
        $script:UiChoiceKind = "new"
        return 0
    }
    if ($choice -match '^[0-9]+$' -and [int]$choice -ge 1 -and [int]$choice -le $nums.Count) {
        $script:UiChoice = $nums[[int]$choice - 1]; $script:UiChoiceKind = "claim"
        return 0
    }
    LogWarn "machine profile: invalid choice '$choice' -- registration skipped"
    return 2
}

# Read-UiNameCompany ALIAS -- on a console, a new profile's display name and
# company (Enter = the identity's). Sets $script:UiName, $script:UiCompany.
function Read-UiNameCompany([string]$AliasName) {
    $script:UiName = ""; $script:UiCompany = ""
    if (-not (Test-UiCanAsk)) { return }
    [Console]::Write("Display name for $AliasName (Enter = identity name): ")
    $script:UiName = Read-ConsoleChoice "identity name"
    [Console]::Write("Company for $AliasName (Enter = identity company): ")
    $script:UiCompany = Read-ConsoleChoice "identity company"
}

# Invoke-UiRegister DIR MODE VALUE COMMIT [NAME COMPANY EMAIL] -- register this
# machine (parity: ui_register; see there for MODE and the exit-4 rules). Sets
# $script:UiKey, UiAlias, UiOwner. Writes the "machine profile" row. Returns 0
# registered or verified, 1 failed (LogError + ERROR row), 2 skipped at the
# confirm (LogWarn + WARN row).
function Invoke-UiRegister([string]$Dir, [string]$Mode, [string]$Value, [bool]$Commit, [string]$Name = "", [string]$Company = "", [string]$Email = "") {
    $pf = Join-Path $Dir "profile.json"
    $tmp = "$pf.tmp.$PID"
    $extra = @()
    if ($Mode -ceq "claim") { $extra = @("--claim", $Value) }
    elseif ($Value) { $extra = @("--alias", $Value) }
    $tries = 0
    while ($true) {
        $tries++
        $regArgs = @("register", "--profile", $pf, "--out", $tmp, "--shell", $script:UiMachineShell, "--environment", $script:AitoolsEnvironment)
        if ($Name) { $regArgs += @("--name", $Name) }
        if ($Company) { $regArgs += @("--company", $Company) }
        if (-not (Test-Path -LiteralPath $pf)) { $regArgs += @("--create", "--github-user", $script:UiGhUser, "--email", $Email) }
        $null = Invoke-UiProfile ($regArgs + $extra)
        $rc = $script:UiProfRc
        Write-UiResolverWarnings
        if ($rc -ne 4 -or $Mode -ceq "claim" -or $tries -ge 3) { break }
        Remove-UiTmp $tmp
        $owner = Get-UiTag "owner"; $okey = Get-UiTag "ownerKey"
        if ($owner -ceq "unregistered" -and $okey) {
            Log "machine profile: alias `"$Value`" names profile $okey, which belongs to no machine -- claiming it for this machine"
            $extra += @("--claim", $okey); $Mode = "claim"
            continue
        }
        if (-not (Test-UiCanAsk)) {
            LogError "machine profile: alias `"$Value`" is used by another machine's profile ($okey) -- not registered without a confirm on a terminal; run: aitools user init --alias <another name>"
            Write-Summary "ERROR" "machine profile" "alias used by another machine"
            Write-UiAction "Run: aitools user init --alias <another name> (or confirm on a terminal)"
            return 1
        }
        [Console]::Write("Alias `"$Value`" is used by another machine's profile ($okey). Use it for this machine too? [y/N]: ")
        $ans = Read-ConsoleChoice "no"
        if ($ans -match '^[yY]') {
            Log "machine profile: alias `"$Value`" shared with profile $okey (confirmed at the prompt)"
            $extra += @("--allow-duplicate-alias")
            continue
        }
        LogWarn "machine profile: alias `"$Value`" is used by another machine's profile ($okey) -- registration skipped"
        Write-Summary "WARN" "machine profile" "skipped"
        return 2
    }
    if ($rc -ne 0) {
        Remove-UiTmp $tmp
        $errText = Get-UiFirstError
        if (-not $errText) { $errText = "see deploy.log" }
        if ($rc -eq 3 -or $rc -eq 4) {
            LogError "machine profile: registration refused (resolver exit $rc): $errText"
            Write-Summary "ERROR" "machine profile" "registration refused"
        } else {
            LogError "machine profile: register failed (resolver exit $rc): $errText"
            Write-Summary "ERROR" "machine profile" "register failed"
        }
        Write-UiAction "see deploy.log -- fix profile.json, then run: aitools user init"
        return 1
    }
    $result = Get-UiTag "result"
    $script:UiKey = Get-UiTag "key"; $script:UiAlias = Get-UiTag "alias"; $script:UiOwner = Get-UiTag "owner"
    $claimed = Get-UiTag "claimed"
    if ($result -ceq "unchanged") {
        Remove-UiTmp $tmp
        LogOk "machine profile: this machine is '$($script:UiAlias)' (profile $($script:UiKey), verified)"
        Write-Summary "OK" "machine profile" "verified ($($script:UiAlias))"
        return 0
    }
    $check = Read-JsonFile $tmp
    if ($check.State -ne "valid") {
        Remove-UiTmp $tmp
        LogError "machine profile: register wrote an invalid file ($($check.Message)) -- profile.json left untouched"
        Write-Summary "ERROR" "machine profile" "register validation failed"
        return 1
    }
    Backup-File $pf
    try {
        Move-Item -LiteralPath $tmp -Destination $pf -Force -ErrorAction Stop
    } catch {
        Remove-UiTmp $tmp
        LogError "machine profile: could not replace $pf"
        Write-Summary "ERROR" "machine profile" "write failed"
        return 1
    }
    $from = if ($claimed) { ", claimed from $claimed" } else { "" }
    LogOk "machine profile: registered this machine as '$($script:UiAlias)' ($result, profile $($script:UiKey)$from)"
    if ($Commit -and (Test-Path -LiteralPath (Join-Path $Dir ".git"))) {
        $null = Invoke-UiCommit $Dir "Register machine profile: $($script:UiAlias)" @("profile.json")   # failures: LogWarn + ACTION inside
    }
    Write-Summary "OK" "machine profile" "$result ($($script:UiAlias))"
    return 0
}

# Invoke-UiMigrate DIR -- re-key alias-keyed (revision 2.1) profiles by machine id
# (parity: ui_migrate). Row "profile keys". Returns 0, 1 failed.
function Invoke-UiMigrate([string]$Dir) {
    $null = Invoke-UiProfile @("migrate", "--profile", (Join-Path $Dir "profile.json"))
    $rc = $script:UiProfRc
    Write-UiResolverWarnings
    if ($rc -ne 0) {
        $errs = @(Get-UiLines "error" | Where-Object { $_ })
        foreach ($e1 in $errs) { LogError "machine profile: re-key failed: $e1" }
        if ($errs.Count -eq 0) { LogError "machine profile: re-key failed (resolver exit $rc)" }
        Write-Summary "ERROR" "profile keys" "re-key failed"
        Write-UiAction "see deploy.log -- fix profile.json, then run: aitools user init"
        return 1
    }
    if ((Get-UiTag "result") -ceq "migrated") {
        LogOk "machine profile: profiles re-keyed by machine id: $(Get-UiTag 'renamed')"
        if ((Get-UiTag "pushed") -cne "true") { Write-UiPushAction $Dir }
        Write-Summary "OK" "profile keys" "re-keyed by machine id"
    } else {
        LogDetail "machine profile: re-key: $(Get-UiTag 'result') (every profile is keyed by machine id)"
    }
    return 0
}

# Invoke-UiResolve DIR -- which profile this machine is (parity: ui_resolve; no
# override is passed: -Alias goes to register, Review3 #82 M1). Sets
# $script:UiVia, UiKey, UiAlias, UiOwner, UiThisId. Returns 0, or 1 on a resolver
# error user init cannot resolve (LogError + ERROR row + ACTION).
function Invoke-UiResolve([string]$Dir) {
    $null = Invoke-UiProfile @("resolve", "--profile", (Join-Path $Dir "profile.json"), "--environment", $script:AitoolsEnvironment)
    $script:UiVia = Get-UiTag "via"; $script:UiKey = Get-UiTag "key"; $script:UiAlias = Get-UiTag "alias"
    $script:UiOwner = Get-UiTag "owner"; $script:UiThisId = Get-UiTag "machineId"
    if (-not $script:UiKey) { $script:UiVia = "none" }
    Write-UiResolverWarnings
    $aShown = if ($script:UiAlias) { $script:UiAlias } else { "none" }
    $kShown = if ($script:UiKey) { $script:UiKey } else { "none" }
    $oShown = if ($script:UiOwner) { $script:UiOwner } else { "absent" }
    Log "machine profile: alias=$aShown via=$($script:UiVia) key=$kShown owner=$oShown"
    if ($script:UiProfRc -eq 0) { return 0 }
    $real = $false
    foreach ($e1 in (Get-UiLines "error")) {
        if (-not $e1) { continue }
        if (Test-UiHandled $e1) { Log "machine profile: $e1 (user init handles this)" }
        else { LogError "machine profile: $e1"; $real = $true }
    }
    if (-not (Get-UiFirstError)) { LogError "machine profile: resolver failed (exit $($script:UiProfRc))"; $real = $true }
    if (-not $real) { return 0 }
    Write-Summary "ERROR" "machine profile" "resolver error"
    Write-UiAction "see deploy.log -- fix profile.json, then run: aitools user init"
    return 1
}

# Read-UiIdentity DIR -- identity for a new profile.json (parity: ui_identity).
# Sets $script:UiIdName, UiIdEmail, UiIdCompany.
function Read-UiIdentity([string]$Dir) {
    $script:UiIdName = ""; $script:UiIdEmail = ""; $script:UiIdCompany = ""
    if (Test-Path -LiteralPath $Dir) {
        $v = (& git -C $Dir config user.name 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) { $script:UiIdName = $v }   # unset (exit 1): the fallback below
        $v = (& git -C $Dir config user.email 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) { $script:UiIdEmail = $v }   # unset: asked below, else empty
    }
    if (-not $script:UiIdName) { $script:UiIdName = [Environment]::UserName }
    if (-not (Test-UiCanAsk)) { return }
    [Console]::Write("Display name [$($script:UiIdName)]: ")
    $v = Read-ConsoleChoice $script:UiIdName
    if ($v) { $script:UiIdName = $v }
    [Console]::Write("Email [$($script:UiIdEmail)]: ")
    $dflt = if ($script:UiIdEmail) { $script:UiIdEmail } else { "none" }
    $v = Read-ConsoleChoice $dflt
    if ($v) { $script:UiIdEmail = $v }
    [Console]::Write("Company: ")
    $script:UiIdCompany = Read-ConsoleChoice "none"
}

# Invoke-UiScaffold DIR COMMIT -- decision 6: DIR has no profile.json (parity:
# ui_scaffold). Returns Invoke-UiRegister's code.
# TODO(PR #96): profile.json meta.intent is protected text pending approval -- the
# scaffold writes no meta.intent until it is approved (S3-M3Lead, 2026-10-22).
function Invoke-UiScaffold([string]$Dir, [bool]$Commit) {
    Log "machine profile: no profile.json in $Dir -- creating it (identity + this machine's profile)"
    Read-UiIdentity $Dir
    $aliasName = $script:UserAlias
    if (-not $aliasName -and (Test-UiCanAsk)) {
        [Console]::Write("Alias for this machine (Enter = hostname): ")
        $aliasName = Read-ConsoleChoice "the hostname"
    }
    return (Invoke-UiRegister $Dir "alias" $aliasName $Commit $script:UiIdName $script:UiIdCompany $script:UiIdEmail)
}

# Invoke-UiRegisterFlow DIR COMMIT -- register this machine in DIR (parity:
# ui_register_flow). Sets $script:UiMachineKey, UiMachineAlias, UiMachineOwner
# ("" when not registered). Returns 0 registered, verified or skipped by the user
# (WARN row), 1 not registered (ERROR row).
function Invoke-UiRegisterFlow([string]$Dir, [bool]$Commit) {
    $script:UiMachineKey = ""; $script:UiMachineAlias = ""; $script:UiMachineOwner = ""
    $want = $script:UserAlias
    $rc = 0; $sug = ""
    if (-not (Test-Path -LiteralPath (Join-Path $Dir "profile.json"))) {
        $rc = Invoke-UiScaffold $Dir $Commit
    } elseif (Test-UiProfileDirty $Dir) {
        if ((Invoke-UiResolve $Dir) -ne 0) { return 1 }
        if ($script:UiOwner -ceq "this" -and ($script:UiVia -ceq "id" -or $script:UiVia -ceq "environment")) {
            $script:UiMachineKey = $script:UiKey; $script:UiMachineAlias = $script:UiAlias; $script:UiMachineOwner = "this"
            LogWarn "machine profile: profile.json in $Dir has uncommitted changes -- this machine's profile ('$($script:UiAlias)') was not refreshed; commit or discard them, then run: aitools user init"
            Write-Summary "WARN" "machine profile" "not refreshed (local edits)"
            Write-UiAction "commit or discard the changes to profile.json in $Dir, then run: aitools user init"
            return 0
        }
        LogError "machine profile: profile.json in $Dir has uncommitted changes -- not registered (they would be committed with it); commit or discard them, then run: aitools user init"
        Write-Summary "ERROR" "machine profile" "not registered (local edits)"
        Write-UiAction "commit or discard the changes to profile.json in $Dir, then run: aitools user init"
        return 1
    } else {
        $null = Invoke-UiMigrate $Dir   # failure: logged + ERROR row; resolution still reads legacy profiles
        if ((Invoke-UiResolve $Dir) -ne 0) { return 1 }
        # AITOOLS_MACHINE_ALIAS naming an existing profile (resolver via=override) is used as
        # -Alias would be; an unknown one is a resolver error (design (b) step 1). With
        # -Alias it is ignored (Invoke-UserInit clears it).
        if (-not $want -and $script:UiVia -ceq "override") { $want = $script:UiAlias }
        if ($want) {
            if ($script:UiOwner -cne "this") { Read-UiNameCompany $want } else { $script:UiName = ""; $script:UiCompany = "" }
            $rc = Invoke-UiRegister $Dir "alias" $want $Commit $script:UiName $script:UiCompany ""
        } else {
            switch -CaseSensitive ($script:UiVia) {
                { $_ -ceq "id" -or $_ -ceq "environment" } {
                    # Refresh the machine facts (hostname, os, arch, shell) of this machine's profile
                    $rc = Invoke-UiRegister $Dir "refresh" "" $Commit
                    break
                }
                "config" {
                    # This machine's id cannot be detected: config.json's cached key vouches for
                    # the profile, but register needs the id (it would refuse with exit 3)
                    LogWarn "machine profile: this machine's id cannot be detected -- profile '$($script:UiAlias)' (from config.json machineId) was not refreshed"
                    Write-Summary "WARN" "machine profile" "not refreshed (no machine id)"
                    # owner "config": the key is NOT passed to setup-user-config, which re-derives it
                    # (via=config) and keeps the cached machineId (review M2)
                    $script:UiMachineKey = $script:UiKey; $script:UiMachineAlias = $script:UiAlias; $script:UiMachineOwner = "config"
                    return 0
                }
                "alias" {
                    if ($script:RegisterCachedAliasSilently) {
                        Log "machine profile: config.json names profile '$($script:UiKey)' (no machine.id) -- claiming it for this machine (decision 2)"
                        $rc = Invoke-UiRegister $Dir "claim" $script:UiKey $Commit
                    } else {
                        $sug = $script:UiKey; $rc = 100
                    }
                    break
                }
                "hostname" { $sug = $script:UiKey; $rc = 100; break }
                default { $rc = 100 }
            }
            if ($rc -eq 100) {
                $rc = Read-UiChoose (Join-Path $Dir "profile.json") $sug $script:UiThisId
                if ($rc -eq 0) {
                    if ($script:UiChoiceKind -ceq "claim") {
                        $rc = Invoke-UiRegister $Dir "claim" $script:UiChoice $Commit
                    } else {
                        Read-UiNameCompany $script:UiChoice
                        $rc = Invoke-UiRegister $Dir "alias" $script:UiChoice $Commit $script:UiName $script:UiCompany ""
                    }
                } elseif ($rc -eq 2) {
                    Write-Summary "WARN" "machine profile" "skipped"
                }
            }
        }
    }
    if ($rc -eq 0) {
        $script:UiMachineKey = $script:UiKey; $script:UiMachineAlias = $script:UiAlias; $script:UiMachineOwner = $script:UiOwner
        return 0
    }
    if ($rc -eq 2) { return 0 }
    return 1
}

# Invoke-UiV1Migrate DIR -- DIR/profile.json is v1: convert it to v2 revision 2.2
# and register this machine under its id (parity: migrate_profile_v1_to_v2).
# Returns 0 (also when nothing to do), 1 failed.
function Invoke-UiV1Migrate([string]$Dir) {
    $pf = Join-Path $Dir "profile.json"
    if (-not (Test-Path -LiteralPath $pf)) { return 0 }
    $r = Read-JsonFile $pf
    if ($r.State -eq "valid" -and (Get-JText $r.Value @("version")) -ceq "2") { return 0 }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        LogWarn "profile.json in $Dir is v1 (legacy) -- node is needed to migrate it; install node, then run: aitools user init"
        Write-Summary "WARN" "machine profile" "v1 profile not migrated"
        return 0
    }
    if (Test-UiProfileDirty $Dir) {
        LogWarn "profile.json in $Dir is v1 and has uncommitted changes -- not migrated; commit or discard them, then run: aitools user init"
        Write-Summary "WARN" "machine profile" "v1 profile not migrated"
        Write-UiAction "commit or discard the changes to profile.json in $Dir, then run: aitools user init"
        return 0
    }
    Log "profile.json in $Dir is v1 (legacy) -- migrating to v2 (profiles keyed by machine id)"
    $null = Invoke-UiProfile @("hostname")
    $hostName = if ($script:UiProfRc -eq 0 -and $script:UiProfOut.Count -gt 0) { $script:UiProfOut[0] } else { "" }
    $tmp = "$pf.tmp.$PID"
    $js = @'
const fs = require("fs");
const [src, dst, host] = process.argv.slice(1);
const old = JSON.parse(fs.readFileSync(src, "utf8").replace(/^﻿/, ""));
const name = (old.git && old.git.name) || old.name || "";
const email = (old.git && old.git.email) || old.email || "";
const v2 = { version: 2, meta: { schemaRevision: "2.2" },
    identity: { github: old.github || "", email: email, name: name, company: old.company || "", git: { name: name, email: email } },
    profiles: {} };
// The other v1 machines: profiles that belong to no machine yet (claimable)
if (Array.isArray(old.machines)) {
    let n = 1;
    for (const m of old.machines) {
        const h = String((m && m.hostname) || "").split(".")[0].toLowerCase();
        if (host && h === host) continue;
        while (v2.profiles["machine" + n]) n++;
        v2.profiles["machine" + n] = { machine: m };
    }
}
// Non-v1 sections (e.g. cursor) are kept
const v1Keys = ["name", "email", "github", "company", "git", "machines", "version"];
for (const k of Object.keys(old)) { if (!v1Keys.includes(k) && !(k in v2)) v2[k] = old[k]; }
fs.writeFileSync(dst, JSON.stringify(v2, null, 2) + "\n");
'@
    $out = (& node -e $js $pf $tmp $hostName 2>&1 | Out-String)
    $nodeRc = $LASTEXITCODE
    if ($nodeRc -ne 0 -or (Read-JsonFile $tmp).State -ne "valid") {
        Write-UiLogLines "v1 migration: " $out
        Remove-UiTmp $tmp
        LogError "profile.json in $Dir could not be migrated from v1 (see deploy.log) -- left untouched"
        Write-Summary "ERROR" "machine profile" "v1 migration failed"
        return 1
    }
    Backup-File $pf
    try {
        Move-Item -LiteralPath $tmp -Destination $pf -Force -ErrorAction Stop
    } catch {
        Remove-UiTmp $tmp
        LogError "profile.json in $Dir could not be replaced -- v1 migration not written"
        Write-Summary "ERROR" "machine profile" "v1 migration failed"
        return 1
    }
    LogOk "profile.json in $Dir migrated to v2"
    $aliasName = $script:UserAlias
    if (-not $aliasName -and (Test-UiCanAsk)) {
        [Console]::Write("Alias for this machine (Enter = hostname): ")
        $aliasName = Read-ConsoleChoice "the hostname"
    }
    $reg = Invoke-UiRegister $Dir "alias" $aliasName $false   # failure or skip: logged + row inside; the migration is committed either way
    if (Test-Path -LiteralPath (Join-Path $Dir ".git")) { $null = Invoke-UiCommit $Dir "Migrate profile.json from v1 to v2" @("profile.json") }
    if ($reg -eq 1) { return 1 }
    return 0
}

# Invoke-UiCreateDotprofile DIR -- Path 3: a new local dotprofile, committed, then
# a private GitHub repo created and pushed (parity: ui_create_dotprofile). Writes
# the "dotprofile" row. Returns 0, 1 failed (ERROR row).
function Invoke-UiCreateDotprofile([string]$Dir) {
    Log "user init: creating the dotprofile $Dir"
    try {
        $null = New-Item -ItemType Directory -Path (Join-Path $Dir "sessions") -Force -ErrorAction Stop
    } catch {
        LogError "user init: could not create $Dir"
        Write-Summary "ERROR" "dotprofile" "create failed"
        return 1
    }
    $reg = 0
    if ((Invoke-UiRegisterFlow $Dir $false) -ne 0) { $reg = 1 }   # failure: logged + ERROR row inside; the repo is still created
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    try {
        [IO.File]::WriteAllText((Join-Path $Dir ".gitattributes"), "* text=auto eol=lf`n*.jsonl text eol=lf`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $Dir ".gitignore"), ".scratch/`n*.bak.*`n.DS_Store`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $Dir "README.md"), "# $($script:UiRepoName)`n`nPrivate user repo for session archives and profile data.`nSee [aitools](https://github.com/$($script:UiGhUser)/aitools) for details.`n", $utf8)
    } catch {
        LogError "user init: could not write the dotprofile files in $Dir"
        Write-Summary "ERROR" "dotprofile" "create failed"
        return 1
    }
    $out = (& git -C $Dir init -b main 2>&1 | Out-String); $grc = $LASTEXITCODE
    if ($grc -eq 0 -and $script:UiIdName) { $out = (& git -C $Dir config user.name $script:UiIdName 2>&1 | Out-String); $grc = $LASTEXITCODE }
    if ($grc -eq 0 -and $script:UiIdEmail) { $out = (& git -C $Dir config user.email $script:UiIdEmail 2>&1 | Out-String); $grc = $LASTEXITCODE }
    if ($grc -eq 0) { $out = (& git -C $Dir add -A 2>&1 | Out-String); $grc = $LASTEXITCODE }
    if ($grc -eq 0) { $out = (& git -C $Dir commit -m "Initial commit: profile and session archive structure" 2>&1 | Out-String); $grc = $LASTEXITCODE }
    Write-UiLogLines "git: " $out
    if ($grc -ne 0) {
        LogError "user init: git init / first commit failed in $Dir (exit $grc, see deploy.log) -- commit it by hand, then run: aitools user init"
        Write-Summary "ERROR" "dotprofile" "first commit failed"
        Write-UiAction "commit the dotprofile in $Dir, then run: aitools user init"
        return 1
    }
    LogOk "user init: dotprofile created and committed"
    $create = "Run: gh repo create $($script:UiRepoName) --private --source $Dir --push"
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        LogWarn "user init: gh not found -- the dotprofile was not pushed; create the private GitHub repo $($script:UiRepoName) and push it"
        Write-Summary "WARN" "dotprofile" "created, not pushed"
        Write-UiAction $create
        return $reg
    }
    $ans = "y"
    if (Test-UiCanAsk) {
        [Console]::Write("Create the private GitHub repo '$($script:UiRepoName)' and push? [Y/n]: ")
        $ans = Read-ConsoleChoice "yes"
        if (-not $ans) { $ans = "y" }
    }
    if ($ans -notmatch '^[yY]') {
        LogWarn "user init: GitHub repo not created -- the dotprofile stays local; create it and push: gh repo create $($script:UiRepoName) --private --source $Dir --push"
        Write-Summary "WARN" "dotprofile" "created, not pushed"
        Write-UiAction $create
        return $reg
    }
    $prevPrompt = $env:GIT_TERMINAL_PROMPT; $prevSsh = $env:GIT_SSH_COMMAND
    $ask = Test-UiCanAsk
    try {
        if (-not $ask) {
            $env:GIT_TERMINAL_PROMPT = "0"
            if (-not $env:GIT_SSH_COMMAND) { $env:GIT_SSH_COMMAND = "ssh -o BatchMode=yes" }
        }
        $out = (& gh repo create $script:UiRepoName --private --source $Dir --push 2>&1 | Out-String)
        $grc = $LASTEXITCODE
    } finally {
        $env:GIT_TERMINAL_PROMPT = $prevPrompt; $env:GIT_SSH_COMMAND = $prevSsh
    }
    Write-UiLogLines "gh repo create: " $out
    if ($grc -ne 0) {
        LogWarn "user init: gh repo create failed (exit $grc, see deploy.log) -- the dotprofile stays local; run: gh repo create $($script:UiRepoName) --private --source $Dir --push"
        Write-Summary "WARN" "dotprofile" "created, not pushed"
        Write-UiAction $create
        return $reg
    }
    LogOk "user init: private GitHub repo $($script:UiGhUser)/$($script:UiRepoName) created and pushed"
    Write-Summary "OK" "dotprofile" "created"
    return $reg
}

# Invoke-UiScaffoldClaudeMd DIR -- the dotprofile's claude/CLAUDE.md from the
# shared template when it is missing, committed (only that file) and pushed
# (parity: ui_scaffold_claude_md). Returns 0, 1 failed.
function Invoke-UiScaffoldClaudeMd([string]$Dir) {
    $dest = Join-Path $Dir "claude" "CLAUDE.md"
    $src = Join-Path $repoPath "shared" "claude-shared.md"
    if (Test-Path -LiteralPath $dest) { return 0 }
    if (-not (Test-Path -LiteralPath $src)) {
        LogWarn "user init: $src not found -- claude/CLAUDE.md not created in the dotprofile"
        Write-Summary "WARN" "claude template" "template missing"
        return 0
    }
    try {
        $null = New-Item -ItemType Directory -Path (Join-Path $Dir "claude") -Force -ErrorAction Stop
        Copy-Item -LiteralPath $src -Destination $dest -ErrorAction Stop
    } catch {
        LogError "user init: could not create $dest"
        Write-Summary "ERROR" "claude template" "create failed"
        return 1
    }
    LogOk "user init: created claude/CLAUDE.md in the dotprofile (template with placeholders)"
    if (Test-Path -LiteralPath (Join-Path $Dir ".git")) { $null = Invoke-UiCommit $Dir "Add claude/CLAUDE.md template" @("claude/CLAUDE.md") }
    Write-Summary "OK" "claude template" "created"
    return 0
}

# Invoke-UserInit -- `aitools user init` (parity: user_init in scripts/aitools).
# Returns 0 done (warnings possible), 1 any failure, 2 user abort in a review
# menu (D-TS13).
function Invoke-UserInit {
    $rc = 0
    $script:UiGhUser = ""; $script:UiRepoName = ""
    $script:UiMachineKey = ""; $script:UiMachineAlias = ""; $script:UiMachineOwner = ""
    # -Force: no prompts here, and the review menus of setup-user-hooks take the source
    if ($Force) { $env:AITOOLS_FORCE = "1" }

    # GitHub user: gh, else config.json githubUser, else asked on a console
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $v = (& gh api user --jq '.login' 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) { $script:UiGhUser = $v }   # not signed in: the fallbacks below
    }
    if (-not $script:UiGhUser) {
        $v = ReadConfigKey -File $configFile -Key "githubUser"
        if ($v) { $script:UiGhUser = [string]$v }
    }
    if (-not $script:UiGhUser -and (Test-UiCanAsk)) {
        [Console]::Write("GitHub username: ")
        $script:UiGhUser = Read-ConsoleChoice "none"
    }
    if (-not $script:UiGhUser) {
        LogError "user init: GitHub username unknown (gh not signed in, no githubUser in config.json, no terminal to ask) -- run: gh auth login, then aitools user init"
        Write-Summary "ERROR" "dotprofile" "GitHub user unknown"
        Write-UiAction "Run: gh auth login, then aitools user init"
        return 1
    }
    Log "user init: GitHub user $($script:UiGhUser)"
    $script:UiRepoName = "aitools-$($script:UiGhUser)"

    # Repos directory from config.json (a leading ~ is the home directory)
    $reposDir = [string](ReadConfigKey -File $configFile -Key "reposPath")
    if ($reposDir -ceq "~") { $reposDir = $HOME }
    elseif ($reposDir.StartsWith("~/") -or $reposDir.StartsWith("~\")) { $reposDir = Join-Path $HOME $reposDir.Substring(2) }
    if (-not $reposDir) { $reposDir = Join-Path $HOME "repos" }
    # A relative reposPath would put the dotprofile (and its GitHub repo) under the
    # current directory, and setup-user-config refuses it anyway (review M1): refused
    if (-not [IO.Path]::IsPathRooted($reposDir)) {
        LogError "user init: reposPath in $configFile is not an absolute path ($reposDir) -- set an absolute reposPath (or run: aitools install --repos-path <absolute path>), then run: aitools user init"
        Write-Summary "ERROR" "dotprofile" "reposPath not absolute"
        Write-UiAction "Set an absolute reposPath in $configFile, then run: aitools user init"
        return 1
    }
    $userRepoDir = Join-Path $reposDir $script:UiRepoName
    # -Alias wins over a (possibly stale) AITOOLS_MACHINE_ALIAS, for the resolver and
    # the writer alike (review m3)
    if ($script:UserAlias -and $env:AITOOLS_MACHINE_ALIAS) {
        Log "user init: AITOOLS_MACHINE_ALIAS=$($env:AITOOLS_MACHINE_ALIAS) ignored (--alias $($script:UserAlias) given)"
        Remove-Item Env:\AITOOLS_MACHINE_ALIAS -ErrorAction SilentlyContinue
        if ($env:AITOOLS_MACHINE_ALIAS) { LogWarn "user init: AITOOLS_MACHINE_ALIAS could not be cleared" }
    }

    if (Test-Path -LiteralPath (Join-Path $userRepoDir ".git")) {
        # --- Path 1: local dotprofile present ---
        Log "user init: dotprofile $userRepoDir (present)"
        Write-Summary "OK" "dotprofile" "verified"
        if ((Invoke-UiV1Migrate $userRepoDir) -ne 0) { $rc = 1 }
        if ((Invoke-UiRegisterFlow $userRepoDir $true) -ne 0) { $rc = 1 }
    } else {
        $ghRepo = $false
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            $null = & gh repo view "$($script:UiGhUser)/$($script:UiRepoName)" --json name 2>&1
            $ghRepo = ($LASTEXITCODE -eq 0)   # non-zero: no such repo (or gh not signed in)
        }
        if ($ghRepo) {
            # --- Path 2: GitHub repo present, no local clone ---
            Log "user init: cloning $($script:UiGhUser)/$($script:UiRepoName) to $userRepoDir"
            $out = (& gh repo clone "$($script:UiGhUser)/$($script:UiRepoName)" $userRepoDir 2>&1 | Out-String)
            $crc = $LASTEXITCODE
            Write-UiLogLines "gh repo clone: " $out
            if ($crc -ne 0) {
                LogError "user init: gh repo clone $($script:UiGhUser)/$($script:UiRepoName) failed (exit $crc, see deploy.log) -- clone it, then run: aitools user init"
                Write-Summary "ERROR" "dotprofile" "clone failed"
                Write-UiAction "Run: gh repo clone $($script:UiGhUser)/$($script:UiRepoName) $userRepoDir, then aitools user init"
                return 1
            }
            Write-Summary "OK" "dotprofile" "cloned"
            # Git identity for this clone from the profile (Review3 #82 minor 8: results checked)
            $pr = Read-JsonFile (Join-Path $userRepoDir "profile.json")
            if ($pr.State -eq "valid") {
                $dn = Get-JText $pr.Value @("identity", "git", "name")
                $de = Get-JText $pr.Value @("identity", "git", "email")
                if ($dn -and $de) {
                    $out = (& git -C $userRepoDir config user.name $dn 2>&1 | Out-String); $crc = $LASTEXITCODE
                    if ($crc -eq 0) { $out = (& git -C $userRepoDir config user.email $de 2>&1 | Out-String); $crc = $LASTEXITCODE }
                    if ($crc -ne 0) { LogWarn "user init: could not set the git identity of the clone (exit ${crc}: $($out.Trim())) -- commits use git's own identity" }
                }
            }
            if ((Invoke-UiV1Migrate $userRepoDir) -ne 0) { $rc = 1 }
            if ((Invoke-UiRegisterFlow $userRepoDir $true) -ne 0) { $rc = 1 }
        } else {
            # --- Path 3: fresh setup ---
            if ((Invoke-UiCreateDotprofile $userRepoDir) -ne 0) { $rc = 1 }
        }
    }
    # This machine without a profile at the end (skipped at a prompt, refused, failed)
    # is one outcome with one exit code, 1 (Review3 #82 minor 3)
    $noMachine = $false
    if (-not $script:UiMachineKey) {
        # A skip at a prompt wrote a WARN row only: name the reason for the exit code (review n1)
        if ($rc -eq 0) { LogError "machine profile: this machine is not registered (skipped) -- run: aitools user init" }
        $rc = 1
        # Reported here: setup-user-config gets -NoMachine, so it adds no second
        # machine-profile ERROR / ACTION (M3-FINISH item 2). Decided here, not from an
        # empty $machineKey at the writer call: the owner "config" branch below also
        # empties it for a registered machine whose id cannot be detected.
        $noMachine = $true
    }

    if (Test-Path -LiteralPath $userRepoDir) {
        if ((Invoke-UiScaffoldClaudeMd $userRepoDir) -ne 0) { $rc = 1 }
    }

    # config.json has one writer (setup-user-config): GitHub user, dotprofile path and
    # this machine's profile key (-MachineId; ConfigKey contract). Another machine's
    # key is never passed (ConfigKey Q3); a key that only config.json vouches for (owner
    # "config") is left to the writer to re-derive (review M2); an unregistered machine
    # ($noMachine) gets -NoMachine instead of a key. In-process: reset the
    # exit code, catch a throw; its output goes to the host, never into this function's
    # return value (review m1: `exit (Invoke-UserInitCommand)` would otherwise exit 0).
    $machineKey = $script:UiMachineKey
    if ($script:UiMachineOwner -ceq "config") {
        LogDetail "user init: machine id undetectable -- -MachineId not passed (the writer keeps the cached machineId)"
        $machineKey = ""
    } elseif ($machineKey -and $script:UiMachineOwner -cne "this") {
        LogError "user init: profile $machineKey is not this machine's (owner $($script:UiMachineOwner)) -- not passed to setup-user-config"
        Write-Summary "ERROR" "machine profile" "not this machine's profile"
        $machineKey = ""; $rc = 1
    }
    $configWriter = Join-Path $repoPath "scripts" "setup-user-config.ps1"
    $writerArgs = @{ GithubUser = $script:UiGhUser; UserRepoPath = $userRepoDir }
    if ($machineKey) { $writerArgs["MachineId"] = $machineKey }
    elseif ($noMachine) { $writerArgs["NoMachine"] = $true }
    $global:LASTEXITCODE = 0
    try {
        & $configWriter @writerArgs | Out-Host
        $writerRc = $LASTEXITCODE
        if ($writerRc -ne 0) {
            LogError "user init: setup-user-config failed (exit $writerRc) -- see $logFile"
            Write-Summary "ERROR" "aitools config" "setup-user-config failed"
            $rc = 1
        }
    } catch {
        LogError "user init: setup-user-config.ps1 failed: $_"
        Write-Summary "ERROR" "aitools config" "setup-user-config failed"
        $rc = 1
    }

    # Session archive hook. Exit 2 = the user aborted in the review menu (D-TS13):
    # stop with exit 2; any other failure is logged.
    Log "user init: deploying the session archive hook"
    $hookSetup = Join-Path $repoPath "scripts" "setup-user-hooks.ps1"
    $hookRc = 0
    if (-not (Test-Path -LiteralPath $hookSetup)) {
        $hookRc = 127
    } else {
        $global:LASTEXITCODE = 0
        try {
            & $hookSetup | Out-Host
            $hookRc = $LASTEXITCODE
        } catch {
            LogError "user init: setup-user-hooks.ps1 failed: $_"
            $hookRc = 1
        }
    }
    if ($hookRc -eq 2) {
        Log "user init: aborted by user"
        return 2
    }
    if ($hookRc -eq 127) {
        LogError "user init: $hookSetup not found -- the session archive hook was not deployed"
        Write-Summary "ERROR" "claude hooks" "setup script missing"
        $rc = 1
    } elseif ($hookRc -and $hookRc -ne 0) {
        LogError "user init: setup-user-hooks.ps1 failed (exit $hookRc) -- see $logFile"
        $rc = 1
    }
    if ($rc -eq 0) {
        LogOk "user init: done -- sessions will be archived to $(Join-Path $userRepoDir 'sessions')"
    }
    return $rc
}

# Invoke-UserInitCommand -- decision 3: user init has its own run summary, created
# before the user block (its rows and those of its child scripts) and shown
# before it returns. Returns Invoke-UserInit's exit code.
function Invoke-UserInitCommand {
    $env:AITOOLS_SUMMARY_FILE = Join-Path $HOME ".aitools" "run-summary.txt"
    try {
        $null = New-Item -ItemType Directory -Path (Join-Path $HOME ".aitools") -Force -ErrorAction Stop
        $null = New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force -ErrorAction Stop
    } catch {
        LogWarn "user init: could not create the run summary $($env:AITOOLS_SUMMARY_FILE) -- the summary panel is not shown"
    }
    $initOut = @(Invoke-UserInit)
    # The exit code is the last value; anything before it leaked into the output stream
    $initRc = 1
    if ($initOut.Count -gt 0 -and $initOut[-1] -is [int]) { $initRc = $initOut[-1] }
    else { LogError "user init: no exit code returned (internal error) -- exit 1" }
    if ($initOut.Count -gt 1) { LogDetail "user init: $($initOut.Count - 1) stray output value(s) before the exit code" }
    Show-Summary
    Remove-Item Env:\AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
    if (Test-Path Env:\AITOOLS_SUMMARY_FILE) { LogDetail "AITOOLS_SUMMARY_FILE could not be cleared" }
    return $initRc
}
# --- END user init ---

# ---------------------------------------------------------------------------
# user -- user repo management
# ---------------------------------------------------------------------------

if ($doUser) {
    switch ($subCmd) {
        "init" {
            exit (Invoke-UserInitCommand)
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

            # Delegate the actual archive (project derivation, subagents,
            # idempotent dest-exists, commit/push) to ait-harvest.py -- the
            # single source of truth shared with the SessionEnd hook.
            # Resolve a Python interpreter (existence check + explicit fallback).
            $archivePy = $null
            if (Get-Command python -ErrorAction SilentlyContinue) {
                $archivePy = "python"
            } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
                $archivePy = "python3"
            }
            if (-not $archivePy) {
                LogError "Python 3 not found; cannot archive"
                exit 1
            }
            $archiveHelper = $null
            $candidate = Join-Path $repoPath "scripts\ait-harvest.py"
            if (Test-Path $candidate) {
                $archiveHelper = $candidate
            } else {
                $fallback = Join-Path $env:USERPROFILE "repos\aitools\scripts\ait-harvest.py"
                if (Test-Path $fallback) { $archiveHelper = $fallback }
            }
            if (-not $archiveHelper) {
                LogError "ait-harvest.py not found; cannot archive"
                exit 1
            }
            & $archivePy $archiveHelper archive --session $fullId --transcript $transcript.FullName
            Write-Host "Archive requested for $fullId (see ~/.aitools/logs/ait-harvest.log)"
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
# Run update (pull + rebuild + deploy/install)
# ---------------------------------------------------------------------------

$env:AITOOLS_RUN_ID = -join ((1..6) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

# Init summary file for this run; child scripts append via AITOOLS_SUMMARY_FILE.
# SUPPRESS=1 tells aitools-install.ps1 not to display it (we display after it returns).
$env:AITOOLS_SUMMARY_FILE = Join-Path $env:USERPROFILE ".aitools\run-summary.txt"
Remove-Item $env:AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
New-Item -ItemType File -Path $env:AITOOLS_SUMMARY_FILE -Force | Out-Null
$env:AITOOLS_SUPPRESS_SUMMARY_DISPLAY = "1"


Log "aitools $AITOOLS_INSTALLED_VERSION"

if ($doInstall) {
    $steps = 3
} elseif ($doGitpull) {
    $steps = 4
} else {
    # no-args: quiet pull + rebuild + deploy
    $steps = 3
}

# --- Smart reload: skip steps 1-2 if re-execing after deploy list change ---
$_prebuildDone = $false
if ($env:AITOOLS_PREBUILD_DONE -eq "1") {
    $_prebuildDone = $true
    $pulledUpdates = $false
    if ($env:AITOOLS_PULLED_UPDATES -eq "1") { $pulledUpdates = $true }
    Remove-Item Env:\AITOOLS_PREBUILD_DONE -ErrorAction SilentlyContinue
    Remove-Item Env:\AITOOLS_PULLED_UPDATES -ErrorAction SilentlyContinue
    Log "Steps 1-2 already complete (reloaded)"
}

if (-not $_prebuildDone) {
# [1/N] Pull latest
Log "Step 1/$steps`: Pulling latest"
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
        # Full output to the log first; the console keeps its preview.
        foreach ($pullLine in $pullOut.Split("`n")) {
            if ($pullLine.Trim()) { LogDetail "git-pull: $($pullLine.TrimEnd())" }
        }
        if ($doGitpull) {
            LogError "git pull failed (see $logFile)"
            Write-Host $pullOut
            exit 1
        } else {
            if ($pullOut -match "(?i)(could not resolve|unable to access|connection refused|connection timed out|no route to host)") {
                LogWarn "Could not reach remote - deploying from local checkout"
            } else {
                LogWarn "git pull failed -- deploying from local checkout (see $logFile)"
                $pullOut.Trim().Split("`n") | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" }
            }
            Write-Summary "WARN" "source" "stale local checkout (git pull failed)"
        }
    } elseif ($pullOut -match "Already up to date") {
        LogOk "Already up to date"
    } else {
        $pulledUpdates = $true
        LogOk "Updated"
    }
} finally {
    Pop-Location
}

# The dotprofile, as the resolver finds it (env, config.json, convention, scan):
# pulled here (quiet, non-blocking -- stale local data is better than failing) and
# passed to build-deploy below. A resolver error is logged with its ERROR row and
# ACTION by the lib; the build then resolves (and skips) on its own.
$buildUserRepo = ""
if ((Resolve-UserRepoPath) -eq 0) {
    $userRepoPath = $script:AitLibUserRepoPath
    if (Test-Path (Join-Path $userRepoPath ".git")) {
        $urPull = git -C $userRepoPath pull --ff-only --quiet 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            LogWarn "user repo pull failed -- using local copy."
            LogDetail "user-repo-pull: $($urPull.Trim())"
        }
    }
    # Forward slashes (C:/Users/...), the form Git Bash and pwsh both read
    $buildUserRepo = $userRepoPath -replace '\\', '/'
}

# [2/N] Rebuild deploy scripts
Log "Step 2/$steps`: Rebuilding deploy scripts"
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
# The dotprofile resolved above reaches the build as AITOOLS_USER_REPO_PATH, scoped
# to this one call (B5a Q1; PR #95 follow-up, review H5): restored right after it
$prevUserRepoEnv = $env:AITOOLS_USER_REPO_PATH
try {
    if ($buildUserRepo) { $env:AITOOLS_USER_REPO_PATH = $buildUserRepo }
    $buildResult = & $bashExe "$unixRepoPath/scripts/build-deploy.sh" 2>&1 | Out-String
    $buildRc = $LASTEXITCODE
} finally {
    $env:AITOOLS_USER_REPO_PATH = $prevUserRepoEnv
}
Add-Content -Path $logFile -Value $buildResult
if ($buildRc -eq 0) {
    LogOk "Rebuilt"
} else {
    LogError "build failed (see $logFile)"
    exit 1
}

# Check if repo has a different deploy list than the running binary.
# If so, self-update and re-exec so Deploy-Configs uses the current list.
# Cost when lists match: one string comparison (~0ms). No extra work.
$repoAitools = Join-Path $repoPath "scripts\aitools.ps1"
if (Test-Path $repoAitools) {
    $_repoList = (Select-String -Path $repoAitools -Pattern 'deployScripts\s*=\s*@\(' | Select-Object -Last 1)
    $_selfList = (Select-String -Path $PSCommandPath -Pattern 'deployScripts\s*=\s*@\(' | Select-Object -Last 1)
    if ($_repoList -and $_selfList -and $_repoList.Line.Trim() -ne $_selfList.Line.Trim()) {
        Log "Deploy script list changed -- reloading entry point"
        # Validate syntax before overwriting
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($repoAitools, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -eq 0) {
            $newVersion = Get-RepoVersion $repoPath
            $srcContent = Get-Content $repoAitools -Raw
            $stampedContent = $srcContent -replace '^\$AITOOLS_INSTALLED_VERSION = ".*"', "`$AITOOLS_INSTALLED_VERSION = `"$newVersion`""
            $installedPath = Join-Path $env:USERPROFILE ".local\bin\aitools.ps1"
            [System.IO.File]::WriteAllText($installedPath, $stampedContent, [System.Text.UTF8Encoding]::new($false))
            $env:AITOOLS_PREBUILD_DONE = "1"
            if ($pulledUpdates) { $env:AITOOLS_PULLED_UPDATES = "1" }
            & $installedPath @PSBoundParameters
            exit $LASTEXITCODE
        } else {
            foreach ($err in $parseErrors) {
                LogDetail "aitools.ps1 parse: line $($err.Extent.StartLineNumber): $($err.Message)"
            }
            LogWarn "Repo scripts/aitools.ps1 has parse errors -- continuing with current list (see $logFile)"
        }
    }
}

}  # _prebuildDone

# Overall exit status: any failed installer/deploy step makes `aitools` exit non-zero
$overallRc = 0

if ($doInstall) {
    # --- install: pull + rebuild + run installer (includes deploy) ---
    Log "Step 3/$steps`: Running installer"
    $installerArgs = @()
    if ($SkipGhAuth) { $installerArgs += "-SkipGhAuth" }
    if ($SkipDriveDetection) { $installerArgs += "-SkipDriveDetection" }
    if ($ReposPath) { $installerArgs += "-ReposPath"; $installerArgs += $ReposPath }
    # Interactive iff run from a console: the installer and its setup scripts decide
    # for themselves. -Force makes every review prompt take the source version
    # (backup kept), console or not.
    if ($Force) { $env:AITOOLS_FORCE = "1" }
    & "$repoPath\scripts\aitools-install.ps1" @installerArgs
    $installerRc = $LASTEXITCODE
    if (Test-Path Env:\AITOOLS_FORCE) { Remove-Item Env:\AITOOLS_FORCE }
    Write-Host ""
    # Exit 2 = the user chose [x]abort at a review menu (D-TS13): the run stops
    if ($installerRc -eq 2) {
        Log "Installer aborted by user at a review menu -- run stopped (exit 2)"
        Show-Summary
        exit 2
    }
    if ($installerRc -eq 0) {
        LogOk "All up to date ($(Get-RepoVersion $repoPath))"
        # Session archive hint (after final status line)
        $userRepo = Read-ConfigKey -File $configFile -Key "userRepoPath"
        if (-not $userRepo) {
            Write-Host "hint: To archive sessions across machines, run 'aitools user init'." -ForegroundColor Yellow
        }
        Invoke-ProfileCheck -Mode "interactive"
    } else {
        Log "Completed with errors (see $logFile)" "error"
        $overallRc = 1
    }

} elseif ($doGitpull) {
    # --- gitpull: pull + rebuild + deploy + changelog + version tag ---
    Log "Step 3/$steps`: Deploying configurations"
    $deployRc = Deploy-Configs (Join-Path $repoPath "scripts")
    # [x]abort in deploy-harness (D-TS13): show what ran and stop with exit 2
    if ($script:deployAborted) {
        Show-Summary
        exit 2
    }
    if ($deployRc -eq 0) {
        LogOk "Done"
    } else {
        Log "Completed with $deployRc error(s)" "error"
        $overallRc = 1
    }

    Log "Step 4/$steps`: Tagging version"
    # Skip if HEAD already has a tag (e.g., re-running gitpull without new commits)
    $existing = git -C $repoPath describe --tags --match "v*" --exact-match HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing) {
        LogOk "HEAD already tagged ($existing) -- skipping"
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
            LogWarn "RELEASE_NOTES.md has no entry for $tag -- skipping tag"
            Log "Add a '## $tag -- Title ($today)' section first"
            $tag = "(skipped)"
        } else {
            git -C $repoPath tag $tag
            $pushResult = git -C $repoPath push origin $tag 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                LogOk "Tagged $tag"
            } else {
                LogWarn "Tagged $tag (local only -- push failed)"
            }
        }
    }

    if ($pulledUpdates) {
        LogOk "Updated and deployed ($tag)"
        # Show date-formatted changelog (no hashes)
        Push-Location $repoPath
        git log --format='  %ad  %s' --date=short ORIG_HEAD..HEAD 2>$null | ForEach-Object { Write-Host $_ }
        Pop-Location
    } else {
        LogOk "Deployed ($tag)"
    }

} else {
    # --- no-args: quiet pull + rebuild + deploy ---
    Log "Step 3/$steps`: Deploying configurations"
    $deployRc = Deploy-Configs (Join-Path $repoPath "scripts")
    # [x]abort in deploy-harness (D-TS13): show what ran and stop with exit 2
    if ($script:deployAborted) {
        Show-Summary
        exit 2
    }
    if ($deployRc -eq 0) {
        LogOk "Done"
    } else {
        Log "Completed with $deployRc error(s)" "error"
        $overallRc = 1
    }

    LogOk "Configs deployed ($(Get-RepoVersion $repoPath))"

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
        foreach ($err in $parseErrors) {
            LogDetail "aitools.ps1 parse: line $($err.Extent.StartLineNumber): $($err.Message)"
        }
        LogWarn "skipping PS1 self-update (new aitools.ps1 has parse errors on this PowerShell version; see $logFile)"
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

$relayPrompt = Join-Path $repoPath "scripts\relay-outbound-prompt.ps1"
if (Test-Path $relayPrompt) {
    . $relayPrompt
    $relayRc = Invoke-RelayOutboundPrompt -RepoPath $repoPath
    if ($relayRc -eq 2) { exit 2 }
}

Remove-Item Env:\AITOOLS_RUN_ID -ErrorAction SilentlyContinue
Remove-Item Env:\AITOOLS_SUMMARY_FILE -ErrorAction SilentlyContinue
Remove-Item Env:\AITOOLS_SUPPRESS_SUMMARY_DISPLAY -ErrorAction SilentlyContinue

exit $overallRc
