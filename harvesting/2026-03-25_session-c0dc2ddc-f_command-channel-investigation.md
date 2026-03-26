# Command Channel Architecture Investigation

**Investigator**: S2-CommandChannel
**Date**: 2026-03-25
**Session**: c0dc2ddc-f464-404d-a637-8103afda27af
**Classification**: Broad architecture investigation + feature proposals
**Mission**: How should the dashboard communicate directives to the agent? What do other systems do? What should aitools build?

---

## Executive Summary

The question is: how does a commander direct an autonomous agent through a dashboard, when the agent has no "incoming message" hook? I investigated twelve systems across six domains. The answer is that **polling a shared data store is the correct pattern for Claude Code's current architecture**, but aitools should build three layers above raw polling to make the command channel feel responsive, reliable, and integrated with the self-learning spiral.

The three layers: (1) a **Stop-hook command reader** that checks for pending directives every time the agent pauses, (2) a **command protocol** that gives directives structure (type, priority, acknowledgment lifecycle), and (3) a **dashboard command interface** that lets the commander issue structured directives with one click or keyboard shortcut. Together, these turn the existing dashboard + SQLite + hooks architecture into a proper command channel without requiring any Claude Code platform changes.

The investigation also surfaced four new feature proposals that go beyond the command channel: an **agent orchestration panel**, a **session handoff protocol**, a **governance health dashboard**, and a **context-aware command suggestions** system.

---

## Part 1: Cross-Domain Investigation

### Domain 1: Agentic AI Frameworks (LangGraph, OpenAI Agents SDK, Temporal)

**LangGraph interrupt/checkpoint/resume pattern**: LangGraph solves bidirectional communication with `interrupt()` and `Command(resume=value)`. When an agent hits an interrupt, the entire graph state is checkpointed to a database (Postgres or SQLite). The graph literally stops. A human reviews, provides input, and the graph resumes from the exact checkpoint with the human input injected into the node's local state. The key insight: **the graph does not poll. It stops and waits.** The human input is durable (survives crashes). The graph resumes exactly where it left off.

**Relevance to aitools**: Claude Code cannot stop-and-wait like LangGraph. CC is a continuous process with a conversation loop. The checkpoint/resume pattern maps to CC's `/resume` command (resume a prior session), but NOT to mid-session command injection. However, the *durability* principle applies: commands should survive process crashes. SQLite provides this.

**Temporal signals**: Temporal uses "signals" to inject information into running workflows. A signal handler decorated with `@workflow.signal` receives the signal and updates workflow state variables. The workflow's main loop continuously checks state variables and reacts. This is **polling a shared state store** -- exactly the pattern aitools already has via SQLite. The key difference: Temporal's signal delivery is guaranteed by the platform. CC's hook-based polling is best-effort (fires only when the agent pauses).

**OpenAI Agents SDK**: Uses `RunToolApprovalItem` -- when a tool needs approval, the run pauses and returns pending approvals in a `result.interruptions` array. The client displays them, collects decisions, and resumes. This is the LangGraph pattern with different naming. CC does not expose this API.

**Key takeaway**: The pattern across all three frameworks is: **durable state store + polling at natural pause points**. LangGraph and OpenAI SDK create artificial pause points (interrupts). Temporal's workflow loop is the polling mechanism. For CC, the natural pause points are: Stop hooks (agent finished responding), PreToolUse (agent about to act), and PostToolUse (agent just acted).

### Domain 2: ChatOps / Human-in-the-Loop SDKs (HumanLayer, Slack)

**HumanLayer SDK**: Provides `@hl.require_approval()` decorator that halts function execution until a human approves, and `hl.human_as_tool()` that lets agents request human input as a tool call. Communication channels include Slack, Email, and Discord. The key insight: **the approval decision is delivered asynchronously through a channel the human is already using.** The agent doesn't poll a dashboard -- a Slack message arrives, the human clicks a button, the callback triggers resolution.

**Slack interactive messages**: The approval workflow pattern -- bot sends a message with Approve/Deny buttons, user clicks, callback handler fires, workflow proceeds. The bidirectional communication is: bot -> Slack message -> human -> button click -> callback -> bot. This is **event-driven**, not polling.

**Relevance to aitools**: The "use a channel the human is already in" principle is important. The commander is already in a browser looking at the dashboard. Making the dashboard the command channel (rather than requiring them to switch to Slack or the terminal) is the right UX decision. The feedback loop v2 already does this -- the investigation confirmed the architecture is sound.

### Domain 3: CI/CD Approval Gates (Jenkins, Argo CD)

**Jenkins manual approval stages**: A pipeline pauses at an `input` step. The Jenkins dashboard shows a "Proceed/Abort" dialog. The pipeline blocks until the human decides. The approval is durable (stored in Jenkins' build record). Timeout is configurable.

**Argo CD sync with approval**: Changes detected -> dashboard shows diff -> human clicks "Sync" -> deployment proceeds. The webhook pattern: GitHub pushes event -> Argo CD processes -> waits for human sync.

**Key takeaway**: CI/CD systems use **explicit pause points** where the pipeline stops and waits. This maps to the LangGraph interrupt pattern. The dashboard is the approval interface. The approval is a single binary decision (proceed/abort), not a rich command. aitools needs richer commands than proceed/abort.

### Domain 4: Jupyter Notebooks (Comms, Widgets)

**Jupyter Comms**: Bidirectional messaging between kernel and frontend via `comm_open`, `comm_msg`, `comm_close`. A widget registers a comm target, the frontend connects, messages flow both ways. The kernel can send via `my_comm.send(data)`, the frontend via `kernel.comm_msg(...)`.

**Critical limitation**: Widget comm messages are processed in the shell channel, which is only flushed in the kernel's main thread loop. **When the kernel is busy executing, widgets cannot send messages to the kernel.** This is the exact same constraint CC has -- when the agent is "thinking" or executing a tool, external messages cannot be injected.

**Key takeaway**: Jupyter and CC share the same fundamental constraint. Jupyter's solution: widgets buffer messages and deliver them when the kernel is idle. This maps directly to: dashboard writes commands to SQLite, Stop hook reads them when the agent pauses.

### Domain 5: VS Code Extension Webviews

**postMessage/onDidReceiveMessage**: VS Code webviews are sandboxed. All communication uses `postMessage()`. Extension -> webview: `panel.webview.postMessage(data)`. Webview -> extension: `vscode.postMessage(data)` + `panel.webview.onDidReceiveMessage(handler)`. Messages are JSON-serializable. The pattern is: **message queue with typed handlers**.

**Relevance to aitools**: The dashboard is a webview equivalent. The dashboard's fetch()-based POST to the API is the equivalent of `vscode.postMessage()`. The server's request handler is the equivalent of `onDidReceiveMessage()`. The pattern is already implemented in the feedback loop v2.

### Domain 6: NASA Mission Control (Open MCT, JPL Ground Systems)

**Uplink/downlink separation**: In NASA's ground systems, the uplink (commands to spacecraft) and downlink (telemetry from spacecraft) are **separate subsystems** that are "not well integrated because of the nature of planetary missions with large one-way light times." Commands go up through a command processor; telemetry comes down through a telemetry processor. They share a common time reference but are otherwise independent.

**Open MCT**: A plugin-based mission control framework. Telemetry sources provide real-time streaming data and historical data. The "telemetry dictionary" defines all available data points. Plugins for YAMCS add command capability alongside telemetry visualization.

**Key takeaway**: NASA separates observation (telemetry/downlink) from command (uplink). The observation path is high-bandwidth, continuous, automated. The command path is lower-bandwidth, deliberate, verified. This maps to aitools: the dashboard's message display is telemetry (downlink). The commander's feedback is commands (uplink). They should be separate subsystems sharing a common data store.

### Domain 7: Claude Code Platform (Hooks, SDK, Feature Requests)

**Current hook architecture**: Hooks fire on lifecycle events (PreToolUse, PostToolUse, Stop, SessionStart, SessionEnd, etc.). Stop hooks run when the agent finishes responding. A Stop hook can block (exit code 2) to force the agent to continue, with stderr text injected as context. This is the mechanism for mid-session command injection.

**GitHub Issue #24983**: Feature request for "External event sources to trigger messages in active conversation." Currently marked as duplicate. The author notes: "Hooks only fire on internal lifecycle events -- no support for external triggers. MCP servers are pull-only."

**GitHub Issue #70 (Agent SDK)**: Feature request for "Real-Time Steering for Claude Agents SDK." Notes that Claude Code already supports real-time steering (human can type while agent is running), but the SDK does not expose this capability programmatically.

**Claude Agent SDK V2**: Supports `createSession()/resumeSession()` for persistent sessions, and `send()/stream()` for multi-turn conversations. Mid-session message injection for supervisor patterns is described but the current implementation does not fully support interrupting an active agent run.

**Key takeaway**: CC's platform constraint is real -- no external event injection. The Stop hook is the only reliable mechanism for reading external state. However, the Stop hook fires at a natural pause point (agent done responding), which is exactly when a command should be read. The frequency depends on conversation dynamics, but for a session with active tool use, Stop hooks fire every 15-60 seconds. This is acceptable latency for commander directives.

---

## Part 2: Synthesis -- The Command Channel Architecture

### Why polling is correct

Every system investigated ultimately reduces to one of two patterns:

1. **Pause-and-wait** (LangGraph, OpenAI SDK, Jenkins, Temporal): The agent/pipeline/workflow stops at a defined point and waits for human input. Input is delivered synchronously.

2. **Polling a shared store** (Temporal signals, Jupyter widgets, VS Code webviews): The agent checks a shared state store at natural pause points. Input is delivered asynchronously with bounded latency.

Claude Code cannot do pattern 1 (it doesn't expose interrupt/resume APIs for external callers). Pattern 2 is the correct choice. The shared store is SQLite (already in place). The polling point is the Stop hook (fires when the agent finishes a response). The bounded latency is 15-60 seconds in active sessions (time between Stop hook firings).

### Why the current feedback loop is almost right

The feedback loop v2 (session-command-center-v2.py) already implements:
- Commander writes feedback via dashboard POST -> SQLite `commander_feedback` table
- Agent can read via GET `/api/feedback?status=submitted` or direct DB query
- Lifecycle tracking: submitted -> acknowledged -> resolved -> deferred

What's missing:
1. **No automatic polling** -- the agent must manually check for feedback. No hook reads pending commands.
2. **No command priority** -- all feedback is equal. A "stop what you're doing" directive has the same priority as an "observation."
3. **No structured commands** -- the feedback types (correction, directive, bug, observation, priority) are categories, not commands. There's no "execute this tool" or "read this file" command type.
4. **No integration with the self-learning loop** -- corrections don't automatically become OL entries.

### The three-layer architecture

**Layer 1: Stop-Hook Command Reader (Detection)**

A new Stop hook (`command-channel-stop.sh`) that runs every time the agent finishes a response:

1. Opens the session SQLite DB
2. Queries for pending commands: `SELECT * FROM commander_feedback WHERE status = 'submitted' ORDER BY created_at`
3. If pending commands exist:
   - Writes them to stderr (injected as context for the next agent turn)
   - Updates status to `acknowledged` with timestamp
   - Returns exit code 2 (block) to force the agent to address the commands before proceeding
4. If no pending commands: exits 0 (no-op)

This is the "Temporal signals" pattern adapted for CC's hook architecture. The Stop hook IS the signal handler. SQLite IS the durable signal queue.

Performance: SQLite read with WAL mode is <5ms. The hook runs `python3 scripts/harness-db.py feedback --session $PREFIX --status submitted` or uses inline Python. Total overhead: <50ms per Stop hook firing. Well within the hook budget.

**Layer 2: Command Protocol (Structure)**

Extend the `commander_feedback` table or add a new `commander_directives` table with structured command types:

```sql
CREATE TABLE IF NOT EXISTS commander_directives (
    directive_id INTEGER PRIMARY KEY AUTOINCREMENT,
    directive_type TEXT NOT NULL
        CHECK (directive_type IN (
            'correction',     -- "This is wrong, the correct answer is X"
            'redirect',       -- "Stop X, do Y instead"
            'priority',       -- "This is urgent / this can wait"
            'question',       -- "Why did you do X?" (Socratic verification)
            'approve',        -- "Proceed with this plan"
            'reject',         -- "Do not proceed with this plan"
            'context',        -- "Here's additional context: ..."
            'checkpoint'      -- "Commit what you have, summarize progress"
        )),
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('flash', 'priority', 'normal')),
    message TEXT NOT NULL,
    target TEXT,                  -- what it's about (mission, file, decision)
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'acknowledged', 'executed', 'rejected', 'deferred')),
    response TEXT,                -- agent's response to the directive
    created_at TEXT NOT NULL,     -- ISO 8601 UTC
    acknowledged_at TEXT,
    executed_at TEXT
);
```

The priority system matters: `flash` directives interrupt the agent immediately (Stop hook blocks). `priority` directives are surfaced at the next natural pause. `normal` directives are queued.

**Layer 3: Dashboard Command Interface (Prevention/Input)**

Extend the dashboard UI with a command interface:

1. **Command palette** (Cmd+K): Quick command entry with type selection. Already prototyped in the feedback loop v2.
2. **Quick action buttons**: Pre-built commands for common directives:
   - "Checkpoint" (triggers commit + progress summary)
   - "Redirect" (opens redirect form)
   - "Approve Plan" / "Reject Plan" (binary decision on pending plans)
   - "Context" (opens context input form)
3. **Command history**: Shows all directives with status badges, timestamps, agent responses.
4. **Active commands panel**: Persistent display of pending/acknowledged commands. Visual indicator (pulsing badge, color change) when commands are pending.

---

## Part 3: Feature Proposals

### Proposal 1: Agent Orchestration Panel

**What it is**: A dashboard panel that shows all active agents (main session + delegated subagents) with their status, current task, and a command interface for each.

**Why it matters**: The commander currently has no visibility into delegated agents. The consolidated OL documents "48 minutes saved across 3 parallel bursts" in the marse session -- but the commander couldn't SEE those bursts happening. They relied on the main agent reporting status.

**How it works**:
- The `delegation_log` table already tracks agent launches (launched_at, status, prompt_summary).
- The `missions` table tracks mission status (launched, in_progress, complete, failed, killed).
- The dashboard already has a "Delegations" tab (currently empty because write-side hooks don't exist yet).
- Populate these tables from delegation hooks, then render a live orchestration view.

**What the panel shows**:
- Tree view of active agents (main -> subagent -> sub-subagent)
- Per-agent: status, current task, duration, token usage
- Per-agent command buttons: "Kill" (mark as killed in DB, Stop hook picks up), "Redirect" (send a directive to a specific agent)

**Dependency**: Requires delegation hooks that write to the `delegation_log` and `missions` tables. These are the "write-side hooks" noted as missing in the current session's OL.

**Architecture insight from NASA**: Open MCT's plugin architecture shows how to build this. Each agent is a "telemetry source" with its own data dictionary. The orchestration panel is a "layout" plugin that composes agent views. The command interface is an "action" plugin.

### Proposal 2: Session Handoff Protocol via Dashboard

**What it is**: When a session ends, the dashboard generates a handoff briefing and makes it available as a clickable artifact for the next session.

**Why it matters**: The consolidated OL identifies warmup cost as a critical gap (OL Part 6, U2): "Every new session starts cold. The commander has to re-teach values, correct assumptions, calibrate expectations. This session took approximately 12 human messages before the agent 'started to get it.'"

**How it works**:
- SessionEnd hook generates a handoff briefing (already designed: `.aitools/channel/handoffs/`)
- Dashboard displays the handoff as a prominent banner at the top: "Session ended. Handoff available."
- Next session's SessionStart hook reads the latest handoff and injects it as context
- Dashboard shows handoff acceptance status (loaded, partial, failed)

**Cross-session dashboard**: Instead of one dashboard per session, add a "session history" view that shows recent sessions with their handoff status. The commander can see: which sessions produced handoffs, which handoffs were consumed by the next session, where the chain broke.

### Proposal 3: Governance Health Dashboard

**What it is**: A dashboard view that shows the health of the three-layer governance system (Prevention, Detection, Audit) with metrics aggregated from the harness DB's `kpi_events` table.

**Why it matters**: The consolidated OL identifies governance health metric as a critical gap (G4): "There is no quantitative measure of whether governance is improving, degrading, or stable across sessions."

**Metrics to display**:
- Hook fire rate (detection layer health)
- Rule compliance rate (prevention layer health, from check script results)
- Incident trend (open vs closed over time)
- OL carry-forward rate (how many sessions load the consolidated OL)
- Delegation duty compliance (how many delegations include all 6 elements)

**Architecture**: The `kpi_events` table in the harness DB already supports this. Each metric is a `metric_name` with `dimensions` (JSON blob). The dashboard queries the harness DB (not session DBs) for cross-session aggregation.

### Proposal 4: Context-Aware Command Suggestions

**What it is**: The dashboard analyzes the agent's recent messages and suggests relevant commands the commander might want to issue.

**Why it matters**: The commander's corrections follow patterns (OL Part 1: "How the Commander Corrects"). If the dashboard can detect common correction triggers, it can pre-build the command.

**Examples**:
- Agent just launched 3+ subagents -> suggest "Show delegation status"
- Agent wrote a plan -> suggest "Approve Plan" / "Reject Plan"
- Agent made a commit -> suggest "Run check scripts" / "Review diff"
- Session duration > 2h -> suggest "Checkpoint" (OL session hygiene)
- Agent mentioned an assumption -> suggest "Verify assumption" / "Flag as incorrect"

**Architecture**: A lightweight classifier runs on the last N messages. It looks for keywords and message types, not deep NLP. The suggestions appear as quick-action buttons in the command palette.

---

## Part 4: Implementation Roadmap

### Phase 1: Command Channel (builds on existing feedback loop)

**Effort**: 1 session (main agent with 1 subagent)

1. **Stop hook** (`command-channel-stop.sh`): Reads pending directives from SQLite, injects via stderr, blocks if flash priority.
2. **Schema extension**: Add `commander_directives` table (or extend `commander_feedback` with priority and response fields).
3. **harness-db.py directives**: CLI subcommand for reading/acknowledging/executing directives.
4. **Dashboard command palette**: Extend session-command-center-v2.py with the command interface.

### Phase 2: Delegation Visibility (enables orchestration panel)

**Effort**: 1 session

1. **Delegation hooks**: PreToolUse hooks on Agent/Task tool calls that write to `delegation_log` and `missions`.
2. **Dashboard delegation tab**: Populate from live DB data.
3. **Kill command**: Dashboard button -> directive with target = mission_id -> Stop hook relays to agent.

### Phase 3: Self-Learning Integration

**Effort**: 1-2 sessions

1. **Correction-to-OL pipeline**: SessionEnd hook reads resolved corrections, formats as OL entries, appends to consolidated OL.
2. **Governance health metrics**: KPI collection hooks + dashboard view.
3. **Session handoff via dashboard**: Banner display + next-session injection.

### Phase 4: Context-Aware Suggestions

**Effort**: 1 session

1. **Message classifier**: Lightweight pattern matching on recent messages.
2. **Suggestion engine**: Maps classifier output to pre-built commands.
3. **Dashboard integration**: Suggestions appear as quick-action buttons.

---

## Part 5: Operational Learning

### OL-CC1: Polling is correct when push is unavailable

**Principle**: When the platform does not support push notifications (external event injection), polling a durable shared store at natural pause points is the correct pattern. Every major framework (Temporal, LangGraph, Jupyter) uses this pattern when push is unavailable. The key variables are: store durability (SQLite > /tmp), polling frequency (Stop hook fires every 15-60s in active sessions), and latency tolerance (commander directives tolerate 60s latency; crash recovery does not).

**Evidence**: All 12 systems investigated. Temporal signals = polling workflow state. Jupyter widgets = polling comm queue when kernel is idle. LangGraph checkpoints = polling checkpoint store on resume.

### OL-CC2: Separate observation from command

**Principle**: The observation path (telemetry/downlink) and the command path (uplink) should be separate subsystems sharing a common data store. NASA separates them because they have different bandwidth, latency, and reliability requirements. For aitools: messages (agent -> commander) are high-bandwidth, continuous, automated. Directives (commander -> agent) are low-bandwidth, deliberate, verified.

**Evidence**: NASA JPL ground systems. Open MCT plugin architecture. The feedback loop v2's separate `commander_feedback` table (not mixed into `messages`) is the correct design.

### OL-CC3: The Stop hook is the agent's "idle loop"

**Principle**: In CC's architecture, the Stop hook serves the same function as Temporal's workflow main loop, Jupyter's kernel idle handler, and a game engine's frame callback. It's the point where the agent is receptive to external input. Building command processing into the Stop hook is architecturally sound -- it's not a hack, it's the designed extension point.

**Evidence**: CC docs explicitly state Stop hooks can block (exit 2) to force continuation. The stderr injection mechanism is designed for context injection. The only constraint is that the Stop hook must be fast (<100ms), which SQLite reads easily satisfy.

### OL-CC4: Priority matters more than latency

**Principle**: The commander doesn't need sub-second command delivery. They need priority-based processing: "stop what you're doing" must interrupt immediately (next Stop hook), while "here's some context" can wait. Priority is more important than latency. The feedback loop v2 treats all feedback equally -- this is the gap.

**Evidence**: NASA command uplink has priority levels. Slack interactive messages have urgency routing. CI/CD has "abort" vs "continue." The commander's corrections (OL Part 1) have implicit priority: "stop worrying about X" is flash priority; "I notice Y" is normal priority.

### OL-CC5: The Claude Agent SDK will eventually solve this better

**Principle**: GitHub Issue #70 (Agent SDK real-time steering) and Issue #24983 (external event sources) are active feature requests. When the platform supports mid-session message injection, the Stop-hook polling pattern becomes unnecessary. Design the command channel so it can be migrated from Stop-hook polling to SDK push when the platform supports it. The migration path: keep the SQLite data store and the dashboard command interface; replace the Stop hook reader with an SDK event handler.

**Evidence**: Claude Code already supports real-time steering (human typing while agent runs). The capability exists in the product but is not exposed via hooks or SDK. The feature requests track this gap.

---

## Cross-References

| Source | What it provided |
|--------|-----------------|
| LangGraph interrupt/checkpoint/resume | Pause-and-wait pattern, durable state, exact-point resume |
| Temporal signals | Polling shared state from workflow loop, signal handler pattern |
| OpenAI Agents SDK RunToolApprovalItem | Interruption/approval pattern, structured pause |
| HumanLayer SDK | Channel-based approval delivery, decorator pattern |
| Slack interactive messages | Button callback, approval workflow, bidirectional via existing channel |
| Jenkins/Argo CD approval gates | Pipeline pause, binary approval, dashboard as approval UI |
| Jupyter Comms/Widgets | Bidirectional messaging, kernel-busy constraint (same as CC) |
| VS Code webview postMessage | Typed message queue, sandboxed bidirectional communication |
| NASA Open MCT | Plugin architecture, telemetry dictionary, command integration |
| NASA JPL ground systems | Uplink/downlink separation, command verification, priority |
| CC hooks docs | Stop hook block mechanism, stderr injection, lifecycle events |
| CC GitHub issues #24983, #70 | Platform constraints, feature requests, future direction |
| Claude Agent SDK V2 | Session resume, mid-session injection (requested, not yet available) |

## Sources

- [LangGraph Interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts)
- [Temporal Human-in-the-Loop AI Agent](https://docs.temporal.io/ai-cookbook/human-in-the-loop-python)
- [OpenAI Agents SDK Human-in-the-Loop](https://openai.github.io/openai-agents-js/guides/human-in-the-loop/)
- [HumanLayer SDK](https://pypi.org/project/humanlayer/)
- [Slack Interactive Messages](https://api.slack.com/automation/interactive-messages)
- [Slack Approval Workflows](https://api.slack.com/best-practices/blueprints/approval-workflows)
- [Jupyter Messaging](https://jupyter-client.readthedocs.io/en/stable/messaging.html)
- [VS Code Webview API](https://code.visualstudio.com/api/extension-guides/webview)
- [NASA Open MCT](https://nasa.github.io/openmct/)
- [NASA Ground Data Systems](https://www.nasa.gov/smallsat-institute/sst-soa/ground-data-systems-and-mission-operations/)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [CC Issue #24983: External Event Sources](https://github.com/anthropics/claude-code/issues/24983)
- [Agent SDK Issue #70: Real-Time Steering](https://github.com/anthropics/claude-agent-sdk-typescript/issues/70)
- [Claude Agent SDK TypeScript V2](https://platform.claude.com/docs/en/agent-sdk/typescript-v2-preview)
- [Claude Code Headless/Programmatic](https://code.claude.com/docs/en/headless)
- [MCP Transports (Streamable HTTP)](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports)
- [Auth0 Secure HITL](https://auth0.com/blog/secure-human-in-the-loop-interactions-for-ai-agents/)
- [StackAI HITL Design](https://www.stackai.com/insights/human-in-the-loop-ai-agents-how-to-design-approval-workflows-for-safe-and-scalable-automation)
- [Permit.io HITL Best Practices](https://www.permit.io/blog/human-in-the-loop-for-ai-agents-best-practices-frameworks-use-cases-and-demo)
- [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- [SQLite WAL Mode](https://sqlite.org/wal.html)
- [F Prime Ground Interface Architecture](https://fprime.jpl.nasa.gov/latest/docs/user-manual/framework/ground-interface/)
