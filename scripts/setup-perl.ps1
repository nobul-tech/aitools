# setup-perl.ps1 -- Installs/updates Perl on Windows
# Safe to re-run -- detects existing install and skips if present.
#
# Windows: Uses winget to install Strawberry Perl (preferred).
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-perl"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Install/update ---
if (Get-Command perl -ErrorAction SilentlyContinue) {
    # Already installed -- get version info
    $perlVersion = (perl -e "print $];" 2>&1)
    $perlPath = (Get-Command perl).Source
    LogOk "Perl already installed (version $perlVersion)"
    Log "Install path: $perlPath"

    # Version minimum check: require 5.010+
    try {
        $numericVersion = [double]$perlVersion
        if ($numericVersion -lt 5.010) {
            LogWarn "Perl version $perlVersion is below minimum 5.010"
            Write-Summary "WARN" "perl" "$perlVersion (below minimum 5.010)"
        } else {
            Write-Summary "OK" "perl" "$perlVersion"
        }
    } catch {
        LogWarn "Could not parse Perl version: $perlVersion"
        Write-Summary "WARN" "perl" "$perlVersion (version parse failed)"
    }
} else {
    Log "Installing Perl (Strawberry Perl) via winget..."
    $wingetOutput = winget install --exact --id StrawberryPerl.StrawberryPerl --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
    Log-WingetOutput $wingetOutput
    if ($LASTEXITCODE -ne 0) {
        LogError "winget install failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "perl" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path

    $found = Ensure-ToolOnPath "perl" @(
        "C:\Strawberry\perl\bin\perl.exe"  # Verified: 2026-03-12 (v5.42.0.1)
    )
    if (-not $found) {
        LogError "Perl not found on PATH after install"
        Write-Summary "ERROR" "perl" "installed but not on PATH"
        Write-Summary "ACTION" "" "Add Strawberry Perl bin to PATH -- perl not accessible"
    } else {
        $perlVersion = (perl -e "print $];" 2>&1)
        $perlPath = (Get-Command perl).Source
        LogOk "Perl installed (version $perlVersion)"
        Log "Install path: $perlPath"

        # Verify the install directory is in persistent PATH
        $perlDir = Split-Path $perlPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$perlDir*") {
            LogError "Perl install dir not in persistent PATH: $perlDir"
            Write-Summary "ERROR" "perl" "installed but not on PATH"
            LogWarn "Add $perlDir to PATH -- tool not accessible to Claude Code"
            Write-Summary "ACTION" "" "Add $perlDir to PATH -- perl not accessible"
        } else {
            # Version minimum check: require 5.010+
            try {
                $numericVersion = [double]$perlVersion
                if ($numericVersion -lt 5.010) {
                    LogWarn "Perl version $perlVersion is below minimum 5.010"
                    Write-Summary "WARN" "perl" "$perlVersion (below minimum 5.010)"
                } else {
                    Write-Summary "OK" "perl" "$perlVersion"
                }
            } catch {
                LogWarn "Could not parse Perl version: $perlVersion"
                Write-Summary "WARN" "perl" "$perlVersion (version parse failed)"
            }
        }
    }
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
