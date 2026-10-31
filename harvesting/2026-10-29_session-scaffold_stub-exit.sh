#!/usr/bin/env bash
# stub-exit.sh -- run every packaging stub under an isolated HOME and record its exit code
set -uo pipefail
R=/Users/new-jose/repos/aitools
export HOME=/Users/new-jose/repos/aitools/.scratch/session-scaffold/home
for f in packaging/macos/postinstall packaging/macos/aitools-pkg-run.sh packaging/linux/postinst packaging/linux/aitools-setup; do
    "$R/$f" configure > /dev/null 2> "$HOME/stub.err"
    printf 'exit %s %s: %s\n' "$?" "$f" "$(cat "$HOME/stub.err")"
done
for f in packaging/windows/install-system.ps1 packaging/windows/install-user.ps1 packaging/windows/detect-user.ps1; do
    pwsh -NoProfile -File "$R/$f" > "$HOME/stub.out" 2> "$HOME/stub.err"
    printf 'exit %s %s: stdout=[%s] stderr=%s\n' "$?" "$f" "$(cat "$HOME/stub.out")" "$(cat "$HOME/stub.err")"
done
