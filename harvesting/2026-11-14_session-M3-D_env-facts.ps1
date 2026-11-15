# env-facts.ps1 -- read-only local environment facts for the pywinpty evaluation (M3-Fixes-D)
foreach ($n in 'python','python3','py','uv','pip') {
    $c = Get-Command $n -All -ErrorAction SilentlyContinue
    if ($c) { foreach ($x in $c) { "{0,-8} -> {1} ({2})" -f $n, $x.Source, $x.CommandType } } else { "{0,-8} -> (not found)" -f $n }
}
"--- python --version"
python --version
"--- python sys info"
python -c "import sys, platform, sysconfig; print(sys.executable); print(sys.version); print(platform.machine(), platform.architecture()[0]); print(sysconfig.get_platform()); import site; print('usersite', site.getusersitepackages(), 'enabled', site.ENABLE_USER_SITE); print('prefix', sys.prefix, 'base', sys.base_prefix)"
"--- pip --version"
python -m pip --version
"--- pip show pywinpty"
python -m pip show pywinpty
"pip show exit: $LASTEXITCODE"
"--- import winpty"
python -c "import winpty; print(winpty.__file__)"
"import exit: $LASTEXITCODE"
"--- uv --version"
uv --version
"--- uv python list (installed only)"
uv python list --only-installed
"--- py launcher list"
py -0p
