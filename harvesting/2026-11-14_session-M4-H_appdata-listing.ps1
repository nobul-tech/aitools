# appdata-listing.ps1 -- list the real APPDATA Python user site (name, size, mtime) to a file
param([Parameter(Mandatory)][string]$Out)
$dirs = @("C:\Users\jdpal\AppData\Roaming\Python")
$lines = foreach ($d in $dirs) {
    if (Test-Path -LiteralPath $d) {
        Get-ChildItem -LiteralPath $d -Recurse -Force | Sort-Object FullName | ForEach-Object {
            "{0}`t{1}`t{2:o}" -f $_.FullName, $(if ($_.PSIsContainer) { "dir" } else { $_.Length }), $_.LastWriteTimeUtc
        }
    } else { "missing $d" }
}
[IO.File]::WriteAllLines($Out, [string[]]@($lines))
Write-Output "$(@($lines).Count) entries -> $Out"
