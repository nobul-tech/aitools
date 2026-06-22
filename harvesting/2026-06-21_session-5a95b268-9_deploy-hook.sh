#!/usr/bin/env bash
# Deploy the fire-and-forget session-archive.sh: rebuild MDM templates, then
# deploy hooks to ~/.claude/hooks/. Output goes to logs (smoke-test-pattern);
# we check exit codes here and only surface the logs on failure.
set -uo pipefail

REPO="/Users/new-jose/repos/aitools"
LOGDIR="$REPO/.scratch/session-5a95b268-9"

echo "=== 1. build-deploy.sh (regenerate deploy/ MDM templates) ==="
bash "$REPO/scripts/build-deploy.sh" > "$LOGDIR/build-deploy.log" 2>&1
rc_build=$?
echo "build-deploy exit: $rc_build"

echo
echo "=== 2. setup-user-hooks.sh (deploy to ~/.claude/hooks/) ==="
# Non-tty stdin auto-selects overwrite (interactive-menus rule).
bash "$REPO/scripts/setup-user-hooks.sh" > "$LOGDIR/setup-hooks.log" 2>&1
rc_hooks=$?
echo "setup-user-hooks exit: $rc_hooks"

echo
echo "=== 3. verify deployed hook matches source ==="
if diff -q "$REPO/shared/hooks/session-archive.sh" "$HOME/.claude/hooks/session-archive.sh" > /dev/null 2>&1; then
    echo "MATCH: deployed ~/.claude/hooks/session-archive.sh == source"
else
    echo "MISMATCH: deployed hook differs from source"
    diff "$REPO/shared/hooks/session-archive.sh" "$HOME/.claude/hooks/session-archive.sh" || true
fi

echo
echo "=== 4. confirm fire-and-forget marker present in deployed file ==="
if grep -q "Fire-and-forget" "$HOME/.claude/hooks/session-archive.sh"; then
    echo "OK: deployed hook has fire-and-forget design"
else
    echo "FAIL: deployed hook is the OLD synchronous version"
fi
