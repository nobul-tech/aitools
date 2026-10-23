#!/usr/bin/env bash
# test-install.sh -- the installers' Step 3 and Step 5 helpers and log override on
# the lib relay (M3-FINISH item 7, FIX-2; audit A-1, A-16, A-17, A-18), in bash
# (scripts/aitools-install.sh) and PowerShell (scripts/aitools-install.ps1).
#
# The full installer cannot run here (incident #89). Each case extracts the two
# blocks "# --- BEGIN install log helpers" and "# --- BEGIN install log override"
# from the installer, sources aitools-lib with logging_init "aitools-install"
# under an isolated HOME, and runs one step against a stub config writer:
#   step5-warn     a writer warning is counted in the installer's WARNINGS, its
#                  lines reach deploy.jsonl (one run_id with the installer's own)
#                  and the console; its own OK row is kept
#   step5-crash    a writer that dies without a row: one error and the relay's
#                  "ERROR|aitools config|script failed (exit 1)"
#   step5-ownrow   a writer that wrote its own ERROR row and exits 1: one error,
#                  no second row
#   jsonl-blocked  deploy.jsonl cannot be written: one warning, the installer
#                  goes on to the end (set -euo pipefail in bash)
#   step3-*        Step 3 (resolve_repos_dir / Resolve-ReposDir): a relative path
#                  made absolute; a path that cannot be created, or (bash) not
#                  resolved, is one error and one ERROR row "aitools config"
# Platform: macOS/Linux (pwsh runs the .ps1 blocks on any OS). Safe to re-run.
# Usage: bash tests/profile/test-install.sh [--bash-only]
#   AITOOLS_TEST_BASH=/bin/bash runs the bash harness under another bash (macOS 3.2)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
cleanup() {
    # a case leaves a directory without permissions: restore before removing
    if [ -d "$WORK/home/locked" ]; then chmod 755 "$WORK/home/locked"; fi
    rm -rf "$WORK"
}
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
USE_PS=true
if [ "${1:-}" = "--bash-only" ] || ! command -v pwsh >/dev/null 2>&1; then USE_PS=false; fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

H="$WORK/home"

# Stub config writers. WRITER_MODE: warn (one warning, its own OK row, exit 0),
# crash (one warning, then exit 1 without a row or footer), ownrow (log_error, its
# own ERROR row, exit 1), runid (logs the AITOOLS_RUN_ID it sees), quiet (one info
# line, exit 0)
cat > "$WORK/writer.sh" <<'WRITER'
ts="2026-01-01T00:00:00Z"
printf '[%s] [setup-user-config] [info] stub writer\n' "$ts"
case "${WRITER_MODE:-quiet}" in
    warn)
        printf '[%s] [setup-user-config] [warn] stub warning\n' "$ts"
        printf 'OK|aitools config|stub\n' >> "$AITOOLS_SUMMARY_FILE"
        printf '[%s] [setup-user-config] [warn] COMPLETED with 1 warning(s)\n' "$ts"
        exit 0 ;;
    crash)
        printf '[%s] [setup-user-config] [warn] stub warning\n' "$ts"
        exit 1 ;;
    runid)
        printf '[%s] [setup-user-config] [info] run id %s\n' "$ts" "${AITOOLS_RUN_ID:-unset}"
        exit 0 ;;
    ownrow)
        printf '[%s] [setup-user-config] [error] stub failed\n' "$ts"
        printf 'ERROR|aitools config|stub failed\n' >> "$AITOOLS_SUMMARY_FILE"
        printf '[%s] [setup-user-config] [error] FAILED with 1 error(s)\n' "$ts"
        exit 1 ;;
esac
exit 0
WRITER
cat > "$WORK/writer.ps1" <<'WRITER'
param([string]$ReposPath = "", [string]$RepoPath = "")
$ts = "2026-01-01T00:00:00Z"
Write-Host "[$ts] [setup-user-config] [info] stub writer"
switch ($env:WRITER_MODE) {
    "warn" {
        Write-Host "[$ts] [setup-user-config] [warn] stub warning"
        [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "OK|aitools config|stub`n")
        Write-Host "[$ts] [setup-user-config] [warn] COMPLETED with 1 warning(s)"
        exit 0
    }
    "crash" { Write-Host "[$ts] [setup-user-config] [warn] stub warning"; exit 1 }
    "runid" {
        $rid = if ($env:AITOOLS_RUN_ID) { $env:AITOOLS_RUN_ID } else { "unset" }
        Write-Host "[$ts] [setup-user-config] [info] run id $rid"
        exit 0
    }
    "ownrow" {
        Write-Host "[$ts] [setup-user-config] [error] stub failed"
        [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "ERROR|aitools config|stub failed`n")
        Write-Host "[$ts] [setup-user-config] [error] FAILED with 1 error(s)"
        exit 1
    }
}
exit 0
WRITER

# Harnesses: the two installer blocks, then MODE (step5 / step3 PATH), then a last
# log line and the counters (reaching "END" = the installer went on)
cat > "$WORK/harness.sh" <<'HARNESS'
set -euo pipefail
repo="$1"; mode="$2"; shift 2
source "$repo/scripts/aitools-lib.sh"
logging_init "aitools-install"
blocks=$(perl -0777 -ne 'print "$1\n" while /^# --- BEGIN install log (?:helpers|override)[^\n]*\n(.*?)^# --- END install log (?:helpers|override) ---/msg' "$repo/scripts/aitools-install.sh")
if [ -z "$blocks" ]; then printf 'no installer blocks\n'; exit 3; fi
eval "$blocks"
log "harness start"
case "$mode" in
    step5) run_config_writer "$WRITER" --repos-path /x/repos --repo-path /x/repos/aitools ;;
    step3) if resolve_repos_dir "$1"; then printf 'REPOS=%s\n' "$REPOS_PATH"; else printf 'REPOS_FAILED\n'; fi ;;
esac
log "harness end"
printf 'END errors=%s warnings=%s\n' "$ERRORS" "$WARNINGS"
HARNESS
cat > "$WORK/harness.ps1" <<'HARNESS'
param([string]$Repo, [string]$Mode, [string]$ReposPath = "")
. (Join-Path $Repo "scripts/aitools-lib.ps1")
Initialize-Logging "aitools-install"
$text = [IO.File]::ReadAllText((Join-Path $Repo "scripts/aitools-install.ps1"))
$ms = [regex]::Matches($text, '(?ms)^# --- BEGIN install log (?:helpers|override)[^\n]*\n(.*?)^# --- END install log (?:helpers|override) ---')
if ($ms.Count -ne 2) { Write-Output "installer blocks: $($ms.Count), want 2"; exit 3 }
foreach ($m in $ms) { Invoke-Expression $m.Groups[1].Value }
Log "harness start"
switch ($Mode) {
    "step5" { Invoke-ConfigWriter $env:WRITER @{ ReposPath = "/x/repos"; RepoPath = "/x/repos/aitools" } }
    "step3" { $p = Resolve-ReposDir $ReposPath; if ($p) { Write-Output "REPOS=$p" } else { Write-Output "REPOS_FAILED" } }
}
Log "harness end"
Write-Output "END errors=$($script:errors) warnings=$($script:warnings)"
HARNESS

# jsonl-check.pl FILE -- every line valid JSON; prints "records=N invalid=M runids=K
# child=C childwarn=W" (C: setup-user-config records, W: its warn records)
cat > "$WORK/jsonl-check.pl" <<'PERL'
use strict; use warnings; use JSON::PP;
my $f = shift @ARGV; my ($n, $bad, $c, $w) = (0, 0, 0, 0); my %run;
open(my $fh, "<:raw", $f) or do { print "records=0 (no file)\n"; exit 0 };
while (my $l = <$fh>) {
    chomp $l; $n++;
    my $o = eval { JSON::PP->new->utf8->decode($l) };
    if (!$o) { $bad++; next; }
    $run{$o->{run_id}} = 1;
    if ($o->{script} eq "setup-user-config") { $c++; $w++ if $o->{level} eq "warn" && $o->{msg} eq "stub warning"; }
}
printf "records=%d invalid=%d runids=%d child=%d childwarn=%d\n", $n, $bad, scalar(keys %run), $c, $w;
PERL

# run_h IMPL MODE [PATH] -- run a harness; RC, OUT (console, colour codes removed), SUM
run_h() {
    local impl="$1" mode="$2" path="${3:-}"
    RC=0
    : > "$H/summary.txt"
    if [ "$impl" = "bash" ]; then
        (cd "$H" && env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            WRITER="$WORK/writer.sh" WRITER_MODE="${WRITER_MODE:-quiet}" \
            "$BASH_BIN" "$WORK/harness.sh" "$REPO" "$mode" ${path:+"$path"}) > "$WORK/out.txt" 2>&1 || RC=$?
    else
        (cd "$H" && env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            WRITER="$WORK/writer.ps1" WRITER_MODE="${WRITER_MODE:-quiet}" \
            pwsh -NoProfile -File "$WORK/harness.ps1" -Repo "$REPO" -Mode "$mode" -ReposPath "$path") > "$WORK/out.txt" 2>&1 || RC=$?
    fi
    perl -pi -e 's/\e\[[0-9;]*m//g; s/\r//g' "$WORK/out.txt"
    OUT="$WORK/out.txt"
    SUM=$(cat "$H/summary.txt")
}
fresh() { rm -rf "$H"; mkdir -p "$H/.aitools/logs"; }
want_end() {  # want_end NAME "errors=E warnings=W"
    local got
    got=$(perl -ne 'print "$1\n" if /^END (errors=\d+ warnings=\d+)/' "$OUT")
    if [ "$RC" -eq 0 ] && [ "$got" = "$2" ]; then ok "$1: reached the end, $2"
    else bad "$1: rc=$RC end '$got', want '$2'"; perl -pe 's/^/       /' "$OUT"; fi
}
want_sum() {  # want_sum NAME ROWS
    if [ "$SUM" = "$2" ]; then ok "$1: summary rows"
    else bad "$1: summary '$SUM', want '$2'"; fi
}
want_out() {  # want_out NAME TEXT
    if grep -qF -- "$2" "$OUT"; then ok "$1: console has '$2'"
    else bad "$1: console lacks '$2'"; perl -pe 's/^/       /' "$OUT"; fi
}
count_out() {  # count_out NAME TEXT N
    local n
    n=$(perl -ne 'BEGIN { $t = shift @ARGV } $n++ if index($_, $t) >= 0; END { print $n + 0 }' "$2" "$OUT")
    if [ "$n" -eq "$3" ]; then ok "$1: '$2' $3 time(s)"
    else bad "$1: '$2' $n time(s), want $3"; perl -pe 's/^/       /' "$OUT"; fi
}

IMPLS="bash"
if $USE_PS; then IMPLS="bash ps"; fi
printf 'installer Step 3 / Step 5 on the lib relay (pwsh: %s)\n' "$USE_PS"
for impl in $IMPLS; do
    # A-1: a writer warning is counted, its lines reach deploy.jsonl and the console
    fresh; WRITER_MODE=warn run_h "$impl" step5
    want_end "step5-warn ($impl)" "errors=0 warnings=1"
    want_sum "step5-warn ($impl)" "OK|aitools config|stub"
    want_out "step5-warn ($impl)" "[setup-user-config] [warn] stub warning"
    got=$(perl "$WORK/jsonl-check.pl" "$H/.aitools/logs/deploy.jsonl")
    # harness start + end (installer) and the writer's three lines (info, warn, footer)
    if [ "$got" = "records=5 invalid=0 runids=1 child=3 childwarn=1" ]; then ok "step5-warn ($impl): deploy.jsonl ($got)"
    else bad "step5-warn ($impl): deploy.jsonl '$got', want records=5 invalid=0 runids=1 child=3 childwarn=1"; fi

    # Review B m-4: the installer exports one AITOOLS_RUN_ID; the child sees it and
    # every record (the installer's and the relayed child's) carries it
    fresh; WRITER_MODE=runid run_h "$impl" step5
    got=$(perl -MJSON::PP -e '
        my %ids; my $child = "";
        open(my $fh, "<:raw", $ARGV[0]) or do { print "no file\n"; exit 0 };
        while (my $l = <$fh>) { my $o = decode_json($l); $ids{$o->{run_id}} = 1; $child = $1 if $o->{msg} =~ /^run id (\S+)$/; }
        my @k = keys %ids;
        print((@k == 1 && $child ne "" && $child ne "unset" && $k[0] eq $child) ? "same\n" : "ids=@k child=$child\n");' "$H/.aitools/logs/deploy.jsonl")
    if [ "$got" = "same" ]; then ok "step5-runid ($impl): the child's AITOOLS_RUN_ID is every record's run_id"
    else bad "step5-runid ($impl): $got"; fi

    # A-18 / A-3: a writer that dies without a row gets the relay's ERROR row
    fresh; WRITER_MODE=crash run_h "$impl" step5
    want_end "step5-crash ($impl)" "errors=1 warnings=1"
    want_sum "step5-crash ($impl)" "ERROR|aitools config|script failed (exit 1)"
    want_out "step5-crash ($impl)" "Step 5: setup-user-config"

    # ... and a writer that wrote its own ERROR row gets no second one
    fresh; WRITER_MODE=ownrow run_h "$impl" step5
    want_end "step5-ownrow ($impl)" "errors=1 warnings=0"
    want_sum "step5-ownrow ($impl)" "ERROR|aitools config|stub failed"

    # A-16: deploy.jsonl cannot be written (a directory in its place): one warning,
    # the installer goes on (bash: set -euo pipefail), the writer still runs
    fresh; mkdir -p "$H/.aitools/logs/deploy.jsonl"
    WRITER_MODE=warn run_h "$impl" step5
    want_end "jsonl-blocked ($impl)" "errors=0 warnings=2"
    count_out "jsonl-blocked ($impl)" "deploy.jsonl: cannot write" 1
    want_out "jsonl-blocked ($impl)" "[aitools-install] [info] harness end"
    want_sum "jsonl-blocked ($impl)" "OK|aitools config|stub"

    # A-17: Step 3. A relative path is made absolute (and created)
    fresh; run_h "$impl" step3 repos
    got=$(perl -ne 'print "$1\n" if /^REPOS=(.*)$/' "$OUT")
    if [ "$got" = "$H/repos" ] || [ "$got" = "$(cd "$H" && pwd -P)/repos" ]; then ok "step3-relative ($impl): $got"
    else bad "step3-relative ($impl): '$got', want $H/repos"; perl -pe 's/^/       /' "$OUT"; fi
    want_sum "step3-relative ($impl)" ""
    # a path that cannot be created (under a file): one error, one row
    fresh; printf 'x\n' > "$H/afile"
    run_h "$impl" step3 "$H/afile/repos"
    want_out "step3-uncreatable ($impl)" "REPOS_FAILED"
    want_end "step3-uncreatable ($impl)" "errors=1 warnings=0"
    want_sum "step3-uncreatable ($impl)" "ERROR|aitools config|repos dir not created"
done

# A-17, bash: a relative path that exists but cannot be entered is not resolved.
# (PowerShell resolves it with GetFullPath, which does not enter the directory.)
# Root ignores the missing permission, so the case is skipped as root.
if [ "$(id -u)" -eq 0 ]; then
    printf '  skip step3-unresolvable (running as root)\n'
else
    fresh; mkdir -p "$H/locked"; chmod 000 "$H/locked"
    run_h bash step3 locked
    chmod 755 "$H/locked"
    want_out "step3-unresolvable (bash)" "REPOS_FAILED"
    want_end "step3-unresolvable (bash)" "errors=1 warnings=0"
    want_sum "step3-unresolvable (bash)" "ERROR|aitools config|repos path not absolute"
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
