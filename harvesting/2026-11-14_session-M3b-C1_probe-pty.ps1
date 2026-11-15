# probe-pty.ps1 -- which python3 the managed-files suite sees, and whether winpty imports (read-only)
$py = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $py) { "python3: not found"; exit 0 }
"python3: $($py.Source)"
& python3 -c "import sys, winpty; print(sys.version.split()[0]); print(winpty.__file__); import importlib.metadata as m; print('pywinpty', m.version('pywinpty'))" 2>&1
"exit=$LASTEXITCODE"
