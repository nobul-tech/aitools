# env-facts2.ps1 -- read-only: user-site sharing, externally-managed markers, pip config, index versions (M3-Fixes-D)
$interps = @(
  'C:\Users\jdpal\AppData\Local\Python\pythoncore-3.14-64\python.exe',
  'C:\Users\jdpal\.local\bin\python3.exe',
  'C:\Users\jdpal\AppData\Roaming\uv\python\cpython-3.14.10-windows-x86_64-none\python.exe'
)
foreach ($p in $interps) {
  "--- $p"
  & $p -c "import sys, site, sysconfig; print(sys.version.split()[0], sys.executable); print('usersite', site.getusersitepackages(), 'ENABLE_USER_SITE', site.ENABLE_USER_SITE); print('stdlib', sysconfig.get_path('stdlib')); print('purelib', sysconfig.get_path('purelib'))"
}
"--- EXTERNALLY-MANAGED markers"
foreach ($d in 'C:\Users\jdpal\AppData\Local\Python\pythoncore-3.14-64\Lib','C:\Users\jdpal\AppData\Roaming\uv\python\cpython-3.14.10-windows-x86_64-none\Lib') {
  $f = Join-Path $d 'EXTERNALLY-MANAGED'
  "{0}: {1}" -f $f, (Test-Path $f)
}
"--- user site dir exists"
Test-Path 'C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages'
"--- pip config list"
python -m pip config list
"--- env PIP_*"
Get-ChildItem env: | Where-Object Name -like 'PIP_*' | ForEach-Object { "{0}={1}" -f $_.Name, $_.Value }
"--- pip index versions pywinpty"
python -m pip index versions pywinpty
"index exit: $LASTEXITCODE"
"--- pip debug compatible tags (first 5)"
python -m pip debug --verbose 2>$null | Select-String -Pattern 'cp314-cp314-win_amd64' | Select-Object -First 2
