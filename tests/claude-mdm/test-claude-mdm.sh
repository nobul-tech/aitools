#!/usr/bin/env bash
# test-claude-mdm.sh -- tests for setup-user-claude.sh/.ps1 (dev path) and the
# generated MDM copies that scripts/build-deploy.sh writes into <dotprofile>/deploy/
#
# Cases (S3-MF-Audit ids):
#   A-25  the CLAUDE.md footer hostname is the resolver's (lib result
#         AITLIB_MACHINE_HOSTNAME / $script:AitLibMachineHostname), "unknown" when
#         empty; dev and MDM
#   A-26  --dry-run / -DryRun writes one claude.md row: "dry-run: would create",
#         "verified", "dry-run: would update" (same rows in .sh and .ps1: golden)
#   A-19  every generated .ps1 that embeds the profile resolver removes its temp
#         dir and restores AITOOLS_PROFILE_PS1 on every exit (try/finally), also
#         in-process (& script): on macOS/Linux through the generated OS guard's
#         early exit 1 (a guard-refusal test, not a Windows run), on Windows
#         through a dry run
#   A-20  build-deploy output has no colour codes when stderr is not a terminal,
#         and the standalone child resolver's console lines are not repeated in
#         it (they are in deploy.log once); on a terminal both stay visible
#   FO-4  the generated MDM copies fan out ~/.aitools/skills
#
# Platform targeting (plans/ci-platform-targeting.md): each script runs only where
# its OS guard allows. macOS/Linux run setup-user-claude.sh and the generated
# deploy/setup-user-claude.sh; Windows (Git Bash) runs setup-user-claude.ps1 and the
# generated deploy/setup-user-claude.ps1 with native pwsh. build-deploy.sh (a bash
# builder for every platform, cross-platform.md "Build scripts") runs on all three.
# The .sh/.ps1 parity of the dry-run rows is checked against the committed golden
# files in tests/claude-mdm/golden/ (tests/lib/platform-lib.sh golden_match);
# AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux rewrites them. Parsing a .ps1 with
# the PowerShell parser is not running it and is done on every platform with pwsh.
#
# Safe to re-run: every case runs under its own temp HOME (never the real HOME
# or a real dotprofile), removed on exit. The resolver is stubbed through
# AITOOLS_PROFILE_SH / AITOOLS_PROFILE_PS1 (the lib's lookup override) to fix the
# hostname it reports. AITOOLS_TEST_BASH picks the bash that runs the .sh scripts
# (default: bash). Needs perl, git, node for the build; pwsh on Windows; python3
# for the terminal case (pywinpty on Windows). Exit 1 if any case fails.
#
# Usage: bash tests/claude-mdm/test-claude-mdm.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility: macOS/Linux always run only .sh

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 39' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$ROOT/tests/lib/platform-lib.sh"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
GOLDEN_DIR="$ROOT/tests/claude-mdm/golden"
GOLDEN_TMP="$TMP_ROOT"
LANG_RUN="$TEST_LANG"   # sh on macOS/Linux, ps1 on Windows
W="$TMP_ROOT/work"
mkdir -p "$W"

PASS=0
FAIL=0
SKIP=0
OUT=""
ESC=$(printf '\033')

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$OUT" ] && [ -f "$OUT" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/\r//g; s/^/      | /' "$OUT" | tail -n 20
        fi
    fi
}
skip() { printf 'SKIP %s\n' "$1"; SKIP=$((SKIP + 1)); }
# no_embed DIR: DIR exists and holds no aitools-embed-* entry (other runtime
# files .NET may leave in the temp dir are not this test's business)
no_embed() { [ -d "$1" ] && [ -z "$(find "$1" -maxdepth 1 -name 'aitools-embed-*')" ]; }
# has_line FILE LINE: FILE (CRs removed) holds LINE as a whole line
has_line() { [ -f "$1" ] && perl -pe 's/\r//g' "$1" | grep -qxF -- "$2"; }

for t in perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done
HAVE_PWSH=false
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi
if [ "$LANG_RUN" = ps1 ] && ! $HAVE_PWSH; then
    printf 'FAIL pwsh is not on PATH: the .ps1 scripts cannot be tested on Windows\n'
    exit 1
fi
HAVE_NODE=false
if command -v node >/dev/null 2>&1; then HAVE_NODE=true; fi
CAN_CHMOD_READ=true   # chmod 000 blocks reads (not for root, not under Git Bash)
if [ "$TEST_PLATFORM" = windows ]; then CAN_CHMOD_READ=false; fi
if [ "$(id -u)" = 0 ]; then CAN_CHMOD_READ=false; fi
HAVE_PTY=false
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then HAVE_PTY=true; fi
# Windows pty = pywinpty (ConPTY); python3 -c's failure means "not installed".
if $HAVE_PTY && [ "$TEST_PLATFORM" = windows ] && ! python3 -c 'import winpty' >/dev/null 2>&1; then
    HAVE_PTY=false
fi

# The bash that runs the .sh scripts (CI also runs macOS /bin/bash 3.2)
TB="${AITOOLS_TEST_BASH:-bash}"
# Dry-run flag of the language under test
DRY="--dry-run"; if [ "$LANG_RUN" = ps1 ]; then DRY="-DryRun"; fi

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Fixture dotprofile (a git repo in the temp dir) ---
DP="$TMP_ROOT/aitools-tess"
mkdir -p "$DP/claude/rules"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf 'rule one\n' > "$DP/claude/rules/r1.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

write_config() {  # write_config HOME_DIR (userRepoPath in the form native pwsh reads)
    mkdir -p "$1/.aitools"
    printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$(native_path "$DP")" > "$1/.aitools/config.json"
}

# --- Resolver stubs: the real resolver, with its hostname result replaced ---
# stub-host: "stub-host"; no-host: empty (the footer must say "unknown"). The .sh
# stub is read on macOS/Linux, the .ps1 stub on Windows (the lib picks by platform).
for v in stub-host no-host; do
    h="$v"; if [ "$v" = no-host ]; then h=""; fi
    printf '#!/usr/bin/env bash\nout=$("${BASH:-bash}" "%s/scripts/aitools-profile.sh" "$@")\nrc=$?\nprintf "%%s\\n" "$out" | perl -pe '"'"'s/^hostname\\t.*/hostname\\t%s/'"'"'\nexit $rc\n' \
        "$ROOT" "$h" > "$W/$v.sh"
    printf '$out = @(& "%s/scripts/aitools-profile.ps1" @args)\n$rc = $LASTEXITCODE\nforeach ($l in $out) { if ("$l".StartsWith("hostname`t")) { "hostname`t%s" } else { "$l" } }\nexit $rc\n' \
        "$(native_path "$ROOT")" "$h" > "$W/$v.ps1"
done
# fail: a resolver error (exit 2), so resolve_user_repo_path returns 3
printf '#!/usr/bin/env bash\nprintf "via\\tnone\\nerror\\tstub resolver failure\\n"\nexit 2\n' > "$W/fail.sh"
printf '[Console]::Out.WriteLine("via`tnone")\n[Console]::Out.WriteLine("error`tstub resolver failure")\nexit 2\n' > "$W/fail.ps1"

# The live resolver hostname, in the language under test. Isolated HOME and log
# dir: the resolver logs (review N-1). stderr dropped: an unavailable hostname is
# checked through LIVE_HOST being empty.
if [ "$LANG_RUN" = sh ]; then
    LIVE_HOST=$(env HOME="$W/home-host" AITOOLS_LOG_DIR="$W/logs-host" "$TB" "$ROOT/scripts/aitools-profile.sh" hostname 2>/dev/null)
else
    mkdir -p "$W/home-host"
    LIVE_HOST=$(env HOME="$(native_path "$W/home-host")" USERPROFILE="$(native_path "$W/home-host")" \
        AITOOLS_LOG_DIR="$(native_path "$W/logs-host")" \
        pwsh -NoProfile -NonInteractive -File "$(native_path "$ROOT/scripts/aitools-profile.ps1")" hostname 2>/dev/null < /dev/null | perl -pe 's/\r//g')
fi
if [ -z "$LIVE_HOST" ]; then LIVE_HOST="unknown"; fi

# run_claude CASE STUB [args...] -- scripts/setup-user-claude in the language under
# test; HOME = $TMP_ROOT/CASE (kept between calls of the same CASE); STUB =
# stub-host|no-host|live. Paths handed to native pwsh are native (cygpath -m).
run_claude() {
    local name="$1" stub="$2" h; shift 2
    h="$TMP_ROOT/$name"
    [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name.out"
    : > "$TMP_ROOT/$name.summary"
    local envs=(HOME="$h" USERPROFILE="$(native_path "$h")" AITOOLS_LOG_DIR="$(native_path "$h/logs")"
        AITOOLS_SUMMARY_FILE="$(native_path "$TMP_ROOT/$name.summary")")
    if [ "$stub" != live ]; then envs+=(AITOOLS_PROFILE_SH="$W/$stub.sh" AITOOLS_PROFILE_PS1="$(native_path "$W/$stub.ps1")"); fi
    if [ "$LANG_RUN" = sh ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE "${envs[@]}" \
            "$TB" "$ROOT/scripts/setup-user-claude.sh" "$@" < /dev/null > "$OUT" 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE "${envs[@]}" \
            HOME="$(native_path "$h")" \
            pwsh -NoProfile -NonInteractive -File "$(native_path "$ROOT/scripts/setup-user-claude.ps1")" "$@" < /dev/null > "$OUT" 2>&1
    fi
    echo $? > "$TMP_ROOT/$name.rc"
}
rc_of() { cat "$TMP_ROOT/$1.rc"; }
row() { has_line "$TMP_ROOT/$1.summary" "$2"; }
md_of() { printf '%s' "$TMP_ROOT/$1/.claude/CLAUDE.md"; }
claude_rows() { perl -pe 's/\r//g' "$TMP_ROOT/$1.summary" | grep '|claude.md|'; }

lang="$LANG_RUN"

# ---------------------------------------------------------------------------
# A-25 / A-26, dev path (the language under test)
# ---------------------------------------------------------------------------
run_claude "$lang-host" stub-host
check "$lang A-25: footer hostname is the resolver's (stub-host)" \
    "[ \"\$(rc_of $lang-host)\" = 0 ] && grep -qF '(stub-host; profile m1)' \"\$(md_of $lang-host)\""
run_claude "$lang-nohost" no-host
check "$lang A-25: empty resolver hostname -> footer 'unknown'" \
    "[ \"\$(rc_of $lang-nohost)\" = 0 ] && grep -qF '(unknown; profile m1)' \"\$(md_of $lang-nohost)\""
run_claude "$lang-live" live
check "$lang A-25: no stub -> footer hostname equals 'aitools-profile hostname' ($LIVE_HOST)" \
    "[ \"\$(rc_of $lang-live)\" = 0 ] && grep -qF '($LIVE_HOST; profile m1)' \"\$(md_of $lang-live)\""

run_claude "$lang-dry" stub-host "$DRY"
check "$lang A-26: dry run, no CLAUDE.md -> one row 'dry-run: would create', nothing written" \
    "[ \"\$(rc_of $lang-dry)\" = 0 ] && [ \"\$(claude_rows $lang-dry)\" = 'OK|claude.md|dry-run: would create' ] && [ ! -e \"\$(md_of $lang-dry)\" ]"
claude_rows "$lang-dry" > "$TMP_ROOT/dry-1.rows"
check "parity A-26 (no CLAUDE.md): claude.md rows match golden (sh and ps1 share it)" \
    "golden_match dry-1.rows '$TMP_ROOT/dry-1.rows'"
run_claude "$lang-dry" stub-host
run_claude "$lang-dry" stub-host "$DRY"
check "$lang A-26: dry run after a deploy -> 'verified'" \
    "[ \"\$(rc_of $lang-dry)\" = 0 ] && [ \"\$(claude_rows $lang-dry)\" = 'OK|claude.md|verified' ]"
claude_rows "$lang-dry" > "$TMP_ROOT/dry-2.rows"
check "parity A-26 (after a deploy): claude.md rows match golden" \
    "golden_match dry-2.rows '$TMP_ROOT/dry-2.rows'"
printf -- '- local edit\n' >> "$(md_of "$lang-dry")"
cp "$(md_of "$lang-dry")" "$TMP_ROOT/$lang-dry.edited"
run_claude "$lang-dry" stub-host "$DRY"
check "$lang A-26: dry run on an edited CLAUDE.md -> 'dry-run: would update', file untouched" \
    "[ \"\$(rc_of $lang-dry)\" = 0 ] && [ \"\$(claude_rows $lang-dry)\" = 'OK|claude.md|dry-run: would update' ] && cmp -s \"\$(md_of $lang-dry)\" '$TMP_ROOT/$lang-dry.edited'"
claude_rows "$lang-dry" > "$TMP_ROOT/dry-3.rows"
check "parity A-26 (edited CLAUDE.md): claude.md rows match golden" \
    "golden_match dry-3.rows '$TMP_ROOT/dry-3.rows'"
# Unreadable CLAUDE.md (review B-1): a counted warning, a row, exit 0 -- not a
# set -e abort. chmod does not block reads for root or under Git Bash.
if $CAN_CHMOD_READ; then
    chmod 000 "$(md_of "$lang-dry")"
    run_claude "$lang-dry" stub-host "$DRY"
    chmod 644 "$(md_of "$lang-dry")"
    check "$lang A-26: dry run on an unreadable CLAUDE.md -> warning, 'dry-run: would update' row, exit 0" \
        "[ \"\$(rc_of $lang-dry)\" = 0 ] && [ \"\$(claude_rows $lang-dry)\" = 'WARN|claude.md|dry-run: would update' ] && grep -q 'for the dry-run comparison' '$TMP_ROOT/$lang-dry/logs/deploy.log'"
    claude_rows "$lang-dry" > "$TMP_ROOT/dry-4.rows"
    check "parity A-26 (unreadable CLAUDE.md): claude.md rows match golden" \
        "golden_match dry-4.rows '$TMP_ROOT/dry-4.rows'"
else
    skip "$lang unreadable CLAUDE.md case (chmod does not block reads here)"
fi

# ---------------------------------------------------------------------------
# Build (isolated HOME, fixture dotprofile; stderr is a file, not a terminal).
# build-deploy.sh runs on every platform (Git Bash on Windows); its child pwsh
# (resolver, PS1 validation on Windows) reads USERPROFILE, so both are set.
# ---------------------------------------------------------------------------
if ! $HAVE_NODE; then
    skip "build and MDM cases (node not found; build-deploy needs it)"
    printf '\n%d passed, %d failed, %d skipped (%s: %s scripts)\n' "$PASS" "$FAIL" "$SKIP" "$TEST_PLATFORM" "$lang"
    [ "$FAIL" -eq 0 ]
    exit
fi

HB="$TMP_ROOT/home-build"
write_config "$HB"
OUT="$TMP_ROOT/build.out"
env -u AITOOLS_USER_REPO_PATH -u AITOOLS_SUMMARY_FILE -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
    HOME="$HB" USERPROFILE="$(native_path "$HB")" AITOOLS_LOG_DIR="$(native_path "$HB/logs")" \
    "$TB" "$ROOT/scripts/build-deploy.sh" < /dev/null > "$OUT" 2>&1
BUILD_RC=$?
G="$DP/deploy"
check "build: exit 0, setup-user-claude.sh/.ps1 generated" \
    "[ '$BUILD_RC' = 0 ] && [ -x '$G/setup-user-claude.sh' ] && [ -f '$G/setup-user-claude.ps1' ]"
check "build (port): generated claude scripts take the footer hostname from the lib (A-25)" \
    "grep -qF 'MACHINE_HOST=\"\${AITLIB_MACHINE_HOSTNAME:-}\"' '$G/setup-user-claude.sh' && ! grep -q 'scutil --get LocalHostName 2>&1) || _host_rc' '$G/setup-user-claude.sh' && grep -qF '\$machineHost = [string]\$script:AitLibMachineHostname' '$G/setup-user-claude.ps1' && ! grep -qF 'COMPUTERNAME).Split' '$G/setup-user-claude.ps1'"
check "build (port): generated claude scripts write the dry-run rows (A-26)" \
    "[ \"\$(grep -c 'claude.md\" \"dry-run: would' '$G/setup-user-claude.sh')\" = 2 ] && [ \"\$(grep -c 'claude.md\" \"dry-run: would' '$G/setup-user-claude.ps1')\" = 2 ]"
check "build A-20: no colour codes in non-terminal output" "! grep -qF \"\$ESC\" '$OUT'"
check "build: bash -n on the generated .sh ($TB)" "'$TB' -n '$G/setup-user-claude.sh' && '$TB' -n '$G/setup-user-cursor.sh' && '$TB' -n '$G/setup-user-settings.sh'"

EMBED_PS1="setup-user-claude.ps1 setup-user-cursor.ps1 setup-user-settings.ps1"
FINALLY_RE='^\} finally \{ Remove-AitoolsEmbed \}'
_a19_static() {
    local f n_try n_fin last
    for f in $EMBED_PS1; do
        n_try=$(grep -c '^try {' "$G/$f")
        # one "try {" at column 0 per file: the embed block's own try (inside the
        # block, indented) does not count
        n_fin=$(grep -cE "$FINALLY_RE" "$G/$f")
        last=$(perl -ne 'print if /\S/' "$G/$f" | tail -n 1 | perl -pe 's/\r?\n\z//')
        [ "$n_fin" = 1 ] || return 1
        printf '%s\n' "$last" | grep -qE "$FINALLY_RE" || return 1
        [ "$n_try" -ge 1 ] || return 1
    done
}
check "build A-19: each resolver-embedding .ps1 ends with '} finally { Remove-AitoolsEmbed }'" "_a19_static"

# ---------------------------------------------------------------------------
# A-19 runtime. Parsing (every platform with pwsh) is not running. macOS/Linux:
# the generated OS guard refuses (exit 1) -- a guard-refusal test of the
# generated scripts, which tests/os-guards (scripts/, shared/, packaging/) does
# not cover. Windows: the script runs (dry run) and exits normally.
# ---------------------------------------------------------------------------
if $HAVE_PWSH; then
    printf '%s\n' '$e = $null' \
        '$null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e)' \
        'if ($e.Count -gt 0) { $e | ForEach-Object { [Console]::WriteLine($_.Message) }; exit 1 }' > "$W/parse.ps1"
    _parse_all() {
        local f
        for f in $EMBED_PS1; do
            pwsh -NoProfile -NonInteractive -File "$(native_path "$W/parse.ps1")" "$(native_path "$G/$f")" < /dev/null > /dev/null || return 1
        done
    }
    check "build A-19: pwsh parser accepts the three generated .ps1" "_parse_all"
    if [ "$LANG_RUN" = ps1 ]; then
        A19_ARGS="-DryRun"; A19_HOW="dry-run exit"
    else
        A19_ARGS=""; A19_HOW="OS-guard exit 1 (guard refusal)"
    fi
    for f in $EMBED_PS1; do
        n="${f%.ps1}"
        T="$TMP_ROOT/tmp-$n"; mkdir -p "$T"
        h="$TMP_ROOT/g-$n"; write_config "$h"
        OUT="$TMP_ROOT/g-$n.out"
        # TMPDIR: .NET's temp dir on macOS/Linux; TMP/TEMP: on Windows
        # shellcheck disable=SC2086  # A19_ARGS is empty or one switch
        env -u AITOOLS_PROFILE_PS1 -u AITOOLS_PROFILE_FILE -u AITOOLS_DRY_RUN HOME="$(native_path "$h")" USERPROFILE="$(native_path "$h")" \
            TMPDIR="$T/" TMP="$(native_path "$T")" TEMP="$(native_path "$T")" AITOOLS_LOG_DIR="$(native_path "$h/logs")" \
            AITOOLS_SUMMARY_FILE="$(native_path "$TMP_ROOT/g-$n.summary")" \
            pwsh -NoProfile -NonInteractive -File "$(native_path "$G/$f")" $A19_ARGS < /dev/null > "$OUT" 2>&1
        echo $? > "$TMP_ROOT/g-$n.rc"
        if [ "$LANG_RUN" = ps1 ]; then
            check "A-19 $f: $A19_HOW leaves no aitools-embed-* temp dir" "no_embed '$T'"
        else
            check "A-19 $f: $A19_HOW leaves no aitools-embed-* temp dir" \
                "[ \"\$(rc_of g-$n)\" = 1 ] && grep -q 'This script is for Windows' '$OUT' && no_embed '$T'"
        fi
        OUT="$TMP_ROOT/gi-$n.out"
        env -u AITOOLS_PROFILE_PS1 -u AITOOLS_PROFILE_FILE -u AITOOLS_DRY_RUN HOME="$(native_path "$h")" USERPROFILE="$(native_path "$h")" \
            TMPDIR="$T/" TMP="$(native_path "$T")" TEMP="$(native_path "$T")" AITOOLS_LOG_DIR="$(native_path "$h/logs")" \
            AITOOLS_SUMMARY_FILE="$(native_path "$TMP_ROOT/g-$n.summary")" G_SCRIPT="$(native_path "$G/$f")" G_ARGS="$A19_ARGS" \
            pwsh -NoProfile -NonInteractive -Command 'if ($env:G_ARGS) { & $env:G_SCRIPT -DryRun } else { & $env:G_SCRIPT }; if ($env:AITOOLS_PROFILE_PS1) { [Console]::WriteLine("LEAK $($env:AITOOLS_PROFILE_PS1)") } else { [Console]::WriteLine("ENV-RESTORED") }' \
            < /dev/null > "$OUT" 2>&1
        check "A-19 $f: in-process (& script) $A19_HOW restores AITOOLS_PROFILE_PS1" \
            "has_line '$OUT' 'ENV-RESTORED' && no_embed '$T'"
    done
else
    skip "A-19 parse and guard-refusal cases (pwsh not found)"
fi

# Full run of the generated claude .ps1 on Windows, stub hostname
if [ "$LANG_RUN" = ps1 ]; then
    T="$TMP_ROOT/tmp-full"; mkdir -p "$T"
    h="$TMP_ROOT/gps-full"; write_config "$h"
    mkdir -p "$h/.aitools/skills/sk1"
    printf 'skill one\n' > "$h/.aitools/skills/sk1/SKILL.md"
    printf '# aitools skills manifest v1\nsk1\tdotprofile\n' > "$h/.aitools/skills/.aitools-skills-manifest"
    OUT="$TMP_ROOT/gps-full.out"; : > "$TMP_ROOT/gps-full.summary"
    env -u AITOOLS_PROFILE_FILE -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$(native_path "$h")" USERPROFILE="$(native_path "$h")" \
        TMP="$(native_path "$T")" TEMP="$(native_path "$T")" AITOOLS_LOG_DIR="$(native_path "$h/logs")" \
        AITOOLS_SUMMARY_FILE="$(native_path "$TMP_ROOT/gps-full.summary")" AITOOLS_PROFILE_PS1="$(native_path "$W/stub-host.ps1")" \
        pwsh -NoProfile -NonInteractive -File "$(native_path "$G/setup-user-claude.ps1")" < /dev/null > "$OUT" 2>&1
    echo $? > "$TMP_ROOT/gps-full.rc"
    check "MDM ps1 full run: exit 0, footer stub-host, claude.md row, temp dir removed" \
        "[ \"\$(rc_of gps-full)\" = 0 ] && grep -qF '(stub-host; profile m1)' '$h/.claude/CLAUDE.md' && grep -q '^OK|claude.md|created' '$TMP_ROOT/gps-full.summary' && no_embed '$T'"
    check "MDM ps1 full run: skills fanned out from ~/.aitools/skills" \
        "grep -qx 'skill one' '$h/.claude/skills/sk1/SKILL.md' && row gps-full 'OK|claude skills|1 added'"
fi

# ---------------------------------------------------------------------------
# MDM smoke runs (generated script in the language under test, isolated HOME,
# the embedded resolver: no stub)
# ---------------------------------------------------------------------------
run_mdm() {  # run_mdm CASE [args...] -- HOME = $TMP_ROOT/CASE
    local name="$1" h; shift
    h="$TMP_ROOT/$name"; [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name.out"; : > "$TMP_ROOT/$name.summary"
    if [ "$LANG_RUN" = sh ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_PROFILE_SH \
            HOME="$h" AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name.summary" \
            "$TB" "$G/setup-user-claude.sh" "$@" < /dev/null > "$OUT" 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_PROFILE_PS1 \
            HOME="$(native_path "$h")" USERPROFILE="$(native_path "$h")" AITOOLS_LOG_DIR="$(native_path "$h/logs")" \
            AITOOLS_SUMMARY_FILE="$(native_path "$TMP_ROOT/$name.summary")" \
            pwsh -NoProfile -NonInteractive -File "$(native_path "$G/setup-user-claude.ps1")" "$@" < /dev/null > "$OUT" 2>&1
    fi
    echo $? > "$TMP_ROOT/$name.rc"
}
M="mdm-$lang"
run_mdm "$M" "$DRY"
check "MDM $lang dry run: exit 0, 'dry-run: would create', nothing written" \
    "[ \"\$(rc_of $M)\" = 0 ] && [ \"\$(claude_rows $M)\" = 'OK|claude.md|dry-run: would create' ] && [ ! -e \"\$(md_of $M)\" ]"
check "MDM $lang dry run without ~/.aitools/rules: claude rules n/a, rules not embedded" \
    "row $M 'OK|claude rules|n/a (no harness rules)' && ! grep -q 'Rules fallback' '$G/setup-user-claude.sh' && ! grep -q 'Rules fallback' '$G/setup-user-claude.ps1'"
# The rules reach ~/.claude/rules through ~/.aitools/rules, which deploy-harness
# fills first on an endpoint: seed it as deploy-harness would (manifest included)
mkdir -p "$TMP_ROOT/$M/.aitools/rules"
printf 'rule one\n' > "$TMP_ROOT/$M/.aitools/rules/r1.md"
printf '# aitools rules manifest v1\nr1.md\tdotprofile\n' > "$TMP_ROOT/$M/.aitools/rules/.aitools-rules-manifest"
check "MDM $lang dry run without ~/.aitools/skills: no claude skills row (setup-user-skills owns it)" \
    "! grep -qF '|claude skills|' '$TMP_ROOT/$M.summary'"
# The skills likewise reach ~/.claude/skills through ~/.aitools/skills (FO-4)
seed_mdm_skills() {  # seed_mdm_skills HOME_DIR: one skill, a nested file, the skills manifest
    mkdir -p "$1/.aitools/skills/sk1/tests"
    printf 'skill one\n' > "$1/.aitools/skills/sk1/SKILL.md"
    printf 'nested\n' > "$1/.aitools/skills/sk1/tests/t.md"
    printf '# aitools skills manifest v1\nsk1\tdotprofile\n' > "$1/.aitools/skills/.aitools-skills-manifest"
}
seed_mdm_skills "$TMP_ROOT/$M"
run_mdm "$M"
check "MDM $lang run: exit 0, created, footer hostname = resolver's ($LIVE_HOST), rules fanned out from ~/.aitools/rules" \
    "[ \"\$(rc_of $M)\" = 0 ] && row $M 'OK|claude.md|created' && grep -qF '($LIVE_HOST; profile m1)' \"\$(md_of $M)\" && has_line '$TMP_ROOT/$M/.claude/rules/r1.md' 'rule one' && row $M 'OK|claude rules|1 added'"
check "MDM $lang run: skills fanned out from ~/.aitools/skills" \
    "has_line '$TMP_ROOT/$M/.claude/skills/sk1/SKILL.md' 'skill one' && has_line '$TMP_ROOT/$M/.claude/skills/sk1/tests/t.md' nested && row $M 'OK|claude skills|2 added'"
run_mdm "$M" "$DRY"
check "MDM $lang dry run after the deploy: 'verified'" \
    "[ \"\$(rc_of $M)\" = 0 ] && [ \"\$(claude_rows $M)\" = 'OK|claude.md|verified' ]"

# ---------------------------------------------------------------------------
# A-20: the standalone child resolver (no AITOOLS_USER_REPO_PATH) fails. Both
# stubs are set: the lib runs fail.sh on macOS/Linux and fail.ps1 on Windows.
# ---------------------------------------------------------------------------
HF="$TMP_ROOT/home-fail"; write_config "$HF"
OUT="$TMP_ROOT/build-fail.out"
env -u AITOOLS_USER_REPO_PATH -u AITOOLS_SUMMARY_FILE \
    HOME="$HF" USERPROFILE="$(native_path "$HF")" AITOOLS_LOG_DIR="$(native_path "$HF/logs")" \
    AITOOLS_PROFILE_SH="$W/fail.sh" AITOOLS_PROFILE_PS1="$W/fail.ps1" \
    "$TB" "$ROOT/scripts/build-deploy.sh" < /dev/null > "$OUT" 2>&1
echo $? > "$TMP_ROOT/build-fail.rc"
check "A-20 resolver error: build skips (exit 0) with a plain-text warning" \
    "[ \"\$(rc_of build-fail)\" = 0 ] && grep -q '\[build-deploy\] \[warn\] Dotprofile resolver failed' '$OUT' && ! grep -qF \"\$ESC\" '$OUT'"
check "A-20 resolver error: the child's error line is in deploy.log once, not in the build output" \
    "! grep -q 'stub resolver failure' '$OUT' && [ \"\$(grep -c '\[error\] dotprofile: stub resolver failure' '$HF/logs/deploy.log')\" = 1 ]"
if $HAVE_PTY; then
    OUT="$TMP_ROOT/build-fail-tty.out"
    env -u AITOOLS_USER_REPO_PATH -u AITOOLS_SUMMARY_FILE \
        HOME="$HF" USERPROFILE="$(native_path "$HF")" AITOOLS_LOG_DIR="$(native_path "$HF/logs")" \
        AITOOLS_PROFILE_SH="$W/fail.sh" AITOOLS_PROFILE_PS1="$W/fail.ps1" \
        python3 "$PTY" --input '' --log "$OUT" -- "$TB" "$ROOT/scripts/build-deploy.sh"
    # ConPTY (Windows) re-renders the screen, so its colour sequence may differ
    # from the [33m the build writes: any SGR sequence counts there.
    COLOUR="\${ESC}[33m"; if [ "$TEST_PLATFORM" = windows ]; then COLOUR="\${ESC}["; fi
    check "A-20 on a terminal: the warning is coloured and the child's error line is shown" \
        "grep -qF \"$COLOUR\" '$OUT' && grep -q 'stub resolver failure' '$OUT'"
else
    skip "A-20 terminal case (python3 pty not available)"
fi

printf '\n%d passed, %d failed, %d skipped (%s: %s scripts)\n' "$PASS" "$FAIL" "$SKIP" "$TEST_PLATFORM" "$lang"
[ "$FAIL" -eq 0 ]
