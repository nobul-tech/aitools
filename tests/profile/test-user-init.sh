#!/usr/bin/env bash
# test-user-init.sh -- `aitools user init` (scripts/aitools) and its PowerShell
# counterpart (the user-init block of scripts/aitools.ps1), end to end.
#
# Each case builds an isolated HOME with config.json, a throwaway aitools copy
# (scripts/ + shared/, git-initialised; setup-user-hooks replaced by a stub that
# writes one row and exits $HOOK_RC), a gh stub, and a dotprofile with a local
# bare remote. Machine id and hostname come from the resolver's test overrides
# (AITOOLS_PROFILE_TEST_MACHINE_ID / _HOSTNAME): never the real machine, HOME or
# dotprofile. The bash entry point runs whole; PowerShell runs the block between
# "# --- BEGIN user init ---" and "# --- END user init ---" of aitools.ps1 (the
# file itself has a Windows-only guard) through tests/profile/user-init-harness.ps1,
# on a fresh copy of the same fixture. Asserts exit codes, summary rows,
# profile.json, the remote's commits and the config.json machineId, and that
# both shells give the same exit code, rows, profile.json bytes and commits.
# Interactive cases run on a pty (tests/managed-files/pty-run.py) and compare
# the menus line by line.
# Platform: macOS/Linux (CI: macOS and Linux runners). Safe to re-run.
# Usage: bash tests/profile/test-user-init.sh [--bash-only]
#   AITOOLS_TEST_BASH=/bin/bash runs the entry point under another bash (macOS 3.2)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PTY="$REPO/tests/managed-files/pty-run.py"
HARNESS="$REPO/tests/profile/user-init-harness.ps1"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
USE_PS=true
if [ "${1:-}" = "--bash-only" ] || ! command -v pwsh >/dev/null 2>&1; then USE_PS=false; fi
USE_PTY=true
if ! command -v python3 >/dev/null 2>&1; then USE_PTY=false; fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

THIS_ID="AAAAAAAA-1111-2222-3333-444444444444"   # as macOS reports it (upper case)
THIS_KEY="aaaaaaaa-1111-2222-3333-444444444444"  # the profiles key (lower-cased)
OTHER_ID="bbbbbbbb-1111-2222-3333-444444444444"
GH_USER="nobul-jose"

# The throwaway aitools copy (one per run; each case gets its own copy of it)
SRC="$WORK/src"
mkdir -p "$SRC"
cp -R "$REPO/scripts" "$REPO/shared" "$SRC/"
cat > "$SRC/scripts/setup-user-hooks.sh" <<'STUB'
#!/usr/bin/env bash
# test stub: one summary row, exit $HOOK_RC
if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then printf 'OK|claude hooks|stub\n' >> "$AITOOLS_SUMMARY_FILE"; fi
exit "${HOOK_RC:-0}"
STUB
cat > "$SRC/scripts/setup-user-hooks.ps1" <<'STUB'
# test stub: one summary row, exit $env:HOOK_RC
if ($env:AITOOLS_SUMMARY_FILE) { [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "OK|claude hooks|stub`n") }
$rc = 0; if ($env:HOOK_RC) { $rc = [int]$env:HOOK_RC }
exit $rc
STUB

# gh stub: api user -> $GH_USER; repo view -> exit $GH_REPO_VIEW_RC (default 1: no repo);
# repo create NAME --private --source DIR --push -> a bare remote $GH_REMOTE, pushed
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
    "api user") if [ -n "${GH_USER:-}" ]; then printf '%s\n' "$GH_USER"; exit 0; fi; exit 1 ;;
    "repo view") exit "${GH_REPO_VIEW_RC:-1}" ;;
    "repo create")
        src=""; while [ $# -gt 0 ]; do if [ "$1" = "--source" ]; then src="$2"; fi; shift; done
        git init -q --bare "$GH_REMOTE" || exit 1
        git -C "$src" remote add origin "$GH_REMOTE" || exit 1
        git -C "$src" push -q -u origin main || exit 1
        exit 0 ;;
esac
exit 1
STUB
chmod +x "$WORK/bin/gh"

PJ_TWO='{
  "version": 2,
  "meta": { "schemaRevision": "2.2" },
  "identity": { "github": "nobul-jose", "name": "Jose", "company": "nobul-tech", "git": { "name": "Jose", "email": "jose@example.com" } },
  "profiles": {
    "'$OTHER_ID'": { "alias": "laptop", "machine": { "id": "'$OTHER_ID'", "hostname": "laptop-host" } },
    "nobul-mac": { "machine": { "hostname": "old-host" } }
  }
}'
PJ_LEGACY='{
  "version": 2,
  "identity": { "github": "nobul-jose", "name": "Jose", "git": { "name": "Jose", "email": "jose@example.com" } },
  "profiles": {
    "nobul-mac": { "machine": { "id": "'$THIS_ID'", "hostname": "probe-host", "shell": "zsh" } },
    "laptop": { "machine": { "id": "'$OTHER_ID'", "hostname": "laptop-host" } }
  }
}'

# fixture CASE IMPL PROFILE_JSON [CONFIG_EXTRA] -- HOME, aitools copy, dotprofile with a bare remote.
# PROFILE_JSON "" = a dotprofile without profile.json; "-" = no dotprofile at all.
fixture() {
    local c="$1" impl="$2" pj="$3" extra="${4:-}"
    D="$WORK/$c.$impl"; rm -rf "$D"
    H="$D/home"; R="$D/aitools"; DP="$H/repos/aitools-$GH_USER"; BARE="$D/remote.git"
    mkdir -p "$H/.aitools" "$H/repos"
    cp -R "$SRC" "$R"
    git -C "$R" init -q
    printf '[user]\n\tname = Tester\n\temail = tester@example.com\n[init]\n\tdefaultBranch = main\n' > "$H/.gitconfig"
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s"%s\n}\n' "$H/repos" "$R" "$extra" > "$H/.aitools/config.json"
    if [ "$pj" = "-" ]; then return 0; fi
    git init -q --bare "$BARE"
    mkdir -p "$DP"
    printf 'notes\n' > "$DP/notes.txt"
    # A dotprofile with a profile.json also has its CLAUDE.md template (no scaffold commit)
    if [ -n "$pj" ]; then
        printf '%s\n' "$pj" > "$DP/profile.json"
        mkdir -p "$DP/claude"; printf '# template\n' > "$DP/claude/CLAUDE.md"
    fi
    git -C "$DP" init -q -b main
    git -C "$DP" add -A
    git -C "$DP" -c user.name=T -c user.email=t@x commit -q -m init
    git -C "$DP" remote add origin "$BARE"
    git -C "$DP" push -q -u origin main
}

# run IMPL ARGS... -- user init in the fixture; RC, OUT (console), SUM (summary rows)
run() {
    local impl="$1"; shift
    RC=0
    local e=(env -u AITOOLS_SUMMARY_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_FORCE
        HOME="$H" PATH="$WORK/bin:$PATH" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_PRESERVE_SUMMARY=1
        SHELL=/test/bin/pwsh
        GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_NOSYSTEM=1 GH_USER="$GH_USER" GH_REMOTE="$D/gh-remote.git"
        AITOOLS_PROFILE_TEST_MACHINE_ID="$THIS_ID" AITOOLS_PROFILE_TEST_HOSTNAME=probe-host ${CASE_ENV[@]+"${CASE_ENV[@]}"})
    if [ "$impl" = "bash" ]; then
        if [ -n "${PTY_INPUT:-}" ]; then
            "${e[@]}" python3 "$PTY" --input "$PTY_INPUT" --log "$D/out.txt" --timeout 120 -- "$BASH_BIN" "$R/scripts/aitools" user init "$@" > /dev/null 2>&1 || RC=$?
        else
            "${e[@]}" "$BASH_BIN" "$R/scripts/aitools" user init "$@" < /dev/null > "$D/out.txt" 2>&1 || RC=$?
        fi
    else
        local pa=() a
        while [ $# -gt 0 ]; do
            case "$1" in --alias) pa+=(-Alias "$2"); shift 2 ;; --force) pa+=(-Force); shift ;; *) pa+=("$1"); shift ;; esac
        done
        if [ -n "${PTY_INPUT:-}" ]; then
            "${e[@]}" AITOOLS_PROFILE_TEST_ANY_OS=1 python3 "$PTY" --input "$PTY_INPUT" --log "$D/out.txt" --timeout 120 -- \
                pwsh -NoProfile -File "$HARNESS" -RepoPath "$R" ${pa[@]+"${pa[@]}"} > /dev/null 2>&1 || RC=$?
        else
            "${e[@]}" AITOOLS_PROFILE_TEST_ANY_OS=1 pwsh -NoProfile -File "$HARNESS" -RepoPath "$R" ${pa[@]+"${pa[@]}"} \
                < /dev/null > "$D/out.txt" 2>&1 || RC=$?
        fi
    fi
    OUT="$D/out.txt"
    SUM="$D/summary.txt"
    cp "$H/.aitools/logs/last-summary.txt" "$SUM" 2>/dev/null || : > "$SUM"  # no rows = empty copy (asserted by the cases)
    # Fixture paths differ per shell (CASE.bash / CASE.ps): compared as <D>
    D_RE="$D" perl -pi -e 's/\e\[[0-9;]*m//g; s/\r//g; s/\Q$ENV{D_RE}\E/<D>/g' "$OUT" "$SUM"
}

# case_run NAME WANT_RC SETUP ARGS... -- SETUP IMPL builds the fixture; runs bash, then pwsh
case_run() {
    local name="$1" want="$2" setup="$3"; shift 3
    CASE="$name"
    "$setup" bash
    run bash "$@"
    B_RC=$RC; B_D="$D"
    if [ "$RC" -eq "$want" ]; then ok "$name: bash exit $RC"
    else bad "$name: bash exit $RC, want $want"; perl -pe 's/^/       /' "$OUT"; fi
    if $USE_PS; then
        "$setup" ps
        run ps "$@"
        if [ "$RC" -ne "$B_RC" ]; then bad "$name: pwsh exit $RC, bash $B_RC"; perl -pe 's/^/       /' "$OUT"; else ok "$name: pwsh exit $RC"; fi
        if diff "$B_D/summary.txt" "$D/summary.txt" > "$D/sum.diff"; then ok "$name: summary rows identical"
        else bad "$name: summary rows differ (bash < > pwsh)"; perl -pe 's/^/       /' "$D/sum.diff"; fi
        same_file "home/repos/aitools-$GH_USER/profile.json" "profile.json"
        same_log remote.git "remote commits"
        same_log gh-remote.git "GitHub remote commits"
        D="$B_D"; H="$D/home"; DP="$H/repos/aitools-$GH_USER"; BARE="$D/remote.git"; OUT="$D/out.txt"; SUM="$D/summary.txt"
    fi
}
same_file() {  # same_file REL LABEL -- bash and pwsh fixtures hold the same bytes (both absent is fine)
    if [ ! -e "$B_D/$1" ] && [ ! -e "$D/$1" ]; then return 0; fi
    if cmp -s "$B_D/$1" "$D/$1"; then ok "$CASE: $2 bytes identical"
    else bad "$CASE: $2 differs"; diff "$B_D/$1" "$D/$1" | perl -pe 's/^/       /' || true; fi
}
same_log() {  # same_log BARE LABEL -- the same commit subjects on the remote
    if [ ! -d "$B_D/$1" ] && [ ! -d "$D/$1" ]; then return 0; fi
    local a b
    a=$(git -C "$B_D/$1" log --format=%s main 2>&1) || a="(no log: $a)"
    b=$(git -C "$D/$1" log --format=%s main 2>&1) || b="(no log: $b)"
    if [ "$a" = "$b" ]; then ok "$CASE: $2 identical"; else bad "$CASE: $2 differ"; printf '       bash: %s\n       pwsh: %s\n' "$a" "$b"; fi
}
has_row() { if grep -qxF "$1" "$SUM"; then ok "$CASE: row $1"; else bad "$CASE: no row '$1'"; perl -pe 's/^/       /' "$SUM"; fi; }
no_row_like() { if grep -q -- "$1" "$SUM"; then bad "$CASE: unexpected row /$1/"; perl -pe 's/^/       /' "$SUM"; else ok "$CASE: no row /$1/"; fi; }
out_has() { if grep -qF -- "$1" "$OUT"; then ok "$CASE: output has '$1'"; else bad "$CASE: output lacks '$1'"; perl -pe 's/^/       /' "$OUT"; fi; }
pj_has() {  # pj_has PERL-REGEX -- the bash dotprofile's profile.json matches (whole file)
    if perl -0777 -ne 'BEGIN { $r = shift @ARGV } exit(/$r/s ? 0 : 1)' "$1" "$DP/profile.json"; then ok "$CASE: profile.json /$1/"
    else bad "$CASE: profile.json lacks /$1/"; perl -pe 's/^/       /' "$DP/profile.json" 2>/dev/null || true; fi
}
pj_lacks() {
    if perl -0777 -ne 'BEGIN { $r = shift @ARGV } exit(/$r/s ? 1 : 0)' "$1" "$DP/profile.json"; then ok "$CASE: profile.json has no /$1/"
    else bad "$CASE: profile.json has /$1/"; fi
}
pj_get() {  # pj_get SEG... -- a scalar of the bash dotprofile's profile.json ("" = absent)
    perl "$REPO/scripts/aitools-json.pl" get "$DP/profile.json" "$@" 2>/dev/null || true  # absent = "" (the caller compares)
}
pj_alias() {  # pj_alias KEY ALIAS -- profiles.KEY.alias is ALIAS and its machine.id the key
    local a m
    a=$(pj_get profiles "$1" alias); m=$(pj_get profiles "$1" machine id)
    if [ "$a" = "$2" ] && [ "$(printf '%s' "$m" | tr 'A-Z' 'a-z')" = "$1" ]; then ok "$CASE: profiles.$1 alias $2"
    else bad "$CASE: profiles.$1 alias '$a' id '$m', want alias $2"; perl -pe 's/^/       /' "$DP/profile.json" 2>/dev/null || true; fi
}
pj_no_key() {  # pj_no_key KEY -- profiles has no key KEY
    if perl "$REPO/scripts/aitools-json.pl" type "$DP/profile.json" profiles "$1" > /dev/null 2>&1; then bad "$CASE: profiles.$1 still present"
    else ok "$CASE: no profiles.$1"; fi
}
pj_other_intact() {  # the other machine's profile is untouched
    local a m h
    a=$(pj_get profiles "$OTHER_ID" alias); m=$(pj_get profiles "$OTHER_ID" machine id); h=$(pj_get profiles "$OTHER_ID" machine hostname)
    if [ "$a" = "laptop" ] && [ "$m" = "$OTHER_ID" ] && [ "$h" = "laptop-host" ]; then ok "$CASE: the other machine's profile is untouched"
    else bad "$CASE: other profile changed: alias '$a' id '$m' hostname '$h'"; fi
}
remote_has() {  # remote_has BARE SUBJECT -- a commit with this subject reached the bare remote
    local subjects
    subjects=$(git -C "$1" log --format=%s main 2>/dev/null) || subjects=""  # no branch = no commits (reported below)
    if grep -qxF -- "$2" <<< "$subjects"; then ok "$CASE: remote has '$2'"
    else bad "$CASE: remote lacks '$2'"; git -C "$1" log --format='       %s' main 2>&1 || true; fi
}
remote_count() {  # remote_count BARE N
    local n
    n=$(git -C "$1" rev-list --count main 2>/dev/null) || n=0  # no branch = 0 commits
    if [ "$n" -eq "$2" ]; then ok "$CASE: remote has $2 commit(s)"; else bad "$CASE: remote has $n commit(s), want $2"; fi
}
cfg_id() {  # cfg_id ID -- config.json machineId ("" = absent)
    local v
    v=$(perl "$REPO/scripts/aitools-json.pl" get "$H/.aitools/config.json" machineId 2>/dev/null) || v=""  # absent = ""
    if [ "$v" = "$1" ]; then ok "$CASE: config.json machineId '${1}'"; else bad "$CASE: config.json machineId '$v', want '$1'"; fi
}

CASE_ENV=()
PTY_INPUT=""
fx_two() { fixture "$CASE" "$1" "$PJ_TWO"; }
fx_legacy() { fixture "$CASE" "$1" "$PJ_LEGACY"; }

echo "== decision 1: --alias <new> without a terminal creates this machine's profile (Review3 #82 M1)"
case_run alias-new 0 fx_two --alias spare
pj_alias "$THIS_KEY" spare
pj_has "\"id\": \"$THIS_KEY\""
has_row "OK|machine profile|created (spare)"
remote_has "$BARE" "Register machine profile: spare"
cfg_id "$THIS_KEY"
out_has "────"
# machine.shell (Review3 #82 minor 6): bash records the login shell ($SHELL, here
# /test/bin/pwsh so both shells write the same bytes), aitools.ps1 records pwsh
if [ "$(pj_get profiles "$THIS_KEY" machine shell)" = "pwsh" ]; then ok "$CASE: machine.shell from \$SHELL"
else bad "$CASE: machine.shell '$(pj_get profiles "$THIS_KEY" machine shell)'"; fi

echo "== re-run: verified, no new commit"
CASE="alias-new-rerun"
D="$B_D"; H="$D/home"; DP="$H/repos/aitools-$GH_USER"; BARE="$D/remote.git"
run bash
if [ "$RC" -eq 0 ]; then ok "$CASE: exit 0"; else bad "$CASE: exit $RC"; perl -pe 's/^/       /' "$OUT"; fi
has_row "OK|machine profile|verified (spare)"
remote_count "$BARE" 2

echo "== decision 1: --alias of another machine's profile, no terminal -> refused (exit 1)"
case_run alias-other 1 fx_two --alias laptop
has_row "ERROR|machine profile|alias used by another machine"
pj_lacks "\"$THIS_KEY\""
pj_other_intact
remote_count "$BARE" 1

echo "== an unregistered machine without --alias and without a terminal -> ERROR, exit 1"
case_run unregistered-notty 1 fx_two
has_row "ERROR|machine profile|not registered (no terminal)"
has_row "ACTION||Run: aitools user init --alias <name> (or on a terminal)"

echo "== --alias naming a profile no machine owns: claimed (explicit choice)"
case_run alias-claim 0 fx_two --alias nobul-mac
pj_alias "$THIS_KEY" nobul-mac
pj_no_key nobul-mac

echo "== batch 5: legacy profiles are re-keyed (migrate), the writer's re-key ACTION clears"
case_run migrate 0 fx_legacy
has_row "OK|profile keys|re-keyed by machine id"
pj_alias "$THIS_KEY" nobul-mac
pj_alias "$OTHER_ID" laptop
remote_has "$BARE" "Migrate machine profiles to id keys"
no_row_like "re-keys machine profiles"
cfg_id "$THIS_KEY"

echo "== decision 6: Path 1 without profile.json -> scaffold, committed and pushed"
fx_noprofile() { fixture "$CASE" "$1" ""; }
case_run scaffold-path1 0 fx_noprofile
pj_alias "$THIS_KEY" probe-host
pj_has "\"schemaRevision\": \"2.2\""
pj_has "\"github\": \"$GH_USER\""
remote_has "$BARE" "Register machine profile: probe-host"
remote_has "$BARE" "Add claude/CLAUDE.md template"

echo "== decision 6: Path 3 (no dotprofile) -> created, scaffold reaches the (gh) remote"
fx_none() { fixture "$CASE" "$1" "-"; }
case_run scaffold-path3 0 fx_none --alias first
pj_alias "$THIS_KEY" first
remote_has "$D/gh-remote.git" "Initial commit: profile and session archive structure"
remote_has "$D/gh-remote.git" "Add claude/CLAUDE.md template"
remote_pj=$(git -C "$D/gh-remote.git" show main:profile.json 2>/dev/null) || remote_pj=""  # absent = not pushed (asserted)
if grep -q "\"$THIS_KEY\"" <<< "$remote_pj"; then ok "$CASE: profile.json on the remote"; else bad "$CASE: profile.json not on the remote"; fi
has_row "OK|dotprofile|created"

echo "== decision 2 switch = 0 (default): cached machineAlias, no terminal -> ERROR, exit 1 (same as unregistered)"
fx_cached() { fixture "$CASE" "$1" "$PJ_TWO" ',
  "machineAlias": "nobul-mac"'; }
case_run cached-alias-0 1 fx_cached
has_row "ERROR|machine profile|not registered (no terminal)"
pj_lacks "\"$THIS_KEY\""

echo "== decision 2 switch = 1: cached machineAlias -> claimed without asking"
fx_cached_on() {
    fx_cached "$1"
    # .ps1 files are checked out with CRLF (.gitattributes eol=crlf): \r? before the end
    perl -pi -e 's/^AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0(\r?)$/AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=1$1/; s/^(\$script:RegisterCachedAliasSilently = )\$false(\r?)$/$1\$true$2/' \
        "$R/scripts/aitools" "$R/scripts/aitools.ps1"
}
case_run cached-alias-1 0 fx_cached_on
pj_alias "$THIS_KEY" nobul-mac
sw_sh=$(perl -ne 'print if /^AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=/' "$REPO/scripts/aitools")
sw_ps=$(perl -ne 'print if /^\$script:RegisterCachedAliasSilently = /' "$REPO/scripts/aitools.ps1")
if [ "$sw_sh" = "AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0" ] && [ "${sw_ps%$'\r'}" = '$script:RegisterCachedAliasSilently = $false' ]; then
    ok "decision 2 switch: one line per entry point, default 0 / \$false"
else bad "decision 2 switch line not found (or not at its default) in scripts/aitools / aitools.ps1"; fi

echo "== Review3 #82 minor 5: uncommitted edits to profile.json are never committed"
fx_dirty() { fx_two "$1"; perl -pi -e 's/"old-host"/"edited-host"/' "$DP/profile.json"; }
case_run dirty 1 fx_dirty --alias spare
has_row "ERROR|machine profile|not registered (local edits)"
pj_has '"edited-host"'
pj_lacks "\"$THIS_KEY\""
remote_count "$BARE" 1
fx_dirty_reg() {
    fixture "$CASE" "$1" "$PJ_TWO"
    perl -0pi -e 's/("profiles": \{)/$1\n    "'"$THIS_KEY"'": { "alias": "mine", "machine": { "id": "'"$THIS_KEY"'", "hostname": "probe-host" } },/' "$DP/profile.json"
    git -C "$DP" -c user.name=T -c user.email=t@x commit -q -am "register"; git -C "$DP" push -q
    perl -pi -e 's/"old-host"/"edited-host"/' "$DP/profile.json"
}
case_run dirty-registered 0 fx_dirty_reg
has_row "WARN|machine profile|not refreshed (local edits)"
remote_count "$BARE" 2

echo "== Review3 #82 minor 4: a rejected push (remote ahead) is told to pull --rebase"
fx_ahead() {
    fx_two "$1"
    local w="$D/other"
    git clone -q "$BARE" "$w"; printf 'x\n' > "$w/other.txt"; git -C "$w" add other.txt
    git -C "$w" -c user.name=O -c user.email=o@x commit -q -m other; git -C "$w" push -q origin main
}
case_run push-rejected 0 fx_ahead --alias spare
out_has "git pull --rebase, then git push"
has_row "ACTION||git pull --rebase, then git push in <D>/home/repos/aitools-$GH_USER"
has_row "WARN|machine profile|created (spare)"

echo "== D-TS13: the hooks review aborted (exit 2) -> user init exits 2"
CASE_ENV=(HOOK_RC=2)
case_run hook-abort 2 fx_two --alias spare
CASE_ENV=()

echo "== profile-check.js reads machineId (id keys; legacy machineAlias kept)"
CASE="profile-check"
fixture "$CASE" bash "$PJ_TWO" ',
  "userRepoPath": "'"$WORK"'/profile-check.bash/home/repos/aitools-nobul-jose",
  "machineId": "deadbeef-0000-0000-0000-000000000000"'
pc=$(node "$REPO/scripts/profile-check.js" --config "$H/.aitools/config.json") || pc=""
if grep -q '"code":"MACHINE_ID_UNKNOWN"' <<< "$pc"; then ok "$CASE: unknown machineId reported"; else bad "$CASE: $pc"; fi
if grep -q '"machineId":"deadbeef-0000-0000-0000-000000000000"' <<< "$pc"; then ok "$CASE: machineId in the result"; else bad "$CASE: $pc"; fi
perl -pi -e 's/deadbeef-0000-0000-0000-000000000000/'"$OTHER_ID"'/' "$H/.aitools/config.json"
pc=$(node "$REPO/scripts/profile-check.js" --config "$H/.aitools/config.json") || pc=""
if grep -q 'MACHINE_ID_UNKNOWN' <<< "$pc"; then bad "$CASE: id-keyed machineId reported: $pc"; else ok "$CASE: id-keyed machineId found"; fi
perl -pi -e 's/'"$OTHER_ID"'/'"$THIS_ID"'/' "$H/.aitools/config.json"
perl -pi -e 's/"old-host"/"old-host", "id": "'"$THIS_ID"'"/' "$DP/profile.json"
pc=$(node "$REPO/scripts/profile-check.js" --config "$H/.aitools/config.json") || pc=""
if grep -q 'MACHINE_ID_UNKNOWN' <<< "$pc"; then bad "$CASE: legacy (alias-keyed) profile not read: $pc"; else ok "$CASE: legacy alias-keyed profile found by machine.id"; fi

if $USE_PTY; then
    echo "== interactive (pty): claim an unregistered profile; menus identical in both shells"
    PTY_INPUT=$'1\n'
    case_run pty-claim 0 fx_two
    pj_alias "$THIS_KEY" nobul-mac
    pj_other_intact
    out_has "[-] laptop (registered to another machine)"
    out_has "[1] nobul-mac"
    if $USE_PS; then
        perl -ne 'print if /^Which profile|^  \[|^Choice/' "$B_D/out.txt" | perl -pe 's/Choice: .*/Choice: /' > "$WORK/menu.bash"
        perl -ne 'print if /^Which profile|^  \[|^Choice/' "$WORK/pty-claim.ps/out.txt" | perl -pe 's/Choice: .*/Choice: /' > "$WORK/menu.ps"
        if diff "$WORK/menu.bash" "$WORK/menu.ps" > "$WORK/menu.diff"; then ok "pty-claim: menus identical"
        else bad "pty-claim: menus differ"; perl -pe 's/^/       /' "$WORK/menu.diff"; fi
    fi

    echo "== interactive (pty): hostname suggestion on another machine's profile carries the label (Review3 #82 M2)"
    CASE_ENV=(AITOOLS_PROFILE_TEST_HOSTNAME=laptop-host)
    PTY_INPUT=$'s\n'
    case_run pty-hostname-other 1 fx_two
    out_has "[-] laptop (suggested, registered to another machine)"
    out_has "is registered to another machine"
    has_row "WARN|machine profile|skipped"
    pj_lacks "\"$THIS_KEY\""
    CASE_ENV=()

    echo "== interactive (pty): alias of another machine's profile -> confirm -> shared alias, other profile untouched"
    PTY_INPUT=$'\n\ny\n'
    case_run pty-dup-confirm 0 fx_two --alias laptop
    pj_alias "$THIS_KEY" laptop
    pj_other_intact
    out_has "is used by another machine's profile ($OTHER_ID). Use it for this machine too? [y/N]"

    echo "== interactive (pty): ... declined -> skipped (WARN row; not registered = exit 1)"
    PTY_INPUT=$'\n\nn\n'
    case_run pty-dup-decline 1 fx_two --alias laptop
    has_row "WARN|machine profile|skipped"
    pj_lacks "\"$THIS_KEY\""
    PTY_INPUT=""
fi

echo ""
echo "test-user-init: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
