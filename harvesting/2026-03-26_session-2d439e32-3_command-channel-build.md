# Command Channel Build -- Work Product

**Session**: 2d439e32-3
**Date**: 2026-03-25
**Mission**: Build the bidirectional command channel (Layer 1: Stop hook command reader)

## What Was Built

### 1. Stop Hook: `shared/hooks/command-channel-stop.sh`

The critical missing piece -- a Stop hook that fires after every agent response and polls the session SQLite DB for pending commander directives.

**Architecture**:
- Fires on every Stop event (agent finishes responding)
- Opens the session DB at `.aitools/sessions/<prefix>.db`
- Queries both `commander_directives` (Layer 2 protocol) and `commander_feedback` (dashboard v2 fallback) tables for pending entries
- If found: injects directives via stderr (CC injects as context), updates status to 'acknowledged', exits 2 (block -- forces agent to address)
- If none: exits 0 (no-op)
- Uses inline Python (heredoc) for a single fast invocation (<50ms with SQLite WAL)
- Emits JSONL telemetry to events.jsonl for KPI tracking

**Design patterns followed**:
- `set -euo pipefail` (hook convention)
- Pure-bash JSON extraction (same as standing-order-guard.sh)
- Telemetry emission (same as standing-order-guard.sh, delegation-duty-guard.sh)
- Python detection with fallback (same as harness-db-sessionstart.sh)
- Graceful degradation -- table-not-found, DB-not-found, Python-not-found all exit 0

**Priority handling**:
- `flash` directives get `[FLASH]` prefix in output
- `priority` directives get `[PRIORITY]` prefix
- `normal` directives have no prefix
- All priorities cause exit 2 (block) -- the priority affects display, not blocking behavior

### 2. Schema Extension: `commander_directives` + `commander_feedback` tables in harness-db.py SESSION_SCHEMA

Added to the session DB schema so both tables are created automatically when a session starts:
- `commander_directives` -- the Layer 2 protocol table (8 directive types, 3 priorities, 5 statuses)
- `commander_feedback` -- the dashboard v2 table (preserved for backward compatibility)

### 3. CLI Subcommand: `harness-db.py directive`

Four sub-operations:
- `directive add "msg" [--type X] [--priority Y] [--target Z]` -- add a directive
- `directive list [--status S]` -- list directives
- `directive poll` -- poll pending (used by the hook, also standalone)
- `directive ack <id> [--response R] [--status S]` -- mark directive as executed/rejected/deferred

## What Was NOT Built (Deferred)

- **setup-user-hooks.sh integration** -- the hook needs to be registered in the settings.json merge logic and deployed to ~/.claude/hooks/. This requires modifying the protected setup-user-hooks.sh script (source-of-truth gate).
- **Dashboard command palette** -- Layer 3 UI for the commander to issue structured directives. The dashboard v2 already has a feedback form that writes to `commander_feedback`, so basic functionality exists.
- **Hook rollout mode** -- the hook starts in full enforce mode (exit 2 on pending directives). Could add observe mode if false-positive risk emerges.

## Test Results

All tests passed:
- `directive add` -- creates entries with correct types, priorities, targets
- `directive list` -- displays with priority tags and status
- `directive poll` -- finds pending, acknowledges, prints to stderr, returns count on stdout
- `directive ack` -- updates status and response
- Python syntax verification: `py_compile` passed
- Bash syntax verification: `bash -n` passed
- Flash priority display: `[FLASH]` prefix correctly applied
- Target display: `(re: target)` correctly shown when target specified

## Files Modified

| File | Change |
|------|--------|
| `shared/hooks/command-channel-stop.sh` | NEW -- Stop hook (Layer 1) |
| `scripts/harness-db.py` | Added `commander_directives` + `commander_feedback` to SESSION_SCHEMA, added 4 `cmd_directive_*` functions, added parser setup, added dispatch in main() |

## Next Steps for Full Integration

1. Add hook registration in `scripts/setup-user-hooks.sh` (deploy to ~/.claude/hooks/, mergeHookEntry for 'Stop' event)
2. Run `aitools` to deploy the hook
3. Test end-to-end: dashboard writes directive -> Stop hook reads -> agent addresses
4. Consider adding a dedicated `directive` table to the dashboard command center v2
