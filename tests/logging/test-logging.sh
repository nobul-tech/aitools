#!/usr/bin/env bash
# test-logging.sh -- unit tests for the shared logging framework (scripts/aitools-lib.sh),
# check-lib.sh's checks.log / checks.jsonl writers, and the bash entry point (scripts/aitools).
#
# Safe to re-run: every case runs in its own temp HOME / log dir, removed on exit.
# Platform: macOS, Linux (OS guard below; commander, 2026-11-14: "sh scripts
# and tests should only run on linux/mac and ps1 on windows"). On Windows,
# tests/logging/test-logging.ps1 tests the PowerShell side (aitools-lib.ps1,
# check-lib.ps1, scripts/aitools.ps1). Exit 1 if any case fails.
# Spec: .claude/rules/script-standards.md (log line format, levels, counters,
# end-of-run summary), reference/logging.md (location, rotation, fail-safe writes;
# section 8: warnings, errors, records, the relay, the panel).
# The shared fixture tests/logging/fixtures/summary-cases.txt (its header is the
# format) is run for every case whose lang is both or sh: each case in a fresh
# bash (the bash running this suite: /bin/bash gives 3.2 on macOS), in its own
# directory, stdin from /dev/null ("needs pty" cases on a terminal through
# tests/managed-files/pty-run.py; SKIP without python3), "external" cases are
# listed, not run. Then cases the fixture does not cover (the I1 contract and
# addendum: summary_begin / _end, run_relay_sync, relay options, nested aborts,
# repair_uv_tool_env, options, push reasons, JSON non-interactive warnings).
#
# Usage: bash tests/logging/test-logging.sh [--help]

set -uo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/logging/test-logging.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/logging/test-logging.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    sed -n '2,22p' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/aitools-lib.sh"
ENTRY="$ROOT/scripts/aitools"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
ESC=$(printf '\033')
TS_RE='\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]'

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
    fi
}

# run_lib <case> <snippet>: source the lib in a fresh bash with an isolated log dir.
# Console output -> $C/out, the log -> $C/logs/deploy.log, rc -> $C/rc.
run_lib() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home"
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="${SUMMARY:-}" \
        bash -c "set -uo pipefail; source '$LIB'; logging_init t; $2" > "$C/out" 2>&1
    echo $? > "$C/rc"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

# ---------------------------------------------------------------------------
# aitools-lib.sh
# ---------------------------------------------------------------------------

run_lib format 'log "hello world"'
check "lib: log line format [ts] [script] [level] message" \
    "grep -Eq '^${TS_RE} \[t\] \[info\] hello world\$' '$LOG'"
check "lib: log file is AITOOLS_LOG_DIR/deploy.log" "[ -s '$C/logs/deploy.log' ]"

run_lib levels 'log_ok a; log_warn b; log_error c; log d info'
check "lib: levels ok/warn/error/info recorded" \
    "grep -q '\[ok\] a' '$LOG' && grep -q '\[warn\] b' '$LOG' && grep -q '\[error\] c' '$LOG' && grep -q '\[info\] d' '$LOG'"
check "lib: log file has no ANSI codes" "! grep -q '$ESC' '$LOG'"
check "lib: warn is yellow on the console" "grep -q '${ESC}\[33m.*\[warn\] b' '$C/out'"
check "lib: error is red on the console" "grep -q '${ESC}\[31m.*\[error\] c' '$C/out'"
check "lib: info is plain on the console" "grep -Eq '^${TS_RE} \[t\] \[info\] d\$' '$C/out'"

run_lib detail 'log_detail "secret diff line"'
check "lib: log_detail writes the log" "grep -q '\[detail\] secret diff line' '$LOG'"
check "lib: log_detail stays off the console" "! grep -q 'secret diff line' '$C/out'"

run_lib counters 'log_error x; log_error y; log_warn z; echo "COUNTS=$ERRORS/$WARNINGS"'
check "lib: log_error/log_warn increment ERRORS/WARNINGS" "grep -q 'COUNTS=2/1' '$C/out'"

run_lib reset 'log_error x; logging_init t2; echo "COUNTS=$ERRORS/$WARNINGS"'
check "lib: logging_init resets the counters" "grep -q 'COUNTS=0/0' '$C/out'"

SUMMARY="" run_lib nosummary 'write_summary OK tool detail; echo "RC=$?"'
check "lib: write_summary is a no-op without AITOOLS_SUMMARY_FILE" "grep -q 'RC=0' '$C/out'"

SUMMARY="$TMP_ROOT/summary.txt" run_lib summary 'write_summary DETAIL tool "it ran"; write_summary OK tool2 v1'
check "lib: write_summary writes CAT|tool|detail" "grep -qx 'DETAIL|tool|it ran' '$TMP_ROOT/summary.txt'"
check "lib: write_summary OK stays OK with no warnings" "grep -qx 'OK|tool2|v1' '$TMP_ROOT/summary.txt'"

SUMMARY="$TMP_ROOT/summary2.txt" run_lib promote 'log_warn w; write_summary OK tool v1'
check "lib: write_summary never promotes OK to WARN after a warning (logging.md 8.3)" \
    "grep -qx 'OK|tool|v1' '$TMP_ROOT/summary2.txt' && ! grep -q '^WARN|tool|' '$TMP_ROOT/summary2.txt'"

C="$TMP_ROOT/rotate"; mkdir -p "$C/logs"
head -c 5242880 /dev/zero | tr '\0' 'x' > "$C/logs/deploy.log"
# Console output is irrelevant here; the check below inspects the rotated files.
env HOME="$C" AITOOLS_LOG_DIR="$C/logs" bash -c "source '$LIB'; logging_init t; log after" > /dev/null 2>&1
check "lib: logging_init rotates a 5 MB log to deploy.log.1" \
    "[ -f '$C/logs/deploy.log.1' ] && grep -q '\[info\] after' '$C/logs/deploy.log' && [ \$(wc -c < '$C/logs/deploy.log') -lt 1000 ]"

# Fail-safe log writes (reference/logging.md section 5): a failed log write is
# swallowed. Under set -euo pipefail the script goes on, the console lines still
# print, the counters still count, and no shell error message appears.
# run_unwritable <case> <log dir>: every log helper, then the counters
run_unwritable() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home"
    env HOME="$C/home" AITOOLS_LOG_DIR="$2" bash -c "set -euo pipefail; source '$LIB'; logging_init t; log info-line; log_detail detail-line; log_warn warn-line; log_error error-line; log_ok ok-line; _ai_log ai-line; echo \"COUNTS=\$ERRORS/\$WARNINGS\"; echo REACHED-END" > "$C/out" 2>&1
    echo $? > "$C/rc"
}
unwritable_checks() {  # <what>
    check "lib: $1 -- set -e run goes on (exit 0)" "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q REACHED-END '$C/out'"
    check "lib: $1 -- console lines still printed" \
        "grep -q '\[info\] info-line' '$C/out' && grep -q '\[warn\] warn-line' '$C/out' && grep -q '\[error\] error-line' '$C/out' && grep -q '\[ok\] ok-line' '$C/out'"
    check "lib: $1 -- log_error/log_warn still count" "grep -q 'COUNTS=1/1' '$C/out'"
    check "lib: $1 -- no shell error, detail and AI lines stay off the console" \
        "! grep -Eq 'Is a directory|Permission denied|cannot create|No such file|detail-line|ai-line' '$C/out'"
}

# deploy.log is a directory (cannot be opened for writing on any platform)
mkdir -p "$TMP_ROOT/logdir-is-dir/logs/deploy.log"
run_unwritable logdir-is-dir "$TMP_ROOT/logdir-is-dir/logs"
unwritable_checks "deploy.log is a directory"

# deploy.log without write permission (root ignores the mode: the write then works,
# and the checks still hold)
mkdir -p "$TMP_ROOT/no-write/logs"; : > "$TMP_ROOT/no-write/logs/deploy.log"
chmod 000 "$TMP_ROOT/no-write/logs/deploy.log"
run_unwritable no-write "$TMP_ROOT/no-write/logs"
chmod 644 "$TMP_ROOT/no-write/logs/deploy.log"
unwritable_checks "deploy.log not writable (chmod 000)"

# The log directory cannot be created (its parent is a file)
: > "$TMP_ROOT/not-a-dir"
run_unwritable no-dir "$TMP_ROOT/not-a-dir/logs"
unwritable_checks "log dir cannot be created"

# ---------------------------------------------------------------------------
# The shared fixture (tests/logging/fixtures/summary-cases.txt; plan
# summary-warn-reporting section 13, tests L1-L32): every case for lang both|sh
# ---------------------------------------------------------------------------
# fixture_run: a Perl runner (fed on stdin, so it may contain any quote) that
# parses the fixture, writes each case's bash script and child scripts, runs the
# case and checks its expectations. It prints one PASS / FAIL / SKIP / EXT line
# per case and a last line "FIXTURE pass=N fail=N skip=N ext=N".
FIXTURE="$ROOT/tests/logging/fixtures/summary-cases.txt"
PTY_RUN="$ROOT/tests/managed-files/pty-run.py"
FIX_OUT="$TMP_ROOT/fixture.out"
perl - "$FIXTURE" "$LIB" "$TMP_ROOT/fixture" "${BASH:-bash}" "$PTY_RUN" > "$FIX_OUT" 2>&1 <<'FIXTURE_RUNNER_EOF'
use strict;
use warnings;
my ($fixture, $lib, $root, $bash, $ptyrun) = @ARGV;
my $RULE = "\xe2\x94\x80" x 56;   # U+2500 x 56, UTF-8 bytes (the panel is read as bytes)
my %COLOUR = (green => "32", yellow => "33", red => "31", magenta => "1;35");

sub decode {
    my ($s, $where) = @_;
    my $out = "";
    while (length $s) {
        if ($s =~ s/\A\\u\{([0-9A-Fa-f]+)\}//) { my $c = chr(hex $1); utf8::encode($c); $out .= $c; next }
        if ($s =~ s/\A\\(.)//s) {
            my %m = ("\\" => "\\", p => "|", n => "\n", r => "\r", t => "\t", e => "\e", s => " ");
            die "fixture error ($where): unknown escape \\$1\n" unless exists $m{$1};
            $out .= $m{$1};
            next;
        }
        $s =~ s/\A([^\\]+)//s;
        $out .= $1;
    }
    return $out;
}
sub sq { my $s = shift; $s =~ s/'/'\\''/g; return "'$s'" }
sub splitdec { my ($rest, $where) = @_; return map { decode($_, $where) } split /\|/, $rest, -1 }

# --- parse ---
open(my $fh, "<", $fixture) or die "cannot read $fixture: $!\n";
my (@cases, $c);
while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ /\A#/ || $line eq "";
    if ($line =~ s/\A\@(sh|ps1) //) { next if $1 eq "ps1" }
    my ($kw, $rest) = $line =~ /\A(\S+)(?: (.*))?\z/s;
    $rest = "" unless defined $rest;
    if ($kw eq "case") { $c = { id => $rest, lang => "both", steps => [], exp => [], children => {}, env => [], summary => 1 }; push @cases, $c; next }
    die "fixture error: line outside a case: $line\n" unless $c;
    my $where = "$c->{id}: $line";
    if ($kw =~ /\A(?:plan|title|spec|note)\z/) { next }
    elsif ($kw eq "lang") { $c->{lang} = $rest }
    elsif ($kw eq "needs") { $c->{pty} = 1 }
    elsif ($kw eq "external") { $c->{external} = $rest }
    elsif ($kw eq "summary") { $c->{summary} = 0 if $rest eq "unset" }
    elsif ($kw eq "env") { push @{ $c->{env} }, decode($rest, $where) }
    elsif ($kw eq "stdin") { my ($k, $t) = $rest =~ /\A(\S+) (.*)\z/s; $c->{stdin} = decode($t, $where) }
    elsif ($kw eq "record") { push @{ $c->{steps} }, ["record", decode($rest, $where)] }
    elsif ($kw eq "file") { push @{ $c->{steps} }, ["file", splitdec($rest, $where)] }
    elsif ($kw eq "call") { push @{ $c->{steps} }, ["call", splitdec($rest, $where)] }
    elsif ($kw eq "relay" || $kw eq "relay-native") { push @{ $c->{steps} }, ["relay", splitdec($rest, $where)] }
    elsif ($kw eq "render") { push @{ $c->{steps} }, ["render"] }
    elsif ($kw eq "child") {
        my ($name, $act, $r) = $rest =~ /\A(\S+) (\S+)(?: (.*))?\z/s;
        die "fixture error ($where): bad child line\n" unless defined $act;
        $r = "" unless defined $r;
        $c->{children}{$name} ||= { lines => [], exit => 0 };
        if ($act eq "exit") { $c->{children}{$name}{exit} = $r }
        elsif ($act eq "call") { push @{ $c->{children}{$name}{lines} }, ["call", splitdec($r, $where)] }
        else { push @{ $c->{children}{$name}{lines} }, [$act, decode($r, $where)] }
    }
    elsif ($kw eq "expect") {
        my ($k, $r) = $rest =~ /\A(\S+)(?: (.*))?\z/s;
        $r = "" unless defined $r;
        push @{ $c->{exp} }, [$k, ($k eq "record" ? decode($r, $where) : decode($r, $where))];
    }
    elsif ($kw eq "panel") {
        my ($col, $t) = $rest =~ /\A(\S+)(?: (.*))?\z/s;
        push @{ $c->{panel} }, [$col, defined $t ? decode($t, $where) : ""];
    }
    else { die "fixture error ($where): unknown keyword $kw\n" }
}
close $fh;

# --- generate bash ---
my %HELPER = (managed_abort => "_managed_abort");
sub call_sh {
    my ($dir, @a) = @_;
    my $h = shift @a;
    my @args = map {
        my $v = $_;
        $v =~ s/\{CASEDIR\}/$dir/g;
        $v eq "{RESULT}" ? "\"\$_fx_result\"" : sq($v)
    } @a;
    if ($h eq "error_reason") {
        return "_fx_reason=\$(error_reason @args)\nprintf '%s' \"\$_fx_reason\" > " . sq("$dir/st.reason") . "\n";
    }
    if ($h eq "deploy_managed_file") {
        return "deploy_managed_file @args\n_fx_result=\"\$MANAGED_FILE_RESULT\"\nprintf '%s' \"\$_fx_result\" > " . sq("$dir/st.result") . "\n";
    }
    my $fn = $HELPER{$h} || $h;
    return "$fn @args\n";
}
sub child_sh {
    my ($dir, $name, $ch) = @_;
    my $s = "set -euo pipefail\nsource " . sq($lib) . "\nlogging_init " . sq($name) . "\n";
    for my $l (@{ $ch->{lines} }) {
        my ($act, @r) = @$l;
        if ($act eq "call") { $s .= call_sh($dir, @r) }
        elsif ($act eq "stdout") { $s .= "printf '%s\\n' " . sq($r[0]) . "\n" }
        elsif ($act eq "stderr") { $s .= "printf '%s\\n' " . sq($r[0]) . " >&2\n" }
        else { die "child action $act is not for bash\n" }
    }
    $s .= "exit $ch->{exit}\n";
    return $s;
}

my ($pass, $fail, $skip, $ext) = (0, 0, 0, 0);
for my $c (@cases) {
    my $id = $c->{id};
    next if $c->{lang} eq "ps1";
    if (defined $c->{external}) { print "EXT  fixture $id (covered by $c->{external})\n"; $ext++; next }
    if ($c->{pty} && system("command -v python3 >/dev/null 2>&1") != 0) {
        print "SKIP fixture $id (needs a terminal: python3 for tests/managed-files/pty-run.py not found)\n"; $skip++; next;
    }
    my $dir = "$root/$id";
    system("mkdir", "-p", "$dir/home", "$dir/logs") == 0 or die "mkdir $dir\n";
    for my $n (keys %{ $c->{children} }) {
        open(my $o, ">", "$dir/$n.sh") or die; print $o child_sh($dir, $n, $c->{children}{$n}); close $o;
    }
    my $s = "set -euo pipefail\nsource " . sq($lib) . "\nlogging_init test-logging\n";
    for my $st (@{ $c->{steps} }) {
        my ($k, @a) = @$st;
        if ($k eq "record") { $s .= "printf '%s\\n' " . sq($a[0]) . " >> \"\$AITOOLS_SUMMARY_FILE\"\n" }
        elsif ($k eq "file") { $s .= "printf '%s' " . sq($a[1]) . " > " . sq("$dir/$a[0]") . "\n" }
        elsif ($k eq "call") { $s .= call_sh($dir, @a) }
        elsif ($k eq "relay") {
            my ($label, $tool, $child, $opt) = @a;
            my @o;
            push @o, "--summary-tool", sq($tool) if $tool ne "";
            push @o, "--abort-warn" if defined $opt && $opt eq "abort-warn";
            $s .= "_fx_rc=0\nrun_child_relayed @o " . sq($label) . " \"\$BASH\" " . sq("$dir/$child.sh") . " || _fx_rc=\$?\n";
            $s .= "printf '%s' \"\$_fx_rc\" > " . sq("$dir/st.relayrc") . "\nprintf '%s' \"\$AITLIB_CHILD_RC\" > " . sq("$dir/st.childrc") . "\n";
        }
        elsif ($k eq "render") { $s .= "show_summary --keep > " . sq("$dir/panel.out") . "\n" }
    }
    $s .= "printf '%s' \"\$ERRORS\" > " . sq("$dir/st.errors") . "\nprintf '%s' \"\$WARNINGS\" > " . sq("$dir/st.warnings") . "\nexit 0\n";
    open(my $o, ">", "$dir/case.sh") or die; print $o $s; close $o;

    # environment: isolated, the summary file, the case's env lines
    local %ENV = %ENV;
    delete @ENV{qw(AITOOLS_FORCE FORCE DRY_RUN AITLIB_RELAYED AITOOLS_SUMMARY_FILE AITOOLS_PRESERVE_SUMMARY AITOOLS_ENVIRONMENT)};
    $ENV{HOME} = "$dir/home";
    $ENV{AITOOLS_LOG_DIR} = "$dir/logs";
    if ($c->{summary}) { open(my $e, ">", "$dir/summary.txt") or die; close $e; $ENV{AITOOLS_SUMMARY_FILE} = "$dir/summary.txt" }
    for my $kv (@{ $c->{env} }) { my ($k, $v) = split /=/, $kv, 2; $ENV{$k} = $v }
    my $rc;
    if ($c->{pty}) {
        $rc = system("python3", $ptyrun, "--input", "$c->{stdin}\\n", "--log", "$dir/pty.log", "--timeout", "30", "--", $bash, "$dir/case.sh");
    } else {
        $rc = system("/bin/sh", "-c", 'exec "$0" "$1" < /dev/null > "$2" 2> "$3"', $bash, "$dir/case.sh", "$dir/out", "$dir/err");
    }
    $rc = $rc >> 8;

    # --- expectations ---
    my @bad;
    my $slurp = sub { my $f = shift; open(my $i, "<", $f) or return undef; local $/; my $t = <$i>; close $i; return defined $t ? $t : "" };
    my $want_exit = 0;
    my @want_rec;
    my $no_rec = 0;
    for my $e (@{ $c->{exp} }) { $want_exit = $e->[1] if $e->[0] eq "case-exit" }
    push @bad, "case process exited $rc, want $want_exit" . ($c->{pty} ? "" : ": " . ($slurp->("$dir/err") // "")) if $rc != $want_exit;
    my $sum = $c->{summary} ? ($slurp->("$dir/summary.txt") // "") : "";
    (my $sum_trim = $sum) =~ s/\n\z//;
    my $log = $slurp->("$dir/logs/deploy.log") // "";
    my @loglines = split /\n/, $log;
    for my $e (@{ $c->{exp} }) {
        my ($k, $v) = @$e;
        if ($k eq "record") { push @want_rec, $v }
        elsif ($k eq "no-records") { $no_rec = 1 }
        elsif ($k eq "record-count") {
            my ($n, $p) = $v =~ /\A(\d+) (.*)\z/s;
            my $got = grep { index($_, $p) == 0 } split /\n/, $sum;
            push @bad, "record-count $p: got $got, want $n" if $got != $n;
        }
        elsif ($k eq "count") {
            my ($which, $n) = split / /, $v;
            my $got = $slurp->("$dir/st.$which") // "(none)";
            push @bad, "count $which: got $got, want $n" if $got ne $n;
        }
        elsif ($k eq "log") {
            push @bad, "log: no line \"$v\"" unless grep { /\A\[[^\]]+\] (.*)\z/ && $1 eq $v } @loglines;
        }
        elsif ($k eq "logsub") {
            my ($lvl, $t) = $v =~ /\A(\S+) (.*)\z/s;
            push @bad, "logsub $lvl: no line containing \"$t\"" unless grep { index($_, "] [$lvl] ") >= 0 && index($_, $t) >= 0 } @loglines;
        }
        elsif ($k eq "reason") { my $g = $slurp->("$dir/st.reason") // "(none)"; push @bad, "reason: got \"$g\", want \"$v\"" if $g ne $v }
        elsif ($k eq "result") { my $g = $slurp->("$dir/st.result") // "(none)"; push @bad, "result: got \"$g\", want \"$v\"" if $g ne $v }
        elsif ($k eq "relay-rc") { my $g = $slurp->("$dir/st.relayrc") // "(none)"; push @bad, "relay-rc: got $g, want $v" if $g ne $v }
        elsif ($k eq "child-rc") { my $g = $slurp->("$dir/st.childrc") // "(none)"; push @bad, "child-rc: got $g, want $v" if $g ne $v }
        elsif ($k eq "case-exit") { }
        elsif ($k eq "panel-none") { my $g = $slurp->("$dir/panel.out") // ""; push @bad, "panel-none: render printed " . length($g) . " bytes" if $g ne "" }
        else { push @bad, "unknown expectation $k" }
    }
    if (@want_rec || $no_rec) {
        my $want = join("\n", @want_rec);
        push @bad, "records:\n      got:  " . join("\n            ", split /\n/, $sum_trim) . "\n      want: " . join("\n            ", @want_rec) if $sum_trim ne $want;
    }
    if ($c->{panel}) {
        my @got = split /\n/, ($slurp->("$dir/panel.out") // ""), -1;
        pop @got if @got && $got[-1] eq "";
        my @want = @{ $c->{panel} };
        my $n = @got > @want ? @got : @want;
        for my $i (0 .. $n - 1) {
            my $g = $got[$i];
            my $w = $want[$i];
            if (!defined $g || !defined $w) { push @bad, "panel line " . ($i + 1) . ": got " . (defined $g ? "\"$g\"" : "nothing") . ", want " . (defined $w ? "$w->[0] \"$w->[1]\"" : "nothing"); next }
            my ($code) = $g =~ /\A\e\[([0-9;]*)m/;
            (my $plain = $g) =~ s/\e\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]//g;
            my ($col, $text) = @$w;
            if ($col eq "blank") { push @bad, "panel line " . ($i + 1) . ": want blank, got \"$plain\"" if $g ne ""; next }
            if ($col eq "rule") { push @bad, "panel line " . ($i + 1) . ": want the rule, got \"$plain\"" if $g ne $RULE; next }
            push @bad, "panel line " . ($i + 1) . ": want $col \"$text\", got " . (defined $code ? "\\e[${code}m" : "no colour") . " \"$plain\""
                if !defined $code || $code ne $COLOUR{$col} || $plain ne $text;
        }
    }
    if (@bad) { print "FAIL fixture $id\n"; print "      | $_\n" for @bad; $fail++ }
    else { print "PASS fixture $id\n"; $pass++ }
}
print "FIXTURE pass=$pass fail=$fail skip=$skip ext=$ext\n";
FIXTURE_RUNNER_EOF
fix_rc=$?
cat "$FIX_OUT"
fix_line=$(perl -ne 'print $1 if /^FIXTURE (.*)$/' "$FIX_OUT")
fix_pass=$(perl -ne 'print $1 if /^FIXTURE pass=(\d+)/' "$FIX_OUT")
fix_fail=$(perl -ne 'print $1 if /^FIXTURE .*fail=(\d+)/' "$FIX_OUT")
check "fixture: the runner completed (exit $fix_rc; $fix_line)" "[ '$fix_rc' = 0 ] && [ -n '$fix_line' ]"
PASS=$((PASS + ${fix_pass:-0}))
FAIL=$((FAIL + ${fix_fail:-0}))

# ---------------------------------------------------------------------------
# Library pieces the fixture does not cover (the I1 contract and its addendum):
# summary_begin / summary_end, run_relay_sync, the relay's --no-mirror, --quiet,
# name fallback and nested rules, one deploy.jsonl record per line, the abort
# recorded once, repair_uv_tool_env, write_action's ACTION de-duplication and
# the options. Each case: $C/main.sh (and child scripts) in a fresh bash, the
# library at $X_LIB, the case directory at $X_DIR.
# ---------------------------------------------------------------------------
# xcase NAME: a new case directory C with logs/ and an empty summary file
xcase() {
    C="$TMP_ROOT/x-$1"
    mkdir -p "$C/home" "$C/logs"
    : > "$C/summary.txt"
}
# xrun [ENV=VALUE...]: run $C/main.sh; stdout -> $C/out, stderr -> $C/err, exit -> $C/rc
xrun() {
    env -u AITLIB_RELAYED -u AITOOLS_FORCE HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" \
        AITOOLS_SUMMARY_FILE="$C/summary.txt" X_LIB="$LIB" X_DIR="$C" "$@" "${BASH:-bash}" "$C/main.sh" \
        < /dev/null > "$C/out" 2> "$C/err"
    echo $? > "$C/rc"
}
# count_lines FILE FIXED: lines of FILE containing FIXED (0 when FILE is missing)
count_lines() {
    if [ -f "$1" ]; then grep -cF -- "$2" "$1"; else echo 0; fi
}

# summary_begin / summary_end: the owner creates, draws and deletes the file
xcase sum-owner
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
unset AITOOLS_SUMMARY_FILE
source "$X_LIB"; logging_init t
summary_begin
f="$AITOOLS_SUMMARY_FILE"
printf 'OWNER=%s EXISTS=%s\n' "$AITLIB_SUMMARY_OWNER" "$([ -f "$f" ] && echo yes || echo no)"
write_summary OK owned-tool v1
summary_end
printf 'AFTER=%s GONE=%s\n' "${AITOOLS_SUMMARY_FILE:-unset}" "$([ -e "$f" ] && echo no || echo yes)"
EOF
xrun
check "summary_begin: unset -> creates and exports the file, this process owns it" "grep -q 'OWNER=true EXISTS=yes' '$C/out'"
check "summary_end: the owner draws the panel" "grep -q 'owned-tool' '$C/out'"
check "summary_end: the owner deletes the file and unsets AITOOLS_SUMMARY_FILE" "grep -q 'AFTER=unset GONE=yes' '$C/out'"

xcase sum-notowner
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
summary_begin
printf 'OWNER=%s FILE=%s\n' "$AITLIB_SUMMARY_OWNER" "$AITOOLS_SUMMARY_FILE"
write_summary OK parent-tool v1
summary_end
EOF
xrun
check "summary_begin: already set -> not the owner, the file is the parent's" "grep -q 'OWNER=false FILE=$C/summary.txt' '$C/out'"
check "summary_end: not the owner -> draws nothing, the file stays" \
    "! grep -q 'parent-tool' '$C/out' && grep -qx 'OK|parent-tool|v1' '$C/summary.txt'"

# run_relay_sync: output as detail lines; a failure is one warning with its reason
xcase relay-sync
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_relay_sync bash -c 'echo synced-line; echo note-line >&2' || rc=$?
printf 'OK-RC=%s W=%s\n' "$rc" "$WARNINGS"
rc=0
run_relay_sync bash -c 'echo progress; echo "Error: relay.md not found" >&2; exit 4' || rc=$?
printf 'FAIL-RC=%s W=%s\n' "$rc" "$WARNINGS"
cp "$AITOOLS_SUMMARY_FILE" "$X_DIR/summary-fail.txt"
rc=0
run_relay_sync aitools-test-no-such-python sync.py || rc=$?
printf 'NF-RC=%s W=%s\n' "$rc" "$WARNINGS"
EOF
xrun
check "run_relay_sync: success -> output as detail lines, no warning" \
    "grep -q 'OK-RC=0 W=0' '$C/out' && grep -q '\[detail\] relay sync: synced-line' '$C/logs/deploy.log' && grep -q '\[detail\] relay sync: note-line' '$C/logs/deploy.log'"
check "run_relay_sync: failure -> its exit code, one warning under 'relay sync' with the reason" \
    "grep -q 'FAIL-RC=4 W=1' '$C/out' && [ \"\$(cat '$C/summary-fail.txt')\" = 'WARN|relay sync|relay -> AGENTS.md sync failed (exit 4, non-fatal): Error: relay.md not found' ]"
check "run_relay_sync: command not found -> 127, one warning 'not run'" \
    "grep -q 'NF-RC=127 W=2' '$C/out' && grep -qx 'WARN|relay sync|relay -> AGENTS.md sync not run (non-fatal): aitools-test-no-such-python not found' '$C/summary.txt'"
check "run_relay_sync: failure -> the output is in deploy.log as detail lines" "grep -q '\[detail\] output: progress' '$C/logs/deploy.log'"

# --no-mirror / --quiet / name fallback
xcase relay-opts
cat > "$C/child.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init opt-child
log "info-line"
log_warn "warn-line"
printf 'plain-line\n'
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
run_child_relayed --no-mirror "nm" bash "$X_DIR/child.sh"
printf 'NM-JSONL=%s\n' "$(grep -c 'info-line' "$AITOOLS_LOG_DIR/deploy.jsonl" 2>/dev/null || echo 0)"
run_child_relayed "mirrored" bash "$X_DIR/child.sh"
printf 'M-JSONL=%s\n' "$(grep -c 'info-line' "$AITOOLS_LOG_DIR/deploy.jsonl" 2>/dev/null || echo 0)"
printf -- '---QUIET---\n'
run_child_relayed --quiet "q" bash "$X_DIR/child.sh"
printf -- '---END--- CW=%s W=%s\n' "$AITLIB_CHILD_WARNINGS" "$WARNINGS"
rc=0
run_child_relayed "my label" bash -c 'exit 3' || rc=$?
printf 'FALLBACK-RC=%s\n' "$rc"
EOF
xrun
check "relay --no-mirror: the child's lines are not mirrored to deploy.jsonl" "grep -q 'NM-JSONL=0' '$C/out'"
check "relay (default): the child's lines are mirrored once" "grep -q 'M-JSONL=1' '$C/out'"
check "relay --quiet: only the child's warn line is printed (all lines counted)" \
    "perl -ne 'print if /---QUIET---/ .. /---END---/' '$C/out' > '$C/quiet.txt'; grep -q 'warn-line' '$C/quiet.txt' && ! grep -q 'info-line' '$C/quiet.txt' && ! grep -q 'plain-line' '$C/quiet.txt' && grep -q 'CW=1 W=0' '$C/out'"
check "relay: no tool and no .sh/.ps1 argument -> the record is named after the label" \
    "grep -q 'FALLBACK-RC=1' '$C/out' && grep -qx 'ERROR|my label|my label failed (exit 3)|no output (exit 3)' '$C/summary.txt'"

# One deploy.jsonl record per structured line: only the outermost relay mirrors
# (AITLIB_RELAYED), also when the middle script sets the jsonl option
xcase one-mirror
cat > "$C/gc.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init gc
log "gc-line"
EOF
cat > "$C/middle.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init middle
AITLIB_OPT_JSONL=true
log "mid-line"
run_child_relayed "gc" bash "$X_DIR/gc.sh"
log "mid-after"
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
run_child_relayed "middle" bash "$X_DIR/middle.sh"
EOF
xrun
check "nested relays: each structured line is in deploy.jsonl exactly once" \
    "[ \"\$(count_lines '$C/logs/deploy.jsonl' '\"msg\":\"mid-line\"')\" = 1 ] && [ \"\$(count_lines '$C/logs/deploy.jsonl' '\"msg\":\"gc-line\"')\" = 1 ] && [ \"\$(count_lines '$C/logs/deploy.jsonl' '\"msg\":\"mid-after\"')\" = 1 ]"

# A nested abort is recorded once, by the innermost relay
xcase nested-abort
cat > "$C/gc.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init gc
_managed_abort
EOF
cat > "$C/middle.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init middle
run_child_relayed --summary-tool "inner tool" "gc step" bash "$X_DIR/gc.sh" || true
exit "$AITLIB_CHILD_RC"
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_child_relayed --summary-tool "outer tool" "middle step" bash "$X_DIR/middle.sh" || rc=$?
printf 'RC=%s CHILD=%s E=%s W=%s\n' "$rc" "$AITLIB_CHILD_RC" "$ERRORS" "$WARNINGS"
EOF
xrun
check "nested abort: one record, by the innermost relay; the outer relay counts it without a second record" \
    "[ \"\$(cat '$C/summary.txt')\" = 'ERROR|inner tool|gc step failed (exit 2)|aborted by user' ] && grep -q 'RC=1 CHILD=2 E=1 W=0' '$C/out'"

# --abort-warn when the child recorded a warning, then aborted: its warning is
# not an abort record, so the relay records the abort (8.3 "A user abort")
xcase abort-warn-after-warn
cat > "$C/child.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init dh
write_warn "harness files" "something odd"
_managed_abort
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_child_relayed --summary-tool "harness files" --abort-warn "deploy-harness" bash "$X_DIR/child.sh" || rc=$?
printf 'RC=%s CHILD=%s E=%s W=%s\n' "$rc" "$AITLIB_CHILD_RC" "$ERRORS" "$WARNINGS"
EOF
xrun
check "relay --abort-warn: a warning, then an abort -- the relay records the abort, one parent warning" \
    "[ \"\$(cat '$C/summary.txt')\" = 'WARN|harness files|something odd
WARN|harness files|aborted by user' ] && grep -q 'RC=1 CHILD=2 E=0 W=1' '$C/out'"

# The same without --abort-warn: one ERROR abort record after the child's warning
xcase abort-after-warn
cat > "$C/child.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init fx
write_warn "fx tool" "skipped one file"
_managed_abort
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_child_relayed --summary-tool "fx tool" "fx step" bash "$X_DIR/child.sh" || rc=$?
printf 'RC=%s CHILD=%s E=%s W=%s\n' "$rc" "$AITLIB_CHILD_RC" "$ERRORS" "$WARNINGS"
EOF
xrun
check "relay: a warning, then an abort -- one ERROR abort record from the relay, one parent error" \
    "[ \"\$(cat '$C/summary.txt')\" = 'WARN|fx tool|skipped one file
ERROR|fx tool|fx step failed (exit 2)|aborted by user' ] && grep -q 'RC=1 CHILD=2 E=1 W=0' '$C/out' && ! grep -q 'the child recorded it' '$C/logs/deploy.log'"

# --abort-warn when the child wrote the abort record itself: not recorded again
xcase abort-warn-recorded
cat > "$C/child.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init dh
write_warn "harness files" "aborted by user"
exit 2
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_child_relayed --summary-tool "harness files" --abort-warn "deploy-harness" bash "$X_DIR/child.sh" || rc=$?
printf 'RC=%s CHILD=%s E=%s W=%s\n' "$rc" "$AITLIB_CHILD_RC" "$ERRORS" "$WARNINGS"
EOF
xrun
check "relay --abort-warn: an abort record the child wrote is counted, not recorded again" \
    "[ \"\$(cat '$C/summary.txt')\" = 'WARN|harness files|aborted by user' ] && grep -q 'RC=1 CHILD=2 E=0 W=1' '$C/out' && grep -q 'deploy-harness aborted by user -- the child recorded it' '$C/logs/deploy.log'"

# A failed child that recorded its own error: the relay logs no derived reason
xcase fail-recorded-log
cat > "$C/child.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init fr
write_error "fr tool" "fr step" "the real cause"
log "an unrelated last line"
exit 1
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_child_relayed --summary-tool "fr tool" "fr run" bash "$X_DIR/child.sh" || rc=$?
printf 'RC=%s E=%s\n' "$rc" "$ERRORS"
EOF
xrun
check "relay: a failed child that recorded its error -- logged '<label> failed (exit N) -- the child recorded its error', no derived reason" \
    "[ \"\$(cat '$C/summary.txt')\" = 'ERROR|fr tool|fr step|the real cause' ] && grep -q 'RC=1 E=1' '$C/out' && grep -q '\[t\] \[error\] fr run failed (exit 1) -- the child recorded its error\$' '$C/logs/deploy.log' && ! grep -q 'unrelated last line --' '$C/logs/deploy.log'"

# A middle script's own error lines decide, not a grandchild's it re-printed
xcase own-errors
cat > "$C/gc.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init gc
log_error "gc-err"
EOF
cat > "$C/middle.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init middle
out=$(bash "$X_DIR/gc.sh") || true
relay_child_log "$out"
log "middle done"
exit 0
EOF
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
run_child_relayed "middle step" bash "$X_DIR/middle.sh" || rc=$?
printf 'RC=%s CE=%s E=%s\n' "$rc" "$AITLIB_CHILD_ERRORS" "$ERRORS"
EOF
xrun
check "nested relay: a grandchild's error line re-printed by a middle script that exits 0 does not fail it" \
    "grep -q 'RC=0 CE=0 E=0' '$C/out' && [ \"\$(cat '$C/summary.txt')\" = 'ERROR|gc|gc-err|' ]"

# repair_uv_tool_env: 1 not applicable; 3 failed and recorded under TOOL
xcase uv-repair
mkdir -p "$C/stub"
cat > "$C/stub/uv" <<'EOF'
#!/bin/bash
if [ "$1 $2" = "python find" ]; then exit 1; fi
if [ "$1 $2" = "tool install" ]; then echo "error: boom" >&2; exit 2; fi
exit 0
EOF
chmod +x "$C/stub/uv"
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
rc=0
repair_uv_tool_env modal "some other failure" "modal cli" || rc=$?
printf 'NA-RC=%s E=%s\n' "$rc" "$ERRORS"
rc=0
repair_uv_tool_env modal "error: missing a valid environment" "modal cli" || rc=$?
printf 'FAIL-RC=%s E=%s W=%s\n' "$rc" "$ERRORS" "$WARNINGS"
EOF
xrun PATH="$C/stub:/usr/bin:/bin"
check "repair_uv_tool_env: not applicable -> 1, nothing recorded" "grep -q 'NA-RC=1 E=0' '$C/out'"
check "repair_uv_tool_env: failed -> 3, one error under TOOL with its reason, no warning" \
    "grep -q 'FAIL-RC=3 E=1 W=0' '$C/out' && [ \"\$(grep -c . '$C/summary.txt')\" = 1 ] && grep -q '^ERROR|modal cli|modal uv environment repair failed' '$C/summary.txt'"

# write_action: an identical ACTION is written once
xcase action-dedupe
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
write_action vercel "not authenticated -- run: vercel login" "vercel login"
write_action vercel2 "not authenticated -- run: vercel login" "vercel login"
printf 'W=%s\n' "$WARNINGS"
EOF
xrun
check "write_action: two warnings, the identical ACTION once" \
    "grep -q 'W=2' '$C/out' && [ \"\$(count_lines '$C/summary.txt' 'ACTION||vercel login')\" = 1 ] && [ \"\$(count_lines '$C/summary.txt' 'WARN|')\" = 2 ]"

# Options: stderr console (and no records), colour on a terminal only, jsonl
xcase opt-stderr
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"
AITLIB_OPT_CONSOLE_STDERR=true
logging_init t
log_warn "to-stderr"
write_warn tool "not-recorded"
write_error tool "what" "why"
printf 'W=%s E=%s\n' "$WARNINGS" "$ERRORS"
EOF
xrun
check "option stderr console: console lines on stderr only" \
    "grep -q 'to-stderr' '$C/err' && ! grep -q 'to-stderr' '$C/out'"
check "option stderr console: the helpers count but record nothing (library-style tool)" \
    "grep -q 'W=2 E=1' '$C/out' && [ ! -s '$C/summary.txt' ]"

xcase opt-color
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
AITLIB_OPT_COLOR_AUTO=true
log_warn "auto-colour"
AITLIB_OPT_COLOR_AUTO=false
log_warn "always-colour"
EOF
xrun
check "option colour auto: no colour when stdout is not a terminal" \
    "perl -ne 'BEGIN { \$a = \$b = 0 } \$a++ if /auto-colour/ && !/\\e/; \$b++ if /always-colour/ && /\\e\\[33m/; END { exit((\$a == 1 && \$b == 1) ? 0 : 1) }' '$C/out'"

xcase opt-jsonl
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
AITLIB_OPT_JSONL=true
log "jsonl-line"
write_warn tool "jsonl-warn"
EOF
xrun
check "option jsonl: each log line is also one deploy.jsonl record" \
    "[ \"\$(count_lines '$C/logs/deploy.jsonl' '\"msg\":\"jsonl-line\"')\" = 1 ] && [ \"\$(count_lines '$C/logs/deploy.jsonl' '\"level\":\"warn\"')\" = 1 ]"

# dotprofile_commit_push: a failed commit or push is one warning under TOOL whose
# text carries "(exit N: <reason>)", the reason from git's output (logging.md
# 8.3; the same text in Invoke-DotprofileCommitPush)
xcase dp-push
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
cd "$X_DIR"
git init -q --bare remote.git
git clone -q remote.git dp 2> /dev/null
git -C dp config user.name t
git -C dp config user.email t@example.invalid
printf 'init\n' > dp/init.md
git -C dp add init.md
git -C dp commit -q -m init
git -C dp push -q -u origin HEAD 2> /dev/null
AITLIB_USER_REPO_PATH="$X_DIR/dp"
# Commit failure: a pre-commit hook refuses the commit
printf '#!/bin/sh\necho "error: blocked by hook" >&2\nexit 1\n' > dp/.git/hooks/pre-commit
chmod +x dp/.git/hooks/pre-commit
printf 'x\n' > dp/x.md
dotprofile_commit_push "$X_DIR/dp/x.md" "add x" "dp tool"
printf 'COMMIT=%s W=%s\n' "$AITLIB_DOTPROFILE_PUSH" "$WARNINGS"
cp "$AITOOLS_SUMMARY_FILE" "$X_DIR/summary-commit.txt"
: > "$AITOOLS_SUMMARY_FILE"
rm dp/.git/hooks/pre-commit
# Push failure: the remote is gone
rm -rf remote.git
printf 'y\n' > dp/y.md
dotprofile_commit_push "$X_DIR/dp/y.md" "add y" "dp tool"
printf 'PUSH=%s W=%s\n' "$AITLIB_DOTPROFILE_PUSH" "$WARNINGS"
EOF
if command -v git >/dev/null 2>&1; then
    xrun
    check "dotprofile_commit_push: a failed commit -> one warning under TOOL with git's error line as its reason" \
        "grep -q 'COMMIT=commit-failed W=1' '$C/out' && [ \"\$(cat '$C/summary-commit.txt')\" = \"WARN|dp tool|dotprofile commit failed (exit 1: error: blocked by hook) -- commit and push x.md in $C/dp by hand
ACTION||commit and push x.md in $C/dp\" ]"
    check "dotprofile_commit_push: a failed push -> one warning under TOOL with git's error line as its reason" \
        "grep -q 'PUSH=push-failed W=2' '$C/out' && [ \"\$(grep -c . '$C/summary.txt')\" = 2 ] && perl -ne 'BEGIN { \$n = 0 } \$n++ if m{^WARN\\|dp tool\\|dotprofile push failed \\(exit [1-9][0-9]*: fatal: .*\\) -- run git push in \\Q$C/dp\\E\$}; END { exit(\$n == 1 ? 0 : 1) }' '$C/summary.txt' && grep -qxF 'ACTION||run git push in $C/dp' '$C/summary.txt'"
    check "dotprofile_commit_push: git's output is in deploy.log as detail lines" \
        "grep -q '\[detail\] output: error: blocked by hook' '$C/logs/deploy.log'"
else
    printf 'SKIP dotprofile_commit_push cases: git not found\n'
fi

# The JSON field review and the settings sync: a field overwritten in a
# non-interactive run is one warning under the caller's tool (logging.md 8.3
# "What is a warning", as for a text file: L32b); under --force it is info; a
# field only in LOCAL is kept, no warning; a live file that is created, none
xcase json-overwrite
cat > "$C/main.sh" <<'EOF'
set -euo pipefail
source "$X_LIB"; logging_init t
local_json='{
  "a": 1,
  "b": 2,
  "z": 9
}'
printf '%s\n' "$local_json" > "$X_DIR/x.json"
deploy_managed_file '{"a": 5, "b": 2, "c": 3}' "$X_DIR/x.json" "json tool" "x.json"
printf 'NI=%s W=%s\n' "$MANAGED_FILE_RESULT" "$WARNINGS"
cp "$AITOOLS_SUMMARY_FILE" "$X_DIR/summary-ni.txt"
: > "$AITOOLS_SUMMARY_FILE"
printf '%s\n' "$local_json" > "$X_DIR/x.json"
export AITOOLS_FORCE=1
deploy_managed_file '{"a": 5, "b": 2, "c": 3}' "$X_DIR/x.json" "json tool" "x.json"
unset AITOOLS_FORCE
printf 'FORCE=%s W=%s\n' "$MANAGED_FILE_RESULT" "$WARNINGS"
cp "$AITOOLS_SUMMARY_FILE" "$X_DIR/summary-force.txt"
: > "$AITOOLS_SUMMARY_FILE"
printf '{"theme": "dark"}\n' > "$X_DIR/settings.json"
printf '{"claude": {"settings": {"theme": "light"}}}\n' > "$X_DIR/profile.json"
sync_managed_json "$X_DIR/settings.json" "$X_DIR/profile.json" "claude.settings" "hooks" "" "claude settings"
printf 'SYNC=%s W=%s\n' "$SYNC_MANAGED_JSON_RESULT" "$WARNINGS"
cp "$AITOOLS_SUMMARY_FILE" "$X_DIR/summary-sync.txt"
: > "$AITOOLS_SUMMARY_FILE"
rm "$X_DIR/settings.json"
sync_managed_json "$X_DIR/settings.json" "$X_DIR/profile.json" "claude.settings" "hooks" "" "claude settings"
printf 'NEW=%s W=%s\n' "$SYNC_MANAGED_JSON_RESULT" "$WARNINGS"
EOF
if command -v node >/dev/null 2>&1; then
    xrun
    check "JSON field review, non-interactive: one warning per overwritten field under TOOL; a local-only field kept" \
        "grep -q 'NI=updated W=2' '$C/out' && [ \"\$(cat '$C/summary-ni.txt')\" = 'WARN|json tool|Divergence in x.json: a -- overwriting from source (non-interactive)
WARN|json tool|Divergence in x.json: c -- overwriting from source (non-interactive)' ] && grep -q '\"z\": 9' '$C/x.json'"
    check "JSON field review, non-interactive: the warning is logged at warn" \
        "grep -q '\[warn\] Divergence in x.json: a -- overwriting from source (non-interactive)' '$C/logs/deploy.log'"
    check "JSON field review, --force: info, no warning, no record" \
        "grep -q 'FORCE=updated W=2' '$C/out' && [ ! -s '$C/summary-force.txt' ] && grep -q '\[info\] Divergence in x.json: a -- overwriting from source (--force)' '$C/logs/deploy.log'"
    check "settings sync, non-interactive: an overwritten leaf is one warning under TOOL" \
        "grep -q 'SYNC=updated W=3' '$C/out' && [ \"\$(cat '$C/summary-sync.txt')\" = 'WARN|claude settings|Divergence in theme -- overwriting from profile.json (non-interactive)' ]"
    check "settings sync: a live file created from the profile -> no warning" \
        "grep -q 'NEW=created W=3' '$C/out' && [ ! -s '$C/summary.txt' ]"
else
    printf 'SKIP JSON field review cases: node not found\n'
fi

# ---------------------------------------------------------------------------
# scripts/check-lib.sh -- checks.log / checks.jsonl writers (incident #174)
# ---------------------------------------------------------------------------
# The same fail-safe contract for the check scripts' own log files: under
# set -euo pipefail a checks.log / checks.jsonl that cannot be written (or a log
# dir that cannot be created) ends nothing, every step line still prints and
# every step counter still counts. A writable pair still gets every line.
CHECK_LIB="$ROOT/scripts/check-lib.sh"
# run_checks <case> <log dir>: check_log_init, one step of each kind, print_summary
run_checks() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home"
    env HOME="$C/home" AITOOLS_LOG_DIR="$2" bash -c "set -euo pipefail; source '$CHECK_LIB'; check_log_init probe; step_pass 1 pass-step; step_fail 2 fail-step 'a \"quoted\" detail'; step_warn 3 warn-step; step_skip 4 skip-step; print_summary; echo \"COUNTS=\$PASS_COUNT/\$FAIL_COUNT/\$WARN_COUNT/\$SKIP_COUNT\"; echo REACHED-END" > "$C/out" 2>&1
    echo $? > "$C/rc"
}
check_run_checks() {  # <what>
    check "check-lib: $1 -- set -e run goes on (exit 0)" "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q REACHED-END '$C/out'"
    check "check-lib: $1 -- step lines still printed" \
        "grep -q 'pass-step.*\[PASS\]' '$C/out' && grep -q 'fail-step.*\[FAIL\]' '$C/out' && grep -q 'warn-step.*\[WARN\]' '$C/out' && grep -q 'skip-step.*\[SKIP\]' '$C/out' && grep -q 'SUMMARY: 1 PASS, 1 SKIP, 1 WARN, 1 FAIL' '$C/out'"
    check "check-lib: $1 -- step counters still count" "grep -q 'COUNTS=1/1/1/1' '$C/out'"
    check "check-lib: $1 -- no shell error on the console" \
        "! grep -Eq 'Is a directory|Permission denied|cannot create|Not a directory|No such file' '$C/out'"
}

# Writable: every line reaches checks.log, every checks.jsonl line is one JSON object
run_checks checks-written "$TMP_ROOT/checks-written/logs"
check_run_checks "writable"
check "check-lib: writable -- checks.log has run start, the 4 steps and the summary" \
    "[ \"\$(grep -cE 'RUN START|pass-step|fail-step.*a \"quoted\" detail|warn-step|skip-step|=== SUMMARY: 1 PASS, 1 SKIP, 1 WARN, 1 FAIL' '$TMP_ROOT/checks-written/logs/checks.log')\" = 6 ]"
check "check-lib: writable -- checks.jsonl has 6 records, each valid JSON" \
    "perl -MJSON::PP -ne 'BEGIN { \$n = 0; \$bad = 0 } s/\\r?\\n\\z//; \$n++; \$bad++ unless eval { decode_json(\$_); 1 }; END { exit((\$n == 6 && !\$bad) ? 0 : 1) }' '$TMP_ROOT/checks-written/logs/checks.jsonl'"

# checks.log and checks.jsonl are directories
mkdir -p "$TMP_ROOT/checks-dir/logs/checks.log" "$TMP_ROOT/checks-dir/logs/checks.jsonl"
run_checks checks-dir "$TMP_ROOT/checks-dir/logs"
check_run_checks "checks.log/.jsonl are directories"

# checks.log and checks.jsonl without write permission (root ignores the mode:
# the writes then work, and the checks still hold)
mkdir -p "$TMP_ROOT/checks-nowrite/logs"
: > "$TMP_ROOT/checks-nowrite/logs/checks.log"; : > "$TMP_ROOT/checks-nowrite/logs/checks.jsonl"
chmod 000 "$TMP_ROOT/checks-nowrite/logs/checks.log" "$TMP_ROOT/checks-nowrite/logs/checks.jsonl"
run_checks checks-nowrite "$TMP_ROOT/checks-nowrite/logs"
chmod 644 "$TMP_ROOT/checks-nowrite/logs/checks.log" "$TMP_ROOT/checks-nowrite/logs/checks.jsonl"
check_run_checks "checks.log/.jsonl not writable (chmod 000)"

# The log directory cannot be created (its parent is a file)
: > "$TMP_ROOT/checks-notadir"
run_checks checks-nodir "$TMP_ROOT/checks-notadir/logs"
check_run_checks "log dir cannot be created"

# ---------------------------------------------------------------------------
# scripts/aitools (entry point) -- uses the lib's logging, defines none of its own
# ---------------------------------------------------------------------------

check "entry: defines no log functions (uses aitools-lib)" \
    "! grep -Eq '^[[:space:]]*(log|log_ok|log_warn|log_error|log_detail)\(\)' '$ENTRY'"

# The cases below run scripts/aitools past its argument parsing. (In Git Bash on
# Windows it hands off to aitools.ps1 before any of this code runs: commander,
# 2026-11-14, RFI 38dc-3; tests/aitools-entry/test-win-forwarder.ps1 covers that
# path.)

# fake_repo <case> [with-lib]: HOME with config.json -> a repo dir holding the lib.
fake_repo() {
    C="$TMP_ROOT/$1"
    mkdir -p "$C/home/.aitools" "$C/repo/.git" "$C/repo/scripts"
    if [ "${2:-}" = "with-lib" ]; then cp "$LIB" "$C/repo/scripts/"; fi
    printf '{"version":2,"repoPath":"%s"}\n' "$C/repo" > "$C/home/.aitools/config.json"
}
run_entry() {  # args... (uses $C from fake_repo)
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" bash "$ENTRY" "$@" < /dev/null > "$C/out" 2> "$C/err"
    echo $? > "$C/rc"
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || { mkdir -p "$C/logs"; : > "$LOG"; }
}

fake_repo unknown with-lib
run_entry --bogus-flag
check "entry: unknown argument exits 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
check "entry: unknown argument written to deploy.log" \
    "grep -Eq '^${TS_RE} \[aitools\] \[error\] unknown argument .--bogus-flag.' '$LOG'"
check "entry: unknown argument shown in the lib's console format (not a bare 'error:')" \
    "grep -Eq '${TS_RE} \[aitools\] \[error\] unknown argument' '$C/out' && ! grep -q '^error: unknown argument' '$C/err'"

fake_repo prelib with-lib
mkdir -p "$C/home/.config/ai-tooling"
run_entry --bogus-flag
check "entry: warnings found before the lib loads are logged after it loads" \
    "grep -q '\[aitools\] \[warn\] both .*ai-tooling.* exist' '$LOG'"

fake_repo nolib
run_entry --bogus-flag
check "entry: missing aitools-lib exits 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
check "entry: missing aitools-lib names the path on stderr" "grep -q 'aitools-lib.sh not found at $C/repo/scripts' '$C/err'"

fake_repo version
rm -rf "$C/repo"
run_entry --version
check "entry: --version answers without the repo" \
    "[ \"\$(cat '$C/rc')\" = 0 ] && grep -q '^aitools ' '$C/out' && grep -q 'repo: not found' '$C/out'"

printf -- '---- %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
