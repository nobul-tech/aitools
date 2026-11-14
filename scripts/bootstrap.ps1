# bootstrap.ps1 -- One-line remote bootstrap for aitools on Windows.
#
# Usage (fresh machine):
#   irm https://raw.githubusercontent.com/nobul-tech/aitools/main/scripts/bootstrap.ps1 | iex
#
# Ensures git (via winget), clones nobul-tech/aitools, ensures PowerShell 7
# (pwsh, via winget), hands off to scripts/aitools-install.ps1 under pwsh (full
# toolchain + configs), then -- when interactive -- runs `aitools user init` and
# `aitools` under pwsh to pull your dotprofile.
#
# PowerShell 7 (pwsh) is the project baseline (.claude/rules/cross-platform.md):
# the installer and aitools.ps1 always run under pwsh, never under Windows
# PowerShell 5.1. This file itself may run under 5.1 (the stock `irm | iex`
# shell), so it stays ASCII and 5.1-parseable.
#
# Idempotent: if the clone already exists it pulls and reinstalls.
# Override the clone location with $env:AITOOLS_DIR (default: ~\repos\aitools).

$ErrorActionPreference = 'Stop'

$repoUrl    = 'https://github.com/nobul-tech/aitools.git'
$aitoolsDir = if ($env:AITOOLS_DIR) { $env:AITOOLS_DIR } else { Join-Path $HOME 'repos\aitools' }

function Say($m) { Write-Host "[bootstrap] $m" -ForegroundColor Cyan }

# Update-SessionPath -- append the Machine and User PATH entries from the registry
# that this session does not have yet (additive, like Refresh-Path in aitools-lib),
# so a tool winget just installed resolves without a restart.
function Update-SessionPath {
    $have = @{}
    foreach ($d in ($env:Path -split ';')) { if ($d) { $have[$d.ToLowerInvariant()] = $true } }
    $add = @()
    $reg = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
           [System.Environment]::GetEnvironmentVariable('Path', 'User')
    foreach ($d in ($reg -split ';')) {
        if ($d -and -not $have.ContainsKey($d.ToLowerInvariant())) {
            $add += $d
            $have[$d.ToLowerInvariant()] = $true
        }
    }
    if ($add.Count -gt 0) { $env:Path = $env:Path.TrimEnd(';') + ';' + ($add -join ';') }
}

# --- 1. git (the irreducible prerequisite; PowerShell + winget ship with Windows) ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    }
    Say "Installing Git via winget..."
    winget install --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
    Update-SessionPath
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

# --- 3. PowerShell 7 (pwsh): the installer and aitools.ps1 run under it ---
# Install method: the tool registry's preferred Windows method for pwsh (winget,
# Microsoft.PowerShell; /tool-registry skill), the same command the Git Bash
# installer (scripts/aitools-install.sh) runs when pwsh is missing.
$pwshCmd = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue
if (-not $pwshCmd) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "PowerShell 7 (pwsh) not found and winget not found. Install 'App Installer' from the Microsoft Store (or PowerShell 7: https://aka.ms/install-powershell), then re-run."
    }
    Say "Installing PowerShell 7 (pwsh) via winget..."
    winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
    $wingetRc = $LASTEXITCODE
    Update-SessionPath
    $pwshCmd = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue
    if (-not $pwshCmd) {
        throw "PowerShell 7 (pwsh) is still unavailable after winget install (exit $wingetRc) -- restart the terminal and re-run."
    }
}
$pwsh = @($pwshCmd)[0].Source

# --- 4. Install toolchain + deploy configs (machine environment, "Tier 1") ---
Say "Running installer (pwsh: $pwsh)..."
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $aitoolsDir 'scripts\aitools-install.ps1')
if ($LASTEXITCODE -eq 0) {
    Say "Installer completed."
} else {
    Say "Installer reported issues (exit $LASTEXITCODE) -- see the log above before continuing."
}

# --- 5. Pull the user's authoritative dotprofile, then build FROM it ("Tier 2") ---
# The remote aitools-<ghuser> repo -- not this machine -- is the source of truth for
# personalization. Order matters: Step 4 deployed shared-only configs (no dotprofile
# yet), so we (a) 'user init' to clone/pull the dotprofile and set userRepoPath, then
# (b) re-run 'aitools' so build-deploy + the config deploy source the freshly pulled
# dotprofile. Any machine the user provisions converges on the same remote dotprofile.
#
# aitools.ps1 is the file the installer's Step 6 writes (%USERPROFILE%\.local\bin),
# found by path like bootstrap.sh does ($HOME/.local/bin/aitools); run under pwsh.
# Interactive only. [Environment]::UserInteractive is false in headless/MDM runs.
$aitoolsPs1 = Join-Path $env:USERPROFILE '.local\bin\aitools.ps1'
if ([Environment]::UserInteractive -and (Test-Path $aitoolsPs1)) {
    Say "Pulling your dotprofile: aitools user init"
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $aitoolsPs1 user init
    if ($LASTEXITCODE -eq 0) {
        Say "Rebuilding configs from your dotprofile: aitools"
        & $pwsh -NoProfile -ExecutionPolicy Bypass -File $aitoolsPs1
        if ($LASTEXITCODE -ne 0) { Say "rebuild reported issues (exit $LASTEXITCODE) -- see the log above" }
    } else {
        Say "user init skipped/failed (exit $LASTEXITCODE) -- run 'aitools user init; aitools' later"
    }
} else {
    Say "Skipping dotprofile (non-interactive, or $aitoolsPs1 not installed). Run 'aitools user init; aitools' later."
}

Say "Done. Open a new shell so PATH + aliases take effect."
