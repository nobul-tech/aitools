#!/usr/bin/env bash
# run-phase.sh PHASE [--dry-run] [--cursor-only] -- S3-CursorVerify-Pwsh runner.
# Runs, under the isolated fixture HOME/USERPROFILE (contract v1.0 "Environment"):
#   1. deploy-harness: <fx>/aitools/scripts/deploy-harness.cvps.ps1 -SkipConfig [-DryRun]
#      (a copy of deploy-harness.ps1 in the same directory with only its Windows
#      OS guard disabled; made by this script with perl, diff logged)
#   2. setup-user-cursor: <fx>/aitools/tests/rules-fanout-cursor/step4-driver.ps1
#      <fx>/aitools/scripts/setup-user-cursor.ps1 [-DryRun]  (steps 4 and 5 only)
# stdin /dev/null, rg/agent stubs on PATH, NO_COLOR=1, AITOOLS_* unset.
# Outputs: out/PHASE/{harness,cursor}.{out,summary}, exit.txt, rows.txt, tree.txt, tree-ext.txt, snap.txt
set -uo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
ROOT="$S/fx-main"; A="$ROOT/aitools"; H="$ROOT/home"
PHASE="${1:?usage: run-phase.sh PHASE [--dry-run] [--cursor-only]}"; shift
DRY=""; CURSOR_ONLY=0
for a in "$@"; do
    case "$a" in
        --dry-run) DRY="-DryRun" ;;
        --cursor-only) CURSOR_ONLY=1 ;;
        *) echo "unknown arg $a" >&2; exit 64 ;;
    esac
done
O="$S/out-main/$PHASE"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] [run-phase] [info] %s\n' "$(ts)" "$*"; }
die() { printf '[%s] [run-phase] [error] %s\n' "$(ts)" "$*" >&2; exit 1; }

# --- isolation guard (contract "Never") ---
REAL_HOME=/Users/new-jose
case "$H" in "$REAL_HOME"|"$REAL_HOME/") die "isolated HOME is the real HOME" ;; esac
case "$H" in "$S"/*) ;; *) die "isolated HOME $H is not under the scratch dir" ;; esac
[ -d "$H/.aitools" ] || die "no fixture home at $H"
[ -d "$A/.git" ] || die "no fixture clone at $A"

mkdir -p "$O" "$S/bin"
printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$S/bin/rg"
printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$S/bin/agent"
chmod +x "$S/bin/rg" "$S/bin/agent"

# deploy-harness copy with the OS guard disabled (only that line changes)
DH="$A/scripts/deploy-harness.cvps.ps1"
perl -pe 's/^(if \(\$PSVersionTable\.PSVersion\.Major -ge 6 -and )-not \$IsWindows\)/$1\$false)/' \
    "$A/scripts/deploy-harness.ps1" > "$DH"
diff "$A/scripts/deploy-harness.ps1" "$DH" > "$O/harness-copy.diff"
[ "$(grep -c . "$O/harness-copy.diff")" -eq 4 ] || die "guard patch did not apply exactly once (see $O/harness-copy.diff)"

run() { # run NAME ARGS...
    local n="$1"; shift
    : > "$O/$n.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_LOG_DIR -u AITOOLS_USER_REPO_PATH \
        HOME="$H" USERPROFILE="$H" AITOOLS_SUMMARY_FILE="$O/$n.summary" PATH="$S/bin:$PATH" NO_COLOR=1 \
        "$@" < /dev/null > "$O/$n.out" 2>&1
    local rc=$?
    echo "$n $rc" >> "$O/exit.txt"
    log "$n exit $rc"
}

: > "$O/exit.txt"
if [ "$CURSOR_ONLY" -eq 0 ]; then
    run harness pwsh -NoProfile -File "$DH" -SkipConfig $DRY
fi
run cursor pwsh -NoProfile -File "$A/tests/rules-fanout-cursor/step4-driver.ps1" "$A/scripts/setup-user-cursor.ps1" $DRY

perl "$S/gen-rows.pl" "$O/rows.txt" "$O/harness.summary" "$O/cursor.summary"
perl "$S/gen-tree.pl" "$H" "$O"
cat "$O/exit.txt"
