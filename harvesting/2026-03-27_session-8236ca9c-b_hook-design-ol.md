# Operational Learning: Hook Design Mission (Session 8236ca9c)

**Mission Commander**: hook-design
**Date**: 2026-03-26

## OL Items

OL-HD1: Stop hooks receive JSON on stdin with session_id field. Confirmed by
reading command-channel-stop.sh which extracts session_id from Stop hook input.

OL-HD2: The .scratch/.current-session file contains the absolute path to the
current session's scratch directory. Written by scratch-init.sh at SessionStart.
This is the reliable pointer for finding session-specific files from hooks.

OL-HD3: Running estimate markdown lives in the session scratch directory, not
in .aitools/channel/. The .aitools/channel/running-estimate.json is a different
format (JSON, tracked in git, cross-machine carry-forward). The markdown
running estimate is session-ephemeral in .scratch/session-*/.

OL-HD4: Multiple Stop hooks coexist -- command-channel-stop.sh is already a Stop
hook. Adding two more creates 3 Stop hooks total. CC should process all of them
sequentially after each response. Unverified but low risk.

OL-HD5: The 7-step process is not yet codified in a reference file. A-O10
marks it as open. I reconstructed it from OL-13 (receipt and response), OL-41
(OBSERVE-SURFACE-PROPOSE-CONNECT), and the OODA/military staff process
provenance as: Receive, Classify, Orient, Assess, Surface, Propose, Connect.
This is an ASSUMPTION (A-HD1 in design doc) that the commander should verify.

OL-HD6: Pipeline integration (build-deploy.sh, setup-user-hooks.sh, setup-user-hooks.ps1)
is a separate work item from writing the hook scripts themselves. The hooks are
functional standalone -- they can be manually copied to ~/.claude/hooks/ and
registered in settings.json for testing before pipeline integration.

OL-HD7: Existing hooks use two JSON extraction patterns:
  a) Pure bash regex with BASH_REMATCH (delegation-duty-guard.sh, command-channel-stop.sh)
  b) grep + sed pipeline (scratch-init.sh)
Pattern (a) is faster and more portable. Used in both new hooks.

OL-HD8: The verify hook requires zero file reads -- it's a static string.
This makes it extremely fast (<5ms) and impossible to fail on missing files.
The identity hook does file reads (running estimate) but has a static fallback.

OL-HD9: Per OL-42, I designed from the specs (running estimate, RFC, governance plan,
hook-rollout.md, cross-platform.md) rather than copying existing hook patterns.
The delegation-duty-guard.sh was read for STRUCTURE reference only (header format,
telemetry pattern, json_field pattern). The actual logic was designed from scratch
per the D-27 requirements.

OL-HD10: Perl is used for running estimate parsing because grep -P is not
portable (macOS BSD grep does not support it -- per cross-platform.md and
script-standards.md). Perl is a managed tool available on all platforms.

## Decisions

D-HD1: Both hooks always inject (no threshold/interval gating). Rationale: the
whole point is that process drops on EVERY turn (OL-14). Throttling defeats the
purpose. If context cost becomes a concern, reduce the message size, don't skip
turns.

D-HD2: Static fallback when no running estimate exists. The identity and process
reinforcement are valuable even without dynamic OL/gaps. A session without a
running estimate still needs identity reinforcement.

D-HD3: Telemetry uses the same events.jsonl pattern as other hooks (delegation-duty-guard.sh,
command-channel-stop.sh). One line per event, appended atomically.

D-HD4: No Python dependency in these hooks. Unlike command-channel-stop.sh
(which needs Python for SQLite), these hooks only need bash and perl. Fewer
dependencies = fewer failure modes.

## What I could not resolve

1. The 7-step process names are unverified (A-HD1). The commander should
   confirm or correct: Receive, Classify, Orient, Assess, Surface, Propose, Connect.

2. Pipeline integration is not done. The hooks exist in shared/hooks/ but are
   not yet in build-deploy.sh or setup-user-hooks.sh. Manual deployment is
   needed for testing.

3. Whether 3 Stop hooks firing sequentially creates noticeable latency. Each
   is budgeted at <50ms, so 3 would be <150ms total. Should be acceptable
   but unverified.

4. Whether the running estimate markdown format is stable enough for regex
   parsing. If the format changes, the perl extraction will silently return
   empty strings (safe degradation to static fallback).

5. The optimal message length for stderr injection. Too long wastes context;
   too short loses information. Current design is ~10-15 lines with OL, ~5
   lines without. May need tuning after observation.
