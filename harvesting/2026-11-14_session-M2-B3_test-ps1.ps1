# Functional check of the re-ask loops in relay-outbound-prompt.ps1 and aliases.ps1.
# Dot-sources the REAL files. Relay input via [Console]::SetIn; alias input via a
# Read-Host stub (a function shadows the cmdlet) fed from a queue.
$wt = 'C:\Users\jdpal\repos\aitools\.claude\worktrees\menus-reask'
$sd = Join-Path $wt '.scratch\session-M2-B3'
. (Join-Path $wt 'scripts\relay-outbound-prompt.ps1')
. (Join-Path $wt 'shared\shell\aliases.ps1')

function Test-Relay([string]$Name, [string]$In) {
    [Console]::SetIn([IO.StringReader]::new($In))
    [Console]::WriteLine("=== relay ${Name}:")
    $r = Read-RelayOutboundChoice
    [Console]::WriteLine("")
    [Console]::WriteLine("--> returned '$r' (count $(@($r).Count))")
}
Test-Relay 'empty-then-c' "`nc`n"
Test-Relay 'word-then-Quit' "foo`n  Quit  `n"
Test-Relay 'S' "S`n"
Test-Relay 'show' "show`n"
Test-Relay 'prefix-no-longer-matches' "qq`nsx`nc`n"
Test-Relay 'eof-immediate' ""
Test-Relay 'empty-then-eof' "`n"
Test-Relay 'partial-valid-at-eof' "q"
$junk = (1..60 | ForEach-Object { 'x' }) -join "`n"
[Console]::SetIn([IO.StringReader]::new("$junk`n"))
$sw = [IO.StringWriter]::new(); $old = [Console]::Out; [Console]::SetOut($sw)
$r = Read-RelayOutboundChoice
[Console]::SetOut($old)
$o = $sw.ToString()
$hints = ([regex]::Matches($o, 'please type one of')).Count
"=== relay 60-junk: returned '$r' hints=$hints endsWith-noinput=$($o.TrimEnd().EndsWith('(no input -- continuing)'))"

$script:queue = [System.Collections.Generic.Queue[object]]::new()
function Read-Host([string]$Prompt) {
    [Console]::Write("${Prompt}: ")
    if ($script:queue.Count -eq 0) { [Console]::WriteLine('<EOF>'); return $null }
    $v = $script:queue.Dequeue(); [Console]::WriteLine("<$v>"); return $v
}
function Test-Confirm([string]$Name, [object[]]$Answers) {
    $script:queue.Clear(); foreach ($a in $Answers) { $script:queue.Enqueue($a) }
    "=== confirm ${Name}:"
    $r = _aitools_confirm "Overwrite? [y/n]"
    "--> returned $r (count $(@($r).Count))"
}
Test-Confirm 'empty-then-y' @('', 'y')
Test-Confirm 'YES' @('  YES ')
Test-Confirm 'maybe-then-no' @('maybe', 'no')
Test-Confirm 'N' @('N')
Test-Confirm 'eof-immediate' @()
Test-Confirm 'empty-then-eof' @('')
$script:queue.Clear(); 1..60 | ForEach-Object { $script:queue.Enqueue('x') }
$r = _aitools_confirm "Overwrite? [y/n]" 6>$null
"=== confirm 60-junk: returned $r, queue left $($script:queue.Count)"

# cc end to end with a stub claude, in an empty dir
function claude { [Console]::WriteLine("STUB claude $args") }
$ccdir = Join-Path $sd 'ccdir-ps'
$null = New-Item -ItemType Directory -Force $ccdir
Push-Location $ccdir
$script:queue.Clear(); $script:queue.Enqueue(''); $script:queue.Enqueue('y')
cc --foo
$script:queue.Clear(); $script:queue.Enqueue('n')
cc --bar
Pop-Location

# Invoke-RelayOutboundPrompt end to end on a throwaway repo with a dirty relay.md:
# stdin is redirected here, so the hint path must run and return 0
$repo = Join-Path $sd 'relay-repo'
$null = New-Item -ItemType Directory -Force (Join-Path $repo '.aitools\channel')
git -C $repo init -q 2>&1 | Out-Null
Set-Content -Path (Join-Path $repo '.aitools\channel\relay.md') -Value 'x'
"=== Invoke-RelayOutboundPrompt (IsInputRedirected=$([Console]::IsInputRedirected)):"
$rc = Invoke-RelayOutboundPrompt -RepoPath $repo
"--> returned '$rc' (count $(@($rc).Count))"
