# setup-user-claude.ps1 — Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run — replaces existing file with latest version.

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

# Remove existing file so we always write the latest version
if (Test-Path $claudeMd) {
    Remove-Item $claudeMd
    Write-Host "Removed existing $claudeMd"
}

# Normalize path for @import (forward slashes)
$importPath = $SharedPath -replace '\\', '/'

$content = @"
@"$importPath"

## Machine-Specific

- Machine: Windows 11 Pro for Workstations
- Shell: PowerShell, Git Bash, WSL/bash
- Google Drive mount: G:\My Drive\
"@

Set-Content -Path $claudeMd -Value $content -Encoding UTF8
Write-Host "Wrote user-level CLAUDE.md at $claudeMd"
Write-Host "It imports shared preferences from: $SharedPath"
