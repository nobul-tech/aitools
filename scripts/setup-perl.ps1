# setup-perl.ps1 -- Installs/updates Perl on Windows
# Safe to re-run -- detects existing install and skips if present.
#
# Windows: Uses winget to install Strawberry Perl (preferred).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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

    # Version minimum check: require 5.010+ (a warning when below or unparsable;
    # the perl still works, so its OK status is written either way)
    try {
        $numericVersion = [double]$perlVersion
        if ($numericVersion -lt 5.010) {
            Write-AitWarn "perl" "version $perlVersion is below the minimum 5.010"
        }
    } catch {
        Write-AitWarn "perl" "could not parse version '$perlVersion': $($_.Exception.Message)"
    }
    Write-Summary "OK" "perl" "$perlVersion"
} else {
    Log "Installing Perl (Strawberry Perl) via winget..."
    $wingetOutput = winget install --exact --id StrawberryPerl.StrawberryPerl --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    if ($installRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines
        Write-AitError "perl" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path

    $found = Ensure-ToolOnPath "perl" @(
        "C:\Strawberry\perl\bin\perl.exe"  # Verified: 2026-03-12 (v5.42.0.1)
    )
    if (-not $found -and $installRc -ne 0) {
        # One failed install, one red line: the winget error above is the cause
        Log "perl not found after the failed winget install"
    } elseif (-not $found) {
        Write-AitError "perl" "installed but not on PATH" "found neither on PATH nor at C:\Strawberry\perl\bin\perl.exe"
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
            # Standard 4: one error, plus the remedy as an ACTION
            Write-AitError "perl" "installed but not on PATH" "$perlDir is not in the persistent PATH"
            Write-Summary "ACTION" "" "Add $perlDir to PATH -- perl not accessible"
        } else {
            # Version minimum check: require 5.010+ (a warning when below or
            # unparsable; the OK status either way)
            try {
                $numericVersion = [double]$perlVersion
                if ($numericVersion -lt 5.010) {
                    Write-AitWarn "perl" "version $perlVersion is below the minimum 5.010"
                }
            } catch {
                Write-AitWarn "perl" "could not parse version '$perlVersion': $($_.Exception.Message)"
            }
            Write-Summary "OK" "perl" "$perlVersion"
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
