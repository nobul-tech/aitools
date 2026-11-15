param([string]$Out, [string]$Variant = "new", [string]$Extra = "2E8")
# aitools.ps1 Step 2 style: $m = Save-ConsoleInputMode; try { $null | & <child> } finally
# { Restore-ConsoleInputMode $m "build-deploy" }, where the child (stdin a pipe) opens
# CONIN$ itself and leaves the console at 0x$Extra. Then one Read-ConsoleChoice.
#   -Variant new  : worktree lib (helpers from the lib, type AitConsoleInput)
#   -Variant main : origin/main lib + Save-/Restore-ConsoleInputMode extracted from
#                   origin/main aitools.ps1 (type AitConsoleModeGuard)
$ErrorActionPreference = "Stop"
$Lib = $Variant
$LogTag = "guard-$Variant-$Extra"
. (Join-Path $PSScriptRoot "tcommon.ps1")
if ($Variant -eq "main") {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot "origin-aitools.ps1"), [ref]$null, [ref]$null)
    foreach ($name in @("Save-ConsoleInputMode", "Restore-ConsoleInputMode")) {
        $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
        . ([scriptblock]::Create($fn.Extent.Text))
    }
    W "Save/Restore extracted from origin/main aitools.ps1"
}
$sw = [Diagnostics.Stopwatch]::StartNew()
$consoleInMode = Save-ConsoleInputMode
$sw.Stop()
W ("Save-ConsoleInputMode (cold compile) {0} ms: Mode=0x{1:X} Reason={2}" -f $sw.Elapsed.TotalMilliseconds.ToString("0.0"), $consoleInMode.Mode, $consoleInMode.Reason)
try {
    $childOut = $null | & pwsh -NoProfile -File (Join-Path $PSScriptRoot "setraw.ps1") -Mode $Extra -Out $Out -Conin 2>&1 | Out-String
    W "child exit=$LASTEXITCODE"
} finally {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Restore-ConsoleInputMode $consoleInMode "build-deploy"
    $sw.Stop()
    W ("Restore-ConsoleInputMode returned [{0}] in {1} ms" -f $r, $sw.Elapsed.TotalMilliseconds.ToString("0.00"))
}
$typeName = if ($Variant -eq "main") { "AitConsoleModeGuard" } else { "AitConsoleInput" }
W ("mode after restore ({0}::Get): 0x{1:X}" -f $typeName, ($typeName -as [type])::Get())
W ("console types loaded: AitConsoleModeGuard={0} AitConsoleInput={1}" -f [bool]('AitConsoleModeGuard' -as [type]), [bool]('AitConsoleInput' -as [type]))
[Console]::Write("  choice [o/s]: ")
W "READY"
$sw = [Diagnostics.Stopwatch]::StartNew()
$line = Read-ConsoleChoice "overwrite"
$sw.Stop()
W ("GOT [{0}] after {1} ms" -f $line, $sw.ElapsedMilliseconds)
W ("console types loaded after the read: AitConsoleModeGuard={0} AitConsoleInput={1}" -f [bool]('AitConsoleModeGuard' -as [type]), [bool]('AitConsoleInput' -as [type]))
W "DONE"
Start-Sleep -Milliseconds 800
