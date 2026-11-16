#!/usr/bin/env bash
# replay-parent.sh -- tests/replay fixture: the parent (entry point) of the
# replay run of tests/replay/test-replay.sh. It owns the run summary file
# (summary_begin), relays each child with the library's run_child_relayed, as
# the aitools runners do (deploy_configs in scripts/aitools), draws the panel
# (summary_end) and exits 1 when its error count (its own errors and every
# relayed child that failed, reference/logging.md 8.3) is above 0.
#
# Not a product script: run only by the test harness, never alone.
# Environment (set by the harness):
#   REPLAY_LIB            aitools-lib.sh of the temp aitools copy
#   REPLAY_STEPS          the children to relay, in order (default: node claude crash)
#                           node    fixtures/setup-node.sh (a warning with an ACTION, then OK node.js)
#                           claude  the real setup-user-claude.sh of the temp copy (REPLAY_CLAUDE)
#                           crash   fixtures/setup-crash.sh (writes boom to stderr, exits 3)
#                           gh      the generated gh-auth child (REPLAY_GH), the installer's Step 2 block
#   REPLAY_CLAUDE         path of setup-user-claude.sh
#   REPLAY_GH             path of the generated gh-auth child
# Platform: macOS/Linux (the suite carries the OS guard).

set -euo pipefail

# shellcheck source=/dev/null
. "${REPLAY_LIB:?REPLAY_LIB is not set}"
logging_init "replay-parent"

FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
summary_begin

for step in ${REPLAY_STEPS:-node claude crash}; do
    rc=0
    case "$step" in
        node)   run_child_relayed --summary-tool "node.js" "setup-node.sh" "${BASH:-bash}" "$FIX/setup-node.sh" || rc=$? ;;
        claude) run_child_relayed --summary-tool "claude.md" "setup-user-claude.sh" "${BASH:-bash}" "${REPLAY_CLAUDE:?}" || rc=$? ;;
        crash)  run_child_relayed --summary-tool "crash test" "setup-crash.sh" "${BASH:-bash}" "$FIX/setup-crash.sh" || rc=$? ;;
        gh)     run_child_relayed --summary-tool "gh auth" "Step 2: gh authentication" "${BASH:-bash}" "${REPLAY_GH:?}" || rc=$? ;;
        *)      write_error "" "unknown replay step $step" "not one of node, claude, crash, gh (harness bug)"; continue ;;
    esac
    # Counted (and, when needed, recorded) by the relay: info only here
    if [ "$rc" -ne 0 ]; then log "$step: child failed (exit $AITLIB_CHILD_RC)"; fi
done

if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    summary_end
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
else
    log "COMPLETED successfully" "ok"
fi
summary_end
exit 0
