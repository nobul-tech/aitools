param([string]$Out, [string]$Variant = "noguard", [string]$Extra = "")
# (b) The real Step 2 command (Git Bash build-deploy.sh), isolated, in a real console.
# Variant: noguard | guard | nullstdin | guard-nullstdin
# Isolation: HOME/USERPROFILE = scratch home, AITOOLS_USER_REPO_PATH = scratch clone
# of the dotprofile, AITOOLS_LOG_DIR = scratch. Never the real HOME or dotprofile.
$ErrorActionPreference = "Stop"
$scr = $PSScriptRoot
function W([string]$s) { Add-Content -LiteralPath $Out -Value ("{0:HH:mm:ss.fff} {1}" -f (Get-Date), $s) }
$fakeHome = Join-Path $scr "home"
New-Item -ItemType Directory -Force -Path $fakeHome | Out-Null
$env:HOME = $fakeHome
$env:USERPROFILE = $fakeHome
$env:AITOOLS_LOG_DIR = Join-Path $scr "logs-build-$Variant"
$env:AITOOLS_USER_REPO_PATH = (Join-Path $scr "dotprofile") -replace '\\', '/'
. "C:\Users\jdpal\repos\aitools\.claude\worktrees\console-profile\scripts\aitools-lib.ps1"
Initialize-Logging "m3b-build"
. "$scr\extract-guard.ps1"
$guard = $Variant -like "guard*"
$nullIn = $Variant -like "*nullstdin"
$saved = $null
if ($guard) {
    # Cold: no Add-Type has run in this process yet (conmode.cs.ps1 is loaded after)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $saved = Save-ConsoleInputMode
    $saveMs = $sw.ElapsedMilliseconds
}
. "$scr\conmode.cs.ps1"
W ("start: mode=0x{0:X} stdinRedirected={1} variant={2} HOME={3} AITOOLS_USER_REPO_PATH={4}" -f [ConMode]::InMode(), [Console]::IsInputRedirected, $Variant, $env:HOME, $env:AITOOLS_USER_REPO_PATH)
if ($guard) { W ("Save-ConsoleInputMode (cold, incl. Add-Type): Mode=0x{0:X} Reason={1} {2} ms" -f $saved.Mode, $saved.Reason, $saveMs) }
$bashExe = "$env:ProgramFiles\Git\bin\bash.exe"
$t1 = & $bashExe -c 'if [ -t 0 ]; then echo "stdin tty"; else echo "stdin not-tty"; fi' 2>&1 | Out-String
$t2 = $null | & $bashExe -c 'if [ -t 0 ]; then echo "stdin tty"; else echo "stdin not-tty"; fi' 2>&1 | Out-String
W ("probe plain: {0}; probe `$null-piped: {1}; mode now=0x{2:X}" -f $t1.Trim(), $t2.Trim(), [ConMode]::InMode())
W "READY"
Start-Sleep -Milliseconds 800
$unixRepoPath = "/c/Users/jdpal/repos/aitools/.claude/worktrees/console-profile"
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    if ($nullIn) {
        $buildResult = $null | & $bashExe "$unixRepoPath/scripts/build-deploy.sh" 2>&1 | Out-String
    } else {
        $buildResult = & $bashExe "$unixRepoPath/scripts/build-deploy.sh" 2>&1 | Out-String
    }
    $buildRc = $LASTEXITCODE
} finally {
    W ("after build: mode=0x{0:X} ({1} ms)" -f [ConMode]::InMode(), $sw.ElapsedMilliseconds)
    if ($guard) { W ("Restore-ConsoleInputMode: " + (Restore-ConsoleInputMode $saved "build-deploy")) }
}
Set-Content -LiteralPath (Join-Path $scr "build-output-$Variant.log") -Value $buildResult
W ("build rc={0}; final mode=0x{1:X}" -f $buildRc, [ConMode]::InMode())
W "DONE"
Start-Sleep -Milliseconds 500
