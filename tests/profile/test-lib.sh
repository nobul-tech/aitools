#!/usr/bin/env bash
# test-lib.sh -- tests for the aitools-lib profile wrappers (bash and PowerShell):
# resolve_user_repo_path / Resolve-UserRepoPath, resolve_machine_profile /
# Resolve-MachineProfile, tool_exception_get / Get-ToolException,
# tool_exception_record / Set-ToolException.
#
# Each case sources the lib in a fresh shell with an isolated HOME, calls one
# wrapper, and prints its return code, globals, WARNINGS/ERRORS counters and the
# summary rows; the bash and PowerShell results must match the expectation.
# Platform: macOS/Linux (pwsh runs with AITOOLS_PROFILE_TEST_ANY_OS=1). Safe to re-run.
# Usage: bash tests/profile/test-lib.sh [--bash-only]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

FIX_KIND=""
fixture() {  # fixture with-id|hostname-only|none
    FIX_KIND="$1"
    rm -rf "$H"; mkdir -p "$H/repos" "$H/.aitools"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
    [ "$1" = "none" ] && return 0
    mkdir -p "$DP"
    local idline=""
    if [ "$1" = "with-id" ]; then idline="\"id\": \"$ID_MAC\","; fi
    cat > "$DP/profile.json" <<JSON
{
  "version": 2,
  "identity": { "github": "nobul-jose", "name": "Jose", "company": "nobul-tech", "git": { "name": "Jose", "email": "jose@nobul.tech" } },
  "profiles": {
    "nobul-mac": { "machine": { $idline "hostname": "nobul-mac" } }
  }
}
JSON
    git -C "$DP" init -q
    git -C "$DP" config user.name Test
    git -C "$DP" config user.email test@example.com
    git -C "$DP" add profile.json
    git -C "$DP" commit -q -m init
}

# Bash driver: source the lib, run one call, print the results
cat > "$WORK/drive.sh" <<'DRIVE'
set -euo pipefail
source "$REPO/scripts/aitools-lib.sh"
logging_init "test-lib"
rc=0
case "$CALL" in
    urp)  resolve_user_repo_path || rc=$? ;;
    rmp)  resolve_machine_profile || rc=$? ;;
    eget) tool_exception_get go || rc=$? ;;
    eset) tool_exception_record go pkg-installer /usr/local/bin/go 1.22.5 || rc=$? ;;
esac
printf 'rc=%s\n' "$rc"
case "$CALL" in
    urp)  printf 'path=%s via=%s\n' "$USER_REPO_PATH" "$USER_REPO_VIA" ;;
    rmp)  printf 'alias=%s via=%s company=%s name=%s\n' "$MACHINE_ALIAS" "$MACHINE_VIA" "$PROFILE_COMPANY" "$PROFILE_NAME" ;;
    eget) printf 'found=%s method=%s path=%s\n' "$TOOL_EXC_FOUND" "$TOOL_EXC_METHOD" "$TOOL_EXC_PATH" ;;
    eset) printf 'pushed=%s\n' "$TOOL_EXC_PUSHED" ;;
esac
printf 'warnings=%s errors=%s\n' "$WARNINGS" "$ERRORS"
DRIVE
cat > "$WORK/drive.ps1" <<'DRIVE'
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-lib"
$rc = 0
switch ($env:CALL) {
    "urp"  { $rc = Resolve-UserRepoPath }
    "rmp"  { $rc = Resolve-MachineProfile }
    "eget" { $r = Get-ToolException "go"; $rc = if ($null -eq $r) { 1 } else { 0 } }
    "eset" { $rc = Set-ToolException "go" "pkg-installer" "/usr/local/bin/go" "1.22.5" }
}
"rc=$rc"
switch ($env:CALL) {
    "urp"  { "path=$($script:UserRepoPath) via=$($script:UserRepoVia)" }
    "rmp"  { "alias=$($script:MachineAlias) via=$($script:MachineVia) company=$($script:ProfileCompany) name=$($script:ProfileName)" }
    "eget" { $f = if ($r -and $r.Found) { "true" } else { "false" }; $m = if ($r) { $r.Method } else { "" }; $p = if ($r) { $r.Path } else { "" }; "found=$f method=$m path=$p" }
    "eset" { $pu = if ($script:ToolExcPushed) { "true" } else { "false" }; "pushed=$pu" }
}
"warnings=$($script:warnings) errors=$($script:errors)"
DRIVE

# run_case NAME CALL EXPECTED-OUTPUT EXPECTED-SUMMARY
run_case() {
    local name="$1" call="$2" want="$3" wsum="$4" impl got
    for impl in bash ps; do
        if [ "$impl" = "ps" ] && ! $USE_PS; then continue; fi
        : > "$H/summary.txt"
        if [ "$impl" = "bash" ]; then
            got=$(env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" REPO="$REPO" CALL="$call" \
                AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac \
                "$BASH_BIN" "$WORK/drive.sh" 2>/dev/null) || got="driver failed: $?"  # stderr: console log lines
            got=$(printf '%s\n' "$got" | grep -E '^(rc|path|alias|found|pushed|warnings)=' || true)  # only the driver's result lines (log lines also reach stdout)
        else
            got=$(env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_SUMMARY_FILE="$H/summary.txt" REPO="$REPO" CALL="$call" \
                AITOOLS_PROFILE_TEST_MACHINE_ID="$ID_MAC" AITOOLS_PROFILE_TEST_HOSTNAME=nobul-mac AITOOLS_PROFILE_TEST_ANY_OS=1 \
                pwsh -NoProfile -File "$WORK/drive.ps1" 2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g') || got="driver failed: $?"  # Write-Host console lines dropped by the grep below
            got=$(printf '%s\n' "$got" | grep -E '^(rc|path|alias|found|pushed|warnings)=' || true)  # only the driver's result lines
        fi
        if [ "$got" = "$want" ]; then ok "$name ($impl): result"
        else bad "$name ($impl): got"; printf '%s\n' "$got" | sed 's/^/         /'; printf '       want\n'; printf '%s\n' "$want" | sed 's/^/         /'; fi
        local sum; sum=$(cat "$H/summary.txt")
        if [ "$sum" = "$wsum" ]; then ok "$name ($impl): summary rows"
        else bad "$name ($impl): summary '$sum', want '$wsum'"; fi
        if [ "$call" = "eset" ]; then fixture "$FIX_KIND"; fi   # state changed: rebuild for the next implementation
    done
}

printf 'aitools-lib profile wrapper tests (pwsh: %s)\n' "$USE_PS"

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

fixture with-id
run_case eget-none eget "rc=0
found=false method= path=
warnings=0 errors=0" ""

fixture none
run_case eget-unavailable eget "rc=1
found=false method= path=
warnings=1 errors=0" ""

fixture with-id
run_case eset-written eset "rc=0
pushed=false
warnings=1 errors=0" "ACTION||run git push in $DP"

fixture hostname-only
run_case eset-refused eset "rc=3
pushed=false
warnings=1 errors=0" "ACTION||run aitools user init to remember tool choices"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
