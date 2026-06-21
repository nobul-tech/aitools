#!/usr/bin/env bash
# Verify the LIVE ~/.bash_profile resolves managed tools correctly in a fresh
# login-shell-like environment (pristine PATH, profile sourced).
set -uo pipefail

echo "===== live ~/.bash_profile managed block ====="
grep -nA12 '# >>> aitools managed >>>' "$HOME/.bash_profile"

echo
echo "===== marker counts (expect 1 each) ====="
echo "start: $(grep -cF '# >>> aitools managed >>>' "$HOME/.bash_profile")"
echo "end:   $(grep -cF '# <<< aitools managed <<<' "$HOME/.bash_profile")"

echo
echo "===== fresh login shell resolution ====="
env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash --noprofile --norc -c '
    source "$HOME/.bash_profile" 2>/tmp/verify_live_err.log
    echo "PATH head: $(echo "$PATH" | cut -d: -f1-4)"
    echo "python3 -> $(command -v python3) ($(python3 --version 2>&1))"
    echo "bash    -> $(command -v bash) ($(bash --version 2>&1 | head -1))"
    echo "agent   -> $(command -v agent)"
'
echo "----- sourcing stderr (expected: autoload not found) -----"
cat /tmp/verify_live_err.log 2>/dev/null || true
