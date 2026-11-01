#!/usr/bin/env bash
# test-profile.sh -- unit and parity tests for scripts/aitools-profile.sh and .ps1
# (and the JSON engines scripts/aitools-json.pl and .ps1)
#
# Every case runs the resolver of this platform with injected machine ids and
# hostnames, in an isolated HOME, and asserts expected values and exit codes.
#
# Platform targeting (plans/ci-platform-targeting.md): each resolver runs only
# where its OS guard allows, with the guard intact. macOS/Linux run
# aitools-profile.sh (and the perl JSON engine); Windows (Git Bash) runs
# aitools-profile.ps1 (and aitools-json.ps1) with native pwsh: -NonInteractive,
# every path in Windows form (cygpath -m: the script, $WORK paths in arguments,
# environment values and fixture files), HOME and USERPROFILE both set, MSYS
# argument conversion off. The native spellings of the temp root in pwsh output
# are mapped back to the POSIX path (from_native), so one set of expectations
# serves both. Parity between the two resolvers (they must print byte-identical
# output and write byte-identical files) is checked against committed golden
# files in tests/profile/golden/profile-* (tests/lib/platform-lib.sh
# golden_match): the .sh run on macOS/Linux and the .ps1 run on Windows must
# both equal them. Invalid-JSON parser messages are cut after "is invalid JSON"
# (each engine words them differently); a written profile's own os and arch
# become <OS> and <ARCH>. AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux rewrites
# the golden files. Cases with no PowerShell partner (claude-code-web: Linux
# only, PowerShell never branches on the environment; help text; rev-m3-numbers,
# a perl-engine guarantee) have no golden file; POSIX permission cases (chmod)
# run on macOS/Linux only.
# Safe to re-run: an isolated HOME under a temp dir (removed on exit).
# Usage: bash tests/profile/test-profile.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: macOS/Linux always run only bash
#   AITOOLS_TEST_BASH=/bin/bash runs the resolver under another bash (e.g. macOS 3.2)

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 30' "$0"
    exit 0
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$REPO/tests/lib/platform-lib.sh"
SH="$REPO/scripts/aitools-profile.sh"
PS="$REPO/scripts/aitools-profile.ps1"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
LANG_RUN="$TEST_LANG"   # sh on macOS/Linux, ps1 on Windows
GOLDEN_DIR="$REPO/tests/profile/golden"
GOLDEN_TMP="$WORK"
PLATFORM_LINUX=false
if [ "$TEST_PLATFORM" = linux ]; then PLATFORM_LINUX=true; fi
NWORK="$(native_path "$WORK")"   # Windows form of $WORK (unchanged elsewhere)
NREPO="$(native_path "$REPO")"
# The os and arch values register writes for this machine (both resolvers):
# os darwin|linux|win32, arch x64|arm64
ARCH=$(uname -m); case "$ARCH" in x86_64|amd64) ARCH=x64 ;; arm64|aarch64) ARCH=arm64 ;; esac
case "$TEST_PLATFORM" in windows) OSNAME=win32 ;; linux) OSNAME=linux ;; *) OSNAME=darwin ;; esac

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { printf '  skip %s\n' "$1"; }

if [ "$LANG_RUN" = ps1 ] && ! command -v pwsh >/dev/null 2>&1; then
    printf '  FAIL pwsh is not on PATH: aitools-profile.ps1 cannot be tested on Windows\n'
    exit 1
fi

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
# to_native WORD -- WORD with every $WORK and $REPO in Windows form (arguments and
# VAR=value words handed to native pwsh); unchanged off Windows
to_native() {
    local s="$1"
    if [ "$TEST_PLATFORM" = windows ]; then s="${s//"$WORK"/$NWORK}"; s="${s//"$REPO"/$NREPO}"; fi
    printf '%s' "$s"
}

ID_MAC="3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
ID_OTHER="0B1C2D3E-0000-1111-2222-333344445555"

# fresh_home NAME -- isolated HOME with ~/repos and ~/.aitools; sets H, and HN (H
# as the resolver of this platform reads it: for paths inside fixture files)
fresh_home() {
    H="$WORK/$1/home"
    HN="$(to_native "$H")"
    mkdir -p "$H/repos" "$H/.aitools"
}

write_profile() {  # write_profile DIR (stdin = JSON)
    mkdir -p "$1"
    cat > "$1/profile.json"
}

base_profile() {
    cat <<'JSON'
{
  "version": 2,
  "identity": {
    "github": "nobul-jose",
    "email": "jose@nobul.tech",
    "name": "Jose",
    "company": "nobul-tech",
    "git": {
      "name": "Jose",
      "email": "jose@nobul.tech"
    }
  },
  "profiles": {
    "laptop": {
      "company": "Nobul",
      "machine": {
        "hostname": "Joses-MBP",
        "os": "darwin"
      }
    },
    "nobul-mac": {
      "machine": {
        "hostname": "nobul-mac.local",
        "os": "darwin"
      }
    },
    "workstation": {
      "name": "pepe",
      "machine": {
        "hostname": "NewcoPC",
        "hostnames": ["newco-pc"],
        "os": "win32"
      }
    }
  }
}
JSON
}

# run_impl OUTFILE ARGS... -- run the resolver of this platform in the isolated
# HOME: aitools-profile.sh (macOS/Linux) or aitools-profile.ps1 under native pwsh
# (Windows); sets RC. Environment for the case comes from CASE_ENV (KEY=VALUE
# words). On Windows the output and stderr pass through from_native.
run_impl() {
    local out="$1"; shift
    RC=0
    if [ "$LANG_RUN" = sh ]; then
        # shellcheck disable=SC2086  # CASE_ENV is a list of VAR=value words
        env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" $CASE_ENV "$BASH_BIN" "$SH" "$@" > "$out" 2>"$out.err" || RC=$?
    else
        local a nargs=() nenv hn
        for a in "$@"; do nargs+=("$(to_native "$a")"); done
        nenv="$(to_native "$CASE_ENV")"
        # The case HOME comes from H here, never from a saved HN: a block that
        # switches H and back (dc-host) left HN on the other home (CI run
        # 41265193554: exc-set-same .. exc-set-nopush ran against dc-host)
        hn="$(to_native "$H")"
        # shellcheck disable=SC2086  # nenv is a list of VAR=value words
        env HOME="$hn" USERPROFILE="$hn" AITOOLS_LOG_DIR="$hn/.aitools/logs" $nenv MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
            pwsh -NoProfile -NonInteractive -File "$(native_path "$PS")" ${nargs[@]+"${nargs[@]}"} > "$out" 2>"$out.err" || RC=$?
        from_native "$out"
        from_native "$out.err"
    fi
}

normalize() { perl -pe 's/( is invalid JSON).*/$1/' "$1"; }

# plat_norm FILE -- FILE with the os and arch values this machine writes into a
# profile ("os": "$OSNAME", "arch": "$ARCH") replaced by <OS> and <ARCH>
plat_norm() { PN_OS="$OSNAME" PN_ARCH="$ARCH" perl -pe 's/"os": "\Q$ENV{PN_OS}\E"/"os": "<OS>"/g; s/"arch": "\Q$ENV{PN_ARCH}\E"/"arch": "<ARCH>"/g' "$1"; }

# golden_check NAME GOLDEN FILE -- one check: FILE equals tests/profile/golden/GOLDEN
# (the .sh output on macOS/Linux and the .ps1 output on Windows share it)
golden_check() {
    if golden_match "$2" "$3"; then ok "$1: matches golden $2 (sh and ps1 share it)"
    else bad "$1: differs from golden $2"; fi
}

# case_run NAME EXPECTED_RC ARGS... -- run the resolver of this platform, check
# the exit code and (unless NO_PARITY=1) the output against its golden file.
# Leaves the output in $OUT for value assertions.
case_run() {
    local name="$1" want="$2"; shift 2
    CASE="$name"
    OUT="$WORK/$name.out"
    run_impl "$OUT" "$@"
    if [ "$RC" -eq "$want" ]; then ok "$name: $LANG_RUN exit $RC"
    else bad "$name: $LANG_RUN exit $RC, want $want"; sed 's/^/       /' "$OUT" "$OUT.err"; fi
    if [ "${NO_PARITY:-}" != "1" ]; then
        normalize "$OUT" > "$WORK/$name.norm"
        golden_check "$name" "profile-$name.out" "$WORK/$name.norm"
    fi
}

# expect KEY VALUE -- the first KEY<TAB> line in $OUT equals VALUE
expect() {
    local got
    got=$(perl -ne 'BEGIN { $k = shift @ARGV } if (/^\Q$k\E\t(.*)$/) { print $1; exit }' "$1" "$OUT")
    if [ "$got" = "$2" ]; then ok "$CASE: $1=$2"; else bad "$CASE: $1='$got', want '$2'"; fi
}
# expect_line PATTERN -- some line in $OUT matches the perl regex
expect_line() {
    if perl -ne 'BEGIN { $r = shift @ARGV } $f = 1 if /$r/; END { exit($f ? 0 : 1) }' "$1" "$OUT"; then ok "$CASE: line /$1/"
    else bad "$CASE: no line matches /$1/"; sed 's/^/       /' "$OUT"; fi
}
expect_no_line() {
    if perl -ne 'BEGIN { $r = shift @ARGV } $f = 1 if /$r/; END { exit($f ? 0 : 1) }' "$1" "$OUT"; then bad "$CASE: unexpected line /$1/"
    else ok "$CASE: no line /$1/"; fi
}

M=(--machine-id-value "$ID_MAC" --hostname-value nobul-mac)
CASE_ENV=""
printf 'aitools-profile tests (%s: aitools-profile.%s)\n' "$TEST_PLATFORM" "$LANG_RUN"

# --- Which dotprofile -------------------------------------------------------
fresh_home urp-convention
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run urp-convention 0 user-repo-path
expect path "$H/repos/aitools-nobul-jose"; expect via convention

fresh_home urp-scan
base_profile | write_profile "$H/repos/aitools-nobul-jose"
mkdir -p "$H/repos/aitools-empty"
case_run urp-scan 0 user-repo-path
expect via scan; expect_line '^warn\tgithubUser unknown -- used the only dotprofile'

fresh_home urp-scan-two
base_profile | write_profile "$H/repos/aitools-a"
base_profile | write_profile "$H/repos/aitools-b"
case_run urp-scan-two 1 user-repo-path
expect via none; expect_line '^warn\tgithubUser unknown and 2 aitools-\* repos'

fresh_home urp-none
printf '{ "githubUser": "someone" }\n' > "$H/.aitools/config.json"
case_run urp-none 1 user-repo-path
expect expected "$H/repos/aitools-someone"

fresh_home urp-config
base_profile | write_profile "$H/elsewhere/dp"
printf '{ "userRepoPath": "%s" }\n' "$HN/elsewhere/dp/" > "$H/.aitools/config.json"
case_run urp-config 0 user-repo-path
expect path "$H/elsewhere/dp"; expect via config

fresh_home urp-config-stale
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "userRepoPath": "%s", "githubUser": "nobul-jose" }\n' "$HN/gone" > "$H/.aitools/config.json"
case_run urp-config-stale 0 user-repo-path
expect via convention; expect_line '^warn\tconfig.json userRepoPath does not exist'

fresh_home urp-env
base_profile | write_profile "$H/envdp"
CASE_ENV="AITOOLS_USER_REPO_PATH=$H/envdp"
case_run urp-env 0 user-repo-path --user-repo-path "$H/nope"
expect via env
CASE_ENV="AITOOLS_USER_REPO_PATH=$H/missing"
case_run urp-env-missing 2 user-repo-path
expect_line '^error\tAITOOLS_USER_REPO_PATH does not exist'
CASE_ENV=""

fresh_home urp-arg
case_run urp-arg-missing 2 user-repo-path --user-repo-path "$H/nope"
expect_line '^error\t--user-repo-path does not exist'

fresh_home urp-plain
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run urp-plain 0 user-repo-path --plain
if [ "$(cat "$OUT")" = "$H/repos/aitools-nobul-jose" ]; then ok "urp-plain: path only"; else bad "urp-plain: got '$(cat "$OUT")'"; fi

fresh_home urp-corrupt-config
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": ' > "$H/.aitools/config.json"
case_run urp-corrupt-config 0 user-repo-path
expect via scan; expect_line '^warn\t.*config.json is invalid JSON'

# `~` in config.json paths expands to HOME in both resolvers (S3-M3-B8c parity finding)
fresh_home urp-tilde
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "userRepoPath": "~/repos/aitools-nobul-jose" }\n' > "$H/.aitools/config.json"
case_run urp-tilde 0 user-repo-path
expect via config; expect path "$H/repos/aitools-nobul-jose"
printf '{ "reposPath": "~/repos", "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run urp-tilde-repos 0 user-repo-path
expect via convention; expect path "$H/repos/aitools-nobul-jose"

# A UTF-16 config.json or profile.json is rejected by both, with one message
# (S3-M3-B8c parity finding: PowerShell used to decode it, perl could not)
fresh_home urp-utf16
base_profile | write_profile "$H/repos/aitools-nobul-jose"
perl -e 'use Encode; print "\xff\xfe", Encode::encode("UTF-16LE", qq({ "userRepoPath": "$ARGV[0]" }\n))' "$HN/repos/aitools-nobul-jose" > "$H/.aitools/config.json"
case_run urp-utf16 0 user-repo-path
expect via scan
expect_line '^warn\t.*/\.aitools/config\.json is UTF-16 encoded, not UTF-8 -- save it as UTF-8 -- resolving without it$'
perl -e 'use Encode; local $/; my $t = <STDIN>; print "\xff\xfe", Encode::encode("UTF-16LE", $t)' < "$H/repos/aitools-nobul-jose/profile.json" > "$H/u16.json"
case_run rm-utf16-profile 2 resolve "${M[@]}" --profile "$H/u16.json"
expect_line '^error\t.*/u16\.json is UTF-16 encoded, not UTF-8 -- save it as UTF-8$'

# --- Which machine profile ---------------------------------------------------
fresh_home rm-alias
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose", "machineAlias": "nobul-mac" }\n' > "$H/.aitools/config.json"
case_run rm-alias 0 resolve "${M[@]}"
expect alias nobul-mac; expect via alias; expect name Jose; expect company nobul-tech
expect machineId "$ID_MAC"; expect hostname nobul-mac
expect_line '^warn\tprofile "nobul-mac" has no machine.id'

fresh_home rm-hostname
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-hostname 0 resolve "${M[@]}"
expect alias nobul-mac; expect via hostname
expect_line '^warn\tmatched by hostname only'
expect_no_line 'has no machine.id'

case_run rm-hostname-alt 0 resolve --machine-id-value "$ID_OTHER" --hostname-value NEWCO-PC
expect alias workstation; expect name pepe; expect company nobul-tech

case_run rm-profile-company 0 resolve --machine-id-value "$ID_OTHER" --hostname-value joses-mbp
expect alias laptop; expect company Nobul; expect name Jose

case_run rm-none 2 resolve --machine-id-value "$ID_OTHER" --hostname-value some-other-host
expect alias ""; expect via none; expect company nobul-tech; expect name Jose
expect_line '^error\tno profile matches this machine \(machine.id 0B1C2D3E.*hostname some-other-host\)'

fresh_home rm-id
base_profile | perl -0pe "s/\"hostname\": \"nobul-mac.local\"/\"id\": \"$(printf '%s' "$ID_MAC" | tr 'A-Z' 'a-z')\",\n        \"hostname\": \"nobul-mac.local\"/" \
    | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose", "machineAlias": "laptop" }\n' > "$H/.aitools/config.json"
case_run rm-id 0 resolve "${M[@]}"
expect alias nobul-mac; expect via id
expect_line '^warn\tconfig.json machineAlias "laptop" disagrees with machine.id match "nobul-mac"'

CASE_ENV="AITOOLS_MACHINE_ALIAS=laptop"
case_run rm-override-env 0 resolve "${M[@]}"
expect alias laptop; expect via override
expect_line '^warn\tprofile "laptop" has no machine.id'
case_run rm-override-derive 0 derive-config "${M[@]}"
expect derived.machineAlias ""; expect_line '^warn\tmachine alias from AITOOLS_MACHINE_ALIAS -- not saved'
CASE_ENV=""
case_run rm-override-arg 0 resolve "${M[@]}" --alias workstation
expect alias workstation; expect via override
expect_line '^warn\tprofile "workstation" has no machine.id'
case_run rm-override-unknown 2 resolve "${M[@]}" --alias nope
expect_line '^error\toverride alias "nope" not in profiles \(laptop, nobul-mac, workstation\)'

fresh_home rm-id-twice
base_profile | perl -0pe "s/\"hostname\": \"(nobul-mac.local|Joses-MBP)\"/\"id\": \"$ID_MAC\",\n        \"hostname\": \"\$1\"/g" \
    | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-id-twice 2 resolve "${M[@]}"
expect_line '^error\tmachine.id 3D4DF2A5.* is registered on more than one profile: laptop, nobul-mac'

fresh_home rm-host-twice
base_profile | perl -0pe 's/"Joses-MBP"/"nobul-mac"/' | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-host-twice 2 resolve "${M[@]}"
expect_line '^error\thostname matches more than one profile: laptop, nobul-mac'

fresh_home rm-stale-alias
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose", "machineAlias": "new-mac" }\n' > "$H/.aitools/config.json"
case_run rm-stale-alias 0 resolve "${M[@]}"
expect via hostname
expect_line '^warn\tconfig.json machineAlias "new-mac" not in profiles \(laptop, nobul-mac, workstation\)'

fresh_home rm-no-dotprofile
case_run rm-no-dotprofile 1 resolve "${M[@]}"
expect via none; expect userRepoVia none

fresh_home rm-corrupt-profile
mkdir -p "$H/repos/aitools-nobul-jose"
printf '{ "version": 2, "profiles": { ' > "$H/repos/aitools-nobul-jose/profile.json"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-corrupt-profile 2 resolve "${M[@]}"
expect_line '^error\t.*profile.json is invalid JSON'

fresh_home rm-v1
write_profile "$H/repos/aitools-nobul-jose" <<'JSON'
{ "name": "Jose", "machines": [] }
JSON
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-v1 2 resolve "${M[@]}"
expect_line '^error\tprofile.json is not v2$'
expect_no_line 'has no profiles object'
# A v2 file without a profiles object has its own message (PR #98 review m1)
write_profile "$H/repos/aitools-nobul-jose" <<'JSON'
{ "version": 2, "identity": { "github": "nobul-jose" } }
JSON
case_run rm-v2-no-profiles 2 resolve "${M[@]}"
expect_line '^error\tprofile.json has no profiles object$'
expect_no_line 'is not v2'
write_profile "$H/repos/aitools-nobul-jose" <<'JSON'
{ "version": 2, "identity": { "github": "nobul-jose" }, "profiles": [] }
JSON
case_run rm-v2-profiles-array 2 resolve "${M[@]}"
expect_line '^error\tprofile.json has no profiles object$'

fresh_home rm-profile-file
CASE_ENV="AITOOLS_PROFILE_FILE=$H/missing.json"
case_run rm-profile-file-missing 2 resolve "${M[@]}"
expect_line '^error\tprofile file set but missing: .*\(AITOOLS_PROFILE_FILE\)'
base_profile > "$H/snap.json"
CASE_ENV="AITOOLS_PROFILE_FILE=$H/snap.json"
case_run rm-profile-file 0 resolve "${M[@]}"
expect alias nobul-mac; expect profileFile "$H/snap.json"
CASE_ENV=""

# claude-code-web exists only on Linux, and PowerShell never branches on the
# environment (cross-platform.md "Environment branches"): .sh only, no golden
if $PLATFORM_LINUX; then
    fresh_home rm-web
    base_profile | perl -0pe 's/"os": "win32"/"os": "win32",\n        "environment": "claude-code-web"/' \
        | write_profile "$H/repos/aitools-nobul-jose"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
    NO_PARITY=1 case_run rm-web 0 resolve "${M[@]}" --environment claude-code-web
    expect alias workstation; expect via environment; expect environment claude-code-web
else
    skip "rm-web (claude-code-web exists only on Linux)"
fi

fresh_home rm-json
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-json 0 resolve "${M[@]}" --json --alias laptop
expect_line '^\{"alias":"laptop","via":"override",.*"warnings":\["profile \\"laptop\\" has no machine.id.*"\],"errors":\[\]\}$'

# --- derive-config -------------------------------------------------------------
fresh_home dc
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "reposPath": "%s" }\n' "$HN/repos" > "$H/.aitools/config.json"
case_run dc 0 derive-config "${M[@]}" --github-user nobul-jose --alias nobul-mac
expect derived.githubUser nobul-jose; expect derived.userRepoPath "$H/repos/aitools-nobul-jose"
expect derived.machineAlias nobul-mac; expect via override; expect aliases "laptop, nobul-mac, workstation"

fresh_home dc-none
case_run dc-none 1 derive-config "${M[@]}" --github-user ghost
expect derived.githubUser ghost; expect derived.userRepoPath ""
expect_line '^warn\tno dotprofile found -- only bootstrap keys written'

fresh_home dc-env
base_profile | write_profile "$H/envdp"
CASE_ENV="AITOOLS_USER_REPO_PATH=$H/envdp"
case_run dc-env 0 derive-config "${M[@]}"
expect derived.userRepoPath ""; expect derived.githubUser nobul-jose
expect via hostname; expect derived.machineAlias ""   # a hostname match is not cached (PR #76 review M1)
expect_line '^warn\tdotprofile from AITOOLS_USER_REPO_PATH -- not saved'
CASE_ENV=""

# --- snapshot ------------------------------------------------------------------
fresh_home snap
base_profile | perl -0pe 's/"profiles"/"claude": { "settings": { "model": "opus" } },\n  "profiles"/' > "$H/p.json"
case_run snap 0 snapshot --profile "$H/p.json"
expect_line '^\{"version":2,"identity":\{"github":"nobul-jose".*\},"cursor":\{\},"profiles":\{"laptop"'
expect_no_line 'settings'

# --- register --------------------------------------------------------------------
fresh_home reg
# Escapes, unicode, nested arrays, a number with a fraction and empty containers:
# a no-op registration must keep every other byte (node layout, key order).
cat > "$H/p.json" <<'JSON'
{
  "version": 2,
  "identity": {
    "github": "nobul-jose",
    "email": "jose@nobul.tech",
    "git": {
      "name": "José \"Pepe\" Palencia",
      "email": "jose@nobul.tech"
    }
  },
  "claude": {
    "settings": {
      "z": [
        1,
        2.5,
        {
          "a": null,
          "b": []
        },
        {}
      ],
      "path": "C:\\Users\\pepe\\repos",
      "tab": "a\tb",
      "emoji": "😀",
      "when": "2026-10-21T12:00:00Z"
    }
  },
  "profiles": {
    "nobul-mac": {
      "name": "Jose",
      "company": "nobul-tech",
      "machine": {
        "hostname": "nobul-mac",
        "os": "darwin",
        "arch": "ARCH",
        "shell": "bash"
      }
    }
  }
}
JSON
# The JSON-engine cases below start from this file before os/arch are made this
# machine's (their results must not depend on the platform)
cp "$H/p.json" "$WORK/reg-template.json"
perl -pi -e "s/\"ARCH\"/\"$ARCH\"/; s/\"os\": \"darwin\"/\"os\": \"$OSNAME\"/" "$H/p.json"
ID_MAC_LC=$(printf '%s' "$ID_MAC" | tr 'A-Z' 'a-z')
ID_OTHER_LC=$(printf '%s' "$ID_OTHER" | tr 'A-Z' 'a-z')
# --alias alone never claims an alias-keyed profile without machine.id (no terminal
# choice behind it: design c); the refusal names the profile and the --claim way
case_run reg-noclaim 4 register --profile "$H/p.json" --alias nobul-mac --shell bash --out "$H/out0.json" "${M[@]}"
expect result refused; expect owner unregistered; expect ownerKey nobul-mac
expect_line '^error\talias "nobul-mac" is used by profile nobul-mac, which is not registered to any machine -- claim it \(--claim nobul-mac\) or choose another alias$'
# --claim KEY (after the user picked it): re-keyed under this machine's id (position
# kept), alias = the old key, machine.id added
case_run reg-update 0 register --profile "$H/p.json" --claim nobul-mac --shell bash --out "$H/out.json" "${M[@]}"
expect result updated; expect machineId "$ID_MAC"; expect key "$ID_MAC_LC"; expect alias nobul-mac
expect claimed nobul-mac; expect owner this
perl -0pe "s/\"nobul-mac\": \\{/\"$ID_MAC_LC\": {/; s/(\"shell\": \"bash\")\\n      \\}/\$1,\\n        \"id\": \"$ID_MAC_LC\"\\n      },\\n      \"alias\": \"nobul-mac\"/" "$H/p.json" > "$WORK/reg-update.want.json"
if cmp -s "$WORK/reg-update.want.json" "$H/out.json"; then
    ok "reg-update: only the key, machine.id and alias changed (other bytes kept)"
else
    bad "reg-update: unexpected changes"; diff "$WORK/reg-update.want.json" "$H/out.json" | sed 's/^/       /' || true
fi
# Parity: both resolvers write identical bytes (this machine's os/arch normalized)
plat_norm "$H/out.json" > "$WORK/reg-update.written.json"
golden_check "reg-update (written file)" profile-reg-update.written.json "$WORK/reg-update.written.json"
case_run reg-unchanged 0 register --profile "$H/out.json" --alias nobul-mac --shell bash --out "$H/out2.json" "${M[@]}"
expect result unchanged
if cmp -s "$H/out.json" "$H/out2.json"; then ok "reg-unchanged: file bytes stable"; else bad "reg-unchanged: file changed"; fi

# A new id with a new alias: created without a terminal (Review3 #82-M1, resolver side)
case_run reg-new-alias 0 register --profile "$H/out.json" --alias spare --name Pepe --company Other \
    --out "$H/out3.json" --machine-id-value "$ID_OTHER" --hostname-value spare-host
expect result created; expect key "$ID_OTHER_LC"; expect alias spare; expect claimed ""
OUT="$H/out3.json"
CASE=reg-new-alias-file
if perl -0ne 'BEGIN { $k = shift @ARGV } exit(/"\Q$k\E": \{\n      "alias": "spare",\n      "name": "Pepe",\n      "company": "Other",\n      "machine": \{\n        "id": "\Q$k\E",\n        "hostname": "spare-host",/ ? 0 : 1)' "$ID_OTHER_LC" "$OUT"; then
    ok "reg-new-alias-file: profiles.<id> = alias, name, company, machine (id = key, lower-cased)"
else bad "reg-new-alias-file: entry shape"; sed 's/^/       /' "$OUT"; fi

# The same id again with another alias: the alias field is renamed, nothing else
case_run reg-rename-alias 0 register --profile "$H/out.json" --alias mac2 --shell bash --out "$H/out4.json" "${M[@]}"
expect result updated; expect key "$ID_MAC_LC"; expect alias mac2; expect claimed ""
if [ "$(perl "$REPO/scripts/aitools-json.pl" get "$H/out4.json" profiles "$ID_MAC_LC" alias)" = "mac2" ]; then ok "reg-rename-alias: alias field renamed"
else bad "reg-rename-alias: alias not renamed"; fi

# An alias another machine's profile answers to: refused, exit 4 (decision 1)
case_run reg-alias-taken 4 register --profile "$H/out3.json" --alias spare --out "$H/out5.json" "${M[@]}"
expect result refused; expect owner other; expect ownerKey "$ID_OTHER_LC"
expect_line '^error\talias "spare" is used by another machine.s profile \(0b1c2d3e-0000-1111-2222-333344445555\) -- choose another alias'
if [ -e "$H/out5.json" ]; then bad "reg-alias-taken: wrote --out"; else ok "reg-alias-taken: nothing written"; fi
# ... unless confirmed interactively: the duplicate is allowed and warned about
case_run reg-alias-dup 0 register --profile "$H/out3.json" --alias spare --allow-duplicate-alias --out "$H/out6.json" "${M[@]}"
expect result updated; expect alias spare
expect_line "^warn\talias \"spare\" is used by 2 machines \\($ID_OTHER_LC, $ID_MAC_LC\\)$"
OTHER_BEFORE=$(perl "$REPO/scripts/aitools-json.pl" json "$H/out3.json" profiles "$ID_OTHER_LC")
if [ "$(perl "$REPO/scripts/aitools-json.pl" json "$H/out6.json" profiles "$ID_OTHER_LC")" = "$OTHER_BEFORE" ]; then
    ok "reg-alias-dup: the other machine's profile is untouched"
else bad "reg-alias-dup: the other machine's profile changed"; fi
# The legacy key of an alias-keyed profile registered to another machine: refused too (#82-M2)
write_profile "$H/m2leg" <<JSON
{ "version": 2, "profiles": { "laptop": { "machine": { "id": "$ID_OTHER", "hostname": "joses-mbp" } } } }
JSON
case_run reg-legacy-taken 4 register --profile "$H/m2leg/profile.json" --alias laptop --out "$H/out7.json" "${M[@]}"
expect owner other; expect ownerKey laptop

# One machine id on an id-keyed and an alias-keyed profile: error, exit 2
write_profile "$H/dupid" <<JSON
{ "version": 2, "profiles": {
  "$ID_MAC_LC": { "alias": "nobul-mac", "machine": { "id": "$ID_MAC_LC" } },
  "old-mac": { "machine": { "id": "$ID_MAC" } } } }
JSON
case_run reg-dup-id 2 register --profile "$H/dupid/profile.json" --alias nobul-mac --out "$H/out8.json" "${M[@]}"
expect_line '^error\tmachine.id 3D4DF2A5.* is already registered on profile "old-mac"'

# No detectable machine id: refused, exit 3 (there is no key to write under)
case_run reg-no-id 3 register --profile "$H/out3.json" --alias x --out "$H/out9.json" --machine-id-value none --hostname-value nobul-mac
expect result refused
expect_line '^error\tno machine id: no machine id \(test value\) -- a machine profile is keyed by this machine.s id$'

# No --alias: a new profile takes the short hostname
case_run reg-default-alias 0 register --profile "$H/out3.json" --out "$H/out10.json" --machine-id-value AAAA-BBBB --hostname-value Box-One.local
expect result created; expect key aaaa-bbbb; expect alias box-one

# Review S3-M3-Resolver-Review (PR #86) fixes
# M2: re-registering after a confirmed duplicate alias is not refused (safe to re-run)
case_run reg-dup-rerun 0 register --profile "$H/out6.json" --out "$H/out11.json" "${M[@]}"
expect alias spare; expect_line "^warn\\talias \"spare\" is used by 2 machines"
case_run reg-dup-rerun-same 0 register --profile "$H/out6.json" --alias spare --out "$H/out12.json" "${M[@]}"
expect alias spare
# M3: --claim refuses a profile registered to another machine, and an unknown key
case_run reg-claim-foreign 4 register --profile "$H/m2leg/profile.json" --claim laptop --out "$H/out13.json" "${M[@]}"
expect owner other; expect ownerKey laptop
expect_line '^error\t--claim: profile "laptop" is registered to another machine -- not claimed$'
case_run reg-claim-missing 2 register --profile "$H/m2leg/profile.json" --claim nope --out "$H/out14.json" "${M[@]}"
expect_line '^error\t--claim: no profile "nope"$'
# M4: a renamed machine's registration updates machine.hostname (clears the clone warning)
case_run reg-hostname 0 register --profile "$H/out3.json" --out "$H/out15.json" --machine-id-value "$ID_MAC" --hostname-value renamed-mac
expect result updated
if [ "$(perl "$REPO/scripts/aitools-json.pl" get "$H/out15.json" profiles "$ID_MAC_LC" machine hostname)" = "renamed-mac" ]; then ok "reg-hostname: machine.hostname updated"
else bad "reg-hostname: machine.hostname not updated"; fi
# minor 6: aliases differing only in case conflict; nit 4: an id-shaped alias is refused
case_run reg-alias-case 4 register --profile "$H/out3.json" --alias SPARE --out "$H/out16.json" "${M[@]}"
expect ownerKey "$ID_OTHER_LC"
case_run reg-alias-idshape 2 register --profile "$H/out3.json" --alias "$ID_OTHER" --out "$H/out17.json" "${M[@]}"

fresh_home reg-create
case_run reg-create 0 register --profile "$H/new/profile.json" --alias nobul-mac --create --github-user nobul-jose \
    --email jose@nobul.tech --name Jose --company nobul-tech --shell zsh --out "$H/created.json" "${M[@]}"
expect result created
# Parity: both resolvers write identical bytes (this machine's os/arch normalized)
plat_norm "$H/created.json" > "$WORK/reg-create.written.json"
golden_check "reg-create (written file)" profile-reg-create.written.json "$WORK/reg-create.written.json"
OUT="$H/created.json"; CASE=reg-create-file
expect_line '^  "version": 2,$'
expect_line '^    "schemaRevision": "2.2"$'
expect_line '^    "company": "nobul-tech",$'
if perl -0ne 'BEGIN { $k = shift @ARGV } exit(/"\Q$k\E": \{\n\s+"alias": "nobul-mac",\n\s+"machine": \{\n\s+"id": "\Q$k\E",/ ? 0 : 1)' "$ID_MAC_LC" "$OUT"; then
    ok "reg-create-file: profiles.<id> with alias, no per-profile name/company (identity holds them)"
else bad "reg-create-file: entry shape"; sed 's/^/       /' "$OUT"; fi

case_run reg-missing-nocreate 1 register --profile "$H/none.json" --alias x --out "$H/o.json" "${M[@]}"
case_run reg-bad-alias 2 register --profile "$H/none.json" --alias "bad alias" --out "$H/o.json" "${M[@]}"

# --- tool exceptions -----------------------------------------------------------------
# case_fresh NAME RC SETUP ARGS... -- like case_run, but SETUP rebuilds the fixture
# first (exception-set changes state). Checks the exit code, the output and the
# resulting profile.json against their golden files. The resulting profile.json is
# kept as $WORK/NAME.profile.json (empty when there is none).
case_fresh() {
    local name="$1" want="$2" setup="$3"; shift 3
    CASE="$name"
    OUT="$WORK/$name.out"
    "$setup"
    run_impl "$OUT" "$@"
    # temp file names carry each run's PID
    if [ "${NORM_TMP:-}" = "1" ]; then perl -pi -e 's/\.tmp\.[0-9]+/.tmp.<pid>/g' "$OUT"; fi
    cp "$EXC_PF" "$WORK/$name.profile.json" 2>/dev/null || : > "$WORK/$name.profile.json"  # absent profile = empty copy
    if [ "$RC" -eq "$want" ]; then ok "$name: $LANG_RUN exit $RC"
    else bad "$name: $LANG_RUN exit $RC, want $want"; sed 's/^/       /' "$OUT" "$OUT.err"; fi
    golden_check "$name" "profile-$name.out" "$OUT"
    # NORM_AT=1: a real clock wrote decidedAt
    NORM_AT_ON="${NORM_AT:-}" perl -pe 'if ($ENV{NORM_AT_ON}) { s/"decidedAt": "[^"]*"/"decidedAt": "<now>"/ }' \
        "$WORK/$name.profile.json" > "$WORK/$name.profile.golden.json"
    golden_check "$name (profile.json)" "profile-$name.profile.json" "$WORK/$name.profile.golden.json"
}

fresh_home exc
EXC_DIR="$H/repos/aitools-nobul-jose"
EXC_PF="$EXC_DIR/profile.json"
EXC_REMOTE="$WORK/exc-remote.git"
exc_profile() {
    base_profile | perl -0pe "s/\"hostname\": \"nobul-mac.local\"/\"id\": \"$ID_MAC\",\n        \"hostname\": \"nobul-mac.local\"/"
}
setup_exc_git() {
    rm -rf "$EXC_DIR" "$EXC_REMOTE"
    exc_profile | write_profile "$EXC_DIR"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
    git init -q --bare "$EXC_REMOTE"
    git -C "$EXC_DIR" init -q
    git -C "$EXC_DIR" config user.name "Test"
    git -C "$EXC_DIR" config user.email "test@example.com"
    git -C "$EXC_DIR" add profile.json
    git -C "$EXC_DIR" commit -q -m init
    git -C "$EXC_DIR" remote add origin "$EXC_REMOTE"
    git -C "$EXC_DIR" push -q -u origin HEAD 2>/dev/null  # bare remote in a temp dir; result checked by the pushed=true assertion
    printf 'unrelated\n' > "$EXC_DIR/other.txt"
    git -C "$EXC_DIR" add other.txt
}
setup_exc_plain() {
    rm -rf "$EXC_DIR"
    exc_profile | write_profile "$EXC_DIR"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
}
setup_exc_hostname() {
    rm -rf "$EXC_DIR"
    base_profile | write_profile "$EXC_DIR"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
}
setup_exc_none() { rm -rf "$EXC_DIR"; printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"; }
SET_ARGS=(exception-set --slug go --platform macos --method pkg-installer --path /usr/local/bin/go --version 1.22.5 \
    --by setup-go --decided-at 2026-10-21T12:00:00Z)

case_fresh exc-set-git 0 setup_exc_git "${SET_ARGS[@]}" "${M[@]}"
expect result created; expect alias nobul-mac; expect via id; expect committed true; expect pushed true
# A legacy alias-keyed profile with this machine's id: written, with a migrate warning (design d)
expect key nobul-mac; expect legacy true; expect owner this
expect_line '^warn\tprofile "nobul-mac" is keyed by alias -- run: aitools-profile migrate'
OUT="$WORK/exc-set-git.profile.json"; CASE=exc-set-git-file
if perl -0ne 'exit(/"toolExceptions": \{\n        "go": \{\n          "decision": "keep",\n          "detected": \{\n            "platform": "macos",\n            "method": "pkg-installer",\n            "path": "\/usr\/local\/bin\/go",\n            "version": "1.22.5"\n          \},\n          "decidedAt": "2026-10-21T12:00:00Z",\n          "decidedBy": "setup-go",\n          "reason": null\n        \}/ ? 0 : 1)' "$OUT"; then
    ok "exc-set-git: entry shape and order as reference/user-repo.md"
else bad "exc-set-git: entry shape"; sed 's/^/       /' "$OUT"; fi
committed_files=$(git -C "$EXC_DIR" show --name-only --format=%s HEAD | perl -ne 'print if /\S/' | paste -sd '|' -)
if [ "$committed_files" = "Record tool exception: keep go (pkg-installer) on nobul-mac|profile.json" ]; then
    ok "exc-set-git: commit holds only profile.json (staged other.txt left alone)"
else bad "exc-set-git: commit was '$committed_files'"; fi
if [ "$(git -C "$EXC_REMOTE" rev-parse HEAD)" = "$(git -C "$EXC_DIR" rev-parse HEAD)" ]; then ok "exc-set-git: pushed to the remote"
else bad "exc-set-git: remote not updated"; fi

# The state left by that run feeds the reads below
case_run exc-get 0 exception-get --slug go "${M[@]}"
expect found true; expect platform macos; expect method pkg-installer; expect path /usr/local/bin/go
expect version 1.22.5; expect decidedAt 2026-10-21T12:00:00Z; expect decidedBy setup-go; expect reason ""
case_run exc-get-other 0 exception-get --slug typst "${M[@]}"
expect found false; expect alias nobul-mac
case_run exc-set-unchanged 0 "${SET_ARGS[@]}" "${M[@]}"
expect result unchanged; expect committed false

setup_exc_noident() {
    setup_exc_git
    # A distinctive owner, so the assertion cannot pass on the real global identity
    perl -pi -e 's/jose\@nobul\.tech/owner\@example.test/g' "$EXC_PF"
    git -C "$EXC_DIR" commit -q -m owner -- profile.json
    git -C "$EXC_DIR" config --unset user.name
    git -C "$EXC_DIR" config --unset user.email
}
case_fresh exc-set-noident 0 setup_exc_noident "${SET_ARGS[@]}" "${M[@]}"
expect committed true
author=$(git -C "$EXC_DIR" log -1 --format='%an <%ae>')
if [ "$author" = "Jose <owner@example.test>" ]; then ok "exc-set-noident: committed as the profile's identity.git"
else bad "exc-set-noident: author '$author'"; fi

case_fresh exc-set-plain 0 setup_exc_plain "${SET_ARGS[@]}" "${M[@]}" --reason "corporate MDM pin"
expect result created; expect committed false
expect_line '^warn\t.* is not a git repository -- profile.json written but not committed$'
OUT="$WORK/exc-set-plain.profile.json"; CASE=exc-set-plain-file
expect_line '"reason": "corporate MDM pin"'

case_fresh exc-set-hostname 3 setup_exc_hostname "${SET_ARGS[@]}" "${M[@]}"
expect result refused; expect via hostname
expect_line '^error\tmachine profile "nobul-mac" matched by hostname only -- run: aitools user init to remember tool choices$'
if cmp -s "$WORK/exc-set-hostname.profile.json" <(base_profile); then ok "exc-set-hostname: profile.json untouched"
else bad "exc-set-hostname: profile.json changed"; fi

case_fresh exc-set-none 3 setup_exc_none "${SET_ARGS[@]}" "${M[@]}"
expect result refused; expect_line '^error\tno dotprofile profile.json -- run: aitools user init'

CASE_ENV="AITOOLS_PROFILE_FILE=$H/snap.json"
base_profile > "$H/snap.json"
case_fresh exc-set-snapshot 3 setup_exc_plain "${SET_ARGS[@]}" "${M[@]}"
expect_line '^error\tprofile from AITOOLS_PROFILE_FILE is a read-only snapshot'
CASE_ENV="AITOOLS_DRY_RUN=1"
case_fresh exc-set-dry 0 setup_exc_plain "${SET_ARGS[@]}" "${M[@]}"
expect result dry-run
if cmp -s "$WORK/exc-set-dry.profile.json" <(exc_profile); then ok "exc-set-dry: profile.json untouched"
else bad "exc-set-dry: profile.json changed"; fi
CASE_ENV=""

case_fresh exc-get-none 2 setup_exc_hostname exception-get --slug go --machine-id-value "$ID_OTHER" --hostname-value elsewhere
expect found false; expect_line '^error\tno profile matches this machine'
# --- PR #76 review: alias writes, timestamps, dirty file, push failure ---------
# via=alias with an unregistered profile (this machine has an id): refused
setup_exc_alias() {
    setup_exc_hostname
    printf '{ "githubUser": "nobul-jose", "machineAlias": "laptop" }\n' > "$H/.aitools/config.json"
}
case_fresh exc-set-alias 3 setup_exc_alias "${SET_ARGS[@]}" "${M[@]}"
expect via alias
expect_line '^error\tmachine profile "laptop" is not registered to this machine -- run: aitools user init to remember tool choices$'
# via=alias with a profile registered to another machine: refused
setup_exc_foreign() {
    setup_exc_alias
    perl -0pi -e 's/"hostname": "Joses-MBP"/"id": "OTHER-MACHINE",\n        "hostname": "Joses-MBP"/' "$EXC_PF"
}
# The cached alias names another machine's profile: ignored (step 4L), then the
# hostname match is refused
case_fresh exc-set-foreign 3 setup_exc_foreign "${SET_ARGS[@]}" "${M[@]}"
expect_line '^warn\tconfig.json machineAlias "laptop" names a profile registered to another machine \(machine.id OTHER-MACHINE\) -- ignored$'
expect via hostname
expect_line '^error\tmachine profile "nobul-mac" matched by hostname only'
# An override naming a profile that is not this machine's: refused (design b)
CASE_ENV="AITOOLS_MACHINE_ALIAS=laptop"
case_fresh exc-set-override 3 setup_exc_alias "${SET_ARGS[@]}" "${M[@]}"
expect via override; expect result refused; expect owner unregistered
expect_line '^error\tmachine profile "laptop" is not registered to this machine'
# An override naming this machine's own profile: allowed
CASE_ENV="AITOOLS_MACHINE_ALIAS=nobul-mac"
case_fresh exc-set-override-own 0 setup_exc_plain "${SET_ARGS[@]}" "${M[@]}"
expect via override; expect owner this; expect result created
CASE_ENV=""
# derive-config does not cache a hostname match
EXC_H="$H"
fresh_home dc-host
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run dc-hostname-not-saved 0 derive-config "${M[@]}"
expect via hostname; expect derived.machineAlias ""
expect_line '^warn\tmachine alias "nobul-mac" matched by hostname only -- not saved to config.json$'
H="$EXC_H"
HN="$(to_native "$H")"

# Without --decided-at: an identical re-keep is unchanged; a changed one gets a new time
SET_NOW=(exception-set --slug go --platform macos --method pkg-installer --path /usr/local/bin/go --version 1.22.5 --by setup-go)
setup_exc_existing() {
    setup_exc_git
    perl -0pi -e 's/("hostname": "nobul-mac.local",\n        "os": "darwin")/$1,\n        "x": 1/' "$EXC_PF"
    perl -0pi -e 's/"x": 1/"x": 1\n      },\n      "toolExceptions": {\n        "go": {\n          "decision": "keep",\n          "detected": {\n            "platform": "macos",\n            "method": "pkg-installer",\n            "path": "\/usr\/local\/bin\/go",\n            "version": "1.22.5"\n          },\n          "decidedAt": "2026-01-01T00:00:00Z",\n          "decidedBy": "setup-go",\n          "reason": null\n        }/' "$EXC_PF"
    git -C "$EXC_DIR" commit -q -m existing -- profile.json
}
case_fresh exc-set-same 0 setup_exc_existing "${SET_NOW[@]}" "${M[@]}"
expect result unchanged; expect committed false
NORM_AT=1 case_fresh exc-set-changed 0 setup_exc_existing exception-set --slug go --platform macos --method pkg-installer \
    --path /usr/local/bin/go --version 1.23.0 --by setup-go "${M[@]}"
expect result updated; expect committed true
if grep -q '"decidedAt": "2026-01-01T00:00:00Z"' "$WORK/exc-set-changed.profile.json"; then bad "exc-set-changed: kept the old decidedAt"
else ok "exc-set-changed: new decidedAt"; fi

# profile.json edited by hand and not committed: written, not auto-committed
setup_exc_dirty() { setup_exc_git; perl -pi -e 's/"Joses-MBP"/"Joses-MBP-2"/' "$EXC_PF"; }
case_fresh exc-set-dirty 0 setup_exc_dirty "${SET_ARGS[@]}" "${M[@]}"
expect result created; expect committed false
expect_line '^warn\tprofile.json had uncommitted changes before this write -- not committed automatically'

# Push fails (no remote): committed, not pushed, warning
setup_exc_noremote() { setup_exc_git; git -C "$EXC_DIR" remote remove origin; }
case_fresh exc-set-nopush 0 setup_exc_noremote "${SET_ARGS[@]}" "${M[@]}"
expect committed true; expect pushed false
expect_line '^warn\tdotprofile push failed \(exit [0-9]+\) -- run git push in '

case_run exc-bad-platform 2 exception-set --slug go --platform darwin --method m --path /p --by setup-go "${M[@]}"
case_run exc-bad-slug 2 exception-get --slug "Go Lang" "${M[@]}"

# --- id-keyed profiles (re-key design batch 2) -----------------------------------------
# profiles.<machine id, lower-cased> with an alias field; legacy alias-keyed profiles
# are still read. Fields: key, alias, via, owner, legacy.
id_profile() {
    cat <<JSON
{
  "version": 2,
  "identity": {
    "github": "nobul-jose",
    "email": "jose@nobul.tech",
    "name": "Jose",
    "company": "nobul-tech",
    "git": {
      "name": "Jose",
      "email": "jose@nobul.tech"
    }
  },
  "profiles": {
    "$ID_MAC_LC": {
      "alias": "nobul-mac",
      "machine": {
        "id": "$ID_MAC_LC",
        "hostname": "nobul-mac",
        "os": "darwin"
      }
    },
    "$ID_OTHER_LC": {
      "alias": "laptop",
      "company": "Nobul",
      "machine": {
        "id": "$ID_OTHER_LC",
        "hostname": "Joses-MBP",
        "os": "darwin"
      }
    },
    "old-pc": {
      "machine": {
        "hostname": "NewcoPC",
        "os": "win32"
      }
    }
  }
}
JSON
}
fresh_home idk
id_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run idk-resolve 0 resolve "${M[@]}"
expect key "$ID_MAC_LC"; expect alias nobul-mac; expect via id; expect owner this; expect legacy false
expect company nobul-tech
expect_no_line '^warn'
case_run idk-json 0 resolve "${M[@]}" --json
expect_line "^\\{\"alias\":\"nobul-mac\",\"via\":\"id\",\"key\":\"$ID_MAC_LC\",\"owner\":\"this\",\"legacy\":\"false\","
# Override by alias field, by key (any case), and to a profile without an id
case_run idk-override-other 0 resolve "${M[@]}" --alias laptop
expect key "$ID_OTHER_LC"; expect via override; expect owner other; expect company Nobul
expect_line "^warn\\tprofile \"laptop\" is registered to another machine \\(machine.id $ID_OTHER_LC, this machine $ID_MAC\\)$"
case_run idk-override-key 0 resolve "${M[@]}" --alias "$ID_OTHER"
expect key "$ID_OTHER_LC"; expect alias laptop; expect via override
case_run idk-override-unreg 0 resolve "${M[@]}" --alias old-pc
expect key old-pc; expect owner unregistered; expect legacy true
case_run idk-none 2 resolve --machine-id-value 11111111-2222 --hostname-value elsewhere
expect key ""; expect owner absent; expect via none; expect legacy false
# A stored hostname that differs from the live one: the only clone signal
case_run idk-host-mismatch 0 resolve --machine-id-value "$ID_MAC" --hostname-value renamed-mac
expect via id
expect_line "^warn\\tprofile \"nobul-mac\" was registered with hostname \"nobul-mac\", this machine is \"renamed-mac\" -- renamed \\(run: aitools user init to update it\\), or a clone that shares machine id $ID_MAC$"
# Hostname match on another machine's id-keyed profile: owner other (Review3 #82-M2 warning)
case_run idk-host-other 0 resolve --machine-id-value 99999999-0000 --hostname-value joses-mbp
expect via hostname; expect key "$ID_OTHER_LC"; expect owner other
expect_line '^warn\tprofile "laptop" is registered to another machine'
# Upper-case key written by hand: found ignoring case
fresh_home idk-upper
id_profile | perl -pe "s/\"\Q$ID_MAC_LC\E\": \\{/\"$ID_MAC\": {/" | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run idk-upper 0 resolve "${M[@]}"
expect key "$ID_MAC"; expect via id; expect legacy false; expect owner this

# config.json machineId: used only when the live id cannot be detected (step 4)
fresh_home idk-cfg
id_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose", "machineId": "%s", "machineAlias": "nobul-mac" }\n' "$ID_MAC_LC" > "$H/.aitools/config.json"
case_run idk-cfg 0 resolve --machine-id-value none --hostname-value nobul-mac
expect via config; expect key "$ID_MAC_LC"; expect owner this
expect_line '^warn\tmachine id unavailable: no machine id \(test value\)$'
case_run idk-cfg-live 0 resolve --machine-id-value "$ID_OTHER" --hostname-value nobul-mac
expect via id; expect key "$ID_OTHER_LC"
expect_line "^warn\\tconfig.json machineId \"$ID_MAC_LC\" disagrees with machine.id match \"$ID_OTHER_LC\" -- machine.id wins$"
printf '{ "githubUser": "nobul-jose", "machineId": "gone-id" }\n' > "$H/.aitools/config.json"
case_run idk-cfg-stale 0 resolve --machine-id-value none --hostname-value nobul-mac
expect via hostname
expect_line '^warn\tconfig.json machineId "gone-id" not in profiles -- ignored$'

# derive-config: derived.machineId only for this machine's id-keyed profile
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run idk-derive 0 derive-config "${M[@]}"
expect derived.machineId "$ID_MAC_LC"; expect derived.machineAlias nobul-mac; expect key "$ID_MAC_LC"
expect aliases "nobul-mac, laptop, old-pc"
case_run idk-derive-other 0 derive-config "${M[@]}" --alias laptop
expect derived.machineId ""; expect derived.machineAlias laptop; expect owner other

# One alias on two machines (after an interactive confirm): every resolve warns, and
# an --alias lookup by that alias is an error that lists the keys
fresh_home idk-dup
id_profile | perl -pe 's/"alias": "laptop"/"alias": "nobul-mac"/' | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run idk-dup 0 resolve "${M[@]}"
expect via id; expect_line "^warn\\talias \"nobul-mac\" is used by 2 machines \\($ID_MAC_LC, $ID_OTHER_LC\\)$"
case_run idk-dup-lookup 2 resolve "${M[@]}" --alias nobul-mac
expect_line "^error\\talias \"nobul-mac\" is used by more than one profile: $ID_MAC_LC, $ID_OTHER_LC -- select one by its key$"
case_run idk-dup-bykey 0 resolve "${M[@]}" --alias "$ID_OTHER_LC"
expect key "$ID_OTHER_LC"

# Tool exceptions on an id-keyed profile: profiles.<id>.toolExceptions
fresh_home idk-exc
EXC_DIR="$H/repos/aitools-nobul-jose"
EXC_PF="$EXC_DIR/profile.json"
setup_idk_exc() {
    rm -rf "$EXC_DIR"
    id_profile | write_profile "$EXC_DIR"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
}
case_fresh idk-exc-set 0 setup_idk_exc "${SET_ARGS[@]}" "${M[@]}"
expect result created; expect key "$ID_MAC_LC"; expect legacy false; expect via id
if [ "$(perl "$REPO/scripts/aitools-json.pl" get "$EXC_PF" profiles "$ID_MAC_LC" toolExceptions go decision)" = "keep" ]; then
    ok "idk-exc-set: written at profiles.<id>.toolExceptions.go"
else bad "idk-exc-set: entry missing"; fi
case_run idk-exc-get 0 exception-get --slug go "${M[@]}"
expect found true; expect key "$ID_MAC_LC"; expect owner this; expect method pkg-installer
# Another machine's profile by override: refused; no id detectable: refused
CASE_ENV="AITOOLS_MACHINE_ALIAS=laptop"
case_fresh idk-exc-other 3 setup_idk_exc "${SET_ARGS[@]}" "${M[@]}"
expect owner other; expect_line '^error\tmachine profile "laptop" is not registered to this machine'
CASE_ENV=""
setup_idk_exc_cfg() { setup_idk_exc; printf '{ "githubUser": "nobul-jose", "machineId": "%s" }\n' "$ID_MAC_LC" > "$H/.aitools/config.json"; }
case_fresh idk-exc-cfg 3 setup_idk_exc_cfg "${SET_ARGS[@]}" --machine-id-value none --hostname-value nobul-mac
expect via config
expect_line '^error\tmachine profile "nobul-mac" matched by config.json machineId only \(machine id unavailable\) -- tool choice not saved$'
# Review minor 1: another machine's recorded decision is never returned
setup_idk_exc_other() {
    setup_idk_exc
    perl -0pi -e 's/("hostname": "Joses-MBP",\n        "os": "darwin"\n      \})/$1,\n      "toolExceptions": {\n        "go": {\n          "decision": "keep",\n          "detected": {\n            "platform": "macos",\n            "method": "brew",\n            "path": "\/x",\n            "version": "1"\n          },\n          "decidedAt": "2026-01-01T00:00:00Z",\n          "decidedBy": "setup-go",\n          "reason": null\n        }\n      }/' "$EXC_PF"
}
case_fresh idk-exc-get-other 0 setup_idk_exc_other exception-get --slug go --machine-id-value 99999999-0000 --hostname-value joses-mbp
expect via hostname; expect owner other; expect found false; expect method ""
expect_line '^warn\ttoolExceptions.go in profile "laptop" is not this machine.s \(owner other\) -- ignored$'
# Review minor 2: owner unknown when this machine's id cannot be detected
case_run idk-owner-unknown 0 resolve --machine-id-value none --hostname-value nobul-mac --alias nobul-mac
expect owner unknown; expect key "$ID_MAC_LC"
# Review minor 3: a key that disagrees with its machine.id is reported; migrate refuses it
fresh_home idk-mismatch
id_profile | perl -0pe "s/(\"id\": \")\Q$ID_MAC_LC\E\"/\${1}$ID_OTHER\"/" | perl -0pe "s/\"\Q$ID_OTHER_LC\E\": \\{/\"other-laptop\": {/" \
    | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run idk-mismatch 0 resolve "${M[@]}"
expect via id; expect key "$ID_MAC_LC"
expect_line "^warn\\tprofile key \"$ID_MAC_LC\" disagrees with its machine.id \"$ID_OTHER\" -- fix profile.json by hand$"
cp "$H/repos/aitools-nobul-jose/profile.json" "$WORK/idk-mismatch.before.json"
case_run idk-mismatch-migrate 2 migrate
expect result failed
expect_line "^error\\tprofile key \"$ID_MAC_LC\" disagrees with its machine.id \"$ID_OTHER\" -- fix profile.json by hand; nothing written$"
if cmp -s "$WORK/idk-mismatch.before.json" "$H/repos/aitools-nobul-jose/profile.json"; then ok "idk-mismatch-migrate: nothing written"
else bad "idk-mismatch-migrate: profile.json changed"; fi

# --- migrate (re-key design section f) --------------------------------------------------
fresh_home mig
EXC_DIR="$H/repos/aitools-nobul-jose"
EXC_PF="$EXC_DIR/profile.json"
EXC_REMOTE="$WORK/mig-remote.git"
mig_profile() {
    base_profile | perl -0pe "s/\"hostname\": \"nobul-mac.local\"/\"id\": \"$ID_MAC\",\n        \"hostname\": \"nobul-mac.local\"/; s/\"hostname\": \"Joses-MBP\"/\"id\": \"$ID_OTHER_LC\",\n        \"hostname\": \"Joses-MBP\"/; s/(\n  \}\n\}\n)\z/,\n    \"web\": {\n      \"machine\": {\n        \"environment\": \"claude-code-web\"\n      }\n    }\$1/"
}
setup_mig_plain() {
    rm -rf "$EXC_DIR"
    mig_profile | write_profile "$EXC_DIR"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
}
setup_mig_git() {
    rm -rf "$EXC_DIR" "$EXC_REMOTE"
    setup_mig_plain
    git init -q --bare "$EXC_REMOTE"
    git -C "$EXC_DIR" init -q
    git -C "$EXC_DIR" config user.name "Test"
    git -C "$EXC_DIR" config user.email "test@example.com"
    git -C "$EXC_DIR" add profile.json
    git -C "$EXC_DIR" commit -q -m init
    git -C "$EXC_DIR" remote add origin "$EXC_REMOTE"
    git -C "$EXC_DIR" push -q -u origin HEAD 2>/dev/null  # bare remote in a temp dir; result checked by the pushed=true assertion
}
MIG_RENAMED="laptop -> $ID_OTHER_LC, nobul-mac -> $ID_MAC_LC, web -> environment:claude-code-web"
case_fresh mig-dry 0 setup_mig_plain migrate --dry-run
expect result dry-run; expect renamed "$MIG_RENAMED"; expect unclaimed workstation
expect_line '^warn\tprofile "workstation" has no machine.id -- left as is \(aitools user init claims it\)$'
if cmp -s "$EXC_PF" <(mig_profile); then ok "mig-dry: profile.json untouched"; else bad "mig-dry: profile.json changed"; fi

case_fresh mig-run 0 setup_mig_git migrate
expect result migrated; expect renamed "$MIG_RENAMED"; expect committed true; expect pushed true
got_keys=$(perl "$REPO/scripts/aitools-json.pl" keys "$EXC_PF" profiles | paste -sd ',' -)
if [ "$got_keys" = "$ID_OTHER_LC,$ID_MAC_LC,workstation,environment:claude-code-web" ]; then ok "mig-run: keys re-keyed in place ($got_keys)"
else bad "mig-run: keys '$got_keys'"; fi
# Exact bytes: keys renamed, `alias` appended to each re-keyed profile, nothing else
# (machine.id keeps its upper case: content is not rewritten). The fixture is put in
# the engine's layout first (an empty edit), as every writer does.
mig_profile > "$WORK/mig-run.in.json"
perl "$REPO/scripts/aitools-json.pl" edit "$WORK/mig-run.in.json" "$WORK/mig-run.canon.json" < /dev/null
perl -0pe "s/\"nobul-mac\": \\{/\"$ID_MAC_LC\": {/; s/\"laptop\": \\{/\"$ID_OTHER_LC\": {/; s/\"web\": \\{/\"environment:claude-code-web\": {/;
    s/(\"hostname\": \"Joses-MBP\",\\n        \"os\": \"darwin\"\\n      \\})/\$1,\\n      \"alias\": \"laptop\"/;
    s/(\"hostname\": \"nobul-mac.local\",\\n        \"os\": \"darwin\"\\n      \\})/\$1,\\n      \"alias\": \"nobul-mac\"/;
    s/(\"environment\": \"claude-code-web\"\\n      \\})/\$1,\\n      \"alias\": \"web\"/" "$WORK/mig-run.canon.json" > "$WORK/mig-run.want.json"
if cmp -s "$WORK/mig-run.want.json" "$EXC_PF"; then ok "mig-run: only keys renamed and alias lines added (other bytes kept)"
else bad "mig-run: unexpected bytes"; diff "$WORK/mig-run.want.json" "$EXC_PF" | sed 's/^/       /' || true; fi
mig_commit=$(git -C "$EXC_DIR" show --name-only --format=%s HEAD | perl -ne 'print if /\S/' | paste -sd '|' -)
if [ "$mig_commit" = "Migrate machine profiles to id keys|profile.json" ]; then ok "mig-run: committed profile.json only"
else bad "mig-run: commit '$mig_commit'"; fi
if [ "$(git -C "$EXC_REMOTE" rev-parse HEAD)" = "$(git -C "$EXC_DIR" rev-parse HEAD)" ]; then ok "mig-run: pushed"; else bad "mig-run: not pushed"; fi
if ls "$EXC_DIR"/profile.json.bak.* >/dev/null 2>&1; then ok "mig-run: backup written"; else bad "mig-run: no backup"; fi  # ls result checked by the if

# After the migration: resolves via id, not legacy; a second run changes nothing
case_run mig-resolve 0 resolve "${M[@]}"
expect via id; expect key "$ID_MAC_LC"; expect alias nobul-mac; expect legacy false
expect_no_line 'keyed by alias'
case_run mig-again 0 migrate
expect result unchanged; expect renamed ""; expect committed false

# One machine id on two profiles: error, nothing written
setup_mig_dup() {
    setup_mig_plain
    perl -0pi -e "s/\"\Q$ID_OTHER_LC\E\"/\"$ID_MAC\"/" "$EXC_PF"
}
case_fresh mig-dup 2 setup_mig_dup migrate
expect result failed
expect_line "^error\\tprofiles \"laptop\" and \"nobul-mac\" would both be keyed \"$ID_MAC_LC\" \\(one machine id on two profiles\\) -- nothing written$"
if cmp -s "$EXC_PF" <(mig_profile | perl -0pe "s/\"\Q$ID_OTHER_LC\E\"/\"$ID_MAC\"/"); then ok "mig-dup: profile.json untouched"
else bad "mig-dup: profile.json changed"; fi
CASE_ENV="AITOOLS_PROFILE_FILE=$H/snap.json"
mig_profile > "$H/snap.json"
case_fresh mig-snapshot 3 setup_mig_plain migrate
expect result refused
CASE_ENV=""
# Not v2, and v2 without a profiles object: one message each, nothing written (PR #98 m1)
setup_mig_v1() { rm -rf "$EXC_DIR"; printf '{ "name": "Jose", "machines": [] }\n' | write_profile "$EXC_DIR"; }
case_fresh mig-v1 2 setup_mig_v1 migrate
expect result failed
expect_line '^error\tprofile.json is not v2$'
setup_mig_noprof() { rm -rf "$EXC_DIR"; printf '{ "version": 2, "identity": { "github": "nobul-jose" } }\n' | write_profile "$EXC_DIR"; }
case_fresh mig-no-profiles 2 setup_mig_noprof migrate
expect result failed
expect_line '^error\tprofile.json has no profiles object$'
if [ "$(cat "$EXC_PF")" = '{ "version": 2, "identity": { "github": "nobul-jose" } }' ]; then ok "mig-no-profiles: profile.json untouched"
else bad "mig-no-profiles: profile.json changed"; fi

# --- regressions from the PR #73 review (S3-Profile-Review) --------------------------
fresh_home rev
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
CASE_ENV="AITOOLS_ENVIRONMENT=bogus"
case_run rev-m1-stdout 0 user-repo-path --plain   # M1: the lib's environment warning must not reach stdout
if [ "$(cat "$OUT")" = "$H/repos/aitools-nobul-jose" ]; then ok "rev-m1-stdout: stdout holds only the path"
else bad "rev-m1-stdout: stdout was '$(cat "$OUT")'"; fi
CASE_ENV=""

write_profile "$H/m2" <<'JSON'
{ "version": 2, "profiles": { "a": { "machine": null } } }
JSON
case_run rev-m2-throw 2 register --profile "$H/m2/profile.json" --claim a --out "$H/m2.out" "${M[@]}"
expect_line "^error\tregister failed: set: 'machine' is not an object"

write_profile "$H/m3" <<'JSON'
{
  "version": 2,
  "claude": {
    "settings": {
      "a": 0.30000000000000004,
      "b": 0.3333333333333333,
      "c": 12345678901234567890
    }
  },
  "profiles": {
    "a": {
      "machine": {
        "id": "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
      }
    }
  }
}
JSON
# Number literals kept byte for byte: a perl-engine guarantee (aitools-profile.ps1
# documents that non-integer literals are re-formatted), so macOS/Linux only
if [ "$LANG_RUN" = sh ]; then
    NO_PARITY=1 case_run rev-m3-numbers 0 register --profile "$H/m3/profile.json" --alias a --out "$H/m3.out" "${M[@]}"
    if perl -0ne 'exit(/"a": 0\.30000000000000004,\n      "b": 0\.3333333333333333,\n      "c": 12345678901234567890\n/ ? 0 : 1)' "$H/m3.out"; then
        ok "rev-m3-numbers: number literals kept byte for byte (bash)"
    else bad "rev-m3-numbers: numbers changed"; sed 's/^/       /' "$H/m3.out"; fi
else
    skip "rev-m3-numbers (number literals byte for byte: the perl engine's guarantee, macOS/Linux)"
fi

NO_PARITY=1 case_run rev-help 0 --help   # help text names each platform's sources
expect_line '^aitools-profile\.(sh|ps1) -- dotprofile and machine-profile resolver'
case_run rev-opt-case 2 resolve --PROFILE "$H/m2/profile.json"

write_profile "$H/m7" <<'JSON'
{ "version": 2, "identity": { "github": "x" }, "profiles": { "a": { "machine": { "id": "3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5", "hostname": "nobul-mac", "os": "OS", "arch": "ARCH" } } } }
JSON
perl -pi -e "s/\"OS\"/\"$OSNAME\"/; s/\"ARCH\"/\"$ARCH\"/" "$H/m7/profile.json"
case_run rev-m7-name 0 register --profile "$H/m7/profile.json" --alias a --name NewName --out "$H/m7.out" "${M[@]}"
expect result updated
case_run rev-m8-tab 2 register --profile "$H/m7/profile.json" --alias a --name "$(printf 'a\tb')" --out "$H/m8.out" "${M[@]}"

write_profile "$H/m9" <<'JSON'
{ "version": 2, "identity": {}, "cursor": ["only"], "profiles": {} }
JSON
case_run rev-m9-snapshot 0 snapshot --profile "$H/m9/profile.json"
expect_line '"cursor":\["only"\]'

case_run rev-host-trim 0 resolve --machine-id-value "$ID_OTHER" --hostname-value "  NewcoPC.corp  "
expect alias workstation; expect via hostname

# --- JSON engines: rename (re-key design batch 1) ------------------------------------
# The perl edit op "rename<TAB>NEW<TAB>SEG..." and Rename-JKey in aitools-json.ps1
# must keep the key's position and every other byte, and write identical bytes.
# Each engine runs where its resolver runs: perl (aitools-profile.sh's engine) on
# macOS/Linux, aitools-json.ps1 on Windows; their results share golden files.
# aitools-json.pl also serves as the read-only checker below (check, keys, get)
# on every platform: perl ships with Git for Windows.
JPL="$REPO/scripts/aitools-json.pl"
JPS1="$REPO/scripts/aitools-json.ps1"
JW="$WORK/jrename"
mkdir -p "$JW"
cat > "$JW/driver.ps1" <<'PS1'
# Test driver: IN OUT OP... ; each OP is "|"-separated:
#   rename|NEW|SEG...   set|STRING-VALUE|SEG...
. $env:AITOOLS_TEST_JSON_PS1
$r = Read-JsonFile $args[0]
if ($r.State -ne "valid") { [Console]::Error.WriteLine($r.Message); exit 2 }
try {
    for ($i = 2; $i -lt $args.Count; $i++) {
        $f = ([string]$args[$i]).Split("|")
        $segs = [string[]]@()
        if ($f.Count -gt 2) { $segs = [string[]]$f[2..($f.Count - 1)] }
        if ($f[0] -eq "rename") { Rename-JKey $r.Value $f[1] $segs }
        elseif ($f[0] -eq "set") { Set-JValue $r.Value $f[1] $segs }
        else { throw "driver: unknown op $($f[0])" }
    }
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 2 }
[IO.File]::WriteAllText($args[1], (ConvertTo-NodeJson $r.Value) + "`n", $script:Utf8NoBom)
exit 0
PS1
# The register fixture above (as written, before os/arch were made this machine's):
# escapes, unicode, nested arrays, a fraction, empty containers, a date string. Add
# a profile before and after the one to rename.
perl -0pe 's/("profiles": \{\n)/$1    "first": {\n      "machine": {\n        "os": "linux"\n      }\n    },\n/; s/(\n  \}\n\}\n)\z/,\n    "last": {\n      "list": [\n        "a"\n      ]\n    }$1/' "$WORK/reg-template.json" > "$JW/in.json"
if perl "$JPL" check "$JW/in.json"; then ok "jr-fixture: valid JSON"; else bad "jr-fixture: invalid"; sed 's/^/       /' "$JW/in.json"; fi

# jr_case NAME WANT_RC "PERL_OPS" PS_OP... -- run this platform's engine on in.json
# (perl: PERL_OPS on stdin; aitools-json.ps1: the PS_OP arguments to driver.ps1);
# sets JOUT (the written file) and JERR (its stderr)
jr_case() {
    local name="$1" want="$2" ops="$3" eng; shift 3
    CASE="$name"
    RC=0
    local in="${JR_IN:-$JW/in.json}"
    if [ "$LANG_RUN" = sh ]; then
        eng=perl; JOUT="$JW/$name.pl.json"; JERR="$JW/$name.pl.err"
        printf '%b' "$ops" | perl "$JPL" edit "$in" "$JOUT" > "$JERR" 2>&1 || RC=$?
    else
        eng=pwsh; JOUT="$JW/$name.ps.json"; JERR="$JW/$name.ps.err"
        env AITOOLS_TEST_JSON_PS1="$(native_path "$JPS1")" MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
            pwsh -NoProfile -NonInteractive -File "$(native_path "$JW/driver.ps1")" "$(native_path "$in")" "$(native_path "$JOUT")" "$@" \
            > "$JERR" 2>&1 || RC=$?
        from_native "$JERR"
    fi
    if [ "$RC" -eq "$want" ]; then ok "$name: $eng exit $RC"
    else bad "$name: $eng exit $RC, want $want"; sed 's/^/       /' "$JERR"; fi
    if [ "$want" -ne 0 ]; then
        if [ -e "$JOUT" ]; then bad "$name: $eng wrote $JOUT on failure"; else ok "$name: $eng wrote nothing"; fi
        golden_check "$name (message)" "profile-$name.err" "$JERR"
    else
        golden_check "$name (written file)" "profile-$name.json" "$JOUT"
    fi
}
# jr_keys WANT SEG... -- keys of the object at SEG in $JOUT, joined with ","
jr_keys() {
    local want="$1" got; shift
    got=$(perl "$JPL" keys "$JOUT" "$@" | paste -sd ',' -)
    if [ "$got" = "$want" ]; then ok "$CASE: keys $want"; else bad "$CASE: keys '$got', want '$want'"; fi
}
# jr_msg TEXT -- the engine's stderr is exactly TEXT
jr_msg() {
    if [ "$(cat "$JERR")" = "$1" ]; then ok "$CASE: message '$1'"
    else bad "$CASE: message '$(cat "$JERR")', want '$1'"; fi
}

ID_MAC_LC=$(printf '%s' "$ID_MAC" | tr 'A-Z' 'a-z')
jr_case jr-middle 0 "rename\t$ID_MAC_LC\tprofiles\tnobul-mac\n" "rename|$ID_MAC_LC|profiles|nobul-mac"
jr_keys "first,$ID_MAC_LC,last" profiles
if [ "$(perl "$JPL" get "$JOUT" profiles "$ID_MAC_LC" machine hostname)" = "nobul-mac" ]; then ok "jr-middle: value moved with the key"
else bad "jr-middle: value lost"; fi
diff "$JW/in.json" "$JOUT" > "$JW/jr-middle.diff" || true  # differences expected; counted below
if perl -ne '$n++ if /^[<>]/; $k++ if /^> +"\Q'"$ID_MAC_LC"'\E": \{$/; END { exit($n == 2 && $k == 1 ? 0 : 1) }' "$JW/jr-middle.diff"; then
    ok "jr-middle: only the key line changed (other bytes kept)"
else bad "jr-middle: unexpected changes"; sed 's/^/       /' "$JW/jr-middle.diff"; fi

jr_case jr-first 0 "rename\tfirst-renamed\tprofiles\tfirst\n" "rename|first-renamed|profiles|first"
jr_keys "first-renamed,nobul-mac,last" profiles
jr_case jr-last 0 "rename\tz\tprofiles\tlast\n" "rename|z|profiles|last"
jr_keys "first,nobul-mac,z" profiles
jr_case jr-top 0 "rename\tident\tidentity\n" "rename|ident|identity"
jr_keys "version,ident,claude,profiles"
jr_case jr-then-set 0 "rename\tnew-key\tprofiles\tnobul-mac\nset\tstring\tnobul-mac\tprofiles\tnew-key\talias\n" \
    "rename|new-key|profiles|nobul-mac" "set|nobul-mac|profiles|new-key|alias"
jr_keys "name,company,machine,alias" profiles new-key
jr_case jr-case-only 0 "rename\tNOBUL-MAC\tprofiles\tnobul-mac\n" "rename|NOBUL-MAC|profiles|nobul-mac"
jr_keys "first,NOBUL-MAC,last" profiles
jr_case jr-same 0 "rename\tnobul-mac\tprofiles\tnobul-mac\n" "rename|nobul-mac|profiles|nobul-mac"
if cmp -s "$JW/in.json" "$JOUT"; then ok "jr-same: no-op, bytes unchanged"; else bad "jr-same: file changed"; fi

jr_case jr-missing 2 "rename\tx\tprofiles\tnope\n" "rename|x|profiles|nope"
jr_msg "rename: 'nope' not found"
jr_case jr-exists 2 "rename\tlast\tprofiles\tfirst\n" "rename|last|profiles|first"
jr_msg "rename: 'last' already exists"
jr_case jr-exists-case 2 "rename\tLAST\tprofiles\tfirst\n" "rename|LAST|profiles|first"
jr_msg "rename: 'LAST' already exists"
jr_case jr-old-case 2 "rename\tx\tprofiles\tNOBUL-MAC\n" "rename|x|profiles|NOBUL-MAC"
jr_msg "rename: 'NOBUL-MAC' not found"
jr_case jr-path-missing 2 "rename\tx\tnope\tnobul-mac\n" "rename|x|nope|nobul-mac"
jr_msg "rename: 'nope' not found"
jr_case jr-not-object 2 "rename\tx\tversion\ty\n" "rename|x|version|y"
jr_msg "rename: 'version' is not an object"
jr_case jr-no-key 2 "rename\tx\n" "rename|x"
jr_msg "rename: no key given"
jr_case jr-empty-new 2 "rename\t\tprofiles\tfirst\n" "rename||profiles|first"
jr_msg "rename: new key is empty"

# Scalar and array values two levels down (review S3-M3-JsonRename-Review, nit 2)
jr_case jr-deep-scalar 0 "rename\tp2\tclaude\tsettings\tpath\n" "rename|p2|claude|settings|path"
jr_keys "z,p2,tab,emoji,when" claude settings
jr_case jr-deep-array 0 "rename\tzz\tclaude\tsettings\tz\n" "rename|zz|claude|settings|z"
jr_keys "zz,path,tab,emoji,when" claude settings

# Null, empty-array, single-item-array and object values three levels deep; non-ASCII keys
printf '%s\n' '{' '  "a": {' '    "b": {' '      "n": null,' '      "e": [],' '      "one": [' '        1' '      ],' \
    '      "Été": {},' '      "k": true' '    }' '  }' '}' > "$JW/uni.json"
JR_IN="$JW/uni.json"
jr_case jr-null 0 "rename\tnn\ta\tb\tn\n" "rename|nn|a|b|n"
jr_keys "nn,e,one,Été,k" a b
jr_case jr-empty-array 0 "rename\tee\ta\tb\te\n" "rename|ee|a|b|e"
jr_case jr-one-array 0 "rename\too\ta\tb\tone\n" "rename|oo|a|b|one"
jr_case jr-unicode-key 0 "rename\tété2\ta\tb\tÉté\n" "rename|été2|a|b|Été"
jr_keys "n,e,one,été2,k" a b
# Another key equal ignoring Unicode case: refused by both (PowerShell could not read the result)
jr_case jr-unicode-exists 2 "rename\tété\ta\tb\tk\n" "rename|été|a|b|k"
jr_msg "rename: 'été' already exists"
JR_IN=""

# A failed rename leaves an existing output file untouched (perl writes only on
# success): the perl engine's own guarantee, macOS/Linux
if [ "$LANG_RUN" = sh ]; then
    printf 'sentinel\n' > "$JW/keep.json"
    RC=0
    printf 'rename\tx\tprofiles\tnope\n' | perl "$JPL" edit "$JW/in.json" "$JW/keep.json" 2>/dev/null || RC=$?  # rc checked below
    if [ "$RC" -eq 2 ] && [ "$(cat "$JW/keep.json")" = "sentinel" ]; then ok "jr-keep-out: existing OUT untouched on failure"
    else bad "jr-keep-out: rc $RC, OUT '$(cat "$JW/keep.json")'"; fi
else
    skip "jr-keep-out (the perl engine's edit command: macOS/Linux)"
fi

# --- S3-MF-Audit A-6..A-9: write failures, key case, detail logging ------------------
# JSON engines: a set whose new segment equals an existing key ignoring case is
# refused by both, with one message (A-9; perl used to add a sibling key that
# ConvertFrom-Json cannot read, PowerShell overwrote the other key)
jr_case jr-set-case-last 2 "set\tstring\tv\tprofiles\tNOBUL-MAC\n" "set|v|profiles|NOBUL-MAC"
jr_msg "set: 'NOBUL-MAC' differs only in case from existing key 'nobul-mac'"
jr_case jr-set-case-mid 2 "set\tstring\tv\tprofiles\tNOBUL-MAC\talias\n" "set|v|profiles|NOBUL-MAC|alias"
jr_msg "set: 'NOBUL-MAC' differs only in case from existing key 'nobul-mac'"
jr_case jr-set-case-top 2 "set\tstring\tv\tProfiles\n" "set|v|Profiles"
jr_msg "set: 'Profiles' differs only in case from existing key 'profiles'"
jr_case jr-set-exact 0 "set\tstring\tv\tprofiles\tnobul-mac\tbrand-new\n" "set|v|profiles|nobul-mac|brand-new"
if [ "$(perl "$JPL" get "$JOUT" profiles nobul-mac brand-new)" = "v" ]; then ok "jr-set-exact: new key written"
else bad "jr-set-exact: new key missing"; fi
JR_IN="$JW/uni.json"
jr_case jr-set-case-unicode 2 "set\tstring\tv\ta\tb\tété\n" "set|v|a|b|été"
jr_msg "set: 'été' differs only in case from existing key 'Été'"
JR_IN=""

fresh_home a69
EXC_DIR="$H/repos/aitools-nobul-jose"
EXC_PF="$EXC_DIR/profile.json"
# writable DIR -- undo a read-only fixture so the next setup (rm -rf) can run
writable() { if [ -d "$1" ]; then chmod u+w "$1"; fi; }
exc_case_profile() { exc_profile | perl -0pe 's/("hostname": "nobul-mac.local",\n        "os": "darwin"\n      \})/$1,\n      "ToolExceptions": {}/'; }
setup_a69_case() {
    writable "$EXC_DIR"; rm -rf "$EXC_DIR"
    exc_case_profile | write_profile "$EXC_DIR"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
}
# exception-set on a profile with a hand-written "ToolExceptions": refused by both,
# same lines, profile.json untouched
case_fresh a9-exc-case 2 setup_a69_case "${SET_ARGS[@]}" "${M[@]}"
expect result failed
expect_line "^error\\texception-set failed: set: 'toolExceptions' differs only in case from existing key 'ToolExceptions'$"
if cmp -s "$WORK/a9-exc-case.profile.json" <(exc_case_profile); then ok "a9-exc-case: profile.json untouched"
else bad "a9-exc-case: profile.json changed"; fi

# A temp file that cannot be written: same message in both (A-8), no temp file left (A-7).
# A read-only directory (chmod 555) is POSIX: on Windows chmod does not stop a file
# being created in a directory, so these cases run on macOS/Linux only.
if [ "$LANG_RUN" = sh ]; then
    setup_a69_ro() { writable "$EXC_DIR"; setup_exc_plain; chmod 555 "$EXC_DIR"; }
    NORM_TMP=1 case_fresh a78-exc-ro 2 setup_a69_ro "${SET_ARGS[@]}" "${M[@]}"
    writable "$EXC_DIR"
    expect result failed
    expect_line "^error\\texception-set failed: cannot write $EXC_PF\\.tmp\\.<pid>: Permission denied$"
    if [ -z "$(find "$EXC_DIR" -name 'profile.json.tmp.*')" ]; then ok "a78-exc-ro: no temp file left"
    else bad "a78-exc-ro: temp file left"; fi
    if cmp -s "$WORK/a78-exc-ro.profile.json" <(exc_profile); then ok "a78-exc-ro: profile.json untouched"
    else bad "a78-exc-ro: profile.json changed"; fi
    setup_a69_mig_ro() { writable "$EXC_DIR"; setup_mig_plain; chmod 555 "$EXC_DIR"; }
    NORM_TMP=1 case_fresh a8-mig-ro 2 setup_a69_mig_ro migrate
    writable "$EXC_DIR"
    expect result failed
    expect_line "^error\\tmigrate failed: cannot write $EXC_PF\\.tmp\\.<pid>: Permission denied$"
else
    skip "a78-exc-ro, a8-mig-ro (a read-only directory needs POSIX permissions: macOS/Linux)"
fi
# register --out that cannot be written (read-only directory, missing directory)
exc_profile | write_profile "$H/a8reg"
if [ "$LANG_RUN" = sh ]; then
    mkdir -p "$H/a8ro"
    chmod 555 "$H/a8ro"
    case_run a8-reg-ro 2 register --profile "$H/a8reg/profile.json" --alias nobul-mac --out "$H/a8ro/out.json" "${M[@]}"
    chmod u+w "$H/a8ro"
    expect result failed
    expect_line "^error\\tregister failed: cannot write $H/a8ro/out.json: Permission denied$"
else
    skip "a8-reg-ro (a read-only directory needs POSIX permissions: macOS/Linux)"
fi
case_run a8-reg-nodir 2 register --profile "$H/a8reg/profile.json" --alias nobul-mac --out "$H/a8none/sub/out.json" "${M[@]}"
expect_line "^error\\tregister failed: cannot write $H/a8none/sub/out.json: No such file or directory$"

# snapshot failures reach deploy.log at detail, not only stderr (A-6): one line for
# the one resolver run
A6_RUNS=1
# a6_logged NAME TEXT -- deploy.log has TEXT on A6_RUNS detail lines (Windows: the
# log's native paths read back as $WORK paths)
a6_logged() {
    local n
    cp "$H/.aitools/logs/deploy.log" "$WORK/a6-deploy.log"
    from_native "$WORK/a6-deploy.log"
    n=$(grep -cF "[detail] $2" "$WORK/a6-deploy.log" || true)  # grep -c exits 1 on 0 matches; count checked below
    if [ "$n" = "$A6_RUNS" ]; then ok "$1: logged at detail ($n)"
    else bad "$1: $n detail lines in deploy.log, want $A6_RUNS"; fi
}
case_run a6-snap-missing 1 snapshot --profile "$H/a6none/profile.json"
a6_logged a6-snap-missing "snapshot: profile.json not found: $H/a6none/profile.json"
printf '{ "version": \n' > "$H/a6bad.json"
case_run a6-snap-invalid 2 snapshot --profile "$H/a6bad.json"
a6_logged a6-snap-invalid "snapshot: $H/a6bad.json is invalid JSON"

# --- usage ------------------------------------------------------------------------
case_run usage-unknown 2 resolve --bogus
NO_PARITY=1 case_run usage-nocmd 2   # help text names each platform's sources

printf '\n%s passed, %s failed (%s: aitools-profile.%s)\n' "$PASS" "$FAIL" "$TEST_PLATFORM" "$LANG_RUN"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
