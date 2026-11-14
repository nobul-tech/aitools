# Simulate the CI windows step "Install pywinpty (scripts/setup-pywinpty.ps1, hash-pinned)"
# locally, isolated: APPDATA, RUNNER_TEMP and PIP_CACHE_DIR in a temp dir. The step body is
# extracted from check.yml (js-yaml) and run the way GitHub runs a pwsh step
# ($ErrorActionPreference = 'stop' prepended, exit $LASTEXITCODE appended).
param([string]$Python = "")
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\pywinpty'
$t = Join-Path ([IO.Path]::GetTempPath()) ("ci-sim-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $t "appdata") -Force | Out-Null
$body = & node -e "const y=require('C:/Users/jdpal/AppData/Roaming/npm/node_modules/vercel/node_modules/js-yaml');const d=y.load(require('fs').readFileSync(process.argv[1],'utf8'));const s=d.jobs.windows.steps.find(x=>/^Install pywinpty/.test(x.name));process.stdout.write(s.run)" (Join-Path $wt ".github\workflows\check.yml")
$stepFile = Join-Path $t "step.ps1"
[IO.File]::WriteAllText($stepFile, "`$ErrorActionPreference = 'stop'`n" + ($body -join "`n") + "`nif ((Test-Path -LiteralPath variable:\LASTEXITCODE)) { exit `$LASTEXITCODE }`n")
$env:APPDATA = Join-Path $t "appdata"
$env:RUNNER_TEMP = $t
$env:PIP_CACHE_DIR = Join-Path $t "pipcache"
if ($Python) { $env:AITOOLS_PYWINPTY_PYTHON = $Python }
Push-Location $wt
& (Get-Process -Id $PID).Path -NoProfile -File $stepFile
$rc = $LASTEXITCODE
Pop-Location
"step exit: $rc"
Remove-Item -LiteralPath $t -Recurse -Force
