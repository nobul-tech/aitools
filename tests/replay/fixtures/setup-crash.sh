#!/usr/bin/env bash
# setup-crash.sh -- tests/replay fixture: a relayed child that crashes. It logs
# one info line, writes "boom" to stderr and exits 3 without recording anything,
# as a script that dies under set -e does. The relay must record the failure
# once, as one error of the parent, with "boom" as its reason
# (reference/logging.md 8.3 "A failed child", "Its REASON": the child's last 20
# stderr lines).
# Not a product script: run only by tests/replay/fixtures/replay-parent.sh.
# Environment: REPLAY_LIB (aitools-lib.sh of the temp aitools copy).

set -euo pipefail

# shellcheck source=/dev/null
. "${REPLAY_LIB:?REPLAY_LIB is not set}"
logging_init "setup-crash"

log "crash test: starting"
printf 'boom\n' >&2
exit 3
