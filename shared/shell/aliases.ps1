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
# Uses temp files to bypass PowerShell pipeline encoding (non-ASCII mangling).
# Fixes .NET clipboard encoding: GetData("HTML Format") decodes UTF-8 bytes
# as Windows-1252, producing mojibake. We reverse-encode via 1252 then
# re-decode as UTF-8 to recover the original characters.
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
    # Fix encoding: .NET decodes the UTF-8 clipboard bytes as Windows-1252,
    # producing mojibake (e.g. em-dash -> a]S, NBSP -> A NBSP). Reverse it:
    # encode back to bytes via 1252, then decode those bytes as UTF-8.
    $win1252 = [System.Text.Encoding]::GetEncoding(1252)
    $rawBytes = $win1252.GetBytes($raw)
    $raw = [System.Text.Encoding]::UTF8.GetString($rawBytes)
    if ($raw -match '(?s)<!--StartFragment-->(.*)<!--EndFragment-->') {
        $html = $Matches[1]
    } else {
        $html = $raw
    }
    # Strip style/class/target attrs and bare div/span wrappers (Gmail noise)
    $html = $html -replace '\s*(style|class|target|saferedirecturl)="[^"]*"', ''
    $html = $html -replace '</?(?:div|span)[^>]*>', ''
    # Replace &nbsp; entities and raw NBSP/narrow NBSP in HTML before pandoc
    $html = $html -replace '&nbsp;', ' ' -replace ([char]0x00A0), ' ' -replace ([char]0x202F), ' '
    # Use temp files to bypass PowerShell pipeline encoding issues
    # (piping pandoc output through PS mangles non-ASCII UTF-8 bytes)
    $tempIn = Join-Path ([System.IO.Path]::GetTempPath()) "clip2md_in.html"
    $tempOut = Join-Path ([System.IO.Path]::GetTempPath()) "clip2md_out.md"
    try {
        [System.IO.File]::WriteAllText($tempIn, $html, [System.Text.UTF8Encoding]::new($false))
        pandoc -f html -t markdown -o $tempOut $tempIn
        $md = [System.IO.File]::ReadAllText($tempOut, [System.Text.UTF8Encoding]::new($false))
    } finally {
        Remove-Item $tempIn, $tempOut -ErrorAction SilentlyContinue
    }
    # Clean up pandoc output: remove empty attr blocks, stray NBSP/narrow NBSP
    $md = $md -replace '\{=""\}', '' -replace ([char]0x00A0), ' ' -replace ([char]0x202F), ' '
    if (-not $md -or $md.Trim().Length -eq 0) {
        Write-Error "clip2md: pandoc produced empty output"
        return
    }
    if ($OutFile) {
        # Resolve relative paths against PowerShell's $PWD, not .NET's CWD
        # ([IO.File]::WriteAllText uses .NET CWD which doesn't track PS cd)
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
        [System.IO.File]::WriteAllText($resolvedPath, $md, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Saved to $resolvedPath"
    } else {
        $md
    }
}
