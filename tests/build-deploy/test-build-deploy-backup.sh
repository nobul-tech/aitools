#!/usr/bin/env bash
# test-build-deploy-backup.sh -- build-deploy.sh backs up the dotprofile deploy/
# and swaps a new build in only on success (#86).
#
# Cases (each on its own fixture dotprofile, a git repo with a committed deploy/
# that holds a stale file the real build never generates):
#   success   -- deploy/ replaced (stale file gone), backup made and identical to
#                the old tree, backups pruned to 5 (oldest first), no swap dir left,
#                backups ignored by git (.gitignore '*.bak.*', as `aitools user init`)
#   failure   -- the build fails late (generated PS1 validation, stub pwsh exits 1):
#                exit 1, deploy/ unchanged, the backup kept, no swap dir left
#   first     -- no deploy/ yet: deploy/ created, no backup, "nothing to back up"
#   unignored -- a dotprofile without the ignore line gets a warning
#
# Safe to re-run: every case runs under its own temp HOME and fixture dotprofile
# (removed on exit), passed by AITOOLS_USER_REPO_PATH; the real HOME and the real
# dotprofile are never read or written. A stub pwsh on PATH stands in for the PS1
# validator (exit 0, or exit 1 for the failure case). Needs node, perl and git.
# AITOOLS_TEST_BASH picks the bash that runs build-deploy.sh (default: bash).
# Platform: macOS, Linux (Windows takes the build's Git Bash validation branch,
# which this stub does not reach). Exit 1 on failure.
#
# Usage: bash tests/build-deploy/test-build-deploy-backup.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 24' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 25
        fi
    fi
}

for tool in node perl git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'FAIL %s not found -- cannot run build-deploy.sh\n' "$tool"
        exit 1
    fi
done

# setup_case <name> <pwsh exit> <with deploy/: yes|no> <gitignore: yes|no>
setup_case() {
    C="$TMP_ROOT/$1"
    D="$C/dot"
    mkdir -p "$C/home/.aitools" "$C/bin" "$D"
    printf '#!/usr/bin/env bash\nexit %s\n' "$2" > "$C/bin/pwsh"
    chmod +x "$C/bin/pwsh"
    git -C "$D" init -q
    git -C "$D" config user.email test@example.invalid
    git -C "$D" config user.name test
    if [ "$4" = yes ]; then
        printf '.scratch/\n*.bak.*\n.DS_Store\n' > "$D/.gitignore"
    fi
    printf '# fixture\n' > "$D/README.md"
    if [ "$3" = yes ]; then
        mkdir -p "$D/deploy"
        printf 'old build\n' > "$D/deploy/setup-user-claude.sh"
        printf 'stale generated file\n' > "$D/deploy/stale-only.txt"
        cp -Rp "$D/deploy" "$C/pristine"
    fi
    git -C "$D" add -A
    git -C "$D" commit -q -m fixture
}

run_build() {
    env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
        HOME="$C/home" AITOOLS_USER_REPO_PATH="$D" PATH="$C/bin:$PATH" \
        "$TB" "$ROOT/scripts/build-deploy.sh" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}

count_backups() {
    find "$D" -maxdepth 1 -type d -name 'deploy.bak.*' | wc -l | tr -d ' '
}
count_swap() {
    find "$D" -maxdepth 1 -name 'deploy.swap.bak.*' | wc -l | tr -d ' '
}
newest_backup() {
    find "$D" -maxdepth 1 -type d -name 'deploy.bak.*' | LC_ALL=C sort | tail -n 1
}

# --- success: replace, back up, prune to 5 -------------------------------------
setup_case success 0 yes yes
for n in 1 2 3 4 5 6; do
    mkdir -p "$D/deploy.bak.2020-01-0${n}T000000Z"
    printf 'old backup %s\n' "$n" > "$D/deploy.bak.2020-01-0${n}T000000Z/marker"
done
run_build
check "success: exit 0" "[ \"\$(cat '$C/rc')\" = 0 ]"
check "success: new deploy/ generated" "[ -f '$D/deploy/deploy-harness.sh' ] && ! grep -qx 'old build' '$D/deploy/setup-user-claude.sh'"
check "success: stale generated file removed" "[ ! -e '$D/deploy/stale-only.txt' ]"
check "success: backups pruned to 5" "[ \"\$(count_backups)\" = 5 ]"
check "success: the two oldest backups pruned" "[ ! -e '$D/deploy.bak.2020-01-01T000000Z' ] && [ ! -e '$D/deploy.bak.2020-01-02T000000Z' ] && [ -d '$D/deploy.bak.2020-01-03T000000Z' ]"
NB="$(newest_backup)"
check "success: newest backup is today's run" "case '${NB##*/}' in deploy.bak.2020-*) false ;; deploy.bak.*) true ;; *) false ;; esac"
check "success: backup identical to the old deploy/" "diff -rq '$C/pristine' '$NB' >/dev/null"
check "success: no swap directory left" "[ \"\$(count_swap)\" = 0 ]"
check "success: backups ignored by git" "! git -C '$D' status --porcelain | grep -q 'deploy\\.bak\\.'"
check "success: backup and swap logged" "grep -q 'Backed up deploy/ to' '$C/out' && grep -q 'Pruned old deploy/ backup' '$C/out' && grep -q 'Replaced deploy/' '$C/out'"
check "success: no ignore warning" "! grep -q 'does not ignore' '$C/out'"

# --- failure: late build failure keeps the old deploy/ and the backup ----------
setup_case failure 1 yes yes
run_build
check "failure: exit 1" "[ \"\$(cat '$C/rc')\" = 1 ]"
check "failure: PS1 validation is what failed" "grep -q 'PS1 file(s) failed validation' '$C/out'"
check "failure: deploy/ unchanged" "diff -rq '$C/pristine' '$D/deploy' >/dev/null"
check "failure: one backup kept" "[ \"\$(count_backups)\" = 1 ]"
NB="$(newest_backup)"
check "failure: backup identical to the old deploy/" "[ -n '$NB' ] && diff -rq '$C/pristine' '$NB' >/dev/null"
check "failure: no swap directory left" "[ \"\$(count_swap)\" = 0 ]"
check "failure: git sees no change" "[ -z \"\$(git -C '$D' status --porcelain)\" ]"

# --- first build: no deploy/ yet ------------------------------------------------
setup_case first 0 no yes
run_build
check "first: exit 0" "[ \"\$(cat '$C/rc')\" = 0 ]"
check "first: deploy/ created" "[ -f '$D/deploy/deploy-harness.sh' ]"
check "first: no backup" "[ \"\$(count_backups)\" = 0 ]"
check "first: logged nothing to back up" "grep -q 'nothing to back up' '$C/out'"

# --- unignored: a dotprofile without the ignore line is warned -----------------
setup_case unignored 0 yes no
run_build
check "unignored: exit 0" "[ \"\$(cat '$C/rc')\" = 0 ]"
check "unignored: warning names the fix" "grep -q \"does not ignore deploy.bak\" '$C/out' && grep -q \"add 'deploy.bak.\\*/'\" '$C/out'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
