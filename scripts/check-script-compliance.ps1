# check-script-compliance.ps1 -- Verify setup scripts follow script-standards.md
# Usage: pwsh -File scripts/check-script-compliance.ps1
# Checks: log format, exit footers, write_summary coverage, counter tracking,
#          raw echo/Write-Host, OS guards, logging init, cross-platform pairing,
#          SilentlyContinue result checks, summary categories, the summary
#          rules of reference/logging.md section 8 (step 13) and the log
#          writers outside aitools-lib (step 14, logging.md 8.1).
#          $StrictSummary (below; $true since plan step I5) makes step 12,
#          step 13 rule 4 and step 14 FAIL instead of report (WARN).

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir "check-lib.ps1")
. (Join-Path $scriptDir "init-logging.ps1")

# OS guard: use .sh on macOS/Linux
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use check-script-compliance.sh."
    exit 1
}

CheckLogInit "script-compliance"

Set-Location $repoRoot

Write-Host ""
Write-Host "=== SCRIPT STANDARDS COMPLIANCE ===" -ForegroundColor White
Write-Host ""

# ---------------------------------------------------------------------------
# Report, then fail (plan summary-warn-reporting, steps I2 and I5). With
# $StrictSummary $true (set in step I5, once every call site had migrated),
# step 12 accepts only the categories OK, DETAIL and ACTION, in upper case, as
# Write-Summary does (it records no other category), and step 13 rule 4
# (legacy write_summary WARN / ERROR calls) and step 14 (log writers outside
# aitools-lib) FAIL on any site. With it $false (the migration, steps I2-I3),
# step 12 accepted OK, WARN, ERROR, ACTION and DETAIL in any case, and rule 4
# and step 14 reported their sites as a WARN. The .sh twin has the same switch
# (STRICT_SUMMARY), set the same way.
# ---------------------------------------------------------------------------
$StrictSummary = $true

# Collect target scripts
$shScripts = @(Get-ChildItem "scripts/setup-*.sh" -ErrorAction SilentlyContinue)
$shScripts += @(Get-Item "scripts/aitools-install.sh" -ErrorAction SilentlyContinue)
$shScripts = @($shScripts | Where-Object { $_ })

$ps1Scripts = @(Get-ChildItem "scripts/setup-*.ps1" -ErrorAction SilentlyContinue)
$ps1Scripts += @(Get-Item "scripts/aitools-install.ps1" -ErrorAction SilentlyContinue)
$ps1Scripts = @($ps1Scripts | Where-Object { $_ })

# ---------------------------------------------------------------------------
# 1. Log format compliance -- verify lib produces [ts] [script] [level] msg
# ---------------------------------------------------------------------------
$libContent = Get-Content "scripts/aitools-lib.ps1" -Raw -ErrorAction SilentlyContinue
if ($libContent -match '\[\$level\]' -or $libContent -match '\[level\]') {
    StepPass "1" "Log format compliance" "aitools-lib.ps1 uses [level] format"
} else {
    StepFail "1" "Log format compliance" "aitools-lib.ps1 missing [level] in format"
}

# ---------------------------------------------------------------------------
# 2. Exit footer pattern -- every setup script has warnings check
# ---------------------------------------------------------------------------
$step2Fail = 0
$step2Details = @()
foreach ($f in $ps1Scripts) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -notmatch 'warnings') {
        $step2Fail++
        $step2Details += $f.Name
    }
}

if ($step2Fail -eq 0) {
    StepPass "2" "Exit footer pattern" "all PS1 scripts check warnings"
} else {
    StepFail "2" "Exit footer pattern" "$step2Fail scripts missing warnings: $($step2Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 3. write_summary coverage -- every exit 1 has preceding Write-Summary
#    Exempt: OS guard exits, main exit footer, and an exit after an error or
#    warning helper: LogError, Write-AitError, Write-AitWarn, Write-AitAction
#    (each records itself: logging.md 8.2)
# ---------------------------------------------------------------------------
$step3Fail = 0
$step3Details = @()
foreach ($f in $ps1Scripts) {
    $lines = @(Get-Content $f.FullName -ErrorAction SilentlyContinue)
    if (-not $lines) { continue }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*exit 1' -and $lines[$i] -notmatch '^\s*#') {
            # Check preceding 10 lines for context
            $start = [Math]::Max(0, $i - 10)
            $context = $lines[$start..$i] -join "`n"
            # Skip if Write-Summary present
            if ($context -match 'Write-Summary') { continue }
            # Skip main exit footer
            if ($context -match '\$errors') { continue }
            # Skip OS guard exits
            if ($context -match 'IsWindows|IsMacOS') { continue }
            # Skip LogError exits (error tracked by counter)
            if ($context -match 'LogError') { continue }
            # Skip exits after a warning or error helper (it logs, counts and records)
            if ($context -match 'Write-AitError|Write-AitWarn|Write-AitAction') { continue }
            $step3Fail++
            $step3Details += "$($f.Name):$($i + 1)"
        }
    }
}

if ($step3Fail -eq 0) {
    StepPass "3" "Write-Summary before exit 1" "all early exits have summary"
} else {
    StepFail "3" "Write-Summary before exit 1" "$step3Fail gaps: $($step3Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 4. Error counter tracking -- LogError increments $script:errors in lib.
#    Steps 4 and 5 match the function's body across lines ((?s), up to its
#    first "}"): the body starts on the line after "function LogError($msg) {"
# ---------------------------------------------------------------------------
if ($libContent -match '(?s)function\s+LogError\b[^}]*\$script:errors\+\+') {
    StepPass "4" "Error counter tracking (PS1)" "LogError increments errors"
} else {
    StepFail "4" "Error counter tracking (PS1)" "LogError does not increment errors"
}

# ---------------------------------------------------------------------------
# 5. Warning counter tracking -- LogWarn increments $script:warnings in lib
# ---------------------------------------------------------------------------
if ($libContent -match '(?s)function\s+LogWarn\b[^}]*\$script:warnings\+\+') {
    StepPass "5" "Warning counter tracking (PS1)" "LogWarn increments warnings"
} else {
    StepFail "5" "Warning counter tracking (PS1)" "LogWarn does not increment warnings"
}

# ---------------------------------------------------------------------------
# 6. No raw Write-Host in setup scripts
# ---------------------------------------------------------------------------
$step6Fail = 0
$step6Details = @()
foreach ($f in $ps1Scripts) {
    # Skip aitools-install.ps1 (has legitimate Write-Host for prompts)
    if ($f.Name -eq "aitools-install.ps1") { continue }
    $lines = @(Get-Content $f.FullName -ErrorAction SilentlyContinue)
    $rawCount = 0
    foreach ($line in $lines) {
        if ($line -match '^\s*Write-Host\s' -and $line -notmatch '^\s*#') {
            $rawCount++
        }
    }
    if ($rawCount -gt 0) {
        $step6Fail += $rawCount
        $step6Details += "$($f.Name)($rawCount)"
    }
}

if ($step6Fail -eq 0) {
    StepPass "6" "No raw Write-Host in setup scripts" "all use structured logging"
} else {
    StepWarn "6" "No raw Write-Host in setup scripts" "$step6Fail raw Write-Host(s): $($step6Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 7. Grep pipefail safety (bash only -- skip for PS1)
# ---------------------------------------------------------------------------
StepSkip "7" "Grep pipefail safety" "PS1 only -- not applicable"

# ---------------------------------------------------------------------------
# 8. OS guard present
# ---------------------------------------------------------------------------
$step8Fail = 0
$step8Details = @()
foreach ($f in $ps1Scripts) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -notmatch 'IsWindows' -and $content -notmatch 'IsMacOS') {
        $step8Fail++
        $step8Details += $f.Name
    }
}

if ($step8Fail -eq 0) {
    StepPass "8" "OS guard present (.ps1)" "all have IsWindows/IsMacOS guard"
} else {
    StepFail "8" "OS guard present (.ps1)" "$step8Fail missing: $($step8Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 9. Logging init present
# ---------------------------------------------------------------------------
$step9Fail = 0
$step9Details = @()
foreach ($f in $ps1Scripts) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    if ($content -notmatch 'Initialize-Logging') {
        $step9Fail++
        $step9Details += $f.Name
    }
}

if ($step9Fail -eq 0) {
    StepPass "9" "Logging init present (.ps1)" "all call Initialize-Logging"
} else {
    StepFail "9" "Logging init present (.ps1)" "$step9Fail missing: $($step9Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 10. Cross-platform pairing
# ---------------------------------------------------------------------------
$step10Fail = 0
$step10Details = @()
foreach ($f in $ps1Scripts) {
    $base = $f.BaseName
    $shFile = "scripts/$base.sh"
    if (-not (Test-Path $shFile)) {
        $step10Fail++
        $step10Details += "$($f.Name)"
    }
}
foreach ($f in $shScripts) {
    $base = $f.BaseName
    $ps1File = "scripts/$base.ps1"
    if (-not (Test-Path $ps1File)) {
        $step10Fail++
        $step10Details += "$($f.Name)"
    }
}

if ($step10Fail -eq 0) {
    StepPass "10" "Cross-platform pairing" "all .sh have .ps1 and vice versa"
} else {
    StepFail "10" "Cross-platform pairing" "$step10Fail unpaired: $($step10Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 11. -ErrorAction SilentlyContinue has result check (PS1 scripts)
# ---------------------------------------------------------------------------
$step11Fail = 0
$step11Details = @()
foreach ($f in $ps1Scripts) {
    $lines = Get-Content $f -ErrorAction Stop
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'ErrorAction SilentlyContinue' -and $lines[$i] -notmatch '^\s*#') {
            $lineno = $i + 1
            # Check next 3 lines for a null/result check
            $checkEnd = [Math]::Min($i + 3, $lines.Count - 1)
            $nearby = ($lines[($i+1)..$checkEnd]) -join "`n"
            if ($nearby -match '-not|if\s|\bif\(|\.Count|\.Length|null|catch') { continue }
            # Exempt: Get-Command checks (command existence)
            $checkStart = [Math]::Max($i - 3, 0)
            $preceding = ($lines[$checkStart..$i]) -join "`n"
            if ($preceding -match 'Get-Command') { continue }
            # Exempt: result check comment on same line
            if ($lines[$i] -match 'checked on') { continue }
            $step11Fail++
            $step11Details += "$(Split-Path $f -Leaf):$lineno"
        }
    }
}

if ($step11Fail -eq 0) {
    StepPass "11" "SilentlyContinue has result check" "all occurrences verified"
} else {
    StepFail "11" "SilentlyContinue has result check" "$step11Fail unchecked: $($step11Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 12. Write-Summary uses valid categories: with $StrictSummary on, only OK,
#     DETAIL and ACTION, in upper case (WARN and ERROR records come from the
#     warning and error helpers: logging.md 8.2; Write-Summary records no
#     other category); with it off, OK, WARN, ERROR, ACTION, DETAIL in any case
# ---------------------------------------------------------------------------
$step12Fail = 0
$step12Details = @()
$validCats = if ($StrictSummary) { @('OK', 'DETAIL', 'ACTION') } else { @('OK', 'WARN', 'ERROR', 'ACTION', 'DETAIL') }
# Test-S12Valid CAT: valid with the rule above (exact case when strict)
function Test-S12Valid([string]$Cat) {
    if ($StrictSummary) { return ($validCats -ccontains $Cat) }
    return ($validCats -contains $Cat)
}
foreach ($f in $ps1Scripts) {
    $lines = Get-Content $f -ErrorAction Stop
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'Write-Summary\s+"(\w+)"' -and $lines[$i] -notmatch '^\s*#') {
            $cat = $Matches[1]
            if (-not (Test-S12Valid $cat)) {
                $step12Fail++
                $step12Details += "$(Split-Path $f -Leaf):$($i+1)($cat)"
            }
        }
    }
}
foreach ($f in $shScripts) {
    $lines = Get-Content $f -ErrorAction Stop
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'write_summary\s+(\w+)\s' -and $lines[$i] -notmatch '^\s*#') {
            $cat = $Matches[1]
            if (-not (Test-S12Valid $cat)) {
                $step12Fail++
                $step12Details += "$(Split-Path $f -Leaf):$($i+1)($cat)"
            }
        }
    }
}

if ($step12Fail -eq 0) {
    StepPass "12" "write_summary valid categories" "all use $($validCats -join '/')"
} else {
    StepFail "12" "write_summary valid categories" "$step12Fail invalid: $($step12Details -join ', ')"
}

# ---------------------------------------------------------------------------
# 13. Summary rules (reference/logging.md 8.2, 8.3)
#     Rule 1: write_summary / Write-Summary never change the category: the
#             function body neither reads the warning or error count nor sets
#             a category word (the old promotion of OK to WARN fails here).
#     Rule 2: every write_error / Write-AitError call passes a non-empty
#             reason, its third argument (-Reason in PowerShell): "" and ''
#             (and $null in PowerShell) fail.
#     Rule 3: the relay changes no parent warning count: no library function
#             whose name contains relay or child changes WARNINGS /
#             $script:warnings.
#     Rule 4: legacy write_summary WARN / ERROR calls (Write-Summary "WARN" /
#             "ERROR") are reported (WARN) while $StrictSummary is $false and
#             FAIL when it is $true.
#     Rules 1 and 3 read scripts/aitools-lib.sh and .ps1; rules 2 and 4 read
#     the step 14 scripts and the library.
# 14. Log writers through aitools-lib (reference/logging.md 8.1). In every
#     bash and PowerShell script under scripts/, except the 8.1 exceptions
#     (the program's %EXEMPT_FILE, $EXEMPT_CHECK and @EXEMPT_LINE), a site is
#     listed as file:line(kind): log-func (a logging function defined outside
#     the library), log-append (an append to a log, a .jsonl or
#     $AITOOLS_SUMMARY_FILE), raw-primitive (a call of _aitlib_log_append,
#     Add-AitLibLogText, jsonl_record or Write-JsonlRecord), ccr-read
#     (CLAUDE_CODE_REMOTE). Reported (WARN) while $StrictSummary is $false,
#     FAIL when it is $true. The .sh twin's comment lists every form.
# Both steps run one perl program, kept byte-identical in the .sh twin
# (tests/check-script-compliance/test-logging-spec.sh compares the two), so
# the twins report the same results. perl is a managed tool on every platform
# and the check steps' shared perl helpers are an approved cross-language
# exception (.claude/rules/cross-platform.md, RFI fa81-16). A program that
# cannot run (perl missing included) is a FAIL "(scan failed)", never a pass.
# ---------------------------------------------------------------------------
$logSpecProg = @'
# logspec: the reference/logging.md section 8 checks of check-script-compliance
# (step 13, the summary rules; step 14, the log writers). This program is kept
# byte-identical in check-script-compliance.sh and check-script-compliance.ps1
# (tests/check-script-compliance/test-logging-spec.sh compares them), so the two
# twins report the same results: change both together.
# Usage: perl -e PROG MODE STRICT ROOT
#   MODE    summary (step 13) or writers (step 14): one line
#           "RESULT<TAB>PASS|WARN|FAIL<TAB>detail"; list-writers, list-legacy,
#           list-scope: one site or file per line
#   STRICT  true or false: the calling twin's STRICT_SUMMARY
#   ROOT    the repository root
# Exit 0; a file it cannot read ends it with a message and a non-zero exit.
use strict;
use warnings;

my ($MODE, $STRICT, $ROOT) = @ARGV;
die "logspec: usage: MODE STRICT ROOT\n" unless defined $ROOT;
$STRICT = $STRICT eq "true" ? 1 : 0;
chdir($ROOT) or die "logspec: cannot enter $ROOT: $!\n";

# --- The files (logging.md 8.1 "Writers") -------------------------------------
# In scope: every bash and PowerShell script under scripts/: *.sh, *.ps1, and an
# extensionless file whose first line is a sh or bash shebang (scripts/aitools,
# scripts/githooks/*). The exceptions are exactly the writers that logging.md
# 8.1 lists under scripts/; change this list and 8.1 together.
my %EXEMPT_FILE = (
    "scripts/aitools-lib.sh"           => "the library",
    "scripts/aitools-lib.ps1"          => "the library",
    "scripts/check-lib.sh"             => "the check library (checks.log, section 6)",
    "scripts/check-lib.ps1"            => "the check library (checks.log, section 6)",
    "scripts/bootstrap.sh"             => "executes before the repository is cloned",
    "scripts/bootstrap.ps1"            => "executes before the repository is cloned",
    "scripts/hh.sh"                    => "installed alone in ~/.local/bin",
    "scripts/hh.ps1"                   => "the Windows hh, no library",
    "scripts/relay-outbound-prompt.sh" => "sourced into its caller",
);
# The check scripts, which log through the check library
my $EXEMPT_CHECK = qr{\Ascripts/check-[^/]+[.](?:sh|ps1)\z};
# One line of an in-scope file: [file, kind, line pattern, reason]
my @EXEMPT_LINE = (
    ["scripts/build-deploy.sh", "log-append", qr/ERROR[|]harness files[|]/,
     "the truncation guard of the generated deploy-harness.sh writes one ERROR record by hand before the library loads"],
);
my %LIB = ("scripts/aitools-lib.sh" => "sh", "scripts/aitools-lib.ps1" => "ps1");

sub read_lines {
    my ($f) = @_;
    open(my $fh, "<", $f) or die "logspec: cannot read $f: $!\n";
    my @l = <$fh>;
    close($fh) or die "logspec: cannot close $f: $!\n";
    s/\r?\n?\z// for @l;
    return @l;
}

# script_files: [path, kind] of every bash and PowerShell script under scripts/
sub script_files {
    my @out;
    for my $p (sort(glob("scripts/*")), sort(glob("scripts/githooks/*"))) {
        next unless -f $p;
        (my $b = $p) =~ s{.*/}{};
        if ($b =~ /[.]sh\z/)  { push @out, [$p, "sh"];  next }
        if ($b =~ /[.]ps1\z/) { push @out, [$p, "ps1"]; next }
        next if $b =~ /[.]/;
        my ($first) = read_lines($p);
        push @out, [$p, "sh"] if defined $first && $first =~ /\A#![^\n]*\b(?:ba)?sh\b/;
    }
    return @out;
}
sub in_scope { my ($f) = @_; return !$EXEMPT_FILE{$f} && $f !~ $EXEMPT_CHECK }

# --- A small shell and PowerShell lexer (one line at a time) ------------------
sub is_esc { my ($kind, $c) = @_; return $kind eq "sh" ? $c eq "\\" : $c eq "`" }

# skip_string KIND S I: the index of the quote that closes the string opening
# at I (length S when it does not close on this line)
sub skip_string {
    my ($kind, $s, $i) = @_;
    my $q = substr($s, $i, 1);
    my $n = length $s;
    my $j = $i + 1;
    while ($j < $n) {
        my $x = substr($s, $j, 1);
        if ($q eq "\x27") {
            if ($x eq "\x27") {
                return $j unless $kind eq "ps1" && substr($s, $j + 1, 1) eq "\x27";
                $j += 2;
                next;
            }
            $j++;
            next;
        }
        if (is_esc($kind, $x)) { $j += 2; next }
        if ($x eq "\$" && substr($s, $j + 1, 1) eq "(") { $j = skip_group($kind, $s, $j + 1) + 1; next }
        if ($x eq "\"") {
            return $j unless $kind eq "ps1" && substr($s, $j + 1, 1) eq "\"";
            $j += 2;
            next;
        }
        $j++;
    }
    return $n;
}

# skip_group KIND S I: the index of the bracket that closes the one at I
sub skip_group {
    my ($kind, $s, $i) = @_;
    my $d = 0;
    my $n = length $s;
    my $j = $i;
    while ($j < $n) {
        my $x = substr($s, $j, 1);
        if ($x eq "\"" || $x eq "\x27") { $j = skip_string($kind, $s, $j) + 1; next }
        if (is_esc($kind, $x)) { $j += 2; next }
        if ($x eq "(" || $x eq "[" || $x eq "{") { $d++ }
        elsif ($x eq ")" || $x eq "]" || $x eq "}") { $d--; return $j if $d <= 0 }
        $j++;
    }
    return $n;
}

# string_at KIND S POS: the index of the quote that opens the string POS is in,
# or -1 when POS is not inside a quoted string
sub string_at {
    my ($kind, $s, $pos) = @_;
    my $i = 0;
    while ($i < $pos) {
        my $c = substr($s, $i, 1);
        if ($c eq "\"" || $c eq "\x27") {
            my $j = skip_string($kind, $s, $i);
            return $i if $j >= $pos;
            $i = $j + 1;
            next;
        }
        if (is_esc($kind, $c)) { $i += 2; next }
        $i++;
    }
    return -1;
}
sub quoted_at { my ($kind, $s, $pos) = @_; return string_at($kind, $s, $pos) >= 0 }

# strip_comment KIND L: L without its comment
sub strip_comment {
    my ($kind, $l) = @_;
    my $n = length $l;
    my $i = 0;
    while ($i < $n) {
        my $c = substr($l, $i, 1);
        if ($c eq "\"" || $c eq "\x27") { $i = skip_string($kind, $l, $i) + 1; next }
        if (is_esc($kind, $c)) { $i += 2; next }
        return substr($l, 0, $i) if $c eq "#" && ($i == 0 || substr($l, $i - 1, 1) =~ /[ \t;]/);
        $i++;
    }
    return $l;
}

# code_lines KIND LINES: the lines with comments removed (PowerShell <# #> too)
sub code_lines {
    my ($kind, @lines) = @_;
    my @out;
    my $block = 0;
    for my $l (@lines) {
        if ($kind eq "ps1") {
            if ($block) {
                if ($l =~ /#>/) { $l = substr($l, $+[0]); $block = 0 }
                else { push @out, ""; next }
            }
            while ($l =~ /<#/) {
                my $s = $-[0];
                if (substr($l, $s) =~ /#>/) { $l = substr($l, 0, $s) . substr($l, $s + $+[0]) }
                else { $l = substr($l, 0, $s); $block = 1; last }
            }
        }
        push @out, strip_comment($kind, $l);
    }
    return @out;
}

# logical KIND CODE: [first line number, text] with continued lines joined
# (a trailing backslash in bash, a trailing backtick in PowerShell)
sub logical {
    my ($kind, @code) = @_;
    my @out;
    my $k = 0;
    while ($k <= $#code) {
        my ($start, $t) = ($k + 1, $code[$k]);
        my $cont = $kind eq "sh" ? qr/(?<!\\)(?:\\\\)*\\[ \t]*\z/ : qr/`[ \t]*\z/;
        while ($t =~ $cont && $k < $#code) {
            $t =~ s/.[ \t]*\z//;
            $k++;
            $t .= " " . $code[$k];
        }
        push @out, [$start, $t];
        $k++;
    }
    return @out;
}

# words KIND S: the words of the command that starts at the beginning of S
sub words {
    my ($kind, $s) = @_;
    my @w;
    my $cur = "";
    my $has = 0;
    my $n = length $s;
    my $i = 0;
    my $stop = $kind eq "sh" ? qr/[;&|)}]/ : qr/[;|)}]/;
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        if ($c eq " " || $c eq "\t") {
            if ($has) { push @w, $cur; $cur = ""; $has = 0 }
            $i++;
            next;
        }
        last if $c =~ $stop;
        my $j = $i;
        if ($c eq "\"" || $c eq "\x27") { $j = skip_string($kind, $s, $i) }
        elsif ($c eq "(" || $c eq "[" || $c eq "{") { $j = skip_group($kind, $s, $i) }
        elsif (is_esc($kind, $c)) { $j = $i + 1 }
        $j = $n - 1 if $j >= $n;
        $cur .= substr($s, $i, $j - $i + 1);
        $has = 1;
        $i = $j + 1;
    }
    push @w, $cur if $has;
    return @w;
}

# calls KIND TEXT NAME: [position, words] of each call of NAME at a command
# position that is not a function definition. A call inside a quoted string
# counts only when the string is what echo or printf prints and starts with
# the call (generated code, such as echo '    write_summary ERROR ...'); its
# words end where the string ends.
sub calls {
    my ($kind, $t, $name) = @_;
    my @out;
    my $re = $kind eq "sh" ? qr/(?<![\w-])\Q$name\E(?![\w-])/ : qr/(?<![\w-])\Q$name\E(?![\w-])/i;
    my $pre = $kind eq "sh"
        ? qr/(?:\A|[;&|({!)]|\b(?:then|do|else|if|elif|while|until))[ \t]*\z/
        : qr/(?:\A|[;|({=&]|\b(?:else|elseif|if|try|finally))[ \t]*\z/i;
    while ($t =~ /$re/g) {
        my $p = $-[0];
        my $before = substr($t, 0, $p);
        next if $before =~ /\bfunction[ \t]+\z/i;
        my $open = string_at($kind, $t, $p);
        my $rest = substr($t, $p);
        if ($open >= 0) {
            next unless substr($t, $open + 1, $p - $open - 1) =~ /\A[ \t]*\z/;
            next unless substr($t, 0, $open) =~ /(?:\A|[;&|({ \t])(?:echo|printf)(?:[ \t]+-[A-Za-z]+)*[ \t]+\z/;
            $rest = substr($t, $p, skip_string($kind, $t, $open) - $p);
        } else {
            next unless $before =~ $pre;
        }
        next if $rest =~ /\A[\w-]+[ \t]*\(\)/;
        push @out, [$p, [words($kind, $rest)]];
    }
    return @out;
}

# call_sites KIND TEXT SHNAME PSNAME: the calls in one logical line; a bash
# file is also searched for PowerShell calls (the PowerShell code a generator
# such as build-deploy.sh writes out)
sub call_sites {
    my ($kind, $t, $shname, $psname) = @_;
    my @c;
    push @c, map { ["sh", @$_] } calls("sh", $t, $shname) if $kind eq "sh";
    push @c, map { ["ps1", @$_] } calls("ps1", $t, $psname);
    return @c;
}

# functions KIND CODE: name (lower case for PowerShell) => [[line, text], ...]
# for each function defined at column 0
sub functions {
    my ($kind, @code) = @_;
    my %fn;
    my $cur;
    for my $k (0 .. $#code) {
        my $l = $code[$k];
        if (!defined $cur) {
            my $name;
            if ($kind eq "sh" && $l =~ /\A(?:function[ \t]+)?([A-Za-z_][\w-]*)[ \t]*\(\)/) { $name = $1 }
            elsif ($kind eq "sh" && $l =~ /\Afunction[ \t]+([A-Za-z_][\w-]*)/) { $name = $1 }
            elsif ($kind eq "ps1" && $l =~ /\Afunction[ \t]+(?:(?:script|global):)?([\w-]+)/i) { $name = lc $1 }
            next unless defined $name;
            $cur = $name;
            $fn{$cur} = [[$k + 1, $l]];
            my $open = () = $l =~ /\{/g;
            my $close = () = $l =~ /\}/g;
            undef $cur if $open > 0 && $open == $close;
            next;
        }
        push @{$fn{$cur}}, [$k + 1, $l];
        undef $cur if $l =~ /\A\}/;
    }
    return %fn;
}

sub is_empty_arg {
    my ($kind, $w) = @_;
    return 1 if $w eq "\"\"" || $w eq "\x27\x27";
    return 1 if $kind eq "ps1" && $w =~ /\A(?:\$null|\(\[string\]::Empty\))\z/i;
    return 0;
}

# --- Step 14: log writers outside the library ---------------------------------
my $SH_LOGFN = qr/b?log(?:_\w+)?|jsonl_\w+|write_(?:summary|warn|action|error)|error_reason|logging_init/;
my $PS_LOGFN = qr/Log|LogOk|LogWarn|LogError|LogDetail|Write-Summary|Write-AitWarn|Write-AitAction|Write-AitError|Get-AitErrorReason|Write-Jsonl\w*|Add-AitLibLogText|Initialize-Logging/i;
my $LOG_TARGET = qr/[.]log\b|[.]jsonl\b|(?<![A-Za-z])log_?(?:file|dir)\b|AITOOLS_SUMMARY_FILE/i;
my $RAW = qr/(?<![\w-])(?:_aitlib_log_append|Add-AitLibLogText|jsonl_record|Write-JsonlRecord)(?![\w-])/;

sub line_exempt {
    my ($f, $kind, $text) = @_;
    for my $e (@EXEMPT_LINE) {
        return 1 if $e->[0] eq $f && $e->[1] eq $kind && $text =~ $e->[2];
    }
    return 0;
}

sub writer_hits {
    my @hits;
    for my $fk (script_files()) {
        my ($f, $kind) = @$fk;
        next unless in_scope($f);
        my @code = code_lines($kind, read_lines($f));
        for my $k (0 .. $#code) {
            my $l = $code[$k];
            next unless $l =~ /\S/;
            my %found;
            if ($kind eq "sh") {
                $found{"log-func"} = 1
                    if $l =~ /\A[ \t]*(?:function[ \t]+)?(?:$SH_LOGFN)[ \t]*\(\)/ || $l =~ /\A[ \t]*function[ \t]+(?:$SH_LOGFN)(?![\w-])/;
                while ($l =~ />>/g) {
                    my $p = $-[0];
                    next if quoted_at($kind, $l, $p);
                    my ($target) = substr($l, $p + 2) =~ /\A[ \t]*(\S+)/;
                    $found{"log-append"} = 1 if defined $target && $target =~ $LOG_TARGET;
                }
                $found{"log-append"} = 1
                    if $l =~ /(?<![\w-])tee[ \t]+(?:-[A-Za-z]*a[A-Za-z]*|--append)(?![\w-])(.*)/ && $1 =~ $LOG_TARGET;
                $found{"raw-primitive"} = 1 if $l =~ $RAW;
            }
            # PowerShell forms; in a bash file, the PowerShell code a generator
            # (build-deploy.sh) writes out
            $found{"log-func"} = 1 if $l =~ /\A[ \t]*function[ \t]+(?:(?:script|global):)?(?:$PS_LOGFN)(?![\w-])/;
            my $psapp = $kind eq "sh"
                ? qr/(?<![\w-])(?:Add-Content|AppendAll(?:Text|Lines))(?![\w-])|(?<![\w-])(?:Out-File|Tee-Object)(?![\w-])(?=.*-Append\b)/i
                : qr/(?<![\w-])(?:Add-Content|AppendAll(?:Text|Lines))(?![\w-])|>>|(?<![\w-])(?:Out-File|Tee-Object)(?![\w-])(?=.*-Append\b)/i;
            while ($l =~ /$psapp/g) {
                my $p = $-[0];
                next if quoted_at("ps1", $l, $p);
                $found{"log-append"} = 1 if substr($l, $p) =~ $LOG_TARGET;
            }
            $found{"raw-primitive"} = 1 if $kind eq "ps1" && $l =~ /(?<![\w-])(?:_aitlib_log_append|Add-AitLibLogText|jsonl_record|Write-JsonlRecord)(?![\w-])/i;
            $found{"ccr-read"} = 1 if $l =~ /CLAUDE_CODE_REMOTE/;
            for my $kd (sort keys %found) {
                next if line_exempt($f, $kd, $l);
                push @hits, "$f:" . ($k + 1) . "($kd)";
            }
        }
    }
    return @hits;
}

# --- Step 13: the summary rules -----------------------------------------------
sub lib_functions {
    my ($f) = @_;
    my $kind = $LIB{$f};
    return functions($kind, code_lines($kind, read_lines($f)));
}

# Rule 1: write_summary / Write-Summary never change the category: the body
# neither reads the warning or error count nor assigns a category word
sub rule1 {
    my @p;
    for my $f (sort keys %LIB) {
        my $kind = $LIB{$f};
        my $name = $kind eq "sh" ? "write_summary" : "write-summary";
        if (!-f $f) { push @p, "$f missing"; next }
        my %fn = lib_functions($f);
        if (!$fn{$name}) { push @p, "$f: $name not found"; next }
        for my $e (@{$fn{$name}}) {
            my ($n, $l) = @$e;
            if ($kind eq "sh") {
                push @p, "$f:$n(reads the count)" if $l =~ /\b(?:WARNINGS|ERRORS)\b/;
                push @p, "$f:$n(sets the category)"
                    if $l =~ /(?:\A|[ \t;])(?:local[ \t]+|declare[ \t]+(?:-\w+[ \t]+)*)?[A-Za-z_]\w*=(["\x27]?)(?:OK|WARN|ERROR|ACTION|DETAIL)\1(?=[ \t;]|\z)/;
            } else {
                push @p, "$f:$n(reads the count)" if $l =~ /\$(?:script:|global:)?(?:warnings|errors)\b/i;
                push @p, "$f:$n(sets the category)" if $l =~ /\$[\w:]+[ \t]*=[ \t]*(["\x27])(?:OK|WARN|ERROR|ACTION|DETAIL)\1/i;
            }
        }
    }
    return @p;
}

# Rule 2: every write_error / Write-AitError call passes a non-empty reason (its
# third argument; -Reason in PowerShell). A splatted or "$@" argument list is
# not judged.
sub rule2 {
    my @p;
    my $n = 0;
    for my $fk (script_files()) {
        my ($f, $kind) = @$fk;
        next unless in_scope($f) || $LIB{$f};
        for my $ll (logical($kind, code_lines($kind, read_lines($f)))) {
            my ($line, $t) = @$ll;
            for my $c (call_sites($kind, $t, "write_error", "Write-AitError")) {
                my ($ck, $pos, $w) = @$c;
                my @a = @$w;
                shift @a;
                $n++;
                my $why = reason_problem($ck, @a);
                push @p, "$f:$line($why)" if $why;
            }
        }
    }
    return ($n, @p);
}

sub reason_problem {
    my ($kind, @a) = @_;
    my $reason;
    if ($kind eq "sh") {
        return "" if grep { /\$[@*]|\[[@*]\]/ } @a;
        $reason = $a[2];
    } else {
        return "" if grep { /\A@\w/ } @a;
        my @pos;
        my %named;
        my $i = 0;
        while ($i <= $#a) {
            my $w = $a[$i];
            if ($w =~ /\A-([A-Za-z]\w*)(?::(.*))?\z/s) {
                my ($pn, $val) = (lc $1, $2);
                if (!defined $val) { $i++; $val = $a[$i] }
                for my $full (qw(tool what reason)) {
                    $named{$full} = $val if index($full, $pn) == 0;
                }
            } else {
                push @pos, $w;
            }
            $i++;
        }
        $reason = exists $named{reason} ? $named{reason} : $pos[2 - (exists $named{tool} ? 1 : 0) - (exists $named{what} ? 1 : 0)];
    }
    return "no reason" unless defined $reason;
    return "empty reason" if is_empty_arg($kind, $reason);
    return "";
}

# Rule 3: the relay changes no parent warning count: no relay function (a
# library function whose name contains relay or child) changes WARNINGS /
# $script:warnings
sub rule3 {
    my @p;
    my %need = ("scripts/aitools-lib.sh" => [qw(run_child_relayed relay_child_log)],
                "scripts/aitools-lib.ps1" => [qw(invoke-childrelayed send-childlog)]);
    for my $f (sort keys %LIB) {
        my $kind = $LIB{$f};
        if (!-f $f) { push @p, "$f missing"; next }
        my %fn = lib_functions($f);
        for my $r (@{$need{$f}}) { push @p, "$f: $r not found" unless $fn{$r} }
        for my $name (sort grep { /relay|child/i } keys %fn) {
            for my $e (@{$fn{$name}}) {
                my ($n, $l) = @$e;
                my $hit = $kind eq "sh"
                    ? ($l =~ /(?<![\w\$])WARNINGS[ \t]*(?:\+\+|--|[-+]?=(?!=))/ || $l =~ /(?:\+\+|--)[ \t]*WARNINGS\b/ || $l =~ /\b(?:printf[ \t]+-v|let)[ \t]+["\x27]?WARNINGS\b/)
                    : ($l =~ /\$script:warnings[ \t]*(?:\+\+|--|[-+]?=(?!=))/i || $l =~ /(?:\+\+|--)[ \t]*\$script:warnings\b/i);
                push @p, "$f:$n($name)" if $hit;
            }
        }
    }
    return @p;
}

# Rule 4: legacy write_summary WARN / ERROR calls (retired: logging.md 8.2, 8.3)
sub legacy_calls {
    my @hits;
    for my $fk (script_files()) {
        my ($f, $kind) = @$fk;
        next unless in_scope($f) || $LIB{$f};
        for my $ll (logical($kind, code_lines($kind, read_lines($f)))) {
            my ($line, $t) = @$ll;
            for my $c (call_sites($kind, $t, "write_summary", "Write-Summary")) {
                my ($ck, $pos, $w) = @$c;
                my $cat = $w->[1];
                next unless defined $cat;
                my $re = $ck eq "sh" ? qr/\A(["\x27]?)(WARN|ERROR)\1\z/ : qr/\A(["\x27]?)(WARN|ERROR)\1\z/i;
                push @hits, [$f, $line, uc $2] if $cat =~ $re;
            }
        }
    }
    return @hits;
}

sub result { my ($v, $d) = @_; print "RESULT\t$v\t$d\n" }

if ($MODE eq "list-scope") {
    for my $fk (script_files()) { print "$fk->[0]\n" if in_scope($fk->[0]) }
} elsif ($MODE eq "list-writers") {
    print "$_\n" for writer_hits();
} elsif ($MODE eq "list-legacy") {
    print "$_->[0]:$_->[1]($_->[2])\n" for legacy_calls();
} elsif ($MODE eq "writers") {
    my @h = writer_hits();
    if (!@h) {
        result("PASS", "no log writer outside aitools-lib (exceptions: logging.md 8.1)");
    } else {
        my $d = scalar(@h) . " log writer site(s) outside aitools-lib (logging.md 8.1): " . join(" ", @h);
        result($STRICT ? "FAIL" : "WARN", $STRICT ? $d : "$d -- reported until STRICT_SUMMARY is on");
    }
} elsif ($MODE eq "summary") {
    my @r1 = rule1();
    my ($n2, @r2) = rule2();
    my @r3 = rule3();
    my @r4 = legacy_calls();
    my ($fail, $warn) = (0, 0);
    my @d;
    if (@r1) { $fail = 1; push @d, "rule 1 FAIL, write_summary changes the category: @r1" }
    else { push @d, "rule 1 ok" }
    if (@r2) { $fail = 1; push @d, "rule 2 FAIL, write_error without a reason: @r2" }
    else { push @d, "rule 2 ok ($n2 write_error call(s))" }
    if (@r3) { $fail = 1; push @d, "rule 3 FAIL, the relay changes the parent warning count: @r3" }
    else { push @d, "rule 3 ok" }
    if (@r4) {
        my %c;
        $c{$_->[0]}++ for @r4;
        my $list = join(" ", map { "$_($c{$_})" } sort keys %c);
        if ($STRICT) { $fail = 1; push @d, "rule 4 FAIL, " . scalar(@r4) . " legacy write_summary WARN/ERROR call(s): $list" }
        else { $warn = 1; push @d, "rule 4 reported, " . scalar(@r4) . " legacy write_summary WARN/ERROR call(s), a FAIL once STRICT_SUMMARY is on: $list" }
    } else {
        push @d, "rule 4 ok (no legacy WARN/ERROR call)";
    }
    result($fail ? "FAIL" : $warn ? "WARN" : "PASS", join("; ", @d));
} else {
    die "logspec: unknown mode \"$MODE\"\n";
}
exit 0;
'@

# Invoke-LogSpec MODE: run the program in MODE (summary or writers) from a
# temporary file; returns @{ Result = PASS, WARN or FAIL; Detail = ... }
function Invoke-LogSpec([string]$Mode) {
    $res = @{ Result = "FAIL"; Detail = "(scan failed)" }
    if (-not (Get-Command perl -ErrorAction SilentlyContinue)) {
        $res.Detail = "(scan failed: perl not available)"
        return $res
    }
    $prog = Join-Path ([IO.Path]::GetTempPath()) ("aitools-logspec-" + [guid]::NewGuid().ToString("N") + ".pl")
    try {
        [IO.File]::WriteAllText($prog, ($logSpecProg -replace "`r", ""), [System.Text.UTF8Encoding]::new($false))
        $strictArg = if ($StrictSummary) { "true" } else { "false" }
        $out = @(& perl $prog $Mode $strictArg $repoRoot)
        if ($LASTEXITCODE -ne 0) { return $res }
        foreach ($l in $out) {
            if ("$l" -match '^RESULT\t(PASS|WARN|FAIL)\t(.*)$') {
                $res.Result = $Matches[1]
                $res.Detail = $Matches[2]
            }
        }
    } catch {
        $res.Detail = "(scan failed: $($_.Exception.Message))"
    } finally {
        Remove-Item -LiteralPath $prog -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $prog) { LogDetail "logspec: temp file not removed: $prog" }
    }
    return $res
}

# Invoke-LogSpecStep NUM LABEL MODE: one step result from Invoke-LogSpec MODE
function Invoke-LogSpecStep([string]$Num, [string]$Label, [string]$Mode) {
    $r = Invoke-LogSpec $Mode
    switch ($r.Result) {
        "PASS"  { StepPass $Num $Label $r.Detail }
        "WARN"  { StepWarn $Num $Label $r.Detail }
        default { StepFail $Num $Label $r.Detail }
    }
}

Invoke-LogSpecStep "13" "Summary rules (logging.md 8.2, 8.3)" "summary"
Invoke-LogSpecStep "14" "Log writers through aitools-lib (8.1)" "writers"

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
PrintSummary

if ($script:FailCount -gt 0) {
    exit 1
} else {
    exit 0
}
