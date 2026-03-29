# Operational Learning: verify-and-propose Mission (Session 8236ca9c)

**Mission Commander**: verify-and-propose
**Date**: 2026-03-26

## OL Items

OL-VP1: Three Stop hooks (command-channel-stop.sh, failure-mode-identity-stop.sh,
failure-mode-verify-stop.sh) exist in shared/hooks/ but NONE are registered in the
deployment pipeline. Zero Stop hooks are active in settings.json. This is the same
class of bug that v0.67.0 introduced (removing deleted hook references without adding
new hook references). The pattern: "committed to source tree" != "deployed and firing."

OL-VP2: The hook deployment pipeline has a structural gap for Stop hooks. The pipeline
was built around SessionStart, SessionEnd, PreToolUse, and PostToolUse events. When
Stop hooks were deleted in the telemetry rebuild (v0.67.0, commit e070043), the removal
was completed but the re-addition was never done. command-channel-stop.sh was committed
in 934d50c without pipeline registration. The failure-mode hooks followed the same
pattern. Three consecutive sessions produced Stop hooks; none registered them.

OL-VP3: The 7-step process names (Receive, Classify, Orient, Assess, Surface, Propose,
Connect) appear in both hooks and the running estimate, all traced to A-HD1 which is
explicitly UNVERIFIED (A-O10). This creates a consistency that looks like verification
but is actually propagation of the same unverified assumption. Multiple references to
the same source do not make the source more reliable.

OL-VP4: D-27 specifies "one fires at start of every prompt, one at end." Both hooks
are Stop hooks (end). CC has no dedicated start-of-turn event. This deviation from
D-27's literal specification was not surfaced in the design doc or OL. The practical
effect may be equivalent (Stop stderr injected before next turn per A-H9), but the
deviation should be acknowledged, not silently normalized.

OL-VP5: The delegation-duty-guard hook IS firing and IS detecting low scores (0-4/6
across 65 findings in running-estimate.json). The detection layer works. What is
missing is the correction layer -- the failure-mode hooks are designed to be that
correction layer, but they are not deployed.

OL-VP6: Pipeline integration for hooks is a 3+ file change affecting a shared library
(setup-user-hooks.sh, setup-user-hooks.ps1, build-deploy.sh). Per PSO plan-execution,
this requires the sub-agent execution pattern. This is not a "quick fix" -- it is a
structured modification that touches the most complex deployment script in the project.

OL-VP7: The identity hook reads the session scratch directory's running estimate via
.current-session pointer. This is the same pointer that was hijacked in session
2d439e32-3 (F-2 phantom session). If .current-session points to the wrong directory,
the identity hook will inject OL from the wrong session or inject nothing. The pointer
is a single point of failure for all hooks that depend on it.

OL-VP8: The verify hook is the simplest hook in the project -- 101 lines, zero file
reads, static string output, ~5ms execution. This is a good model for future hooks
that need to inject behavioral reminders without runtime data dependencies.

OL-VP9: The running estimate markdown format is not standardized. The identity hook's
perl extraction relies on specific heading names (### Open, ### Blockers) and line
formats (OL-N:, A-ON:, A-BN:). If a future session uses different headings, extraction
silently returns empty. The fallback is correct (static injection), but the dynamic
content -- which is the hook's primary value -- is lost.

OL-VP10: Three prior Stop hooks were deleted in the telemetry rebuild (surfacing-duty,
estimate-refresh, intent-sentinel) because their /tmp state tracking was unreliable.
The new Stop hooks avoid /tmp entirely -- identity uses .scratch/.current-session
(session-scoped), verify uses no state at all. This is a design improvement that
addresses the root cause of the prior hooks' failure.

## Decisions

D-VP1: Pipeline integration should add all 3 Stop hooks in one change, not
incrementally. Rationale: the settings.json merge logic, validation logic, and
argument passing are tightly coupled. Adding hooks one at a time creates 3 rounds
of touching the same sensitive code. One batch is cleaner and testable.

D-VP2: The verify hook's static checklist approach (no file reads) is the correct
design for behavioral reminders. Reserve file-reading hooks for data injection
(identity) and command delivery (command-channel).

## What I Could Not Resolve

1. The 7-step process names -- unverified, Commander decision needed (A-O10)
2. Whether Stop hook placement satisfies D-27's "start of prompt" requirement
3. The optimal observation period before evaluating hook effectiveness
4. Whether the running estimate markdown format will be standardized or the
   identity hook should be more resilient to format variation
5. Whether the events pipeline should target JSONL or SQLite (F-4 from handoff)

## Assumptions Made

A-VP1: I assume the identity hook's degradation behavior (empty dynamic content,
static fallback) is acceptable. STATUS: UNVERIFIED -- Commander may prefer a
louder failure when the running estimate is missing or unparseable.

A-VP2: I assume pipeline integration can be done as one batch for all 3 Stop
hooks. STATUS: ASSUMPTION -- depends on whether command-channel-stop.sh has
additional dependencies (Python/SQLite) that complicate the merge.

A-VP3: I assume the delegation-guard scores in running-estimate.json are accurate
and not artifacts of the phantom session (.current-session hijack). STATUS:
PARTIALLY VERIFIED -- the timestamps (22:58Z-23:35Z March 25) predate the
phantom session start (16:45 local March 25 = 23:45Z), so most scores should
be from the correct session.

## Cross-references

- Running estimate: /Users/pepe/repos/aitools/.scratch/session-8236ca9c-b/running-estimate-v1.md
- Hook design: /Users/pepe/repos/aitools/.scratch/session-8236ca9c-b/hook-design.md
- Hook design OL: /Users/pepe/repos/aitools/.scratch/session-8236ca9c-b/hook-design-ol.md
- Prior handoff: /Users/pepe/repos/aitools/.aitools/channel/handoffs/handoff-2d439e32-3.md
- Consolidated OL: /Users/pepe/repos/aitools/harvesting/2026-03-25_session-c0dc2ddc-f_consolidated-operational-learning.md
