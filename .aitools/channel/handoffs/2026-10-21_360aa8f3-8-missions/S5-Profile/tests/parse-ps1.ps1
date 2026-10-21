# parse-ps1.ps1 -- parse-check the drafted PS1 files (no execution)
$dir = "/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile/S5-Profile-drafts/scripts"
foreach ($f in @("setup-user-config.ps1", "aitools-lib.ps1.profile-block.ps1")) {
    $p = Join-Path $dir $f
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e)
    Write-Output ("{0}: {1} parse error(s)" -f $f, $e.Count)
    foreach ($x in $e) { Write-Output ("  line {0}: {1}" -f $x.Extent.StartLineNumber, $x.Message) }
}
