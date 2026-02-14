# setup-user-claude.ps1 — Creates user-level ~/.claude/CLAUDE.md on Windows
# Safe to re-run — replaces existing file with latest version.

param(
    [string]$SharedPath = (Join-Path $PSScriptRoot "..\shared\claude-shared.md")
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

# Verify shared file exists
if (-not (Test-Path $SharedPath)) {
    Write-Error "Shared preferences not found at: $SharedPath"
    exit 1
}

# Read shared preferences and write inline (Cursor doesn't resolve @import)
$sharedContent = Get-Content -Path $SharedPath -Raw

$content = @"
$sharedContent

## Machine-Specific

- Machine: $([System.Environment]::OSVersion.VersionString) ($env:COMPUTERNAME)
- Shell: bash (Claude Code requires Git Bash on Windows)
"@

Set-Content -Path $claudeMd -Value $content -Encoding UTF8
Write-Host "Wrote user-level CLAUDE.md at $claudeMd"
Write-Host "Inlined shared preferences from: $SharedPath"
