# Mission Control Artifact Inventory

**Compiled**: 2026-03-25, session 2d439e32-3
**Purpose**: Complete inventory of every artifact across the aitools repo that informs what mission control is, was designed to be, or should become. Sorted by date within each category.

---

## Timeline Summary

| Date | Session | What happened |
|------|---------|---------------|
| 2026-03-19 | Z1IhGrcgGO | First session activity dashboard (40-agent HTML report) |
| 2026-03-21 | 5HyCwPtSDH | Feasibility study, RECON brief, dynamic dashboard built + shipped (v0.63.0) |
| 2026-03-22 | 5HyCwPtSDH | M24 dynamic mode, multi-mission, health checks, /mission-control skill shipped (v0.65.0) |
| 2026-03-24 | RnTOD5XJFi | Dashboard miss discovered, gap analysis, proposals, multi-session architecture FRAGORD |
| 2026-03-24 | 5RXfu1UodN | Institutional memory capture referencing dashboard patterns |
| 2026-03-25 | c0dc2ddc-f | SQLite-backed command center, feedback loop, Vercel deploy (nobulai.tools), command channel designed, session viewer |
| 2026-03-25 | 2d439e32-3 | Meaning reconstruction, data flow investigation, export-mission-control.py, refresh pipeline |

---

## Category 1: Commander Intent (Jose's Words -- Authoritative)

### 1a. meaning-reconstruction.md -- Section 2: What Mission Control Means
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/meaning-reconstruction.md`
- **Type**: Reconstructed commander intent, provenance-traced
- **Date**: 2026-03-25
- **Status**: CURRENT -- the definitive document
- **Summary**: Mission control is 7 things per Jose's words: (1) a context-efficient communication channel, (2) bidirectional (commander sees + sends feedback), (3) no MVP/no versions/continuously evolving, (4) web-accessible at nobulai.tools, (5) full observability (prompts, context, decisions, OL), (6) reviews and proposals go through MC not conversation, (7) the cockpit to the harness machine.

Key quotes with provenance:
- "mission control is critical...context-efficient communication" (OBS-63)
- "there is no dashboard MVP...just mission control" (line 2555)
- "i hate using local server. i want a web portal" (line 2468)
- "bidirectional -- commander feedback flows to agents" (OBS-59)
- "proposals go through mission control, not conversation" (D-MC-PREREQUISITE)

---

## Category 2: Architecture Studies and Proposals

### 2a. feasibility-mission-control.json
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/feasibility-mission-control.json`
- **Type**: Feasibility study with 7-option evaluation matrix
- **Date**: 2026-03-21
- **Status**: HISTORICAL -- conclusions implemented, superseded by SQLite transition
- **Summary**: Evaluated 7 options for dynamic dashboard. Key insight: "the running estimate JSON IS already the data model." All viable options converge to embedded JSON + generator script. fetch() from file:/// is CORS-blocked. Chose stdlib HTTP server (Option C). Architecture is settled.

### 2b. recon-mission-control-fragord.json (FRAGORD v2)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/recon-mission-control-fragord.json`
- **Type**: Intelligence brief for dashboard build mission
- **Date**: 2026-03-21
- **Status**: HISTORICAL -- consumed by M24 mission
- **Summary**: Mechanism-agnostic requirements, S1 role definition, commander intent, executability assessment. Defines data elements per panel (session header, summary stats, agent tracker, governance, findings, open threads, session state, conclusions). Supersedes first recon (hook-centric, killed by CORS finding).

### 2c. recon-mission-control.json
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/recon-mission-control.json`
- **Type**: Intelligence brief (first version)
- **Date**: 2026-03-21
- **Status**: SUPERSEDED by 2b -- assumed hook-centric architecture that CORS killed
- **Summary**: Full audit of 3 existing dashboards, hook architecture, planning brief decisions. Found .gitignore still blocks .aitools/. Still useful for its dashboard data model audit.

### 2d. mission-control-gap-analysis.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-control-gap-analysis.md`
- **Type**: Root cause analysis
- **Date**: 2026-03-24
- **Status**: CURRENT -- the schema mismatch diagnosis is still the core problem pattern
- **Summary**: 14+ hour session launched 3 competing missions (Alpha/Bravo/Charlie). All dashboards showed zeros. Root cause: schema mismatch -- missions wrote ad-hoc running estimate schemas that didn't match generate-dashboard.py's expected data contract. "The diagnosis: Schema mismatch."

### 2e. mission-control-proposals.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-control-proposals.md`
- **Type**: Three-category proposal (immediate fixes, infrastructure, architecture)
- **Date**: 2026-03-24
- **Status**: PARTIALLY IMPLEMENTED -- schema validation shipped in v0.65.0, some proposals overtaken by SQLite transition
- **Summary**: Proposes running estimate schema validation, dashboard pre-flight health check, running estimate templates. Category 2 (mission command infrastructure) proposes codifying ad-hoc monitoring into harness. Category 3 proposes SQLite migration alignment. Some proposals became the /mission-control skill.

### 2f. dashboard-extension-investigation.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/dashboard-extension-investigation.md`
- **Type**: Architecture recommendation with evidence
- **Date**: 2026-03-25
- **Status**: PARTIALLY IMPLEMENTED -- the standalone approach was taken instead of extending
- **Summary**: Recommends extending generate-dashboard.py with a --db flag (~80-120 lines). The export bridge (harness-db.py export_session_to_dict()) already exists. The architecture cleanly separates data acquisition from rendering. Instead, session-command-center.py was built as standalone (architectural decision documented in 3b).

### 2g. command-channel-investigation.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/command-channel-investigation.md`
- **Type**: Cross-domain architecture investigation + feature proposals
- **Date**: 2026-03-25
- **Status**: CURRENT -- three-layer architecture design is the blueprint
- **Summary**: Investigated 12 systems across 7 domains (LangGraph, Temporal, NASA Open MCT, Jupyter, VS Code, etc.). Answer: "polling a shared data store is the correct pattern for CC's architecture." Three layers: (1) Stop-hook command reader, (2) command protocol (typed directives in SQLite), (3) dashboard command interface. Four bonus features: orchestration panel, session handoff protocol, governance health dashboard, context-aware command suggestions.

### 2h. feedback-loop-investigation.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/feedback-loop-investigation.md`
- **Type**: Architecture investigation + working prototype
- **Date**: 2026-03-25
- **Status**: IMPLEMENTED in session-command-center-v2.py
- **Summary**: Designs bidirectional command interface: commander submits feedback through dashboard UI -> written to SQLite (commander_feedback table) -> agent reads -> corrections become OL. Key insight: "the dashboard is already polling the DB every 3 seconds. Adding a write path closes the loop."

### 2i. proposal-web-portal-v2.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/proposal-web-portal-v2.md`
- **Type**: Current-state assessment + architectural direction
- **Date**: 2026-03-25
- **Status**: CURRENT -- describes the relay pattern (D-RELAY-PATTERN) and what exists
- **Summary**: Documents three local dashboards (generate-dashboard.py, session-command-center-v2.py, session-viewer.py) plus the nobulai.tools static deployment. Future: Cloudflare tunnel relay pattern where local machine is source of truth, public URL proxies to it. Currently: static snapshot on Vercel.

### 2j. mission-control-data-flow-investigation.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/mission-control-data-flow-investigation.md`
- **Type**: Architecture investigation and pipeline design
- **Date**: 2026-03-25
- **Status**: CURRENT -- maps the two completely separate dashboard pipelines
- **Summary**: nobulai.tools was frozen on session c0dc2ddc-f data. Root cause: no automated pipeline connects session DB writes to Vercel deployment. Documented the two separate dashboards (local JSON-backed on port 8411 vs public SQLite-backed on Vercel). Local dashboard is a zombie process. Found generate-dashboard.py has no --db flag yet.

---

## Category 3: Code Artifacts (Built Things)

### 3a. generate-dashboard.py
- **Path**: `/Users/pepe/repos/aitools/scripts/generate-dashboard.py`
- **Type**: Shipped production code (1547 lines)
- **Date**: Committed 2026-03-21, updated 2026-03-22
- **Status**: CURRENT -- production, JSON-backed dashboard generator
- **Summary**: The first S1 (Administration) capability in the harness. Reads running estimate JSON, produces self-contained HTML dashboard. Three modes: static, live (--serve with polling), multi-mission (--multi-dir). Zero external dependencies. GitHub-style dark theme. Architecture: embedded JSON + generator script (Option G from feasibility study).

### 3b. session-command-center.py
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/session-command-center.py`
- **Type**: Working prototype (~1000 lines)
- **Date**: 2026-03-25
- **Status**: CURRENT but in scratch -- needs promotion decision
- **Summary**: The DB-backed evolution of generate-dashboard.py. Reads SQLite session DB directly (not JSON). Live polling every 3 seconds. Auto-detects current session. Standalone (architectural decision: self-contained, not extension). Tabs: Messages, Delegations (empty -- write-side gap), Missions (empty), Governance, State.

### 3c. session-command-center-v2.py
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/session-command-center-v2.py`
- **Type**: Working prototype with feedback loop (~1100 lines)
- **Date**: 2026-03-25
- **Status**: CURRENT but in scratch -- needs promotion decision
- **Summary**: Extends v1 with bidirectional feedback: commander_feedback table, POST /api/feedback, feedback lifecycle (submitted/acknowledged/resolved), Cmd+K modal, quick feedback button, toast notifications, pending/resolved sections. "The DB-backed command interface for the self-learning loop."

### 3d. session-viewer.py
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/session-viewer.py`
- **Type**: Working prototype (560 lines)
- **Date**: 2026-03-25
- **Status**: CURRENT but in scratch -- needs promotion decision
- **Summary**: Session file browser with markdown rendering, auto-refresh, and feedback UI (right-click contextual feedback, viewer_feedback table). Dark theme matching mission control design language. Purpose: commander observability into session artifacts without opening files in wrong apps.

### 3e. export-mission-control.py (current session version)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/export-mission-control.py`
- **Type**: Working code (single-file exporter)
- **Date**: 2026-03-25
- **Status**: CURRENT -- the deployed pipeline
- **Summary**: Reads session SQLite DB, embeds into HTML template, writes static index.html for Vercel deploy. Includes feedback form, modal (Cmd+K), live feedback list (polls /api/feedback), toast notifications. Extracts markdown documents from scratch directory and categorizes them.

### 3f. mission-control-deploy/ (build pipeline)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mission-control-deploy/`
- **Type**: Build pipeline (export-snapshot.py + build.py + deploy.sh + vercel.json)
- **Date**: 2026-03-25
- **Status**: SUPERSEDED by 3e (export-mission-control.py) -- this was the original multi-file pipeline
- **Summary**: The first Vercel deployment pipeline. export-snapshot.py extracts SQLite to JSON snapshot, build.py generates 139KB self-contained HTML, deploy.sh orchestrates all three + vercel deploy. Had a JS syntax error (escaped quotes in f-string) that caused blank dashboard -- fixed in mission-control-verify-findings.md.

### 3g. refresh-nobulai.sh
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/refresh-nobulai.sh`
- **Type**: One-command refresh script
- **Date**: 2026-03-25
- **Status**: CURRENT -- convenience wrapper
- **Summary**: Reads current session DB via export-mission-control.py, deploys to Vercel with --prod. Supports --preview for staging. The repeatable 3-step pipeline: export -> write HTML -> vercel deploy.

### 3h. aitools-dashboard.sh / aitools-dashboard.ps1
- **Path**: `/Users/pepe/repos/aitools/scripts/aitools-dashboard.sh` and `.ps1`
- **Type**: Shipped production code (CLI lifecycle management)
- **Date**: Committed 2026-03-21, updated 2026-03-22
- **Status**: CURRENT -- production, manages JSON-backed dashboard only
- **Summary**: Dashboard lifecycle: --background, --stop, --status, --health-check, --snapshot. Multi-instance via port-keyed PID registry (~/.aitools/dashboard-pids/). Delegates to generate-dashboard.py. Does NOT know about SQLite-backed dashboards.

### 3i. dashboard-serve.sh (SessionStart hook)
- **Path**: `/Users/pepe/repos/aitools/shared/hooks/dashboard-serve.sh`
- **Type**: Shipped hook
- **Date**: Committed 2026-03-22
- **Status**: CURRENT but launches stale data -- auto-launches JSON-backed dashboard, not SQLite-backed
- **Summary**: Thin dispatcher that fires on SessionStart. Calls aitools dashboard --background. Zero user action needed. Currently launches the JSON-backed dashboard which reads running-estimate.json -- often stale from prior sessions.

### 3j. ol-dashboard.py
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/ol-dashboard.py`
- **Type**: One-off utility
- **Date**: 2026-03-25
- **Status**: SCRATCH -- ad-hoc OL artifact browser
- **Summary**: Scans harvesting/, .scratch/, .aitools/channel/, plans/ for OL artifacts (AARs, briefings, running estimates). Shows the 10 most recent. HTML dashboard opened in Chrome. Tangential to mission control proper.

### 3k. generate-dashboards.py (session 5HyCwPtSDH)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/generate-dashboards.py`
- **Type**: Prototype that became generate-dashboard.py
- **Date**: 2026-03-21
- **Status**: SUPERSEDED -- evolved into scripts/generate-dashboard.py
- **Summary**: The original dashboard generator from the session that built the feature. Precursor to the shipped version.

### 3l. test-mission-control-dashboard.html
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/test-mission-control-dashboard.html`
- **Type**: Test HTML dashboard
- **Date**: 2026-03-21
- **Status**: HISTORICAL -- test artifact
- **Summary**: Test dashboard HTML from the build session. Dark theme, full CSS vars, same design language that became the standard.

### 3m. command-channel-stop.sh + schema + CLI
- **Path**: Described in `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/command-channel-build.md`
- **Type**: Working prototype (hook + schema + CLI subcommand)
- **Date**: 2026-03-25
- **Status**: BUILT NOT DEPLOYED -- needs setup-user-hooks.sh registration
- **Summary**: Layer 1 of the command channel. Stop hook polls commander_directives table, injects via stderr, exits 2 to block. harness-db.py directive add/list/poll/ack subcommands. Flash/priority/normal priorities.

---

## Category 4: Operational Learning

### 4a. mission-control-v2-operational-learning.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mission-control-v2-operational-learning.md`
- **Type**: OL from the agent that built session-command-center.py
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Key findings: (F1) the read-write asymmetry is stark -- only messages table has data, (F2) messages are the only real-time session data, (F3) port congestion from dashboard sprawl, (F4) SQLite read-only connections work well. What's missing: write-side hooks, decision recording, observation recording, schwerpunkt population, port lifecycle management.

### 4b. feedback-loop-operational-learning.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/feedback-loop-operational-learning.md`
- **Type**: OL from the feedback loop builder
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Built session-command-center-v2.py with commander_feedback table, API endpoints, feedback modal, lifecycle tracking. "The key insight: the dashboard is already polling the DB. Adding a write path closes the loop."

### 4c. command-channel-operational-learning.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/command-channel-operational-learning.md`
- **Type**: OL from the command channel investigation
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Five OL principles from cross-domain research: (1) polling universally correct when push unavailable, (2) feedback loop v2 is architecturally sound but incomplete, (3) CC platform constraints real but not blocking, (4) NASA uplink/downlink separation validates architecture, (5) Agent SDK V2 will provide better mechanism.

### 4d. observability-evaluation-report.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/observability-evaluation-report.md`
- **Type**: Tool evaluation for observability gap
- **Date**: 2026-03-25
- **Status**: CURRENT -- chose built-in Python converter over pip dependency
- **Summary**: Evaluated glow (terminal markdown), Python-Markdown (pip dep), and built-in converter. Chose zero-dep approach. Led to session-viewer.py.

### 4e. feedback-ui-operational-learning.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/feedback-ui-operational-learning.md`
- **Type**: OL from session-viewer feedback UI builder
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Right-click contextual feedback, viewer_feedback table, bottom toolbar. "Feedback is the communication channel from commander-in-the-future to agent-in-the-past."

### 4f. ol-dashboard-redeploy.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/ol-dashboard-redeploy.md`
- **Type**: OL from Vercel redeploy
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: 4-command pipeline for refreshing dashboard: export -> build -> deploy -> verify. Repeatable. Could be wrapped into single alias. Vercel deploys in ~7 seconds.

### 4g. mission-5-operational-learning.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mission-5-operational-learning.md`
- **Type**: OL from Vercel deploy subagent
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Redeployed with 155 messages, 29 decisions, 176 observations. Pipeline: export-snapshot.py -> build.py -> vercel deploy.

### 4h. dashboard-investigation-aar.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/dashboard-investigation-aar.md`
- **Type**: AAR (After Action Review)
- **Date**: 2026-03-24
- **Status**: CURRENT -- root cause analysis of the dashboard miss
- **Summary**: Three rounds of prompt refinement missed dashboards entirely. Root cause: prompt agents never read the dashboard scripts (only governance/planning layers). Contributing: harness-state.json has zero dashboard content, planning brief has only 1 dashboard mention, OL frames dashboards as gap not capability. "Demonstrate-then-skip occurrence #4."

### 4i. dashboard-verification-aar.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/dashboard-verification-aar.md`
- **Type**: AAR from dashboard verification
- **Date**: 2026-03-24
- **Status**: CURRENT
- **Summary**: VERIFIED WORKING. Dashboard on port 8411 rendered correctly (29 delegations, 23 decisions, 18 findings). Multi-port test confirmed 3 simultaneous dashboards. Full chrome-devtools monitoring workflow verified.

### 4j. m24-dynamic-dashboard-aar.json
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/m24-dynamic-dashboard-aar.json`
- **Type**: AAR from the original dynamic dashboard build
- **Date**: 2026-03-22
- **Status**: HISTORICAL -- documents the silent descoping incident
- **Summary**: Critical observation: "Hard requirement silently descoped without surfacing." CORS blocking was discovered but team silently descended to static generator instead of surfacing as HARD BLOCK. Chose stdlib HTTP server (alt-1) as the VIABLE approach.

### 4k. stopgap-observability-report.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/stopgap-observability-report.md`
- **Type**: Decision report for Vercel deployment
- **Date**: 2026-03-25
- **Status**: CURRENT -- documents D-VERCEL-STOPGAP decision
- **Summary**: Chose static HTML with embedded JSON snapshot on Vercel over Vercel Python runtime or GitHub Pages. Rationale: zero infrastructure, one HTML file, deploy in one command. "Ship today, evolve tomorrow."

---

## Category 5: Investigation Reports and Findings

### 5a. mission-control-investigation.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/mission-control-investigation.md`
- **Type**: Tab-by-tab audit and fix report
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Audited nobulai.tools tab by tab. FIXED: feedback form missing (two build pipelines existed, newer one lacked form), feedback API 404 (dist/ had no api/ directory). Found 8 unfixed issues: delegations 0, missions 0, completed work 0, two session rows, current session not reflected, mobile responsiveness minimal, bidirectional messaging not functional, snapshot staleness.

### 5b. mission-control-verify-findings.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mission-control-verify-findings.md`
- **Type**: Verification and fix report
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Dashboard was BLANK due to JS syntax error (classList.toggle quotes in f-string). Fixed build.py. All 6 tabs verified working. Data accuracy: messages and decisions match, delegations = DATA GAP (0 in DB despite 25+ launched).

### 5c. s3-commander-feedback-synthesis.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/s3-commander-feedback-synthesis.md`
- **Type**: Commander feedback investigation (6 items)
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Addressed 6 commander feedback items from dashboard. Item 1: /aitool-provenance naming. Item 5: deploy updated dashboard to nobulai.tools. Demonstrates the feedback loop working -- commander provides feedback via dashboard, agents investigate and act.

### 5d. m17-mission-analysis-gap.json
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/m17-mission-analysis-gap.json`
- **Type**: Intelligence investigation
- **Date**: 2026-03-21
- **Status**: HISTORICAL but findings are current
- **Summary**: Post-mission analysis is a gap in the harness. S3 never independently initiated reconciliation. 8 of 12 deviations from unverified assumptions could have been caught by post-mission analysis. Reconciliation produces highest-leverage governance decisions.

### 5e. feedback-analysis.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-2d439e32-3/feedback-analysis.md`
- **Type**: Analysis of commander feedback items
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Analyzed 6 feedback items from dashboard. Provenance naming correct. CLAUDE.md self-awareness from nobul-ops needs extraction. Work product from session needs to be accessible via mission control.

---

## Category 6: Delegation Prompts (Design Intent)

### 6a. delegation-mission-control-v2.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-mission-control-v2.md`
- **Type**: Delegation prompt for SQLite-backed command center
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced session-command-center.py
- **Summary**: "Build the live session command center for the aitools harness." Specifies: session identity, delegates launched, messages, running estimate state, OL, decisions. "A command center view -- not a report, a live instrument panel."

### 6b. delegation-mission-control-verify.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-mission-control-verify.md`
- **Type**: Delegation prompt for verification + fix
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced mission-control-verify-findings.md
- **Summary**: "Mission control is live at nobulai.tools. Make it work as intended." Verify features, identify issues, fix what you can. "Think like the commander -- zero friction."

### 6c. delegation-dashboard-feedback-loop.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-dashboard-feedback-loop.md`
- **Type**: Delegation prompt for feedback loop
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced session-command-center-v2.py and feedback-loop-investigation.md
- **Summary**: "Make the mission control dashboard a bidirectional command interface." Feedback, incidents, OL surfacing, carry-forward state. "The dashboard should become part of the self-learning loop."

### 6d. delegation-dashboard-investigation.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-dashboard-investigation.md`
- **Type**: Delegation prompt for architecture investigation
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced dashboard-extension-investigation.md
- **Summary**: "Investigate how to extend generate-dashboard.py to serve from SQLite instead of JSON." Should it extend or be separate?

### 6e. delegation-observability-mission.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-observability-mission.md`
- **Type**: Delegation prompt for observability gap solution
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced observability-evaluation-report.md and session-viewer.py
- **Summary**: "The commander cannot easily observe session artifacts. Investigate, evaluate, and build a solution." Led to session-viewer.py.

### 6f. delegation-observability-stopgap.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-observability-stopgap.md`
- **Type**: Delegation prompt for Vercel deployment
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced nobulai.tools deployment
- **Summary**: "Commander needs mission control accessible without friction TODAY. Not after Cloudflare. Now." Led to static snapshot on Vercel.

### 6g. delegation-ol-dashboard.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-ol-dashboard.md`
- **Type**: Delegation prompt for OL artifact browser
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced ol-dashboard.py
- **Summary**: "Surface all operational learning artifacts in the repo." Find files, generate HTML dashboard, open in Chrome.

### 6h. delegation-feedback-ui.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-feedback-ui.md`
- **Type**: Delegation prompt for session-viewer feedback
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced feedback-ui-operational-learning.md
- **Summary**: "Add a feedback mechanism to session-viewer.py." Right-click contextual feedback, viewer_feedback table, bottom toolbar.

### 6i. delegation-2deep-feedback-mission.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/delegation-2deep-feedback-mission.md`
- **Type**: Delegation prompt for 2-deep feedback synthesis
- **Date**: 2026-03-25
- **Status**: EXECUTED -- produced s3-commander-feedback-synthesis.md
- **Summary**: Process all 6 commander feedback items from dashboard. 2-deep delegation test.

### 6j. mission-dashboard-investigation.md (delegation prompt)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-dashboard-investigation.md`
- **Type**: Delegation prompt for dashboard miss investigation
- **Date**: 2026-03-24
- **Status**: EXECUTED -- produced dashboard-investigation-aar.md
- **Summary**: "Investigate why dynamic mission control dashboards have been absent from mission prompts." Audit conversation, find prior work, produce improved prompts with dashboard requirements.

### 6k. mission-dashboard-verification.md (delegation prompt)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-dashboard-verification.md`
- **Type**: Delegation prompt for dashboard verification
- **Date**: 2026-03-24
- **Status**: EXECUTED -- produced dashboard-verification-aar.md
- **Summary**: "The commander has NEVER been asked to review a dashboard. This is demonstrate-then-skip #4." Test it RIGHT NOW, present to commander.

### 6l. mission-fragord-dashboard.md and -v2.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-fragord-dashboard.md` and `mission-fragord-dashboard-v2.md`
- **Type**: Delegation prompts for running estimate update + dashboard verification + SQLite architecture
- **Date**: 2026-03-24
- **Status**: v2 EXECUTED -- produced the running estimate v9 update and SQLite migration RFC
- **Summary**: v1: update running estimate, verify dashboard, produce dashboard RFC, produce v6 prompts. v2: expanded by commander to incorporate SQLite patterns from marse, convert running estimate to SQLite, multi-session dashboards.

---

## Category 7: Shipped Skills and Release Notes

### 7a. /mission-control skill
- **Path**: `/Users/pepe/repos/aitools/shared/skills/mission-control/SKILL.md`
- **Type**: Shipped user-level skill
- **Date**: Committed 2026-03-22 (v0.65.0)
- **Status**: CURRENT but limited -- codifies monitoring commands, not the full MC vision
- **Summary**: Codifies 7 ad-hoc monitoring patterns from the multi-mission operation where dashboards showed zeros. 4-layer stack: infrastructure health, activity monitoring, work product inventory, deliverable validation. Pre-flight verification protocol, mission health thresholds, FRAGORD criteria. Does NOT cover the bidirectional communication, web portal, or feedback capabilities.

### 7b. RELEASE_NOTES.md references
- **Path**: `/Users/pepe/repos/aitools/RELEASE_NOTES.md`
- **Type**: Shipped version history
- **Status**: CURRENT
- **Summary of mission control entries**:
  - v0.62.5 (2026-03-19): "Session activity dashboard" -- 40-agent interactive HTML report
  - v0.63.0 (2026-03-21): "Dynamic mission control dashboard" -- aitools dashboard CLI, SessionStart hook, zero dependencies
  - v0.65.0 (2026-03-24): "/mission-control skill, multi-mission dashboard, schema validation, health check, multi-instance ports, running estimate template"
  - v0.67.0 (2026-03-25): "Telemetry rebuild, /aitool-continue, mission control" -- 360 harvested artifacts

---

## Category 8: Dashboard Integration Materials

### 8a. dashboard-integration-section.md
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/dashboard-integration-section.md`
- **Type**: Template section for mission prompts
- **Date**: 2026-03-24
- **Status**: CURRENT -- should be included in future mission prompts
- **Summary**: "Live Dashboard Requirement (NON-NEGOTIABLE)." Instructions for mission agents: create running estimate, launch dashboard at mission start, maintain estimate during execution, commander monitors via chrome-devtools. Documents the existing dashboard system and what agents MUST do.

---

## Category 9: Screenshots and Visual Evidence

### 9a. Session c0dc2ddc-f screenshots (21 files)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mc-screenshot-*.png` and `mc-verify-*.png`
- **Type**: Visual evidence of deployed dashboard
- **Date**: 2026-03-25
- **Status**: CURRENT
- **Summary**: Screenshots of nobulai.tools at various stages: homepage, tabs (delegations, governance, state, feedback), expanded cards, deployment verification. 21 screenshots documenting the visual evolution.

### 9b. Session RnTOD5XJFi dashboard screenshots (6 files)
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/dashboard-port*-screenshot.png` and `dashboard-*-8411.png`
- **Type**: Visual evidence of local dashboard
- **Date**: 2026-03-24
- **Status**: HISTORICAL
- **Summary**: Screenshots from multi-port verification test (ports 8411, 8421, 8422).

### 9c. Session 5HyCwPtSDH dashboard screenshots
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/m24-live-dashboard-*.png`
- **Type**: Visual evidence from original build
- **Date**: 2026-03-22
- **Status**: HISTORICAL
- **Summary**: Initial and after-update screenshots of the first live dashboard.

### 9d. Session c0dc2ddc-f command center screenshot
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/command-center-screenshot.png`
- **Type**: Visual evidence of session command center
- **Date**: 2026-03-25
- **Status**: CURRENT

---

## Category 10: Harvested Artifacts (in harvesting/)

### 10a. Mission control JSON files (4 unique, 28 duplicates)
- **Paths**: `harvesting/2026-03-22_recon-mission-control.json`, `harvesting/2026-03-22_feasibility-mission-control.json`, `harvesting/2026-03-22_recon-mission-control-fragord.json`, `harvesting/2026-03-22_m17-mission-analysis-gap.json`
- **Type**: Harvested copies of session-5HyCwPtSDH intelligence products
- **Date**: 2026-03-22
- **Status**: DUPLICATED 6x (harvesting bug produced _1 through _6 copies of each)
- **Summary**: Copies of the feasibility study, RECON briefs, and gap analysis from the dashboard build session.

### 10b. Dashboard HTML files (7 unique, many duplicates)
- **Paths**: `harvesting/2026-03-22_session-dashboard.html`, `harvesting/2026-03-22_*-dashboard-v2.html`, `harvesting/2026-03-22_*-governance-dashboard.html`, `harvesting/2026-03-22_*-live-dashboard.html`, etc.
- **Type**: Harvested dashboard HTML files
- **Date**: 2026-03-22
- **Status**: HISTORICAL -- snapshots of dashboards from sessions Z1IhGrcgGO and 5HyCwPtSDH

### 10c. Session c0dc2ddc-f delegation docs
- **Paths**: `harvesting/2026-03-25_session-c0dc2ddc-f_delegation-mission-control-v2.md`, `harvesting/2026-03-25_session-c0dc2ddc-f_delegation-mission-control-verify.md`, `harvesting/2026-03-25_session-c0dc2ddc-f_delegation-dashboard-*.md`, `harvesting/2026-03-25_session-c0dc2ddc-f_command-channel-*.md`, `harvesting/2026-03-25_session-c0dc2ddc-f_dashboard-extension-investigation.md`
- **Type**: Harvested copies of session-c0dc2ddc-f mission control work
- **Date**: 2026-03-25
- **Status**: CURRENT -- harvested for promotion evaluation

---

## Category 11: Cross-Session Context

### 11a. mission-bravo-institutional-memory.json
- **Path**: `/Users/pepe/repos/aitools/.scratch/session-5RXfu1UodN/mission-bravo-institutional-memory.json`
- **Type**: Institutional memory capture
- **Date**: 2026-03-24
- **Status**: HISTORICAL
- **Summary**: 89KB intelligence product from session 5RXfu1UodN. Contains running estimate lifecycle AAR, dashboard patterns, and cross-session knowledge. Includes how dashboards fit into the broader institutional memory picture.

### 11b. planning-brief.json
- **Path**: `/Users/pepe/repos/aitools/plans/mission-command-briefing/planning-brief.json`
- **Type**: Mission command planning brief
- **Date**: Various (session 5HyCwPtSDH era)
- **Status**: STALE for dashboard content -- only 1 dashboard mention (Datadog plan). D-DASHBOARD-* decisions never amended into brief (DS-4 deferred item).
- **Summary**: 54 decisions, but dashboard decisions (D-DASHBOARD-SHIP-DEFINITION, D-CLI-NATIVE-DASHBOARD, D-DYNAMIC-HARD-REQUIREMENT) were never added. This gap contributed to the dashboard miss in mission prompts.

---

## Key Decisions (D-*) Relevant to Mission Control

| Decision | Source | Date | Status |
|----------|--------|------|--------|
| D-DASHBOARD-SHIP-DEFINITION | session 5HyCwPtSDH | 2026-03-22 | Active |
| D-CLI-NATIVE-DASHBOARD | session 5HyCwPtSDH | 2026-03-22 | Active |
| D-DYNAMIC-HARD-REQUIREMENT | session 5HyCwPtSDH | 2026-03-22 | Active |
| D-DASHBOARD-GOVERNANCE | session 5HyCwPtSDH | 2026-03-22 | Active |
| D-NO-MVP | session c0dc2ddc-f | 2026-03-25 | Active |
| D-MC-PREREQUISITE | session 2d439e32-3 | 2026-03-25 | Active |
| D-NOBULAI-TOOLS | session c0dc2ddc-f | 2026-03-25 | Active |
| D-VERCEL-STOPGAP | session c0dc2ddc-f | 2026-03-25 | Active |
| D-RELAY-PATTERN | session c0dc2ddc-f | 2026-03-25 | Active (future) |
| D-COMMAND-CHANNEL | session c0dc2ddc-f | 2026-03-25 | Designed not built |

---

## Summary: The Evolution of Mission Control

**Phase 1 (2026-03-19)**: Static HTML report of 40 agents. One-off, manually generated.

**Phase 2 (2026-03-21)**: Dynamic dashboard. Feasibility study -> generate-dashboard.py shipped. JSON-backed, live polling, CLI lifecycle. The first S1 (Administration) capability.

**Phase 3 (2026-03-22)**: Multi-mission, schema validation, health checks, /mission-control skill. Responding to the "all dashboards showed zeros" failure from competing missions.

**Phase 4 (2026-03-24)**: Dashboard miss discovered. Root cause: implementation layer invisible to prompt agents. Proposals for mission command infrastructure. SQLite architecture FRAGORD with multi-session requirements.

**Phase 5 (2026-03-25, session c0dc2ddc)**: Architectural explosion. SQLite-backed command center (session-command-center.py), bidirectional feedback loop (v2.py), session file viewer (session-viewer.py), Vercel deployment (nobulai.tools), command channel investigation (3-layer architecture), OL dashboard. Commander articulated the full vision: "no MVP, continuously evolving, bidirectional, web-accessible, context-efficient communication channel."

**Phase 6 (2026-03-25, session 2d439e32)**: Meaning reconstruction. Data flow investigation. Single-file export pipeline. Refresh automation. Fixed broken feedback. Deployed current session. Commander intent formally documented with provenance.

**What mission control IS today**: Three local tools (JSON dashboard, SQLite command center, file viewer), one public deployment (nobulai.tools static snapshot), one shipped skill (/mission-control monitoring commands), and a designed-but-not-built command channel. No unified architecture. The tools share a design language (dark theme) but share no code and have separate data pipelines.

**What mission control SHOULD become** (per commander intent): A single continuously-evolving bidirectional web interface at nobulai.tools where the commander observes session state, delegate activity, decisions, OL, and proposals -- and sends feedback and directives back through the same interface -- without consuming conversational context tokens.

---

## Total artifact count: ~80+ unique artifacts across 6 sessions
