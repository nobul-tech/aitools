param([string]$Out, [string]$Variant = "new", [string]$Extra = "")
# Does a terminating error inside Invoke-AI leave the spinner running? Mirrors scripts/aitools.ps1,
# which runs each setup script in-process inside `try { & $scriptPath } catch { ...; continue }`.
# Fake backend: a session function `claude` (Get-Command finds it first) that holds an exclusive
# lock on deploy.log when it returns, so Invoke-AI's next log write (result=accepted) throws -- as
# any file-lock / disk error on deploy.log would.
#   -Variant nofin : new spinner, Invoke-AiMerge without try/finally (lib-nofinally.ps1)
#   -Variant new   : worktree lib (Stop-AiSpinner in a finally)
$ErrorActionPreference = "Continue"
$LogTag = "throw-$Variant"; $Lib = $Variant; $Stub = $false
. (Join-Path $PSScriptRoot "tcommon.ps1")
$global:C2LogPath = Join-Path $env:AITOOLS_LOG_DIR "deploy.log"
$global:C2Lock = $null
function global:claude {
    $null = @($input)
    Start-Sleep -Milliseconds 1500
    $global:C2Lock = [IO.File]::Open($global:C2LogPath, 'Open', 'ReadWrite', 'None')
    $global:LASTEXITCODE = 0
    "# Title"
    "merged line"
}
W "runspaces before: $(RS)"
W "READY"
try {
    # the "setup script" body
    $r = Invoke-AiMerge -FilePath (Join-Path $PSScriptRoot "a.md") -SourceContent "# Title`nsource line" -LocalContent "# Title`nlocal line"
    W "Invoke-AiMerge returned [$r] (no throw)"
} catch {
    W ("CAUGHT by the outer catch (as aitools.ps1 does): {0}" -f $_.Exception.Message)
}
if ($global:C2Lock) { $global:C2Lock.Dispose(); W "log lock released" }
W ("spinner still registered: {0}" -f [bool]$script:_aiSpinner)
W "runspaces after the catch: $(RS)"
W "NEXT-SCRIPT"
[Console]::WriteLine("")
[Console]::WriteLine("next setup script output line")
Start-Sleep -Milliseconds 2500
W "runspaces at end: $(RS)"
W "DONE"
