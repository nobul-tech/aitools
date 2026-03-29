# Tool-Ops Verification Report

**Mission Commander**: tool-ops-verify (executed by assessment-lead)
**Session**: 8236ca9c | **Date**: 2026-03-26

---

## Hook Verification Summary

### Deployed Hooks: 12 of 15 registered, all matching source

| Hook | Event | Matcher | Deployed? | Registered? | Source Match? | Mock Test |
|------|-------|---------|-----------|-------------|---------------|-----------|
| standing-order-guard.sh | PreToolUse | Bash | YES | YES | MATCH | PASS (exit 0 clean, exit 2 violation) |
| glossary-skill-guard.sh | PreToolUse | Read\|Grep | YES | YES | MATCH | PASS (exit 0) |
| block-claude-code-guide.sh | PreToolUse | Agent | YES | YES | MATCH | PASS (deny JSON on guide, exit 0 on normal) |
| delegation-duty-guard.sh | PreToolUse | Agent | YES | YES | MATCH | NOT TESTED (requires Agent context) |
| sh-file-fixup.sh | PostToolUse | Write\|Edit | YES | YES | MATCH | NOT TESTED (requires file context) |
| scratch-init.sh | SessionStart | "" | YES | YES | MATCH | N/A (lifecycle hook) |
| dashboard-serve.sh | SessionStart | "" | YES | YES | MATCH | N/A (lifecycle hook) |
| harness-db-sessionstart.sh | SessionStart | "" | YES | YES | MATCH | N/A (lifecycle hook) |
| session-archive.sh | SessionEnd | "" | YES | YES | MATCH | N/A (lifecycle hook) |
| harvest-session.sh | SessionEnd | "" | YES | YES | MATCH | N/A (lifecycle hook) |
| tool-ops-session-audit.sh | SessionEnd | "" | YES | YES | MATCH | N/A (lifecycle hook) |
| harness-db-sessionend.sh | SessionEnd | "" | YES | YES | MATCH | N/A (lifecycle hook) |

### Unregistered Hooks: 3 Stop hooks

| Hook | Event | Source Exists? | Deployed? | Registered? | Status |
|------|-------|---------------|-----------|-------------|--------|
| command-channel-stop.sh | Stop | YES (Mar 25) | NO | NO | F-1 HIGH from handoff |
| failure-mode-identity-stop.sh | Stop | YES (Mar 26) | NO | NO | Written this session |
| failure-mode-verify-stop.sh | Stop | YES (Mar 26) | NO | NO | Written this session |

**Critical finding**: ZERO Stop hooks are deployed or registered. The Stop event key does not exist in settings.json at all.

---

## Deny Rules Verification

### Expected (from tool-ops.json)

| Rule ID | Pattern | Hook | Status |
|---------|---------|------|--------|
| cc-deny-guide-subagent | Agent(claude-code-guide) | block-claude-code-guide.sh | PRESENT in settings.json |

### Actual (from settings.json permissions.deny)

```
"deny": [
    "MCP(vercel)",
    "MCP(webflow)",
    "Agent(claude-code-guide)"
]
```

**Result**: The deny rule from tool-ops.json is correctly deployed. The two MCP denies (vercel, webflow) are also present -- these are documented in CLAUDE.md as disabled-by-default MCP servers.

**No missing deny rules. No extra deny rules relative to documented expectations.**

---

## Governance Modes

From tool-ops.json, all Claude Code governance modes are set to "audit":

| Category | Mode | What This Means |
|----------|------|----------------|
| denyRules | audit | Rules exist and fire but we audit effectiveness, don't assume |
| hooks | audit | Hooks exist and fire but we audit coverage, don't assume |
| contextInjection | audit | Context injection patterns documented, effectiveness audited |
| kpis | audit | KPI collection exists but completeness audited |
| versionDeps | audit | Version dependencies documented but staleness audited |
| verifications | audit | Test cases exist but execution frequency audited |

**Observation**: All modes are "audit" -- none have been promoted to "active." This is consistent with the harness being in early operation. The tool-ops.json was last updated 2026-03-15.

---

## KPI Pipeline Verification

### events.jsonl (current session)

File: `/Users/pepe/repos/aitools/.scratch/session-8236ca9c-b/events.jsonl`
- 29 events recorded this session
- Event types: hook_fire (sog), hook_block (sog), delegation (ddg), identity_stop (fmi), verify_stop (fmv), fixup
- Sources: sog (standing-order-guard), ddg (delegation-duty-guard), fmi (failure-mode-identity), fmv (failure-mode-verify), fixup (sh-file-fixup)
- Format: valid JSONL with UTC timestamps

**Observation**: The failure-mode hooks (fmi, fmv) have events from smoke testing (19:10Z) even though they are not registered in settings.json. This is because they were manually tested via pipe, not fired by CC.

### harness.db

**NOT empty** (contradicts handoff F-2).
- File size: 98304 bytes
- Tables: 9 (session_index, kpi_events, kpi_ship_log, dashboard_state, schema_version, knowledge_items, provenance_edges, nogood_sets, sqlite_sequence)
- Content: 4 sessions indexed, 30 KPI events, 5 knowledge items, 2 provenance edges, 1 nogood set

### Session DB events table

Current session (8236ca9c-b.db): events table exists but has 0 rows.
Phantom session (d3dae79d-9.db): events table exists but has 0 rows.

**Pipeline gap**: JSONL events go to .scratch/session-*/events.jsonl (file). The SQLite events table exists in the schema but nothing writes to it. The pipeline is designed for JSONL-first with batch import to harness.db at session end (via harness-db-sessionend.sh). The session DB events table appears to be unused.

### harness-db.py status output

```
Session databases (5):
  2d439e32-3.db: ended, 65 messages
  8236ca9c-b.db: active, 0 messages
  c0dc2ddc-f.db: ended, 200 messages
  d3dae79d-9.db: ended, 0 messages
  harness.db: ERROR: attempt to write a readonly database
```

**Observation**: harness.db reports "attempt to write a readonly database" during status check. This may be a WAL-mode locking issue or a permissions issue.

---

## Source vs Deployed Drift

**All 12 deployed hooks match source exactly.** Zero drift detected.

This was verified by running `diff` between each `shared/hooks/<name>.sh` and `~/.claude/hooks/<name>.sh`. All 12 comparisons returned no output (identical files).

---

## Mock Test Results

### standing-order-guard.sh

| Input | Expected | Actual | Result |
|-------|----------|--------|--------|
| `git status` (clean) | exit 0 | exit 0 | PASS |
| `git status \|\| git log` (violation) | exit 2 (enforce mode) | exit 2 | PASS |

**OL-47 CONFIRMED**: The `||` check is in enforce mode in the code (`MODE_OR="enforce"` promoted 2026-03-24) but the hook-rollout.md rule still says it is `observe` under `MODE_REST`. The rule is stale. Same for `;` and backticks.

### block-claude-code-guide.sh

| Input | Expected | Actual | Result |
|-------|----------|--------|--------|
| `claude-code-guide` subagent | deny JSON | deny JSON with detailed reason | PASS |
| `Explore` subagent | exit 0, no output | exit 0, no output | PASS |

The deny JSON includes corrective context: chrome-devtools alternatives, hook type schemas, and the incident reference (#34730).

---

## Verification Cases from tool-ops.json

tool-ops.json defines 2 mock-json-pipe test cases for block-claude-code-guide.sh:

| Case | Input | Expected Exit | Expected Stdout | Actual | Result |
|------|-------|--------------|-----------------|--------|--------|
| 1 | guide subagent | 0 | permissionDecision.*deny | exit 0, deny JSON | PASS |
| 2 | Explore subagent | 0 | null (no output) | exit 0, no output | PASS |

**tool-ops.json verification cases work as specified.**

---

## Items Requiring Action

### CRITICAL
1. **Register 3 Stop hooks** -- command-channel-stop.sh, failure-mode-identity-stop.sh, failure-mode-verify-stop.sh. Requires changes to build-deploy.sh, setup-user-hooks.sh, setup-user-hooks.ps1. Per PSO plan-execution, this is a 3+ file change requiring sub-agent execution pattern.

### HIGH
2. **Update hook-rollout.md** -- the enforcement state table is stale. ||, ;, and backticks are enforce, not observe. Their MODE variables are MODE_OR, MODE_SEMICOLON, MODE_BACKTICK, not MODE_REST. This is a protected file change.

### MEDIUM
3. **harness.db readonly error** -- the status command reports write errors. Investigate WAL mode or permissions.
4. **Phantom session cleanup** -- end d3dae79d-9, decide on 21 orphaned entries.
5. **tool-ops.json staleness** -- last updated 2026-03-15 (11 days). Only documents 1 tool (claude-code) with 1 deny rule and 1 hook. The actual deployed state has 12 hooks and 3 deny rules. The registry is severely incomplete.

### LOW
6. **11 .bak files** in ~/.claude/hooks/ growing unbounded.
7. **Session DB events table** unused -- clarify design intent (JSONL-only or JSONL+SQLite).
