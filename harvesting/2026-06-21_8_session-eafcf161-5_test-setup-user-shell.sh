#!/usr/bin/env bash
# Throwaway test driver for setup-user-shell.sh -- operates on COPIES of the
# live profiles in a scratch dir, never the real ~/.bash_profile.
set -uo pipefail

REPO="/Users/new-jose/repos/aitools"
T="$REPO/.scratch/session-eafcf161-5/shelltest"
rm -rf "$T"
mkdir -p "$T"

# Copy live profiles into the fake profile dir
cp "$HOME/.bash_profile" "$T/.bash_profile"
cp "$HOME/.bashrc" "$T/.bashrc" 2>/dev/null || true

echo "===== ORIGINAL .bash_profile ====="
cat "$T/.bash_profile"

echo
echo "===== RUN 1 ====="
AITOOLS_PROFILE_DIR="$T" bash "$REPO/scripts/setup-user-shell.sh"
echo "exit: $?"

echo
echo "===== RUN 2 (idempotency) ====="
AITOOLS_PROFILE_DIR="$T" bash "$REPO/scripts/setup-user-shell.sh"
echo "exit: $?"

echo
echo "===== RESULT .bash_profile ====="
cat "$T/.bash_profile"

echo
echo "===== marker counts (expect 1 each) ====="
echo "start: $(grep -cF '# >>> aitools managed >>>' "$T/.bash_profile")"
echo "end:   $(grep -cF '# <<< aitools managed <<<' "$T/.bash_profile")"

echo
echo "===== RESOLVED PATH after sourcing result (subshell) ====="
# Source the resulting profile with a representative pristine PATH, then report
# order + what wins. Run in a child bash; tolerate the known zsh-line errors.
env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash --noprofile --norc -c '
    source "'"$T"'/.bash_profile" 2>/tmp/shelltest_src_err.log
    echo "PATH=$PATH"
    echo "python3 -> $(command -v python3)"
    echo "bash    -> $(command -v bash)"
    echo "agent   -> $(command -v agent)"
'
echo "----- stderr from sourcing (expected: autoload/compinit not found) -----"
cat /tmp/shelltest_src_err.log 2>/dev/null || true
