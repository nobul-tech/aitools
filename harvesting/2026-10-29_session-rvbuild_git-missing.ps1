# git-missing.ps1 -- what deploy-harness.ps1 Add-Source sees when git is not installed
# (simulated with a command name that does not exist). Prints the exit code it reads.
$global:LASTEXITCODE = 0
$null = & aitools-no-such-git-xyz -C . rev-parse --is-inside-work-tree 2>$null
"after rev-parse: LASTEXITCODE=$LASTEXITCODE"
try {
    $raw = & aitools-no-such-git-xyz -C . ls-files -z 2> ([IO.Path]::GetTempFileName())
    $lsRc = $LASTEXITCODE
} finally { }
"after ls-files: lsRc=$lsRc raw=[$raw]"
