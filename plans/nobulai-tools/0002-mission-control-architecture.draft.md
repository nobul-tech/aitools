# RFC 0002: Mission Control Architecture

- **Status**: Draft
- **Created**: 2026-03-28
- **Author**: Jose (via Claude Code, session f078fb16)
- **Linked**: RFC 0001 (nobulai-tools Product Definition), RFC 0003 (OL Graph Architecture), command-channel-investigation.md, meaning-reconstruction.md

**Intent**: **Purpose**: Define the mission control architecture for nobulai.tools — the commander's cockpit for monitoring sessions, communicating with agents, reviewing work products, and directing operations. **Scope**: MC landing page, session view, session viewer, command channel (directives + feedback), data path from local machine to cloud, multi-session monitoring. NOT the OL graph (RFC 0003). NOT the product infrastructure (RFC 0001). NOT the local harness implementation (aitools repo). **Audience**: Jose (decision-maker), any session implementing MC features in nobulai-tools.

## What Mission Control Means

From Jose's own words (meaning-reconstruction.md, Section 2), mission control is 7 things:

1. **A context-efficient communication channel** — "mission control is critical because it's a more context-efficient communication channel than conversation" (OBS-63, session c0dc2ddc-f)
2. **Bidirectional** — "commander feedback flows to agents" (OBS-59). Jose sees what agents are doing. Jose sends feedback and guidance back. Agents read and act.
3. **No MVP, continuously evolving** — "there is no dashboard MVP...just mission control" (D-NO-MVP). No versions, no alpha, no beta. Just mission control.
4. **Web-accessible** — "i hate using local server. i want a web portal" (session c0dc2ddc, line 2468). Lives at nobulai.tools. Accessible from any device.
5. **Full observability** — "i want to see what prompt was used to launch the mission, what context the agent loaded, what decisions it made and why" (session c0dc2ddc, line 2433)
6. **Reviews and proposals supported through MC** — both conversation and MC channels are supported for proposals (D-F10, session f078fb16)
7. **The cockpit to the harness machine** — the harness is the machine, MC is the cockpit

## MC Page Structure

### Landing Page: nobulai.tools/&lt;user&gt;/mc

Groups sessions by machine, then repo. Collapses empty levels (D-F6).

Content:
- Active sessions with live status (schwerpunkt, turn count, duration, health indicators)
- Recent sessions (last 7 days, clickable)
- Quick directives panel (Correction, Redirect, Approve, Reject, Context, Checkpoint)
- Per-session health indicators (from /mission-control skill's 7 monitoring patterns: process discovery, last activity, progress gauge, work product count, deliverable size, deliverable validation, dashboard health)

### Session View: nobulai.tools/&lt;user&gt;/mc/session/&lt;id&gt;

Tabs (matching what's already built and working at nobulai.tools):
- **Messages** — SITREPs + Findings, filterable by type, severity, agent role
- **Governance** — Decisions + Observations with status
- **Delegations** — Subagent launches, duty compliance scores (6 elements), tree view
- **Missions** — Nested missions with status tracking
- **State** — Schwerpunkt, completed work, deviations, hard requirements
- **Feedback** — Bidirectional: commander writes directives/feedback, agents read. Shows lifecycle (pending → acknowledged → executed/resolved)
- **Documents** — Session artifacts from scratch, rendered markdown
- **Git Diffs** — Commits from this session

### Session Viewer: nobulai.tools/&lt;user&gt;/mc/session/&lt;id&gt;/viewer

The commander's observability into session artifacts:
- File browser for session scratch + harvested artifacts
- Rendered markdown with syntax highlighting
- Right-click contextual feedback (per session-viewer.py): right-click on any section → feedback modal → saved to viewer_feedback table
- Feedback panel per file showing accumulated feedback
- Line-level feedback targeting (not yet built — requires markdown renderer with data-line attributes)

Data source: for active sessions, files from the local machine via data path. For completed sessions, harvested artifacts (in git) and archived JSONLs.

### Cross-Session View: nobulai.tools/&lt;user&gt;/mc/history

- Session timeline across all projects
- Filter by project, date range, machine
- Delegation quality trends (from KPI events in harness DB)
- Session duration and turn count patterns

## Command Channel Architecture

### Provenance-Grounded Two-Table Design (D-F5)

Two tables serve different purposes with different temporal characteristics, grounded in W3C PROV entity types:

**commander_directives** (uplink — time-critical):
- W3C PROV relationship: "triggered" — triggers immediate agent action
- Trust level: commander_directive (L3, highest authority)
- Delivery: per-turn via Stop hook (command-channel-stop.sh reads, injects via stderr, exits 2 to block)
- Lifecycle: pending → acknowledged → executed/rejected/deferred (session-scoped)
- Priority: flash (interrupt immediately), priority (next pause), normal (queued)
- Types: correction, redirect, priority, question, approve, reject, context, checkpoint

**commander_feedback** (OL — cross-session):
- W3C PROV relationship: "informed" — informs future decisions, becomes OL
- Trust level: varies (L2-L3)
- Delivery: pulled by agent on demand, no Stop hook blocking
- Lifecycle: submitted → acknowledged → resolved (may span sessions)
- Promotion: becomes knowledge_items in provenance graph when promoted at session boundaries

### Three-Layer Architecture (from command-channel-investigation.md)

**Layer 1: Stop-Hook Command Reader** (command-channel-stop.sh — built, not deployed)
- Fires on every Stop event (agent finishes responding)
- Opens session SQLite DB
- Queries commander_directives for pending entries
- If found: injects via stderr, acknowledges, exits 2 (block)
- If none: exits 0 (no-op)
- Performance: <50ms (SQLite WAL read)

**Layer 2: Command Protocol** (commander_directives table — built)
- 8 directive types, 3 priorities, 5 statuses
- CLI: harness-db.py directive add/list/poll/ack
- Durable: survives process crashes (SQLite)

**Layer 3: Dashboard Command Interface** (nobulai.tools MC UI)
- Command palette (Cmd+K): quick command entry with type selection
- Quick action buttons: Checkpoint, Redirect, Approve/Reject
- Command history with status badges
- Active commands panel with visual indicators (pulsing badge for pending)

### Cross-Domain Validation (from command-channel-investigation.md)

12 systems across 7 domains confirmed the architecture:
- Polling is universally correct when push is unavailable (OL-CC1)
- Observation and command should be separate subsystems (OL-CC2, NASA uplink/downlink)
- The Stop hook is the agent's "idle loop" (OL-CC3, same as Temporal's workflow loop, Jupyter's kernel idle)
- Priority matters more than latency (OL-CC4)
- Claude Agent SDK will eventually provide better mechanism (OL-CC5) — design for migration

## Data Path

### Constraints (D-F7)
- Last known state / offline acceptable when machine is off
- Directives must reach agent per-turn during active sessions
- Efficient caching, best effort, cost effective

### For Active Sessions (machine online, session running)
- Machine exposes local API (session-command-center-v2.py or equivalent)
- nobulai.tools GraphQL API connects to local machine endpoint
- Mechanism TBD: Cloudflare Tunnel, WebSocket, or cloud intermediary
- Directives: nobulai.tools UI → API → local machine endpoint → session SQLite DB → Stop hook reads
- Observation: local session DB → local API → nobulai.tools API → UI

### For Completed Sessions (machine may be offline)
- Session JSONL archived to dotprofile repo (git-tracked, pushed by session-archive.sh)
- Session DB exported to running-estimate.json (git-tracked, pushed at SessionEnd)
- Harvested artifacts in harvesting/ (git-tracked)
- nobulai.tools reads from git (dotprofile + aitools repos)
- No live updates — static cached state

### Caching Strategy
- Cloud cache updated while machine is online
- When machine goes offline, cache serves last known state
- Session state has a "last synced" timestamp displayed in UI
- Stale indicators when data is >5 minutes old during active session

## Existing Prototypes (in aitools scratch)

| Prototype | Location | What it does | Status |
|-----------|----------|-------------|--------|
| session-command-center.py | .scratch/session-c0dc2ddc-f/ | DB-backed live dashboard, auto-detect session, 7 tabs | Working, in scratch |
| session-command-center-v2.py | .scratch/session-c0dc2ddc-f/ | v1 + bidirectional feedback (POST/GET /api/feedback, Cmd+K modal, lifecycle tracking) | Working, in scratch |
| session-viewer.py | .scratch/session-c0dc2ddc-f/ | File browser, markdown rendering, right-click feedback, viewer_feedback table | Working, in scratch |
| export-mission-control.py | .scratch/session-2d439e32-3/ | SQLite → static HTML for Vercel | Working, deployed to nobulai.tools |
| command-channel-stop.sh | shared/hooks/ | Stop hook command reader (Layer 1) | Built, not deployed |
| generate-dashboard.py | scripts/ | JSON-backed dashboard (original, pre-SQLite) | Shipped, production |

These prototypes ARE the specification. The nobulai-tools implementation ports their functionality to the web product.

## Open Questions

| # | Question | Suggested Answer |
|---|----------|-----------------|
| 1 | Data path mechanism for active sessions? | Cloudflare Tunnel (credits available), evaluate alternatives |
| 2 | How does the session viewer get scratch files remotely? | Active: via local API/tunnel. Completed: only harvested artifacts |
| 3 | Multi-session monitoring (concurrent Alpha/Bravo/Charlie)? | Landing page shows all active, health indicators per session |
| 4 | Agent orchestration panel (delegation tree view)? | Phase 2 — requires write-side delegation hooks |
| 5 | Governance health dashboard (cross-session metrics)? | Phase 3 — reads from harness DB kpi_events |
| 6 | Context-aware command suggestions? | Phase 4 — lightweight classifier on recent messages |

## Implementation Phases

| Phase | What | Depends on |
|-------|------|-----------|
| 0 | Port session-command-center-v2.py to nobulai-tools (MC session view) | RFC 0001 repo exists |
| 0 | Port session-viewer.py to nobulai-tools (session viewer) | RFC 0001 repo exists |
| 1 | Implement MC landing page (machine → repo → sessions) | Phase 0 |
| 1 | Implement command channel via API (directives table + UI) | Phase 0, data path decided |
| 2 | Deploy command-channel-stop.sh (register in deployment pipeline) | Phase 1 |
| 2 | Implement delegation tree view | Write-side delegation hooks |
| 3 | Cross-session history view | Harness DB KPI data |
| 3 | Governance health metrics | Harness DB KPI aggregation |

## Test Plan

| # | Test | Verifies |
|---|------|----------|
| 1 | MC landing page shows active sessions grouped by machine/repo | Landing page works |
| 2 | Session view tabs all render with data | Session view works |
| 3 | Directive sent from MC UI reaches agent within one turn | Command channel end-to-end |
| 4 | Flash directive blocks agent (exit 2 from Stop hook) | Priority handling |
| 5 | Session viewer renders markdown with contextual feedback | Session viewer works |
| 6 | Completed session viewable when machine is offline | Caching/offline works |
| 7 | Multiple concurrent sessions visible on landing page | Multi-session monitoring |
