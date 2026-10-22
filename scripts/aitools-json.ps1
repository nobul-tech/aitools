# aitools-json.ps1 -- JSON helpers for the aitools PowerShell scripts (dot-sourced)
#
# Intent (DRAFT, awaiting commander approval): Give PowerShell scripts one way
# to read, navigate, edit and write JSON files that keeps key order and writes
# the node JSON.stringify(v, null, 2) layout (LF, no BOM), the PowerShell
# counterpart of aitools-json.pl, so every writer of a shared file such as
# profile.json produces the same bytes. NOT a policy layer: it decides nothing
# about profiles or config. Consumed by: aitools-profile.ps1,
# setup-user-config.ps1.
#
# Usage: . (Join-Path $PSScriptRoot "aitools-json.ps1")
# Platform: PowerShell 7 (any OS). Defines functions only; safe to dot-source again.
# ---------------------------------------------------------------------------
# JSON helpers (PSCustomObject trees from ConvertFrom-Json)
# ---------------------------------------------------------------------------
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:JsonDateKind = @{}
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) {
    # PS 7.5+: keep ISO date strings as strings (older 7.x converts them to DateTime)
    $script:JsonDateKind = @{ DateKind = "String" }
}

# Read-JsonFile PATH -> @{ State = valid|missing|invalid; Value; Message }
function Read-JsonFile([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{ State = "missing"; Value = $null; Message = "" }
    }
    try {
        $raw = [IO.File]::ReadAllText($Path, $script:Utf8NoBom)
    } catch {
        return @{ State = "invalid"; Value = $null; Message = "cannot read ${Path}: $($_.Exception.Message)" }
    }
    $raw = $raw.TrimStart([char]0xFEFF)
    try {
        $v = ConvertFrom-Json -InputObject $raw -Depth 64 -ErrorAction Stop @script:JsonDateKind
    } catch {
        return @{ State = "invalid"; Value = $null; Message = "$Path is invalid JSON: $($_.Exception.Message)" }
    }
    if ($v -isnot [System.Management.Automation.PSCustomObject]) {
        if ($null -eq $v) { return @{ State = "invalid"; Value = $null; Message = "$Path is invalid JSON: empty file" } }
        return @{ State = "invalid"; Value = $null; Message = "${Path}: top level is not an object" }
    }
    return @{ State = "valid"; Value = $v; Message = "" }
}

# Get-JNode ROOT SEG... -> @{ Found; Value } (Found=$false when a segment is absent)
function Get-JNode($Root, [string[]]$Segs) {
    $o = $Root
    foreach ($s in $Segs) {
        if ($o -isnot [System.Management.Automation.PSCustomObject]) { return @{ Found = $false; Value = $null } }
        $p = $o.PSObject.Properties[$s]
        if (-not $p) { return @{ Found = $false; Value = $null } }
        $o = $p.Value
    }
    return @{ Found = $true; Value = $o }
}

function Test-JScalar($v) {
    return ($v -is [string] -or $v -is [bool] -or $v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal] -or $v -is [System.Numerics.BigInteger] -or $v -is [datetime])
}

function ConvertTo-JText($v) {
    if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
    if ($v -is [datetime]) { return $v.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
    if ($v -is [double] -or $v -is [decimal]) { return ([System.Convert]::ToString($v, [System.Globalization.CultureInfo]::InvariantCulture)) }
    return [string]$v
}

# Read-JScalar ROOT SEG... -> @{ Found; Text } -- Found only for a non-null scalar
function Read-JScalar($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $null -eq $n.Value -or -not (Test-JScalar $n.Value)) { return @{ Found = $false; Text = "" } }
    return @{ Found = $true; Text = (ConvertTo-JText $n.Value) }
}
function Get-JText($Root, [string[]]$Segs) { return (Read-JScalar $Root $Segs).Text }

function Get-JType($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $null -eq $n.Value) { return "" }
    $v = $n.Value
    if ($v -is [System.Management.Automation.PSCustomObject]) { return "object" }
    if ($v -is [System.Array]) { return "array" }
    if ($v -is [string] -or $v -is [datetime]) { return "string" }
    if ($v -is [bool]) { return "boolean" }
    return "number"
}

function Get-JKeys($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $n.Value -isnot [System.Management.Automation.PSCustomObject]) { return @() }
    return @($n.Value.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-JItems($Root, [string[]]$Segs) {
    $n = Get-JNode $Root $Segs
    if (-not $n.Found -or $n.Value -isnot [System.Array]) { return @() }
    return @($n.Value | Where-Object { $null -ne $_ -and (Test-JScalar $_) } | ForEach-Object { ConvertTo-JText $_ })
}

# Set-JValue ROOT VALUE SEG... -- creates missing objects; new keys are appended
function Set-JValue($Root, $Value, [string[]]$Segs) {
    $o = $Root
    for ($i = 0; $i -lt $Segs.Count - 1; $i++) {
        $s = $Segs[$i]
        $p = $o.PSObject.Properties[$s]
        if (-not $p) {
            $o | Add-Member -NotePropertyName $s -NotePropertyValue ([PSCustomObject]@{})
            $p = $o.PSObject.Properties[$s]
        }
        if ($p.Value -isnot [System.Management.Automation.PSCustomObject]) { throw "set: '$s' is not an object" }
        $o = $p.Value
    }
    $last = $Segs[$Segs.Count - 1]
    $p = $o.PSObject.Properties[$last]
    if ($p) { $p.Value = $Value } else { $o | Add-Member -NotePropertyName $last -NotePropertyValue $Value }
}

# Rename-JKey ROOT NEWNAME SEG... -- rename the key named by the last SEG to
# NEWNAME in place, keeping its position and value: the counterpart of the
# aitools-json.pl edit op "rename", with the same rules and the same messages
# (thrown): "rename: no key given", "rename: '<seg>' not found",
# "rename: '<seg>' is not an object", "rename: '<NEWNAME>' already exists"
# (another key equals NEWNAME ignoring case). NEWNAME equal to the key is a
# no-op; a case-only rename (ABC -> abc) is allowed. Segments match exactly
# (case-sensitive), as in the perl engine. Order is kept by removing the key and
# every key after it, then adding them back with the key renamed.
function Rename-JKey($Root, [string]$NewName, [string[]]$Segs) {
    if ($null -eq $Segs -or $Segs.Count -eq 0) { throw "rename: no key given" }
    $o = $Root
    for ($i = 0; $i -lt $Segs.Count - 1; $i++) {
        $s = $Segs[$i]
        $p = $null
        foreach ($q in $o.PSObject.Properties) { if ($q.Name -ceq $s) { $p = $q; break } }
        if (-not $p) { throw "rename: '$s' not found" }
        if ($p.Value -isnot [System.Management.Automation.PSCustomObject]) { throw "rename: '$s' is not an object" }
        $o = $p.Value
    }
    $old = $Segs[$Segs.Count - 1]
    $props = @($o.PSObject.Properties)
    $idx = -1
    for ($j = 0; $j -lt $props.Count; $j++) { if ($props[$j].Name -ceq $old) { $idx = $j; break } }
    if ($idx -lt 0) { throw "rename: '$old' not found" }
    if ($NewName -ceq $old) { return }
    for ($j = 0; $j -lt $props.Count; $j++) {
        if ($j -ne $idx -and $props[$j].Name -ieq $NewName) { throw "rename: '$NewName' already exists" }
    }
    $names = [System.Collections.Generic.List[string]]::new()
    $values = [System.Collections.Generic.List[object]]::new()
    for ($j = $idx; $j -lt $props.Count; $j++) { $names.Add($props[$j].Name); $values.Add($props[$j].Value) }
    foreach ($n in $names) { $o.PSObject.Properties.Remove($n) }
    $names[0] = $NewName
    for ($j = 0; $j -lt $names.Count; $j++) { $o | Add-Member -NotePropertyName $names[$j] -NotePropertyValue $values[$j] }
}

# ConvertTo-NodeJson VALUE [-Compress] -- node JSON.stringify layout (LF, no BOM)
function ConvertTo-NodeJson($Value, [switch]$Compress) {
    $j = ConvertTo-Json -InputObject $Value -Depth 64 -Compress:$Compress
    return ($j -replace "`r`n", "`n")
}

