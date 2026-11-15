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
#   step3-prompt-* (bash, on a pseudo-terminal) the Step 3 prompt
#                  (prompt_repos_path) is on the terminal and not on stdout
#   log-*          the log override's deploy.log write is fail-safe
#                  (reference/logging.md section 5; incident #174): with deploy.log
#                  a directory, (bash) a file with mode 000, or (PowerShell) held
#                  open with no sharing, under $ErrorActionPreference = "Stop" and
#                  inside a try, the run goes on, the console lines print and the
#                  counters count; a writable deploy.log still gets the lines
#   relaysync-*    Step 22's run_relay_sync / Invoke-RelaySync: the sync runs and
#                  its exit code is returned whether or not deploy.log can be
#                  written; its output (stdout and stderr) reaches a writable one
#
# Platform targeting (plans/ci-platform-targeting.md): each half runs only where
# its installer runs. macOS/Linux run the bash blocks (aitools-install.sh with
# aitools-lib.sh); Windows (Git Bash) runs the PowerShell blocks
# (aitools-install.ps1 with aitools-lib.ps1) with native pwsh, paths in Windows
# form (cygpath -m), HOME and USERPROFILE both set. There is no sh-vs-ps1 parity
# comparison here: every check is an explicit expectation, the same text for
# both languages, so the suite has no golden files.
# Safe to re-run: an isolated HOME under a temp dir (removed on exit).
# Usage: bash tests/profile/test-install.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: macOS/Linux always run only bash
#   AITOOLS_TEST_BASH=/bin/bash runs the bash harness under another bash (macOS 3.2)

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 44' "$0"
    exit 0
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$REPO/tests/lib/platform-lib.sh"
WORK="$(mktemp -d)"
cleanup() {
    # a case leaves a directory without permissions: restore before removing
    if [ -d "$WORK/home/locked" ]; then chmod 755 "$WORK/home/locked"; fi
    rm -rf "$WORK"
}
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
LANG_RUN="$TEST_LANG"   # sh on macOS/Linux, ps1 on Windows

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

if [ "$LANG_RUN" = ps1 ] && ! command -v pwsh >/dev/null 2>&1; then
    printf '  FAIL pwsh is not on PATH: the .ps1 installer blocks cannot be tested on Windows\n'
    exit 1
fi

# np P -- P in Windows form ("" stays ""). A path under $WORK gets the native
# $WORK prefix by string replacement: cygpath refuses a path whose parent is a
# file ("Not a directory"), which step3-uncreatable passes on purpose (CI run
# 41265193554)
NWORK="$(native_path "$WORK")"
np() {
    if [ -z "$1" ]; then return 0; fi
    case "$1" in
        "$WORK"/*) printf '%s%s' "$NWORK" "${1#"$WORK"}" ;;
        *) native_path "$1" ;;
    esac
}

# WORK_SPELLINGS -- Windows: every spelling of $WORK a native program may print,
# one per line: cygpath's default form, its long form and its 8.3 short form.
# The CI temp root is both C:/Users/RUNNER~1/... and C:/Users/runneradmin/...;
# pwsh prints whichever its API returns (CI run 41265193554). Empty elsewhere.
WORK_SPELLINGS=""
if [ "$TEST_PLATFORM" = windows ]; then
    for ws_opt in "" -l -s; do
        # shellcheck disable=SC2086  # ws_opt is empty or one option
        if ws="$(cygpath -m $ws_opt "$WORK")" && [ -n "$ws" ]; then WORK_SPELLINGS="$WORK_SPELLINGS$ws"$'\n'
        else printf '  note: cygpath -m %s gave no spelling of %s (that spelling is not mapped back)\n' "$ws_opt" "$WORK"; fi
    done
fi

# from_native FILE -- Windows: rewrite, in place, every spelling of $WORK that
# native pwsh prints (each of WORK_SPELLINGS as C:/..., C:\..., JSON-escaped
# C:\\... and /c/...) back to $WORK, with the separators after it turned into
# slashes, and remove CRs. A no-op elsewhere.
from_native() {
    [ "$TEST_PLATFORM" = windows ] || return 0
    FN_POSIX="$WORK" FN_NATIVES="$WORK_SPELLINGS" perl -pi -e '
        BEGIN {
            my %seen;
            for my $n (grep { length } split /\n/, $ENV{FN_NATIVES}) {
                (my $bs = $n) =~ s{/}{\\}g; (my $js = $bs) =~ s{\\}{\\\\}g;
                my $us = $n; $us =~ s{^([A-Za-z]):}{"/" . lc($1)}e;
                $seen{$_} = 1 for grep { length } ($js, $bs, $n, $us);
            }
            @fn_re = map { qr/\Q$_\E/i } sort { length($b) <=> length($a) } keys %seen;
        }
        s/\r//g;
        for my $re (@fn_re) { s{$re([^\s"\x27|()]*)}{my $r = $1; $r =~ s{\\\\}{/}g; $r =~ tr{\\}{/}; "$ENV{FN_POSIX}$r"}ge; }
    ' "$1"
}

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

# Stub relay syncs (Step 22): one stdout and one stderr line, a marker file (it
# ran), exit SYNC_RC (default 0)
cat > "$WORK/sync.sh" <<'SYNC'
printf 'sync-out-line\n'
printf 'sync-err-line\n' >&2
: > "$SYNC_MARK"
exit "${SYNC_RC:-0}"
SYNC
cat > "$WORK/sync.ps1" <<'SYNC'
Write-Output "sync-out-line"
[Console]::Error.WriteLine("sync-err-line")
[IO.File]::WriteAllText($env:SYNC_MARK, "ran")
$c = 0
if ($env:SYNC_RC) { $c = [int]$env:SYNC_RC }
exit $c
SYNC

# Harnesses: the two installer blocks, then MODE (step5 / step3 PATH / logprobe /
# relaysync), then a last log line and the counters (reaching "END" = the
# installer went on)
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
    step3prompt) prompt_repos_path; printf 'REPOS=%s\n' "$REPOS_PATH" ;;
    logprobe) log_warn "probe-warn"; log_error "probe-error"; printf 'PROBE-DONE\n' ;;
    relaysync) sync_rc=0; run_relay_sync "$BASH" "$SYNC" || sync_rc=$?; printf 'SYNC-RC=%s\n' "$sync_rc" ;;
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
    "logprobe" {
        # LOCK_LOG=1: this process holds deploy.log open with no sharing while the
        # probe logs (Windows enforces the share mode per handle, so the installer's
        # write fails as it would against another process's lock)
        $hold = $null
        if ($env:LOCK_LOG -eq "1") { $hold = [IO.File]::Open($logFile, 'OpenOrCreate', 'ReadWrite', 'None') }
        $ErrorActionPreference = "Stop"
        try { LogWarn "probe-warn"; LogError "probe-error"; Write-Output "PROBE-DONE" }
        catch { Write-Output "CAUGHT: $($_.Exception.Message)" }
        finally { $ErrorActionPreference = "Continue"; if ($hold) { $hold.Dispose() } }
    }
    "relaysync" {
        $rc = Invoke-RelaySync "pwsh" @("-NoProfile", "-NonInteractive", "-File", $env:SYNC)
        Write-Output "SYNC-RC=$rc"
    }
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
            SYNC="$WORK/sync.sh" SYNC_MARK="$H/sync.mark" SYNC_RC="${SYNC_RC:-0}" LOCK_LOG="${LOCK_LOG:-0}" \
            "$BASH_BIN" "$WORK/harness.sh" "$REPO" "$mode" ${path:+"$path"}) > "$WORK/out.txt" 2>&1 || RC=$?
    else
        # Native pwsh (Windows): Windows paths; MSYS argument conversion off, so
        # Git Bash passes every argument as written
        (cd "$H" && env HOME="$(native_path "$H")" USERPROFILE="$(native_path "$H")" \
            AITOOLS_LOG_DIR="$(native_path "$H/.aitools/logs")" AITOOLS_SUMMARY_FILE="$(native_path "$H/summary.txt")" \
            WRITER="$(native_path "$WORK/writer.ps1")" WRITER_MODE="${WRITER_MODE:-quiet}" \
            SYNC="$(native_path "$WORK/sync.ps1")" SYNC_MARK="$(native_path "$H/sync.mark")" SYNC_RC="${SYNC_RC:-0}" LOCK_LOG="${LOCK_LOG:-0}" \
            MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
            pwsh -NoProfile -NonInteractive -File "$(native_path "$WORK/harness.ps1")" -Repo "$(native_path "$REPO")" \
            -Mode "$mode" -ReposPath "$(np "$path")") > "$WORK/out.txt" 2>&1 || RC=$?
        from_native "$WORK/out.txt"
        from_native "$H/summary.txt"
    fi
    perl -pi -e 's/\e\[[0-9;]*m//g; s/\r//g' "$WORK/out.txt"
    OUT="$WORK/out.txt"
    SUM=$(perl -pe 's/\r//g' "$H/summary.txt")
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
want_no_out() {  # want_no_out NAME PERL-REGEX -- no console line matches
    if perl -ne 'BEGIN { $r = shift @ARGV } $f = 1 if /$r/; END { exit($f ? 0 : 1) }' "$2" "$OUT"; then
        bad "$1: console matches /$2/"; perl -pe 's/^/       /' "$OUT"
    else ok "$1: console has no /$2/"; fi
}
log_has() {  # log_has NAME TEXT -- deploy.log (a file) contains TEXT
    if [ -f "$H/.aitools/logs/deploy.log" ] && grep -qF -- "$2" "$H/.aitools/logs/deploy.log"; then ok "$1: deploy.log has '$2'"
    else bad "$1: deploy.log lacks '$2'"; fi
}
# Fail-safe log probe (incident #174): the run went on, both console lines printed,
# both counters counted, no catch and no write error on the console
want_probe() {  # want_probe NAME
    want_end "$1" "errors=1 warnings=1"
    want_out "$1" "PROBE-DONE"
    want_out "$1" "[aitools-install] [warn] probe-warn"
    want_out "$1" "[aitools-install] [error] probe-error"
    want_no_out "$1" 'CAUGHT|Exception|Add-Content|tee:|Is a directory|Permission denied|cannot access|being used by another process'
}
# The sync ran (marker), returned WANT_RC, and the installer went on
want_sync() {  # want_sync NAME WANT_RC
    want_end "$1" "errors=0 warnings=0"
    want_out "$1" "SYNC-RC=$2"
    if [ -f "$H/sync.mark" ]; then ok "$1: the sync ran"; else bad "$1: the sync did not run"; fi
    want_no_out "$1" 'Exception|Add-Content|Is a directory|Permission denied|cannot access'
}

IMPLS="bash"
if [ "$LANG_RUN" = ps1 ]; then IMPLS="ps"; fi
printf 'installer Step 3 / Step 5 on the lib relay (%s: %s)\n' "$TEST_PLATFORM" "$IMPLS"
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
    elif [ "$TEST_PLATFORM" = windows ] && [ -d "$H/repos" ] && printf '%s' "$got" | grep -Eq '^[A-Za-z]:[\\/].*[\\/]home[\\/]repos$'; then
        # pwsh printed the temp root in another spelling (8.3 short name or long name) than cygpath
        ok "step3-relative ($impl): $got (absolute, created)"
    else bad "step3-relative ($impl): '$got', want $H/repos"; perl -pe 's/^/       /' "$OUT"; fi
    want_sum "step3-relative ($impl)" ""
    # a path that cannot be created (under a file): one error, one row
    fresh; printf 'x\n' > "$H/afile"
    run_h "$impl" step3 "$H/afile/repos"
    want_out "step3-uncreatable ($impl)" "REPOS_FAILED"
    want_end "step3-uncreatable ($impl)" "errors=1 warnings=0"
    want_sum "step3-uncreatable ($impl)" "ERROR|aitools config|repos dir not created"

    # Incident #174: the log override's deploy.log write is fail-safe. A writable
    # deploy.log still gets the lines ...
    fresh; run_h "$impl" logprobe
    want_probe "log-written ($impl)"
    log_has "log-written ($impl)" "[aitools-install] [warn] probe-warn"
    log_has "log-written ($impl)" "[aitools-install] [error] probe-error"
    # ... and one that cannot be written (a directory in its place) ends nothing
    fresh; mkdir -p "$H/.aitools/logs/deploy.log"
    run_h "$impl" logprobe
    want_probe "log-blocked ($impl)"

    # Step 22 relay sync: its output (stdout and stderr) reaches deploy.log ...
    fresh; run_h "$impl" relaysync
    want_sync "relaysync-ok ($impl)" 0
    log_has "relaysync-ok ($impl)" "sync-out-line"
    log_has "relaysync-ok ($impl)" "sync-err-line"
    # ... its exit code comes back ...
    fresh; SYNC_RC=3 run_h "$impl" relaysync
    want_sync "relaysync-rc ($impl)" 3
    # ... and a deploy.log that cannot be written neither skips it nor ends the run
    fresh; mkdir -p "$H/.aitools/logs/deploy.log"
    run_h "$impl" relaysync
    want_sync "relaysync-blocked ($impl)" 0
done

# Incident #174, bash: deploy.log without write permission (mode 000). Root ignores
# the mode (the write then succeeds), so the case is skipped as root. bash only:
# macOS/Linux.
if [ "$LANG_RUN" != sh ]; then
    printf '  skip log-unwritable (bash installer only: macOS/Linux)\n'
elif [ "$(id -u)" -eq 0 ]; then
    printf '  skip log-unwritable (running as root: mode 000 does not block the write)\n'
else
    fresh; : > "$H/.aitools/logs/deploy.log"; chmod 000 "$H/.aitools/logs/deploy.log"
    run_h bash logprobe
    chmod 644 "$H/.aitools/logs/deploy.log"
    want_probe "log-unwritable (bash)"
fi

# Incident #174, PowerShell: deploy.log held open with no sharing (a lock) while
# the probe logs under $ErrorActionPreference = "Stop" inside a try. Windows only:
# this suite runs the PowerShell installer blocks on Windows.
if [ "$LANG_RUN" != ps1 ]; then
    printf '  skip log-locked (PowerShell installer only: Windows)\n'
else
    fresh; LOCK_LOG=1 run_h ps logprobe
    want_probe "log-locked (ps)"
    if grep -qF -- "probe-warn" "$H/.aitools/logs/deploy.log"; then bad "log-locked (ps): the lock did not hold (probe line in deploy.log)"
    else ok "log-locked (ps): nothing written while the lock held"; fi
fi

# A-17, bash: a relative path that exists but cannot be entered is not resolved.
# (PowerShell resolves it with GetFullPath, which does not enter the directory.)
# Root ignores the missing permission, so the case is skipped as root. bash only:
# macOS/Linux.
if [ "$LANG_RUN" != sh ]; then
    printf '  skip step3-unresolvable (bash installer only: macOS/Linux)\n'
elif [ "$(id -u)" -eq 0 ]; then
    printf '  skip step3-unresolvable (running as root)\n'
else
    fresh; mkdir -p "$H/locked"; chmod 000 "$H/locked"
    run_h bash step3 locked
    chmod 755 "$H/locked"
    want_out "step3-unresolvable (bash)" "REPOS_FAILED"
    want_end "step3-unresolvable (bash)" "errors=1 warnings=0"
    want_sum "step3-unresolvable (bash)" "ERROR|aitools config|repos path not absolute"
fi

# M5-Fixes item 10: the Step 3 prompt (prompt_repos_path) goes to the terminal
# (/dev/tty), never stdout, and the answer is read from the terminal. The harness
# runs on a pseudo-terminal (tests/managed-files/pty-run.py) with its stdout and
# stderr sent to a file: the prompt must be on the terminal and not in the file.
# bash only (macOS/Linux); needs python3 (stdlib pty).
# run_step3_tty INPUT -- RC, $WORK/stdout.txt (the harness's stdout + stderr),
# $WORK/tty.txt (what reached the terminal)
run_step3_tty() {
    RC=0
    : > "$H/summary.txt"
    printf '%s\n' "cd '$H' || exit 9" \
        "exec env HOME='$H' AITOOLS_LOG_DIR='$H/.aitools/logs' AITOOLS_SUMMARY_FILE='$H/summary.txt' '$BASH_BIN' '$WORK/harness.sh' '$REPO' step3prompt > '$WORK/stdout.txt' 2>&1" \
        > "$WORK/step3-tty.sh"
    python3 "$REPO/tests/managed-files/pty-run.py" --input "$1" --log "$WORK/tty.txt" --timeout 30 -- "$BASH_BIN" "$WORK/step3-tty.sh" || RC=$?
    OUT="$WORK/stdout.txt"
}
step3_prompt_case() {  # step3_prompt_case NAME INPUT WANT_REPOS
    local name="step3-prompt-$1 (bash)" got
    fresh; run_step3_tty "$2"
    got=$(perl -ne 'print "$1\n" if /^REPOS=(.*)$/' "$OUT")
    if [ "$RC" -eq 0 ] && [ "$got" = "$3" ]; then ok "$name: REPOS=$got"
    else bad "$name: rc=$RC REPOS='$got', want '$3'"; perl -pe 's/^/       /' "$OUT"; fi
    if grep -qF -- "Where should new repos live? [~/repos]: " "$WORK/tty.txt"; then ok "$name: the prompt reached the terminal"
    else bad "$name: the prompt is not on the terminal"; perl -pe 's/^/       /' "$WORK/tty.txt"; fi
    if grep -qF -- "Where should new repos live?" "$OUT"; then bad "$name: the prompt went to stdout/stderr"; perl -pe 's/^/       /' "$OUT"
    else ok "$name: no prompt on stdout/stderr"; fi
}
if [ "$LANG_RUN" != sh ]; then
    printf '  skip step3-prompt (bash installer only: macOS/Linux)\n'
elif ! command -v python3 >/dev/null 2>&1; then
    printf '  skip step3-prompt (python3 not on PATH: no pseudo-terminal)\n'
else
    step3_prompt_case answer 'myrepos\n' "myrepos"
    step3_prompt_case tilde '~/code\n' "$H/code"
    step3_prompt_case empty '\n' "$H/repos"
    step3_prompt_case eof '\x04' "$H/repos"
    if grep -qF -- "[warn] No input at prompt (EOF) -- defaulting to ~/repos" "$H/.aitools/logs/deploy.log"; then ok "step3-prompt-eof (bash): EOF warning logged"
    else bad "step3-prompt-eof (bash): no EOF warning in deploy.log"; fi
fi

printf '\n%s passed, %s failed (%s: %s)\n' "$PASS" "$FAIL" "$TEST_PLATFORM" "$IMPLS"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
