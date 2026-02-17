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

# Clipboard HTML -> Markdown (requires pandoc)
function clip2md {
    param([string]$OutFile)
    if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
        Write-Error "clip2md: pandoc not found. Run 'aitools install' or 'winget install --exact --id JohnMacFarlane.Pandoc'"
        return
    }
    Add-Type -AssemblyName System.Windows.Forms
    $raw = [System.Windows.Forms.Clipboard]::GetData("HTML Format")
    if (-not $raw) {
        Write-Error "clip2md: no HTML content on clipboard"
        return
    }
    if ($raw -match '(?s)<!--StartFragment-->(.*)<!--EndFragment-->') {
        $html = $Matches[1]
    } else {
        $html = $raw
    }
    if ($OutFile) {
        $html | pandoc -f html -t markdown -o $OutFile
        Write-Host "Saved to $OutFile"
    } else {
        $html | pandoc -f html -t markdown
    }
}
