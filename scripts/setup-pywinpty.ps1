# setup-pywinpty.ps1 -- Installs pywinpty (ConPTY backend for the pty test runner,
# tests/managed-files/pty-run.py) into the Python user site on Windows, wheel only and
# hash-pinned. The stdlib pty module is POSIX-only; setup-pywinpty.sh reports n/a there.
# Safe to re-run -- verifies an importable pywinpty at the pinned version and changes
# nothing then; otherwise pip moves the user site to the pinned version.
# Platform: Windows 11 (environment always local). Non-interactive: never prompts.
# Install source, version and health flags: the /tool-registry skill, entry "pywinpty".
# Evaluation: reference/evaluations/pywinpty-windows-2026-11-13.md.
#
# Command (commander, RFI fa81-7, 2026-11-14; the last two flags only silence pip):
#   <python> -m pip install --user --only-binary=:all: --require-hashes
#            --disable-pip-version-check --no-input -r <pin>
# Never --break-system-packages, never --target: an EXTERNALLY-MANAGED interpreter
# (PEP 668) is reported as WARN + ACTION and left untouched.
#
# Writes: the pywinpty package in the interpreter's user site (%APPDATA%\Python\PythonXY\
#   site-packages) through pip. No config file is written.
#
# Pin (single source of truth: scripts/requirements-pywinpty.txt), first found wins:
#   1. $env:AITOOLS_PYWINPTY_PIN -- a path (tests); set but missing is an ERROR
#   2. requirements-pywinpty.txt next to this script (dev path, package path)
#   3. $AitoolsEmbeddedPywinptyPin -- defined only in the MDM copy: build-deploy.sh
#      appends it right after the inlined library; written to a temp file for pip
#   The version comes from the "pywinpty==X.Y.Z" line, the covered interpreter tags
#   from the "# wheel-tags:" line.
#
# Interpreter: the one the pty suites use. They call python3 (bash and pwsh suites), so
# python3 is tried first (first match on PATH, which must run: the Microsoft Store
# WindowsApps stub does not), then python. On CI (actions/setup-python) and on a
# PyManager workstation both names resolve to the same interpreter. aitools install
# Step 15 makes python3 the uv-managed CPython, which is EXTERNALLY-MANAGED: pip
# refuses it (WARN + ACTION). The user site is shared by every CPython of one
# major.minor, so the remedy is one run with a non-managed CPython of that version:
#   $env:AITOOLS_PYWINPTY_PYTHON='<path>\python.exe'; pwsh -File scripts\setup-pywinpty.ps1
# AITOOLS_PYWINPTY_PYTHON is that documented remedy and the test override; when it is
# set, only that interpreter is used.
#
# Usage: setup-pywinpty.ps1 [-DryRun]   (AITOOLS_DRY_RUN=1 is the same)

param(
    [switch]$DryRun
)

# Env passthrough from parent (aitools CLI)
if ($env:AITOOLS_DRY_RUN -eq "1") { $DryRun = [switch]::Present }

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-pywinpty"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

if ($DryRun) { Log "[DRY RUN] Preview mode -- nothing will be installed" }

# Summary detail: at most 30 characters (script-standards).
function Get-ShortDetail([string]$Text) {
    if ($Text.Length -gt 30) { return $Text.Substring(0, 27) + "..." }
    return $Text
}

# Run an interpreter; returns @{ Code; Lines }. Every output line (stdout and stderr) is
# logged as detail. An interpreter that cannot be started returns Code -1 (logged).
function Invoke-Python {
    param([string]$Python, [string]$Label, [string[]]$Arguments)
    $lines = @()
    try {
        $raw = & $Python @Arguments 2>&1
        $code = $LASTEXITCODE
    } catch {
        LogDetail "${Label}: could not start ${Python}: $_"
        return @{ Code = -1; Lines = @() }
    }
    if ($null -eq $code) { $code = -1 }
    foreach ($r in @($raw)) { $lines += "$r".TrimEnd() }
    foreach ($l in $lines) { if ($l.Trim()) { LogDetail "${Label}: $l" } }
    LogDetail "${Label}: exit $code"
    return @{ Code = $code; Lines = $lines }
}

# key=value output lines -> hashtable
function ConvertFrom-KeyValueLines([string[]]$Lines) {
    $map = @{}
    foreach ($l in $Lines) {
        if ($l -match '^([a-z_]+)=(.*)$') { $map[$Matches[1]] = $Matches[2] }
    }
    return $map
}

# Python one-liners. No double quotes inside (native argument passing). '' and '.' are
# dropped from sys.path so a winpty module in the current directory cannot pass as installed.
$probeCode = @'
import sys, os, site, sysconfig; tag = 'cp%d%d' % sys.version_info[:2] + ('t' if sysconfig.get_config_var('Py_GIL_DISABLED') else '') + '-' + sysconfig.get_platform().replace('-', '_').replace('.', '_'); print('version=' + sys.version.split()[0]); print('majmin=%d.%d' % sys.version_info[:2]); print('executable=' + sys.executable); print('tag=' + tag); print('venv=' + str(sys.prefix != sys.base_prefix)); print('externally_managed=' + str(os.path.isfile(os.path.join(sysconfig.get_path('stdlib'), 'EXTERNALLY-MANAGED')))); print('user_site=' + str(site.getusersitepackages())); print('user_site_enabled=' + str(site.ENABLE_USER_SITE))
'@
$importCode = @'
import sys; sys.path[:] = [p for p in sys.path if p not in ('', '.')]; import importlib.metadata as m, winpty; print('version=' + m.version('pywinpty')); print('file=' + winpty.__file__)
'@

# WARN + ACTION for an EXTERNALLY-MANAGED interpreter (marker found, or pip refused).
function Write-ExternallyManaged {
    param([string]$Python, [string]$MajMin, [string]$UserSite)
    LogWarn "$Python is EXTERNALLY-MANAGED (PEP 668): pip refuses to install into it, --user included. Not overridden (--break-system-packages is never used)."
    Write-Summary "WARN" "pywinpty" "python externally managed"
    $action = 'Run once with a non-managed CPython ' + $MajMin + ' (python.org or PyManager): $env:AITOOLS_PYWINPTY_PYTHON=''<path>\python.exe''; pwsh -File ' + $PSCommandPath + ' -- its --user install lands in ' + $UserSite + ', which ' + $Python + ' also reads'
    LogWarn $action
    Write-Summary "ACTION" "" $action
}

# WARN + ACTION for a virtual-environment interpreter (pip refuses --user there).
function Write-VenvRefused {
    param([string]$Python, [string]$MajMin)
    LogWarn "$Python runs in a virtual environment: pip refuses --user there, and a venv does not read the user site"
    Write-Summary "WARN" "pywinpty" "venv python, --user refused"
    $action = 'Deactivate the virtual environment so python3 is a base CPython ' + $MajMin + ' (or set $env:AITOOLS_PYWINPTY_PYTHON to one), then re-run ' + $PSCommandPath
    LogWarn $action
    Write-Summary "ACTION" "" $action
}

$script:pinTempFile = $null

function Invoke-PywinptySetup {
    # --- 1. Pin ---
    $pinPath = $null
    if ($env:AITOOLS_PYWINPTY_PIN) {
        if (Test-Path -LiteralPath $env:AITOOLS_PYWINPTY_PIN -PathType Leaf) {
            $pinPath = $env:AITOOLS_PYWINPTY_PIN
            Log "Pin: $pinPath (AITOOLS_PYWINPTY_PIN)"
        } else {
            LogError "AITOOLS_PYWINPTY_PIN is set but the file does not exist: $env:AITOOLS_PYWINPTY_PIN"
            Write-Summary "ERROR" "pywinpty" "pin file missing"
            return
        }
    } else {
        $repoPin = Join-Path $PSScriptRoot "requirements-pywinpty.txt"
        if (Test-Path -LiteralPath $repoPin -PathType Leaf) {
            $pinPath = $repoPin
            Log "Pin: $pinPath (next to this script)"
        } else {
            # Defined only in the MDM copy. Undefined (dev, package) -> $null, checked below.
            $embedded = Get-Variable -Name AitoolsEmbeddedPywinptyPin -Scope Script -ValueOnly -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($embedded)) {
                LogError "No pywinpty pin: AITOOLS_PYWINPTY_PIN unset, $repoPin missing, no embedded pin"
                Write-Summary "ERROR" "pywinpty" "pin file missing"
                return
            }
            try {
                $script:pinTempFile = [IO.Path]::GetTempFileName()
                [IO.File]::WriteAllText($script:pinTempFile, $embedded, [Text.UTF8Encoding]::new($false))
            } catch {
                LogError "Could not write the embedded pin to a temp file: $_"
                Write-Summary "ERROR" "pywinpty" "pin temp file failed"
                return
            }
            $pinPath = $script:pinTempFile
            Log "Pin: embedded in this script (written to $pinPath)"
        }
    }

    try {
        $pinText = [IO.File]::ReadAllText($pinPath)
    } catch {
        LogError "Could not read the pin $pinPath : $_"
        Write-Summary "ERROR" "pywinpty" "pin file unreadable"
        return
    }
    $pinVersion = $null
    $tags = @()
    foreach ($line in ($pinText -split '\r?\n')) {
        if (-not $pinVersion -and $line -match '^\s*pywinpty==([0-9][0-9A-Za-z.]*)') { $pinVersion = $Matches[1] }
        if ($line -match '^\s*#\s*wheel-tags:\s*(.+?)\s*$') {
            $tags += @($Matches[1] -split '\s+' | Where-Object { $_ })
        }
    }
    $badTags = @($tags | Where-Object { $_ -notmatch '^cp\d+t?-win_(amd64|arm64)$' })
    if (-not $pinVersion -or $tags.Count -eq 0 -or $badTags.Count -gt 0) {
        LogError "Pin $pinPath unreadable: version '$pinVersion', wheel tags '$($tags -join ' ')' (invalid: '$($badTags -join ' ')')"
        Write-Summary "ERROR" "pywinpty" "pin file unreadable"
        return
    }
    Log "Pinned pywinpty $pinVersion for: $($tags -join ' ')"

    # --- 2. Interpreter ---
    $candidates = @()
    if ($env:AITOOLS_PYWINPTY_PYTHON) {
        $candidates += [pscustomobject]@{ Name = "AITOOLS_PYWINPTY_PYTHON"; Path = $env:AITOOLS_PYWINPTY_PYTHON }
    } else {
        foreach ($name in @("python3", "python")) {
            # Get-Command exempt: command-existence check; a missing name falls through to the next
            $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) {
                $candidates += [pscustomobject]@{ Name = $name; Path = $cmd.Source }
            } else {
                Log "$name not on PATH"
            }
        }
    }
    $py = $null
    foreach ($c in $candidates) {
        $r = Invoke-Python -Python $c.Path -Label "run $($c.Name)" -Arguments @("-c", "import sys; print(sys.version.split()[0])")
        if ($r.Code -eq 0 -and $r.Lines.Count -gt 0 -and $r.Lines[0] -match '^\d+\.\d+') {
            $py = $c.Path
            Log "Interpreter: $($c.Name) -> $py (Python $($r.Lines[0]))"
            break
        }
        Log "$($c.Name) at $($c.Path) does not run (exit $($r.Code)) -- not used"
    }
    if (-not $py) {
        $tried = ($candidates | ForEach-Object { "$($_.Name)=$($_.Path)" }) -join ', '
        if (-not $tried) { $tried = "neither python3 nor python on PATH" }
        LogWarn "No working Python interpreter (tried: $tried) -- pywinpty needs one"
        Write-Summary "WARN" "pywinpty" "python not found"
        $action = "Run aitools install (Step 15 Python), then re-run $PSCommandPath"
        LogWarn $action
        Write-Summary "ACTION" "" $action
        return
    }

    $probe = Invoke-Python -Python $py -Label "probe" -Arguments @("-c", $probeCode)
    $info = ConvertFrom-KeyValueLines $probe.Lines
    if ($probe.Code -ne 0 -or -not $info['tag'] -or -not $info['majmin']) {
        LogError "Interpreter probe of $py failed (exit $($probe.Code)) -- see $logFile"
        Write-Summary "ERROR" "pywinpty" "python probe failed"
        return
    }
    Log "Python $($info['version']) ($($info['tag'])) at $($info['executable']); user site $($info['user_site']) (enabled: $($info['user_site_enabled']))"

    # --- 3. Already installed at the pinned version? (before every refusal check: a
    # verified install changes nothing, whatever the interpreter's install policy) ---
    $imp = Invoke-Python -Python $py -Label "import check" -Arguments @("-c", $importCode)
    $impInfo = ConvertFrom-KeyValueLines $imp.Lines
    $installed = $null
    if ($imp.Code -eq 0) { $installed = $impInfo['version'] }
    if ($installed -and $installed -eq $pinVersion) {
        LogOk "pywinpty $pinVersion verified (winpty at $($impInfo['file']))"
        Write-Summary "OK" "pywinpty" "$pinVersion (verified)"
        return
    }
    if ($installed) {
        Log "pywinpty $installed is installed (winpty at $($impInfo['file'])); pinned $pinVersion -- pip moves it to the pinned version"
    } else {
        Log "pywinpty is not importable by $py"
    }

    # --- 4. Wheel tag covered by the pin? ---
    if ($tags -notcontains $info['tag']) {
        LogWarn "No pinned pywinpty wheel for $($info['tag']) (Python $($info['version']) at $py); the pin covers: $($tags -join ' ')"
        Write-Summary "WARN" "pywinpty" (Get-ShortDetail "no wheel for $($info['tag'])")
        $action = "Python $($info['version']) ($($info['tag'])) has no pinned pywinpty wheel (pinned: $($tags -join ', ')) -- use a covered CPython as python3 (or set AITOOLS_PYWINPTY_PYTHON), then re-run $PSCommandPath"
        LogWarn $action
        Write-Summary "ACTION" "" $action
        return
    }

    # --- 5. Can pip install --user into it? ---
    if ($info['venv'] -eq 'True') {
        Write-VenvRefused -Python $py -MajMin $info['majmin']
        return
    }
    if ($info['externally_managed'] -eq 'True') {
        Write-ExternallyManaged -Python $py -MajMin $info['majmin'] -UserSite $info['user_site']
        return
    }

    # --- 6. Install ---
    $pipArgs = @("-m", "pip", "install", "--user", "--only-binary=:all:", "--require-hashes",
                 "--disable-pip-version-check", "--no-input", "-r", $pinPath)
    $pipCmdText = "$py " + ($pipArgs -join ' ')
    if ($DryRun) {
        Log "[DRY RUN] Would run: $pipCmdText"
        Write-Summary "OK" "pywinpty" "dry-run: would install $pinVersion"
        return
    }
    Log "Running: $pipCmdText"
    $pip = Invoke-Python -Python $py -Label "pip install" -Arguments $pipArgs
    $pipText = $pip.Lines -join "`n"
    if ($pip.Code -ne 0) {
        if ($pipText -match 'externally-managed-environment') {
            Write-ExternallyManaged -Python $py -MajMin $info['majmin'] -UserSite $info['user_site']
        } elseif ($pipText -match "Can not perform a '--user' install") {
            Write-VenvRefused -Python $py -MajMin $info['majmin']
        } elseif ($pipText -match 'No module named pip') {
            LogError "$py has no pip module (exit $($pip.Code))"
            Write-Summary "ERROR" "pywinpty" "pip not available"
            $action = "$py -m ensurepip --upgrade, then re-run $PSCommandPath"
            LogWarn $action
            Write-Summary "ACTION" "" $action
        } else {
            LogError "pip install failed (exit $($pip.Code)) -- see $logFile"
            Write-Summary "ERROR" "pywinpty" (Get-ShortDetail "pip install failed (exit $($pip.Code))")
        }
        return
    }
    $outcome = "installed"
    if ($pipText -match 'Successfully installed') {
        Log "pip: Successfully installed pywinpty $pinVersion"
    } elseif ($pipText -match 'Requirement already satisfied') {
        $outcome = "already present"
        Log "pip: Requirement already satisfied (pywinpty $pinVersion)"
    } else {
        Log "pip exited 0 without 'Successfully installed' or 'Requirement already satisfied' -- verifying the import"
    }

    # --- 7. Verify ---
    $imp2 = Invoke-Python -Python $py -Label "import verify" -Arguments @("-c", $importCode)
    $imp2Info = ConvertFrom-KeyValueLines $imp2.Lines
    if ($imp2.Code -eq 0 -and $imp2Info['version'] -eq $pinVersion) {
        LogOk "pywinpty $pinVersion $outcome (winpty at $($imp2Info['file']))"
        Write-Summary "OK" "pywinpty" "$pinVersion ($outcome)"
    } else {
        LogError "pywinpty $pinVersion not importable by $py after pip (exit $($imp2.Code), version '$($imp2Info['version'])') -- see $logFile"
        Write-Summary "ERROR" "pywinpty" "import failed after install"
    }
}

try {
    Invoke-PywinptySetup
} finally {
    if ($script:pinTempFile -and (Test-Path -LiteralPath $script:pinTempFile)) {
        try {
            Remove-Item -LiteralPath $script:pinTempFile -Force -ErrorAction Stop
            LogDetail "Removed temp pin $($script:pinTempFile)"
        } catch {
            LogWarn "Could not remove temp pin $($script:pinTempFile): $_"
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
