#!/usr/bin/env bash
# test-sh-file-fixup.sh -- tests for shared/hooks/sh-file-fixup.sh (PostToolUse, Write|Edit).
#
# Covers: a .sh with CRLF, mode 644 and git index 100644 is fixed (LF, +x,
# index 100755) and the report reaches Claude as stdout
# hookSpecificOutput.additionalContext (event PostToolUse) equal to the
# stderr text; the hook runs from a cwd outside the file's repo (git -C);
# a second run has nothing to fix (no output); a failed git update-index
# (index.lock held) is reported as "fix failed", never as fixed; non-.sh,
# missing file, empty and malformed input are silent with exit 0.
# The executable-bit checks are skipped on Windows Git Bash (no POSIX modes).
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Usage: bash tests/hooks/test-sh-file-fixup.sh
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-sh-file-fixup.sh

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook-test-lib.sh"

HOOK="${TEST_HOOK_OVERRIDE:-$HOOKS/sh-file-fixup.sh}"  # override: run against another copy (regression checks)
POSIX_MODES=true
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) POSIX_MODES=false ;; esac

REPOD="$WORK/repo"
mkdir -p "$REPOD"
git -C "$REPOD" init -q
git -C "$REPOD" config user.email t@example.com
git -C "$REPOD" config user.name t
git -C "$REPOD" config core.autocrlf false

payload() {  # payload <file path> > file
    printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s","content":"x"},"tool_response":{"success":true}}' "$NOGIT" "$1"
}

has_cr() { perl -ne 'exit 1 if /\r/' "$1"; }  # exit 0 = no CR

echo "== CRLF + 644 + index 100644: fixed, reported to Claude =="
F="$REPOD/a.sh"
printf '#!/usr/bin/env bash\r\necho hi\r\n' > "$F"
chmod 644 "$F"
git -C "$REPOD" add a.sh
git -C "$REPOD" update-index --chmod=-x a.sh
payload "$F" > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "exit 0" [ "$RC" -eq 0 ]
check "CRLF removed" has_cr "$F"
if $POSIX_MODES; then
    check "executable on disk" [ -x "$F" ]
    check "stderr names CRLF->LF, +x and git+x" contains "$ERR" "fixed: CRLF->LF +x git+x"
else
    skip "executable on disk (Windows: no POSIX modes)"
    check "stderr names CRLF->LF and git+x" contains "$ERR" "git+x"
fi
check "git index is 100755 (git -C, cwd outside the repo)" [ "$(git -C "$REPOD" ls-files -s a.sh | cut -c1-6)" = "100755" ]
check "stdout is PostToolUse additionalContext equal to stderr" ctx_is PostToolUse "$ERR"
check "stdout is one line" [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" = "1" ]

echo "== second run: nothing to fix =="
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "exit 0" [ "$RC" -eq 0 ]
check "no stdout" [ -z "$OUT" ]
check "no stderr" [ -z "$ERR" ]

echo "== git update-index fails (index.lock): reported as failed =="
G="$REPOD/b.sh"
printf '#!/usr/bin/env bash\necho b\n' > "$G"
chmod 755 "$G"
git -C "$REPOD" add b.sh
git -C "$REPOD" update-index --chmod=-x b.sh
: > "$REPOD/.git/index.lock"
payload "$G" > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
rm -f "$REPOD/.git/index.lock"
check "exit 0" [ "$RC" -eq 0 ]
check "stderr says fix failed: git+x" contains "$ERR" "fix failed: git+x"
check "stderr does not claim git+x fixed" eval '! contains "$ERR" "fixed: git+x"'
check "stdout additionalContext equals stderr" ctx_is PostToolUse "$ERR"
check "index still 100644" [ "$(git -C "$REPOD" ls-files -s b.sh | cut -c1-6)" = "100644" ]

echo "== file name with spaces and a quote-like character =="
H="$REPOD/my file's.sh"
printf 'echo x\r\n' > "$H"
payload "$H" > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "exit 0" [ "$RC" -eq 0 ]
check "stdout is valid JSON with the name" ctx_has PostToolUse "my file's.sh"

echo "== exemptions: silent, exit 0 =="
printf 'x\r\n' > "$REPOD/c.txt"
payload "$REPOD/c.txt" > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "non-.sh: exit 0, no output" quiet0
check "non-.sh: CR left alone" eval '! has_cr "$REPOD/c.txt"'
payload "$REPOD/missing.sh" > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "missing file: exit 0, no output" quiet0
: > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "empty input: exit 0, no output" quiet0
printf '{"tool_input":{"file_path":' > "$WORK/p.json"
run_hook "$HOOK" "$WORK/p.json" "$NOGIT"
check "malformed input: exit 0, no output" quiet0

finish_tests "test-sh-file-fixup"
