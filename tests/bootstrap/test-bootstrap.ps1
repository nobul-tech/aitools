# test-bootstrap.ps1 -- tests for scripts/bootstrap.ps1, the Windows one-line
# bootstrap (irm ... | iex): it runs the installer and aitools.ps1 under
# PowerShell 7 (pwsh), never under Windows PowerShell 5.1, and installs pwsh with
# the tool registry's preferred Windows method when it is missing.
#
# Safe to re-run: side-effect free. bootstrap.ps1 runs under Windows PowerShell
# 5.1 (powershell.exe, the stock irm | iex shell) in a temp dir with a PATH of
# stubs: git.cmd and winget.cmd record their arguments and do nothing; the clone
# (AITOOLS_DIR) holds a stub scripts\aitools-install.ps1 and USERPROFILE a stub
# .local\bin\aitools.ps1, each recording the PowerShell version it ran under.
# Nothing is installed, cloned or pulled. Removed on exit.
# Platform: Windows (pwsh 7 runs this file; powershell.exe 5.1 runs bootstrap.ps1).
# Elsewhere every case is SKIP (bootstrap.ps1 is Windows-only). Exit 1 if any
# case fails.
#
# Cases:
#   static   ASCII only; parses under pwsh and under Windows PowerShell 5.1; no
#            installer launch through `powershell`; the pwsh install command is
#            the registry's preferred Windows method (tools.pwsh)
#   present  pwsh on PATH: the installer runs under pwsh 7; when the session is
#            interactive, `aitools user init` and `aitools` run under pwsh 7
#   failrc   installer exit 3: reported, and the run goes on (bootstrap.sh parity)
#   initrc   `aitools user init` exit 2: reported, `aitools` (rebuild) not run
#   install  pwsh missing, winget present: winget gets the registry command, then
#            pwsh is found on the registry PATH (Update-SessionPath) and runs the
#            installer. Needs a pwsh.exe on the Machine or User PATH, else SKIP
#   nowinget pwsh and winget missing: a clear error, exit 1, installer not run
# Not covered: pwsh still missing after a winget install (the registry PATH of
# this machine has pwsh; covering it would need a registry edit).
#
# Usage: pwsh -NoProfile -File tests/bootstrap/test-bootstrap.ps1 [-Bootstrap <path>] [-Help]
#   -Bootstrap  the bootstrap.ps1 to test (default: this repo's scripts/bootstrap.ps1);
#               used for the mutation checks

param([string]$Bootstrap = "", [switch]$Help)

if ($Help) {
    Get-Content $PSCommandPath | Select-Object -Skip 1 -First 33
    exit 0
}

$script:pass = 0
$script:fail = 0
$script:skip = 0
function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) { Write-Output "PASS $Name"; $script:pass++ }
    else { Write-Output "FAIL $Name$(if ($Detail) { " -- $Detail" })"; $script:fail++ }
}
function Skip([string]$Name, [string]$Why) { Write-Output "SKIP $Name ($Why)"; $script:skip++ }
function Finish {
    Write-Output ""
    Write-Output "test-bootstrap: $($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
    if ($script:fail -gt 0) { exit 1 }
    exit 0
}

$root = (Resolve-Path (Join-Path $PSScriptRoot ".." "..")).Path
if (-not $Bootstrap) { $Bootstrap = Join-Path $root "scripts" "bootstrap.ps1" }
$Bootstrap = (Resolve-Path $Bootstrap).Path

if (-not $IsWindows) {
    foreach ($c in @("static", "present", "failrc", "initrc", "install", "nowinget")) {
        Skip $c "bootstrap.ps1 is Windows-only"
    }
    Finish
}

$winPs = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$pwshExe = (Get-Process -Id $PID).Path
$pwshDir = Split-Path $pwshExe -Parent
$tmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("aitools-bootstrap-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmpRoot | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)

try {
    # ------------------------------------------------------------------
    # static
    # ------------------------------------------------------------------
    $bytes = [IO.File]::ReadAllBytes($Bootstrap)
    $nonAscii = @($bytes | Where-Object { $_ -gt 0x7F }).Count
    Check "static: bootstrap.ps1 is ASCII (Windows PowerShell 5.1 reads BOM-less files as ANSI)" ($nonAscii -eq 0) "$nonAscii non-ASCII byte(s)"

    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Bootstrap, [ref]$null, [ref]$errs)
    Check "static: parses under pwsh $($PSVersionTable.PSVersion)" ($errs.Count -eq 0) (($errs | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join "; ")

    if (Test-Path $winPs) {
        $parser = Join-Path $tmpRoot "parse51.ps1"
        [IO.File]::WriteAllText($parser, @'
param([string]$Path)
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$e)
if ($e) { $e | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }; exit 1 }
"ok $($PSVersionTable.PSVersion)"
exit 0
'@, $utf8)
        $out51 = & $winPs -NoProfile -ExecutionPolicy Bypass -File $parser $Bootstrap 2>&1
        Check "static: parses under Windows PowerShell 5.1" ($LASTEXITCODE -eq 0) (($out51 | ForEach-Object { "$_" }) -join "; ")
    } else {
        Skip "static: parses under Windows PowerShell 5.1" "$winPs not found"
    }

    $text = [IO.File]::ReadAllText($Bootstrap)
    $code = ($text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
    Check "static: no script launched through powershell (5.1)" ($code -notmatch '(?im)(^|[&|;(]\s*|\s)powershell(\.exe)?\s+-') "a 'powershell ... -' launch is still in bootstrap.ps1"

    $reg = Get-Content -Raw (Join-Path $root "registries" "tool-registry.json") | ConvertFrom-Json
    $regCmd = @($reg.tools.pwsh.install.windows | Where-Object { $_.preferred })[0].command
    Check "static: registry has a preferred Windows install command for pwsh" ([bool]$regCmd)
    if ($regCmd) {
        Check "static: bootstrap installs pwsh with the registry command ($regCmd)" ($code.Contains($regCmd)) "not found in bootstrap.ps1 code lines"
    }

    if (-not (Test-Path $winPs)) {
        foreach ($c in @("present", "failrc", "initrc", "install", "nowinget")) { Skip $c "$winPs not found" }
        Finish
    }

    # ------------------------------------------------------------------
    # Behaviour: bootstrap.ps1 under powershell.exe 5.1 with stubs
    # ------------------------------------------------------------------
    $interactive = [Environment]::UserInteractive

    # New-Case NAME WINGET [WINGETRC]: a case dir with stub\, out\, home\ and the clone
    function New-Case([string]$Name, [bool]$Winget, [int]$WingetRc = 0) {
        $d = Join-Path $tmpRoot $Name
        foreach ($s in @("stub", "out", "home\.local\bin", "aitools\.git", "aitools\scripts")) {
            New-Item -ItemType Directory -Path (Join-Path $d $s) -Force | Out-Null
        }
        [IO.File]::WriteAllText((Join-Path $d "stub\git.cmd"),
            "@echo off`r`necho %*>>`"%BOOT_OUT%\git.txt`"`r`nexit /b 0`r`n", $utf8)
        if ($Winget) {
            [IO.File]::WriteAllText((Join-Path $d "stub\winget.cmd"),
                "@echo off`r`necho %*>>`"%BOOT_OUT%\winget.txt`"`r`nexit /b $WingetRc`r`n", $utf8)
        }
        [IO.File]::WriteAllText((Join-Path $d "aitools\scripts\aitools-install.ps1"), @'
$rc = if ($env:BOOT_INSTALLER_RC) { [int]$env:BOOT_INSTALLER_RC } else { 0 }
Add-Content -Path (Join-Path $env:BOOT_OUT "installer.txt") -Value "$($PSVersionTable.PSVersion.Major)|$($PSVersionTable.PSEdition)"
exit $rc
'@, $utf8)
        [IO.File]::WriteAllText((Join-Path $d "home\.local\bin\aitools.ps1"), @'
Add-Content -Path (Join-Path $env:BOOT_OUT "aitools.txt") -Value "$($PSVersionTable.PSVersion.Major)|$($args -join ' ')"
if (($args -join ' ') -eq 'user init' -and $env:BOOT_INIT_RC) { exit [int]$env:BOOT_INIT_RC }
exit 0
'@, $utf8)
        return $d
    }

    # Invoke-Bootstrap DIR PATHDIRS [EXTRAENV]: run bootstrap.ps1 under 5.1; returns exit code,
    # output text and the recorded files
    function Invoke-Bootstrap([string]$Dir, [string[]]$PathDirs, [hashtable]$Extra = @{}) {
        $names = @("Path", "AITOOLS_DIR", "USERPROFILE", "HOME", "BOOT_OUT", "PSModulePath",
                   "BOOT_INSTALLER_RC", "BOOT_INIT_RC")
        $saved = @{}
        foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
        try {
            $env:Path = ($PathDirs -join ';')
            $env:AITOOLS_DIR = Join-Path $Dir "aitools"
            $env:USERPROFILE = Join-Path $Dir "home"
            $env:HOME = Join-Path $Dir "home"
            $env:BOOT_OUT = Join-Path $Dir "out"
            # pwsh's module paths break Windows PowerShell 5.1 autoloading; let each
            # shell compute its own
            $env:PSModulePath = $null
            $env:BOOT_INSTALLER_RC = $null
            $env:BOOT_INIT_RC = $null
            foreach ($k in $Extra.Keys) { [Environment]::SetEnvironmentVariable($k, $Extra[$k]) }
            $log = Join-Path $Dir "bootstrap.log"
            & $winPs -NoProfile -ExecutionPolicy Bypass -File $Bootstrap *> $log
            $rc = $LASTEXITCODE
        } finally {
            foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $saved[$n]) }
        }
        $read = { param($f) $p = Join-Path (Join-Path $Dir "out") $f; if (Test-Path $p) { Get-Content $p } }
        return [pscustomobject]@{
            Rc = $rc
            Out = [IO.File]::ReadAllText((Join-Path $Dir "bootstrap.log"))
            Installer = @(& $read "installer.txt")
            Aitools = @(& $read "aitools.txt")
            Winget = @(& $read "winget.txt")
            Git = @(& $read "git.txt")
        }
    }

    $sys = @((Join-Path $env:SystemRoot "System32"), $env:SystemRoot,
             (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0"))

    # --- present ---
    $d = New-Case "present" $false
    $r = Invoke-Bootstrap $d (@((Join-Path $d "stub"), $pwshDir) + $sys)
    Check "present: exit 0" ($r.Rc -eq 0) "exit $($r.Rc); $($r.Out)"
    Check "present: git stub pulled the existing clone" (($r.Git -join "`n") -match 'pull --ff-only') ($r.Git -join '; ')
    Check "present: installer ran once under pwsh 7 (Core)" ($r.Installer.Count -eq 1 -and $r.Installer[0] -match '^(\d+)\|Core$' -and [int]$Matches[1] -ge 7) "recorded: $($r.Installer -join '; ')"
    Check "present: winget not called (pwsh already on PATH)" ($r.Winget.Count -eq 0) ($r.Winget -join '; ')
    if ($interactive) {
        Check "present: aitools user init, then aitools, both under pwsh 7" (($r.Aitools -join ';') -match '^(\d+)\|user init;(\d+)\|$' -and [int]$Matches[1] -ge 7 -and [int]$Matches[2] -ge 7) "recorded: $($r.Aitools -join '; ')"
    } else {
        Check "present: non-interactive session skips the dotprofile step" ($r.Aitools.Count -eq 0 -and $r.Out -match 'Skipping dotprofile') "recorded: $($r.Aitools -join '; ')"
    }

    # --- failrc ---
    $d = New-Case "failrc" $false
    $r = Invoke-Bootstrap $d (@((Join-Path $d "stub"), $pwshDir) + $sys) @{ BOOT_INSTALLER_RC = "3" }
    Check "failrc: installer exit 3 is reported" ($r.Out -match 'Installer reported issues \(exit 3\)') $r.Out
    Check "failrc: the run goes on to the end" ($r.Rc -eq 0 -and $r.Out -match 'Done\.') "exit $($r.Rc)"

    # --- initrc ---
    if ($interactive) {
        $d = New-Case "initrc" $false
        $r = Invoke-Bootstrap $d (@((Join-Path $d "stub"), $pwshDir) + $sys) @{ BOOT_INIT_RC = "2" }
        Check "initrc: user init exit 2 is reported and aitools (rebuild) is not run" (($r.Aitools -join ';') -match '^\d+\|user init$' -and $r.Out -match 'user init skipped/failed \(exit 2\)') "recorded: $($r.Aitools -join '; ')"
    } else {
        Skip "initrc" "session is not interactive ([Environment]::UserInteractive is false)"
    }

    # --- install ---
    $regPath = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $regPwsh = @($regPath -split ';' | Where-Object { $_ -and (Test-Path (Join-Path $_ "pwsh.exe")) })
    if ($regPwsh.Count -gt 0) {
        $d = New-Case "install" $true 0
        $r = Invoke-Bootstrap $d (@((Join-Path $d "stub")) + $sys)
        Check "install: winget called once with the registry command and agreements" ($r.Winget.Count -eq 1 -and $r.Winget[0].Trim() -eq (($regCmd -replace '^winget\s+', '') + " --accept-package-agreements --accept-source-agreements")) "recorded: $($r.Winget -join '; ')"
        Check "install: pwsh found on the registry PATH; installer ran under pwsh 7" ($r.Rc -eq 0 -and $r.Installer.Count -eq 1 -and $r.Installer[0] -match '^(\d+)\|Core$' -and [int]$Matches[1] -ge 7) "exit $($r.Rc); recorded: $($r.Installer -join '; '); $($r.Out)"
    } else {
        Skip "install" "no pwsh.exe on this machine's Machine or User PATH"
    }

    # --- nowinget ---
    $d = New-Case "nowinget" $false
    $r = Invoke-Bootstrap $d (@((Join-Path $d "stub")) + $sys)
    Check "nowinget: exit 1" ($r.Rc -eq 1) "exit $($r.Rc)"
    Check "nowinget: names pwsh and winget as missing" ($r.Out -match 'PowerShell 7 \(pwsh\) not found and winget not found') $r.Out
    Check "nowinget: stops before calling winget" ($r.Out -notmatch "winget' is not recognized|CommandNotFoundException") $r.Out
    Check "nowinget: installer not run" ($r.Installer.Count -eq 0) ($r.Installer -join '; ')
} catch {
    # Inside try every error is terminating: count it, never end with a false pass
    Check "suite: no unexpected error" $false "$_ (line $($_.InvocationInfo.ScriptLineNumber))"
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $tmpRoot) { Write-Output "warning: temp dir not removed: $tmpRoot" }
}

Finish
