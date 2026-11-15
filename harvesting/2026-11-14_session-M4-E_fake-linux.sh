#!/usr/bin/env bash
# Exercise setup-pywinpty.sh's POSIX path on Windows with a fake `uname` (prints Linux),
# to see the summary row and whether anything is written under HOME.
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
T=$(mktemp -d)
mkdir -p "$T/bin" "$T/home" "$T/logs"
printf '#!/usr/bin/env bash\necho Linux\n' > "$T/bin/uname"
chmod +x "$T/bin/uname"
: > "$T/summary"
env -u AITOOLS_DRY_RUN PATH="$T/bin:$PATH" HOME="$T/home" AITOOLS_LOG_DIR="$T/logs" AITOOLS_SUMMARY_FILE="$T/summary" \
    bash "$WT/scripts/setup-pywinpty.sh" --dry-run < /dev/null
echo "rc=$?"
echo "--- summary:"; cat -A "$T/summary"
echo "--- HOME files:"; find "$T/home" -type f
echo "--- log:"; grep -e 'n/a on' -e 'DRY RUN' "$T/logs/deploy.log"
rm -rf "$T"
