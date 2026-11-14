#!/usr/bin/env bash
# Run the new suite with a fake `uname` (Linux) on PATH, to exercise its dev-*/mdm-*
# code paths on this Windows machine. Build cases may misbehave (native tools get
# POSIX paths); only the dev/mdm lines matter here.
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
T=$(mktemp -d)
mkdir -p "$T/bin"
printf '#!/usr/bin/env bash\necho Linux\n' > "$T/bin/uname"
chmod +x "$T/bin/uname"
PATH="$T/bin:$PATH" bash "$WT/tests/pywinpty/test-setup-pywinpty.sh"
echo "suite rc=$?"
rm -rf "$T"
