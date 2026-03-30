# CC Agentic Turn Tracking — Evaluation

**Session**: 8a9efdbb-0ecc-4905-b09a-6799dd66f2ee
**Date**: 2026-03-29
**Question**: Does Claude Code let us track the number of agentic turns per prompt turn?

## Answer: Yes, indirectly

CC does not expose a `turn_number` or `tool_call_count` field anywhere.
But it provides two mechanisms that combine into a turn counter:

1. **Stop hooks fire on every agentic turn** — this is the counting mechanism
2. **`transcript_path`** is in Stop hook stdin — you can parse JSONL to count
   `"type":"assistant"` entries since the last `"type":"human"` entry

## Mechanisms investigated

| Mechanism | Exposes turn count? | Notes |
|-----------|-------------------|-------|
| Hook stdin JSON | No explicit field | `session_id`, `transcript_path`, `cwd`, `agent_id`, `agent_type` — no turn counter |
| JSONL transcript | Derivable | Count `"type":"assistant"` after last `"type":"human"` (excluding sidechains) |
| Stop hook firing | Yes (implicit) | Fires per agentic turn — increment a file counter = turn count |
| Environment variables | No | No `CLAUDE_CODE_TURN_COUNT` or similar |
| Settings | No | `effortLevel`, `alwaysThinking` — no turn config |
| Subagent maxTurns | Limits only | YAML frontmatter `maxTurns: N` caps iterations, doesn't expose current count |

## Existing implementation

`harvesting/2026-03-24_intent-sentinel-stop.sh` already implements this:

- Marker file at `/tmp/aitools-intent-$session_id/turn-count`
- Incremented on each Stop hook fire
- Parses `transcript_path` JSONL via perl for `agent_turns_since_human`
- Fires intent reminders after 3+ agent-only turns
- Has cooldown (5 turns between injections)
- Also detects research-to-execution phase transitions (5+ Read/Grep → Write/Edit)

## What CC provides vs what we build

**CC provides:**
- Stop hook fires every agentic turn (the clock tick)
- transcript_path in hook stdin (the log to parse)
- stderr from command hooks → injected as agent feedback (the output channel)
- agent_id/agent_type to distinguish main vs subagent (2.1.68+)

**We build:**
- The counter (marker file in /tmp)
- The parser (perl one-liner scanning JSONL)
- The logic (thresholds, cooldowns, phase detection)
- The injection (stderr messages to redirect agent behavior)

## Upstream requests (not implemented)

- [#26340](https://github.com/anthropics/claude-code/issues/26340) — token usage summary readable by agent (closed as dup of #20642)
- [#4277](https://github.com/anthropics/claude-code/issues/4277) — agentic loop detection service (open, unimplemented)

## Tool-ops assessment

This is a CC capability that should be documented in tool-ops:

- **Category**: Session behavior / hook API
- **Mechanism**: Stop hook + transcript_path parsing
- **Status**: Working (harvested, not yet deployed)
- **KPI potential**: turns_per_prompt (histogram), phase_transitions_detected, intent_injections_fired

## Recommendation

1. Promote intent-sentinel-stop.sh from `harvesting/` to `shared/hooks/`
2. Add turn-tracking as a documented CC capability in tool-ops-claude-code.md
3. Wire turn count into harness-db for KPI tracking
4. Consider filing upstream feature request for native `turn_number` in hook stdin
