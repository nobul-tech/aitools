#!/usr/bin/env bash
# a123b-full.sh -- fidelity check: run the WHOLE setup-user-cursor.sh (steps 1-5;
# rg and agent stubbed on PATH) on the happy fixture and keep the step 4/5
# summary rows, to compare with the a123b-step45.sh driver run.
set -uo pipefail
S="/Users/new-jose/repos/aitools/.claude/worktrees/fo-aud123b/.scratch/session-a123b"
WT="/Users/new-jose/repos/aitools/.claude/worktrees/fo-aud123b"
C="$S/out/full"
if [ -d "$C" ]; then chmod -R u+rwx "$C"; rm -rf "$C"; fi
mkdir -p "$C/bin" "$C/sh"
printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$C/bin/rg"
printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$C/bin/agent"
chmod +x "$C/bin/rg" "$C/bin/agent"
# Reuse the runner's happy seed: copy the seeded HOME from the driver run's fixture
cp -R "$S/out/happy/sh/.aitools" "$C/sh/.aitools.tmp"
H="$C/sh"
# re-seed fresh (the driver run changed its HOME): source the seed functions
eval "$(perl -ne 'print if /^MARK=/ || /^skill\(\)/ || /^rmanifest\(\)/ || /^smanifest\(\)/ || (/^base_tree\(\) \{/ .. /^\}/) || (/^manifests_ok\(\) \{/ .. /^\}/)' "$S/a123b-runner.sh")"
rm -rf "$C/sh/.aitools.tmp"
base_tree
manifests_ok
: > "$C/summary"
env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_LOG_DIR -u AITOOLS_USER_REPO_PATH HOME="$H" USERPROFILE="$H" \
    AITOOLS_SUMMARY_FILE="$C/summary" PATH="$C/bin:$PATH" NO_COLOR=1 \
    bash "$WT/scripts/setup-user-cursor.sh" < /dev/null > "$C/out" 2>&1
echo "full script exit: $?"
grep -E '^(ACTION\|\|Cursor|[A-Z]+\|cursor (rules|skills)\|)' "$C/summary" > "$C/rows"
grep -E '^(ACTION\|\|Cursor|[A-Z]+\|cursor (rules|skills)\|)' "$S/out/happy/sh.summary" > "$C/rows-driver"
if cmp -s "$C/rows" "$C/rows-driver"; then echo "step 4/5 rows: identical to the driver run"; else echo "step 4/5 rows differ:"; diff "$C/rows-driver" "$C/rows"; fi
