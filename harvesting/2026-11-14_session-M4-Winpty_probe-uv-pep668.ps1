# M4-Winpty: read-only probe -- does pip on the uv-managed CPython refuse a --user install (PEP 668)?
$ErrorActionPreference = 'Continue'
$uvpy = (uv python find 3.14 --managed-python 2>&1 | Out-String).Trim()
"uv python find (managed): $uvpy"
$shim = Join-Path $env:USERPROFILE '.local\bin\python3.exe'
"shim exists: $(Test-Path $shim)"
foreach ($py in @($uvpy, $shim)) {
    if (-not $py -or -not (Test-Path $py)) { "skip: $py"; continue }
    "=== $py"
    & $py -c "import sys, sysconfig, os, site; print(sys.executable); print(sys.version); print('marker', os.path.isfile(os.path.join(sysconfig.get_path('stdlib'), 'EXTERNALLY-MANAGED'))); print('usersite', site.getusersitepackages(), site.ENABLE_USER_SITE)"
    & $py -m pip --version 2>&1
    "pip exit $LASTEXITCODE"
    # --dry-run without --report still runs pip's externally-managed check; nothing is installed
    $req = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty\scripts\requirements-pywinpty.txt'
    & $py -m pip install --dry-run --user --only-binary=:all: --require-hashes --disable-pip-version-check -r $req 2>&1
    "pip install --dry-run --user exit $LASTEXITCODE"
}
