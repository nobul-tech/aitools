#!/usr/bin/env bash
# test-config.sh -- tests for scripts/setup-user-config.sh and .ps1 (the config.json writer)
#
# Each case builds an isolated HOME (fake dotprofile + config.json), runs the bash
# writer and, when pwsh is available, the PowerShell writer on a fresh copy of the
# same fixture (AITOOLS_PROFILE_TEST_ANY_OS=1, injected machine id / hostname).
# Asserts exit codes, the written config.json and the summary rows, and that both
# writers produce byte-identical config.json files and identical summary rows.
# Platform: macOS/Linux (CI: macOS and Linux runners). Safe to re-run.
# Usage: bash tests/profile/test-config.sh [--bash-only]
#   AITOOLS_TEST_BASH=/bin/bash runs the writer under another bash (e.g. macOS 3.2)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH="$REPO/scripts/setup-user-config.sh"
PS="$REPO/scripts/setup-user-config.ps1"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
USE_PS=true
if [ "${1:-}" = "--bash-only" ] || ! command -v pwsh >/dev/null 2>&1; then USE_PS=false; fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

ID_MAC="3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
H="$WORK/home"
DP="$H/repos/aitools-nobul-jose"
CFG="$H/.aitools/config.json"
CASE_ENV=""

profile_with_id() {
    mkdir -p "$DP"
    cat > "$DP/profile.json" <<JSON
{
  "version": 2,
  "identity": {
    "github": "nobul-jose",
    "name": "Jose",
    "company": "nobul-tech",
    "git": {
      "name": "Jose",
      "email": "jose@nobul.tech"
    }
  },
  "profiles": {
    "nobul-mac": {
      "machine": {
        "id": "$ID_MAC",
        "hostname": "nobul-mac"
      }
    },
    "laptop": {
      "company": "Nobul",
      "machine": {
        "hostname": "Joses-MBP"
      }
    }
  }
}
JSON
}

reset_home() { rm -rf "$H"; mkdir -p "$H/repos" "$H/.aitools"; }

# run_writer IMPL ARGS... -- run one writer; sets RC; summary rows in $H/summary.txt
run_writer() {
    local impl="$1"; shift
    : > "$H/summary.txt"
    RC=0
    if [ "$impl" = "bash" ]; then
        env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac $CASE_ENV \
            "$BASH_BIN" "$SH" "$@" > "$WORK/out.txt" 2>&1 || RC=$?
    else
        env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac \
            AITOOLS_PROFILE_TEST_ANY_OS=1 $CASE_ENV \
            pwsh -NoProfile -File "$PS" "$@" > "$WORK/out.txt" 2>&1 || RC=$?
    fi
}

# map_args -- translate bash-style options to the PowerShell parameters
map_args() {
    PS_ARGS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --repos-path)     PS_ARGS+=(-ReposPath "$2"); shift 2 ;;
            --repo-path)      PS_ARGS+=(-RepoPath "$2"); shift 2 ;;
            --drives-json)    PS_ARGS+=(-DrivesJson "$2"); shift 2 ;;
            --github-user)    PS_ARGS+=(-GithubUser "$2"); shift 2 ;;
            --user-repo-path) PS_ARGS+=(-UserRepoPath "$2"); shift 2 ;;
            --machine-alias)  PS_ARGS+=(-MachineAlias "$2"); shift 2 ;;
            --dry-run)        PS_ARGS+=(-DryRun); shift ;;
            *)                PS_ARGS+=("$1"); shift ;;
        esac
    done
}

# case_run NAME RC SETUP ARGS... -- SETUP builds the fixture before each writer
case_run() {
    local name="$1" want="$2" setup="$3"; shift 3
    CASE="$name"
    "$setup"
    run_writer bash "$@"
    local brc=$RC
    cp "$CFG" "$WORK/$name.bash.json" 2>/dev/null || : > "$WORK/$name.bash.json"  # no config = empty copy
    cp "$H/summary.txt" "$WORK/$name.bash.summary"
    cp "$WORK/out.txt" "$WORK/$name.bash.out"
    OUTJ="$WORK/$name.bash.json"; SUMM="$WORK/$name.bash.summary"
    if [ "$brc" -eq "$want" ]; then ok "$name: bash exit $brc"
    else bad "$name: bash exit $brc, want $want"; sed 's/^/       /' "$WORK/$name.bash.out"; fi
    if $USE_PS; then
        "$setup"
        map_args "$@"
        run_writer ps ${PS_ARGS[@]+"${PS_ARGS[@]}"}
        cp "$CFG" "$WORK/$name.ps.json" 2>/dev/null || : > "$WORK/$name.ps.json"  # no config = empty copy
        if [ "$RC" -ne "$brc" ]; then bad "$name: pwsh exit $RC, bash $brc"; sed 's/^/       /' "$WORK/out.txt"; fi
        if cmp -s "$WORK/$name.bash.json" "$WORK/$name.ps.json"; then ok "$name: config.json bytes identical"
        else bad "$name: config.json differs"; diff "$WORK/$name.bash.json" "$WORK/$name.ps.json" | sed 's/^/       /' || true; fi
        if diff "$WORK/$name.bash.summary" "$H/summary.txt" > "$WORK/$name.sdiff"; then ok "$name: summary rows identical"
        else bad "$name: summary rows differ"; sed 's/^/       /' "$WORK/$name.sdiff"; fi
    fi
}
has_json() {  # has_json PERL-REGEX -- the bash-written config matches (whole file, /s)
    if perl -0777 -ne 'BEGIN { $r = shift @ARGV } exit(/$r/s ? 0 : 1)' "$1" "$OUTJ"; then ok "$CASE: config /$1/"
    else bad "$CASE: config lacks /$1/"; sed 's/^/       /' "$OUTJ"; fi
}
has_row() {  # has_row LINE -- the bash summary has this exact row
    if grep -qxF "$1" "$SUMM"; then ok "$CASE: row $1"
    else bad "$CASE: no row '$1'"; sed 's/^/       /' "$SUMM"; fi
}
no_row_like() {
    if grep -q "$1" "$SUMM"; then bad "$CASE: unexpected row /$1/"; sed 's/^/       /' "$SUMM"; else ok "$CASE: no row /$1/"; fi
}

printf 'setup-user-config tests (pwsh parity: %s)\n' "$USE_PS"
BOOT=(--repos-path "$H/repos" --repo-path "$H/repos/aitools")

# C1 fresh machine with a dotprofile: created, derived values, meta
fix_fresh() { reset_home; profile_with_id; }
case_run c1-fresh 0 fix_fresh "${BOOT[@]}" --github-user nobul-jose
has_row "OK|aitools config|created"
has_json '\A\{\n  "version": 3,\n  "reposPath": "[^"]+\/repos",\n  "repoPath": "[^"]+\/repos\/aitools",\n  "googleDrives": \[\],\n  "githubUser": "nobul-jose",\n  "userRepoPath": "[^"]+\/aitools-nobul-jose",\n  "machineAlias": "nobul-mac",\n  "meta": \{\n    "intent": \{\n      "purpose": "Per-machine pointers'
has_json '"writer": "setup-user-config",\n    "derivedFrom": "profile.json"\n  \}\n\}\n\z'

# C2 re-run on the result: verified, no write
fix_rerun() { fix_fresh; cp "$WORK/c1-fresh.bash.json" "$CFG"; }
case_run c2-verified 0 fix_rerun
has_row "OK|aitools config|verified"
if cmp -s "$OUTJ" "$WORK/c1-fresh.bash.json"; then ok "c2-verified: file unchanged"; else bad "c2-verified: file changed"; fi
if ls "$H/.aitools/" | grep -q 'config.json.bak'; then bad "c2-verified: a backup was written"; else ok "c2-verified: no backup (no write)"; fi

# C3 existing v2 config: extra keys kept in place, stale alias re-derived, version 3
fix_v2() {
    reset_home; profile_with_id
    cat > "$CFG" <<JSON
{
  "version": 2,
  "reposPath": "$H/repos",
  "repoPath": "$H/repos/aitools",
  "custom": { "keep": true },
  "googleDrives": [ { "path": "/gd", "account": "a@b.c", "label": "" } ],
  "userRepoPath": "$DP",
  "machineAlias": "new-mac"
}
JSON
}
case_run c3-upgrade 0 fix_v2
has_row "OK|aitools config|updated"
has_row "DETAIL|aitools config|version updated"
has_row "DETAIL|aitools config|machineAlias updated"
has_json '"custom": \{\n    "keep": true\n  \},\n  "googleDrives": \[\n    \{\n      "path": "\/gd"'
has_json '"machineAlias": "nobul-mac",\n  "githubUser": "nobul-jose",\n  "meta"'
if ls "$H/.aitools/" | grep -q 'config.json.bak'; then ok "c3-upgrade: backup written"; else bad "c3-upgrade: no backup"; fi

# C4 corrupt config: rebuilt with salvaged keys, WARN
fix_corrupt() {
    reset_home; profile_with_id
    printf '{ "reposPath": "%s", "repoPath": "%s", "machineAlias": "laptop", oops\n' "$H/repos" "$H/repos/aitools" > "$CFG"
}
case_run c4-corrupt 0 fix_corrupt
has_row "WARN|aitools config|rebuilt (was invalid)"
has_json '\A\{\n  "reposPath": "[^"]+",\n  "repoPath": "[^"]+",\n  "machineAlias": "nobul-mac",\n  "version": 3'

# C5 no dotprofile: bootstrap keys only, githubUser from the argument
fix_nodp() { reset_home; }
case_run c5-no-dotprofile 0 fix_nodp "${BOOT[@]}" --github-user someone
has_row "OK|aitools config|created"
has_json '"githubUser": "someone",\n  "meta"'
has_json '"derivedFrom": "bootstrap only"'

# C6 missing bootstrap values: error, nothing written
case_run c6-no-bootstrap 1 fix_nodp
has_row "ERROR|aitools config|missing bootstrap values"
if [ ! -s "$OUTJ" ]; then ok "c6-no-bootstrap: no config written"; else bad "c6-no-bootstrap: config written"; fi

# C7 no machine match: ERROR + ACTION, existing alias kept
fix_nomatch() {
    fix_v2
    perl -pi -e "s/\"id\": \"$ID_MAC\"/\"id\": \"other\"/; s/\"hostname\": \"nobul-mac\"/\"hostname\": \"elsewhere\"/" "$DP/profile.json"
}
case_run c7-no-match 1 fix_nomatch
has_row "ERROR|machine profile|no machine match"
has_row "ACTION||Run: aitools user init (profiles: nobul-mac, laptop)"
has_json '"machineAlias": "new-mac"'

# C8 dry run: nothing written
case_run c8-dry-run 0 fix_v2 --dry-run
has_row "OK|aitools config|dry-run: would update"
if grep -q '"version": 2' "$OUTJ"; then ok "c8-dry-run: config untouched"; else bad "c8-dry-run: config changed"; fi

# C8b dry run writes nothing under ~/.aitools, not even a temp file: it succeeds
# with ~/.aitools read-only (logs go to the writable logs/ below it)
fix_dry_ro() {
    if [ -d "$H/.aitools" ]; then chmod 755 "$H/.aitools"; fi
    fix_v2
    mkdir -p "$H/.aitools/logs"
    chmod 555 "$H/.aitools"
}
case_run c8b-dry-run-readonly 0 fix_dry_ro --dry-run
chmod 755 "$H/.aitools"
has_row "OK|aitools config|dry-run: would update"
no_row_like "merge failed"

# C9 drives: a non-empty array replaces, an empty one keeps
case_run c9-drives 0 fix_v2 --drives-json '[{"path":"/Volumes/GD/My Drive","account":"x@y.z","label":""}]'
has_json '"googleDrives": \[\n    \{\n      "path": "\/Volumes\/GD\/My Drive",\n      "account": "x\@y.z",\n      "label": ""\n    \}\n  \]'
case_run c9-drives-empty 0 fix_v2 --drives-json '[]'
has_json '"path": "\/gd"'

# C10 explicit alias (user init's choice) wins and is saved
case_run c10-alias 0 fix_v2 --machine-alias laptop
has_json '"machineAlias": "laptop"'

# C11 AITOOLS_USER_REPO_PATH: used for the run, not saved
fix_env() { reset_home; profile_with_id; cp -R "$DP" "$H/envdp"; fix_v2_cfg_only; }
fix_v2_cfg_only() { printf '{ "version": 3, "reposPath": "%s", "repoPath": "%s" }\n' "$H/repos" "$H/repos/aitools" > "$CFG"; }
CASE_ENV="AITOOLS_USER_REPO_PATH=$H/envdp"
case_run c11-env 0 fix_env
CASE_ENV=""
if grep -q '"userRepoPath"' "$OUTJ"; then bad "c11-env: userRepoPath saved from the env override"; else ok "c11-env: userRepoPath not saved"; fi
has_json '"machineAlias": "nobul-mac"'

# C13 profile not registered (no machine.id): written, WARN + ACTION (action required)
fix_unreg() {
    fix_v2
    perl -0pi -e "s/\"id\": \"$ID_MAC\",\n\s*//" "$DP/profile.json"
    perl -pi -e 's/"new-mac"/"nobul-mac"/' "$CFG"
}
case_run c13-unregistered 0 fix_unreg
has_row "WARN|aitools config|updated"
has_row "ACTION||Run: aitools user init (registers this machine)"

# C14 relative bootstrap path: bad arguments, nothing written
case_run c14-relative 1 fix_nodp --repos-path repos --repo-path "$H/repos/aitools"
has_row "ERROR|aitools config|bad arguments"
if [ ! -s "$OUTJ" ]; then ok "c14-relative: no config written"; else bad "c14-relative: config written"; fi

# C15 double slash in a path value: validation failed, existing file untouched
case_run c15-double-slash 1 fix_v2 --repos-path "$H/repos//x"
has_row "ERROR|aitools config|validation failed"
if grep -q '"version": 2' "$OUTJ"; then ok "c15-double-slash: config untouched"; else bad "c15-double-slash: config changed"; fi

# C16 invalid profile.json: its own ERROR row, not "no machine match"
fix_badprofile() { fix_v2; printf '{ "version": 2, ' > "$DP/profile.json"; }
case_run c16-bad-profile 1 fix_badprofile
has_row "ERROR|profile.json|invalid (see log)"
no_row_like "no machine match"

# C12 bad arguments
case_run c12-bad-arg 1 fix_nodp --bogus
has_row "ERROR|aitools config|bad arguments"

# --- Installer Step 3/5 helpers (aitools-install.sh/.ps1 "install log helpers" block) ---
# The full installer cannot run here (incident #89); its helper block is extracted
# and run against the real writer under the isolated HOME.
INST_SH="$REPO/scripts/aitools-install.sh"
INST_PS="$REPO/scripts/aitools-install.ps1"
cat > "$WORK/inst-harness.sh" <<'HARNESS'
set -euo pipefail
repo="$1"; mode="$2"; shift 2
source "$repo/scripts/aitools-lib.sh"
logging_init "aitools-install"
LOG_JSONL="$LOG_DIR/deploy.jsonl"; RUN_ID="test01"; HOST_NAME="testhost"; OS_NAME="Darwin"
block=$(perl -0777 -ne 'print $1 if /^# --- BEGIN install log helpers[^\n]*\n(.*?)^# --- END install log helpers ---/ms' "$repo/scripts/aitools-install.sh")
if [ -z "$block" ]; then printf 'no helper block\n'; exit 3; fi
eval "$block"
case "$mode" in
    abs) absolute_repos_path "$1"; printf '\n' ;;
    run) run_config_writer "$repo/scripts/setup-user-config.sh" "$@"
         printf 'COUNTS errors=%s warnings=%s\n' "$ERRORS" "$WARNINGS" ;;
esac
HARNESS
cat > "$WORK/inst-harness.ps1" <<'HARNESS'
param([string]$Repo, [string]$Mode, [string]$ReposPath = "", [string]$RepoPath = "")
. (Join-Path $Repo "scripts/aitools-lib.ps1")
Initialize-Logging "aitools-install"
$logJsonl = Join-Path $logDir "deploy.jsonl"; $runId = "test01"; $hostName = "testhost"; $osName = "Windows"
$text = [IO.File]::ReadAllText((Join-Path $Repo "scripts/aitools-install.ps1"))
$m = [regex]::Match($text, '(?ms)^# --- BEGIN install log helpers[^\n]*\n(.*?)^# --- END install log helpers ---')
if (-not $m.Success) { Write-Output "no helper block"; exit 3 }
Invoke-Expression $m.Groups[1].Value
if ($Mode -eq "abs") { Write-Output (Get-AbsoluteReposPath $ReposPath); exit 0 }
Invoke-ConfigWriter (Join-Path $Repo "scripts/setup-user-config.ps1") @{ ReposPath = $ReposPath; RepoPath = $RepoPath }
Write-Output "COUNTS errors=$($script:errors) warnings=$($script:warnings)"
HARNESS

# inst_run IMPL MODE ARGS... -- run the extracted helpers; output in $WORK/inst.out
inst_run() {
    local impl="$1"; shift
    RC=0
    : > "$H/summary.txt"
    if [ "$impl" = "bash" ]; then
        (cd "$H" && env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac \
            "$BASH_BIN" "$WORK/inst-harness.sh" "$REPO" "$@") > "$WORK/inst.out" 2>&1 || RC=$?
    else
        local mode="$1"; shift
        (cd "$H" && env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac AITOOLS_PROFILE_TEST_ANY_OS=1 \
            pwsh -NoProfile -File "$WORK/inst-harness.ps1" -Repo "$REPO" -Mode "$mode" "$@") > "$WORK/inst.out" 2>&1 || RC=$?
    fi
}
inst_counts() { perl -ne 'print "$1 $2" if /^COUNTS errors=(\d+) warnings=(\d+)/' "$WORK/inst.out"; }
jsonl_check() {  # jsonl_check IMPL -- every deploy.jsonl line is valid JSON; prints the writer's warn count
    local j="$H/.aitools/logs/deploy.jsonl"
    if perl -MJSON::PP -ne 'BEGIN { $n = 0; $s = 0 } $r = decode_json($_); $n++ if $r->{script} eq "setup-user-config" && $r->{level} eq "warn"; $s++ if $r->{script} eq "setup-user-config"; END { print "$s $n" }' "$j" > "$WORK/jsonl.res" 2> "$WORK/jsonl.err"; then
        ok "$1 step5: deploy.jsonl lines are valid JSON"
    else
        bad "$1 step5: deploy.jsonl has an invalid line"; sed 's/^/       /' "$WORK/jsonl.err"
    fi
}

IMPLS="bash"
if $USE_PS; then IMPLS="bash ps"; fi
for impl in $IMPLS; do
    CASE="$impl step3"
    if [ "$impl" = "bash" ]; then inst_run bash abs repos; else inst_run ps abs -ReposPath repos; fi
    got=$(perl -ne 'print if /\S/' "$WORK/inst.out")
    want="$(cd "$H" && pwd -P)/repos"
    want_l="$H/repos"
    REL_GOT="$got"
    if [ "$got" = "$want" ] || [ "$got" = "$want_l" ]; then ok "$impl step3: relative 'repos' -> $got"
    else bad "$impl step3: relative 'repos' -> '$got', want $want_l"; fi
    if [ "$impl" = "bash" ]; then inst_run bash abs /abs/repos; else inst_run ps abs -ReposPath /abs/repos; fi
    got=$(perl -ne 'print if /\S/' "$WORK/inst.out")
    if [ "$got" = "/abs/repos" ]; then ok "$impl step3: absolute path unchanged"; else bad "$impl step3: absolute -> '$got'"; fi

    # Step 5 relays the writer: its lines reach deploy.jsonl, its warnings are counted
    # (C13 fixture: an unregistered profile warns), and the relative-path regression
    # is gone (Step 3's absolute path is accepted and config.json is written)
    fix_unreg
    rm -f "$CFG"
    REL_ABS="$REL_GOT"  # Step 3's answer for the relative 'repos'
    if [ "$impl" = "bash" ]; then inst_run bash run --repos-path "$REL_ABS" --repo-path "$H/repos/aitools"
    else inst_run ps run -ReposPath "$REL_ABS" -RepoPath "$H/repos/aitools"; fi
    counts=$(inst_counts)
    if [ "$RC" -eq 0 ] && [ -s "$CFG" ]; then ok "$impl step5: config.json written"; else bad "$impl step5: rc=$RC, config missing"; sed 's/^/       /' "$WORK/inst.out"; fi
    jsonl_check "$impl"
    read -r jl_all jl_warn < "$WORK/jsonl.res" || true  # empty result = 0 0, reported below
    if [ "${jl_all:-0}" -gt 0 ]; then ok "$impl step5: writer lines in deploy.jsonl ($jl_all)"; else bad "$impl step5: no writer lines in deploy.jsonl"; fi
    if [ "${counts#* }" = "${jl_warn:-x}" ] && [ "${jl_warn:-0}" -gt 0 ]; then ok "$impl step5: writer warnings counted (${counts#* })"
    else bad "$impl step5: counts '$counts', writer warn lines ${jl_warn:-none}"; sed 's/^/       /' "$WORK/inst.out"; fi
    if grep -q '\[setup-user-config\] \[warn\]' "$WORK/inst.out"; then ok "$impl step5: writer lines shown on the console"; else bad "$impl step5: writer lines not shown"; fi

    # A failing writer (relative path reaching it) is one installer error
    reset_home
    if [ "$impl" = "bash" ]; then inst_run bash run --repos-path repos --repo-path "$H/repos/aitools"
    else inst_run ps run -ReposPath repos -RepoPath "$H/repos/aitools"; fi
    counts=$(inst_counts)
    if [ "${counts% *}" = "1" ]; then ok "$impl step5: failed writer = 1 error"; else bad "$impl step5: failed writer counts '$counts'"; sed 's/^/       /' "$WORK/inst.out"; fi
    if grep -qxF "ERROR|aitools config|bad arguments" "$H/summary.txt"; then ok "$impl step5: writer ERROR row kept"; else bad "$impl step5: no writer ERROR row"; fi
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
