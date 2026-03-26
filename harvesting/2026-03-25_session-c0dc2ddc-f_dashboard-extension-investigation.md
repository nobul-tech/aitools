# Dashboard Extension Investigation: SQLite-Backed Live Session Command Center

**Investigator**: S2-Dashboard-Investigator
**Date**: 2026-03-25
**Session**: c0dc2ddc-f464-404d-a637-8103afda27af
**Classification**: Recommendation with evidence

---

## Executive Summary

**Recommendation: Extend `generate-dashboard.py` with a `--db` flag rather than creating a separate tool.** The existing dashboard has the right architecture (live server, HTML template, polling), the export bridge already exists (`harness-db.py export`), and the session DB schema already maps 1:1 to the JSON fields the dashboard renders. The minimum viable extension is small (approximately 80-120 lines of Python) because `export_session_to_dict()` in `harness-db.py` already produces dashboard-compatible JSON.

---

## Finding 1: What generate-dashboard.py Already Supports

**File**: `/Users/pepe/repos/aitools/scripts/generate-dashboard.py` (1547 lines)

The dashboard currently operates in three modes:

| Mode | Flag | Data Source | Server |
|------|------|-------------|--------|
| Static | `--estimate <path>` | JSON file (one-time embed) | None (file:// works) |
| Live | `--estimate <path> --serve` | JSON file (polled via `/api/estimate`) | stdlib HTTPServer on configurable port |
| Multi-mission | `--multi-dir <path> --serve` | Directory scan for `*/running-estimate.json` | HTTPServer with `/api/missions` endpoint |

**Live mode architecture** (lines 159-283):
- `DashboardHandler` serves `/` (HTML) and `/api/estimate` (JSON)
- `watch_and_regenerate()` thread polls file mtime every 1s
- When mtime changes, re-reads JSON, rebuilds HTML with `build_html()`, stores on `server.dashboard_html`
- Client-side JS polls `/api/estimate` every N seconds, re-renders on data change
- Zero external dependencies (stdlib `http.server`, `threading`, `os.stat`)

**Extension surface**: The architecture cleanly separates data acquisition (JSON read) from rendering (HTML template). The `DashboardHandler.do_GET()` for `/api/estimate` reads a JSON file -- this is the only place that needs to change for DB-backed mode. The JS client already handles arbitrary JSON objects via `renderDashboard(D, generatedAt)`.

**Key detail**: The argparse section (lines 1380-1429) currently accepts `--estimate` or `--multi-dir` as the data source. Adding `--db` as a third option follows the existing pattern exactly.

---

## Finding 2: What Data Is in the Session DB Right Now

**Source**: `python3 scripts/harness-db.py status` (ran successfully during investigation)

Current session (`c0dc2ddc-f464-404d-a637-8103afda27af`):
- **Status**: active
- **Missions**: 0
- **Messages**: 59 (all logged by hooks via `harness-db.py log`)
- **Schwerpunkt**: "unspecified" (not populated by the session start flow)

Harness index: 2 sessions registered (current active + one completed test session).

**Critical gap**: The session DB has 59 messages but 0 missions, 0 decisions, 0 delegation log entries. This is because:
1. The `harness-db-sessionstart.sh` hook registers the session but does not record the schwerpunkt
2. No hook or process currently writes to `missions`, `decisions`, `delegation_log`, or `observations` tables
3. The 59 messages are SITREPs from the surfacing-duty Stop hook -- these are the ONLY structured data being written to the DB during this session

---

## Finding 3: The Export Bridge Already Exists

**File**: `/Users/pepe/repos/aitools/scripts/harness-db.py`, function `export_session_to_dict()` (lines 558-760)

This function reads every table in the session DB and produces a dict with keys that the dashboard's `renderDashboard()` JS function consumes:

| Session DB Table | Export Key | Dashboard Renders |
|-----------------|------------|-------------------|
| `session` | `meta` (sessionId, schwerpunkt, version, etc.) | Header, session info |
| `missions` | `openThreads` | Open Threads tab |
| `delegation_log` | `delegationLog` | Agents tab (cards with status, role, mission) |
| `messages` (finding) | `findings` | Findings tab |
| `messages` (sitrep) | `sitreps` | NOT rendered (gap -- see Finding 4) |
| `decisions` | `decisions` | Governance tab, Decisions section |
| `observations` (assumption) | `assumptions` | Governance tab, Assumptions section |
| `observations` (all) | `observations` | NOT rendered (gap) |
| `completed_work` | `completedWork` | Session State tab |
| `hard_requirements` | `hardRequirements` | NOT rendered (gap) |
| `deviations` | `deviations` | Session State tab, Deviations section |
| `version_history` | `versionHistory` | NOT rendered (gap) |

The field naming differs slightly between JSON conventions (the running estimate JSON uses `delegationLog[].type`, `delegationLog[].id`, `delegationLog[].mission`) and the DB export (uses `delegationLog[].agentType`, `delegationLog[].agentName`, `delegationLog[].missionId`). The dashboard JS currently reads the JSON-convention fields. The DB-backed mode would need either:
- Option A: Update `export_session_to_dict()` to match the JSON conventions
- Option B: Update the JS `renderDashboard()` to read both conventions
- Option C: A thin adapter layer in the `/api/estimate` handler

**Recommendation**: Option A (update the export). The export function is the right place to normalize field names. This keeps the JS template unchanged.

---

## Finding 4: Data the Commander Needs That ISN'T in the Session DB

The delegation prompt asks: what data would the commander need for a live session command center?

| Needed Data | In DB? | Gap |
|-------------|--------|-----|
| Delegates launched | YES (delegation_log table) | But no hook WRITES to it. Table exists, always empty. |
| Delegation prompts used | PARTIAL (prompt_summary column) | Same -- exists but never populated |
| Delegate status | YES (delegation_log.status) | Same gap |
| Delegate work product | NO | No `artifacts` table for files produced |
| Session schwerpunkt | YES (session.schwerpunkt) | Written as "unspecified" by current hook |
| SITREPs from delegates | YES (messages table) | 59 messages exist from Stop hook |
| Real-time mission progress | NO | No heartbeat/progress column |
| Token usage per delegate | YES (delegation_log.token_usage) | Never populated |
| Duration per delegate | YES (delegation_log.duration_ms) | Never populated |

**Root cause**: The schema is designed for the data. The write-side hooks don't exist yet. The dashboard extension (read-side) and the hook migration (write-side) are independent work streams. Extending the dashboard to read from the DB is valuable NOW because:
1. It establishes the read path
2. It shows what data IS available (messages, session metadata)
3. It creates visible demand for the write-side hooks -- when the dashboard shows "0 missions" the commander knows the write hooks are missing

---

## Finding 5: Data in the Session DB That the JSON Dashboard Doesn't Show

The current running estimate JSON (`/Users/pepe/repos/aitools/.aitools/channel/running-estimate.json`) is from session `RnTOD5XJFi` -- a PRIOR session dated 2026-03-24. It does NOT reflect the current session at all.

The current session DB has 59 messages that the current dashboard cannot show because:
1. The running estimate JSON is stale (prior session)
2. The dashboard only reads JSON, not SQLite
3. `sitreps` are exported by `export_session_to_dict()` but the dashboard's `renderDashboard()` JS has no sitrep rendering section

This is exactly the problem the commander identified: "I want to see THIS session dynamically." The JSON dashboard shows stale data from prior sessions. A DB-backed dashboard reads real-time data from the current session's DB.

---

## Finding 6: Prior Sessions' Discussion of This Topic

### Proposal 3C from mission-control-proposals.md (session RnTOD5XJFi)

From `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-control-proposals.md` (lines 358-372):

> **Proposal 3C: Mission Control Dashboard as Harness DB View**
> Post-SQLite, `generate-dashboard.py` gains a `--db` mode:
> `python3 scripts/generate-dashboard.py --db .aitools/harness.db --serve --port 8420`
> The dashboard reads the harness DB's session index, lists all active sessions, and renders the multi-mission view from the `missions` table across all session DBs.

This was categorized as Phase 3 (post-SQLite) with dependency on Phase 2 (hook migration). Priority 9 of 9.

### SQLite Architecture RFC (session RnTOD5XJFi)

The RFC at `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/rfc-sqlite-harness-architecture.md` explicitly designed the session DB schema to be dashboard-compatible. The `export_session_to_dict()` function in `harness-db.py` was built to produce the exact JSON the dashboard expects.

### Current session's own analysis

From the current session's assistant responses (line 338): "The SQLite architecture RFC already designed this. The session DB has tables for everything the running estimate holds ... The `harness-db.py export --format json` command exists ... The dashboard already has a `/api/estimate` endpoint that could read from the DB instead of a JSON file."

---

## Finding 7: The dashboard_state Table in Harness DB

The harness DB schema already includes a `dashboard_state` table (schema line 212):

```sql
CREATE TABLE IF NOT EXISTS dashboard_state (
    port INTEGER PRIMARY KEY,
    session_id TEXT NOT NULL,
    pid INTEGER,
    db_path TEXT,
    started_at TEXT NOT NULL,
    last_checked TEXT
);
```

This was designed to track which dashboards are running on which ports, serving which session DBs. It's empty but ready for the `--db` mode.

---

## Architecture Recommendation

### Extend generate-dashboard.py, don't create a separate tool.

**Evidence supporting "extend":**

1. **Same rendering engine**: The HTML template and JS `renderDashboard()` function work on the same JSON shape regardless of source. The DB extension only changes the data acquisition layer.

2. **Same server architecture**: The `HTTPServer` + `DashboardHandler` + poll pattern works identically for DB reads. Replace file mtime polling with DB `updated_at` column polling.

3. **Export bridge exists**: `export_session_to_dict()` already produces dashboard-compatible JSON from the DB. The `/api/estimate` handler can call this function instead of reading a file.

4. **Multi-mission pattern transfers**: The `--multi-dir` mode already aggregates multiple estimates. A `--db` mode that reads all session DBs from the harness index follows the same pattern.

5. **Lifecycle manager already dispatches**: `aitools-dashboard.sh` already finds the estimate, starts the generator, manages PIDs. Adding `--db` requires minimal changes to the shell dispatcher.

**Evidence against "separate tool":**

1. Two separate dashboards with the same design language creates maintenance burden
2. The CSS/JS template is 660+ lines -- duplicating it is not justified
3. The `aitools dashboard` command would need to know which tool to invoke
4. Users would need to learn two interfaces for the same visual

---

## Minimum Viable Extension Spec

### Phase 1: DB-backed single-session dashboard (ships NOW)

**Changes to `generate-dashboard.py`:**

1. Add `--db <path>` argument (mutually exclusive with `--estimate`)
2. Import `sqlite3` and reuse `open_db()` pattern from `harness-db.py`
3. In `DashboardHandler.do_GET()` for `/api/estimate`:
   - If `--db` mode: call `export_session_to_dict()` on the DB, return JSON
   - If `--estimate` mode: read file (current behavior)
4. In `watch_and_regenerate()`:
   - If `--db` mode: poll `session.updated_at` column instead of file mtime
   - Regenerate HTML when `updated_at` changes
5. Add sitrep rendering to `renderDashboard()` JS (the DB exports sitreps, the current JSON dashboard doesn't render them)

**Changes to `harness-db.py`:**

1. Fix field name alignment in `export_session_to_dict()`:
   - `delegationLog[].agentType` -> also expose as `type`
   - `delegationLog[].agentName` -> also expose as `id`
   - `delegationLog[].missionId` -> also expose as `mission` (use description field for mission text)
   - Or: expose both conventions with fallback in JS

**Changes to `aitools-dashboard.sh`:**

1. Auto-detect: if session DB exists for active session, prefer `--db` mode
2. Add `--db` flag passthrough

**Effort estimate**: 80-120 lines of Python for the DB handler path, 20-30 lines of JS for sitrep rendering, 10-20 lines of shell for dispatcher changes.

### Phase 2: DB-backed multi-session dashboard (ships with hook migration)

**Depends on**: Write-side hooks populating `missions`, `delegation_log`, `decisions` tables

1. `--db` mode with harness DB: read `session_index`, attach each session DB, aggregate
2. Multi-session view: one row per active session with live stats
3. Drill-down: click a session row to see its full dashboard
4. Register in `dashboard_state` table

### Phase 3: Full command center (ships with artifact tracking)

**Depends on**: `artifacts` table in session DB (not yet in schema)

1. Work product inventory panel: files produced by each delegate
2. Token/duration metrics per delegation
3. Real-time delegation launch/complete events
4. Session timeline view

---

## What Schema Changes Are Needed

### For Phase 1: None

The schema already has everything needed. The gap is on the write side (hooks), not the read side (schema).

### For Phase 3: One new table

```sql
CREATE TABLE IF NOT EXISTS artifacts (
    artifact_id INTEGER PRIMARY KEY AUTOINCREMENT,
    mission_id TEXT REFERENCES missions(mission_id),
    file_path TEXT NOT NULL,
    file_type TEXT,          -- py, sh, md, json, html
    size_bytes INTEGER,
    created_at TEXT NOT NULL,
    agent_name TEXT
);
```

This was mentioned in the mission-control-proposals.md (Proposal 3B) but never added to the canonical schema.

---

## Operational Learning from This Investigation

### OL-1: The read-write asymmetry is the key insight

The session DB schema is well-designed. The export function works. The dashboard rendering engine works. The bottleneck is NOT "how do we show DB data in the dashboard?" -- it's "how do we get data INTO the DB during the session?" The dashboard extension (read side) is straightforward engineering. The hook migration (write side) is the hard problem.

### OL-2: SITREPs are the only live session data today

59 messages from the Stop hook are the ONLY structured data being written to the current session's DB. Everything else (missions, decisions, delegation log) is empty. This means a Phase 1 DB-backed dashboard would show: session metadata, schwerpunkt, and a sitrep feed. That's already more than the current state (stale JSON from a prior session) but less than the full command center vision.

### OL-3: The export bridge was designed for exactly this

`export_session_to_dict()` was written to produce dashboard-compatible JSON. The fact that it exists and maps every DB table to JSON keys means the DB extension is an import of one function + a handler change. The prior session's S3-November designed the schema and export with dashboard consumption in mind.

### OL-4: Field name normalization is the only friction point

The running estimate JSON (which the dashboard was built against) uses field names like `delegationLog[].type`, `delegationLog[].id`, `delegationLog[].mission`. The DB export uses `delegationLog[].agentType`, `delegationLog[].agentName`, `delegationLog[].missionId`. The JS `renderDashboard()` reads the JSON conventions. Either normalize in the export function or add fallbacks in JS. Export normalization is cleaner.

### OL-5: The multi-dir mode proves the architecture handles multiple data sources

`--multi-dir` mode was added after the initial single-estimate mode. It uses a different handler (`MultiDashboardHandler`), different API endpoint (`/api/missions`), and different HTML template (`MULTI_HTML_TEMPLATE`). Adding `--db` follows this same extension pattern. The codebase is structured for data source polymorphism.

---

## Cross-References

| Artifact | Location |
|----------|----------|
| Dashboard generator | `/Users/pepe/repos/aitools/scripts/generate-dashboard.py` |
| Harness DB CLI | `/Users/pepe/repos/aitools/scripts/harness-db.py` |
| Dashboard lifecycle manager | `/Users/pepe/repos/aitools/scripts/aitools-dashboard.sh` |
| Session DB schema | `/Users/pepe/repos/aitools/reference/harness-db-schema.sql` |
| SQLite architecture RFC | `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/rfc-sqlite-harness-architecture.md` |
| Mission control proposals | `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-control-proposals.md` |
| Current running estimate (stale) | `/Users/pepe/repos/aitools/.aitools/channel/running-estimate.json` |
| Consolidated OL | `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` |
