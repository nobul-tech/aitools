# Check that the proposed Get-AitErrorReason parameter names do not collide with
# PowerShell common parameters when the function is an advanced function.
function Get-AitErrorReason {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string[]]$Output = @(),
        [int]$ExitCode = 0,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    if ($ErrorRecord) { return $ErrorRecord.Exception.Message }
    $lines = @($Output | ForEach-Object { ([string]$_) -creplace "`r", '' -creplace "$([char]27)\[[0-9;]*[A-Za-z]", '' } | Where-Object { $_.Trim() -ne '' })
    foreach ($l in $lines) {
        if ($l -cmatch '(^|\s)(Error:|error:|fatal:)|^E: |failed') { return $l }
    }
    if ($lines.Count -gt 0) { return $lines[-1] }
    return "no output (exit $ExitCode)"
}
try { throw "boom" } catch { $er = $_ }
[Console]::WriteLine("L13: " + (Get-AitErrorReason -Output @("==> Fetching", "Error: No available formula with the name x", "tail") -ExitCode 1))
[Console]::WriteLine("L14: " + (Get-AitErrorReason -Output @("a", "$([char]27)[33mlast line$([char]27)[0m`r", "") -ExitCode 1))
[Console]::WriteLine("L15: " + (Get-AitErrorReason -Output @() -ExitCode 2))
[Console]::WriteLine("exc: " + (Get-AitErrorReason -ErrorRecord $er))
[Console]::WriteLine("params: " + ((Get-Command Get-AitErrorReason).Parameters.Keys -join ','))
