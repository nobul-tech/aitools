#!/usr/bin/env bash
# test-profile.sh -- unit and parity tests for scripts/aitools-profile.sh and .ps1
#
# Runs every case through the bash resolver and, when pwsh is available, the
# PowerShell resolver (AITOOLS_PROFILE_TEST_ANY_OS=1), with injected machine ids
# and hostnames, in an isolated HOME. Asserts expected values and exit codes, and
# that both implementations print byte-identical output (invalid-JSON parser
# messages are cut after "is invalid JSON"; each engine words them differently).
# Platform: macOS/Linux (CI: macOS and Linux runners). Safe to re-run.
# Usage: bash tests/profile/test-profile.sh [--bash-only]
#   AITOOLS_TEST_BASH=/bin/bash runs the resolver under another bash (e.g. macOS 3.2)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH="$REPO/scripts/aitools-profile.sh"
PS="$REPO/scripts/aitools-profile.ps1"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
USE_PS=true
if [ "${1:-}" = "--bash-only" ] || ! command -v pwsh >/dev/null 2>&1; then USE_PS=false; fi
PLATFORM_LINUX=false
if [ "$(uname -s)" = "Linux" ]; then PLATFORM_LINUX=true; fi

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

ID_MAC="3D4DF2A5-7D91-5AF9-9944-4FEEBAAE3CF5"
ID_OTHER="0B1C2D3E-0000-1111-2222-333344445555"

# fresh_home NAME -- isolated HOME with ~/repos and ~/.aitools; sets H
fresh_home() {
    H="$WORK/$1/home"
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

# run_impl IMPL OUTFILE ARGS... -- run one implementation in the isolated HOME;
# sets RC. Environment for the case comes from CASE_ENV (KEY=VALUE words).
run_impl() {
    local impl="$1" out="$2"; shift 2
    RC=0
    if [ "$impl" = "bash" ]; then
        env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" $CASE_ENV "$BASH_BIN" "$SH" "$@" > "$out" 2>"$out.err" || RC=$?
    else
        env HOME="$H" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_PROFILE_TEST_ANY_OS=1 $CASE_ENV \
            pwsh -NoProfile -File "$PS" "$@" > "$out" 2>"$out.err" || RC=$?
    fi
}

normalize() { perl -pe 's/( is invalid JSON).*/$1/' "$1"; }

# case_run NAME EXPECTED_RC ARGS... -- run bash (and pwsh), check rc and parity.
# Leaves the bash output in $OUT for value assertions.
case_run() {
    local name="$1" want="$2"; shift 2
    CASE="$name"
    OUT="$WORK/$name.bash.out"
    run_impl bash "$OUT" "$@"
    local brc=$RC
    if [ "$brc" -eq "$want" ]; then ok "$name: bash exit $brc"
    else bad "$name: bash exit $brc, want $want"; sed 's/^/       /' "$OUT" "$OUT.err"; fi
    if $USE_PS && [ "${NO_PARITY:-}" != "1" ]; then
        local pout="$WORK/$name.ps.out"
        run_impl ps "$pout" "$@"
        if [ "$RC" -ne "$brc" ]; then bad "$name: pwsh exit $RC, bash $brc"; sed 's/^/       /' "$pout.err"; fi
        if diff <(normalize "$OUT") <(normalize "$pout") > "$WORK/$name.diff"; then ok "$name: bash and pwsh output identical"
        else bad "$name: bash and pwsh output differ"; sed 's/^/       /' "$WORK/$name.diff"; fi
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
printf 'aitools-profile tests (pwsh parity: %s)\n' "$USE_PS"

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
printf '{ "userRepoPath": "%s" }\n' "$H/elsewhere/dp/" > "$H/.aitools/config.json"
case_run urp-config 0 user-repo-path
expect path "$H/elsewhere/dp"; expect via config

fresh_home urp-config-stale
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "userRepoPath": "%s", "githubUser": "nobul-jose" }\n' "$H/gone" > "$H/.aitools/config.json"
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
expect_line '^error\tprofile.json is not v2 or has no profiles'

fresh_home rm-profile-file
CASE_ENV="AITOOLS_PROFILE_FILE=$H/missing.json"
case_run rm-profile-file-missing 2 resolve "${M[@]}"
expect_line '^error\tprofile file set but missing: .*\(AITOOLS_PROFILE_FILE\)'
base_profile > "$H/snap.json"
CASE_ENV="AITOOLS_PROFILE_FILE=$H/snap.json"
case_run rm-profile-file 0 resolve "${M[@]}"
expect alias nobul-mac; expect profileFile "$H/snap.json"
CASE_ENV=""

if $PLATFORM_LINUX; then
    fresh_home rm-web
    base_profile | perl -0pe 's/"os": "win32"/"os": "win32",\n        "environment": "claude-code-web"/' \
        | write_profile "$H/repos/aitools-nobul-jose"
    printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
    case_run rm-web 0 resolve "${M[@]}" --environment claude-code-web
    expect alias workstation; expect via environment; expect environment claude-code-web
else
    printf '  skip rm-web (claude-code-web exists only on Linux)\n'
fi

fresh_home rm-json
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "githubUser": "nobul-jose" }\n' > "$H/.aitools/config.json"
case_run rm-json 0 resolve "${M[@]}" --json --alias laptop
expect_line '^\{"alias":"laptop","via":"override",.*"warnings":\["profile \\"laptop\\" has no machine.id.*"\],"errors":\[\]\}$'

# --- derive-config -------------------------------------------------------------
fresh_home dc
base_profile | write_profile "$H/repos/aitools-nobul-jose"
printf '{ "reposPath": "%s" }\n' "$H/repos" > "$H/.aitools/config.json"
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
expect derived.userRepoPath ""; expect derived.githubUser nobul-jose; expect derived.machineAlias nobul-mac
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
ARCH=$(uname -m); case "$ARCH" in x86_64|amd64) ARCH=x64 ;; arm64|aarch64) ARCH=arm64 ;; esac
OSNAME=darwin; if $PLATFORM_LINUX; then OSNAME=linux; fi
perl -pi -e "s/\"ARCH\"/\"$ARCH\"/; s/\"os\": \"darwin\"/\"os\": \"$OSNAME\"/" "$H/p.json"
case_run reg-update 0 register --profile "$H/p.json" --alias nobul-mac --shell bash --out "$H/out.bash.json" "${M[@]}"
expect result updated; expect machineId "$ID_MAC"
diff "$H/p.json" "$H/out.bash.json" > "$WORK/reg.diff" || true  # differences expected; counted below
if perl -ne '$n++ if /^[<>]/; END { exit($n == 3 ? 0 : 1) }' "$WORK/reg.diff"; then
    ok "reg-update: only the machine.id line was added (other bytes kept)"
else
    bad "reg-update: unexpected changes"; diff "$H/p.json" "$H/out.bash.json" | sed 's/^/       /' || true
fi
if $USE_PS; then
    run_impl ps "$WORK/reg-ps.out" register --profile "$H/p.json" --alias nobul-mac --shell bash --out "$H/out.ps.json" "${M[@]}"
    if cmp -s "$H/out.bash.json" "$H/out.ps.json"; then ok "reg-update: bash and pwsh wrote identical bytes"
    else bad "reg-update: written files differ"; diff "$H/out.bash.json" "$H/out.ps.json" | sed 's/^/       /' || true; fi
fi
case_run reg-unchanged 0 register --profile "$H/out.bash.json" --alias nobul-mac --shell bash --out "$H/out2.json" "${M[@]}"
expect result unchanged
if cmp -s "$H/out.bash.json" "$H/out2.json"; then ok "reg-unchanged: file bytes stable"; else bad "reg-unchanged: file changed"; fi

case_run reg-new-alias 0 register --profile "$H/out.bash.json" --alias spare --name Pepe --company Other \
    --out "$H/out3.json" --machine-id-value "$ID_OTHER" --hostname-value spare-host
expect result created
OUT="$H/out3.json"
CASE=reg-new-alias-file
expect_line '"spare": \{'
expect_line '"name": "Pepe"'
expect_line '"company": "Other"'
expect_line '"id": "0B1C2D3E-0000-1111-2222-333344445555"'

case_run reg-dup-id 2 register --profile "$H/out.bash.json" --alias spare --out "$H/out4.json" "${M[@]}"
expect_line '^error\tmachine.id 3D4DF2A5.* is already registered on profile "nobul-mac"'

fresh_home reg-create
case_run reg-create 0 register --profile "$H/new/profile.json" --alias nobul-mac --create --github-user nobul-jose \
    --email jose@nobul.tech --name Jose --company nobul-tech --shell zsh --out "$H/created.bash.json" "${M[@]}"
expect result created
if $USE_PS; then
    mkdir -p "$H/new"
    run_impl ps "$WORK/reg-create-ps.out" register --profile "$H/new/profile.json" --alias nobul-mac --create \
        --github-user nobul-jose --email jose@nobul.tech --name Jose --company nobul-tech --shell zsh --out "$H/created.ps.json" "${M[@]}"
    if cmp -s "$H/created.bash.json" "$H/created.ps.json"; then ok "reg-create: bash and pwsh wrote identical bytes"
    else bad "reg-create: written files differ"; diff "$H/created.bash.json" "$H/created.ps.json" | sed 's/^/       /' || true; fi
fi
OUT="$H/created.bash.json"; CASE=reg-create-file
expect_line '^  "version": 2,$'
expect_line '^    "company": "nobul-tech",$'
if perl -0ne 'exit(/"nobul-mac": \{\n\s+"machine": \{/ ? 0 : 1)' "$OUT"; then ok "reg-create-file: no per-profile name/company (identity holds them)"
else bad "reg-create-file: per-profile name/company written"; fi

case_run reg-missing-nocreate 1 register --profile "$H/none.json" --alias x --out "$H/o.json" "${M[@]}"
case_run reg-bad-alias 2 register --profile "$H/none.json" --alias "bad alias" --out "$H/o.json" "${M[@]}"

# --- tool exceptions -----------------------------------------------------------------
# case_fresh NAME RC SETUP ARGS... -- like case_run, but SETUP rebuilds the fixture
# before each implementation (exception-set changes state).
case_fresh() {
    local name="$1" want="$2" setup="$3"; shift 3
    CASE="$name"
    OUT="$WORK/$name.bash.out"
    "$setup"
    run_impl bash "$OUT" "$@"
    local brc=$RC
    cp "$EXC_PF" "$WORK/$name.bash.profile.json" 2>/dev/null || : > "$WORK/$name.bash.profile.json"  # absent profile = empty copy
    if [ "$brc" -eq "$want" ]; then ok "$name: bash exit $brc"
    else bad "$name: bash exit $brc, want $want"; sed 's/^/       /' "$OUT" "$OUT.err"; fi
    if $USE_PS; then
        local pout="$WORK/$name.ps.out"
        "$setup"
        run_impl ps "$pout" "$@"
        cp "$EXC_PF" "$WORK/$name.ps.profile.json" 2>/dev/null || : > "$WORK/$name.ps.profile.json"  # absent profile = empty copy
        if [ "$RC" -ne "$brc" ]; then bad "$name: pwsh exit $RC, bash $brc"; sed 's/^/       /' "$pout" "$pout.err"; fi
        if diff "$OUT" "$pout" > "$WORK/$name.diff"; then ok "$name: bash and pwsh output identical"
        else bad "$name: bash and pwsh output differ"; sed 's/^/       /' "$WORK/$name.diff"; fi
        if cmp -s "$WORK/$name.bash.profile.json" "$WORK/$name.ps.profile.json"; then ok "$name: profile.json bytes identical"
        else bad "$name: profile.json differs"; diff "$WORK/$name.bash.profile.json" "$WORK/$name.ps.profile.json" | sed 's/^/       /' || true; fi
    fi
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
OUT="$WORK/exc-set-git.bash.profile.json"; CASE=exc-set-git-file
if perl -0ne 'exit(/"toolExceptions": \{\n        "go": \{\n          "decision": "keep",\n          "detected": \{\n            "platform": "macos",\n            "method": "pkg-installer",\n            "path": "\/usr\/local\/bin\/go",\n            "version": "1.22.5"\n          \},\n          "decidedAt": "2026-10-21T12:00:00Z",\n          "decidedBy": "setup-go",\n          "reason": null\n        \}/ ? 0 : 1)' "$OUT"; then
    ok "exc-set-git: entry shape and order as reference/user-repo.md"
else bad "exc-set-git: entry shape"; sed 's/^/       /' "$OUT"; fi
committed_files=$(git -C "$EXC_DIR" show --name-only --format=%s HEAD | perl -ne 'print if /\S/' | paste -sd '|' -)
if [ "$committed_files" = "Record tool exception: keep go (pkg-installer) on nobul-mac|profile.json" ]; then
    ok "exc-set-git: commit holds only profile.json (staged other.txt left alone)"
else bad "exc-set-git: commit was '$committed_files'"; fi
if [ "$(git -C "$EXC_REMOTE" rev-parse HEAD)" = "$(git -C "$EXC_DIR" rev-parse HEAD)" ]; then ok "exc-set-git: pushed to the remote"
else bad "exc-set-git: remote not updated"; fi

# The state left by the PowerShell run (or bash when pwsh is absent) feeds the reads below
case_run exc-get 0 exception-get --slug go "${M[@]}"
expect found true; expect platform macos; expect method pkg-installer; expect path /usr/local/bin/go
expect version 1.22.5; expect decidedAt 2026-10-21T12:00:00Z; expect decidedBy setup-go; expect reason ""
case_run exc-get-other 0 exception-get --slug typst "${M[@]}"
expect found false; expect alias nobul-mac
case_run exc-set-unchanged 0 "${SET_ARGS[@]}" "${M[@]}"
expect result unchanged; expect committed false

setup_exc_noident() {
    setup_exc_git
    git -C "$EXC_DIR" config --unset user.name
    git -C "$EXC_DIR" config --unset user.email
    # A distinctive owner, so the assertion cannot pass on the real global identity
    perl -pi -e 's/jose\@nobul\.tech/owner\@example.test/g' "$EXC_PF"
}
case_fresh exc-set-noident 0 setup_exc_noident "${SET_ARGS[@]}" "${M[@]}"
expect committed true
author=$(git -C "$EXC_DIR" log -1 --format='%an <%ae>')
if [ "$author" = "Jose <owner@example.test>" ]; then ok "exc-set-noident: committed as the profile's identity.git"
else bad "exc-set-noident: author '$author'"; fi

case_fresh exc-set-plain 0 setup_exc_plain "${SET_ARGS[@]}" "${M[@]}" --reason "corporate MDM pin"
expect result created; expect committed false
expect_line '^warn\t.* is not a git repository -- profile.json written but not committed$'
OUT="$WORK/exc-set-plain.bash.profile.json"; CASE=exc-set-plain-file
expect_line '"reason": "corporate MDM pin"'

case_fresh exc-set-hostname 3 setup_exc_hostname "${SET_ARGS[@]}" "${M[@]}"
expect result refused; expect via hostname
expect_line '^error\tmachine profile "nobul-mac" matched by hostname only -- run: aitools user init to remember tool choices$'
if cmp -s "$WORK/exc-set-hostname.bash.profile.json" <(base_profile); then ok "exc-set-hostname: profile.json untouched"
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
if cmp -s "$WORK/exc-set-dry.bash.profile.json" <(exc_profile); then ok "exc-set-dry: profile.json untouched"
else bad "exc-set-dry: profile.json changed"; fi
CASE_ENV=""

case_fresh exc-get-none 2 setup_exc_hostname exception-get --slug go --machine-id-value "$ID_OTHER" --hostname-value elsewhere
expect found false; expect_line '^error\tno profile matches this machine'
case_run exc-bad-platform 2 exception-set --slug go --platform darwin --method m --path /p --by setup-go "${M[@]}"
case_run exc-bad-slug 2 exception-get --slug "Go Lang" "${M[@]}"

# --- usage ------------------------------------------------------------------------
case_run usage-unknown 2 resolve --bogus
NO_PARITY=1 case_run usage-nocmd 2   # help text names each platform's sources
if $USE_PS; then
    run_impl ps "$WORK/usage-ps.out"
    if [ "$RC" -eq 2 ]; then ok "usage-nocmd: pwsh exit 2"; else bad "usage-nocmd: pwsh exit $RC"; fi
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
