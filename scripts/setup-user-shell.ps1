# setup-user-shell.ps1 -- Owns the aitools managed PATH block in the PowerShell profile (Windows)
# Safe to re-run -- idempotent.
# UNTESTED on Windows: authored on macOS; no pwsh available to parse-check. Mirror of setup-user-shell.sh.
#
# The harness must resolve managed tools (uv python shims, cursor-agent, aitools
# shims) deterministically. This script writes a marked block
#   # >>> aitools managed >>>  ...  # <<< aitools managed <<<
# into the user's PowerShell profile ($PROFILE). The block prepends
# $HOME\.local\bin -- the aitools/uv bin dir (aitools-install.ps1 installs its
# shims there) -- so managed copies win for interactive PowerShell sessions.
#
# Mirrors setup-user-shell.sh. The macOS/Linux login-profile equivalent owns
# ~/.bash_profile; on Windows the analog is $PROFILE.
#
# Block re-applied idempotently (replaced in place if markers already present).
#
# Testing: set $env:AITOOLS_PROFILE_PATH to operate on a scratch profile path
# instead of $PROFILE.
#
# See plans/tooling-resolution-and-artifact-registry.md (Workstream A).

# --- Shared library ---
. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "setup-user-shell"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Target profile (overridable for testing) ---
$profilePath = if ($env:AITOOLS_PROFILE_PATH) { $env:AITOOLS_PROFILE_PATH } else { $PROFILE }

$startMarker = "# >>> aitools managed >>>"
$endMarker = "# <<< aitools managed <<<"

# --- The managed block (identical across machines) ---
# Prepends the aitools/uv bin dir so managed tools win for the session.
$block = @"
$startMarker
# Owned by aitools (scripts/setup-user-shell.ps1). Edit via the script, not by hand.
`$__aitoolsLocalBin = Join-Path `$HOME ".local\bin"
if ((Test-Path `$__aitoolsLocalBin) -and (`$env:PATH -split ';')[0] -ne `$__aitoolsLocalBin) {
    `$env:PATH = "`$__aitoolsLocalBin;`$env:PATH"
}
$endMarker
"@

# --- Ensure profile directory exists ---
$profileDir = Split-Path $profilePath -Parent
if ($profileDir -and -not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# --- Back up before writing (skips internally if profile does not exist) ---
Backup-File $profilePath

# --- Detect prior state for accurate reporting ---
$hadBlock = $false
$content = ""
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    if ($null -eq $content) { $content = "" }
    if ($content -match [regex]::Escape($startMarker)) { $hadBlock = $true }
}

# --- Splice the block in (replace in place if present, else append at EOF) ---
$pattern = [regex]::Escape($startMarker) + "(?s).*?" + [regex]::Escape($endMarker) + "(\r?\n)?"
if ($hadBlock) {
    $newContent = [regex]::Replace($content, $pattern, ($block + "`n"))
} else {
    if ($content.Length -gt 0 -and $content -notmatch "(\r?\n)$") { $content += "`n" }
    $newContent = $content + $block + "`n"
}

try {
    Set-Content -Path $profilePath -Value $newContent -NoNewline
} catch {
    LogError "Failed to write managed block to $profilePath : $_"
    Write-Summary "ERROR" "shell" "managed block write failed"
    exit 1
}

# --- Post-write validation: markers present ---
$written = Get-Content $profilePath -Raw
if (($written -notmatch [regex]::Escape($startMarker)) -or ($written -notmatch [regex]::Escape($endMarker))) {
    LogError "Managed block markers missing after write -- $profilePath"
    Write-Summary "ERROR" "shell" "managed block markers missing"
    exit 1
}

if ($hadBlock) {
    LogOk "Refreshed managed block in $profilePath"
    Write-Summary "OK" "shell" "managed block refreshed"
} else {
    LogOk "Added managed block to $profilePath"
    Write-Summary "OK" "shell" "managed block added"
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s)" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
