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

ID_MAC="3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"        # as macOS reports it (upper case)
KEY_MAC="3d4df2a5-7d91-5af9-9944-4feebaae3cf5"       # the profiles key (lower-cased id)
H="$WORK/home"
DP="$H/repos/aitools-nobul-jose"
CFG="$H/.aitools/config.json"
CASE_ENV=""

# write_profile MAC_KEY MAC_ALIAS_LINE MAC_ID MAC_HOST -- profile.json, revision 2.2
# shape: this machine's profile under MAC_KEY, plus "laptop", an unclaimed 2.1 entry
# (alias-keyed, no machine.id). MAC_ALIAS_LINE is the entry's "alias" line ("" = none);
# MAC_ID "" = no machine.id.
write_profile() {
    local key="$1" alias_line="$2" id="$3" host="$4" id_line=""
    if [ -n "$id" ]; then id_line="\"id\": \"$id\","; fi
    mkdir -p "$DP"
    cat > "$DP/profile.json" <<JSON
{
  "version": 2,
  "meta": { "schemaRevision": "2.2" },
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
    "$key": {
      $alias_line
      "machine": {
        $id_line
        "hostname": "$host"
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
# profile_with_id -- this machine registered under its id (revision 2.2)
profile_with_id() { write_profile "$KEY_MAC" '"alias": "nobul-mac",' "$KEY_MAC" nobul-mac; }
# profile_legacy -- the same machine, still keyed by alias (revision 2.1): the
# resolver matches it by machine.id and advises migrate
profile_legacy() { write_profile nobul-mac "" "$ID_MAC" nobul-mac; }

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
            --machine-id)     PS_ARGS+=(-MachineId "$2"); shift 2 ;;
            --machine-alias)  PS_ARGS+=(-MachineAlias "$2"); shift 2 ;;
            --no-machine)     PS_ARGS+=(-NoMachine); shift ;;
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
        cp "$WORK/out.txt" "$WORK/$name.ps.out"
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
no_json() {  # no_json PERL-REGEX -- the bash-written config does not match
    if perl -0777 -ne 'BEGIN { $r = shift @ARGV } exit(/$r/s ? 1 : 0)' "$1" "$OUTJ"; then ok "$CASE: config has no /$1/"
    else bad "$CASE: config has /$1/"; sed 's/^/       /' "$OUTJ"; fi
}
rows_n() {  # rows_n N PREFIX -- the bash summary has exactly N rows starting with PREFIX
    local n
    n=$(grep -c "^$2" "$SUMM") || n=0  # grep -c exits 1 on zero matches; the count is still printed
    if [ "$n" -eq "$1" ]; then ok "$CASE: $1 row(s) $2"; else bad "$CASE: $n row(s) $2, want $1"; sed 's/^/       /' "$SUMM"; fi
}
out_has() {  # out_has TEXT -- each writer's console output (bash, and pwsh when run) contains TEXT
    local impl
    for impl in bash ps; do
        if [ "$impl" = "ps" ] && ! $USE_PS; then continue; fi
        if grep -qF "$1" "$WORK/$CASE.$impl.out"; then ok "$CASE: $impl output has '$1'"
        else bad "$CASE: $impl output lacks '$1'"; sed 's/^/       /' "$WORK/$CASE.$impl.out"; fi
    done
}
log_has() {  # log_has TEXT -- deploy.log (of the last writer run) contains TEXT
    if grep -qF "$1" "$H/.aitools/logs/deploy.log"; then ok "$CASE: deploy.log has '$1'"
    else bad "$CASE: deploy.log lacks '$1'"; fi
}

printf 'setup-user-config tests (pwsh parity: %s)\n' "$USE_PS"
BOOT=(--repos-path "$H/repos" --repo-path "$H/repos/aitools")

# C1 fresh machine with a dotprofile: created, derived values, meta
fix_fresh() { reset_home; profile_with_id; }
case_run c1-fresh 0 fix_fresh "${BOOT[@]}" --github-user nobul-jose
has_row "OK|aitools config|created"
has_json '\A\{\n  "version": 3,\n  "reposPath": "[^"]+\/repos",\n  "repoPath": "[^"]+\/repos\/aitools",\n  "googleDrives": \[\],\n  "githubUser": "nobul-jose",\n  "userRepoPath": "[^"]+\/aitools-nobul-jose",\n  "machineId": "'"$KEY_MAC"'",\n  "machineAlias": "nobul-mac",\n  "meta": \{\n    "intent": \{\n      "purpose": "Per-machine pointers'
has_json '"writer": "setup-user-config",\n    "derivedFrom": "profile.json"\n  \}\n\}\n\z'
rows_n 0 "ACTION"

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
has_row "DETAIL|aitools config|machineId updated"
has_json '"custom": \{\n    "keep": true\n  \},\n  "googleDrives": \[\n    \{\n      "path": "\/gd"'
has_json '"machineAlias": "nobul-mac",\n  "githubUser": "nobul-jose",\n  "machineId": "'"$KEY_MAC"'",\n  "meta"'
if ls "$H/.aitools/" | grep -q 'config.json.bak'; then ok "c3-upgrade: backup written"; else bad "c3-upgrade: no backup"; fi

# C4 corrupt config: rebuilt with salvaged keys, WARN
fix_corrupt() {
    reset_home; profile_with_id
    printf '{ "reposPath": "%s", "repoPath": "%s", "machineAlias": "laptop", oops\n' "$H/repos" "$H/repos/aitools" > "$CFG"
}
case_run c4-corrupt 0 fix_corrupt
has_row "WARN|aitools config|rebuilt (was invalid)"
has_json '\A\{\n  "reposPath": "[^"]+",\n  "repoPath": "[^"]+",\n  "machineAlias": "nobul-mac",\n  "version": 3'
has_json '"machineId": "'"$KEY_MAC"'"'

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
KEY_OTHER="aaaaaaaa-1111-2222-3333-444444444444"
fix_nomatch() {
    fix_v2
    write_profile "$KEY_OTHER" '"alias": "nobul-mac",' "$KEY_OTHER" elsewhere
}
case_run c7-no-match 1 fix_nomatch
has_row "ERROR|machine profile|no machine match"
has_row "ACTION||Run: aitools user init (profiles: nobul-mac, laptop)"
rows_n 1 "ACTION"
has_json '"machineAlias": "new-mac"'
no_json '"machineId"'

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

# C10 explicit choice (user init's): --machine-id selects this machine's profile by
# its key (any case); machineId + display machineAlias are saved
case_run c10-machine-id 0 fix_v2 --machine-id "$ID_MAC"
has_row "OK|aitools config|updated"
out_has "machineAlias=nobul-mac via=override"
has_json '"machineAlias": "nobul-mac"'
has_json '"machineId": "'"$KEY_MAC"'"'
# C10b the deprecated --machine-alias is still accepted for one release (detail line);
# the chosen 2.1 profile has no machine.id: advisory, one ACTION, the row stays OK
case_run c10b-deprecated-alias 0 fix_v2 --machine-alias laptop
has_json '"machineAlias": "laptop"'
no_json '"machineId"'
has_row "OK|aitools config|updated"
has_row "ACTION||Run: aitools user init (registers this machine)"
rows_n 1 "ACTION"
log_has "[detail] deprecated flag:"
# C10c both flags: bad arguments
case_run c10c-both-flags 1 fix_v2 --machine-id "$ID_MAC" --machine-alias nobul-mac
has_row "ERROR|aitools config|bad arguments"
# C10d an unknown --machine-id: no machine match, nothing derived is saved
case_run c10d-unknown-id 1 fix_v2 --machine-id "$KEY_OTHER"
has_row "ERROR|machine profile|no machine match"
has_json '"machineAlias": "new-mac"'

# C11 AITOOLS_USER_REPO_PATH: used for the run, not saved
fix_env() { reset_home; profile_with_id; cp -R "$DP" "$H/envdp"; fix_v2_cfg_only; }
fix_v2_cfg_only() { printf '{ "version": 3, "reposPath": "%s", "repoPath": "%s" }\n' "$H/repos" "$H/repos/aitools" > "$CFG"; }
CASE_ENV="AITOOLS_USER_REPO_PATH=$H/envdp"
case_run c11-env 0 fix_env
CASE_ENV=""
if grep -q '"userRepoPath"' "$OUTJ"; then bad "c11-env: userRepoPath saved from the env override"; else ok "c11-env: userRepoPath not saved"; fi
has_json '"machineAlias": "nobul-mac"'

# C13 cached alias names a 2.1 profile without machine.id (not registered): written;
# the advice is one ACTION (with its counted warning), the config row stays OK
fix_unreg() {
    fix_v2
    write_profile nobul-mac "" "" nobul-mac
    perl -pi -e 's/"new-mac"/"nobul-mac"/' "$CFG"
}
case_run c13-unregistered 0 fix_unreg
has_row "OK|aitools config|updated"
has_row "ACTION||Run: aitools user init (registers this machine)"
rows_n 1 "ACTION"
no_json '"machineId"'
out_has "COMPLETED with 1 warning(s)"

# C17 legacy 2.1 profile (alias-keyed, matched by machine.id): the resolver's
# "run: aitools-profile migrate" advice is ONE ACTION naming the user-facing command
# (aitools user init re-keys), not a WARN row; no machineId (not an id-keyed profile)
fix_legacy() { reset_home; profile_legacy; }
case_run c17-legacy-migrate 0 fix_legacy "${BOOT[@]}"
has_row "OK|aitools config|created"
has_row "ACTION||Run: aitools user init (re-keys machine profiles by machine id)"
rows_n 1 "ACTION"
rows_n 0 "WARN"
has_json '"machineAlias": "nobul-mac"'
no_json '"machineId"'
log_has "run: aitools-profile migrate"

# C18 a real problem (stored hostname differs: renamed, or a clone sharing the id):
# a counted warning, the row becomes WARN; plus the one ACTION
fix_clone() { reset_home; write_profile "$KEY_MAC" '"alias": "nobul-mac",' "$KEY_MAC" other-host; }
case_run c18-real-warning 0 fix_clone "${BOOT[@]}"
has_row "WARN|aitools config|created"
has_row "ACTION||Run: aitools user init (updates this machine's profile)"
rows_n 1 "ACTION"
out_has "COMPLETED with 2 warning(s)"
has_json '"machineId": "'"$KEY_MAC"'"'

# C19 this machine's id cannot be detected: the cached machineId selects the profile
# (via=config) and is kept; the undetectable id is a real warning
fix_noid() { fix_fresh; cp "$WORK/c1-fresh.bash.json" "$CFG"; }
CASE_ENV="AITOOLS_PROFILE_TEST_MACHINE_ID=none"
case_run c19-id-unavailable 0 fix_noid
CASE_ENV=""
has_row "WARN|aitools config|verified"
if cmp -s "$OUTJ" "$WORK/c1-fresh.bash.json"; then ok "c19-id-unavailable: machineId kept, file unchanged"; else bad "c19-id-unavailable: file changed"; fi
log_has "machineAlias=nobul-mac via=config"

# C20 a cached machineId that the match does not confirm (2.1 profile matched by
# machine.id) is removed, so the machineAlias cache (resolver step 4L) stays usable
fix_stale_mid() {
    reset_home; profile_legacy
    printf '{ "version": 3, "reposPath": "%s", "repoPath": "%s", "machineId": "%s", "machineAlias": "nobul-mac" }\n' \
        "$H/repos" "$H/repos/aitools" "$KEY_OTHER" > "$CFG"
}
case_run c20-stale-machine-id 0 fix_stale_mid
has_row "OK|aitools config|updated"
has_row "DETAIL|aitools config|machineId updated"
no_json '"machineId"'
has_json '"machineAlias": "nobul-mac"'
out_has "cached machineId \"$KEY_OTHER\" removed"

# C21 machineId is salvaged from a corrupt config (the id is undetectable, so no
# machineId is derived: the salvaged value is the one written)
fix_corrupt_mid() {
    reset_home; profile_with_id
    printf '{ "reposPath": "%s", "repoPath": "%s", "machineId": "%s", oops\n' "$H/repos" "$H/repos/aitools" "$KEY_MAC" > "$CFG"
}
CASE_ENV="AITOOLS_PROFILE_TEST_MACHINE_ID=none"
case_run c21-salvage-machine-id 0 fix_corrupt_mid
CASE_ENV=""
has_row "WARN|aitools config|rebuilt (was invalid)"
has_json '"machineId": "'"$KEY_MAC"'"'
out_has "Recovered machineId from the invalid config"

# C22 --no-machine (user init left this machine unregistered): the caller owns machine
# registration. No profile matches this machine: no ERROR, no ACTION, exit 0; every
# other field is written; machineId / machineAlias are kept exactly as they were
KEY_KEEP="bbbbbbbb-5555-6666-7777-888888888888"
fix_nm_nomatch() {
    fix_nomatch
    perl -pi -e 's/"machineAlias": "new-mac"/"machineAlias": "new-mac",\n  "machineId": "'"$KEY_KEEP"'"/' "$CFG"
}
case_run c22-no-machine-unmatched 0 fix_nm_nomatch --no-machine --github-user nobul-jose
has_row "OK|aitools config|updated"
rows_n 0 "ERROR"
rows_n 0 "ACTION"
has_json '"machineAlias": "new-mac"'
has_json '"machineId": "'"$KEY_KEEP"'"'
has_json '"githubUser": "nobul-jose"'
has_json '"version": 3'
has_json '"userRepoPath": "[^"]+\/aitools-nobul-jose"'
out_has "COMPLETED successfully"
out_has "machine registration is left to the caller"
log_has "no profile matches this machine"
log_has ": left to the caller)"  # "(--no-machine: ..." (bash) / "(-NoMachine: ..." (PowerShell)
# C22b the same fixture without the flag still reports it (C7 behaviour unchanged)
case_run c22b-unmatched-without-flag 1 fix_nm_nomatch --github-user nobul-jose
has_row "ERROR|machine profile|no machine match"
rows_n 1 "ACTION"
# C22c profile.json with no machine profiles: unregistered too, nothing reported
fix_nm_empty() {
    fix_v2
    printf '{ "version": 2, "meta": { "schemaRevision": "2.2" }, "identity": { "github": "nobul-jose" }, "profiles": {} }\n' > "$DP/profile.json"
}
case_run c22c-no-machine-no-profiles 0 fix_nm_empty --no-machine
rows_n 0 "ERROR"
rows_n 0 "ACTION"
has_json '"machineAlias": "new-mac"'
# C22d unregistered 2.1 profile (C13 fixture): the registration ACTION is the caller's
case_run c22d-no-machine-unregistered 0 fix_unreg --no-machine
has_row "OK|aitools config|updated"
rows_n 0 "ACTION"
rows_n 0 "WARN"
no_json '"machineId"'
has_json '"machineAlias": "nobul-mac"'
out_has "COMPLETED successfully"
# C22e a cached machineId the match would remove (C20) is kept with --no-machine
case_run c22e-no-machine-keeps-id 0 fix_stale_mid --no-machine
rows_n 0 "ACTION"
no_row_like "machineId updated"
has_json '"machineId": "'"$KEY_OTHER"'"'
has_json '"machineAlias": "nobul-mac"'
# C22f a legacy alias-keyed profile (C17): no migrate ACTION, machineAlias not written
case_run c22f-no-machine-legacy 0 fix_legacy "${BOOT[@]}" --no-machine
has_row "OK|aitools config|created"
rows_n 0 "ACTION"
no_json '"machineAlias"'
no_json '"machineId"'
# C22g other derivation errors are still reported: an invalid profile.json
fix_nm_badprofile() { fix_v2; printf '{ "version": 2, ' > "$DP/profile.json"; }
case_run c22g-no-machine-bad-profile 1 fix_nm_badprofile --no-machine
has_row "ERROR|profile.json|invalid (see log)"
# C22h --no-machine with a machine choice: bad arguments, nothing written
case_run c22h-no-machine-and-id 1 fix_v2 --no-machine --machine-id "$ID_MAC"
has_row "ERROR|aitools config|bad arguments"
rows_n 1 "ERROR"
if grep -q '"version": 2' "$OUTJ"; then ok "c22h-no-machine-and-id: config untouched"; else bad "c22h-no-machine-and-id: config changed"; fi
case_run c22i-no-machine-and-alias 1 fix_v2 --machine-alias laptop --no-machine
has_row "ERROR|aitools config|bad arguments"
# C22k an ambiguous match (this machine.id on two profiles) is still an error
fix_nm_dupid() {
    fix_v2
    printf '{ "version": 2, "meta": { "schemaRevision": "2.2" }, "identity": { "github": "nobul-jose" }, "profiles": { "a": { "machine": { "id": "%s", "hostname": "nobul-mac" } }, "b": { "machine": { "id": "%s", "hostname": "nobul-mac" } } } }\n' "$ID_MAC" "$ID_MAC" > "$DP/profile.json"
}
case_run c22k-no-machine-ambiguous 1 fix_nm_dupid --no-machine
has_row "ERROR|machine profile|no machine match"
# C22l --no-machine with --dry-run: nothing written, no machine rows
case_run c22l-no-machine-dry-run 0 fix_nm_nomatch --no-machine --dry-run
has_row "OK|aitools config|dry-run: would update"
rows_n 0 "ERROR"
rows_n 0 "ACTION"
if grep -q '"version": 2' "$OUTJ"; then ok "c22l-no-machine-dry-run: config untouched"; else bad "c22l-no-machine-dry-run: config changed"; fi

# C22j the help text names the flag
CASE="c22j-help"
reset_home
RC=0
env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" "$BASH_BIN" "$SH" --help > "$WORK/help.bash.out" 2>&1 || RC=$?
if [ "$RC" -eq 0 ] && grep -qF -- "--no-machine" "$WORK/help.bash.out"; then ok "c22j-help: bash --help names --no-machine"
else bad "c22j-help: bash --help (exit $RC) lacks --no-machine"; fi
if $USE_PS; then
    RC=0
    env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_PROFILE_TEST_ANY_OS=1 \
        pwsh -NoProfile -File "$PS" -Help > "$WORK/help.ps.out" 2>&1 || RC=$?
    if [ "$RC" -eq 0 ] && grep -qF -- "-NoMachine" "$WORK/help.ps.out"; then
        ok "c22j-help: pwsh -Help names -NoMachine"
    else bad "c22j-help: pwsh -Help lacks -NoMachine"; fi
fi

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
    jsonl) jsonl_write "2026-01-01T00:00:00Z" "t" "info" "$(printf 'q"b\\t\tn\nc\001e\033[31mr\rz')" ;;
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
if ($Mode -eq "jsonl") { Write-JsonlRecord "2026-01-01T00:00:00Z" "t" "info" "q`"b\t`tn`nc$([char]1)e$([char]27)[31mr`rz"; exit 0 }
Invoke-ConfigWriter (Join-Path $Repo "scripts/setup-user-config.ps1") @{ ReposPath = $ReposPath; RepoPath = $RepoPath }
Write-Output "COUNTS errors=$($script:errors) warnings=$($script:warnings)"
HARNESS

# inst_run IMPL MODE ARGS... -- run the extracted helpers; output in $WORK/inst.out
inst_run() {
    local impl="$1"; shift
    RC=0
    : > "$H/summary.txt"
    if [ "$impl" = "bash" ]; then
        (cd "${INST_CWD:-$H}" && env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac \
            "$BASH_BIN" "$WORK/inst-harness.sh" "$REPO" "$@") > "$WORK/inst.out" 2>&1 || RC=$?
    else
        local mode="$1"; shift
        (cd "${INST_CWD:-$H}" && env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" \
            AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac AITOOLS_PROFILE_TEST_ANY_OS=1 \
            pwsh -NoProfile -File "$WORK/inst-harness.ps1" -Repo "$REPO" -Mode "$mode" "$@") > "$WORK/inst.out" 2>&1 || RC=$?
    fi
}
inst_counts() { perl -ne 'print "$1 $2" if /^COUNTS errors=(\d+) warnings=(\d+)/' "$WORK/inst.out"; }
jsonl_check() {  # jsonl_check IMPL -- every deploy.jsonl line is valid JSON; prints the writer's warn count
    local j="$H/.aitools/logs/deploy.jsonl"
    if perl -MJSON::PP -ne 'BEGIN { $n = 0; $s = 0 } $r = decode_json($_); $n++ if $r->{script} eq "setup-user-config" && $r->{level} eq "warn" && $r->{msg} !~ /^(COMPLETED|FAILED) with /; $s++ if $r->{script} eq "setup-user-config"; $f = $1 if $r->{script} eq "setup-user-config" && $r->{msg} =~ /^COMPLETED with (\d+) warning/; END { print "$s $n ", (defined $f ? $f : 0) }' "$j" > "$WORK/jsonl.res" 2> "$WORK/jsonl.err"; then
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
    # normalised: ../ collapsed, and a run from / gives no double slash
    if [ "$impl" = "bash" ]; then inst_run bash abs ../home/repos; else inst_run ps abs -ReposPath ../home/repos; fi
    got=$(perl -ne 'print if /\S/' "$WORK/inst.out")
    if [ "$got" = "$want" ] || [ "$got" = "$want_l" ]; then ok "$impl step3: '../home/repos' normalised"; else bad "$impl step3: '../home/repos' -> '$got'"; fi
    INST_CWD="/"
    if [ "$impl" = "bash" ]; then inst_run bash abs tmp; else inst_run ps abs -ReposPath tmp; fi
    INST_CWD=""
    got=$(perl -ne 'print if /\S/' "$WORK/inst.out")
    if [ "$got" = "/tmp" ]; then ok "$impl step3: relative from / -> /tmp"; else bad "$impl step3: relative from / -> '$got'"; fi
    # JSONL records stay valid with quotes, backslashes and control characters
    mkdir -p "$H/.aitools/logs"
    rm -f "$H/.aitools/logs/deploy.jsonl"
    inst_run "$impl" jsonl
    if perl -MJSON::PP -ne 'decode_json($_)' "$H/.aitools/logs/deploy.jsonl" 2> "$WORK/jsonl.err"; then ok "$impl jsonl: control characters give valid JSON"
    else bad "$impl jsonl: invalid record"; sed 's/^/       /' "$H/.aitools/logs/deploy.jsonl" "$WORK/jsonl.err"; fi

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
    read -r jl_all jl_warn jl_footer < "$WORK/jsonl.res" || true  # empty result = unset, reported below
    if [ "${jl_all:-0}" -gt 0 ]; then ok "$impl step5: writer lines in deploy.jsonl ($jl_all)"; else bad "$impl step5: no writer lines in deploy.jsonl"; fi
    # the installer's count = the writer's own N (its footer) = its warn lines minus the footer
    if [ "${counts#* }" = "${jl_footer:-x}" ] && [ "${jl_warn:-x}" = "${jl_footer:-y}" ] && [ "${jl_footer:-0}" -gt 0 ]; then ok "$impl step5: writer warnings counted (${counts#* })"
    else bad "$impl step5: counts '$counts', writer warn lines ${jl_warn:-none}, writer footer N ${jl_footer:-none}"; sed 's/^/       /' "$WORK/inst.out"; fi
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
