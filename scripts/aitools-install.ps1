# aitools-install.ps1 -- Install aitools command + configure environment
# Run once for first-time setup, or re-run via `aitools` to stay current.
#
# Installs/updates gh CLI, configures repos directory, auto-detects Google
# Drive mounts, writes ~/.aitools/config.json, installs the
# aitools command to ~/.local/bin/, adds shell integration, deploys the
# harness to ~/.aitools (deploy-harness.ps1, Step 8b), and deploys
# all configuration scripts.

param(
    [string]$ReposPath = "",
    [switch]$SkipDriveDetection,
    [switch]$SkipGhAuth,
    [switch]$DryRun,
    [switch]$Help
)

if ($Help) {
    @"
aitools-install.ps1 -- Install aitools command + configure environment

Usage: .\scripts\aitools-install.ps1 [OPTIONS]

Options:
  -ReposPath <string>       Set repos directory without prompting (default: ~/repos)
  -SkipDriveDetection       Skip Google Drive auto-detection
  -SkipGhAuth               Skip gh auth login
  -DryRun                   Preview mode -- show what would change without writing
  -Help                     Show this help

Interactive behavior:
  When stdin is a terminal, prompts for gh login, repos path, and file reviews.
  When piped or run non-interactively, uses defaults and flags.
  AITOOLS_FORCE=1 (aitools install --force): no prompts even in a terminal;
  managed files take the source version (backups kept).
  When config.json already exists, uses saved values without prompting.
"@
    exit 0
}

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "aitools-install"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# The log directory: Initialize-Logging (aitools-lib) creates it, fail-safe
# (reference/logging.md section 5; incident #174: a second, unguarded New-Item here
# printed an error when it could not be created)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }
if ($DryRun) { $env:AITOOLS_DRY_RUN = "1" }

# --- BEGIN install log helpers (tests/profile/test-config.sh extracts this block) ---
# deploy.jsonl records (Write-JsonlRecord), the child relay (Invoke-ChildRelayed)
# and the relay sync (Invoke-RelaySync) come from aitools-lib: one copy for the
# installers, user init and deploy-harness (audit A-1). A record that cannot be
# written is one warning and the run goes on (A-16). This block keeps only the
# installer's own Step 3 / Step 5 helpers.

# Invoke-ConfigWriter WRITER ARGS -- Step 5: run setup-user-config.ps1 in-process
# through the lib relay. The writer logs and records its own warnings and errors;
# the relay shows and mirrors its lines to deploy.jsonl, counts a failed writer
# (exit code or throw) as one error of the installer and records "ERROR|aitools
# config|Step 5: setup-user-config.ps1 failed (...)|<reason>" when the writer
# recorded no error of its own (reference/logging.md 8.3; A-1, A-18). Returns
# nothing.
function Invoke-ConfigWriter([string]$Writer, [hashtable]$WriterArgs) {
    $writerRc = Invoke-ChildRelayed "Step 5: setup-user-config.ps1" $Writer $WriterArgs "aitools config"
    if ($writerRc -ne 0) {
        LogDetail "Step 5: config writer step failed (exit $($script:AitLibChildRc); logged and counted by the relay)"
    }
}

# Get-AbsoluteReposPath PATH -- PATH as an absolute path. A relative answer is taken
# relative to the current location, where Step 3 creates it (the pre-#79 installer
# kept it relative; the config writer accepts absolute paths only). "" when it
# cannot be resolved; the exception message is then in $script:ReposPathError.
function Get-AbsoluteReposPath([string]$Path) {
    $script:ReposPathError = ""
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    try {
        return [IO.Path]::GetFullPath($Path, (Get-Location).Path)
    } catch {
        $script:ReposPathError = $_.Exception.Message -replace '\s*\r?\n\s*', ' '
        return ""
    }
}

# Resolve-ReposDir PATH -- Step 3: make PATH absolute (relative to the current
# location) and create it. Returns the absolute path, or "" after one error
# (Write-AitError "aitools config", the reason the exception message) when it
# cannot be resolved or created; the caller then skips Step 5, whose writer accepts
# absolute paths only (audit A-17).
function Resolve-ReposDir([string]$Path) {
    $abs = $Path
    if (-not [IO.Path]::IsPathRooted($Path)) {
        $abs = Get-AbsoluteReposPath $Path
        if (-not $abs) {
            $why = if ($script:ReposPathError) { $script:ReposPathError } else { "the path could not be resolved" }
            Write-AitError "aitools config" "repos path '$Path' not resolved -- config.json will not be written" $why
            return ""
        }
        Log "Repos path '$Path' is relative -- using $abs (relative to the current directory)"
    }
    if (-not (Test-Path -LiteralPath $abs -PathType Container)) {
        # [IO.Directory]::CreateDirectory throws on failure; New-Item -Force was seen
        # to return $null without an error when a parent is a file (pwsh 7, macOS).
        # The Test-Path after it is the result check either way.
        $why = "not created"
        try {
            $null = [IO.Directory]::CreateDirectory($abs)
        } catch {
            $why = $_.Exception.Message -replace '\s*\r?\n\s*', ' '
        }
        if (-not (Test-Path -LiteralPath $abs -PathType Container)) {
            Write-AitError "aitools config" "repos directory '$abs' not created -- config.json will not be written" $why
            return ""
        }
    }
    return $abs
}
# --- END install log helpers ---

# --- BEGIN install log options (tests/profile/test-install.sh extracts this block) ---
# One run id for this installer's deploy.jsonl records and every relayed child's
# (the lib's Write-JsonlRecord reads AITOOLS_RUN_ID; a child that relays its own
# children passes it on). 6 random bytes as hex, the lib's form. Set only when the
# caller did not set it ($script:InstallSetRunId), and then removed again at the exit
# footer, so an in-process run does not leave it in the session (review B m-2).
$script:InstallSetRunId = $false
if (-not $env:AITOOLS_RUN_ID) {
    $env:AITOOLS_RUN_ID = -join ((1..6) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })
    $script:InstallSetRunId = $true
}
# The library's jsonl option (reference/logging.md sections 3 and 8.2): every log
# line of the installer is also one deploy.jsonl record (Write-JsonlRecord: escaped,
# the run id above; an unwritable deploy.jsonl is one warning, A-16). Inside a relay
# (aitools.ps1 runs this installer relayed) it writes nothing: the outer relay
# mirrors the line (8.3).
$script:AitLibOptJsonl = $true
# --- END install log options ---

# --- Run summary file (reference/logging.md 8.4, 8.5): created here only when no
# caller set one (aitools.ps1 runs this installer with its own); drawn at the end
# only when this installer created it (Complete-AitSummary) ---
Start-AitSummary

# Interactive mode (same rule as the lib's review prompts): a console on stdin and
# no -Force / AITOOLS_FORCE. Otherwise every prompt takes its default.
$installInteractive = ($env:AITOOLS_FORCE -ne "1") -and (Test-InteractiveConsole)

# Get-InstallTool SCRIPT -- the tool name a setup script records under (the tool
# name table, reference/script-standards-detail.md), passed to the relay as its
# summary tool so a failed child is recorded under that name. A script that
# records under several tools gets the first (A6 Q7). Parity: install_tool in
# aitools-install.sh.
function Get-InstallTool([string]$Script) {
    switch ($Script -replace '\.ps1$', '') {
        "setup-gh-cli"         { return "gh cli" }
        "setup-user-shell"     { return "shell" }
        "setup-vercelcli"      { return "vercel cli" }
        "setup-pandoc"         { return "pandoc" }
        "setup-rust"           { return "rust/cargo" }
        "setup-typst"          { return "typst" }
        "setup-uv"             { return "uv" }
        "setup-python"         { return "python" }
        "setup-pywinpty"       { return "pywinpty" }
        "setup-modal"          { return "modal cli" }
        "setup-go"             { return "go" }
        "setup-datadog"        { return "datadog cli" }
        "setup-perl"           { return "perl" }
        "setup-bash"           { return "bash" }
        "setup-google-chrome"  { return "google chrome" }
        "setup-user-claude"    { return "claude.md" }
        "setup-user-cursor"    { return "cursor cli" }
        "setup-user-mcp"       { return "claude mcp" }
        "setup-user-skills"    { return "skills" }
        "setup-cursor-ide-mcp" { return "cursor ide mcp" }
        "setup-user-settings"  { return "claude settings" }
        "setup-user-hooks"     { return "claude hooks" }
        "deploy-harness"       { return "harness files" }
    }
    return ($Script -replace '\.ps1$', '')
}

# --- Script validation helper ---
# Invoke-ValidatedScript STEP SCRIPT -- run setup SCRIPT as installer step STEP
# ("Step 11"). ParseFile first: a parse error is one error under the script's tool
# (the reason its first parse error, every one a detail line) and the script is
# skipped. Then the script runs in-process and relayed (Invoke-ChildRelayed, label
# "<STEP>: <script>", the script's tool): its lines reach the console and
# deploy.jsonl, and a failed child (exit code or throw) is one error of the
# installer, recorded by the relay only when the child recorded none
# (reference/logging.md 8.3). The install continues either way. Parity:
# validate_and_run in aitools-install.sh.
function Invoke-ValidatedScript {
    param([string]$Step, [string]$ScriptPath)
    $name = Split-Path $ScriptPath -Leaf
    $tool = Get-InstallTool $name
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        foreach ($err in $parseErrors) {
            LogDetail "$name parse: line $($err.Extent.StartLineNumber): $($err.Message)"
        }
        $first = $parseErrors[0]
        Write-AitError $tool "$name parse check failed -- skipped" "line $($first.Extent.StartLineNumber): $($first.Message)"
        return
    }
    if ((Invoke-ChildRelayed "${Step}: $name" $ScriptPath @{} $tool) -ne 0) {
        LogDetail "${Step}: $name failed (exit $($script:AitLibChildRc); logged and counted by the relay)"
    }
}

# Invoke-HarnessStep SCRIPT [ARGS] -- Step 8b: run deploy-harness.ps1 (SCRIPT) with the
# ARGS hashtable (the caller passes @{ SkipConfig = $true } when Step 5 ran the config
# writer) in-process and relayed (aitools-lib Invoke-ChildRelayed "harness files"
# -AbortAsWarning: its Write-Host lines go to the console and deploy.jsonl; the
# review menu reads and writes the console directly). A parse error throws, which
# the lib reports as a failure, never as an abort. Returns 2 when deploy-harness
# exited 2 (the user chose [x]abort, D-TS13: the relay recorded one warning,
# "harness files" "aborted by user"; the caller stops the install), else 0. A
# failure is counted and, when deploy-harness recorded none, recorded by the
# relay; the install continues. Parity: run_harness_step in aitools-install.sh.
function Invoke-HarnessStep([string]$Harness, [hashtable]$HarnessArgs = @{}) {
    if (-not (Test-Path -LiteralPath $Harness)) {
        Write-AitWarn "harness files" "deploy-harness.ps1 not found -- skipped (MDM deploy)"
        return 0
    }
    $harnessRc = Invoke-ChildRelayed "Step 8b: deploy-harness.ps1" $Harness $HarnessArgs "harness files" -AbortAsWarning
    if ($harnessRc -eq 0) { return 0 }
    if ($script:AitLibChildRc -eq 2) {
        Log "Step 8b: aborted by user at a review menu -- install stopped (exit 2)"
        return 2
    }
    return 0
}

# --- Post-write JSON validation ---
# Validates a JSON config file after writing: checks non-empty, valid JSON,
# required keys present, and no double-slash paths (excluding protocol prefixes).
# No caller here since config.json moved to setup-user-config.ps1 (M3 B3b). It stays
# in this installer (M3 B2 kept it out of aitools-lib) because config-file-safety.md
# cites it as the reference example for ValidateJsonConfig. Each failure is one
# error (Write-AitError, empty TOOL = this script's name: WHAT "<file> validation
# failed", REASON what is wrong, with the parser's message; reference/logging.md
# 8.2, 8.3). Parity: validate_json_config in aitools-install.sh.
function ValidateJsonConfig {
    param([string]$File, [string[]]$RequiredKeys)
    if (-not (Test-Path $File) -or (Get-Item $File).Length -eq 0) {
        Write-AitError "" "$File validation failed" "the file is empty or missing"
        return
    }
    try {
        $content = [System.IO.File]::ReadAllText($File)
        $parsed = $content | ConvertFrom-Json
    } catch {
        Write-AitError "" "$File validation failed" ("not valid JSON: " + ($_.Exception.Message -replace '\s*\r?\n\s*', ' '))
        return
    }
    foreach ($key in $RequiredKeys) {
        if (-not ($parsed.PSObject.Properties.Name -contains $key)) {
            Write-AitError "" "$File validation failed" "missing required field '$key'"
        }
    }
    # Double-slash path check (skip protocol prefixes)
    if ($content -match '"[^"]*(?<!https?:)//[^"]*"') {
        Write-AitError "" "$File validation failed" "a path value has a double slash: $($Matches[0])"
    }
}

# --- Config file setup ---
$configDir = Join-Path $env:USERPROFILE ".aitools"
$configFile = Join-Path $configDir "config.json"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

# Auto-detect aitools repo path from this script's location
$aitoolsRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ($DryRun) { Log "[DRY RUN] Preview mode -- no files will be written" }

# ============================================================
# 0. System prerequisites (Windows long paths)
# ============================================================
# Windows has a 260-char path limit by default. Many tools (git, cargo, node)
# need longer paths. Enable both the OS-level setting and git's own flag.
$longPathsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
$longPathsEnabled = $false
try {
    $val = Get-ItemProperty $longPathsKey -Name LongPathsEnabled -ErrorAction SilentlyContinue
    if ($val -and $val.LongPathsEnabled -eq 1) { $longPathsEnabled = $true }
} catch {
    # Registry read failed -- treat as disabled
}

if ($longPathsEnabled) {
    LogOk "Windows long paths enabled"
} else {
    # One warning (no tool: recorded under this script's name) and one ACTION
    Write-AitAction "" "Windows long paths disabled (LongPathsEnabled=0) -- cargo/git may fail on deep paths; enable them as admin" "Enable long paths (admin): Set-ItemProperty '$longPathsKey' -Name LongPathsEnabled -Value 1"
}

# git core.longpaths -- can set without elevation
$gitLongPaths = git config --global core.longpaths 2>$null
if ($gitLongPaths -ne "true") {
    Log "Setting git config --global core.longpaths true..."
    $longPathsOut = git config --global core.longpaths true 2>&1 | Out-String
    $longPathsRc = $LASTEXITCODE
    if ($longPathsRc -eq 0) {
        LogOk "git core.longpaths enabled"
    } else {
        # Get-AitErrorReason logs git's output as detail lines
        LogWarn ("git config --global core.longpaths true failed (exit $longPathsRc) -- deep paths may fail: " + (Get-AitErrorReason -Output $longPathsOut -ExitCode $longPathsRc))
    }
} else {
    LogOk "git core.longpaths already enabled"
}

# ============================================================
# 1. Install/update gh CLI
# ============================================================
Log "Step 1: gh CLI"

$ghScript = Join-Path $PSScriptRoot "setup-gh-cli.ps1"
if (Test-Path $ghScript) {
    Invoke-ValidatedScript "Step 1" $ghScript
} else {
    Write-AitWarn "gh cli" "setup-gh-cli.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 2. Authenticate gh
# ============================================================
Log "Step 2: gh authentication"

if ($SkipGhAuth) {
    Log "Skipping gh auth (-SkipGhAuth)"
} elseif (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-AitWarn "gh auth" "gh not installed -- authentication skipped"
} else {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        LogOk "gh already authenticated"
    } elseif ($installInteractive) {
        Log "Not authenticated. Starting gh auth login..."
        # Interactive: gh talks to the console directly, so only the exit code is
        # captured. Start-Process -NoNewWindow -Wait gives it this console (stdin,
        # stdout and stderr): run as a native command inside a relay (aitools.ps1
        # runs this installer relayed), its output would go to the relay's pipeline
        # and gh would not prompt.
        $ghAuthRc = 0
        try {
            $ghAuthProc = Start-Process -FilePath "gh" -ArgumentList @("auth", "login") -NoNewWindow -Wait -PassThru -ErrorAction Stop
            $ghAuthRc = $ghAuthProc.ExitCode
            $ghAuthWhy = Get-AitErrorReason -Output "" -ExitCode $ghAuthRc
        } catch {
            $ghAuthRc = 1
            $ghAuthWhy = Get-AitErrorReason -Output "" -ExitCode 1 -ErrorRecord $_
        }
        if ($ghAuthRc -ne 0) {
            # The output went to the console: the reason is the exit code (or the
            # exception when gh could not be started)
            Write-AitError "gh auth" "gh auth login failed (exit $ghAuthRc)" $ghAuthWhy
            Write-Summary "ACTION" "" "Run: gh auth login"
        }
    } else {
        Write-AitAction "gh auth" "not authenticated (non-interactive run) -- run: gh auth login" "Run: gh auth login"
    }
}

# ============================================================
# 3. Configure repos directory
# ============================================================
Log "Step 3: repos directory"

$resolvedReposPath = ""
if ($ReposPath) {
    $resolvedReposPath = $ReposPath -replace '^~', $env:USERPROFILE
    Log "Using repos path from flag: $resolvedReposPath"
} elseif (Test-Path $configFile) {
    # Config exists -- reuse saved value
    try {
        $existingConfig = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($existingConfig.reposPath) {
            $resolvedReposPath = $existingConfig.reposPath
            Log "Using repos path from config: $resolvedReposPath"
        }
    } catch {
        Write-AitWarn "aitools config" "could not read reposPath from config.json ($($_.Exception.Message -replace '\s*\r?\n\s*', ' ')) -- using the default"
    }
}
if (-not $resolvedReposPath) {
    if ($installInteractive) {
        $defaultPath = Join-Path $env:USERPROFILE "repos"
        [Console]::Write("Where should new repos live? [$defaultPath]: ")
        $userInput = Read-ConsoleChoice $defaultPath
        if ($userInput) {
            $resolvedReposPath = $userInput -replace '^~', $env:USERPROFILE
        } else {
            $resolvedReposPath = $defaultPath
        }
    } else {
        $resolvedReposPath = Join-Path $env:USERPROFILE "repos"
    }
}

$reposOk = $true
$reposAbs = Resolve-ReposDir $resolvedReposPath
if ($reposAbs) {
    $resolvedReposPath = $reposAbs
    LogOk "Repos directory: $resolvedReposPath"
} else {
    $reposOk = $false   # logged with its ERROR row; Step 5 is skipped
}

# ============================================================
# 4. Detect Google Drive mounts
# ============================================================
Log "Step 4: Google Drive detection"

$drives = @()

if ($SkipDriveDetection) {
    Log "Skipping drive detection (-SkipDriveDetection)"
} else {
    # Google Drive for Desktop uses a virtual filesystem driver that Get-Volume
    # cannot see. Get-PSDrive finds them via Description: "<email> - Google Drive"
    # (or "<email> - Google ..." when truncated for longer emails).
    $gdDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Description -like "* - Google*" }
    foreach ($gd in $gdDrives) {
        $email = ($gd.Description -replace ' - Google.*$', '')
        $myDrive = Join-Path $gd.Root "My Drive"
        if (Test-Path $myDrive) {
            $drives += @{
                path    = $myDrive
                account = $email
                label   = ""
            }
            LogOk "Detected Google Drive: $email -> $myDrive"
        }
    }

    if ($drives.Count -eq 0) {
        # Not a warning: a machine without Google Drive is a supported state (the
        # bash twin logs nothing, or info, for it)
        Log "No Google Drive mounts detected"
    }
}

# ============================================================
# 5. Write config file
# ============================================================
Log "Step 5: Writing config"

# config.json has one writer: setup-user-config.ps1 (bootstrap keys from this
# installer + values derived from profile.json; no node needed, P-Q3).
$configWriter = Join-Path $PSScriptRoot "setup-user-config.ps1"
$configWriterRan = $false   # true: Step 8b passes -SkipConfig (the writer runs once)
if (-not $reposOk) {
    Log "Step 5: skipped -- the repos path is unusable (see the error above); config.json not written"
} elseif (-not (Test-Path $configWriter)) {
    Write-AitError "aitools config" "config.json not written" "setup-user-config.ps1 not found next to the installer"
} else {
    $drivesJson = ConvertTo-Json -InputObject @($drives | ForEach-Object { [ordered]@{ path = $_.path; account = $_.account; label = $_.label } }) -Depth 5 -Compress
    if (-not $drivesJson) { $drivesJson = "[]" }
    $writerArgs = @{ ReposPath = $resolvedReposPath; RepoPath = $aitoolsRepo; DrivesJson = $drivesJson }
    if ($DryRun) { $writerArgs["DryRun"] = $true }
    # In-process like Invoke-ValidatedScript: reset the exit code, catch a throw
    Invoke-ConfigWriter $configWriter $writerArgs
    $configWriterRan = $true
}

# ============================================================
# 6. Install aitools command
# ============================================================
Log "Step 6: Install aitools command"

$localBin = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $localBin)) { New-Item -ItemType Directory -Path $localBin -Force | Out-Null }

# Install bash aitools (for Git Bash compatibility)
$aitoolsSrc = Join-Path $PSScriptRoot "aitools"
$aitoolsDst = Join-Path $localBin "aitools"
if (Test-Path $aitoolsSrc) {
    Copy-Item $aitoolsSrc $aitoolsDst -Force
    LogOk "Installed aitools (bash) to $aitoolsDst"
} else {
    Write-AitWarn "aitools install" "aitools bash source not found at $aitoolsSrc -- skipped (MDM deploy)"
}

# Install PowerShell aitools.ps1 (native Windows CLI)
$aitoolsPs1Src = Join-Path $PSScriptRoot "aitools.ps1"
$aitoolsPs1Dst = Join-Path $localBin "aitools.ps1"
if (Test-Path $aitoolsPs1Src) {
    Copy-Item $aitoolsPs1Src $aitoolsPs1Dst -Force
    LogOk "Installed aitools.ps1 to $aitoolsPs1Dst"
} else {
    Write-AitWarn "aitools install" "aitools.ps1 source not found at $aitoolsPs1Src -- skipped (MDM deploy)"
}

$hhPs1Src = Join-Path $PSScriptRoot "hh.ps1"
$hhPs1Dst = Join-Path $localBin "hh.ps1"
if (Test-Path $hhPs1Src) {
    Copy-Item $hhPs1Src $hhPs1Dst -Force
    LogOk "Installed hh.ps1 to $hhPs1Dst"
} else {
    Write-AitWarn "aitools install" "hh.ps1 not found -- skipped (MDM deploy)"
}

# The harness Python CLIs (.aitools\bin) are deployed by deploy-harness (Step 8b).

# ============================================================
# 7. Shell integration
# ============================================================
Log "Step 7: Shell integration"

# setup-user-shell.ps1 is the single owner of $PROFILE (incident #173): the
# PATH block, the shell integration block (aliases.ps1, aitools, hh) and the
# migration of the legacy "# aitools shell integration" lines.
$shellScript = Join-Path $PSScriptRoot "setup-user-shell.ps1"
if (Test-Path $shellScript) {
    Invoke-ValidatedScript "Step 7" $shellScript
} else {
    Write-AitWarn "shell" "setup-user-shell.ps1 not found -- the PowerShell profile blocks skipped (MDM deploy)"
}

# ============================================================
# 8. Node.js
# ============================================================
# Source: https://nodejs.org
Log "Step 8: Node.js"

if (Get-Command node -ErrorAction SilentlyContinue) {
    LogOk "Node.js already installed ($(node --version))"
    Write-Summary "OK" "node.js" "$(node --version)"
} else {
    Log "Installing Node.js via winget..."
    $wingetOutput = winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $nodeRc = $LASTEXITCODE
    if ($nodeRc -ne 0) {
        # Get-AitErrorReason logs winget's output as detail lines
        Write-AitError "node.js" "winget install of Node.js failed (exit $nodeRc)" (Get-AitErrorReason -Output $wingetOutput -ExitCode $nodeRc)
    } else {
        $wingetOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
    }
    Refresh-Path
    if (Get-Command node -ErrorAction SilentlyContinue) {
        LogOk "Node.js installed ($(node --version))"
        Write-Summary "OK" "node.js" "$(node --version)"
    } elseif ($nodeRc -ne 0) {
        # The failed install is the error (one cause, one red line)
        Log "Step 8: 'node' not found in PATH after the failed winget install"
    } else {
        Write-AitError "node.js" "installed but not on PATH" "restart the terminal and re-run"
    }
}

# ============================================================
# 8b. Deployed harness (%USERPROFILE%\.aitools) -- deploy-harness.ps1
# ============================================================
# After Node (Step 8). deploy-harness fills .aitools\{reference,registries,hooks,
# rules,skills,bin} (bin was this installer's own step before). When Step 5 ran the
# config writer, deploy-harness gets -SkipConfig, so the writer runs once per
# install (OK "config.json" "n/a (written by installer)"). When Step 5 skipped it
# (repos path unusable, writer missing), deploy-harness runs the writer itself.
Log "Step 8b: Deployed harness"

$harnessStepArgs = if ($configWriterRan) { @{ SkipConfig = $true } } else { @{} }
$harnessStepRc = Invoke-HarnessStep (Join-Path $PSScriptRoot "deploy-harness.ps1") $harnessStepArgs
if ($harnessStepRc -eq 2) {
    Complete-AitSummary
    exit 2
}

# ============================================================
# 9. Claude Code CLI
# ============================================================
# Source: https://code.claude.com/docs/en/setup
Log "Step 9: Claude Code CLI"

if (Get-Command claude -ErrorAction SilentlyContinue) {
    LogOk "Claude Code already installed ($(claude --version 2>$null | Select-Object -First 1))"
    Write-Summary "OK" "claude code" "$(claude --version 2>$null | Select-Object -First 1)"
    Log "Running claude update..."
    $claudeOutput = claude update 2>&1 | Out-String
    $updateRc = $LASTEXITCODE
    if ($updateRc -ne 0) {
        # One warning (the tool still works); Get-AitErrorReason logs the output as
        # detail lines
        Write-AitWarn "claude code" ("claude update failed (exit $updateRc): " + (Get-AitErrorReason -Output $claudeOutput -ExitCode $updateRc))
    } else {
        foreach ($updateLine in $claudeOutput.Split("`n")) {
            if ($updateLine.Trim()) { Log $updateLine.TrimEnd() }
        }
        if ($claudeOutput -match '(?i)already.*up.to.date|no update') {
            LogOk "Already up to date"
        } else {
            LogOk "claude update finished"
        }
    }
} else {
    Log "Installing Claude Code CLI..."
    $installOut = ""
    try {
        # Capture every stream of the official installer so its output reaches the log.
        $installOut = Invoke-Expression (Invoke-RestMethod 'https://claude.ai/install.ps1') *>&1 | Out-String
        foreach ($installLine in $installOut.Split("`n")) {
            if ($installLine.Trim()) { Log $installLine.TrimEnd() }
        }
        Refresh-Path
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            LogOk "Claude Code installed ($(claude --version 2>$null | Select-Object -First 1))"
            Write-Summary "OK" "claude code" "$(claude --version 2>$null | Select-Object -First 1)"
        } else {
            # Installed but not on PATH is a functional failure (script standards
            # "External command error handling" 4): an error, as in the bash twin
            Write-AitError "claude code" "installed but not on PATH" "restart the terminal and re-run"
        }
    } catch {
        Write-AitError "claude code" "Claude Code install failed" (Get-AitErrorReason -Output $installOut -ExitCode 1 -ErrorRecord $_)
    }
}

# ============================================================
# 10. Vercel CLI
# ============================================================
Log "Step 10: Vercel CLI"

$vercelScript = Join-Path $PSScriptRoot "setup-vercelcli.ps1"
if (Test-Path $vercelScript) {
    Invoke-ValidatedScript "Step 10" $vercelScript
} else {
    Write-AitWarn "vercel cli" "setup-vercelcli.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 11. Pandoc
# ============================================================
Log "Step 11: Pandoc"

$pandocScript = Join-Path $PSScriptRoot "setup-pandoc.ps1"
if (Test-Path $pandocScript) {
    Invoke-ValidatedScript "Step 11" $pandocScript
} else {
    Write-AitWarn "pandoc" "setup-pandoc.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 12. Rust (cargo)
# ============================================================
Log "Step 12: Rust (cargo)"

$rustScript = Join-Path $PSScriptRoot "setup-rust.ps1"
if (Test-Path $rustScript) {
    Invoke-ValidatedScript "Step 12" $rustScript
} else {
    Write-AitWarn "rust/cargo" "setup-rust.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 13. Typst
# ============================================================
Log "Step 13: Typst"

$typstScript = Join-Path $PSScriptRoot "setup-typst.ps1"
if (Test-Path $typstScript) {
    Invoke-ValidatedScript "Step 13" $typstScript
} else {
    Write-AitWarn "typst" "setup-typst.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 14. uv  (MUST precede Python -- uv is the Python manager)
# ============================================================
Log "Step 14: uv"

$uvScript = Join-Path $PSScriptRoot "setup-uv.ps1"
if (Test-Path $uvScript) {
    Invoke-ValidatedScript "Step 14" $uvScript
} else {
    Write-AitWarn "uv" "setup-uv.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 15. Python  (via uv -- requires Step 14)
# ============================================================
Log "Step 15: Python"

$pythonScript = Join-Path $PSScriptRoot "setup-python.ps1"
if (Test-Path $pythonScript) {
    Invoke-ValidatedScript "Step 15" $pythonScript
} else {
    Write-AitWarn "python" "setup-python.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 15b. pywinpty (Windows test library; macOS/Linux report n/a -- requires Step 15)
# ============================================================
# Parity with aitools-install.sh: the .sh reports "n/a (<platform>)". The pin is
# scripts/requirements-pywinpty.txt, next to the script.
Log "Step 15b: pywinpty"

$pywinptyScript = Join-Path $PSScriptRoot "setup-pywinpty.ps1"
if (Test-Path $pywinptyScript) {
    Invoke-ValidatedScript "Step 15b" $pywinptyScript
} else {
    Write-AitWarn "pywinpty" "setup-pywinpty.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 16. Modal CLI
# ============================================================
Log "Step 16: Modal CLI"

$modalScript = Join-Path $PSScriptRoot "setup-modal.ps1"
if (Test-Path $modalScript) {
    Invoke-ValidatedScript "Step 16" $modalScript
} else {
    Write-AitWarn "modal cli" "setup-modal.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 17. Go
# ============================================================
Log "Step 17: Go"

$goScript = Join-Path $PSScriptRoot "setup-go.ps1"
if (Test-Path $goScript) {
    Invoke-ValidatedScript "Step 17" $goScript
} else {
    Write-AitWarn "go" "setup-go.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 18. Datadog CLI
# ============================================================
Log "Step 18: Datadog CLI"

$datadogScript = Join-Path $PSScriptRoot "setup-datadog.ps1"
if (Test-Path $datadogScript) {
    Invoke-ValidatedScript "Step 18" $datadogScript
} else {
    Write-AitWarn "datadog cli" "setup-datadog.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 19. Perl
# ============================================================
Log "Step 19: Perl"

$perlScript = Join-Path $PSScriptRoot "setup-perl.ps1"
if (Test-Path $perlScript) {
    Invoke-ValidatedScript "Step 19" $perlScript
} else {
    Write-AitWarn "perl" "setup-perl.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 20. Bash
# ============================================================
Log "Step 20: Bash"

$bashScript = Join-Path $PSScriptRoot "setup-bash.ps1"
if (Test-Path $bashScript) {
    Invoke-ValidatedScript "Step 20" $bashScript
} else {
    Write-AitWarn "bash" "setup-bash.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 20b. Google Chrome (managed in the Claude Code web environment only, D-CHR1)
# ============================================================
# Parity with aitools-install.sh (D-ENV8): on Windows the script reports "n/a (local)".
Log "Step 20b: Google Chrome"

$chromeScript = Join-Path $PSScriptRoot "setup-google-chrome.ps1"
if (Test-Path $chromeScript) {
    Invoke-ValidatedScript "Step 20b" $chromeScript
} else {
    Write-AitWarn "google chrome" "setup-google-chrome.ps1 not found -- skipped (MDM deploy)"
}

# ============================================================
# 21. Deploy configurations
# ============================================================
Log "Step 21: Deploy configurations"

$deployScripts = @(
    "setup-user-claude.ps1",
    "setup-user-cursor.ps1",
    "setup-user-mcp.ps1",
    "setup-user-skills.ps1",
    "setup-cursor-ide-mcp.ps1",
    "setup-user-settings.ps1",
    "setup-user-hooks.ps1"
)

foreach ($script in $deployScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    if (Test-Path $scriptPath) {
        Invoke-ValidatedScript "Step 21" $scriptPath
    } else {
        Write-AitWarn (Get-InstallTool $script) "$script not found -- skipped (MDM deploy)"
    }
}

# ============================================================
# 22. Relay → Cursor AGENTS.md (mirror; same as aitools deploy)
# ============================================================
Log "Step 22: Relay → Cursor AGENTS.md mirror"

# Invoke-RelaySync (aitools-lib) logs the sync's output as detail lines and records
# a failure as one warning, "relay sync" (with its reason); nothing more here
$syncPy = Join-Path $PSScriptRoot "sync-relay-to-cursor-agents.py"
if (Test-Path $syncPy) {
    if (-not $DryRun) { $env:AITOOLS_SYNC_DEPLOY_LOG = "1" }
    $target = Join-Path $env:USERPROFILE ".cursor\AGENTS.md"
    $syncArgs = @($syncPy, "--target", $target)
    if ($DryRun) { $syncArgs += "--dry-run" }
    $exitCode = -1
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $exitCode = Invoke-RelaySync "python3" $syncArgs
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $pyArgs = @("-3") + $syncArgs
        $exitCode = Invoke-RelaySync "py" $pyArgs
    } else {
        Write-AitWarn "relay sync" "Python not found -- relay -> AGENTS.md sync skipped"
    }
    if ($exitCode -eq 0 -and $DryRun) { LogOk "relay -> AGENTS.md sync (dry-run)" }
    if (Test-Path Env:\AITOOLS_SYNC_DEPLOY_LOG) { Remove-Item Env:\AITOOLS_SYNC_DEPLOY_LOG }
}

# --- Cleanup ---
if ($DryRun) { Remove-Item Env:\AITOOLS_DRY_RUN -ErrorAction SilentlyContinue }
# The run id this installer set (review B m-2); the footer below keeps it (the lib
# cached it at the first record)
if ($script:InstallSetRunId) {
    Remove-Item Env:\AITOOLS_RUN_ID -ErrorAction SilentlyContinue
    if (Test-Path Env:\AITOOLS_RUN_ID) { LogDetail "AITOOLS_RUN_ID could not be cleared" }
}

# The panel, only when this installer created the run summary file (Start-AitSummary)
Complete-AitSummary

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
