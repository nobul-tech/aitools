#!/usr/bin/env bash
# mirror.sh -- Windows-only development aid: run tests/setup-user-shell/test-setup-user-shell.sh
# against a COPY of setup-user-shell.sh with the POSIX OS guard removed, in Git Bash.
# Deviations from a real macOS/Linux run (recorded in the notes): GNU userland of Git Bash,
# display_path overridden to print the POSIX path (Git Bash has cygpath).
set -euo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/console-profile
M=$WT/.scratch/session-M3-A/mirror
rm -rf "$M"
mkdir -p "$M/scripts" "$M/tests/setup-user-shell"
cp "$WT/scripts/aitools-lib.sh" "$M/scripts/aitools-lib.sh"
perl -0pe 's/case "\$\(uname -s\)" in\n    MINGW\*\|MSYS\*\|CYGWIN\*\)\n.*?esac\n//s or die "guard not found\n"; s/(logging_init "setup-user-shell"\n)/$1display_path() { printf "%s" "\$1"; }\n/ or die "logging_init not found\n"' \
    "$WT/scripts/setup-user-shell.sh" > "$M/scripts/setup-user-shell.sh"
perl -0pe 's/case "\$\(uname -s\)" in\n    MINGW\*\|MSYS\*\|CYGWIN\*\)\n.*?esac\n//s or die "skip not found\n"' \
    "$WT/tests/setup-user-shell/test-setup-user-shell.sh" > "$M/tests/setup-user-shell/test-setup-user-shell.sh"
grep -c MINGW "$M/scripts/setup-user-shell.sh" "$M/tests/setup-user-shell/test-setup-user-shell.sh" || true
bash "$M/tests/setup-user-shell/test-setup-user-shell.sh"
