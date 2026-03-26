# Operational Learning: Command Channel Architecture Investigation

**Date**: 2026-03-25
**Session**: c0dc2ddc-f464-404d-a637-8103afda27af
**Agent**: S2-CommandChannel
**Mission**: Investigate bidirectional dashboard-to-agent communication patterns and propose features

---

## What Was Done

1. Read all required context: consolidated OL (560 lines), CLAUDE.md, skills, delegation prompt
2. Read existing implementations: session-command-center-v2.py, feedback-loop-investigation.md, harness-db-schema.sql, dashboard-serve.sh, self-evolution-proposals.md, mission-control-proposals.md, feedback-loop-operational-learning.md
3. Researched 12 systems across 7 domains via web search:
   - Agentic AI frameworks: LangGraph, OpenAI Agents SDK, Temporal
   - ChatOps/HITL SDKs: HumanLayer, Slack interactive messages
   - CI/CD: Jenkins approval gates, Argo CD sync
   - Notebooks: Jupyter Comms/Widgets
   - IDE extensions: VS Code webview postMessage
   - Mission control: NASA Open MCT, JPL ground systems
   - Claude Code platform: hooks, Agent SDK V2, GitHub feature requests
4. Synthesized findings into a three-layer command channel architecture
5. Proposed four new features beyond the command channel
6. Wrote five operational learning principles with cross-domain evidence

## Key Findings

### F1: Polling is universally correct when push is unavailable

Every system that faces the "agent is busy, can't receive messages" constraint (Jupyter kernel busy, CC agent thinking, Temporal workflow executing) uses the same solution: write to a durable shared store, read at the next idle point. This is not a workaround -- it is the architecturally correct pattern. The store is SQLite. The idle point is the Stop hook.

### F2: The feedback loop v2 is architecturally sound but incomplete

The existing implementation (session-command-center-v2.py with `commander_feedback` table) correctly implements the write path (dashboard -> SQLite) and the data model (typed feedback with lifecycle). What's missing is: (a) automatic polling from the agent side (no Stop hook reads the table), (b) priority-based processing (flash vs normal), and (c) integration with the self-learning loop.

### F3: CC platform constraints are real but not blocking

GitHub Issue #24983 (external event sources) and Issue #70 (Agent SDK real-time steering) confirm that mid-session message injection is a known gap. The feature requests are active. But the Stop hook + stderr injection mechanism provides a workable alternative that's within CC's documented capabilities. The only platform change needed is none.

### F4: NASA's uplink/downlink separation validates the architecture

The separate `commander_feedback` table (not mixed into `messages`) mirrors NASA's separation of command uplink from telemetry downlink. Different bandwidth, latency, and reliability requirements. The feedback loop v2 made the right design decision here.

### F5: The Agent SDK V2 will eventually provide a better mechanism

The `resumeSession()` + `send()` pattern in the Agent SDK V2 enables programmatic multi-turn conversations. The V2 preview mentions "mid-session message injection for supervisor patterns." When this stabilizes, the command channel can migrate from Stop-hook polling to SDK push. Design the command protocol to be transport-agnostic.

## Architecture Decision: Three-Layer Command Channel

### Layer 1: Stop-Hook Command Reader
- New hook: `command-channel-stop.sh`
- Polls `commander_directives` table in session SQLite DB
- Flash priority: blocks (exit 2), injects via stderr
- Normal priority: injects via stderr, does not block
- Acknowledges directives on read
- Performance budget: <50ms (SQLite WAL read)

### Layer 2: Command Protocol
- New table: `commander_directives` with typed commands and priority
- Types: correction, redirect, priority, question, approve, reject, context, checkpoint
- Priority: flash (interrupt), priority (next pause), normal (queued)
- Lifecycle: pending -> acknowledged -> executed/rejected/deferred

### Layer 3: Dashboard Command Interface
- Command palette (Cmd+K): already prototyped in feedback loop v2
- Quick action buttons: Checkpoint, Redirect, Approve/Reject Plan
- Command history with status tracking
- Active commands panel with visual indicators

## Feature Proposals

### Proposal 1: Agent Orchestration Panel
Live visibility into delegated agents (tree view, status, commands per agent). Requires delegation hooks writing to `delegation_log` and `missions` tables.

### Proposal 2: Session Handoff Protocol via Dashboard
Dashboard-mediated session handoff with banner display, acceptance tracking, and cross-session history view. Addresses the warmup cost gap (OL G2/U2).

### Proposal 3: Governance Health Dashboard
Cross-session governance metrics (hook fire rate, rule compliance, incident trends, delegation duty compliance) from `kpi_events` table. Addresses governance health metric gap (OL G4).

### Proposal 4: Context-Aware Command Suggestions
Lightweight message classifier that suggests relevant commands based on recent agent behavior (launched subagents -> suggest "Show delegation status"; wrote plan -> suggest "Approve/Reject").

## What Worked Well

1. **Breadth-first research produced convergent findings**: All 12 systems converge on the same fundamental patterns. This gives high confidence in the architecture recommendation.

2. **The existing implementation is closer to correct than expected**: The feedback loop v2 already implements most of the write path. The gap is the read path (Stop hook) and priority.

3. **NASA analogy clarified the architecture**: The uplink/downlink separation provided the clearest mental model for why observations and commands should be separate subsystems.

## What Was Surprising

1. **Jupyter has the exact same constraint as CC**: Kernel busy = can't receive widget messages. The solution (buffer + deliver on idle) is identical to the Stop hook pattern.

2. **The Agent SDK V2 mentions mid-session injection but doesn't fully support it**: The documentation describes the capability but GitHub Issue #70 confirms it's not yet available.

3. **Every CI/CD system uses explicit pause points**: None of them poll. They all stop-and-wait. This is because CI/CD pipelines have natural stage boundaries. CC's "stages" are tool calls, which are too fine-grained for manual approval but right for automated command reading.

## Operational Learning Principles

### OL-CC1: Polling is correct when push is unavailable
When the platform does not support push notifications, polling a durable shared store at natural pause points is the correct pattern.

### OL-CC2: Separate observation from command
Observation (telemetry/downlink) and command (uplink) should be separate subsystems sharing a common data store.

### OL-CC3: The Stop hook is the agent's "idle loop"
In CC's architecture, the Stop hook serves the same function as Temporal's workflow main loop and Jupyter's kernel idle handler.

### OL-CC4: Priority matters more than latency
The commander doesn't need sub-second delivery. They need priority-based processing: "stop what you're doing" interrupts immediately; "here's context" can wait.

### OL-CC5: The Claude Agent SDK will eventually solve this better
Design the command channel so it can migrate from Stop-hook polling to SDK push when the platform supports it. Keep SQLite and dashboard UI; replace the transport.

## Cross-References

| Artifact | Location |
|----------|----------|
| Full investigation | `.scratch/session-c0dc2ddc-f/command-channel-investigation.md` |
| Feedback loop v2 code | `.scratch/session-c0dc2ddc-f/session-command-center-v2.py` |
| Feedback loop investigation | `.scratch/session-c0dc2ddc-f/feedback-loop-investigation.md` |
| Feedback loop OL | `.scratch/session-c0dc2ddc-f/feedback-loop-operational-learning.md` |
| Harness DB schema | `reference/harness-db-schema.sql` |
| Self-evolution proposals | `.scratch/session-RnTOD5XJFi/self-evolution-proposals.md` |
| Mission control proposals | `.scratch/session-RnTOD5XJFi/mission-control-proposals.md` |
| Consolidated OL | `.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` |
