#!/usr/bin/env bash
# ps1-on-macos.sh -- run tests/deploy-harness/test-deploy-harness.sh against
# deploy-harness.ps1 on macOS pwsh (OS guard stripped in the copy only).
set -euo pipefail
W="/Users/new-jose/repos/aitools/.claude/worktrees/harness-shared"
OUT="$(dirname "$0")/ps1run"
rm -rf "$OUT"
mkdir -p "$OUT/tests/deploy-harness" "$OUT/tests/lib" "$OUT/tests/managed-files" "$OUT/scripts" "$OUT/.claude/rules"
cp -R "$W/tests/deploy-harness/golden" "$OUT/tests/deploy-harness/"
cp "$W/tests/lib/platform-lib.sh" "$OUT/tests/lib/"
cp "$W/tests/managed-files/pty-run.py" "$OUT/tests/managed-files/"
cp "$W/.claude/rules/sources-of-truth.md" "$OUT/.claude/rules/" 2>/dev/null || cp "/Users/new-jose/repos/aitools/.claude/worktrees/harness-shared/.claude/rules/sources-of-truth.md" "$OUT/.claude/rules/"
cp "$W/scripts/aitools-lib.ps1" "$W/scripts/setup-user-config.ps1" "$W/scripts/aitools-profile.ps1" "$W/scripts/aitools-json.ps1" "$OUT/scripts/"
# Strip the Windows OS guard (the if block that refuses non-Windows)
perl -0777 -pe 's/if \(\$PSVersionTable\.PSVersion\.Major -ge 6 -and -not \$IsWindows\) \{.*?\r?\n\}\r?\n//s' \
    "$W/scripts/deploy-harness.ps1" > "$OUT/scripts/deploy-harness.ps1"
if grep -q 'IsWindows' "$OUT/scripts/deploy-harness.ps1"; then
    printf 'guard not stripped\n' >&2
    exit 1
fi
# Force the ps1 language
perl -pe 's/^LANG_RUN="\$TEST_LANG".*/LANG_RUN=ps1/' "$W/tests/deploy-harness/test-deploy-harness.sh" > "$OUT/tests/deploy-harness/test-deploy-harness.sh"
bash "$OUT/tests/deploy-harness/test-deploy-harness.sh"
