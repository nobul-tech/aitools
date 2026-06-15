# bootstrap.ps1 -- One-line remote bootstrap for aitools on Windows.
#
# Usage (fresh machine):
#   irm https://raw.githubusercontent.com/nobul-tech/aitools/main/scripts/bootstrap.ps1 | iex
#
# Ensures git (via winget), clones nobul-tech/aitools, hands off to
# scripts/aitools-install.ps1 (full toolchain + configs), then -- when interactive --
# runs `aitools user init` to pull your dotprofile.
#
# Idempotent: if the clone already exists it pulls and reinstalls.
# Override the clone location with $env:AITOOLS_DIR (default: ~\repos\aitools).

$ErrorActionPreference = 'Stop'

$repoUrl    = 'https://github.com/nobul-tech/aitools.git'
$aitoolsDir = if ($env:AITOOLS_DIR) { $env:AITOOLS_DIR } else { Join-Path $HOME 'repos\aitools' }

function Say($m) { Write-Host "[bootstrap] $m" -ForegroundColor Cyan }

# --- 1. git (the irreducible prerequisite; PowerShell + winget ship with Windows) ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    }
    Say "Installing Git via winget..."
    winget install --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
    # Refresh PATH for this session so git resolves without a restart.
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is still unavailable after install -- restart the terminal and re-run."
}

# --- 2. Clone or update the repo ---
if (Test-Path (Join-Path $aitoolsDir '.git')) {
    Say "Updating existing clone at $aitoolsDir"
    git -C $aitoolsDir pull --ff-only
} else {
    Say "Cloning $repoUrl -> $aitoolsDir"
    $parent = Split-Path $aitoolsDir -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    git clone $repoUrl $aitoolsDir
}

# --- 3. Install toolchain + deploy configs (machine environment, "Tier 1") ---
Say "Running installer..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $aitoolsDir 'scripts\aitools-install.ps1')

# --- 4. Personalize: pull dotprofile so placeholders/skills/hooks resolve ("Tier 2") ---
# Interactive only. [Environment]::UserInteractive is false in headless/MDM runs.
$aitoolsCmd = Get-Command aitools -ErrorAction SilentlyContinue
if ([Environment]::UserInteractive -and $aitoolsCmd) {
    Say "Personalizing: aitools user init"
    try { & aitools user init }
    catch { Say "user init skipped/failed -- run it later with: aitools user init" }
} else {
    Say "Skipping 'aitools user init' (non-interactive). Run it later to load your dotprofile."
}

Say "Done. Open a new shell so PATH + aliases take effect."
