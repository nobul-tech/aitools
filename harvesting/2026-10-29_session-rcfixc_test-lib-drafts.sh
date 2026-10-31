#!/usr/bin/env bash
# test-lib-drafts.sh OUT_LIB_DIR -- functional checks of the L181a / L182 drafts on
# a patched scripts/aitools-lib.sh, under an isolated HOME (mktemp -d).
set -uo pipefail
lib="$1/aitools-lib.sh"
H=$(mktemp -d /tmp/rcfixc-home.XXXXXX)
export HOME="$H"
mkdir -p "$H/.aitools/logs"
# shellcheck source=/dev/null
source "$lib"
logging_init "rcfixc-test"
pass=0; fail=0
ok() { echo "PASS: $1"; pass=$((pass + 1)); }
no() { echo "FAIL: $1"; fail=$((fail + 1)); }

# L181a: a directory holding only *.mdc gets backed up
d="$H/.cursor/rules"; mkdir -p "$d"; printf 'x\n' > "$d/a.mdc"
backup_dir "$d"
n=$(find "$H/.cursor" -maxdepth 1 -name 'rules.bak.*' -type d | wc -l | tr -d ' ')
if [ "$n" = "1" ]; then ok "mdc-only dir backed up"; else no "mdc-only dir backed up (found $n)"; fi
# empty dir: no backup
e="$H/empty"; mkdir -p "$e"; backup_dir "$e"
n=$(find "$H" -maxdepth 1 -name 'empty.bak.*' -type d | wc -l | tr -d ' ')
if [ "$n" = "0" ]; then ok "empty dir not backed up"; else no "empty dir not backed up (found $n)"; fi
# prune keeps 5: make 6 old backups, run once more
for i in 1 2 3 4 5 6; do mkdir -p "$H/.cursor/rules.bak.2020-01-0${i}T000000Z"; done
backup_dir "$d"
n=$(find "$H/.cursor" -maxdepth 1 -name 'rules.bak.*' -type d | wc -l | tr -d ' ')
if [ "$n" = "5" ]; then ok "pruned to 5"; else no "pruned to 5 (found $n)"; fi

# L182: the reject reason survives when invoke_ai runs in this shell (no AI CLI on PATH)
PATH_SAVE="$PATH"
export PATH="/usr/bin:/bin"
tmp=$(mktemp)
invoke_ai balanced none _merge_validate 1 <<< "prompt" > "$tmp" || true
export PATH="$PATH_SAVE"
if [ "$AI_REJECT_REASON" = "No AI CLI available (claude or agent)" ]; then ok "reason kept: $AI_REJECT_REASON"; else no "reason kept (got '$AI_REJECT_REASON')"; fi
# old form loses it
AI_REJECT_REASON=""
export PATH="/usr/bin:/bin"
old=$(printf '%s' "prompt" | invoke_ai balanced none _merge_validate 1) || true
export PATH="$PATH_SAVE"
if [ -z "$AI_REJECT_REASON" ]; then ok "old form loses the reason (bug reproduced)"; else no "old form unexpectedly kept '$AI_REJECT_REASON'"; fi
rm -f "$tmp"
echo "passed=$pass failed=$fail HOME=$H"
