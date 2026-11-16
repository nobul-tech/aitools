# setup-cursor-ide-mcp.ps1 — Installs/updates MCP servers for Cursor IDE on Windows
# Safe to re-run — merges managed servers into ~/.cursor/mcp.json.
#
# Managed fields: mcpServers.chrome-devtools, mcpServers.vercel, mcpServers.webflow
# Preserved: all other mcpServers entries, all other top-level keys
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled via `agent mcp disable`.
# Use `aitools --addmcp` to enable per project.
#
# Cursor uses its own MCP config at ~/.cursor/mcp.json (separate from Claude Code's ~/.claude.json).
# Remote servers use the "url" key directly. Local stdio servers use "command" + "args".

param(
    [switch]$DryRun,
    [switch]$Force
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-cursor-ide-mcp"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

Log "Setting up MCP servers for Cursor IDE (user scope)..."

# Check that Node.js is available (required for Chrome DevTools MCP)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-AitError "cursor ide mcp" "Node.js not found" "node is not on PATH -- install it with aitools install or from https://nodejs.org"
    exit 1
} else {
    $nodeVersion = (node --version)
    LogOk "Node.js $nodeVersion found"
}

# Ensure ~/.cursor directory exists
$cursorDir = Join-Path $env:USERPROFILE ".cursor"
if (-not (Test-Path $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    Log "Created $cursorDir"
}

$mcpJson = Join-Path $cursorDir "mcp.json"

# Read existing config or start fresh (merge, not overwrite)
if (-not $DryRun) {
    Backup-File -FilePath $mcpJson
}
$config = @{}
$corrupt = $false
$parseError = ""
if (Test-Path $mcpJson) {
    Log "Merging managed servers into $mcpJson"
    try {
        $raw = Get-Content $mcpJson -Raw
        $config = ConvertPSObjectToHashtable ($raw | ConvertFrom-Json)
    } catch {
        $corrupt = $true
        # Detail only: the corrupt-file error or the forced rewrite below reports it
        $parseError = $_.Exception.Message
        LogDetail "$mcpJson could not be parsed: $parseError"
    }
} else {
    Log "Creating $mcpJson"
}
$beforeKeys = @($config.Keys)

# Ensure mcpServers exists
if (-not $config.ContainsKey("mcpServers")) { $config["mcpServers"] = @{} }

# Snapshot managed server entries before merge for change tracking
$managedServers = @("chrome-devtools", "vercel", "webflow")
$beforeServers = @{}
foreach ($s in $managedServers) {
    if ($config["mcpServers"].ContainsKey($s)) {
        $beforeServers[$s] = Normalize-JsonForComparison $config["mcpServers"][$s] -Depth 5 -Compress
    } else {
        $beforeServers[$s] = $null
    }
}

# Set managed servers (Windows uses cmd /c wrapper for npx)
$config["mcpServers"]["chrome-devtools"] = @{
    command = "cmd"
    args    = @("/c", "npx", "-y", "chrome-devtools-mcp@latest", "--isolated")
}
$config["mcpServers"]["vercel"] = @{
    url = "https://mcp.vercel.com"
}
$config["mcpServers"]["webflow"] = @{
    url = "https://mcp.webflow.com/mcp"
}

# Clobber detection
$managedKeys = @("mcpServers")
$lostKeys = @($beforeKeys | Where-Object { $_ -notin $config.Keys })

$mcpChanged = $false
if ($DryRun) {
    Log "[DRY RUN] $mcpJson`: merge MCP servers"
    Log "  Managed fields: mcpServers.chrome-devtools, mcpServers.vercel, mcpServers.webflow"
    if ($lostKeys.Count -gt 0) {
        Write-AitWarn "cursor ide mcp" "[DRY RUN] would lose non-managed fields: $($lostKeys -join ', ')"
    }
    if ($corrupt) {
        Write-AitWarn "cursor ide mcp" "[DRY RUN] mcp.json is corrupt -- -Force required to overwrite"
    }
} elseif ($corrupt -and -not $Force) {
    Write-AitError "cursor ide mcp" "config corrupt" "$mcpJson is not valid JSON ($parseError) -- fix it or re-run with -Force"
} elseif ($lostKeys.Count -gt 0 -and -not $Force) {
    Write-AitError "cursor ide mcp" "merge would lose fields" "would drop: $($lostKeys -join ', ') -- re-run with -Force to proceed"
} else {
    # A -Force write that loses data stays a warning (reference/logging.md 8.3
    # "What is a warning")
    if ($corrupt) { Write-AitWarn "cursor ide mcp" "overwrote corrupt $mcpJson (-Force)" }
    if ($lostKeys.Count -gt 0) { Write-AitWarn "cursor ide mcp" "dropped fields under -Force: $($lostKeys -join ', ')" }

    $afterJson = $config | ConvertTo-Json -Depth 10
    $afterNorm = Normalize-JsonForComparison $config -Depth 10
    $existingNorm = if ($raw -and -not $corrupt) { Normalize-JsonForComparison (ConvertPSObjectToHashtable ($raw | ConvertFrom-Json)) -Depth 10 } else { $null }
    if (-not $corrupt -and $lostKeys.Count -eq 0 -and $afterNorm -eq $existingNorm) {
        $mcpChanged = $false
        LogOk "Cursor MCP config already up to date"
        Write-Summary "OK" "cursor ide mcp" "verified"
    } else {
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($mcpJson)
        [System.IO.File]::WriteAllText($resolvedPath, $afterJson, [System.Text.UTF8Encoding]::new($false))

        # Post-write validation: a failure is one recorded error and no OK record
        $validationFailed = $false
        try {
            $vContent = [System.IO.File]::ReadAllText($resolvedPath)
            $vParsed = $vContent | ConvertFrom-Json
            if (-not ($vParsed.PSObject.Properties.Name -contains "mcpServers")) {
                $validationFailed = $true
                Write-AitError "cursor ide mcp" "post-write validation failed" "$mcpJson has no 'mcpServers' field"
            }
        } catch {
            $validationFailed = $true
            Write-AitError "cursor ide mcp" "post-write validation failed" "$mcpJson is not valid JSON after the write: $($_.Exception.Message)"
        }

        if (-not $validationFailed) {
            $mcpChanged = $true

            # Detect per-server changes and emit DETAIL lines
            $serverChanges = @()
            foreach ($s in $managedServers) {
                $newVal = Normalize-JsonForComparison $config["mcpServers"][$s] -Depth 5 -Compress
                if ($beforeServers[$s] -ne $newVal) {
                    $oldDisplay = if ($beforeServers[$s]) { $beforeServers[$s] } else { "(unset)" }
                    $serverChanges += "${s}: $oldDisplay -> $newVal"
                }
            }

            LogOk "Cursor MCP config written to $mcpJson"
            Log "Servers configured: chrome-devtools (stdio), vercel (http), webflow (http)"
            if ($serverChanges.Count -gt 0) {
                Emit-MergeDetails -Changes $serverChanges -ToolName "cursor ide mcp"
            }
            Write-Summary "OK" "cursor ide mcp" "updated"
        }
    }
}

# --- Disable vercel/webflow via Cursor CLI if available ---
# `agent mcp disable <name>`: Cursor docs https://cursor.com/docs/cli/mcp
# ("Disabled servers won't load or prompt for approval"). The CLI has no
# `remove` verb. The disable applies to the project (git root) of the current
# directory, not to the user (user rule tool-lifecycle.md "MCP servers");
# `aitools --addmcp` re-enables a server per project with `agent mcp enable`.
# A failed disable is a warning with the CLI's output as its reason (issue #186).
if ($DryRun) {
    Log "[DRY RUN] Would disable vercel/webflow via Cursor CLI (if available)"
} elseif (Get-Command agent -ErrorAction SilentlyContinue) {
    foreach ($server in @("vercel", "webflow")) {
        $result = agent mcp disable $server 2>&1 | Out-String
        $disableRc = $LASTEXITCODE
        if ($disableRc -eq 0) {
            LogOk "$server disabled in Cursor"
        } else {
            Write-AitWarn "cursor ide mcp" "failed to disable ${server}: $(Get-AitErrorReason -Output $result -ExitCode $disableRc)"
        }
    }
} else {
    Log "Cursor CLI (agent) not found - disable vercel/webflow manually:"
    Log "  Cursor Settings > Features > MCP > toggle off vercel and webflow"
    Log "  Or install Cursor CLI: aitools install"
}

# Only suggest restart if config actually changed
if ($mcpChanged) {
    Write-Summary "ACTION" "" "Restart Cursor IDE to apply MCP changes"
}

# --- Exit ---
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
