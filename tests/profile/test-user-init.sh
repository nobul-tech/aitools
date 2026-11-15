#!/usr/bin/env bash
# test-user-init.sh -- `aitools user init` (scripts/aitools), end to end.
#
# Each case builds an isolated HOME with config.json, a throwaway aitools copy
# (scripts/ + shared/, git-initialised; setup-user-hooks replaced by a stub that
# writes one row and exits $HOOK_RC), a gh stub, and a dotprofile with a local
# bare remote. Machine id and hostname come from the resolver's test overrides
# (AITOOLS_PROFILE_TEST_MACHINE_ID / _HOSTNAME): never the real machine, HOME or
# dotprofile. Asserts exit codes, summary rows, profile.json, the remote's
# commits and the config.json machineId.
# M3-FINISH item 2: an unregistered machine runs the writer with --no-machine /
# -NoMachine and gets one machine-profile ERROR (user init's), none of the
# writer's; a registered machine (also one whose id cannot be detected) does not.
# Interactive cases run on a pseudo-terminal (tests/managed-files/pty-run.py,
# POSIX pty; SKIP when python3 is unavailable).
#
# Platform targeting (plans/ci-platform-targeting.md; commander 2026-11-14:
# "sh scripts and tests should only run on linux/mac and ps1 on windows"):
# this harness runs the bash entry point scripts/aitools on macOS/Linux and
# refuses Windows; scripts/aitools.ps1 is tested on Windows by
# tests/profile/test-user-init.ps1. Parity between the two is checked against
# committed golden results, one per case: exit code, summary rows, profile.json
# (this machine's machine.os / machine.arch as <OS> / <ARCH>) and the commit
# subjects on both remotes (fixture directory as <D>, path separators as /), plus
# the pty-claim menu: tests/profile/golden/userinit-*.txt
# (tests/lib/platform-lib.sh golden_match). AITOOLS_TEST_UPDATE_GOLDEN=1 on
# macOS/Linux rewrites them from the bash run.
#
# Safe to re-run: everything lives in a temp directory (removed on exit). Exit 1
# on failure.
# Usage: bash tests/profile/test-user-init.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: the harness always runs only the bash entry point
#   AITOOLS_TEST_BASH=/bin/bash runs the bash entry point under another bash (macOS 3.2)

set -euo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/profile/test-user-init.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/profile/test-user-init.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'last unless /^#/; print if $. > 1' "$0"
    exit 0
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$REPO/tests/lib/platform-lib.sh"
PTY="$REPO/tests/managed-files/pty-run.py"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
GOLDEN_DIR="$REPO/tests/profile/golden"
GOLDEN_TMP="$WORK"
LANG_RUN="$TEST_LANG"   # sh: the bash entry point (macOS/Linux)

PASS=0
FAIL=0
SKIP=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

USE_PTY=true
command -v python3 >/dev/null 2>&1 || USE_PTY=false   # no python3: the pty cases SKIP (reported below)

THIS_ID="AAAAAAAA-1111-2222-3333-444444444444"   # as macOS reports it (upper case)
THIS_KEY="aaaaaaaa-1111-2222-3333-444444444444"  # the profiles key (lower-cased)
OTHER_ID="bbbbbbbb-1111-2222-3333-444444444444"
GH_USER="nobul-jose"
case "$TEST_PLATFORM" in macos) THIS_OS=darwin ;; *) THIS_OS=linux ;; esac

# The throwaway aitools copy (one per run; each case gets its own copy of it)
SRC="$WORK/src"
mkdir -p "$SRC"
cp -R "$REPO/scripts" "$REPO/shared" "$SRC/"
cat > "$SRC/scripts/setup-user-hooks.sh" <<'STUB'
#!/usr/bin/env bash
# test stub: one structured warn line when HOOK_WARN=1, one summary row, exit $HOOK_RC
if [ "${HOOK_WARN:-}" = "1" ]; then printf '[2026-01-01T00:00:00Z] [setup-user-hooks] [warn] stub hook warning\n'; fi
if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then printf 'OK|claude hooks|stub\n' >> "$AITOOLS_SUMMARY_FILE"; fi
exit "${HOOK_RC:-0}"
STUB
cat > "$SRC/scripts/setup-user-hooks.ps1" <<'STUB'
# test stub: one structured warn line when HOOK_WARN=1, one summary row, exit $env:HOOK_RC
if ($env:HOOK_WARN -eq "1") { Write-Host "[2026-01-01T00:00:00Z] [setup-user-hooks] [warn] stub hook warning" }
if ($env:AITOOLS_SUMMARY_FILE) { [IO.File]::AppendAllText($env:AITOOLS_SUMMARY_FILE, "OK|claude hooks|stub`n") }
$rc = 0; if ($env:HOOK_RC) { $rc = [int]$env:HOOK_RC }
exit $rc
STUB

# gh stub: api user -> $GH_USER; repo view -> exit $GH_REPO_VIEW_RC (default 1: no repo);
# repo clone U/R DIR -> clone of $GH_CLONE_SRC; repo create NAME --private --source DIR
# --push -> a bare remote $GH_REMOTE, pushed
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
    "api user") if [ -n "${GH_USER:-}" ]; then printf '%s\n' "$GH_USER"; exit 0; fi; exit 1 ;;
    "repo view") exit "${GH_REPO_VIEW_RC:-1}" ;;
    "repo clone") git clone -q -b main "$GH_CLONE_SRC" "$4" || exit 1; exit 0 ;;
    "repo create")
        src=""; while [ $# -gt 0 ]; do if [ "$1" = "--source" ]; then src="$2"; fi; shift; done
        git init -q --bare -b main "$GH_REMOTE" || exit 1
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

# fixture CASE PROFILE_JSON [CONFIG_EXTRA] -- HOME, aitools copy, dotprofile with a bare remote.
# PROFILE_JSON "" = a dotprofile without profile.json; "-" = no dotprofile at all.
fixture() {
    local c="$1" pj="$2" extra="${3:-}"
    D="$WORK/$c"; rm -rf "$D"
    H="$D/home"; R="$D/aitools"; DP="$H/repos/aitools-$GH_USER"; BARE="$D/remote.git"
    mkdir -p "$H/.aitools" "$H/repos"
    cp -R "$SRC" "$R"
    git -C "$R" init -q
    printf '[user]\n\tname = Tester\n\temail = tester@example.com\n[init]\n\tdefaultBranch = main\n' > "$H/.gitconfig"
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s"%s\n}\n' "$H/repos" "$R" "$extra" > "$H/.aitools/config.json"
    if [ "$pj" = "-" ]; then return 0; fi
    git init -q --bare -b main "$BARE"
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

# norm_run FILE... -- in place: terminal control sequences (SGR colours, cursor
# moves, cursor-forward as spaces, mode and title sequences) and CR removed; the
# fixture directory replaced by <D>, with backslashes in the rest of that path
# turned into slashes.
norm_run() {
    D_P="$D" perl -pi -e '
        s/\e\[(\d*)C/" " x ($1 || 1)/ge;
        s/\e\[[0-9;?]*[ -\/]*[@-~]//g;
        s/\e\][^\a\e]*(?:\a|\e\\)//g;
        s/\r//g;
        for my $t (grep { length } @ENV{qw(D_P)}) {
            s/\Q$t\E([^\s|"]*)/my $r = $1; $r =~ tr{\\}{\/}; "<D>$r"/ge;
        }' "$@"
}

# run ARGS... -- user init of the bash entry point in the fixture; RC, OUT
# (console), SUM (summary rows), both normalized
run() {
    RC=0
    local here="$PWD"
    cd "$D"
    local e
    e=(env -u AITOOLS_SUMMARY_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_FORCE
        HOME="$H" PATH="$WORK/bin:$PATH" AITOOLS_LOG_DIR="$H/.aitools/logs" AITOOLS_PRESERVE_SUMMARY=1
        SHELL=/test/bin/pwsh
        GIT_CONFIG_GLOBAL="$H/.gitconfig" GIT_CONFIG_NOSYSTEM=1 GH_USER="$GH_USER" GH_REMOTE="$D/gh-remote.git" GH_CLONE_SRC="$D/remote.git"
        AITOOLS_PROFILE_TEST_MACHINE_ID="$THIS_ID" AITOOLS_PROFILE_TEST_HOSTNAME=probe-host ${CASE_ENV[@]+"${CASE_ENV[@]}"})
    if [ -n "${PTY_INPUT:-}" ]; then
        "${e[@]}" python3 "$PTY" --input "$PTY_INPUT" --log "$D/out.txt" -- "$BASH_BIN" "$R/scripts/aitools" user init "$@" > /dev/null 2>&1 || RC=$?
    else
        "${e[@]}" "$BASH_BIN" "$R/scripts/aitools" user init "$@" < /dev/null > "$D/out.txt" 2>&1 || RC=$?
    fi
    cd "$here"
    OUT="$D/out.txt"
    SUM="$D/summary.txt"
    cp "$H/.aitools/logs/last-summary.txt" "$SUM" 2>/dev/null || : > "$SUM"  # no rows = empty copy (asserted by the cases)
    norm_run "$OUT" "$SUM"
}

# norm_pj FILE -- profile.json as compared: CR removed; this machine's machine.os and
# machine.arch (platform facts written by register) as <OS> and <ARCH>
norm_pj() {
    THIS_KEY="$THIS_KEY" perl -0777 -pe '
        s/\r//g;
        my $k = $ENV{THIS_KEY};
        s{("\Q$k\E"\s*:\s*)(?<o>\{(?:[^{}"]++|"(?:[^"\\]++|\\.)*+"|(?&o))*+\})}{
            my ($p, $obj) = ($1, $+{o});
            $obj =~ s/("os"\s*:\s*)"[^"]*"/$1"<OS>"/;
            $obj =~ s/("arch"\s*:\s*)"[^"]*"/$1"<ARCH>"/;
            "$p$obj"
        }ge' "$1"
}
# log_subjects BARE -- commit subjects on main of a bare remote ("(none)" when absent)
log_subjects() {
    if [ ! -d "$1" ]; then printf '(none)\n'; return 0; fi
    git -C "$1" log --format=%s main 2>&1 || printf '(no main branch)\n'  # shown in the golden diff
}
# result_golden [NAME] -- this case's result (exit code, summary rows, profile.json,
# remote commits) must equal the golden file userinit-NAME.txt (sh and ps1 share it;
# NAME defaults to this case's name). A case that only compares with another
# case's golden (NAME given) never writes it under AITOOLS_TEST_UPDATE_GOLDEN=1.
result_golden() {
    local g="${1:-$CASE}" f="$D/result.txt"
    {
        printf 'exit %s\n-- summary rows\n' "$RC"; cat "$SUM"
        printf -- '-- profile.json\n'
        if [ -f "$DP/profile.json" ]; then norm_pj "$DP/profile.json"; else printf '(none)\n'; fi
        printf -- '-- remote.git commits\n'; log_subjects "$D/remote.git"
        printf -- '-- gh-remote.git commits\n'; log_subjects "$D/gh-remote.git"
    } > "$f"
    if [ "$g" != "$CASE" ] && [ "${AITOOLS_TEST_UPDATE_GOLDEN:-}" = "1" ]; then
        printf '      | %s: compared with userinit-%s.txt, not written\n' "$CASE" "$g"; return 0
    fi
    if golden_match "userinit-$g.txt" "$f"; then ok "$CASE: exit, rows, profile.json and commits match golden${1:+ userinit-$g.txt}"
    else bad "$CASE: result differs from golden userinit-$g.txt"; fi
}

# case_run NAME WANT_RC SETUP ARGS... -- SETUP builds the fixture; one run, then the golden
case_run() {
    local name="$1" want="$2" setup="$3"; shift 3
    CASE="$name"
    "$setup"
    run "$@"
    if [ "$RC" -eq "$want" ]; then ok "$name: $LANG_RUN exit $RC"
    else bad "$name: $LANG_RUN exit $RC, want $want"; perl -pe 's/^/       /' "$OUT"; fi
    result_golden
}
has_row() { if grep -qxF "$1" "$SUM"; then ok "$CASE: row $1"; else bad "$CASE: no row '$1'"; perl -pe 's/^/       /' "$SUM"; fi; }
no_row_like() { if grep -q -- "$1" "$SUM"; then bad "$CASE: unexpected row /$1/"; perl -pe 's/^/       /' "$SUM"; else ok "$CASE: no row /$1/"; fi; }
out_has() { if grep -qF -- "$1" "$OUT"; then ok "$CASE: output has '$1'"; else bad "$CASE: output lacks '$1'"; perl -pe 's/^/       /' "$OUT"; fi; }
# out_count STRING N -- the console output has STRING exactly N times
out_count() {
    local n
    n=$(perl -0777 -ne 'BEGIN { $s = shift @ARGV } $n++ while /\Q$s\E/g; END { print $n + 0 }' "$1" "$OUT")
    if [ "$n" -eq "$2" ]; then ok "$CASE: output has '$1' $2 time(s)"
    else bad "$CASE: output has '$1' $n time(s), want $2"; perl -pe 's/^/       /' "$OUT"; fi
}
# log_has STRING -- the case HOME's deploy.log has STRING (fixed string)
log_has() {
    local lf="$H/.aitools/logs/deploy.log"
    if [ -f "$lf" ] && grep -qF -- "$1" "$lf"; then ok "$CASE: deploy.log has '$1'"
    else bad "$CASE: deploy.log lacks '$1'"; if [ -f "$lf" ]; then perl -ne 'print "       $_" if /menu answer/' "$lf"; fi; fi
}
pj_has() {  # pj_has PERL-REGEX -- the dotprofile's profile.json matches (whole file)
    if perl -0777 -ne 'BEGIN { $r = shift @ARGV } exit(/$r/s ? 0 : 1)' "$1" "$DP/profile.json"; then ok "$CASE: profile.json /$1/"
    else bad "$CASE: profile.json lacks /$1/"; perl -pe 's/^/       /' "$DP/profile.json" 2>/dev/null || true; fi  # absent file: the FAIL above says so
}
pj_lacks() {
    if perl -0777 -ne 'BEGIN { $r = shift @ARGV } exit(/$r/s ? 1 : 0)' "$1" "$DP/profile.json"; then ok "$CASE: profile.json has no /$1/"
    else bad "$CASE: profile.json has /$1/"; fi
}
pj_get() {  # pj_get SEG... -- a scalar of the dotprofile's profile.json ("" = absent)
    perl "$REPO/scripts/aitools-json.pl" get "$DP/profile.json" "$@" 2>/dev/null || true  # absent = "" (the caller compares)
}
pj_alias() {  # pj_alias KEY ALIAS -- profiles.KEY.alias is ALIAS and its machine.id the key
    local a m
    a=$(pj_get profiles "$1" alias); m=$(pj_get profiles "$1" machine id)
    if [ "$a" = "$2" ] && [ "$(printf '%s' "$m" | tr 'A-Z' 'a-z')" = "$1" ]; then ok "$CASE: profiles.$1 alias $2"
    else bad "$CASE: profiles.$1 alias '$a' id '$m', want alias $2"; perl -pe 's/^/       /' "$DP/profile.json" 2>/dev/null || true; fi  # absent file: the FAIL above says so
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
    else bad "$CASE: remote lacks '$2'"; git -C "$1" log --format='       %s' main 2>&1 || true; fi  # the listing is diagnostic only
}
remote_count() {  # remote_count BARE N
    local n
    n=$(git -C "$1" rev-list --count main 2>/dev/null) || n=0  # no branch = 0 commits
    if [ "$n" -eq "$2" ]; then ok "$CASE: remote has $2 commit(s)"; else bad "$CASE: remote has $n commit(s), want $2"; fi
}
row_count() {  # row_count PREFIX N -- exactly N summary rows start with PREFIX
    local n
    n=$(perl -ne 'BEGIN { $p = shift @ARGV } $n++ if index($_, $p) == 0; END { print $n + 0 }' "$1" "$SUM")
    if [ "$n" -eq "$2" ]; then ok "$CASE: $2 row(s) '$1'"; else bad "$CASE: $n row(s) '$1', want $2"; perl -pe 's/^/       /' "$SUM"; fi
}
# no_machine_flag yes|no -- M3-FINISH item 2: whether setup-user-config ran with
# --no-machine (bash) / -NoMachine (pwsh), read from its info line in the output
no_machine_flag() {
    local got
    if grep -qF "machine registration is left to the caller" "$OUT"; then got=yes; else got=no; fi
    if [ "$got" = "$1" ]; then ok "$CASE ($LANG_RUN): writer flag --no-machine $1"
    else bad "$CASE ($LANG_RUN): writer flag --no-machine $got, want $1"; perl -pe 's/^/       /' "$OUT"; fi
}
# unregistered_once -- the machine-profile outcome is reported once, by user init:
# one "machine profile" ERROR row, none of the writer's (no machine match, its ACTION)
unregistered_once() {
    row_count "ERROR|machine profile|" 1
    no_row_like "no machine match"
    no_row_like "ACTION||Run: aitools user init (profiles:"
    no_machine_flag yes
}
cfg_id() {  # cfg_id ID -- config.json machineId ("" = absent)
    local v
    v=$(perl "$REPO/scripts/aitools-json.pl" get "$H/.aitools/config.json" machineId 2>/dev/null) || v=""  # absent = ""
    if [ "$v" = "$1" ]; then ok "$CASE: config.json machineId '${1}'"; else bad "$CASE: config.json machineId '$v', want '$1'"; fi
}

printf 'user init tests (%s: %s entry point)\n' "$TEST_PLATFORM" "$LANG_RUN"
CASE_ENV=()
PTY_INPUT=""
fx_two() { fixture "$CASE" "$PJ_TWO"; }
fx_legacy() { fixture "$CASE" "$PJ_LEGACY"; }

echo "== decision 1: --alias <new> without a terminal creates this machine's profile (Review3 #82 M1)"
case_run alias-new 0 fx_two --alias spare
pj_alias "$THIS_KEY" spare
pj_has "\"id\": \"$THIS_KEY\""
has_row "OK|machine profile|created (spare)"
remote_has "$BARE" "Register machine profile: spare"
cfg_id "$THIS_KEY"
# the summary panel: box rule (bash; aitools-lib.ps1 Show-Summary draws a dashed
# rule, checked by test-user-init.ps1)
out_has "────"
no_machine_flag no
# machine.shell (Review3 #82 minor 6): bash records the login shell ($SHELL, here
# /test/bin/pwsh so both entry points write the same bytes), aitools.ps1 records pwsh
if [ "$(pj_get profiles "$THIS_KEY" machine shell)" = "pwsh" ]; then ok "$CASE: machine.shell from \$SHELL"
else bad "$CASE: machine.shell '$(pj_get profiles "$THIS_KEY" machine shell)'"; fi
# machine.os / machine.arch: this platform's facts (the golden holds <OS> / <ARCH>)
if [ "$(pj_get profiles "$THIS_KEY" machine os)" = "$THIS_OS" ]; then ok "$CASE: machine.os $THIS_OS"
else bad "$CASE: machine.os '$(pj_get profiles "$THIS_KEY" machine os)', want $THIS_OS"; fi
if [ -n "$(pj_get profiles "$THIS_KEY" machine arch)" ]; then ok "$CASE: machine.arch set"; else bad "$CASE: machine.arch missing"; fi

echo "== re-run: verified, no new commit"
CASE="alias-new-rerun"
run
if [ "$RC" -eq 0 ]; then ok "$CASE: exit 0"; else bad "$CASE: exit $RC"; perl -pe 's/^/       /' "$OUT"; fi
has_row "OK|machine profile|verified (spare)"
remote_count "$BARE" 2

echo "== decision 1: --alias of another machine's profile, no terminal -> refused (exit 1)"
case_run alias-other 1 fx_two --alias laptop
has_row "ERROR|machine profile|alias used by another machine"
unregistered_once
pj_lacks "\"$THIS_KEY\""
pj_other_intact
remote_count "$BARE" 1

echo "== an unregistered machine without --alias and without a terminal -> ERROR, exit 1"
case_run unregistered-notty 1 fx_two
has_row "ERROR|machine profile|not registered (no terminal)"
has_row "ACTION||Run: aitools user init --alias <name> (or on a terminal)"
unregistered_once

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
fx_noprofile() { fixture "$CASE" ""; }
case_run scaffold-path1 0 fx_noprofile
pj_alias "$THIS_KEY" probe-host
pj_has "\"schemaRevision\": \"2.2\""
pj_has "\"github\": \"$GH_USER\""
remote_has "$BARE" "Register machine profile: probe-host"
remote_has "$BARE" "Add claude/CLAUDE.md template"

echo "== decision 6: Path 3 (no dotprofile) -> created, scaffold reaches the (gh) remote"
fx_none() { fixture "$CASE" "-"; }
case_run scaffold-path3 0 fx_none --alias first
pj_alias "$THIS_KEY" first
remote_has "$D/gh-remote.git" "Initial commit: profile and session archive structure"
remote_has "$D/gh-remote.git" "Add claude/CLAUDE.md template"
remote_pj=$(git -C "$D/gh-remote.git" show main:profile.json 2>/dev/null) || remote_pj=""  # absent = not pushed (asserted)
if grep -q "\"$THIS_KEY\"" <<< "$remote_pj"; then ok "$CASE: profile.json on the remote"; else bad "$CASE: profile.json not on the remote"; fi
has_row "OK|dotprofile|created"

echo "== decision 2 switch = 0 (default): cached machineAlias, no terminal -> ERROR, exit 1 (same as unregistered)"
fx_cached() { fixture "$CASE" "$PJ_TWO" ',
  "machineAlias": "nobul-mac"'; }
case_run cached-alias-0 1 fx_cached
has_row "ERROR|machine profile|not registered (no terminal)"
unregistered_once
pj_lacks "\"$THIS_KEY\""

echo "== decision 2 switch = 1: cached machineAlias -> claimed without asking"
fx_cached_on() {
    fx_cached
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
fx_dirty() { fx_two; perl -pi -e 's/"old-host"/"edited-host"/' "$DP/profile.json"; }
case_run dirty 1 fx_dirty --alias spare
has_row "ERROR|machine profile|not registered (local edits)"
unregistered_once
pj_has '"edited-host"'
pj_lacks "\"$THIS_KEY\""
remote_count "$BARE" 1
fx_dirty_reg() {
    fixture "$CASE" "$PJ_TWO"
    perl -0pi -e 's/("profiles": \{)/$1\n    "'"$THIS_KEY"'": { "alias": "mine", "machine": { "id": "'"$THIS_KEY"'", "hostname": "probe-host" } },/' "$DP/profile.json"
    git -C "$DP" -c user.name=T -c user.email=t@x commit -q -am "register"; git -C "$DP" push -q
    perl -pi -e 's/"old-host"/"edited-host"/' "$DP/profile.json"
}
case_run dirty-registered 0 fx_dirty_reg
has_row "WARN|machine profile|not refreshed (local edits)"
no_machine_flag no
remote_count "$BARE" 2

echo "== Review3 #82 minor 4: a rejected push (remote ahead) is told to pull --rebase"
fx_ahead() {
    fx_two
    local w="$D/other"
    git clone -q -b main "$BARE" "$w"; printf 'x\n' > "$w/other.txt"; git -C "$w" add other.txt
    git -C "$w" -c user.name=O -c user.email=o@x commit -q -m other; git -C "$w" push -q origin main
}
case_run push-rejected 0 fx_ahead --alias spare
out_has "git pull --rebase, then git push"
has_row "ACTION||git pull --rebase, then git push in <D>/home/repos/aitools-$GH_USER"
has_row "WARN|machine profile|created (spare)"

echo "== D-TS13: the hooks review aborted (exit 2) -> user init exits 2"
CASE_ENV=(HOOK_RC=2)
case_run hook-abort 2 fx_two --alias spare
# FIX-2 (A-13): the relay records the abort (the stub wrote no ERROR row)
has_row "ERROR|claude hooks|aborted (exit 2)"
CASE_ENV=()

# jsonl_count CASE SCRIPT [LEVEL MSG] -- valid records of SCRIPT (with LEVEL and
# MSG when given) in that fixture's deploy.jsonl; "invalid" when a line is not JSON
jsonl_count() {
    perl -MJSON::PP -e '
        my ($f, $s, $l, $m) = @ARGV; my $n = 0;
        open(my $fh, "<:raw", $f) or do { print "0\n"; exit 0 };
        while (my $r = <$fh>) {
            my $o = eval { decode_json($r) }; if (!$o) { print "invalid\n"; exit 0 }
            next unless $o->{script} eq $s;
            next if defined $l && ($o->{level} ne $l || $o->{msg} ne $m);
            $n++;
        }
        print "$n\n";' "$WORK/$1/home/.aitools/logs/deploy.jsonl" "${@:2}"
}

echo "== FIX-2 (A-12, A-13): user init runs setup-user-config and setup-user-hooks through the lib relay"
# A hooks script that dies (exit 3) without an ERROR row: the relay's row, one error, exit 1
CASE_ENV=(HOOK_RC=3)
case_run hook-crash 1 fx_two --alias spare
has_row "ERROR|claude hooks|script failed (exit 3)"
row_count "ERROR|claude hooks|" 1
CASE_ENV=()
# The children's lines reach deploy.jsonl and the console; a hooks warning is relayed
CASE_ENV=(HOOK_WARN=1)
case_run relay-jsonl 0 fx_two --alias spare
out_has "[setup-user-hooks] [warn] stub hook warning"
n=$(jsonl_count relay-jsonl setup-user-hooks warn "stub hook warning")
if [ "$n" = "1" ]; then ok "relay-jsonl ($LANG_RUN): hooks warning in deploy.jsonl"
else bad "relay-jsonl ($LANG_RUN): hooks warning records '$n', want 1"; fi
n=$(jsonl_count relay-jsonl setup-user-config)
if [ "$n" != "invalid" ] && [ "$n" -gt 0 ]; then ok "relay-jsonl ($LANG_RUN): writer lines in deploy.jsonl ($n)"
else bad "relay-jsonl ($LANG_RUN): writer records '$n'"; fi
CASE_ENV=()

echo "== FIX-2 (A-15): --alias without a value is an error through the lib (bash; pwsh binds it itself)"
CASE="alias-novalue"
fx_two
run --alias
if [ "$RC" -eq 1 ]; then ok "$CASE: sh exit 1"; else bad "$CASE: sh exit $RC, want 1"; perl -pe 's/^/       /' "$OUT"; fi
out_has "[aitools] [error] --alias needs a value (aitools user init --alias <name>)"
if grep -qF -- "--alias needs a value" "$H/.aitools/logs/deploy.log"; then ok "$CASE: in deploy.log"; else bad "$CASE: not in deploy.log"; fi
run --alias --force
if [ "$RC" -eq 1 ]; then ok "$CASE: '--alias --force' exit 1"; else bad "$CASE: '--alias --force' exit $RC, want 1"; fi
out_has "--alias needs a value"

echo "== review M1: a relative reposPath is refused (nothing created under the current directory)"
fx_relative() { fixture "$CASE" "$PJ_TWO"; perl -pi -e 's/"reposPath": "[^"]*"/"reposPath": "repos"/' "$H/.aitools/config.json"; }
case_run relative-repos 1 fx_relative --alias spare
has_row "ERROR|dotprofile|reposPath not absolute"
if [ -e "$D/repos" ]; then bad "$CASE: a repos/ directory was created under the cwd"; else ok "$CASE: nothing created under the cwd"; fi

echo "== review M2: id undetectable (via=config) -> WARN, the cached machineId survives two runs"
fx_viaconfig() {
    fixture "$CASE" "$PJ_TWO" ',
  "machineId": "'"$THIS_KEY"'"'
    perl -0pi -e 's/("profiles": \{)/$1\n    "'"$THIS_KEY"'": { "alias": "mine", "machine": { "id": "'"$THIS_KEY"'", "hostname": "probe-host" } },/' "$DP/profile.json"
    git -C "$DP" -c user.name=T -c user.email=t@x commit -q -am "register"; git -C "$DP" push -q
}
CASE_ENV=(AITOOLS_PROFILE_TEST_MACHINE_ID=none)
case_run via-config 0 fx_viaconfig
has_row "WARN|machine profile|not refreshed (no machine id)"
cfg_id "$THIS_KEY"
# Registered, id undetectable: machine_key is emptied for the writer, but no flag
no_machine_flag no
CASE="via-config-rerun"
run
if [ "$RC" -eq 0 ]; then ok "$CASE: second run exit 0"; else bad "$CASE: second run exit $RC"; perl -pe 's/^/       /' "$OUT"; fi
cfg_id "$THIS_KEY"
CASE_ENV=()

echo "== review m3: --alias wins over a stale AITOOLS_MACHINE_ALIAS"
CASE_ENV=(AITOOLS_MACHINE_ALIAS=bogus)
case_run env-alias-stale 0 fx_two --alias spare
pj_alias "$THIS_KEY" spare
out_has "AITOOLS_MACHINE_ALIAS=bogus ignored"
CASE_ENV=()

echo "== Path 2: the GitHub repo exists, no local clone -> cloned, identity from the profile, registered"
fx_path2() { fx_two; rm -rf "$DP"; }
CASE_ENV=(GH_REPO_VIEW_RC=0)
case_run path2 0 fx_path2 --alias spare
has_row "OK|dotprofile|cloned"
pj_alias "$THIS_KEY" spare
remote_has "$BARE" "Register machine profile: spare"
p2_name=$(git -C "$DP" config user.name) || p2_name=""  # unset = "" (asserted)
if [ "$p2_name" = "Jose" ]; then ok "$CASE: clone's git identity from identity.git"; else bad "$CASE: clone identity '$p2_name'"; fi
CASE_ENV=()

echo "== v1 profile.json -> v2 revision 2.2, this machine under its id, other machines kept, committed"
PJ_V1='{ "name": "Jose", "email": "jose@example.com", "github": "nobul-jose", "company": "nobul-tech",
  "git": { "name": "Jose", "email": "jose@example.com" },
  "machines": [ { "hostname": "probe-host.local", "os": "darwin" }, { "hostname": "other-box", "os": "linux" } ],
  "cursor": { "cli": { "model": "auto" } } }'
fx_v1() { fixture "$CASE" "$PJ_V1"; }
case_run v1-migrate 0 fx_v1 --alias mac1
pj_alias "$THIS_KEY" mac1
if [ "$(pj_get version)" = "2" ] && [ "$(pj_get meta schemaRevision)" = "2.2" ]; then ok "$CASE: version 2, revision 2.2"; else bad "$CASE: version '$(pj_get version)'"; fi
if [ "$(pj_get profiles machine1 machine hostname)" = "other-box" ]; then ok "$CASE: the other v1 machine kept (machine1)"; else bad "$CASE: machine1 '$(pj_get profiles machine1 machine hostname)'"; fi
if [ "$(pj_get cursor cli model)" = "auto" ]; then ok "$CASE: cursor section kept"; else bad "$CASE: cursor section lost"; fi
remote_has "$BARE" "Migrate profile.json from v1 to v2"
if perl "$REPO/scripts/aitools-json.pl" get "$H/.aitools/config.json" machineAlias > /dev/null 2>&1; then
    v1_alias=$(perl "$REPO/scripts/aitools-json.pl" get "$H/.aitools/config.json" machineAlias)
    if [ "$v1_alias" = "mac1" ]; then ok "$CASE: config.json written by setup-user-config"; else bad "$CASE: config machineAlias '$v1_alias'"; fi
else bad "$CASE: config.json has no machineAlias"; fi

echo "== profile-check.js reads machineId (id keys; legacy machineAlias kept)"
# profile-check.js is a node script for every platform (aitools.ps1 and scripts/aitools call it)
CASE="profile-check"
fixture "$CASE" "$PJ_TWO" ',
  "userRepoPath": "'"$WORK/profile-check/home/repos/aitools-nobul-jose"'",
  "machineId": "deadbeef-0000-0000-0000-000000000000"'
PC_CFG="$H/.aitools/config.json"
pc=$(node "$REPO/scripts/profile-check.js" --config "$PC_CFG") || pc=""
if grep -q '"code":"MACHINE_ID_UNKNOWN"' <<< "$pc"; then ok "$CASE: unknown machineId reported"; else bad "$CASE: $pc"; fi
if grep -q '"machineId":"deadbeef-0000-0000-0000-000000000000"' <<< "$pc"; then ok "$CASE: machineId in the result"; else bad "$CASE: $pc"; fi
perl -pi -e 's/deadbeef-0000-0000-0000-000000000000/'"$OTHER_ID"'/' "$H/.aitools/config.json"
pc=$(node "$REPO/scripts/profile-check.js" --config "$PC_CFG") || pc=""
if grep -q 'MACHINE_ID_UNKNOWN' <<< "$pc"; then bad "$CASE: id-keyed machineId reported: $pc"; else ok "$CASE: id-keyed machineId found"; fi
perl -pi -e 's/'"$OTHER_ID"'/'"$THIS_ID"'/' "$H/.aitools/config.json"
perl -pi -e 's/"old-host"/"old-host", "id": "'"$THIS_ID"'"/' "$DP/profile.json"
pc=$(node "$REPO/scripts/profile-check.js" --config "$PC_CFG") || pc=""
if grep -q 'MACHINE_ID_UNKNOWN' <<< "$pc"; then bad "$CASE: legacy (alias-keyed) profile not read: $pc"; else ok "$CASE: legacy alias-keyed profile found by machine.id"; fi

if $USE_PTY; then
    echo "== interactive (pty): claim an unregistered profile; the menu matches the golden (both shells)"
    PTY_INPUT=$'1\n'
    case_run pty-claim 0 fx_two
    pj_alias "$THIS_KEY" nobul-mac
    pj_other_intact
    out_has "[-] laptop (registered to another machine)"
    out_has "[1] nobul-mac"
    perl -ne 'print if /^Which profile|^  \[|^Choice/' "$OUT" | perl -pe 's/Choice: .*/Choice: /; s/[ \t]+$//' > "$D/menu.txt"
    if golden_match userinit-pty-claim-menu.txt "$D/menu.txt"; then ok "pty-claim: menu matches golden"
    else bad "pty-claim: menu differs from golden userinit-pty-claim-menu.txt"; fi

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
    out_has "is used by another machine's profile ($OTHER_ID). Use it for this machine too? [y/n]"

    echo "== interactive (pty): ... declined -> skipped (WARN row; not registered = exit 1)"
    PTY_INPUT=$'\n\nn\n'
    case_run pty-dup-decline 1 fx_two --alias laptop
    has_row "WARN|machine profile|skipped"
    no_machine_flag yes
    no_row_like "no machine match"
    pj_lacks "\"$THIS_KEY\""

    # Re-ask (commander 2026-11-13: "no default or other characters should re-ask"):
    # an empty answer at a choice prompt asks again and applies nothing; the next
    # offered answer gives the same result as answering it at once (the golden of
    # that case). Every answer is logged at detail.
    echo "== interactive (pty): empty answer at the which-profile menu -> asked again; then 1 claims"
    CASE=pty-claim-reask; fx_two
    PTY_INPUT=$'\n1\n'
    run
    if [ "$RC" -eq 0 ]; then ok "$CASE: $LANG_RUN exit $RC"; else bad "$CASE: $LANG_RUN exit $RC, want 0"; perl -pe 's/^/       /' "$OUT"; fi
    result_golden pty-claim
    pj_alias "$THIS_KEY" nobul-mac
    pj_other_intact
    out_count "please type one of 1/n/s" 1
    out_count "Which profile is this machine?" 1
    log_has '[detail] menu answer (which profile): "" -> not one of 1/n/s, asked again'
    log_has '[detail] menu answer (which profile): "1" -> 1'

    echo "== interactive (pty): empty answer at the duplicate-alias confirm -> asked again; then y shares the alias"
    CASE=pty-dup-reask; fx_two
    PTY_INPUT=$'\n\n\ny\n'
    run --alias laptop
    if [ "$RC" -eq 0 ]; then ok "$CASE: $LANG_RUN exit $RC"; else bad "$CASE: $LANG_RUN exit $RC, want 0"; perl -pe 's/^/       /' "$OUT"; fi
    result_golden pty-dup-confirm
    pj_alias "$THIS_KEY" laptop
    pj_other_intact
    out_count "please type one of y/yes/n/no" 1
    log_has '[detail] menu answer (alias laptop): "" -> not one of y/yes/n/no, asked again'
    log_has '[detail] menu answer (alias laptop): "y" -> y'

    echo "== interactive (pty) with --force: no prompt; an unregistered machine is refused like no terminal"
    PTY_INPUT=$'1\n'
    case_run pty-force 1 fx_two --force
    has_row "ERROR|machine profile|not registered (no terminal)"
    if grep -q "Which profile is this machine" "$OUT"; then bad "$CASE: --force prompted"; else ok "$CASE: --force did not prompt"; fi
    PTY_INPUT=""
else
    printf '  skip interactive cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)\n'; SKIP=$((SKIP + 1))
fi

echo ""
echo "test-user-init: $PASS passed, $FAIL failed, $SKIP skipped ($TEST_PLATFORM: $LANG_RUN entry point)"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
