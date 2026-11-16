#!/usr/bin/env bash
# setup-node.sh -- tests/replay fixture: a relayed child that records one
# warning with an ACTION (write_action, under "aitools config": the pasted run's
# unregistered machine) and then the node.js status (OK|node.js|v26). Its
# warning must not turn node.js yellow (reference/logging.md 8.3: a WARN record
# is one warning, never a tool's status; 8.5: green = an OK record and no WARN
# or ERROR record under that name).
# Not a product script: run only by tests/replay/fixtures/replay-parent.sh.
# Environment: REPLAY_LIB (aitools-lib.sh of the temp aitools copy).

set -euo pipefail

# shellcheck source=/dev/null
. "${REPLAY_LIB:?REPLAY_LIB is not set}"
logging_init "setup-node"

log "node.js: v26 found"
write_action "aitools config" "this machine is not registered -- run: aitools user init" "Run: aitools user init (registers this machine)"
write_summary OK "node.js" "v26"

if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
