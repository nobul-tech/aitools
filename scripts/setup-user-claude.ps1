# setup-user-claude.ps1 — Creates user-level ~/.claude/CLAUDE.md on Windows
# Run once per machine. Idempotent (won't overwrite existing file).

param(
    [string]$SharedPath = "G:\My Drive\nobul co\ai-tooling\shared\claude-shared.md"
)

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"

# Ensure ~/.claude/ exists
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    Write-Host "Created $claudeDir"
}

# Don't overwrite existing
if (Test-Path $claudeMd) {
    Write-Host "User-level CLAUDE.md already exists at $claudeMd"
    Write-Host "To regenerate, delete it first and re-run this script."
    exit 0
}

# Normalize path for @import (forward slashes)
$importPath = $SharedPath -replace '\\', '/'

$content = @"
@"$importPath"

## Machine-Specific

- Primary machine: Windows 11 Pro for Workstations
- Shell: PowerShell (primary), Git Bash (secondary)
- Google Drive mount: G:\My Drive\
"@

Set-Content -Path $claudeMd -Value $content -Encoding UTF8
Write-Host "Created user-level CLAUDE.md at $claudeMd"
Write-Host "It imports shared preferences from: $SharedPath"
