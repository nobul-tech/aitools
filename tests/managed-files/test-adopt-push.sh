#!/usr/bin/env bash
# test-adopt-push.sh -- tests for N-Q2 in scripts/aitools-lib.sh: an adopt into
# the dotprofile through deploy_managed_file (accept & adopt, merge & adopt,
# JSON field adopt) is committed (that file only) and pushed by
# dotprofile_commit_push; an adopt target outside the dotprofile is not
# committed; commit and push failures are a warning + ACTION and leave the
# deploy outcome unchanged.
#
# Safe to re-run: every case runs in its own temp HOME with a throwaway
# dotprofile git repo and a bare remote, removed on exit. The real dotprofile is
# never touched (AITOOLS_USER_REPO_PATH points into the temp dir; git's global
# and system config are ignored). Interactive cases run on a pseudo-terminal
# (tests/managed-files/pty-run.py, python3). Platform: macOS, Linux (Git Bash:
# pty cases are skipped). Exit 1 if any case fails.
# Spec: .claude/rules/managed-file-deployment.md "Adopt target";
# reference/managed-file-deployment.md.
#
# Usage: bash tests/managed-files/test-adopt-push.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 18' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/aitools-lib.sh"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
# The user's git config (signing, hooks, templates) must not reach these repos.
: > "$TMP_ROOT/gitconfig"
export GIT_CONFIG_GLOBAL="$TMP_ROOT/gitconfig" GIT_CONFIG_NOSYSTEM=1

PASS=0
FAIL=0
SKIP=0
HAVE_PTY=true
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) HAVE_PTY=false ;; esac
command -v python3 >/dev/null 2>&1 || HAVE_PTY=false

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

g() { git -C "$@" >/dev/null 2>&1; }   # quiet git for fixture setup; each use is followed by a check

# setup_case NAME: temp HOME, dotprofile repo DP (main, pushed to bare remote
# REMOTE), an unrelated repo OTHER, stub bin. DP holds claude/rules/r.md and
# profile.json, committed and pushed.
setup_case() {
    C="$TMP_ROOT/$1"
    DP="$C/dotprofile"; REMOTE="$C/remote.git"; OTHER="$C/other"
    # DPD: DP as the lib's display_path prints it in ACTION rows (Windows form under Git Bash)
    if command -v cygpath >/dev/null 2>&1; then DPD=$(cygpath -w "$DP"); else DPD="$DP"; fi
    mkdir -p "$C/home" "$C/dest" "$C/bin" "$DP/claude/rules" "$OTHER"
    git init -q --bare -b main "$REMOTE"
    git init -q -b main "$DP"
    git init -q -b main "$OTHER"
    local r
    for r in "$DP" "$OTHER"; do
        g "$r" config user.name "Test User"; g "$r" config user.email "test@example.com"
    done
    printf 'source rule\n' > "$DP/claude/rules/r.md"
    printf '{"a":1,"b":2}\n' > "$DP/profile.json"
    printf 'notes\n' > "$DP/notes.md"
    g "$DP" add -A; g "$DP" commit -q -m init; g "$DP" remote add origin "$REMOTE"; g "$DP" push -q -u origin main
    printf 'other source\n' > "$OTHER/o.md"
    g "$OTHER" add -A; g "$OTHER" commit -q -m init
    : > "$C/summary"
    if [ "$(git -C "$REMOTE" rev-parse main 2>/dev/null)" != "$(git -C "$DP" rev-parse HEAD 2>/dev/null)" ]; then
        printf 'FAIL fixture %s: dotprofile not pushed to its remote\n' "$1"; FAIL=$((FAIL + 1))
    fi
}

# run_lib SNIPPET [INPUT]: source the lib in a fresh bash under the case HOME.
# No INPUT -> stdin /dev/null (non-interactive); INPUT -> pty keystrokes.
# The snippet starts as a caller that ran resolve_user_repo_path
# (AITLIB_USER_REPO_PATH=DP, as setup-user-claude does); RUN_UNRESOLVED=1 leaves
# it unset so the helper asks the resolver (AITOOLS_USER_REPO_PATH=DP).
run_lib() {
    local snippet="$1" input="${2:-}" pre="AITLIB_USER_REPO_PATH='$DP'"
    if [ -n "${RUN_UNRESOLVED:-}" ]; then pre=":"; fi
    printf '%s\n' "set -euo pipefail" "source '$LIB'" "logging_init t" "$pre" "$snippet" > "$C/snippet.sh"
    local envs=(HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary"
        AITOOLS_USER_REPO_PATH="$DP" PATH="$C/bin:$PATH" TERM=dumb)
    if [ -z "$input" ]; then
        env "${envs[@]}" bash "$C/snippet.sh" < /dev/null > "$C/out" 2>&1
        echo $? > "$C/rc"
    else
        env "${envs[@]}" python3 "$PTY" --input "$input" --log "$C/out" -- bash "$C/snippet.sh"
        echo $? > "$C/rc"
    fi
    LOG="$C/logs/deploy.log"
    [ -f "$LOG" ] || : > "$LOG"
}

result() { cat "$C/result" 2>/dev/null; }
push_state() { cat "$C/push" 2>/dev/null; }
remote_has() { [ "$(git -C "$REMOTE" show "main:$1" 2>/dev/null)" = "$2" ]; }  # absent = not pushed (asserted)
head_msg() { git -C "$DP" log -1 --format=%s 2>/dev/null; }
commits() { git -C "$DP" rev-list --count HEAD 2>/dev/null; }
committed_files() { git -C "$DP" show --name-only --format= HEAD 2>/dev/null | tr '\n' ' '; }
# DMF: deploy_managed_file SRCF -> DEST with adopt target ADOPT; result and push state to $C
DMF='deploy_managed_file "$(cat "$SRCF")" "$DEST" tool item "$ADOPT"; printf "%s" "$MANAGED_FILE_RESULT" > "$C/result"; printf "%s" "${AITLIB_DOTPROFILE_PUSH:-unset}" > "$C/push"'
# DCP FILE MSG: call the helper directly
dcp() { printf 'dotprofile_commit_push %q %q; printf "%%s" "$AITLIB_DOTPROFILE_PUSH" > %q' "$1" "$2" "$C/push"; }

# ---------------------------------------------------------------------------
# Helper, called directly (non-interactive)
# ---------------------------------------------------------------------------
setup_case direct-pushed
printf 'edited rule\n' > "$DP/claude/rules/r.md"
printf 'unrelated hand edit\n' > "$DP/notes.md"          # unstaged, unrelated
printf 'staged\n' > "$DP/staged.md"; g "$DP" add staged.md  # staged, unrelated
RUN_UNRESOLVED=1 run_lib "$(dcp "$DP/claude/rules/r.md" "Adopt r.md from the deployed copy")"
check "direct (dotprofile from the resolver): committed-pushed" "[ \"\$(push_state)\" = committed-pushed ]"
check "direct: commit holds that file only" "[ \"\$(committed_files)\" = 'claude/rules/r.md ' ] && [ \"\$(head_msg)\" = 'Adopt r.md from the deployed copy' ]"
check "direct: remote has the adopted file" "remote_has claude/rules/r.md 'edited rule'"
check "direct: unrelated unstaged change not committed" "grep -qx 'unrelated hand edit' '$DP/notes.md' && remote_has notes.md notes && [ -n \"\$(git -C '$DP' diff --name-only -- notes.md)\" ]"
check "direct: unrelated staged file still staged, not committed" "[ \"\$(git -C '$DP' diff --cached --name-only)\" = staged.md ] && ! git -C '$REMOTE' cat-file -e main:staged.md 2>/dev/null"
check "direct: ok line logged, no warning" "grep -q '\[ok\] dotprofile: claude/rules/r.md committed and pushed' '$LOG' && ! grep -q '\[warn\]' '$LOG' && ! grep -q '^ACTION' '$C/summary'"

setup_case direct-unchanged
run_lib "$(dcp "$DP/claude/rules/r.md" "Adopt r.md")"
check "unchanged: no commit, no push, no warning" "[ \"\$(push_state)\" = unchanged ] && [ \"\$(commits)\" = 1 ] && ! grep -q '\[warn\]' '$LOG' && ! grep -q '^ACTION' '$C/summary'"

setup_case direct-new-file
printf 'brand new\n' > "$DP/claude/rules/new.md"
run_lib "$(dcp "$DP/claude/rules/new.md" "Adopt new.md")"
check "new (untracked) file: added, committed, pushed" "[ \"\$(push_state)\" = committed-pushed ] && remote_has claude/rules/new.md 'brand new'"

setup_case direct-other-repo
printf 'other edit\n' > "$OTHER/o.md"
RUN_UNRESOLVED=1 run_lib "$(dcp "$OTHER/o.md" "Adopt o.md")"
check "not in the dotprofile (dotprofile from the resolver): nothing committed" "[ \"\$(push_state)\" = not-dotprofile ] && [ -n \"\$(git -C '$OTHER' diff --name-only)\" ] && [ \"\$(git -C '$OTHER' rev-list --count HEAD)\" = 1 ]"

setup_case direct-preresolved
printf 'edited\n' > "$DP/claude/rules/r.md"
run_lib "AITLIB_USER_REPO_PATH='$OTHER'; $(dcp "$DP/claude/rules/r.md" "Adopt r.md")"
check "caller-resolved dotprofile wins (AITLIB_USER_REPO_PATH), no resolver call" "[ \"\$(push_state)\" = not-dotprofile ] && [ \"\$(commits)\" = 1 ]"
run_lib "AITLIB_USER_REPO_PATH=''; $(dcp "$DP/claude/rules/r.md" "Adopt r.md")"
check "caller resolved shared-only (\"\"): not-dotprofile" "[ \"\$(push_state)\" = not-dotprofile ] && [ \"\$(commits)\" = 1 ]"

setup_case direct-push-fail
g "$DP" remote remove origin
printf 'edited rule\n' > "$DP/claude/rules/r.md"
run_lib "$(dcp "$DP/claude/rules/r.md" "Adopt r.md")"
check "push failure: push-failed, committed locally" "[ \"\$(push_state)\" = push-failed ] && [ \"\$(commits)\" = 2 ]"
check "push failure: WARN logged, ACTION 'run git push in <dotprofile>'" "grep -q '\[warn\] dotprofile push failed' '$LOG' && grep -qxF 'ACTION||run git push in $DPD' '$C/summary'"
check "push failure: exit 0 (the run continues)" "[ \"\$(cat '$C/rc')\" = 0 ]"

setup_case direct-push-rejected
git clone -q -b main "$REMOTE" "$C/elsewhere"
g "$C/elsewhere" config user.name x; g "$C/elsewhere" config user.email x@example.com
printf 'from elsewhere\n' > "$C/elsewhere/notes.md"; g "$C/elsewhere" commit -q -am other; g "$C/elsewhere" push -q
printf 'edited rule\n' > "$DP/claude/rules/r.md"
run_lib "$(dcp "$DP/claude/rules/r.md" "Adopt r.md")"
check "push rejected: push-failed, ACTION pull --rebase" "[ \"\$(push_state)\" = push-failed ] && grep -q '\[warn\] dotprofile push rejected' '$LOG' && grep -qxF 'ACTION||git pull --rebase, then git push in $DPD' '$C/summary'"

setup_case direct-commit-fail
printf '#!/bin/sh\nexit 1\n' > "$DP/.git/hooks/pre-commit"; chmod +x "$DP/.git/hooks/pre-commit"
printf 'edited rule\n' > "$DP/claude/rules/r.md"
run_lib "$(dcp "$DP/claude/rules/r.md" "Adopt r.md")"
check "commit failure: commit-failed, WARN + ACTION, nothing pushed" "[ \"\$(push_state)\" = commit-failed ] && grep -q '\[warn\] dotprofile commit failed' '$LOG' && grep -qxF 'ACTION||commit and push claude/rules/r.md in $DPD' '$C/summary' && remote_has claude/rules/r.md 'source rule'"

setup_case direct-action-once
g "$DP" remote remove origin
printf 'e1\n' > "$DP/claude/rules/r.md"; printf '{"a":9}\n' > "$DP/profile.json"
run_lib "$(dcp "$DP/claude/rules/r.md" "Adopt r.md"); $(dcp "$DP/profile.json" "Adopt profile.json")"
check "two push failures in one run: one ACTION row" "[ \"\$(grep -cxF 'ACTION||run git push in $DPD' '$C/summary')\" = 1 ]"

# ---------------------------------------------------------------------------
# Through deploy_managed_file (interactive adopt)
# ---------------------------------------------------------------------------
if $HAVE_PTY; then
    setup_case adopt-dotprofile
    printf 'local edit\n' > "$C/dest/r.md"
    printf 'unrelated hand edit\n' > "$DP/notes.md"
    # Unresolved caller, as deploy-harness (dotprofile from config.json, no resolver call)
    RUN_UNRESOLVED=1 run_lib "C='$C' SRCF='$DP/claude/rules/r.md' DEST='$C/dest/r.md' ADOPT='$DP/claude/rules/r.md'; $DMF" "a\n"
    check "accept & adopt into the dotprofile: result accept & adopt, committed-pushed" "[ \"\$(result)\" = 'accept & adopt' ] && [ \"\$(push_state)\" = committed-pushed ]"
    check "accept & adopt: remote has LOCAL, commit is that file only" "remote_has claude/rules/r.md 'local edit' && [ \"\$(committed_files)\" = 'claude/rules/r.md ' ] && [ \"\$(head_msg)\" = 'Adopt r.md from the deployed copy' ]"
    check "accept & adopt: unrelated change not committed, no 'Uncommitted change' line" "[ -n \"\$(git -C '$DP' diff --name-only -- notes.md)\" ] && ! grep -q 'Uncommitted change in' '$LOG'"
    check "accept & adopt: the backup file is not committed" "! git -C '$REMOTE' ls-tree -r --name-only main | grep -q 'bak'"

    setup_case merge-dotprofile
    printf '#!/usr/bin/env bash\ncat > /dev/null\nprintf "# Title\\nmerged line\\n"\n' > "$C/bin/claude"; chmod +x "$C/bin/claude"
    printf '# Title\nsource line\n' > "$DP/claude/rules/r.md"; g "$DP" commit -q -am src; g "$DP" push -q
    printf '# Title\nlocal line\n' > "$C/dest/r.md"
    run_lib "C='$C' SRCF='$DP/claude/rules/r.md' DEST='$C/dest/r.md' ADOPT='$DP/claude/rules/r.md'; $DMF" "m\ny\n"
    check "merge & adopt into the dotprofile: committed and pushed" "[ \"\$(result)\" = 'accept & adopt' ] && [ \"\$(push_state)\" = committed-pushed ] && remote_has claude/rules/r.md \"\$(printf '# Title\nmerged line')\""

    setup_case json-dotprofile
    printf '{"a":9,"b":2}\n' > "$C/dest/profile.json"
    run_lib "C='$C' SRCF='$DP/profile.json' DEST='$C/dest/profile.json' ADOPT='$DP/profile.json'; $DMF" "a\n"
    check "JSON field adopt into the dotprofile: committed and pushed" "[ \"\$(result)\" = 'accept & adopt' ] && [ \"\$(push_state)\" = committed-pushed ] && [ \"\$(git -C '$REMOTE' show main:profile.json | tr -d ' \n')\" = '{\"a\":9,\"b\":2}' ]"

    setup_case adopt-push-fail
    g "$DP" remote remove origin
    printf 'local edit\n' > "$C/dest/r.md"
    run_lib "C='$C' SRCF='$DP/claude/rules/r.md' DEST='$C/dest/r.md' ADOPT='$DP/claude/rules/r.md'; $DMF" "a\n"
    check "adopt, push fails: outcome still accept & adopt, files written" "[ \"\$(result)\" = 'accept & adopt' ] && grep -qx 'local edit' '$DP/claude/rules/r.md' && grep -qx 'local edit' '$C/dest/r.md' && [ \"\$(cat '$C/rc')\" = 0 ]"
    check "adopt, push fails: push-failed, WARN + ACTION" "[ \"\$(push_state)\" = push-failed ] && grep -q '\[warn\] dotprofile push failed' '$LOG' && grep -qxF 'ACTION||run git push in $DPD' '$C/summary'"

    setup_case adopt-other-repo
    printf 'local edit\n' > "$C/dest/o.md"
    run_lib "C='$C' SRCF='$OTHER/o.md' DEST='$C/dest/o.md' ADOPT='$OTHER/o.md'; $DMF" "a\n"
    check "adopt outside the dotprofile: working tree only, not committed" "[ \"\$(result)\" = 'accept & adopt' ] && [ \"\$(push_state)\" = not-dotprofile ] && grep -qx 'local edit' '$OTHER/o.md' && [ \"\$(git -C '$OTHER' rev-list --count HEAD)\" = 1 ]"
    check "adopt outside the dotprofile: 'Uncommitted change' logged, dotprofile untouched" "grep -q 'Uncommitted change in' '$LOG' && [ \"\$(commits)\" = 1 ]"
else
    printf 'SKIP interactive cases (no python3 pty on this platform)\n'; SKIP=$((SKIP + 1))
fi

# ---------------------------------------------------------------------------
# No adopt: overwrite never commits
# ---------------------------------------------------------------------------
setup_case overwrite-no-commit
printf 'local edit\n' > "$C/dest/r.md"
run_lib "C='$C' SRCF='$DP/claude/rules/r.md' DEST='$C/dest/r.md' ADOPT='$DP/claude/rules/r.md'; $DMF"
check "non-interactive overwrite: dotprofile untouched, helper not called" "[ \"\$(result)\" = updated ] && [ \"\$(push_state)\" = unset ] && [ \"\$(commits)\" = 1 ]"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
