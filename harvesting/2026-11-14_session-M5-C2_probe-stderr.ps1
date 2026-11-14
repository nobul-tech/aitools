$ErrorActionPreference = "Stop"
try {
    $o = @(& perl -e 'print STDERR "warn line\n"; print "out line\n"; exit 1' 2>&1 | ForEach-Object { "$_" })
    "rc=$LASTEXITCODE lines=$($o.Count): $($o -join ' / ')"
} catch {
    "THREW: $_"
}
"PS $($PSVersionTable.PSVersion)"
