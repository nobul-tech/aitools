# Delegation Prompt: Telemetry Architecture Redesign

## Identity

You are S2-Telemetry. You have broad authority to investigate, design, and propose.

## Mission

The current hook-based telemetry architecture is wrong. Three Stop hooks (intent-sentinel, estimate-refresh, surfacing-duty) were disabled this session because they violated every principle from the observability world: synchronous, inline, regex-heavy, /tmp state, perl subprocesses on the hot path.

Design the replacement. The commander has $100K in Datadog credits and the harness has a SQLite session DB.

The existing KPI definitions across the codebase (decision #32, the hook specs, the tool-ops framework) are the spec for WHAT to measure. This mission is about HOW to collect, store, and ship those measurements without friction.

Investigate broadly. Look at how Datadog, OpenTelemetry, Honeycomb, and other observability systems solve collection without overhead. Look at how the provenance investigation (in this session's scratch) concluded: "zero hooks for observation, agent annotates its own work, processing at session boundaries."

The enforcement hooks (standing-order-guard, delegation-duty-guard, glossary-skill-guard, block-claude-code-guide, sh-file-fixup) are different — they modify behavior inline and should stay. But even they should emit events to the DB rather than writing to log files.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — read Part 1 and Part 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/.claude/skills/investigate/SKILL.md`
6. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/provenance-and-infrastructure-findings.md` — provenance investigation findings including "zero hooks" design
7. `/Users/pepe/repos/aitools/reference/harness-db-schema.sql` — session DB and harness DB schemas
8. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/knowledge-query-findings.md` — knowledge query investigation (SQLite FTS5 + sqlite-utils)

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Key Constraints

- $100K Datadog credits (12 months, active)
- SQLite session DB exists and is operational
- Hooks must complete in <50ms (enforcement hooks) or <5ms (event emission)
- No regex parsing of transcripts during the session
- No /tmp, no marker files
- Agent's existing behavior IS the instrumentation
- Cross-platform (macOS, Linux, Windows Git Bash)

## Output

Write findings, architecture proposal, and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
