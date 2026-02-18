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

# ---------------------------------------------------------------------------
# clip2md -- Clipboard HTML -> Markdown with AI-powered naming
# Requires pandoc. Optional: Claude Code CLI for auto-naming and summaries.
# ---------------------------------------------------------------------------

# Logging helper: appends to %LOCALAPPDATA%\ai-tooling\clip2md.log
function _clip2md_log {
    param([string]$Message)
    try {
        $logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
        if (-not (Test-Path $logDir)) {
            $null = New-Item -ItemType Directory -Path $logDir -Force
        }
        $logFile = Join-Path $logDir "clip2md.log"
        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $line = "[$ts] $Message"
        [System.IO.File]::AppendAllText($logFile, "$line`n", [System.Text.UTF8Encoding]::new($false))
    } catch {
        # Logging should never crash the caller
    }
}

# AI helper: calls claude -p for filename + summary
# Returns hashtable @{ Filename = ...; Summary = ... } or $null on failure.
function _clip2md_ai {
    param(
        [string]$Markdown,
        [switch]$SummaryOnly
    )
    $prompt = @"
Name this clipboard content saved as markdown. Analyze the actual body, not just headers or subject lines.

Filename rules:
- Lowercase, digits, hyphens only. No extension. Max 50 chars but shorter is better.
- Adapt to content type:
  Email/thread: compact-date-participant-topic (e.g. 250324-garcia-budget-review)
  Article/blog: source-topic (e.g. verge-ai-pricing)
  Docs: product-section (e.g. aws-iam-roles)
  Other: descriptive topic
- Dates: YYMMDD (e.g. 250324). Omit date if content has none.
- Be compact. Do not pad to fill 50 chars.

Summary: one line, max 80 chars, what the content is actually about.

Respond in EXACTLY this format with nothing else:
FILENAME|SUMMARY
"@
    $resultRaw = $Markdown | & claude -p $prompt 2>$null
    $claudeExit = $LASTEXITCODE
    if ($claudeExit -ne 0) { return $null }

    # Normalize to single string
    if ($resultRaw -is [array]) { $resultRaw = $resultRaw -join '' }
    if (-not $resultRaw) { return $null }
    $resultRaw = $resultRaw.Trim()
    if ($resultRaw.Length -eq 0) { return $null }

    # Parse on first pipe character
    $pipeIdx = $resultRaw.IndexOf('|')
    if ($pipeIdx -ge 0) {
        $rawName = $resultRaw.Substring(0, $pipeIdx).Trim()
        $rawSummary = $resultRaw.Substring($pipeIdx + 1).Trim()
    } else {
        $rawName = $resultRaw
        $rawSummary = ''
    }

    # Truncate summary to 80 chars at word boundary
    if ($rawSummary.Length -gt 80) {
        $lastSpace = $rawSummary.LastIndexOf(' ', 80)
        if ($lastSpace -gt 0) { $rawSummary = $rawSummary.Substring(0, $lastSpace) }
        else { $rawSummary = $rawSummary.Substring(0, 80) }
    }

    if ($SummaryOnly) {
        return @{ Filename = $null; Summary = $rawSummary }
    }

    # Sanitize filename: lowercase, alnum + hyphens only
    $name = $rawName.ToLower()
    $name = $name -replace '[^a-z0-9-]', '-'
    $name = $name -replace '-+', '-'
    $name = $name.TrimStart('-').TrimEnd('-')

    # Truncate to 50 chars at hyphen boundary
    if ($name.Length -gt 50) {
        $lastHyphen = $name.LastIndexOf('-', 50)
        if ($lastHyphen -gt 0) { $name = $name.Substring(0, $lastHyphen) }
        else { $name = $name.Substring(0, 50) }
        $name = $name.TrimEnd('-')
    }

    if (-not $name) { $name = 'clipboard' }

    # Windows reserved names
    $reserved = @('con','prn','aux','nul',
        'com1','com2','com3','com4','com5','com6','com7','com8','com9',
        'lpt1','lpt2','lpt3','lpt4','lpt5','lpt6','lpt7','lpt8','lpt9')
    if ($reserved -contains $name) { $name = "clip-$name" }

    return @{ Filename = $name; Summary = $rawSummary }
}

# Clipboard HTML -> Markdown (requires pandoc)
# Uses temp files to bypass PowerShell pipeline encoding (non-ASCII mangling).
# Fixes .NET clipboard encoding: GetData("HTML Format") decodes UTF-8 bytes
# as Windows-1252, producing mojibake. We reverse-encode via 1252 then
# re-decode as UTF-8 to recover the original characters.
function clip2md {
    # Join all args as the output filename (supports "My Notes" without quotes)
    $OutFile = ''
    if ($args.Count -gt 0) {
        $OutFile = ($args | ForEach-Object { "$_" }) -join ' '
        $OutFile = $OutFile.Trim()
    }

    # 1. Check pandoc
    if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
        Write-Error "clip2md: pandoc not found. Run 'aitools install' or 'winget install --exact --id JohnMacFarlane.Pandoc'"
        _clip2md_log "error: pandoc not found"
        return
    }

    # 2. Extract clipboard HTML
    Add-Type -AssemblyName System.Windows.Forms
    $raw = [System.Windows.Forms.Clipboard]::GetData("HTML Format")
    if (-not $raw) {
        Write-Warning "clip2md: no HTML content on clipboard"
        _clip2md_log "warning: no HTML content on clipboard"
        return
    }

    # 3. Fix encoding: .NET decodes UTF-8 clipboard bytes as Windows-1252
    $win1252 = [System.Text.Encoding]::GetEncoding(1252)
    $rawBytes = $win1252.GetBytes($raw)
    $raw = [System.Text.Encoding]::UTF8.GetString($rawBytes)
    if ($raw -match '(?s)<!--StartFragment-->(.*)<!--EndFragment-->') {
        $html = $Matches[1]
    } else {
        $html = $raw
    }

    # 4. Strip Gmail noise (attrs, divs, nbsp)
    $html = $html -replace '\s*(style|class|target|saferedirecturl)="[^"]*"', ''
    $html = $html -replace '</?(?:div|span)[^>]*>', ''
    $html = $html -replace '&nbsp;', ' ' -replace ([char]0x00A0), ' ' -replace ([char]0x202F), ' '

    # 5. Convert via pandoc (temp files to bypass pipeline encoding)
    $tempIn = Join-Path ([System.IO.Path]::GetTempPath()) "clip2md_in.html"
    $tempOut = Join-Path ([System.IO.Path]::GetTempPath()) "clip2md_out.md"
    try {
        [System.IO.File]::WriteAllText($tempIn, $html, [System.Text.UTF8Encoding]::new($false))
        pandoc -f html -t markdown -o $tempOut $tempIn
        $md = [System.IO.File]::ReadAllText($tempOut, [System.Text.UTF8Encoding]::new($false))
    } finally {
        Remove-Item $tempIn, $tempOut -ErrorAction SilentlyContinue
    }

    # 6. Clean pandoc output (attr blocks, NBSP)
    $md = $md -replace '\{=""\}', '' -replace ([char]0x00A0), ' ' -replace ([char]0x202F), ' '
    if (-not $md -or $md.Trim().Length -eq 0) {
        Write-Error "clip2md: pandoc produced empty output"
        _clip2md_log "error: pandoc produced empty output"
        return
    }

    # Word count (approximate, rounded to nearest 10)
    $wordCount = @($md -split '\s+' | Where-Object { $_ }).Count
    $approxWords = [math]::Round($wordCount / 10) * 10
    if ($approxWords -eq 0 -and $wordCount -gt 0) { $approxWords = $wordCount }

    # 7. Determine mode
    if (-not $OutFile) {
        # --- AUTO-NAME MODE ---
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Write-Error "clip2md: auto-naming requires Claude Code CLI. Provide a filename or install claude."
            _clip2md_log "error: autoname requires Claude Code CLI"
            return
        }

        $randNum = Get-Random
        $tempName = ".clip2md-$randNum.tmp"
        $tempMdPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($tempName)

        try {
            [System.IO.File]::WriteAllText($tempMdPath, $md, [System.Text.UTF8Encoding]::new($false))
            _clip2md_log "wrote temp $tempName"

            # Call claude for filename + summary
            $ai = _clip2md_ai -Markdown $md
            if (-not $ai -or -not $ai.Filename) {
                Write-Error "clip2md: claude failed to generate filename"
                _clip2md_log "error: claude failed"
                return
            }

            $baseName = $ai.Filename
            $summary = $ai.Summary

            # Collision avoidance
            $finalName = "$baseName.md"
            $counter = 2
            while (Test-Path $finalName) {
                $finalName = "$baseName-$counter.md"
                $counter++
                if ($counter -gt 100) { break }
            }

            $finalPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($finalName)
            Move-Item -Path $tempMdPath -Destination $finalPath -Force
            $tempMdPath = $null
            _clip2md_log "renamed $tempName -> $finalName"

            Write-Host "Saved $finalName (HTML, ~$approxWords words)"
            if ($summary) { Write-Host "  $summary" }
            _clip2md_log "saved $finalName (HTML, ~$approxWords words)"
        } finally {
            if ($tempMdPath -and (Test-Path $tempMdPath)) {
                Remove-Item $tempMdPath -ErrorAction SilentlyContinue
                _clip2md_log "cleanup: removed $tempName"
            }
        }
    } else {
        # --- EXPLICIT NAME MODE ---
        # Ensure .md extension (strip if present, re-add)
        if ($OutFile -match '\.md$') {
            $name = $OutFile
        } else {
            $name = "$OutFile.md"
        }

        # Check overwrite
        if (Test-Path $name) {
            $answer = Read-Host "$name exists. Overwrite? [y/N]"
            if ($answer -notmatch '^[Yy]$') {
                Write-Host "Aborted."
                _clip2md_log "aborted: user declined overwrite of $name"
                return
            }
        }

        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($name)
        [System.IO.File]::WriteAllText($resolvedPath, $md, [System.Text.UTF8Encoding]::new($false))

        # Try AI summary if claude available
        $summary = $null
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            $ai = _clip2md_ai -Markdown $md -SummaryOnly
            if ($ai -and $ai.Summary) { $summary = $ai.Summary }
        }

        Write-Host "Saved $name (HTML, ~$approxWords words)"
        if ($summary) { Write-Host "  $summary" }
        _clip2md_log "saved $name (HTML, ~$approxWords words)"
    }
}
