# stamp-probe.ps1 -- does aitools.ps1's version-stamp regex match on -Raw content?
# Reproduces scripts/aitools.ps1:2196-2197 and :2206-2207 against the real files.
$repo = "/Users/new-jose/repos/aitools/scripts"
$ps1 = Get-Content (Join-Path $repo "aitools.ps1") -Raw
$out = $ps1 -replace '^\$AITOOLS_INSTALLED_VERSION = ".*"', '$AITOOLS_INSTALLED_VERSION = "9.9.9"'
"ps1 stamped (single-line ^): " + ($out -match '\$AITOOLS_INSTALLED_VERSION = "9\.9\.9"')
$sh = Get-Content (Join-Path $repo "aitools") -Raw
$out2 = $sh -replace '^AITOOLS_INSTALLED_VERSION=".*"', 'AITOOLS_INSTALLED_VERSION="9.9.9"'
"bash stamped (single-line ^): " + ($out2 -match 'AITOOLS_INSTALLED_VERSION="9\.9\.9"')
$out3 = $ps1 -replace '(?m)^\$AITOOLS_INSTALLED_VERSION = ".*"', '$AITOOLS_INSTALLED_VERSION = "9.9.9"'
"ps1 stamped with (?m): " + ($out3 -match '\$AITOOLS_INSTALLED_VERSION = "9\.9\.9"')
