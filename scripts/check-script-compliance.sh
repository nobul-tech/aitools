#!/usr/bin/env bash
# check-script-compliance.sh -- Verify setup scripts follow script-standards.md
# Usage: bash scripts/check-script-compliance.sh
# Checks: log format, exit footers, write_summary coverage, counter tracking,
#          raw echo/Write-Host, grep pipefail safety (FAIL: a pipeline that ends
#          in a reader that exits early -- grep -q / -l / -m, head, perl exit --
#          in a pipefail bash file under scripts/, shared/hooks/ or tests/; WARN:
#          other pipeline greps without || true in setup scripts), OS guards,
#          logging init, cross-platform
#          pairing, SilentlyContinue result checks, summary categories, the
#          summary rules of reference/logging.md section 8 (step 13) and the
#          log writers outside aitools-lib (step 14, logging.md 8.1).
#          STRICT_SUMMARY (below) switches step 12, step 13 rule 4 and step 14
#          from report (WARN) to FAIL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/check-lib.sh
source "$SCRIPT_DIR/check-lib.sh"
# shellcheck source=scripts/init-logging.sh
source "$SCRIPT_DIR/init-logging.sh"

# OS guard: use .ps1 on Windows
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use check-script-compliance.ps1."
        exit 1 ;;
esac

check_log_init "script-compliance"

cd "$REPO_ROOT"

echo ""
echo "${BOLD}=== SCRIPT STANDARDS COMPLIANCE ===${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Report, then fail (plan summary-warn-reporting, steps I2 and I5). While
# STRICT_SUMMARY is false, step 12 accepts the categories OK, WARN, ERROR,
# ACTION and DETAIL, and step 13 rule 4 (legacy write_summary WARN / ERROR
# calls) and step 14 (log writers outside aitools-lib) report their sites as a
# WARN, so the tree passes while the call sites migrate. When it is true, step
# 12 accepts only OK, DETAIL and ACTION, and both FAIL. The .ps1 twin has the
# same switch ($StrictSummary); step I5 sets both to true.
# ---------------------------------------------------------------------------
STRICT_SUMMARY=false

# Collect target scripts
SH_SCRIPTS=()
PS1_SCRIPTS=()
for f in scripts/setup-*.sh; do
    [ -f "$f" ] && SH_SCRIPTS+=("$f")
done
[ -f "scripts/aitools-install.sh" ] && SH_SCRIPTS+=("scripts/aitools-install.sh")

for f in scripts/setup-*.ps1; do
    [ -f "$f" ] && PS1_SCRIPTS+=("$f")
done
[ -f "scripts/aitools-install.ps1" ] && PS1_SCRIPTS+=("scripts/aitools-install.ps1")

# ---------------------------------------------------------------------------
# 1. Log format compliance -- verify lib produces [ts] [script] [level] msg
# ---------------------------------------------------------------------------
step1_ok=true
if grep -q '\[level\]' scripts/aitools-lib.sh 2>/dev/null || \
   grep -q '\[\$level\]' scripts/aitools-lib.sh 2>/dev/null; then
    : # format string contains [level] or [$level]
else
    step1_ok=false
fi

if $step1_ok; then
    step_pass "1" "Log format compliance" "aitools-lib.sh uses [level] format"
else
    step_fail "1" "Log format compliance" "aitools-lib.sh missing [level] in format"
fi

# ---------------------------------------------------------------------------
# 2. Exit footer pattern -- every setup script has ERRORS + WARNINGS checks
# ---------------------------------------------------------------------------
step2_fail=0
step2_details=""
for f in "${SH_SCRIPTS[@]}"; do
    if ! grep -q 'WARNINGS' "$f" 2>/dev/null; then
        step2_fail=$((step2_fail + 1))
        step2_details="${step2_details} $(basename "$f")"
    fi
done
for f in "${PS1_SCRIPTS[@]}"; do
    if ! grep -q 'warnings' "$f" 2>/dev/null; then
        step2_fail=$((step2_fail + 1))
        step2_details="${step2_details} $(basename "$f")"
    fi
done

if [ "$step2_fail" -eq 0 ]; then
    step_pass "2" "Exit footer pattern" "all scripts check ERRORS + WARNINGS"
else
    step_fail "2" "Exit footer pattern" "${step2_fail} scripts missing WARNINGS:${step2_details}"
fi

# ---------------------------------------------------------------------------
# 3. write_summary coverage -- every exit 1 has preceding write_summary
#    Exempt: OS guard exits (MINGW/MSYS/CYGWIN in context), main exit footer
#    (ERRORS in context), Windows forwarding blocks (ps1_installer/PowerShell),
#    and an exit after an error or warning helper: log_error, write_error,
#    write_warn, write_action (each records itself: logging.md 8.2).
# ---------------------------------------------------------------------------
step3_fail=0
step3_details=""
for f in "${SH_SCRIPTS[@]}"; do
    # Find lines with 'exit 1' (not in comments)
    exit_lines=$(grep -n 'exit 1' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v 'esac' || true)
    while IFS= read -r eline; do
        [ -z "$eline" ] && continue
        lineno=$(echo "$eline" | cut -d: -f1)
        # Check preceding 10 lines for context
        start=$((lineno > 10 ? lineno - 10 : 1))
        context=$(sed -n "${start},${lineno}p" "$f")
        # Skip if write_summary is present
        if echo "$context" | grep 'write_summary' >/dev/null 2>/dev/null; then continue; fi
        # Skip if this is the main exit footer (ERRORS check)
        if echo "$context" | grep 'ERRORS' >/dev/null 2>/dev/null; then continue; fi
        # Skip OS guard exits (fire before summary is available)
        if echo "$context" | grep 'MINGW\|MSYS\|CYGWIN' >/dev/null 2>/dev/null; then continue; fi
        # Skip Windows forwarding blocks
        if echo "$context" | grep 'ps1_installer\|PowerShell\|ps_args\|cygpath' >/dev/null 2>/dev/null; then continue; fi
        # Skip log_error exits in script body (error is tracked by counter)
        if echo "$context" | grep 'log_error' >/dev/null 2>/dev/null; then continue; fi
        # Skip exits after a warning or error helper (it logs, counts and records)
        if echo "$context" | grep 'write_error\|write_warn\|write_action' >/dev/null 2>/dev/null; then continue; fi
        step3_fail=$((step3_fail + 1))
        step3_details="${step3_details} $(basename "$f"):${lineno}"
    done <<< "$exit_lines"
done

if [ "$step3_fail" -eq 0 ]; then
    step_pass "3" "write_summary before exit 1" "all early exits have summary"
else
    step_fail "3" "write_summary before exit 1" "${step3_fail} gaps:${step3_details}"
fi

# ---------------------------------------------------------------------------
# 4. Error counter tracking -- log_error increments ERRORS in lib
# ---------------------------------------------------------------------------
if grep -A2 'log_error' scripts/aitools-lib.sh 2>/dev/null | grep 'ERRORS=' >/dev/null; then
    step_pass "4" "Error counter tracking (bash)" "log_error increments ERRORS"
else
    step_fail "4" "Error counter tracking (bash)" "log_error does not increment ERRORS"
fi

# ---------------------------------------------------------------------------
# 5. Warning counter tracking -- log_warn increments WARNINGS in lib
# ---------------------------------------------------------------------------
if grep -A2 'log_warn' scripts/aitools-lib.sh 2>/dev/null | grep 'WARNINGS=' >/dev/null; then
    step_pass "5" "Warning counter tracking (bash)" "log_warn increments WARNINGS"
else
    step_fail "5" "Warning counter tracking (bash)" "log_warn does not increment WARNINGS"
fi

# ---------------------------------------------------------------------------
# 6. No raw echo/Write-Host in setup scripts
# ---------------------------------------------------------------------------
step6_fail=0
step6_details=""
for f in "${SH_SCRIPTS[@]}"; do
    # Skip aitools-install.sh (has legitimate echo for help text and prompts)
    [ "$(basename "$f")" = "aitools-install.sh" ] && continue
    # Look for bare 'echo' not in comments, not in heredocs
    raw_echos=$(grep -n '^\s*echo ' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v 'echo ""' || true)
    if [ -n "$raw_echos" ]; then
        count=$(echo "$raw_echos" | wc -l | tr -d ' ')
        step6_fail=$((step6_fail + count))
        step6_details="${step6_details} $(basename "$f")(${count})"
    fi
done

if [ "$step6_fail" -eq 0 ]; then
    step_pass "6" "No raw echo in setup scripts" "all use structured logging"
else
    step_warn "6" "No raw echo in setup scripts" "${step6_fail} raw echo(s):${step6_details}"
fi

# ---------------------------------------------------------------------------
# 7. Grep pipefail safety
#    (a) FAIL: a pipeline that ends in a reader that exits before its input
#        ends, in a bash file that runs under pipefail. The readers: grep -q
#        (q in any short-option bundle: -q, -qi, -qxF ...; or --quiet /
#        --silent), grep -l / -L (--files-with-matches /
#        --files-without-match), grep -m N (--max-count), head, and a perl
#        -n / -p program that runs exit or last outside its END block. Such a
#        reader stops reading early; the writer then gets SIGPIPE (exit 141),
#        or, where SIGPIPE is ignored (the GitHub linux runner), exits
#        non-zero on the write error, and under pipefail the pipeline fails,
#        so a condition such as "if writer, piped to grep -q P" can be false
#        although P matched (CI runs 43640967140 and 43642017937; PR #164).
#        The fix forms read their input to the end (reference
#        script-standards-detail.md "Pipelines into grep -q under pipefail"):
#        grep P >/dev/null for grep -q / -l / -L; perl -ne 'print if $. <= N'
#        for head -n N and after grep -m N; next if $done / END { exit } for
#        perl. GNU grep with stdout /dev/null drains its input before it
#        exits, BSD grep reads it to EOF.
#        Scan set: scripts/*.sh, every file in scripts/githooks/,
#        shared/hooks/*.sh, tests/*.sh and tests/*/*.sh, except
#        tests/check-script-compliance/test-step7-grepq.sh (it plants the
#        bad forms on purpose). A file qualifies when a non-comment line runs
#        set with pipefail (set -euo pipefail, set -o pipefail, set -e -o
#        pipefail, any set -<letters>o pipefail), or it is a library that
#        pipefail scripts source (scripts/aitools-lib.sh, check-lib.sh,
#        init-logging.sh, tests/lib/platform-lib.sh,
#        tests/hooks/hook-test-lib.sh). A non-comment line is flagged wherever
#        the pipeline sits: if / elif / while conditions, after !, inside
#        $(...), before && or ||, inside an eval'd check string; also when
#        the line starts with the pipe (a continued pipeline). A site is
#        listed as file:line(reader).
#        grep options are read word by word up to the pattern: "--" and the
#        argument of -e / -f / -A / -B / -C / -d / -D end or skip them (so
#        grep -- -q and grep -e -q are not flagged), a quoted option word
#        ("-q") and a pattern glued to the options (-q"a") are read as
#        options.
#        Not flagged: a reader that reads a file, not a pipe (grep -q P "$f",
#        head -n 1 "$f"), a reader after || or &&, grep -c, perl -0777 (it
#        reads the whole input first), exit inside perl's END { }, comment
#        lines, and a file that does not run under pipefail.
#        Blind spots (a line-based perl regex, not a shell parser): heredoc
#        bodies and multi-line quoted strings are scanned as plain lines (a
#        pipe to a reader inside one is flagged); a pipe at the end of one
#        line followed by the reader at the start of the next line without a
#        leading pipe is missed, and so are |&, egrep / fgrep, a reader
#        behind another word (command grep, LC_ALL=C grep), options after
#        the pattern (grep P -q), a perl program in double quotes or one
#        whose exit is on a later line, sed q and awk exit (the repo uses
#        perl, not sed or awk, for this), and bash embedded in a .ps1 (the
#        Git Bash driver of tests/profile/test-lib.ps1).
#        The patterns are written with character classes ([|], gre[p]) so this
#        file's own source never matches them. A perl failure is a FAIL "(scan
#        failed)", never a silent pass.
#    (b) When (a) finds no site, the step reports the heuristic below (its
#        logic unchanged): a grep in a pipeline without || true in a pipefail
#        setup script is a WARN.
# ---------------------------------------------------------------------------
step7_scan_ok=true
step7_sites=""
if ! step7_sites=$(perl -e '
    use strict; use warnings;
    my %lib = map { $_ => 1 } qw(scripts/aitools-lib.sh scripts/check-lib.sh scripts/init-logging.sh tests/lib/platform-lib.sh tests/hooks/hook-test-lib.sh);
    my %fixture = map { $_ => 1 } qw(tests/check-script-compliance/test-step7-grepq.sh);
    my $pf = qr/\bset[ \t]+(?:-[A-Za-z]+[ \t]+(?:[a-z]+[ \t]+)*)*-[A-Za-z]*o[ \t]+pipefail\b/;
    # grep_reader REST: the early-exit option among the words after grep, or ""
    sub grep_reader {
        my ($rest) = @_;
        my $arg = 0;
        while ($rest =~ /\G[ \t]+([^ \t\r\n]+)/gc) {
            my $w = $1;
            if ($arg) { $arg = 0; next; }
            last if $w =~ /^[<>;&)]/ || $w =~ /^[0-9]+>/ || $w =~ /^[|]/;
            (my $o = $w) =~ s/^(["\x27])(.*)\1$/$2/;
            $o =~ s/["\x27].*//s;
            last unless $o =~ /^-/;
            last if $o eq "--";
            if ($o =~ /^--/) {
                return "grep-q" if $o =~ /^--(?:quiet|silent)$/;
                return "grep-l" if $o =~ /^--files-with(?:out)?-match(?:es)?$/;
                return "grep-m" if $o =~ /^--max-count\b/;
                $arg = 1 if $o =~ /^--(?:regexp|file|context|before-context|after-context|devices|directories|binary-files|label)$/;
                next;
            }
            my @c = split //, substr($o, 1);
            for my $i (0 .. $#c) {
                return "grep-q" if $c[$i] eq "q";
                return "grep-l" if $c[$i] eq "l" || $c[$i] eq "L";
                return "grep-m" if $c[$i] eq "m";
                if ($c[$i] =~ /^[efABCdD]$/) { $arg = 1 if $i == $#c; last; }
            }
        }
        return "";
    }
    # perl_reader REST: "perl-exit" when a -n / -p program runs exit or last
    # outside END { }, else ""
    sub perl_reader {
        my ($rest) = @_;
        my ($opts, $prog) = $rest =~ /^((?:[ \t]+-[^ \t\x27]*)*)[ \t]+\x27([^\x27]*)/ or return "";
        return "" if $opts =~ /-0777/;
        return "" unless $opts =~ /(?:^|[ \t])-[A-Za-z0-9]*[np]/;
        $prog =~ s/\bEND[ \t]*\{[^}]*\}//g;
        return $prog =~ /\b(?:exit|last)\b/ ? "perl-exit" : "";
    }
    for my $f (@ARGV) {
        next unless -f $f;
        next if $fixture{$f};
        open(my $fh, "<", $f) or die "step 7: cannot read $f: $!\n";
        my $on = $lib{$f} ? 1 : 0;
        my @hits;
        while (my $l = <$fh>) {
            next if $l =~ /^[ \t]*#/;
            $on = 1 if $l =~ $pf;
            while ($l =~ /(?<![|])[|](?![|])[ \t]*(gre[p]|hea[d]|per[l])\b/g) {
                my $cmd = $1;
                my $rest = substr($l, pos($l));
                my $r = $cmd eq "head" ? "head" : $cmd eq "grep" ? grep_reader($rest) : perl_reader($rest);
                push @hits, "$f:$.($r)" if $r;
            }
        }
        close($fh) or die "step 7: cannot close $f: $!\n";
        print "$_\n" for ($on ? @hits : ());
    }
' scripts/*.sh scripts/githooks/* shared/hooks/*.sh tests/*.sh tests/*/*.sh); then
    step7_scan_ok=false
fi
step7_n=0
step7_list=""
while IFS= read -r step7_site; do
    [ -n "$step7_site" ] || continue
    step7_n=$((step7_n + 1))
    step7_list="${step7_list} ${step7_site}"
done <<< "$step7_sites"

step7_fail=0
step7_details=""
for f in "${SH_SCRIPTS[@]}"; do
    # Only check scripts with set -euo pipefail
    if ! grep -q 'set -euo pipefail' "$f" 2>/dev/null; then continue; fi
    # Find grep in $() command substitutions without || true
    # Match: $(... grep ... | head ...) without || true
    unsafe=$(grep -n 'grep' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v '|| true' | grep -v 'if ' | grep -v 'command -v' | grep -v '&>/dev/null' || true)
    if [ -n "$unsafe" ]; then
        # Filter to only pipeline greps (most dangerous)
        pipeline_unsafe=$(echo "$unsafe" | grep '|' || true)
        if [ -n "$pipeline_unsafe" ]; then
            count=$(echo "$pipeline_unsafe" | wc -l | tr -d ' ')
            step7_fail=$((step7_fail + count))
            step7_details="${step7_details} $(basename "$f")(${count})"
        fi
    fi
done

if ! $step7_scan_ok; then
    step_fail "7" "Grep pipefail safety" "early-exit reader scan (scan failed)"
elif [ "$step7_n" -gt 0 ]; then
    step_fail "7" "Grep pipefail safety" "${step7_n} pipeline(s) end in a reader that exits early (grep -q / -l / -m, head, perl exit) under pipefail:${step7_list}"
elif [ "$step7_fail" -eq 0 ]; then
    step_pass "7" "Grep pipefail safety" "no unsafe grep pipelines"
else
    step_warn "7" "Grep pipefail safety" "${step7_fail} potential issues:${step7_details}"
fi

# ---------------------------------------------------------------------------
# 8. OS guard present
# ---------------------------------------------------------------------------
step8_fail=0
step8_details=""
for f in "${SH_SCRIPTS[@]}"; do
    if ! grep -q 'MINGW\|MSYS\|CYGWIN' "$f" 2>/dev/null; then
        step8_fail=$((step8_fail + 1))
        step8_details="${step8_details} $(basename "$f")"
    fi
done

if [ "$step8_fail" -eq 0 ]; then
    step_pass "8" "OS guard present (.sh)" "all have MINGW/MSYS/CYGWIN guard"
else
    step_fail "8" "OS guard present (.sh)" "${step8_fail} missing:${step8_details}"
fi

# ---------------------------------------------------------------------------
# 9. Logging init present
# ---------------------------------------------------------------------------
step9_fail=0
step9_details=""
for f in "${SH_SCRIPTS[@]}"; do
    if ! grep -q 'logging_init' "$f" 2>/dev/null; then
        step9_fail=$((step9_fail + 1))
        step9_details="${step9_details} $(basename "$f")"
    fi
done

if [ "$step9_fail" -eq 0 ]; then
    step_pass "9" "Logging init present (.sh)" "all call logging_init"
else
    step_fail "9" "Logging init present (.sh)" "${step9_fail} missing:${step9_details}"
fi

# ---------------------------------------------------------------------------
# 10. Cross-platform pairing
# ---------------------------------------------------------------------------
step10_fail=0
step10_details=""
for f in "${SH_SCRIPTS[@]}"; do
    base=$(basename "$f" .sh)
    ps1_file="scripts/${base}.ps1"
    if [ ! -f "$ps1_file" ]; then
        step10_fail=$((step10_fail + 1))
        step10_details="${step10_details} ${base}.sh"
    fi
done
for f in "${PS1_SCRIPTS[@]}"; do
    base=$(basename "$f" .ps1)
    sh_file="scripts/${base}.sh"
    if [ ! -f "$sh_file" ]; then
        step10_fail=$((step10_fail + 1))
        step10_details="${step10_details} ${base}.ps1"
    fi
done

if [ "$step10_fail" -eq 0 ]; then
    step_pass "10" "Cross-platform pairing" "all .sh have .ps1 and vice versa"
else
    step_fail "10" "Cross-platform pairing" "${step10_fail} unpaired:${step10_details}"
fi

# ---------------------------------------------------------------------------
# 11. -ErrorAction SilentlyContinue has result check (PS1 scripts)
# ---------------------------------------------------------------------------
step11_fail=0
step11_details=""
for f in "${PS1_SCRIPTS[@]}"; do
    # Find lines with -ErrorAction SilentlyContinue (not in comments)
    sc_lines=$(grep -n 'ErrorAction SilentlyContinue' "$f" 2>/dev/null | grep -v '^\s*#' || true)
    while IFS= read -r sc_line; do
        [ -z "$sc_line" ] && continue
        lineno=$(echo "$sc_line" | cut -d: -f1)
        # Check next 3 lines for a null/result check
        check_start=$((lineno + 1))
        check_end=$((lineno + 3))
        total_lines=$(wc -l < "$f" | tr -d ' ')
        [ "$check_end" -gt "$total_lines" ] && check_end=$total_lines
        nearby=$(sed -n "${check_start},${check_end}p" "$f")
        # Look for result checks: -not, if, .Count, .Length, null, catch
        if echo "$nearby" | grep -E '\-not|\bif\b|\.Count|\.Length|null|catch' >/dev/null 2>/dev/null; then
            continue
        fi
        # Exempt: command-existence checks (Get-Command with explicit fallback)
        preceding_start=$((lineno > 3 ? lineno - 3 : 1))
        preceding=$(sed -n "${preceding_start},${lineno}p" "$f")
        if echo "$preceding" | grep 'Get-Command' >/dev/null 2>/dev/null; then continue; fi
        # Also exempt if same line has a result check comment
        if echo "$sc_line" | grep 'checked on' >/dev/null 2>/dev/null; then continue; fi
        step11_fail=$((step11_fail + 1))
        step11_details="${step11_details} $(basename "$f"):${lineno}"
    done <<< "$sc_lines"
done

if [ "$step11_fail" -eq 0 ]; then
    step_pass "11" "SilentlyContinue has result check" "all occurrences verified"
else
    step_fail "11" "SilentlyContinue has result check" "${step11_fail} unchecked:${step11_details}"
fi

# ---------------------------------------------------------------------------
# 12. write_summary uses valid categories: OK, WARN, ERROR, ACTION, DETAIL;
#     with STRICT_SUMMARY on, only OK, DETAIL and ACTION (WARN and ERROR
#     records come from the warning and error helpers: logging.md 8.2)
# ---------------------------------------------------------------------------
step12_fail=0
step12_details=""
if [ "$STRICT_SUMMARY" = true ]; then
    S12_VALID="OK DETAIL ACTION"
else
    S12_VALID="OK WARN ERROR ACTION DETAIL"
fi
# Same rule as the .ps1 twin (check-script-compliance.ps1 step 12): per line,
# a comment line is skipped, and a call is judged by the category word right
# after the function name. The old `grep -n | grep -v '^\s*#'` pipeline never
# skipped a comment (grep -n puts "N:" before the "#"), so a comment that
# mentions write_summary was reported as an invalid category.
# step12_check FILE REGEX: count and record "name:line(category)" per invalid one
step12_check() {
    local f="$1" found
    if ! found=$(S12_RE="$2" S12_NAME="$(basename "$f")" S12_OK="$S12_VALID" perl -ne '
        BEGIN { $re = qr/$ENV{S12_RE}/i; %ok = map { $_ => 1 } split(" ", $ENV{S12_OK}) }
        next if /^\s*#/;
        print "$ENV{S12_NAME}:$.($1)\n" if /$re/ && !$ok{uc $1};
    ' "$f"); then
        step12_fail=$((step12_fail + 1))
        step12_details="${step12_details} $(basename "$f")(scan failed)"
        return 0
    fi
    [ -n "$found" ] || return 0
    step12_fail=$((step12_fail + $(printf '%s\n' "$found" | wc -l | tr -d ' ')))
    step12_details="${step12_details} $(printf '%s' "$found" | tr '\n' ' ')"
}
for f in "${PS1_SCRIPTS[@]}"; do step12_check "$f" 'Write-Summary\s+"(\w+)"'; done
for f in "${SH_SCRIPTS[@]}"; do step12_check "$f" 'write_summary\s+(\w+)\s'; done

if [ "$step12_fail" -eq 0 ]; then
    step_pass "12" "write_summary valid categories" "all use ${S12_VALID// //}"
else
    step_fail "12" "write_summary valid categories" "${step12_fail} invalid:${step12_details}"
fi

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
#             "ERROR") are reported (WARN) while STRICT_SUMMARY is false and
#             FAIL when it is true.
#     Rules 1 and 3 read scripts/aitools-lib.sh and .ps1; rules 2 and 4 read
#     the step 14 scripts and the library.
# 14. Log writers through aitools-lib (reference/logging.md 8.1). In every
#     bash and PowerShell script under scripts/, except the 8.1 exceptions
#     (the program's %EXEMPT_FILE, $EXEMPT_CHECK and @EXEMPT_LINE), a site is
#     listed as file:line(kind):
#       log-func       a logging function defined outside the library (log,
#                      log_*, blog*, jsonl_*, write_summary ..., function Log,
#                      LogWarn, Write-Summary, ...)
#       log-append     an append to a .log, a .jsonl, a log file or directory
#                      variable, or $AITOOLS_SUMMARY_FILE (>>, tee -a,
#                      Add-Content, Out-File -Append, Tee-Object -Append,
#                      AppendAllText / AppendAllLines)
#       raw-primitive  a call of the library's raw writers
#                      (_aitlib_log_append, Add-AitLibLogText, jsonl_record,
#                      Write-JsonlRecord)
#       ccr-read       CLAUDE_CODE_REMOTE (the environment comes from the
#                      library API only: .claude/rules/cross-platform.md)
#     Reported (WARN) while STRICT_SUMMARY is false, FAIL when it is true.
# Both steps run one perl program, kept byte-identical in the .ps1 twin
# (tests/check-script-compliance/test-logging-spec.sh compares the two).
# Blind spots (a line-based lexer, not a parser): an append whose target
# names no log (>> "$f"), a heredoc body read as code, a call split over
# lines without a continuation character, a reason that is not empty but says
# nothing (a check cannot judge it: the plan's section 5.5, limit 3).
# A program that cannot run is a FAIL "(scan failed)", never a silent pass.
# ---------------------------------------------------------------------------
LOGSPEC_PROG=""
# read -d '' returns 1 at the end of the here-document, which is where it
# always stops: || true keeps set -e, and logspec_run checks LOGSPEC_PROG
IFS= read -r -d '' LOGSPEC_PROG <<'LOGSPEC_PERL' || true
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
LOGSPEC_PERL

# logspec_run MODE: run the logspec program in MODE (summary or writers); sets
# LOGSPEC_RESULT (PASS, WARN or FAIL) and LOGSPEC_DETAIL
logspec_run() {
    local out="" line rest
    LOGSPEC_RESULT=FAIL
    LOGSPEC_DETAIL="(scan failed)"
    if [ -z "$LOGSPEC_PROG" ]; then LOGSPEC_DETAIL="(scan failed: no program)"; return 0; fi
    if ! out=$(perl -e "$LOGSPEC_PROG" -- "$1" "$STRICT_SUMMARY" "$REPO_ROOT"); then return 0; fi
    while IFS= read -r line; do
        case "$line" in
            RESULT$'\t'*)
                rest="${line#RESULT$'\t'}"
                case "${rest%%$'\t'*}" in
                    PASS|WARN|FAIL) LOGSPEC_RESULT="${rest%%$'\t'*}"; LOGSPEC_DETAIL="${rest#*$'\t'}" ;;
                esac ;;
        esac
    done <<< "$out"
}

# logspec_step NUM LABEL MODE: one step result from logspec_run MODE
logspec_step() {
    logspec_run "$3"
    case "$LOGSPEC_RESULT" in
        PASS) step_pass "$1" "$2" "$LOGSPEC_DETAIL" ;;
        WARN) step_warn "$1" "$2" "$LOGSPEC_DETAIL" ;;
        *)    step_fail "$1" "$2" "$LOGSPEC_DETAIL" ;;
    esac
}

logspec_step "13" "Summary rules (logging.md 8.2, 8.3)" summary
logspec_step "14" "Log writers through aitools-lib (8.1)" writers

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
else
    exit 0
fi
