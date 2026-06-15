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

# --- 4. Pull the user's authoritative dotprofile, then build FROM it ("Tier 2") ---
# The remote aitools-<ghuser> repo -- not this machine -- is the source of truth for
# personalization. Order matters: Step 3 deployed shared-only configs (no dotprofile
# yet), so we (a) 'user init' to clone/pull the dotprofile and set userRepoPath, then
# (b) re-run 'aitools' so build-deploy + the config deploy source the freshly pulled
# dotprofile. Any machine the user provisions converges on the same remote dotprofile.
#
# Interactive only. [Environment]::UserInteractive is false in headless/MDM runs.
$aitoolsCmd = Get-Command aitools -ErrorAction SilentlyContinue
if ([Environment]::UserInteractive -and $aitoolsCmd) {
    Say "Pulling your dotprofile: aitools user init"
    try {
        & aitools user init
        Say "Rebuilding configs from your dotprofile: aitools"
        & aitools
    } catch {
        Say "user init/rebuild skipped/failed -- run 'aitools user init; aitools' later"
    }
} else {
    Say "Skipping dotprofile (non-interactive). Run 'aitools user init; aitools' later."
}

Say "Done. Open a new shell so PATH + aliases take effect."
