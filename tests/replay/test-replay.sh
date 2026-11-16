#!/usr/bin/env bash
# test-replay.sh -- the replay test (plan summary-warn-reporting, step I6): the
# order of the commander's pasted run, replayed under a pseudo-terminal through
# the library's real relay (run_child_relayed), and the end-of-run panel it
# draws checked line by line against reference/logging.md 8.5.
#
# The run (tests/replay/fixtures/replay-parent.sh, an entry point that owns the
# run summary file and relays each child as scripts/aitools deploy_configs does):
#   1. setup-node.sh (fixture): records one warning with an ACTION under
#      "aitools config" (write_action), then OK|node.js|v26
#   2. the real scripts/setup-user-claude.sh (temp aitools copy): its
#      ~/.claude/CLAUDE.md differs from the template, so its review menu appears
#      on the terminal and is answered [s]kip; one harness rule and one harness
#      skill are fanned out
#   3. setup-crash.sh (fixture): writes "boom" to stderr, exits 3
#   4. Step 2 ("Authenticate gh") of scripts/aitools-install.sh, copied verbatim
#      into a child (fixtures/gh-auth-child.tmpl): gh auth status fails, so it
#      runs the stub gh auth login </dev/tty >/dev/tty, answered on the terminal
# Expected (plan section 11 I6): node.js, claude rules and claude skills green;
# one yellow claude.md line; one yellow aitools config line and its ACTION; one
# red line with the crash reason; no duplicate line; the parent exits 1. The
# review menu appears and takes its answer exactly as it does when
# setup-user-claude runs unrelayed (compared with a direct run on the same
# pseudo-terminal), and gh auth login gets the terminal as stdin and stdout.
# A second run relays only the gh child with gh auth login failing (exit 4):
# one red line (the child's own error, not recorded again by the relay) and its
# ACTION.
#
# Isolation: every run has its own HOME and AITOOLS_LOG_DIR under a temp
# directory created here (removed on exit), PATH = a stub directory (gh) plus
# /usr/bin:/bin, a temp copy of the scripts it runs and a fixture dotprofile;
# never the real HOME, dotprofile or tools.
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# macOS and Linux only. There is no PowerShell twin: the plan's I6 asks for one
# suite, and a pseudo-terminal replay on Windows (ConPTY) is out of its scope;
# the PowerShell relay and panel are covered by tests/logging/test-logging.ps1.
# Needs python3 (tests/managed-files/pty-run.py, POSIX pty): without it every
# case is reported SKIP.
#
# Safe to re-run. Exit 1 on failure.
# Usage: bash tests/replay/test-replay.sh [--help]
#   AITOOLS_TEST_BASH=/bin/bash runs the parent and its children under another
#   bash (macOS 3.2)
#   AITOOLS_TEST_KEEP=1 keeps the temp directory and prints its path

set -euo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows there is no replay suite (a pty replay on Windows is out of scope: see the header).\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows there is no replay suite (a pty replay on Windows is out of scope: see the header).\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'last unless /^#/; print if $. > 1' "$0"
    exit 0
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$REPO/tests/replay/fixtures"
PTY="$REPO/tests/managed-files/pty-run.py"

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  skip %s\n' "$1"; }
# show FILE: a file's lines, indented, after a failure
show() { perl -pe 's/^/       | /' "$1"; }

PY=""
if command -v python3 >/dev/null 2>&1; then PY="$(command -v python3)"; fi
if [ -z "$PY" ]; then
    skip "every replay case (python3 not found: no pseudo-terminal)"
    printf '\nreplay: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
    exit 0
fi

# The bash the parent and its children run under (children use the parent's
# $BASH): an absolute path, since PATH is cut down for the run
TB="${AITOOLS_TEST_BASH:-bash}"
case "$TB" in
    /*) ;;
    *) TB="$(command -v "$TB")" ;;
esac

WORK="$(mktemp -d)"
# AITOOLS_TEST_KEEP=1 keeps the temp directory (its path is printed) for a look
# at the raw terminal output (*.raw), the panels and the HOMEs
cleanup() {
    if [ "${AITOOLS_TEST_KEEP:-}" = "1" ]; then printf 'kept: %s\n' "$WORK"; return 0; fi
    rm -rf "$WORK"
}
trap cleanup EXIT

# A fixture step that fails ends the run (exit 1) instead of showing up later
# as failed or vacuous checks
fixture_fail() { printf 'FATAL fixture setup failed: %s\n' "$1"; exit 1; }
gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Temp aitools copy: the scripts the run executes, unchanged (a git
# checkout, as a dev clone is: adopt targets of shared rules land here) ---
A="$WORK/aitools"
mkdir -p "$A/scripts" "$A/shared" || fixture_fail "mkdir $A"
for f in setup-user-claude.sh aitools-lib.sh aitools-profile.sh aitools-json.pl aitools-install.sh; do
    cp "$REPO/scripts/$f" "$A/scripts/$f" || fixture_fail "cp scripts/$f"
done
cp "$REPO/shared/claude-shared.md" "$A/shared/claude-shared.md" || fixture_fail "cp shared/claude-shared.md"
git -C "$A" init -q || fixture_fail "git init $A"

# --- Fixture dotprofile (git repo, no remote): the CLAUDE.md template and a
# profile.json whose profile m1 config.json names (machineAlias) ---
DP="$WORK/aitools-tess"
mkdir -p "$DP/claude" || fixture_fail "mkdir $DP"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md" || fixture_fail "dotprofile CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json" || fixture_fail "dotprofile profile.json"
git -C "$DP" init -q || fixture_fail "git init $DP"
gitc -C "$DP" add -A || fixture_fail "git add (dotprofile)"
gitc -C "$DP" commit -q -m fixture || fixture_fail "git commit (dotprofile)"

# --- Stub bin: gh only (PATH = this + /usr/bin:/bin) ---
mkdir -p "$WORK/bin" || fixture_fail "mkdir bin"
cp "$FIX/gh-stub.sh" "$WORK/bin/gh" || fixture_fail "cp gh stub"
chmod +x "$WORK/bin/gh" || fixture_fail "chmod gh stub"

# --- The gh-auth child: Step 2 of the installer, verbatim, in the template ---
# The block is the installer's lines from `log "Step 2: gh authentication"` to
# the first `fi` at the start of a line after it. A missing block (the
# installer changed) fails the fixture, not silently a weaker case.
GH_CHILD="$WORK/gh-auth-child.sh"
perl -e '
    my ($tmpl, $inst) = @ARGV;
    open(my $i, "<", $inst) or die "cannot read $inst: $!\n";
    my ($in, $done, $block) = (0, 0, "");
    while (my $l = <$i>) {
        next if $done;
        $in = 1 if !$in && $l =~ /^log "Step 2: gh authentication"$/;
        next unless $in;
        $block .= $l;
        if ($l =~ /^fi$/) { $done = 1 }
    }
    close $i;
    die "Step 2 block not found in $inst\n" unless $done;
    die "Step 2 block has no gh auth login </dev/tty\n" unless $block =~ m{gh auth login </dev/tty >/dev/tty};
    open(my $t, "<", $tmpl) or die "cannot read $tmpl: $!\n";
    my $out = "";
    my $n = 0;
    while (my $l = <$t>) {
        if ($l =~ /^\@INSTALLER_STEP2\@$/) { $out .= $block; $n++ } else { $out .= $l }
    }
    close $t;
    die "template has no \@INSTALLER_STEP2\@ line\n" unless $n == 1;
    print $out;
' "$FIX/gh-auth-child.tmpl" "$A/scripts/aitools-install.sh" > "$GH_CHILD" || fixture_fail "gh-auth child from the installer's Step 2"
"$TB" -n "$GH_CHILD" || fixture_fail "gh-auth child: bash -n"

# The panel's rule (reference/logging.md 8.5: bash, U+2500 x 56)
RULE="$(perl -CS -e 'print "\x{2500}" x 56')"
CLAUDE_LOCAL='# my own CLAUDE.md, edited on this machine'

# seed_home H: a HOME with config.json -> the fixture dotprofile, one harness
# rule and one harness skill (with their manifests, as deploy-harness writes
# them) and a ~/.claude/CLAUDE.md that differs from the template
seed_home() {
    local h="$1"
    mkdir -p "$h/.aitools/rules" "$h/.aitools/skills/replay-skill" "$h/.claude" || fixture_fail "mkdir $h"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$h/.aitools/config.json" || fixture_fail "config.json"
    printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$h/.gitconfig" || fixture_fail ".gitconfig"
    printf '## replay rule\n' > "$h/.aitools/rules/replay.md" || fixture_fail "harness rule"
    printf '# aitools rules manifest v1\nreplay.md\tshared\n' > "$h/.aitools/rules/.aitools-rules-manifest" || fixture_fail "rules manifest"
    printf -- '---\nname: replay-skill\ndescription: replay fixture skill\n---\n\n# replay skill\n' > "$h/.aitools/skills/replay-skill/SKILL.md" || fixture_fail "harness skill"
    printf '# aitools skills manifest v1\nreplay-skill\tshared\n' > "$h/.aitools/skills/.aitools-skills-manifest" || fixture_fail "skills manifest"
    printf '%s\n' "$CLAUDE_LOCAL" > "$h/.claude/CLAUDE.md" || fixture_fail "local CLAUDE.md"
}

# pty_env H: the environment of a run in HOME H (an array, RUN_ENV): nothing of
# the caller's aitools state, stub PATH, logs under H, the resolver's test
# overrides for the machine id and hostname (never the real machine's: the
# fixture profile m1 is found by its alias)
pty_env() {
    local h="$1"
    RUN_ENV=(env -u AITOOLS_SUMMARY_FILE -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_DEPLOY
        -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1
        -u AITOOLS_MACHINE_ALIAS -u AITOOLS_ENVIRONMENT -u AITOOLS_RUN_ID -u AITLIB_RELAYED
        -u CLAUDE_CODE_REMOTE -u NO_COLOR
        HOME="$h" PATH="$WORK/bin:/usr/bin:/bin" TERM=xterm
        AITOOLS_LOG_DIR="$h/.aitools/logs" AITOOLS_PRESERVE_SUMMARY=1
        GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1
        AITOOLS_PROFILE_TEST_MACHINE_ID="cccccccc-1111-2222-3333-444444444444" AITOOLS_PROFILE_TEST_HOSTNAME=replay-host
        REPLAY_LIB="$A/scripts/aitools-lib.sh" REPLAY_CLAUDE="$A/scripts/setup-user-claude.sh"
        REPLAY_GH="$GH_CHILD" GH_STUB_LOG="$h/gh-stub.log")
}

# norm FILE OUT: the terminal output as text: CR, SGR colours and other
# control sequences removed
norm() {
    perl -pe '
        s/\e\[(\d*)C/" " x ($1 || 1)/ge;
        s/\e\[[0-9;?]*[ -\/]*[@-~]//g;
        s/\e\][^\a\e]*(?:\a|\e\\)//g;
        s/\r//g;' "$1" > "$2"
}

# panel NORM OUT: the panel the run drew: the empty line before its first rule
# line through its last rule line (reference/logging.md 8.5 "panel"); nothing
# when no rule line was printed
panel() {
    RULE="$RULE" perl -ne '
        BEGIN { $r = $ENV{RULE}; @l = () }
        chomp; push @l, $_;
        END {
            my ($f, $t);
            for my $i (0 .. $#l) { if ($l[$i] eq $r) { $f = $i unless defined $f; $t = $i } }
            exit 0 unless defined $f && $t > $f;
            $f-- if $f > 0 && $l[$f - 1] eq "";
            print "$l[$_]\n" for $f .. $t;
        }' "$1" > "$2"
}

# menu NORM OUT: the review menu of CLAUDE.md as the terminal showed it: the
# [REVIEW] line through the ">> skipped" line, without the structured log lines
# the relay or the script printed meanwhile, without the typed answers' echo
# (they echo where the terminal received them, which depends on timing), and
# with the prompt line ending at its prompt
menu() {
    perl -ne '
        BEGIN { $in = 0 }
        chomp;
        $in = 1 if /\[REVIEW\] .*CLAUDE\.md differs from source\./;
        next unless $in;
        next if /^\[[^\]]+\] \[[^\]]+\] \[[a-z]+\] /;
        next if $_ eq "s" || $_ eq "tok-replay";
        if (/^(\s*choice \[[a-z\/]+\]: )(.*)$/) {
            # The prompt has no newline: what follows it on the line is the
            # echoed answer and, when it was typed ahead, the next output
            my ($p, $rest) = ($1, $2);
            print "$p\n";
            $rest =~ s/^s(?=\s|$)//;
            next if $rest eq "";
            $_ = $rest;
        }
        print "$_\n";
        exit 0 if /^  >> skipped: local file unchanged$/;' "$1" > "$2"
}

# cut70 TEXT: a yellow line's text as reference/logging.md 8.5 "Cutting" draws
# it: TEXT itself when it is at most 70 code points long, else its first 67
# followed by "..." (the expected panel is built from the records by the rule,
# not copied from a run)
cut70() { T="$1" perl -CSA -e 'my $s = $ENV{T}; utf8::decode($s); print length($s) <= 70 ? $s : substr($s, 0, 67) . "..."' ; }

# same EXPECTED_FILE GOT_FILE NAME: exact comparison, the diff on a failure
same() {
    if diff -u "$1" "$2" > "$WORK/diff.out" 2>&1; then ok "$3"
    else bad "$3"; show "$WORK/diff.out"; fi
}
# count_lines FILE LINE: how often LINE is a whole line of FILE
count_lines() { LINE="$2" perl -ne 'BEGIN { $n = 0 } chomp; $n++ if $_ eq $ENV{LINE}; END { print $n }' "$1"; }
# has_line FILE LINE NAME
has_line() {
    if [ "$(count_lines "$1" "$2")" -ge 1 ]; then ok "$3"
    else bad "$3 (no line '$2')"; show "$1"; fi
}

# ===========================================================================
# Case 1: the replay
# ===========================================================================
printf '== replay: node (warning + ACTION, OK node.js), setup-user-claude (menu: s), crash (boom), gh auth login (tty)\n'
H1="$WORK/replay/home"
seed_home "$H1"
pty_env "$H1"
RC1=0
"${RUN_ENV[@]}" REPLAY_STEPS="node claude crash gh" \
    "$PY" "$PTY" --timeout 120 --input 's\ntok-replay\n' --log "$WORK/replay.raw" -- "$TB" "$FIX/replay-parent.sh" > "$WORK/replay.pty" 2>&1 || RC1=$?
norm "$WORK/replay.raw" "$WORK/replay.out"
panel "$WORK/replay.out" "$WORK/replay.panel"
SUM1="$H1/.aitools/logs/last-summary.txt"
LOG1="$H1/.aitools/logs/deploy.log"

if [ "$RC1" -eq 1 ]; then ok "replay: the parent exits 1"
else bad "replay: the parent exits $RC1, want 1"; show "$WORK/replay.out"; show "$WORK/replay.pty"; fi

# The panel, line by line (reference/logging.md 8.5): green in OK order with
# each tool's DETAIL lines under it; yellow in log order; red with what failed
# and why; the ACTION once
{
    printf '\n%s\n' "$RULE"
    printf '  [ok]  %-16s %s\n' "node.js" "v26"
    printf '  [ok]  %-16s %s\n' "claude rules" "1 added"
    printf '%26s%s\n' "" "added: replay.md"
    printf '  [ok]  %-16s %s\n' "claude skills" "1 added"
    printf '%26s%s\n' "" "added: replay-skill/SKILL.md"
    printf '  [!]   %-16s %s\n' "aitools config" "$(cut70 "this machine is not registered -- run: aitools user init")"
    printf '  [!]   %-16s %s\n' "claude.md" "$(cut70 "skipped at review, local differs from source: CLAUDE.md")"
    printf '  [ERR] %-16s %s\n' "crash test" "setup-crash.sh failed (exit 3): boom"
    printf '\n  ACTION REQUIRED -- run before tools are ready:\n'
    printf '  >>  %s\n' "Run: aitools user init (registers this machine)"
    printf '%s\n' "$RULE"
} > "$WORK/replay.want"
same "$WORK/replay.want" "$WORK/replay.panel" "replay: the panel is the expected one, line by line"

# The objective's points one by one (they name what broke when the whole-panel
# comparison above fails)
for t in "node.js" "claude rules" "claude skills"; do
    n=$(T="$t" perl -ne 'BEGIN { $n = 0 } $n++ if /^  \[ok\]  \Q$ENV{T}\E\s/; END { print $n }' "$WORK/replay.panel")
    if [ "$n" -eq 1 ]; then ok "replay: $t is green (one line)"
    else bad "replay: $t has $n green line(s), want 1"; fi
done
for t in "node.js" "claude rules" "claude skills"; do
    n=$(T="$t" perl -ne 'BEGIN { $n = 0 } $n++ if /^  \[(?:!\] |ERR\])  ?\Q$ENV{T}\E\s/; END { print $n }' "$WORK/replay.panel")
    if [ "$n" -eq 0 ]; then ok "replay: $t has no yellow or red line"
    else bad "replay: $t has $n yellow or red line(s)"; fi
done
n=$(perl -ne 'BEGIN { $n = 0 } $n++ if /^  \[!\]   claude\.md\s/; END { print $n }' "$WORK/replay.panel")
if [ "$n" -eq 1 ]; then ok "replay: one yellow claude.md line"; else bad "replay: $n yellow claude.md line(s), want 1"; fi
n=$(perl -ne 'BEGIN { $n = 0 } $n++ if /^  \[!\]   aitools config\s/; END { print $n }' "$WORK/replay.panel")
if [ "$n" -eq 1 ]; then ok "replay: one yellow aitools config line"; else bad "replay: $n yellow aitools config line(s), want 1"; fi
n=$(perl -ne 'BEGIN { $n = 0 } $n++ if /^  \[ERR\] /; END { print $n }' "$WORK/replay.panel")
if [ "$n" -eq 1 ]; then ok "replay: one red line"; else bad "replay: $n red line(s), want 1"; fi
has_line "$WORK/replay.panel" "  [ERR] crash test       setup-crash.sh failed (exit 3): boom" "replay: the red line states what failed and the crash reason (boom)"
has_line "$WORK/replay.panel" "  >>  Run: aitools user init (registers this machine)" "replay: the aitools config ACTION is shown"
# Colours (8.5 "Colours", bash): green 32, yellow 33, red 31, ACTION bold
# magenta 1;35, on the raw terminal output
colours=$(perl -ne '
    BEGIN { %want = ("  [ok]  node.js" => "32", "  [ok]  claude rules" => "32", "  [ok]  claude skills" => "32",
        "  [!]   aitools config" => "33", "  [!]   claude.md" => "33", "  [ERR] crash test" => "31",
        "  ACTION REQUIRED" => "1;35", "  >>  Run: aitools user init" => "1;35"); %got = () }
    s/\r//g;
    for my $k (keys %want) { $got{$k} = $1 if /\e\[([0-9;]+)m\Q$k\E/ }
    END { for my $k (sort keys %want) { print "$k: want $want{$k}, got ", ($got{$k} // "none"), "\n" if ($got{$k} // "") ne $want{$k} } }' "$WORK/replay.raw")
if [ -z "$colours" ]; then ok "replay: green, yellow, red and ACTION lines in their 8.5 colours"
else bad "replay: panel colours: $colours"; fi
dups=$(RULE="$RULE" perl -ne 'chomp; next if $_ eq "" || $_ eq $ENV{RULE}; print "$_\n" if $seen{$_}++ == 1' "$WORK/replay.panel")
if [ -z "$dups" ]; then ok "replay: no duplicate line in the panel"
else bad "replay: duplicate panel line(s): $dups"; fi

# The run summary file (kept as last-summary.txt): each warning and error
# recorded once (8.3 "Recorded at the source"), node.js's status never
# recoloured (an OK record, no WARN or ERROR record under its name)
if [ -f "$SUM1" ]; then
    for want in 'OK|node.js|v26' 'WARN|aitools config|this machine is not registered -- run: aitools user init' \
        'ACTION||Run: aitools user init (registers this machine)' \
        'WARN|claude.md|skipped at review, local differs from source: CLAUDE.md' \
        'ERROR|crash test|setup-crash.sh failed (exit 3)|boom'; do
        n=$(count_lines "$SUM1" "$want")
        if [ "$n" -eq 1 ]; then ok "replay: record '$want' once"
        else bad "replay: record '$want' $n time(s), want 1"; show "$SUM1"; fi
    done
    n=$(perl -ne 'BEGIN { $n = 0 } $n++ if /^(?:WARN|ERROR)\|/; END { print $n }' "$SUM1")
    if [ "$n" -eq 3 ]; then ok "replay: 3 WARN/ERROR records in all (2 warnings, 1 error)"
    else bad "replay: $n WARN/ERROR records, want 3"; show "$SUM1"; fi
    n=$(perl -ne 'BEGIN { $n = 0 } $n++ if /^(?:WARN|ERROR)\|(?:node\.js|claude rules|claude skills)\|/; END { print $n }' "$SUM1")
    if [ "$n" -eq 0 ]; then ok "replay: no WARN/ERROR record under node.js, claude rules or claude skills"
    else bad "replay: $n WARN/ERROR record(s) under a green tool"; show "$SUM1"; fi
else
    bad "replay: no last-summary.txt (AITOOLS_PRESERVE_SUMMARY=1)"
fi

# The review menu in the relayed child: shown on the terminal, answered s,
# skipped (CLAUDE.md unchanged), the answer logged at detail
if perl -ne 'BEGIN { $f = 0 } $f = 1 if /^\s*\[s\]kip\s+: nothing written; asked again next run$/; END { exit($f ? 0 : 1) }' "$WORK/replay.out"; then
    ok "replay: the CLAUDE.md review menu appears in the relayed child"
else
    bad "replay: no review menu in the output"; show "$WORK/replay.out"
fi
has_line "$WORK/replay.out" "  >> skipped: local file unchanged" "replay: the menu took the answer s (skipped)"
if [ "$(perl -0777 -ne 'print' "$H1/.claude/CLAUDE.md")" = "$CLAUDE_LOCAL" ]; then ok "replay: ~/.claude/CLAUDE.md left as it was (skip)"
else bad "replay: ~/.claude/CLAUDE.md changed"; show "$H1/.claude/CLAUDE.md"; fi
if [ -f "$LOG1" ] && perl -ne 'BEGIN { $f = 0 } $f = 1 if /\[detail\] menu answer \(review CLAUDE\.md\): "s" -> s$/; END { exit($f ? 0 : 1) }' "$LOG1"; then
    ok "replay: deploy.log has the menu answer (s -> s)"
else
    bad "replay: deploy.log has no 'menu answer (review CLAUDE.md): \"s\" -> s'"
fi

# gh auth login inside the relayed child: the terminal is its stdin and stdout
# (the relay's stdout is a pipe), the answer typed on the terminal reaches it
if [ -f "$H1/gh-stub.log" ] && [ "$(perl -ne 'print' "$H1/gh-stub.log")" = "stdin=tty stdout=tty answer=tok-replay" ]; then
    ok "replay: gh auth login runs on the terminal (stdin and stdout) and reads the typed answer"
else
    bad "replay: gh auth login did not get the terminal or the answer"
    if [ -f "$H1/gh-stub.log" ]; then show "$H1/gh-stub.log"; else printf '       | (gh stub never ran)\n'; fi
fi
if perl -ne 'BEGIN { $f = 0 } $f = 1 if /\? Paste your authentication token:/; END { exit($f ? 0 : 1) }' "$WORK/replay.out"; then
    ok "replay: the gh auth login prompt is shown on the terminal"
else
    bad "replay: no gh auth login prompt on the terminal"
fi

# The same menu, unrelayed: setup-user-claude run directly on the pseudo-
# terminal in the same HOME (CLAUDE.md still differs), as before the scripts
# ran relayed. The menus must be the same.
printf '== direct: setup-user-claude.sh unrelayed on the same terminal, menu answered s\n'
: > "$WORK/direct.summary"
RCD=0
"${RUN_ENV[@]}" AITOOLS_SUMMARY_FILE="$WORK/direct.summary" \
    "$PY" "$PTY" --timeout 90 --input 's\n' --log "$WORK/direct.raw" -- "$TB" "$A/scripts/setup-user-claude.sh" > "$WORK/direct.pty" 2>&1 || RCD=$?
norm "$WORK/direct.raw" "$WORK/direct.out"
menu "$WORK/direct.out" "$WORK/direct.menu"
menu "$WORK/replay.out" "$WORK/replay.menu"
if [ "$RCD" -eq 0 ]; then ok "direct: setup-user-claude exits 0"
else bad "direct: setup-user-claude exits $RCD, want 0"; show "$WORK/direct.out"; fi
if [ -s "$WORK/direct.menu" ] && [ -s "$WORK/replay.menu" ]; then
    same "$WORK/direct.menu" "$WORK/replay.menu" "replay: the relayed review menu equals the unrelayed one"
else
    bad "replay: a review menu is missing (direct $(wc -l < "$WORK/direct.menu" | tr -d ' ') lines, relayed $(wc -l < "$WORK/replay.menu" | tr -d ' ') lines)"
    show "$WORK/direct.out"
fi

# ===========================================================================
# Case 2: gh auth login fails inside the relayed child
# ===========================================================================
printf '== gh-fail: Step 2 relayed, gh auth login exits 4\n'
H2="$WORK/ghfail/home"
seed_home "$H2"
pty_env "$H2"
RC2=0
"${RUN_ENV[@]}" REPLAY_STEPS="gh" GH_LOGIN_RC=4 \
    "$PY" "$PTY" --timeout 60 --input 'tok-replay\n' --log "$WORK/ghfail.raw" -- "$TB" "$FIX/replay-parent.sh" > "$WORK/ghfail.pty" 2>&1 || RC2=$?
norm "$WORK/ghfail.raw" "$WORK/ghfail.out"
panel "$WORK/ghfail.out" "$WORK/ghfail.panel"
if [ "$RC2" -eq 1 ]; then ok "gh-fail: the parent exits 1"
else bad "gh-fail: the parent exits $RC2, want 1"; show "$WORK/ghfail.out"; fi
{
    printf '\n%s\n' "$RULE"
    printf '  [ERR] %-16s %s\n' "gh auth" "gh auth login failed (exit 4): no output (exit 4)"
    printf '\n  ACTION REQUIRED -- run before tools are ready:\n'
    printf '  >>  %s\n' "Run: gh auth login"
    printf '%s\n' "$RULE"
} > "$WORK/ghfail.want"
same "$WORK/ghfail.want" "$WORK/ghfail.panel" "gh-fail: one red line (the child's error, not recorded again by the relay) and its ACTION"
SUM2="$H2/.aitools/logs/last-summary.txt"
if [ -f "$SUM2" ]; then
    n=$(perl -ne 'BEGIN { $n = 0 } $n++ if /^ERROR\|/; END { print $n }' "$SUM2")
    if [ "$n" -eq 1 ]; then ok "gh-fail: one ERROR record"
    else bad "gh-fail: $n ERROR records, want 1"; show "$SUM2"; fi
else
    bad "gh-fail: no last-summary.txt"
fi
if [ -f "$H2/gh-stub.log" ] && [ "$(perl -ne 'print' "$H2/gh-stub.log")" = "stdin=tty stdout=tty answer=tok-replay" ]; then
    ok "gh-fail: gh auth login ran on the terminal"
else
    bad "gh-fail: gh auth login did not get the terminal or the answer"
fi

printf '\nreplay: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
