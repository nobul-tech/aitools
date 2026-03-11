# setup-user-mcp.ps1 — Installs/updates user-level MCP servers for Claude Code on Windows
# Safe to re-run — checks existing config, only re-adds when changed or -Force used.
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled by default (deny rules).
# Use `aitools --addmcp` to enable per project.

# --- BEGIN mcp body (extracted by build-deploy) ---
param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-user-mcp"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# Check that claude CLI is available
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    LogError "'claude' CLI not found in PATH. Install Claude Code first: https://claude.ai/download"
    exit 1
}

# Check that Node.js is available (required for Chrome DevTools MCP and settings merge)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    LogError "Node.js not found. Install via 'aitools install' or manually: https://nodejs.org"
    exit 1
} else {
    $nodeVersion = (node --version)
    LogOk "Node.js $nodeVersion found"
}

# --- Check existing MCP server configs via claude mcp list ---
$mcpCurrent = @{}

$savedClaudeCode = $env:CLAUDECODE
Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue

try {
    $mcpListOutput = claude mcp list 2>$null
    $mcpListRc = $LASTEXITCODE
} catch {
    $mcpListOutput = $null
    $mcpListRc = 1
}

if ($savedClaudeCode) {
    $env:CLAUDECODE = $savedClaudeCode
}

if ($mcpListRc -eq 0 -and $mcpListOutput) {
    foreach ($line in $mcpListOutput) {
        $clean = $line -replace '\e\[[0-9;]*m', ''
        if ($clean -match '^(.+?):\s+(.+)\s+-\s+.+$') {
            $name = $Matches[1]
            $details = $Matches[2] -replace '\s+\(HTTP\)$', ''
            $details = $details.TrimEnd()
            $mcpCurrent[$name] = $details
        }
    }
    LogOk "Checked existing MCP config ($($mcpCurrent.Count) servers found)"
} else {
    LogWarn "Could not check existing MCP config; will re-add all servers"
}

function Test-ServerConfigMatches {
    param([string]$Name, [string]$Expected)
    $current = $mcpCurrent[$Name]
    return ($null -ne $current -and $current -eq $Expected)
}

# --- Add all three MCP servers at user scope ---

function Add-McpServer {
    param(
        [string]$Name,
        [string[]]$AddArgs
    )

    # Unset CLAUDECODE to allow running inside a Claude Code session
    $savedClaudeCode = $env:CLAUDECODE
    Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue

    # Remove existing (ignore errors if not found)
    $removeResult = claude mcp remove $Name --scope user 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log "Removed existing $Name config"
    }

    Log "Adding $Name..."
    $addResult = & claude mcp add @AddArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        LogOk "$Name configured"
        $script:mcpChanged = $true
    } else {
        LogError "Failed to add $Name`: $addResult"
        Write-Summary "ERROR" "claude mcp" "failed to add $Name"
    }

    # Restore CLAUDECODE
    if ($savedClaudeCode) {
        $env:CLAUDECODE = $savedClaudeCode
    }
}

$mcpChanged = $false
Log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools -- local stdio server via npx (Windows needs cmd /c wrapper)
if ($Force) {
    if ($DryRun) {
        Log "[DRY RUN] Would re-add MCP server: chrome-devtools (-Force)"
    } else {
        Add-McpServer -Name "chrome-devtools" -AddArgs @("chrome-devtools", "--scope", "user", "cmd", "/c", "npx", "chrome-devtools-mcp@latest", "--", "--isolated")
    }
} elseif (Test-ServerConfigMatches "chrome-devtools" "cmd /c npx chrome-devtools-mcp@latest --isolated") {
    LogOk "chrome-devtools already configured, skipping (use -Force to re-add)"
} else {
    if ($DryRun) {
        Log "[DRY RUN] Would add MCP server: chrome-devtools (stdio, --isolated)"
    } else {
        Add-McpServer -Name "chrome-devtools" -AddArgs @("chrome-devtools", "--scope", "user", "cmd", "/c", "npx", "chrome-devtools-mcp@latest", "--", "--isolated")
    }
}

# Vercel -- remote HTTP server (disabled by default via deny rules below)
if ($Force) {
    if ($DryRun) {
        Log "[DRY RUN] Would re-add MCP server: vercel (-Force)"
    } else {
        Add-McpServer -Name "vercel" -AddArgs @("--transport", "http", "--scope", "user", "vercel", "https://mcp.vercel.com")
    }
} elseif (Test-ServerConfigMatches "vercel" "https://mcp.vercel.com") {
    LogOk "vercel already configured, skipping (use -Force to re-add)"
} else {
    if ($DryRun) {
        Log "[DRY RUN] Would add MCP server: vercel (http)"
    } else {
        Add-McpServer -Name "vercel" -AddArgs @("--transport", "http", "--scope", "user", "vercel", "https://mcp.vercel.com")
    }
}

# Webflow -- remote HTTP server (disabled by default via deny rules below)
if ($Force) {
    if ($DryRun) {
        Log "[DRY RUN] Would re-add MCP server: webflow (-Force)"
    } else {
        Add-McpServer -Name "webflow" -AddArgs @("--transport", "http", "--scope", "user", "webflow", "https://mcp.webflow.com/mcp")
    }
} elseif (Test-ServerConfigMatches "webflow" "https://mcp.webflow.com/mcp") {
    LogOk "webflow already configured, skipping (use -Force to re-add)"
} else {
    if ($DryRun) {
        Log "[DRY RUN] Would add MCP server: webflow (http)"
    } else {
        Add-McpServer -Name "webflow" -AddArgs @("--transport", "http", "--scope", "user", "webflow", "https://mcp.webflow.com/mcp")
    }
}

# --- Merge deny rules into ~/.claude/settings.json ---
# Vercel and Webflow are disabled by default at user level.
# Projects enable them via .claude/settings.local.json (aitools --addmcp).

$settingsFile = Join-Path (Join-Path $env:USERPROFILE ".claude") "settings.json"
$settingsDir = Split-Path $settingsFile -Parent
Log "Merging deny rules into $settingsFile..."

if (-not (Test-Path $settingsDir)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
}

# Back up before merge
if (-not $DryRun) {
    Backup-File -FilePath $settingsFile
}

# Read existing settings or start fresh
$settings = @{}
$corrupt = $false
if (Test-Path $settingsFile) {
    try {
        $raw = Get-Content $settingsFile -Raw
        $settings = ConvertPSObjectToHashtable ($raw | ConvertFrom-Json)
    } catch {
        $corrupt = $true
        LogWarn "$settingsFile could not be parsed ($_)"
    }
}
$beforeKeys = @($settings.Keys)

# Ensure permissions.deny exists
if (-not $settings.ContainsKey("permissions")) { $settings["permissions"] = @{} }
if (-not $settings["permissions"].ContainsKey("deny")) { $settings["permissions"]["deny"] = @() }

# Add deny rules if not already present
$denyRules = @("MCP(vercel)", "MCP(webflow)")
foreach ($rule in $denyRules) {
    if ($rule -notin $settings["permissions"]["deny"]) {
        $settings["permissions"]["deny"] += $rule
    }
}

# Clobber detection
$managedKeys = @("permissions")
$lostKeys = @($beforeKeys | Where-Object { $_ -notin $settings.Keys })

if ($DryRun) {
    Log "[DRY RUN] $settingsFile`: merge deny rules"
    Log "  Managed fields: permissions.deny"
    if ($lostKeys.Count -gt 0) {
        LogWarn "[DRY RUN] CLOBBER: would lose non-managed fields: $($lostKeys -join ', ')"
    }
    if ($corrupt) {
        LogWarn "[DRY RUN] File is corrupt -- -Force required to overwrite"
    }
} elseif ($corrupt -and -not $Force) {
    LogError "$settingsFile is corrupt. Use -Force to overwrite, or fix manually."
    Write-Summary "ERROR" "claude mcp" "settings corrupt"
} elseif ($lostKeys.Count -gt 0 -and -not $Force) {
    LogError "$settingsFile merge would lose fields: $($lostKeys -join ', '). Use -Force to proceed."
    Write-Summary "ERROR" "claude mcp" "merge would lose fields"
} else {
    if ($corrupt) { LogWarn "Proceeding with -Force on corrupt file" }
    if ($lostKeys.Count -gt 0) { LogWarn "Proceeding with -Force, losing fields: $($lostKeys -join ', ')" }

    $mergedNorm = Normalize-JsonForComparison $settings -Depth 10
    $existingNorm = if ($raw -and -not $corrupt) {
        Normalize-JsonForComparison (ConvertPSObjectToHashtable ($raw | ConvertFrom-Json)) -Depth 10
    } else { $null }

    if (-not $corrupt -and $lostKeys.Count -eq 0 -and $mergedNorm -eq $existingNorm) {
        LogOk "Deny rules unchanged in $settingsFile"
    } else {
        $json = $settings | ConvertTo-Json -Depth 10
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($settingsFile)
        [System.IO.File]::WriteAllText($resolvedPath, $json, [System.Text.UTF8Encoding]::new($false))

        # Post-write validation
        try {
            $vContent = [System.IO.File]::ReadAllText($resolvedPath)
            $vParsed = $vContent | ConvertFrom-Json
            if (-not ($vParsed.PSObject.Properties.Name -contains "permissions")) {
                LogError "Validation failed: $settingsFile missing required field 'permissions'"
            }
        } catch {
            LogError "Validation failed: $settingsFile is not valid JSON -- $_"
        }

        LogOk "Deny rules set for vercel, webflow in $settingsFile"
        $mcpChanged = $true
    }
}

if ($DryRun) {
    Log "[DRY RUN] Would configure user-level MCP (all servers; vercel/webflow disabled by default)"
} else {
    LogOk "User-level MCP configured (all servers; vercel/webflow disabled by default)"
    if ($errors -eq 0) {
        Write-Summary "OK" "claude mcp" $(if ($mcpChanged) { "configured" } else { "unchanged" })
    }
}
Log "To enable per project: aitools --addmcp vercel"
Log "To check status: aitools mcp"

# Display cloud MCP servers configured at claude.ai.
# Silent no-op if claude CLI unavailable or no cloud servers found.
function Show-CloudMcpStatus {
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { return }
    $savedClaudeCode = $env:CLAUDECODE
    Remove-Item Env:\CLAUDECODE -ErrorAction SilentlyContinue
    try {
        $savedEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = claude mcp list 2>$null
        [Console]::OutputEncoding = $savedEncoding
    } catch { $raw = $null }
    if ($savedClaudeCode) { $env:CLAUDECODE = $savedClaudeCode }
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
    Log "Cloud MCP servers (configured at claude.ai):"
    foreach ($entry in $entries) {
        $pad = if ($entry.Name.Length -lt 24) { " " * (24 - $entry.Name.Length) } else { " " }
        Log "  $($entry.Name)$pad$($entry.Status)"
    }
}

# --- END mcp body (extracted by build-deploy) ---

# --- Deploy Chrome DevTools skills ---
# Vendored from https://github.com/ChromeDevTools/chrome-devtools-mcp/tree/main/skills
# These provide structured workflows for browser automation and a11y auditing.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsSrc = Join-Path (Join-Path (Split-Path -Parent $scriptDir) "shared") "skills"
$skillsDest = Join-Path (Join-Path $env:USERPROFILE ".claude") "skills"
$skillsDestCursor = Join-Path (Join-Path $env:USERPROFILE ".cursor") "skills"

$allSkillDests = @($skillsDest, $skillsDestCursor)

$script:skillChanges = 0
function Deploy-Skill {
    param([string]$SkillName, [string]$DestBase, [string]$ToolName)

    $src = Join-Path (Join-Path $skillsSrc $SkillName) "SKILL.md"
    $destDir = Join-Path $DestBase $SkillName
    $dest = Join-Path $destDir "SKILL.md"

    if (-not (Test-Path $src)) {
        LogError "Skill source not found: $src"
        return
    }

    try {
        $srcContent = Get-Content $src -Raw -ErrorAction Stop
    } catch {
        LogError "Cannot read skill source $SkillName`: $_"
        return
    }

    $skillResult = Deploy-ManagedFile -Content $srcContent -DestPath $dest -ToolName $ToolName -ItemName $SkillName -AdoptLabel "shared/"

    if ($skillResult -eq "adopted") {
        # Copy deployed version back to repo source
        Copy-Item -Path $dest -Destination $src -Force -ErrorAction Stop
        LogOk "Adopted skill to shared/: $SkillName"
        # Sync adopted content to all other deploy targets (prevents clobber)
        foreach ($otherBase in $allSkillDests) {
            if ($otherBase -eq $DestBase) { continue }
            $otherDir = Join-Path $otherBase $SkillName
            if (-not (Test-Path $otherDir)) {
                New-Item -ItemType Directory -Path $otherDir -Force | Out-Null
            }
            Copy-Item -Path $dest -Destination (Join-Path $otherDir "SKILL.md") -Force
        }
    }
    if ($skillResult -eq "created" -or $skillResult -eq "updated") {
        $script:skillChanges++
    }
    Record-DeployOutcome -Outcome $skillResult -ToolName $ToolName -ItemName $SkillName
}

Log "Deploying Chrome DevTools skills to $skillsDest..."
$errorsBeforeClaudeSkills = $errors
Initialize-DeployTracker
Deploy-Skill "chrome-devtools" $skillsDest "claude skills"
Deploy-Skill "a11y-debugging" $skillsDest "claude skills"
if ($errors -eq $errorsBeforeClaudeSkills) {
    Write-DeployTrackerSummary -ToolName "claude skills"
} else {
    Write-Summary "ERROR" "claude skills" "deploy failed"
}

Log "Deploying Chrome DevTools skills to $skillsDestCursor..."
$errorsBeforeCursorSkills = $errors
Initialize-DeployTracker
Deploy-Skill "chrome-devtools" $skillsDestCursor "cursor skills"
Deploy-Skill "a11y-debugging" $skillsDestCursor "cursor skills"
if ($errors -eq $errorsBeforeCursorSkills) {
    Write-DeployTrackerSummary -ToolName "cursor skills"
} else {
    Write-Summary "ERROR" "cursor skills" "deploy failed"
}

# --- BEGIN exit (extracted by build-deploy) ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Show-CloudMcpStatus
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Show-CloudMcpStatus
    Log "COMPLETED successfully" "ok"
    exit 0
}
# --- END exit (extracted by build-deploy) ---
