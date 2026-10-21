# Functional test for Sync-ManagedJson (pwsh) — mirrors the bash scenarios.
. "$PSScriptRoot/../../scripts/aitools-lib.ps1"
Initialize-Logging "test-sync-ps" | Out-Null

$T = Join-Path ([System.IO.Path]::GetTempPath()) ("synctest-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $T -Force | Out-Null
$pass = 0; $fail = 0
function Chk($label, $exp, $act) {
    if ("$exp" -eq "$act") { Write-Host "PASS: $label"; $script:pass++ }
    else { Write-Host "FAIL: $label (exp [$exp] got [$act])"; $script:fail++ }
}
function JGet($file, $path) {
    # Use node for stable JSON rendering (PowerShell unwraps single-element arrays).
    $js = "const o=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));let v=o;for(const k of process.argv[2].split('.')){if(k==='')continue;v=(v==null)?undefined:v[k];}const s=JSON.stringify(v);process.stdout.write(s===undefined?'null':s);"
    return (& node -e $js $file $path)
}

Write-Host "===== S1: first-run adopt (profile silent) ====="
@'
{ "model": "opus[1m]", "theme": "light", "alwaysThinkingEnabled": true,
  "hooks": {"Stop":[{"matcher":"","hooks":[{"type":"command","command":"x"}]}]},
  "permissions": {"defaultMode":"default","deny":["KEEPME"]} }
'@ | Set-Content -Path "$T/settings.json" -NoNewline
'{"version":2,"claude":{"autoMemory":false}}' | Set-Content -Path "$T/profile.json" -NoNewline
Sync-ManagedJson -LiveFile "$T/settings.json" -ProfileFile "$T/profile.json" -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules "MCP(vercel),MCP(webflow),Agent(claude-code-guide)" *> $null
Chk "S1 profile theme adopted" '"light"' (JGet "$T/profile.json" "claude.settings.theme")
Chk "S1 profile deny adopted" '["KEEPME"]' (JGet "$T/profile.json" "claude.settings.permissions.deny")
Chk "S1 hooks NOT adopted" 'null' (JGet "$T/profile.json" "claude.settings.hooks")
Chk "S1 live theme unchanged" '"light"' (JGet "$T/settings.json" "theme")

Write-Host "`n===== S2: idempotence ====="
$before = Get-Content "$T/settings.json" -Raw
Sync-ManagedJson -LiveFile "$T/settings.json" -ProfileFile "$T/profile.json" -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules "MCP(vercel),MCP(webflow),Agent(claude-code-guide)" *> $null
Chk "S2 result unchanged" "unchanged" $script:SyncManagedJsonResult
Chk "S2 bytes identical" $before (Get-Content "$T/settings.json" -Raw)

Write-Host "`n===== S3: deprecated rule stripped, never adopted ====="
'{ "theme":"dark", "permissions":{"defaultMode":"default","deny":["MCP(vercel)","KEEPME"]} }' | Set-Content "$T/s3.json" -NoNewline
'{"claude":{}}' | Set-Content "$T/p3.json" -NoNewline
Sync-ManagedJson -LiveFile "$T/s3.json" -ProfileFile "$T/p3.json" -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules "MCP(vercel),MCP(webflow),Agent(claude-code-guide)" *> $null
Chk "S3 live deny no vercel" '["KEEPME"]' (JGet "$T/s3.json" "permissions.deny")
Chk "S3 profile deny KEEPME only" '["KEEPME"]' (JGet "$T/p3.json" "claude.settings.permissions.deny")

Write-Host "`n===== S4: divergence + AITOOLS_FORCE -> overwrite ====="
'{ "theme":"light" }' | Set-Content "$T/s4.json" -NoNewline
'{"claude":{"settings":{"theme":"dark"}}}' | Set-Content "$T/p4.json" -NoNewline
$env:AITOOLS_FORCE = "1"
Sync-ManagedJson -LiveFile "$T/s4.json" -ProfileFile "$T/p4.json" -SubPath "claude.settings" -ExcludeKeys "hooks" -DeprecatedRules "" *> $null
Remove-Item Env:\AITOOLS_FORCE
Chk "S4 live theme overwritten dark" '"dark"' (JGet "$T/s4.json" "theme")

Write-Host "`n===== RESULTS: $pass passed, $fail failed ====="
Remove-Item -Recurse -Force $T
if ($fail -ne 0) { exit 1 }
