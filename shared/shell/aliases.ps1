# AI Tooling PowerShell aliases -- dot-source from $PROFILE
# Usage: . "$HOME\repos\ai-tooling\shared\shell\aliases.ps1"

function cc {
    if (-not (Test-Path "CLAUDE.md") -and -not (Test-Path "CLAUDE.local.md")) {
        Write-Host "No CLAUDE.md found in $(Get-Location)."
        $answer = Read-Host "Create one with 'claude /init'? [y/N]"
        if ($answer -match '^[Yy]$') {
            claude /init
        }
    }
    claude @args
}

# Quick resume last session
function ccr { claude -c @args }

# Interactive session picker
function ccs { claude --resume @args }
