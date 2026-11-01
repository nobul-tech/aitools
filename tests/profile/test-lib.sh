#!/usr/bin/env bash
# test-lib.sh -- tests for the aitools-lib profile wrappers (bash and PowerShell):
# resolve_user_repo_path / Resolve-UserRepoPath, resolve_machine_profile /
# Resolve-MachineProfile, tool_exception_get / Get-ToolException,
# tool_exception_record / Set-ToolException.
#
# Each case sources the lib in a fresh shell with an isolated HOME, calls one
# wrapper, and prints its return code, AITLIB_* / $script:AitLib* results,
# WARNINGS/ERRORS counters and the summary rows; the bash and PowerShell results
# must match the expectation. Also covered: a caller's own variables and
# parameters survive sourcing the lib and calling the wrappers (PR #80 B1/M1),
# unchanged and dry-run records do not warn (m1), one ACTION per run (m3), the
# AITOOLS_PROFILE_SH/PS1 overrides, and the bash -> pwsh branch of aitools-lib.sh
# that Git Bash takes on Windows (m2; AITLIB_PROFILE_VIA_PWSH=1 is set too, a
# no-op there).
# Re-key batch 3: the id-key results (AITLIB_MACHINE_KEY/OWNER/LEGACY/HOSTNAME)
# on id-keyed, legacy, other-machine and no-match profiles and with a resolver
# that predates them; resolver exits 3 and 4 mapped and logged in every wrapper;
# one dotprofile ACTION per run; the child-log relay helpers (jsonl_record /
# Write-JsonlRecord, relay_child_log / Send-ChildLog, run_child_relayed /
# Invoke-ChildRelayed): valid JSONL with escaping, identical records in both
# shells, warning/error counts, footers not counted, child exit codes.
# M3-FINISH item 3: the runner itself (_aitlib_profile_run / Invoke-AitLibProfile)
# accepts "result" lines (register, migrate) and a bare hostname value, passes
# exits 1-4 through, names a missing resolver (exit 2 + error line), turns a
# throw into an error line, and converts --path/--profile/--out/--config values
# on the Git Bash branch (a cygpath stub).
# M3-FINISH item 7 (FIX-1): the machine-profile "resolver missing" ACTION (A-2,
# one per run with the dotprofile wrapper's); the relay's ERROR row for a failed
# child that wrote none -- crash, exit 127, abort, error lines with exit 0, PS
# throw and parse error, no command -- and none for a child that wrote its own or
# without a summary tool (A-3); the relay's temp file: mktemp failure and a
# failed removal (A-4, stubs on PATH).
#
# Platform targeting (plans/ci-platform-targeting.md): each case runs only where
# the code it tests runs. macOS/Linux run the bash cases (aitools-lib.sh with
# aitools-profile.sh); Windows (Git Bash) runs the PowerShell cases
# (aitools-lib.ps1 with aitools-profile.ps1, native pwsh, Windows paths, HOME and
# USERPROFILE both set) and the "gitbash" cases: aitools-lib.sh under Git Bash,
# whose profile wrappers call aitools-profile.ps1 through pwsh (m2). No guard is
# bypassed. The one sh-vs-ps1 parity comparison (relay-record: identical
# deploy.jsonl records) is checked against the committed golden file
# tests/profile/golden/lib-relay-record.jsonl (tests/lib/platform-lib.sh
# golden_match; host and os replaced by <HOST> and <OS>);
# AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux rewrites it.
# Safe to re-run: an isolated HOME under a temp dir (removed on exit).
# Usage: bash tests/profile/test-lib.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: macOS/Linux always run only bash
#   AITOOLS_TEST_BASH=/bin/bash runs the bash drivers under another bash (macOS 3.2)

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 49' "$0"
    exit 0
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$REPO/tests/lib/platform-lib.sh"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
LANG_RUN="$TEST_LANG"   # sh on macOS/Linux, ps1 on Windows
GOLDEN_DIR="$REPO/tests/profile/golden"
GOLDEN_TMP="$WORK"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

if [ "$LANG_RUN" = ps1 ] && ! command -v pwsh >/dev/null 2>&1; then
    printf '  FAIL pwsh is not on PATH: the PowerShell cases cannot be tested on Windows\n'
    exit 1
fi

# impl_runs IMPL -- 0 when IMPL runs on this platform: bash on macOS/Linux; ps
# and gitbash (aitools-lib.sh under Git Bash, its pwsh branch) on Windows
impl_runs() {
    case "$1" in
        bash) [ "$LANG_RUN" = sh ] ;;
        ps|gitbash) [ "$LANG_RUN" = ps1 ] ;;
        *) return 1 ;;
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
# to_native WORDS -- WORDS with every $WORK and $REPO prefix in native form (the
# VAR=value words and comma lists handed to native pwsh); unchanged off Windows
to_native() {
    if [ "$TEST_PLATFORM" != windows ]; then printf '%s' "$1"; return 0; fi
    TN_W="$WORK" TN_WN="$(native_path "$WORK")" TN_R="$REPO" TN_RN="$(native_path "$REPO")" \
        perl -e 'my $s = $ARGV[0]; $s =~ s/\Q$ENV{TN_W}\E/$ENV{TN_WN}/g; $s =~ s/\Q$ENV{TN_R}\E/$ENV{TN_RN}/g; print $s' "$1"
}

ID_MAC="3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
ID_KEY="3d4df2a5-7d91-5af9-9944-4feebaae3cf5"   # ID_MAC lower-cased: the profiles key (revision 2.2)
H="$WORK/home"
DP="$H/repos/aitools-nobul-jose"
A_DP="ACTION||see deploy.log -- the dotprofile could not be resolved"

FIX_KIND=""
FIX_NAME="Jose"
fixture() {  # fixture with-id|with-exc|hostname-only|id-key|other-id|none  (identity name: $FIX_NAME)
    # with-id / with-exc / hostname-only: legacy (revision 2.1) entry keyed by alias;
    # id-key: this machine's entry keyed by its id (2.2); other-id: another machine's
    # id-keyed entry that has this machine's hostname
    FIX_KIND="$1"
    rm -rf "$H"; mkdir -p "$H/repos" "$H/.aitools"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
    [ "$1" = "none" ] && return 0
    mkdir -p "$DP"
    local idline="" excline="" entry
    if [ "$1" = "with-id" ] || [ "$1" = "with-exc" ]; then idline="\"id\": \"$ID_MAC\","; fi
    if [ "$1" = "with-exc" ]; then
        excline=', "toolExceptions": { "go": { "decision": "keep", "detected": { "platform": "macos", "method": "pkg-installer", "path": "/usr/local/bin/go", "version": "1.22.5" }, "decidedAt": "2026-10-01T00:00:00Z", "decidedBy": "setup-go", "reason": null } }'
    fi
    entry="\"nobul-mac\": { \"machine\": { $idline \"hostname\": \"nobul-mac\" }$excline }"
    if [ "$1" = "id-key" ]; then
        entry="\"$ID_KEY\": { \"alias\": \"nobul-mac\", \"company\": \"nobul-mac-co\", \"machine\": { \"id\": \"$ID_KEY\", \"hostname\": \"nobul-mac\" } }"
    elif [ "$1" = "other-id" ]; then
        entry="\"aaaaaaaa-1111-2222-3333-444444444444\": { \"alias\": \"old-mac\", \"machine\": { \"id\": \"aaaaaaaa-1111-2222-3333-444444444444\", \"hostname\": \"nobul-mac\" } }"
    fi
    cat > "$DP/profile.json" <<JSON
{
  "version": 2,
  "identity": { "github": "nobul-jose", "name": "$FIX_NAME", "company": "nobul-tech", "git": { "name": "Jose", "email": "jose@nobul.tech" } },
  "profiles": {
    $entry
  }
}
JSON
    git -C "$DP" init -q
    git -C "$DP" config user.name Test
    git -C "$DP" config user.email test@example.com
    git -C "$DP" add profile.json
    git -C "$DP" commit -q -m init
}

# Resolver stubs for the AITOOLS_PROFILE_SH / AITOOLS_PROFILE_PS1 override cases
printf '#!/usr/bin/env bash\nprintf "path\\t/stub/aitools-dp\\nvia\\tenv\\n"\nexit 0\n' > "$WORK/stub.sh"
printf '"path`t/stub/aitools-dp"\n"via`tenv"\nexit 0\n' > "$WORK/stub.ps1"
# Broken resolvers (PR #80 review 2, M1): silent exit 0 / exit 1, a throw, a parse error
printf 'exit 0\n' > "$WORK/silent0.sh"; printf 'exit 0\n' > "$WORK/silent0.ps1"
printf 'exit 1\n' > "$WORK/silent1.sh"; printf 'exit 1\n' > "$WORK/silent1.ps1"
printf 'throw "boom"\n' > "$WORK/throw.ps1"
printf 'if (\n' > "$WORK/parse.ps1"
# Re-key batch 3: resolvers that exit 3 (refused) and 4 (alias in use), and a
# resolver that predates the id-key fields (no key/owner/legacy lines)
for n in 3 4; do
    printf '#!/usr/bin/env bash\nprintf "via\\tnone\\nerror\\tstub says no\\n"\nexit %s\n' "$n" > "$WORK/exit$n.sh"
    printf '"via`tnone"\n"error`tstub says no"\nexit %s\n' "$n" > "$WORK/exit$n.ps1"
done
printf '#!/usr/bin/env bash\nprintf "alias\\tnobul-mac\\nvia\\tid\\nhostname\\tnobul-mac\\nname\\tJose\\ncompany\\tnobul-tech\\n"\nexit 0\n' > "$WORK/oldres.sh"
printf '"alias`tnobul-mac"\n"via`tid"\n"hostname`tnobul-mac"\n"name`tJose"\n"company`tnobul-tech"\nexit 0\n' > "$WORK/oldres.ps1"
# M3-FINISH item 3: commands that print a "result" line and no "via" line
# (register, migrate), a bare hostname value, a plain error exit, and a stub that
# echoes its arguments (the Git Bash path conversion)
printf '#!/usr/bin/env bash\nprintf "result\\tcreated\\nkey\\tk1\\n"\nexit 0\n' > "$WORK/res0.sh"
printf '"result`tcreated"\n"key`tk1"\nexit 0\n' > "$WORK/res0.ps1"
printf '#!/usr/bin/env bash\nprintf "result\\tfailed\\nerror\\tprofile.json not found\\n"\nexit 1\n' > "$WORK/res1.sh"
printf '"result`tfailed"\n"error`tprofile.json not found"\nexit 1\n' > "$WORK/res1.ps1"
printf '#!/usr/bin/env bash\nprintf "probe-host\\n"\nexit 0\n' > "$WORK/host.sh"
printf '"probe-host"\nexit 0\n' > "$WORK/host.ps1"
printf '#!/usr/bin/env bash\nprintf "error\\tbad input\\n"\nexit 2\n' > "$WORK/exit2.sh"
printf '"error`tbad input"\nexit 2\n' > "$WORK/exit2.ps1"
printf '"result`tok"\nforeach ($x in $args) { "arg`t$x" }\nexit 0\n' > "$WORK/args.ps1"
# A cygpath stub: -w marks paths under /conv/ (W/conv/...); every other call goes
# to the real cygpath (Windows: the resolver path itself must be converted), or
# prints the path as is where there is none
mkdir -p "$WORK/fakebin"
REAL_CYGPATH=""
if command -v cygpath >/dev/null 2>&1; then REAL_CYGPATH="$(command -v cygpath)"; fi
printf '#!/usr/bin/env bash\ncase "$2" in /conv/*) printf "W%%s\\n" "$2" ;; *) if [ -n "%s" ]; then exec "%s" "$@"; fi; printf "%%s\\n" "$2" ;; esac\n' \
    "$REAL_CYGPATH" "$REAL_CYGPATH" > "$WORK/fakebin/cygpath"
chmod +x "$WORK/fakebin/cygpath"

# Bash driver: source the lib, run one call, print the results
cat > "$WORK/drive.sh" <<'DRIVE'
set -euo pipefail
if [ "$CALL" = "keep" ]; then
    # A caller's own variables with the names the lib used before PR #80's fix
    USER_REPO_PATH=/caller/urp; PROFILE_FILE=/caller/pf; MACHINE_ALIAS=caller; PROFILE_NAME=caller-name
fi
source "$REPO/scripts/aitools-lib.sh"
logging_init "test-lib"
LOG_START=$(perl -ne 'END { print $. + 0 }' "$LOG_FILE")
rc=0
case "$CALL" in
    urp)  resolve_user_repo_path || rc=$? ;;
    urp2) resolve_user_repo_path || rc=$?; rc=0; resolve_user_repo_path || rc=$? ;;
    rmp|rmpk)  resolve_machine_profile || rc=$? ;;
    rmp2) resolve_machine_profile || rc=$?; rc=0; resolve_machine_profile || rc=$? ;;
    eget) tool_exception_get go || rc=$? ;;
    eset) tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$? ;;
    eset2)
        tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$?
        WARNINGS=0; : > "$AITOOLS_SUMMARY_FILE"; rc=0   # judge the second, identical call only
        tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$? ;;
    keep) resolve_user_repo_path || rc=$?; resolve_machine_profile || rc=$? ;;
    run)
        # The runner itself: RUN_ARGS is comma-separated; FAKEBIN goes first on PATH
        if [ -n "${FAKEBIN:-}" ]; then PATH="$FAKEBIN:$PATH"; fi
        IFS=, read -r -a run_args <<< "$RUN_ARGS"
        _aitlib_profile_run "${run_args[@]}" || rc=$?
        printf 'rc=%s profrc=%s\n' "$rc" "$AITLIB_PROFILE_RC"
        v=$(_aitlib_profile_tag result); if [ -z "$v" ]; then v=$(_aitlib_profile_tag via); fi
        if [ -z "$v" ]; then v=$(printf '%s\n' "$AITLIB_PROFILE_OUT" | perl -ne 'print, exit if /^[^\t]+$/'); fi
        printf 'out=%s\n' "$v"
        printf 'err=%s\n' "$(_aitlib_profile_lines error | perl -ne 'print, exit if /\S/')"
        a=$(_aitlib_profile_lines arg | perl -pe 's/\n/ /' | perl -pe 's/ $//')
        if [ -n "$a" ]; then printf 'args=%s\n' "$a"; fi
        printf 'warnings=%s errors=%s\n' "$WARNINGS" "$ERRORS"
        exit 0 ;;
esac
printf 'rc=%s\n' "$rc"
case "$CALL" in
    urp|urp2)  printf 'path=%s via=%s\n' "$AITLIB_USER_REPO_PATH" "$AITLIB_USER_REPO_VIA" ;;
    rmp|rmp2) printf 'alias=%s via=%s company=%s name=%s\n' "$AITLIB_MACHINE_ALIAS" "$AITLIB_MACHINE_VIA" "$AITLIB_PROFILE_COMPANY" "$AITLIB_PROFILE_NAME" ;;
    rmpk)
        printf 'alias=%s via=%s company=%s\n' "$AITLIB_MACHINE_ALIAS" "$AITLIB_MACHINE_VIA" "$AITLIB_PROFILE_COMPANY"
        printf 'key=%s owner=%s legacy=%s host=%s\n' "$AITLIB_MACHINE_KEY" "$AITLIB_MACHINE_OWNER" "$AITLIB_MACHINE_LEGACY" "$AITLIB_MACHINE_HOSTNAME" ;;
    eget) printf 'found=%s method=%s path=%s\n' "$AITLIB_TOOL_EXC_FOUND" "$AITLIB_TOOL_EXC_METHOD" "$AITLIB_TOOL_EXC_PATH" ;;
    eset|eset2) printf 'result=%s pushed=%s\n' "$AITLIB_TOOL_EXC_RESULT" "$AITLIB_TOOL_EXC_PUSHED" ;;
    keep)
        printf 'kept=urp:%s pf:%s alias:%s name:%s\n' "$USER_REPO_PATH" "$PROFILE_FILE" "$MACHINE_ALIAS" "$PROFILE_NAME"
        printf 'alias=%s urp-via=%s\n' "$AITLIB_MACHINE_ALIAS" "$AITLIB_USER_REPO_VIA" ;;
esac
printf 'warnings=%s errors=%s\n' "$WARNINGS" "$ERRORS"
# SHOW_NOTES=1: how many log lines name a resolver exit 3 or 4 (batch 3 mapping)
if [ "${SHOW_NOTES:-}" = "1" ]; then
    printf 'notes=%s\n' "$(perl -ne '$n++ if $. > '"$LOG_START"' && /resolver exit [34]: /; END { print $n + 0 }' "$LOG_FILE")"
fi
DRIVE
# PowerShell driver. The parameters reproduce PR #80 B1: setup-user-config.ps1
# declares [string]$UserRepoPath and dot-sources the lib; it must keep its value.
cat > "$WORK/drive.ps1" <<'DRIVE'
param([string]$UserRepoPath = "", [string]$MachineAlias = "", [string]$ProfileFile = "")
$profileName = "caller-name"
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-lib"
$logStart = @([IO.File]::ReadAllLines($logFile)).Count
$rc = 0
switch ($env:CALL) {
    "urp"  { $rc = Resolve-UserRepoPath }
    "urp2" { $null = Resolve-UserRepoPath; $rc = Resolve-UserRepoPath }
    { $_ -in "rmp", "rmpk" } { $rc = Resolve-MachineProfile }
    "rmp2" { $null = Resolve-MachineProfile; $rc = Resolve-MachineProfile }
    "eget" { $r = Get-ToolException "go"; $rc = if ($null -eq $r) { 1 } else { 0 } }
    "eset" { $rc = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5" }
    "eset2" {
        $null = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5"
        $script:warnings = 0; [IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
        $rc = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5"
    }
    "keep" { $null = Resolve-UserRepoPath; $rc = Resolve-MachineProfile }
    "run" {
        # The runner itself: RUN_ARGS is comma-separated
        $ran = Invoke-AitLibProfile @($env:RUN_ARGS -split ',')
        $rc = if ($ran) { 0 } else { 1 }
        "rc=$rc profrc=$($script:AitLibProfileRc)"
        $v = Get-AitLibProfileTag "result"; if (-not $v) { $v = Get-AitLibProfileTag "via" }
        if (-not $v) { $v = @($script:AitLibProfileOut | Where-Object { $_ -and -not $_.Contains("`t") }) | Select-Object -First 1 }
        "out=$v"
        "err=$(@(Get-AitLibProfileLines 'error' | Where-Object { $_ -match '\S' }) | Select-Object -First 1)"
        $a = @(Get-AitLibProfileLines "arg")
        if ($a.Count) { "args=$($a -join ' ')" }
        "warnings=$($script:warnings) errors=$($script:errors)"
        exit 0
    }
}
"rc=$rc"
switch ($env:CALL) {
    { $_ -in "urp", "urp2" } { "path=$($script:AitLibUserRepoPath) via=$($script:AitLibUserRepoVia)" }
    { $_ -in "rmp", "rmp2" } { "alias=$($script:AitLibMachineAlias) via=$($script:AitLibMachineVia) company=$($script:AitLibProfileCompany) name=$($script:AitLibProfileName)" }
    "rmpk" {
        "alias=$($script:AitLibMachineAlias) via=$($script:AitLibMachineVia) company=$($script:AitLibProfileCompany)"
        $lg = if ($script:AitLibMachineLegacy) { "true" } else { "false" }
        "key=$($script:AitLibMachineKey) owner=$($script:AitLibMachineOwner) legacy=$lg host=$($script:AitLibMachineHostname)"
    }
    "eget" { $f = if ($r -and $r.Found) { "true" } else { "false" }; $m = if ($r) { $r.Method } else { "" }; $p = if ($r) { $r.Path } else { "" }; "found=$f method=$m path=$p" }
    { $_ -in "eset", "eset2" } { $pu = if ($script:AitLibToolExcPushed) { "true" } else { "false" }; "result=$($script:AitLibToolExcResult) pushed=$pu" }
    "keep" {
        "kept=urp:$UserRepoPath pf:$ProfileFile alias:$MachineAlias name:$profileName"
        "alias=$($script:AitLibMachineAlias) urp-via=$($script:AitLibUserRepoVia)"
    }
}
"warnings=$($script:warnings) errors=$($script:errors)"
if ($env:SHOW_NOTES -eq "1") {
    "notes=$(@([IO.File]::ReadAllLines($logFile) | Select-Object -Skip $logStart | Where-Object { $_ -cmatch 'resolver exit [34]: ' }).Count)"
}
DRIVE

# run_case NAME CALL EXPECTED-OUTPUT EXPECTED-SUMMARY [EXTRA-ENV] [IMPLS]
# EXTRA-ENV: space-separated VAR=value words (no spaces in values); IMPLS: "bash ps"
# (default), "bash", "ps" or "gitbash"; each runs only where impl_runs says
run_case() {
    local name="$1" call="$2" want="$3" wsum="$4" extra="${5:-}" impls="${6:-bash ps}" impl got
    for impl in $impls; do
        if ! impl_runs "$impl"; then continue; fi
        : > "$H/summary.txt"
        if [ "$impl" = "bash" ]; then
            # shellcheck disable=SC2086  # $extra is word-split on purpose
            got=$(env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" REPO="$REPO" CALL="$call" \
                AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac $extra \
                "$BASH_BIN" "$WORK/drive.sh" 2>/dev/null) || got="driver failed: $?"  # stderr: console log lines
            got=$(printf '%s\n' "$got" | grep -E '^(rc|path|alias|found|result|kept|warnings|key|notes|out|err|args)=' || true)  # only the driver's result lines (log lines also reach stdout)
        elif [ "$impl" = "gitbash" ]; then
            # aitools-lib.sh under Git Bash (Windows): its wrappers run aitools-profile.ps1
            # through native pwsh, whose $HOME follows USERPROFILE
            # shellcheck disable=SC2086  # $extra is word-split on purpose
            got=$(env HOME="$H" USERPROFILE="$(native_path "$H")" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
                REPO="$REPO" CALL="$call" AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac $extra \
                "$BASH_BIN" "$WORK/drive.sh" 2>/dev/null) || got="driver failed: $?"  # stderr: console log lines
            # cygpath -u may spell the temp root /c/... instead of /tmp/...: from_native maps it back
            printf '%s\n' "$got" > "$WORK/got.txt"
            from_native "$WORK/got.txt"
            got=$(grep -E '^(rc|path|alias|found|result|kept|warnings|key|notes|out|err|args)=' "$WORK/got.txt" || true)  # only the driver's result lines
        else
            # Native pwsh (Windows): Windows paths, MSYS argument conversion off
            # (-UserRepoPath /caller/urp must arrive as written)
            # shellcheck disable=SC2086,SC2046  # $extra / to_native are word-split on purpose
            got=$(env HOME="$(native_path "$H")" USERPROFILE="$(native_path "$H")" AITOOLS_LOG_DIR="$(native_path "$H/.aitools/logs")" \
                AITOOLS_SUMMARY_FILE="$(native_path "$H/summary.txt")" REPO="$(native_path "$REPO")" CALL="$call" \
                AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac $(to_native "$extra") \
                MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
                pwsh -NoProfile -NonInteractive -File "$(native_path "$WORK/drive.ps1")" -UserRepoPath /caller/urp -MachineAlias caller -ProfileFile /caller/pf \
                2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g') || got="driver failed: $?"  # Write-Host console lines dropped by the grep below
            printf '%s\n' "$got" > "$WORK/got.txt"
            from_native "$WORK/got.txt"
            got=$(grep -E '^(rc|path|alias|found|result|kept|warnings|key|notes|out|err|args)=' "$WORK/got.txt" || true)  # only the driver's result lines
        fi
        if [ "$impl" != "bash" ]; then from_native "$H/summary.txt"; fi
        if [ "$got" = "$want" ]; then ok "$name ($impl): result"
        else bad "$name ($impl): got"; printf '%s\n' "$got" | sed 's/^/         /'; printf '       want\n'; printf '%s\n' "$want" | sed 's/^/         /'; fi
        local sum; sum=$(cat "$H/summary.txt")
        if [ "$sum" = "$wsum" ]; then ok "$name ($impl): summary rows"
        else bad "$name ($impl): summary '$sum', want '$wsum'"; fi
        case "$call" in eset*) fixture "$FIX_KIND" ;; esac   # state changed: rebuild for the next implementation
    done
}

printf 'aitools-lib profile wrapper tests (%s: %s)\n' "$TEST_PLATFORM" "$LANG_RUN"

fixture with-id
run_case urp-found urp "rc=0
path=$DP via=convention
warnings=0 errors=0" ""

fixture none
run_case urp-none urp "rc=1
path= via=none
warnings=0 errors=0" ""

fixture with-id
run_case rmp-id rmp "rc=0
alias=nobul-mac via=id company=nobul-tech name=Jose
warnings=0 errors=0" ""

# hostname-only: resolver warnings are detail lines (no WARN promotion)
fixture hostname-only
run_case rmp-hostname rmp "rc=0
alias=nobul-mac via=hostname company=nobul-tech name=Jose
warnings=0 errors=0" ""

fixture none
run_case rmp-none rmp "rc=1
alias= via=none company= name=
warnings=0 errors=0" ""

fixture with-id
perl -pi -e "s/$ID_MAC/OTHER-ID/; s/\"hostname\": \"nobul-mac\"/\"hostname\": \"elsewhere\"/" "$DP/profile.json"
run_case rmp-nomatch rmp "rc=3
alias= via=none company=nobul-tech name=Jose
warnings=0 errors=2" "ERROR|machine profile|no machine match
ACTION||Run: aitools user init (pick or register this machine's profile)"

# m3: the same failure twice in one run -> two ERROR rows, one ACTION
run_case rmp-nomatch-twice rmp2 "rc=3
alias= via=none company=nobul-tech name=Jose
warnings=0 errors=4" "ERROR|machine profile|no machine match
ACTION||Run: aitools user init (pick or register this machine's profile)
ERROR|machine profile|no machine match"

fixture with-id
run_case eget-none eget "rc=0
found=false method= path=
warnings=0 errors=0" ""

fixture none
run_case eget-unavailable eget "rc=1
found=false method= path=
warnings=1 errors=0" ""

# No remote: the push fails -> warning + ACTION
fixture with-id
run_case eset-written eset "rc=0
result=created pushed=false
warnings=1 errors=0" "ACTION||run git push in $DP"

# m1: an identical second record and a dry run write nothing: no warning, no ACTION
fixture with-id
run_case eset-unchanged eset2 "rc=0
result=unchanged pushed=false
warnings=0 errors=0" ""

fixture with-id
run_case eset-dry-run eset "rc=0
result=dry-run pushed=false
warnings=0 errors=0" "" "AITOOLS_DRY_RUN=1"

fixture hostname-only
run_case eset-refused eset "rc=3
result=refused pushed=false
warnings=1 errors=0" "ACTION||run aitools user init to remember tool choices"

# B1/M1: the caller's own variables and parameters survive sourcing the lib and
# calling the wrappers (bash: USER_REPO_PATH, PROFILE_FILE, MACHINE_ALIAS,
# PROFILE_NAME; PowerShell: -UserRepoPath, -MachineAlias, -ProfileFile, $profileName)
fixture with-id
run_case caller-vars-survive keep "rc=0
kept=urp:/caller/urp pf:/caller/pf alias:caller name:caller-name
alias=nobul-mac urp-via=convention
warnings=0 errors=0" ""

# AITOOLS_PROFILE_SH / AITOOLS_PROFILE_PS1 overrides: a missing resolver, then a stub
fixture with-id
run_case override-missing urp "rc=3
path= via=none
warnings=0 errors=1" "ERROR|dotprofile|resolver missing
$A_DP" "AITOOLS_PROFILE_SH=$WORK/none.sh AITOOLS_PROFILE_PS1=$WORK/none.ps1"

run_case override-stub urp "rc=0
path=/stub/aitools-dp via=env
warnings=0 errors=0" "" "AITOOLS_PROFILE_SH=$WORK/stub.sh AITOOLS_PROFILE_PS1=$WORK/stub.ps1"

fixture with-exc
run_case eget-found eget "rc=0
found=true method=pkg-installer path=/usr/local/bin/go
warnings=0 errors=0" ""

# Review 2 M1: a resolver exit 0 or 1 without result lines is an error, not
# "found" or "shared-only"; a throw or parse error is an error too
fixture with-id
run_case broken-silent0-urp urp "rc=3
path= via=
warnings=0 errors=1" "ERROR|dotprofile|resolver failed
$A_DP" "AITOOLS_PROFILE_SH=$WORK/silent0.sh AITOOLS_PROFILE_PS1=$WORK/silent0.ps1"

run_case broken-silent1-urp urp "rc=3
path= via=
warnings=0 errors=1" "ERROR|dotprofile|resolver failed
$A_DP" "AITOOLS_PROFILE_SH=$WORK/silent1.sh AITOOLS_PROFILE_PS1=$WORK/silent1.ps1"

run_case broken-silent1-rmp rmp "rc=3
alias= via= company= name=
warnings=0 errors=2" "ERROR|machine profile|no machine match
ACTION||Run: aitools user init (pick or register this machine's profile)" "AITOOLS_PROFILE_SH=$WORK/silent1.sh AITOOLS_PROFILE_PS1=$WORK/silent1.ps1"

run_case broken-silent0-eget eget "rc=1
found=false method= path=
warnings=1 errors=0" "" "AITOOLS_PROFILE_SH=$WORK/silent0.sh AITOOLS_PROFILE_PS1=$WORK/silent0.ps1"

run_case broken-silent0-eset eset "rc=1
result=failed pushed=false
warnings=1 errors=0" "ACTION||see deploy.log -- a tool choice (tool exception) was not saved" "AITOOLS_PROFILE_SH=$WORK/silent0.sh AITOOLS_PROFILE_PS1=$WORK/silent0.ps1"

run_case broken-throw-urp urp "rc=3
path= via=
warnings=0 errors=1" "ERROR|dotprofile|resolver failed
$A_DP" "AITOOLS_PROFILE_PS1=$WORK/throw.ps1" ps

run_case broken-parse-urp urp "rc=3
path= via=
warnings=0 errors=1" "ERROR|dotprofile|resolver failed
$A_DP" "AITOOLS_PROFILE_PS1=$WORK/parse.ps1" ps

# Re-key batch 3, item 1: the id-key results
fixture id-key
run_case rmpk-id-key rmpk "rc=0
alias=nobul-mac via=id company=nobul-mac-co
key=$ID_KEY owner=this legacy=false host=nobul-mac
warnings=0 errors=0" ""

fixture with-id
run_case rmpk-legacy rmpk "rc=0
alias=nobul-mac via=id company=nobul-tech
key=nobul-mac owner=this legacy=true host=nobul-mac
warnings=0 errors=0" ""

fixture hostname-only
run_case rmpk-unregistered rmpk "rc=0
alias=nobul-mac via=hostname company=nobul-tech
key=nobul-mac owner=unregistered legacy=true host=nobul-mac
warnings=0 errors=0" ""

# Another machine's id-keyed profile with this hostname: matched, owner other
fixture other-id
run_case rmpk-other rmpk "rc=0
alias=old-mac via=hostname company=nobul-tech
key=aaaaaaaa-1111-2222-3333-444444444444 owner=other legacy=false host=nobul-mac
warnings=0 errors=0" ""

fixture none
run_case rmpk-none rmpk "rc=1
alias= via=none company=
key= owner=absent legacy=false host=nobul-mac
warnings=0 errors=0" ""

fixture with-id
perl -pi -e "s/$ID_MAC/OTHER-ID/; s/\"hostname\": \"nobul-mac\"/\"hostname\": \"elsewhere\"/" "$DP/profile.json"
run_case rmpk-nomatch rmpk "rc=3
alias= via=none company=nobul-tech
key= owner=absent legacy=false host=nobul-mac
warnings=0 errors=2" "ERROR|machine profile|no machine match
ACTION||Run: aitools user init (pick or register this machine's profile)"

# A resolver that predates the id-key fields (an older embedded copy): defaults
fixture with-id
run_case rmpk-old-resolver rmpk "rc=0
alias=nobul-mac via=id company=nobul-tech
key= owner=absent legacy=false host=nobul-mac
warnings=0 errors=0" "" "AITOOLS_PROFILE_SH=$WORK/oldres.sh AITOOLS_PROFILE_PS1=$WORK/oldres.ps1"

# Item 3: a dotprofile resolver error twice in one run -> two ERROR rows, one ACTION
run_case urp-missing-twice urp2 "rc=3
path= via=none
warnings=0 errors=2" "ERROR|dotprofile|resolver missing
$A_DP
ERROR|dotprofile|resolver missing" "AITOOLS_PROFILE_SH=$WORK/none.sh AITOOLS_PROFILE_PS1=$WORK/none.ps1"

# FIX-1, A-2: the machine-profile wrapper's "resolver missing" path writes the
# ACTION too; with the dotprofile wrapper in the same run, one ACTION in total
run_case rmp-missing rmp "rc=3
alias= via=none company= name=
warnings=0 errors=1" "ERROR|machine profile|resolver missing
$A_DP" "AITOOLS_PROFILE_SH=$WORK/none.sh AITOOLS_PROFILE_PS1=$WORK/none.ps1"
run_case urp-rmp-missing keep "rc=3
kept=urp:/caller/urp pf:/caller/pf alias:caller name:caller-name
alias= urp-via=none
warnings=0 errors=2" "ERROR|dotprofile|resolver missing
$A_DP
ERROR|machine profile|resolver missing" "AITOOLS_PROFILE_SH=$WORK/none.sh AITOOLS_PROFILE_PS1=$WORK/none.ps1"

# Item 2: resolver exits 3 and 4 are mapped and logged with their meaning in
# every wrapper; neither is read as "nothing found"
for n in 3 4; do
    X="AITOOLS_PROFILE_SH=$WORK/exit$n.sh AITOOLS_PROFILE_PS1=$WORK/exit$n.ps1 SHOW_NOTES=1"
    fixture with-id
    run_case "exit$n-urp" urp "rc=3
path= via=none
warnings=0 errors=1
notes=1" "ERROR|dotprofile|resolver failed
$A_DP" "$X"
    run_case "exit$n-rmp" rmp "rc=3
alias= via=none company= name=
warnings=0 errors=2
notes=1" "ERROR|machine profile|no machine match
ACTION||Run: aitools user init (pick or register this machine's profile)" "$X"
    run_case "exit$n-eget" eget "rc=1
found=false method= path=
warnings=1 errors=0
notes=1" "" "$X"
done
fixture with-id
run_case exit3-eset eset "rc=3
result=refused pushed=false
warnings=1 errors=0
notes=1" "ACTION||run aitools user init to remember tool choices" "AITOOLS_PROFILE_SH=$WORK/exit3.sh AITOOLS_PROFILE_PS1=$WORK/exit3.ps1 SHOW_NOTES=1"
run_case exit4-eset eset "rc=1
result=failed pushed=false
warnings=1 errors=0
notes=1" "ACTION||see deploy.log -- a tool choice (tool exception) was not saved" "AITOOLS_PROFILE_SH=$WORK/exit4.sh AITOOLS_PROFILE_PS1=$WORK/exit4.ps1 SHOW_NOTES=1"

# M3-FINISH item 3: the runner itself (_aitlib_profile_run / Invoke-AitLibProfile),
# as user init calls it. register and migrate print a "result" line and no "via"
# line; hostname prints a bare value. Each exit code 0-4 and a missing resolver.
fixture with-id
stub() { printf 'AITOOLS_PROFILE_SH=%s/%s.sh AITOOLS_PROFILE_PS1=%s/%s.ps1' "$WORK" "$1" "$WORK" "$1"; }
run_case run-register-result run "rc=0 profrc=0
out=created
err=
warnings=0 errors=0" "" "RUN_ARGS=register $(stub res0)"
run_case run-migrate-result run "rc=0 profrc=0
out=created
err=
warnings=0 errors=0" "" "RUN_ARGS=migrate $(stub res0)"
run_case run-register-exit1-result run "rc=0 profrc=1
out=failed
err=profile.json not found
warnings=0 errors=0" "" "RUN_ARGS=register $(stub res1)"
run_case run-exit2 run "rc=0 profrc=2
out=
err=bad input
warnings=0 errors=0" "" "RUN_ARGS=register $(stub exit2)"
for n in 3 4; do
    run_case "run-exit$n" run "rc=0 profrc=$n
out=none
err=stub says no
warnings=0 errors=0" "" "RUN_ARGS=register $(stub "exit$n")"
done
for n in 0 1; do
    run_case "run-silent$n-register" run "rc=0 profrc=2
out=
err=resolver exited $n without result lines (see deploy.log)
warnings=0 errors=0" "" "RUN_ARGS=register $(stub "silent$n")"
done
run_case run-hostname-stub run "rc=0 profrc=0
out=probe-host
err=
warnings=0 errors=0" "" "RUN_ARGS=hostname $(stub host)"
run_case run-hostname-empty run "rc=0 profrc=2
out=
err=resolver exited 0 without result lines (see deploy.log)
warnings=0 errors=0" "" "RUN_ARGS=hostname $(stub silent0)"
# A bare value is accepted only for hostname and machine-id
run_case run-bare-value-resolve run "rc=0 profrc=2
out=probe-host
err=resolver exited 0 without result lines (see deploy.log)
warnings=0 errors=0" "" "RUN_ARGS=resolve $(stub host)"
run_case run-missing run "rc=1 profrc=2
out=
err=resolver none.sh not found ($WORK)
warnings=0 errors=0" "" "RUN_ARGS=register $(stub none)" bash
run_case run-missing run "rc=1 profrc=2
out=
err=resolver none.ps1 not found ($WORK)
warnings=0 errors=0" "" "RUN_ARGS=register $(stub none)" ps
run_case run-throw run "rc=0 profrc=2
out=
err=aitools-profile register threw: boom
warnings=0 errors=0" "" "RUN_ARGS=register AITOOLS_PROFILE_PS1=$WORK/throw.ps1" ps
# The real resolver (this fixture: this machine's id-keyed profile)
fixture id-key
run_case run-real-register run "rc=0 profrc=0
out=updated
err=
warnings=0 errors=0" "" "RUN_ARGS=register,--profile,$DP/profile.json,--out,$WORK/reg.tmp,--shell,zsh,--environment,local"
rm -f "$WORK/reg.tmp"
run_case run-real-migrate run "rc=0 profrc=0
out=unchanged
err=
warnings=0 errors=0" "" "RUN_ARGS=migrate,--profile,$DP/profile.json"
run_case run-real-hostname run "rc=0 profrc=0
out=nobul-mac
err=
warnings=0 errors=0" "" "RUN_ARGS=hostname"

# m2: the bash -> pwsh branch of aitools-lib.sh, the one Git Bash takes on Windows
# (AITOOLS_PLATFORM windows; AITLIB_PROFILE_VIA_PWSH=1 is a no-op there). Windows
# only: on macOS/Linux it would run aitools-profile.ps1, whose guard refuses. A
# non-ASCII identity value must arrive intact (UTF-8 output).
if [ "$LANG_RUN" != ps1 ]; then
    printf '  skip via-pwsh-* (the Git Bash -> pwsh branch runs on Windows only)\n'
else
    PWSH_ENV="AITLIB_PROFILE_VIA_PWSH=1"
    fixture with-id
    run_case via-pwsh-urp urp "rc=0
path=$DP via=convention
warnings=0 errors=0" "" "$PWSH_ENV" gitbash

    FIX_NAME="José"
    fixture with-id
    run_case via-pwsh-rmp-utf8 rmp "rc=0
alias=nobul-mac via=id company=nobul-tech name=José
warnings=0 errors=0" "" "$PWSH_ENV" gitbash
    FIX_NAME="Jose"

    fixture id-key
    run_case via-pwsh-rmpk-id-key rmpk "rc=0
alias=nobul-mac via=id company=nobul-mac-co
key=$ID_KEY owner=this legacy=false host=nobul-mac
warnings=0 errors=0" "" "$PWSH_ENV" gitbash

    fixture with-id
    run_case via-pwsh-exit4-urp urp "rc=3
path= via=none
warnings=0 errors=1
notes=1" "ERROR|dotprofile|resolver failed
$A_DP" "$PWSH_ENV AITOOLS_PROFILE_PS1=$WORK/exit4.ps1 SHOW_NOTES=1" gitbash

    fixture hostname-only
    run_case via-pwsh-eset-refused eset "rc=3
result=refused pushed=false
warnings=1 errors=0" "ACTION||run aitools user init to remember tool choices" "$PWSH_ENV" gitbash

    fixture with-id
    run_case via-pwsh-stub urp "rc=0
path=/stub/aitools-dp via=env
warnings=0 errors=0" "" "$PWSH_ENV AITOOLS_PROFILE_PS1=$WORK/stub.ps1" gitbash

    for broken in silent0 silent1 throw parse; do
        run_case "via-pwsh-broken-$broken" urp "rc=3
path= via=
warnings=0 errors=1" "ERROR|dotprofile|resolver failed
$A_DP" "$PWSH_ENV AITOOLS_PROFILE_PS1=$WORK/$broken.ps1" gitbash
    done

    # M3-FINISH item 3 through the pwsh branch: result lines, a bare hostname, a
    # throw (an "error" line, as in-process), a missing resolver, and the path
    # arguments that are converted (--path, --profile, --out, --config; --slug not)
    run_case via-pwsh-run-register-result run "rc=0 profrc=0
out=created
err=
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=register AITOOLS_PROFILE_PS1=$WORK/res0.ps1" gitbash
    run_case via-pwsh-run-exit1-result run "rc=0 profrc=1
out=failed
err=profile.json not found
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=register AITOOLS_PROFILE_PS1=$WORK/res1.ps1" gitbash
    run_case via-pwsh-run-hostname run "rc=0 profrc=0
out=probe-host
err=
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=hostname AITOOLS_PROFILE_PS1=$WORK/host.ps1" gitbash
    run_case via-pwsh-run-silent0 run "rc=0 profrc=2
out=
err=resolver exited 0 without result lines (see deploy.log)
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=migrate AITOOLS_PROFILE_PS1=$WORK/silent0.ps1" gitbash
    run_case via-pwsh-run-throw run "rc=0 profrc=2
out=
err=aitools-profile register threw: boom
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=register AITOOLS_PROFILE_PS1=$WORK/throw.ps1" gitbash
    run_case via-pwsh-run-missing run "rc=1 profrc=2
out=
err=resolver none.ps1 or pwsh not found ($WORK)
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=register AITOOLS_PROFILE_PS1=$WORK/none.ps1" gitbash
    run_case via-pwsh-run-path-args run "rc=0 profrc=0
out=ok
err=
args=register --profile W/conv/p.json --out W/conv/o.tmp --config W/conv/c.json --path W/conv/x --slug /conv/s
warnings=0 errors=0" "" "$PWSH_ENV FAKEBIN=$WORK/fakebin RUN_ARGS=register,--profile,/conv/p.json,--out,/conv/o.tmp,--config,/conv/c.json,--path,/conv/x,--slug,/conv/s AITOOLS_PROFILE_PS1=$WORK/args.ps1" gitbash
    fixture id-key
    run_case via-pwsh-run-real-register run "rc=0 profrc=0
out=updated
err=
warnings=0 errors=0" "" "$PWSH_ENV RUN_ARGS=register,--profile,$DP/profile.json,--out,$WORK/reg.tmp,--shell,zsh,--environment,local" gitbash
    rm -f "$WORK/reg.tmp"
fi

# ---------------------------------------------------------------------------
# Re-key batch 3, item 4: child-log relay helpers (deploy.jsonl)
# ---------------------------------------------------------------------------
# Children that log through the lib: info, a warning with a quote, a backslash
# and a tab, a second warning, then by CHILD_FAIL:
#   0  the standard exit footer, exit 0
#   1  an error, its own ERROR row "child tool|child failed", footer, exit 1
#   2  an error, no row, exit 0 anyway (a child bug)
#   3  dies before any row or footer: bash `false` under set -e, PS exit 1
#   4  exit 127: bash runs a missing command, PS exit 127
#   5  a user abort: "Aborted by user", exit 2 (D-TS13)
#   6  PS: throws; bash: footer, exit 0
#   7  bash: makes RO_DIR read-only (it holds the relay's exit-code file, made
#      by the mktemp stub in $WORK/mkro: the file cannot be removed), then
#      footer, exit 0
cat > "$WORK/child.sh" <<'CHILD'
set -euo pipefail
source "$REPO/scripts/aitools-lib.sh"
logging_init "child-sh"
log "child info"
log_warn "quote \" back \\ tab"$'\t'"end"
log_warn "second warning"
case "${CHILD_FAIL:-0}" in
    1) log_error "child error"; write_summary ERROR "child tool" "child failed" ;;
    2) log_error "child error" ;;
    3) false ;;
    4) aitools-test-no-such-command ;;
    5) log_error "Aborted by user"; exit 2 ;;
    7) chmod 555 "$RO_DIR" ;;
esac
if [ "$ERRORS" -gt 0 ] && [ "${CHILD_FAIL:-0}" = "1" ]; then log "FAILED with $ERRORS error(s)" "error"; exit 1
elif [ "$WARNINGS" -gt 0 ]; then log "COMPLETED with $WARNINGS warning(s)" "warn"; exit 0
else log "COMPLETED successfully" "ok"; exit 0; fi
CHILD
cat > "$WORK/child.ps1" <<'CHILD'
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "child-ps"
Log "child info"
LogWarn "quote `" back \ tab`tend"
LogWarn "second warning"
switch ($env:CHILD_FAIL) {
    "1" { LogError "child error"; Write-Summary "ERROR" "child tool" "child failed" }
    "2" { LogError "child error" }
    "3" { exit 1 }
    "4" { exit 127 }
    "5" { LogError "Aborted by user"; exit 2 }
    "6" { throw "child died" }
}
# Review m4: the relay's own parameters and locals must not leak into the child (dynamic scope)
if ($Label -or $ChildScript -or $ChildArgs -or $SummaryTool -or $Detail -or $ErrRows) { LogError "parent's Invoke-ChildRelayed variables are visible" }
if ($errors -gt 0 -and $env:CHILD_FAIL -eq "1") { Log "FAILED with $errors error(s). See log: $logFile" "error"; exit 1 }
elseif ($warnings -gt 0) { Log "COMPLETED with $warnings warning(s)" "warn"; exit 0 }
else { Log "COMPLETED successfully" "ok"; exit 0 }
CHILD
# A child that does not parse (PowerShell: the relay sees a parse error)
printf 'Log "never"\nif (\n' > "$WORK/child-parse.ps1"
# Parents: RMODE=record (one jsonl_record with CR, ESC, newline, tab, quote,
# backslash), run (run_child_relayed / Invoke-ChildRelayed with the summary tool
# "child tool"), run-notool (no summary tool), parse (PS: a child that does not
# parse), captured (relay_child_log / Send-ChildLog on captured output)
cat > "$WORK/relay.sh" <<'RELAY'
set -euo pipefail
# FAKEBIN: a mktemp stub goes first on PATH (macOS mktemp ignores TMPDIR)
if [ -n "${FAKEBIN:-}" ]; then PATH="$FAKEBIN:$PATH"; fi
source "$REPO/scripts/aitools-lib.sh"
logging_init "test-relay"
# PRE_ROW=1: an earlier step's ERROR row is in the summary before the child runs
if [ "${PRE_ROW:-}" = "1" ]; then write_summary ERROR "earlier step" "failed before"; fi
rc=0
case "$RMODE" in
    record) jsonl_record 2026-01-01T00:00:00Z test-relay warn "q \" b \\ t"$'\t'"n"$'\n'"l"$'\r'" e"$'\033'"[0m x José ✓" ;;
    noargs)
        run_child_relayed --summary-tool "child tool" "no command" || rc=$?
        printf 'rc=%s child_rc=%s\n' "$rc" "$AITLIB_CHILD_RC" ;;
    run)
        run_child_relayed --summary-tool "child tool" "child step" "${BASH:-bash}" "$REPO_WORK/child.sh" || rc=$?
        printf 'rc=%s child_rc=%s\n' "$rc" "$AITLIB_CHILD_RC" ;;
    run-notool)
        run_child_relayed "child step" "${BASH:-bash}" "$REPO_WORK/child.sh" || rc=$?
        printf 'rc=%s child_rc=%s\n' "$rc" "$AITLIB_CHILD_RC" ;;
    captured)
        out=""; crc=0
        out=$("${BASH:-bash}" "$REPO_WORK/child.sh") || crc=$?
        relay_child_log "$out"
        printf 'rc=%s child_rc=%s\n' "$rc" "$crc" ;;
esac
printf 'cw=%s ce=%s warnings=%s errors=%s\n' "${AITLIB_CHILD_WARNINGS:-}" "${AITLIB_CHILD_ERRORS:-}" "$WARNINGS" "$ERRORS"
RELAY
cat > "$WORK/relay.ps1" <<'RELAY'
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-relay"
# PRE_ROW=1: an earlier step's ERROR row is in the summary before the child runs
if ($env:PRE_ROW -eq "1") { Write-Summary "ERROR" "earlier step" "failed before" }
$rc = 0
$child = Join-Path $env:REPO_WORK "child.ps1"
switch ($env:RMODE) {
    "record" { Write-JsonlRecord "2026-01-01T00:00:00Z" "test-relay" "warn" "q `" b \ t`tn`nl`r e$([char]27)[0m x José ✓" }
    "noargs" {
        $rc = Invoke-ChildRelayed "no command" "" @{} "child tool"
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "run" {
        $rc = Invoke-ChildRelayed "child step" $child @{} "child tool"
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "run-notool" {
        $rc = Invoke-ChildRelayed "child step" $child @{}
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "parse" {
        $rc = Invoke-ChildRelayed "child step" (Join-Path $env:REPO_WORK "child-parse.ps1") @{} "child tool"
        "rc=$rc child_rc=$($script:AitLibChildRc)"
    }
    "captured" {
        $global:LASTEXITCODE = 0
        $lines = @(& $child 6>&1 | ForEach-Object { [string]$_ })
        $crc = $LASTEXITCODE
        Send-ChildLog $lines
        "rc=$rc child_rc=$crc"
    }
}
"cw=$($script:AitLibChildWarnings) ce=$($script:AitLibChildErrors) warnings=$($script:warnings) errors=$($script:errors)"
RELAY
# check-jsonl.pl FILE WANT-MSG... -- every line valid JSON with the installers'
# key order; prints "records=N" and, for each WANT-MSG, "msg-ok" / "msg-missing"
cat > "$WORK/check-jsonl.pl" <<'PERL'
use strict; use warnings; use JSON::PP; use Encode qw(decode);
my $f = shift @ARGV; my %msgs; my $n = 0; my $bad = 0;
@ARGV = map { decode("UTF-8", $_) } @ARGV;   # decoded msgs are characters, not bytes
open(my $fh, "<:raw", $f) or do { print "records=0 (no file)\n"; exit 0 };
while (my $l = <$fh>) {
    chomp $l; $n++;
    my $o = eval { JSON::PP->new->utf8->decode($l) };
    if (!$o) { $bad++; next; }
    my @k = ($l =~ /"(ts|host|os|script|run_id|level|msg)":/g);
    $bad++ unless join(",", @k) eq "ts,host,os,script,run_id,level,msg";
    $msgs{$o->{msg}} = 1;
}
print "records=$n invalid=$bad\n";
for my $w (@ARGV) { print exists $msgs{$w} ? "msg-ok\n" : "msg-missing: $w\n"; }
PERL

WARN_MSG="quote \" back \\ tab"$'\t'"end"
# relay_case NAME MODE CHILD_FAIL WANT-RESULT WANT-RECORDS [WANT-SUMMARY] [IMPLS] [EXTRA-ENV]
# WANT-RECORDS "-": no deploy.jsonl expected (no child ran); "skip": the child
# printed nothing (no console or deploy.jsonl check). WANT-SUMMARY: the summary
# rows (default none). IMPLS: "bash ps" (default), "bash" or "ps"; each runs only
# where impl_runs says. EXTRA-ENV: space-separated VAR=value words.
relay_case() {
    local name="$1" mode="$2" fail="$3" want="$4" wrec="$5" wsum="${6:-}" impls="${7:-bash ps}" extra="${8:-}" impl got out jl sum
    for impl in $impls; do
        if ! impl_runs "$impl"; then continue; fi
        rm -rf "$H"; mkdir -p "$H/.aitools/logs"; : > "$H/summary.txt"
        jl="$H/.aitools/logs/deploy.jsonl"
        if [ "$impl" = "bash" ]; then
            # shellcheck disable=SC2086  # $extra is word-split on purpose
            out=$(env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" REPO="$REPO" REPO_WORK="$WORK" \
                RMODE="$mode" CHILD_FAIL="$fail" AITOOLS_RUN_ID=run-fixed $extra "$BASH_BIN" "$WORK/relay.sh" 2>/dev/null) || out="driver failed: $?"  # stderr: a crashing child's own messages
        else
            # Native pwsh (Windows): Windows paths, MSYS argument conversion off
            # shellcheck disable=SC2086,SC2046  # $extra / to_native are word-split on purpose
            out=$(env HOME="$(native_path "$H")" USERPROFILE="$(native_path "$H")" AITOOLS_LOG_DIR="$(native_path "$H/.aitools/logs")" \
                AITOOLS_SUMMARY_FILE="$(native_path "$H/summary.txt")" REPO="$(native_path "$REPO")" REPO_WORK="$(native_path "$WORK")" \
                RMODE="$mode" CHILD_FAIL="$fail" AITOOLS_RUN_ID=run-fixed $(to_native "$extra") MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
                pwsh -NoProfile -NonInteractive -File "$(native_path "$WORK/relay.ps1")" 2>/dev/null \
                | perl -pe 's/\e\[[0-9;]*m//g; s/\r//g') || out="driver failed: $?"  # colour codes of the relayed console lines; CRs
            from_native "$H/summary.txt"
        fi
        got=$(printf '%s\n' "$out" | grep -E '^(rc|cw)=' || true)  # only the driver's result lines
        if [ "$got" = "$want" ]; then ok "$name ($impl): result"
        else bad "$name ($impl): got"; printf '%s\n' "$got" | sed 's/^/         /'; printf '       want\n'; printf '%s\n' "$want" | sed 's/^/         /'; fi
        sum=$(cat "$H/summary.txt")
        if [ "$sum" = "$wsum" ]; then ok "$name ($impl): summary rows"
        else bad "$name ($impl): summary '$sum', want '$wsum'"; fi
        if [ "$wrec" = "-" ]; then
            if [ -f "$jl" ]; then bad "$name ($impl): deploy.jsonl written without a child"; else ok "$name ($impl): no deploy.jsonl"; fi
            continue
        fi
        if [ "$wrec" = "skip" ]; then continue; fi
        if [ "$mode" != "record" ]; then
            if printf '%s\n' "$out" | grep -qF "second warning"; then ok "$name ($impl): child lines on the console"
            else bad "$name ($impl): child lines not on the console"; fi
        fi
        got=$(perl "$WORK/check-jsonl.pl" "$jl" "$WARN_MSG")
        if [ "$mode" = "record" ]; then
            got=$(perl "$WORK/check-jsonl.pl" "$jl" "q \" b \\ t"$'\t'"n"$'\n'"l e[0m x José ✓")
            cp "$jl" "$WORK/record.jsonl"
        fi
        if [ "$got" = "$wrec" ]; then ok "$name ($impl): deploy.jsonl"
        else bad "$name ($impl): deploy.jsonl '$got', want '$wrec'"; fi
    done
}

printf 'relay helpers\n'
relay_case relay-record record 0 "cw= ce= warnings=0 errors=0" "records=1 invalid=0
msg-ok"
# Parity: the bash record (macOS/Linux) and the PowerShell record (Windows) equal
# one golden file. host and os name the machine the record was written on (they
# were equal when both shells ran on one machine): placeholders here.
if [ -f "$WORK/record.jsonl" ]; then
    perl -pe 's/"host":"(?:[^"\\]|\\.)*"/"host":"<HOST>"/; s/"os":"(?:[^"\\]|\\.)*"/"os":"<OS>"/' "$WORK/record.jsonl" > "$WORK/record.norm.jsonl"
    if golden_match lib-relay-record.jsonl "$WORK/record.norm.jsonl"; then ok "relay-record: record matches golden (bash and PowerShell share it)"
    else bad "relay-record: record differs from golden lib-relay-record.jsonl"; fi
else
    bad "relay-record: no deploy.jsonl record to compare"
fi
relay_case relay-run-ok run 0 "rc=0 child_rc=0
cw=2 ce=0 warnings=2 errors=0" "records=4 invalid=0
msg-ok"
# A failed child that wrote its own ERROR row gets no second one (FIX-1, A-3)
relay_case relay-run-fail run 1 "rc=1 child_rc=1
cw=2 ce=1 warnings=2 errors=1" "records=5 invalid=0
msg-ok" "ERROR|child tool|child failed"
# A child that logged an error but exited 0 and wrote no row: one ERROR row
relay_case relay-run-error-exit0 run 2 "rc=1 child_rc=0
cw=2 ce=1 warnings=2 errors=1" "records=5 invalid=0
msg-ok" "ERROR|child tool|logged errors (exit 0)"
# A-3: a child that died before its own rows (set -e abort / exit 1, exit 127)
# is in the panel as ERROR; a user abort (exit 2) too
relay_case relay-run-crash run 3 "rc=1 child_rc=1
cw=2 ce=0 warnings=2 errors=1" "records=3 invalid=0
msg-ok" "ERROR|child tool|script failed (exit 1)"
relay_case relay-run-exit127 run 4 "rc=1 child_rc=127
cw=2 ce=0 warnings=2 errors=1" "records=3 invalid=0
msg-ok" "ERROR|child tool|script failed (exit 127)"
relay_case relay-run-abort run 5 "rc=1 child_rc=2
cw=2 ce=1 warnings=2 errors=1" "records=4 invalid=0
msg-ok" "ERROR|child tool|aborted (exit 2)"
# Review A m1: the dedupe compares with the rows before the child, not with zero:
# an earlier step's ERROR row does not hide the crashed child's row
relay_case relay-run-crash-prior-row run 3 "rc=1 child_rc=1
cw=2 ce=0 warnings=2 errors=1" "records=3 invalid=0
msg-ok" "ERROR|earlier step|failed before
ERROR|child tool|script failed (exit 1)" "bash ps" "PRE_ROW=1"
# Without a summary tool: no row (the caller writes its own)
relay_case relay-run-crash-notool run-notool 3 "rc=1 child_rc=1
cw=2 ce=0 warnings=2 errors=1" "records=3 invalid=0
msg-ok" ""
# PowerShell: a throw and a parse error (in-process) are one LogError and a row
relay_case relay-run-throw run 6 "rc=1 child_rc=1
cw=2 ce=0 warnings=2 errors=1" "records=3 invalid=0
msg-ok" "ERROR|child tool|script failed (exception)" ps
relay_case relay-run-parse parse 0 "rc=1 child_rc=1
cw=0 ce=0 warnings=0 errors=1" "skip" "ERROR|child tool|script failed (exception)" ps
# Review m3: no command is a failure, not a silent success; with a tool, a row
relay_case relay-run-no-command noargs 0 "rc=1 child_rc=1
cw=0 ce=0 warnings=0 errors=1" "-" "ERROR|child tool|not run (no command)"
# A-4 (bash only: the relay's exit-code temp file). mktemp fails: not run, a row;
# the file cannot be removed: a detail line, nothing else changes. mktemp stubs:
# $WORK/mkfail fails, $WORK/mkro creates the file in $WORK/tmpro
mkdir -p "$WORK/mkfail" "$WORK/mkro" "$WORK/tmpro"
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/mkfail/mktemp"
printf '#!/usr/bin/env bash\n: > "%s/tmpro/rc.tmp"\nprintf "%%s\\n" "%s/tmpro/rc.tmp"\n' "$WORK" "$WORK" > "$WORK/mkro/mktemp"
chmod +x "$WORK/mkfail/mktemp" "$WORK/mkro/mktemp"
relay_case relay-run-mktemp-fail run 0 "rc=1 child_rc=1
cw=0 ce=0 warnings=0 errors=1" "-" "ERROR|child tool|not run (mktemp failed)" bash "FAKEBIN=$WORK/mkfail"
# Review A n3: root ignores the read-only directory (Claude Code web runs as root).
# bash only (the relay's own temp file in aitools-lib.sh): macOS/Linux
if [ "$LANG_RUN" != sh ]; then
    printf '  skip relay-run-rm-fail (bash relay temp file: macOS/Linux)\n'
elif [ "$(id -u)" -eq 0 ]; then
    printf '  skip relay-run-rm-fail (running as root: a read-only directory does not stop rm)\n'
else
    relay_case relay-run-rm-fail run 7 "rc=0 child_rc=0
cw=2 ce=0 warnings=2 errors=0" "records=4 invalid=0
msg-ok" "" bash "FAKEBIN=$WORK/mkro RO_DIR=$WORK/tmpro"
    chmod 755 "$WORK/tmpro"
    if grep -qF "[detail] child step: could not remove temp file $WORK/tmpro/rc.tmp" "$H/.aitools/logs/deploy.log"; then ok "relay-run-rm-fail (bash): detail line in deploy.log"
    else bad "relay-run-rm-fail (bash): no 'could not remove temp file' detail line"; fi
fi
relay_case relay-captured captured 0 "rc=0 child_rc=0
cw=2 ce=0 warnings=2 errors=0" "records=4 invalid=0
msg-ok"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
