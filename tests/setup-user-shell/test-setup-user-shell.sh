#!/usr/bin/env bash
# test-setup-user-shell.sh -- tests for scripts/setup-user-shell.sh: the aitools PATH
# block in ~/.bash_profile and the shell integration lines in ~/.bashrc / ~/.zshrc.
#
# Safe to re-run: every case uses its own temp profile dir, HOME, log dir and summary
# file, removed on exit. Platform: macOS/Linux only (OS guard below; setup-user-shell.sh
# has a POSIX OS guard). Commander, 2026-11-14: "sh scripts and tests should only run
# on linux/mac and ps1 on windows". On Windows, test-setup-user-shell.ps1 tests the
# .ps1 twin with pwsh. Exit 1 if any case fails.
# Covers: blocks added to a new profile and .bashrc; re-run unchanged (no write, no
# backup); user lines around a stale block kept; duplicate blocks collapsed; stray
# block lines and a profile failing bash -n reported as WARN + ACTION with the
# backup choice; a splice that would break the profile refused; .zshrc only when it
# exists; the legacy "# ai-tooling" pair migrated; MDM (no aliases.sh).
#
# Usage: bash tests/setup-user-shell/test-setup-user-shell.sh [--help]
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/setup-user-shell/test-setup-user-shell.sh

set -euo pipefail

# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/setup-user-shell/test-setup-user-shell.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/setup-user-shell/test-setup-user-shell.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. > 1 && $. <= 18' "$0"
    exit 0
fi

BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP="$ROOT/scripts/setup-user-shell.sh"
TMP_ROOT=$(mktemp -d)
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

ALIASES="$TMP_ROOT/aliases.sh"
printf '# test aliases\n' > "$ALIASES"
NO_ALIASES="$TMP_ROOT/absent/aliases.sh"

PS="# >>> aitools managed >>>"
PE="# <<< aitools managed <<<"
MARKER="# aitools shell integration"

PASS=0
FAIL=0
SKIP=0
check() {  # check <description> <command string>: PASS when it exits 0
    if eval "$2"; then printf 'PASS %s\n' "$1"; PASS=$((PASS + 1)); else printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); fi
}

# cl FILE LINE: the number of lines of FILE equal to LINE (0 when FILE is absent).
cl() {
    [ -f "$1" ] || { echo 0; return 0; }
    perl -e 'my ($f, $l) = @ARGV; open my $h, "<", $f or die "$f: $!\n"; my $n = 0; while (<$h>) { chomp; $n++ if $_ eq $l; } print $n;' "$1" "$2"
}

# run_setup CASE PROFILE_DIR [ALIASES]: run setup-user-shell.sh isolated; writes
# $TMP_ROOT/CASE/{rc,summary.txt,run.log}.
run_setup() {
    local case_dir="$TMP_ROOT/$1" rc=0
    mkdir -p "$case_dir" "$case_dir/home"
    rm -f "$case_dir/summary.txt"
    HOME="$case_dir/home" AITOOLS_PROFILE_DIR="$2" AITOOLS_ALIASES_PATH="${3:-$ALIASES}" \
    AITOOLS_LOG_DIR="$case_dir/logs" AITOOLS_SUMMARY_FILE="$case_dir/summary.txt" \
        "$BASH_BIN" "$SETUP" > "$case_dir/run.log" 2>&1 || rc=$?
    printf '%s' "$rc" > "$case_dir/rc"
    touch "$case_dir/summary.txt"
}
rc_of() { cat "$TMP_ROOT/$1/rc"; }
summary_has() { grep -qF -- "$2" "$TMP_ROOT/$1/summary.txt"; }
backups() { find "$1" -maxdepth 1 -name "$2.bak.*" | wc -l | tr -d ' '; }
new_dir() { mkdir -p "$TMP_ROOT/p-$1"; printf '%s' "$TMP_ROOT/p-$1"; }

# The current block, as a fresh run writes it.
D=$(new_dir new)
run_setup new "$D"
BLOCK_TEXT="$TMP_ROOT/block.txt"
cp "$D/.bash_profile" "$BLOCK_TEXT"

# --- New profile ---
check "new: exit 0, OK managed block added + integration added" \
    "[ \"\$(rc_of new)\" = 0 ] && summary_has new 'OK|shell|managed block added' && summary_has new 'OK|shell|integration added'"
check "new: one block, passes bash -n" "[ \"\$(cl '$D/.bash_profile' '$PS')\" = 1 ] && \"\$BASH_BIN\" -n '$D/.bash_profile'"
check "new: .bashrc created with the source line, .zshrc not created" \
    "grep -qxF '$MARKER' '$D/.bashrc' && grep -qxF 'source \"$ALIASES\"' '$D/.bashrc' && [ ! -e '$D/.zshrc' ]"
cp "$D/.bash_profile" "$TMP_ROOT/new-profile.1"
cp "$D/.bashrc" "$TMP_ROOT/new-bashrc.1"
run_setup new2 "$D"
run_setup new3 "$D"
check "re-run: exit 0, OK managed block unchanged + integration unchanged" \
    "[ \"\$(rc_of new2)\" = 0 ] && summary_has new2 'OK|shell|managed block unchanged' && summary_has new3 'OK|shell|integration unchanged'"
check "re-run: .bash_profile and .bashrc byte-identical" \
    "cmp -s '$D/.bash_profile' '$TMP_ROOT/new-profile.1' && cmp -s '$D/.bashrc' '$TMP_ROOT/new-bashrc.1'"
check "re-run: no write, so no backup taken" "[ \"\$(backups '$D' .bash_profile)\" = 0 ] && [ \"\$(backups '$D' .bashrc)\" = 0 ]"

# --- User lines around a stale block ---
D=$(new_dir user)
printf 'alias ll="ls -l"\n\n%s\nstale=1\n%s\n\nexport FOO=1\n' "$PS" "$PE" > "$D/.bash_profile"
{ printf 'alias ll="ls -l"\n\n'; cat "$BLOCK_TEXT"; printf '\nexport FOO=1\n'; } > "$TMP_ROOT/user.expected"
run_setup user "$D"
check "stale block: replaced in place, user lines kept (OK refreshed)" \
    "[ \"\$(rc_of user)\" = 0 ] && cmp -s '$D/.bash_profile' '$TMP_ROOT/user.expected' && summary_has user 'OK|shell|managed block refreshed'"
check "stale block: one backup of the old profile" "[ \"\$(backups '$D' .bash_profile)\" = 1 ]"

# --- Duplicate blocks and stray marker lines ---
D=$(new_dir dup)
{ printf '# u1\n'; cat "$BLOCK_TEXT"; printf '# u2\n%s\n' "$PE"; cat "$BLOCK_TEXT"; printf '\n# u3\n%s\nx=1\n%s\n# u4\n' "$PS" "$PE"; } > "$D/.bash_profile"
{ printf '# u1\n'; cat "$BLOCK_TEXT"; printf '# u2\n\n# u3\n# u4\n'; } > "$TMP_ROOT/dup.expected"
run_setup dup "$D"
check "duplicates: OK collapsed 3 blocks to 1, stray end marker removed" \
    "[ \"\$(rc_of dup)\" = 0 ] && summary_has dup 'OK|shell|collapsed 3 blocks to 1' && cmp -s '$D/.bash_profile' '$TMP_ROOT/dup.expected'"
check "duplicates: no WARN (nothing damaged)" "! grep -q '^WARN' '$TMP_ROOT/dup/summary.txt'"

# --- Stray block lines outside the markers: WARN + ACTION, backup choice ---
D=$(new_dir stray)
{ printf 'alias a=b\n'; cat "$BLOCK_TEXT"; cat "$BLOCK_TEXT"; printf '# Owned by aitools (scripts/setup-user-shell.sh). Placed last so it re-asserts\n'; } > "$D/.bash_profile"
{ printf 'alias a=b\n'; cat "$BLOCK_TEXT"; } > "$D/.bash_profile.bak.2026-01-01T000000Z"
{ cat "$BLOCK_TEXT"; cat "$BLOCK_TEXT"; } > "$D/.bash_profile.bak.2026-02-01T000000Z"
{ cat "$BLOCK_TEXT"; printf '__aitoolsLocalBin=1\n'; } > "$D/.bash_profile.bak.2026-03-01T000000Z"
run_setup stray "$D"
check "stray lines: exit 0, collapsed, WARN profile damage left in place" \
    "[ \"\$(rc_of stray)\" = 0 ] && summary_has stray 'collapsed 2 blocks to 1' && summary_has stray 'WARN|shell|profile damage left in place'"
check "stray lines: left in place, one block" \
    "grep -qF 'Owned by aitools (scripts/setup-user-shell.sh). Placed last so it re-asserts' '$D/.bash_profile' && [ \"\$(cl '$D/.bash_profile' '$PS')\" = 1 ]"
check "stray lines: ACTION names the newest clean backup (01; 02 two blocks, 03 a stray line)" \
    "summary_has stray 'ACTION||Restore $D/.bash_profile from $D/.bash_profile.bak.2026-01-01T000000Z'"

D=$(new_dir nobak)
{ cat "$BLOCK_TEXT"; printf '__aitoolsLocalBin=1\n'; } > "$D/.bash_profile"
run_setup nobak "$D"
check "no clean backup: ACTION says repair by hand" \
    "[ \"\$(rc_of nobak)\" = 0 ] && summary_has nobak 'ACTION||Repair $D/.bash_profile by hand (no clean backup)'"

# --- A profile that already fails bash -n: written (not worse), WARN ---
D=$(new_dir broken)
printf 'if true; then\n  echo hi\n' > "$D/.bash_profile"
run_setup broken "$D"
check "fails bash -n before and after: block added, WARN + ACTION" \
    "[ \"\$(rc_of broken)\" = 0 ] && [ \"\$(cl '$D/.bash_profile' '$PS')\" = 1 ] && summary_has broken 'WARN|shell|profile damage left in place' && summary_has broken 'ACTION||Repair'"

# --- A splice that would break the profile is refused ---
D=$(new_dir guard)
# The block region holds the "fi" of an if that starts above it: the splice would
# drop the fi and leave the if unterminated.
printf 'if true; then\n:\n%s\n:\nfi\n%s\n' "$PS" "$PE" > "$D/.bash_profile"
check "fixture: the guard profile passes bash -n" "\"\$BASH_BIN\" -n '$D/.bash_profile'"
cp "$D/.bash_profile" "$TMP_ROOT/guard.before"
run_setup guard "$D"
check "breaking splice: exit 1, ERROR row, profile unchanged" \
    "[ \"\$(rc_of guard)\" = 1 ] && summary_has guard 'ERROR|shell|managed block splice failed parse check' && cmp -s '$D/.bash_profile' '$TMP_ROOT/guard.before'"

# --- rc files: .zshrc when present, legacy pair migrated, user lines kept ---
D=$(new_dir rc)
printf 'export A=1\n\n# ai-tooling shell integration\nsource "/old/ai-tooling/shared/shell/aliases.sh"\nexport B=2\n' > "$D/.bashrc"
cp "$D/.bashrc" "$TMP_ROOT/rc.bashrc.before"
printf 'setopt x\n' > "$D/.zshrc"
run_setup rc "$D"
check "rc: OK legacy integration migrated" "[ \"\$(rc_of rc)\" = 0 ] && summary_has rc 'OK|shell|legacy integration migrated'"
check "rc: legacy pair gone, user lines kept, new source line added" \
    "! grep -qF 'ai-tooling' '$D/.bashrc' && grep -qxF 'export A=1' '$D/.bashrc' && grep -qxF 'export B=2' '$D/.bashrc' && grep -qxF 'source \"$ALIASES\"' '$D/.bashrc'"
check "rc: one .bashrc backup, holding the pre-migration content" \
    "[ \"\$(backups '$D' .bashrc)\" = 1 ] && cmp -s \"\$(find '$D' -maxdepth 1 -name '.bashrc.bak.*')\" '$TMP_ROOT/rc.bashrc.before'"
check "rc: existing .zshrc gets the integration lines" "grep -qxF '$MARKER' '$D/.zshrc' && grep -qxF 'setopt x' '$D/.zshrc'"
run_setup rc2 "$D"
check "rc: re-run leaves both rc files alone (integration unchanged)" \
    "summary_has rc2 'OK|shell|integration unchanged' && [ \"\$(cl '$D/.bashrc' '$MARKER')\" = 1 ] && [ \"\$(cl '$D/.zshrc' '$MARKER')\" = 1 ]"

# --- MDM: aliases.sh absent ---
D=$(new_dir mdm)
run_setup mdm "$D" "$NO_ALIASES"
check "MDM: exit 0, WARN aliases.sh not found, block still written, no .bashrc" \
    "[ \"\$(rc_of mdm)\" = 0 ] && summary_has mdm 'WARN|shell|aliases.sh not found' && [ \"\$(cl '$D/.bash_profile' '$PS')\" = 1 ] && [ ! -e '$D/.bashrc' ]"

printf '\n%d passed, %d failed, %d skipped (bash: %s)\n' "$PASS" "$FAIL" "$SKIP" "$("$BASH_BIN" -c 'echo $BASH_VERSION')"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
