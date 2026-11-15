# probe-markers.ps1 -- read-only: which interpreters on this machine carry EXTERNALLY-MANAGED
$code = 'import sys, os, sysconfig; p = os.path.join(sysconfig.get_path(''stdlib''), ''EXTERNALLY-MANAGED''); print(sys.executable, sys.version.split()[0], ''marker='' + str(os.path.isfile(p)), p)'
"--- uv python list --only-installed"
uv python list --only-installed 2>&1
"--- uv python find"
uv python find 2>&1
"--- python3 / python on PATH (all matches)"
Get-Command python3, python -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }
$targets = @()
$targets += (Get-Command python3, python -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
$uvList = uv python list --only-installed --output-format json 2>$null | ConvertFrom-Json
foreach ($u in @($uvList)) { if ($u.path) { $targets += $u.path } }
"--- markers"
foreach ($t in ($targets | Select-Object -Unique)) {
    $out = & $t -c $code 2>&1
    "$t (exit $LASTEXITCODE): $out"
}
