# Mission Control Data Flow Investigation

**Investigator**: Commander agent, session 2d439e32-3
**Date**: 2026-03-25
**Status**: Findings complete, deployment executed, pipeline designed

---

## Executive Summary

nobulai.tools was frozen on session c0dc2ddc-f data. The current session (2d439e32-3)
had 53 messages in its SQLite DB but was invisible on the public dashboard. Root cause:
no automated pipeline connects session DB writes to Vercel deployment.

**Actions taken this session:**
1. Ran `export-mission-control.py` against current session DB -- produced 41KB static HTML
2. Deployed to Vercel production via `vercel --yes --prod` -- nobulai.tools now shows session 2d439e32-3
3. Verified via chrome-devtools: sessionId=2d439e32-3, status=active, 53 messages, exported at 00:13:11Z

**The local dashboard on port 8411 is a zombie** -- process 4685 is listening but not responding
(curl returns exit code 28 / connection timeout). It was started by a prior session's SessionStart
hook and is serving stale running-estimate.json data from session c0dc2ddc-f.

---

## Current Architecture (as found)

```
Session hooks                 running-estimate.json           generate-dashboard.py
  (write sitreps  ---------> (JSON, git-tracked,     ------> (reads JSON, serves
   to SQLite DB)              exported at SessionEnd)          on port 8411)
                                    |
                                    v
                              [STALE: session c0dc2ddc-f data]

export-snapshot.py            session-snapshot.json            build.py
  (reads SQLite DB,  -------> (JSON snapshot)         -------> (embeds into HTML)
   produces JSON)                                                    |
                                                                     v
                                                              index.html --> vercel deploy
                                                                              --> nobulai.tools
```

### Two completely separate dashboards

| Dashboard | Data source | Rendering | Deployment |
|-----------|-------------|-----------|------------|
| Local (port 8411) | running-estimate.json | generate-dashboard.py (live server, polls file) | SessionStart hook |
| Public (nobulai.tools) | Session SQLite DB | export-mission-control.py (static HTML) | Manual `vercel deploy` |

These share NO code. The local dashboard reads JSON. The public dashboard reads SQLite.
The public dashboard was built in session c0dc2ddc-f as a one-off export tool.

---

## Finding 1: Why nobulai.tools Was Frozen

The pipeline from session c0dc2ddc-f was:
1. `export-snapshot.py` reads SQLite DB --> `session-snapshot.json`
2. `build.py` reads snapshot + HTML template --> `index.html`
3. `deploy.sh` orchestrates 1+2 and runs `vercel deploy`

This pipeline lived entirely in `.scratch/session-c0dc2ddc-f/mission-control-deploy/`.
No hook, no cron, no automation triggers it. Each deployment was a manual command
run by the agent during that session.

When session c0dc2ddc-f ended, nobody ran the pipeline again. The current session
created its own `export-mission-control.py` (a simplified single-file version that
combines export + HTML template) but had not deployed it until this investigation.

---

## Finding 2: Local Dashboard Is Zombie

- **Process**: PID 4685, Python, listening on localhost:8411
- **PID registry**: Empty (`~/.aitools/dashboard-pids/` has no .pid files)
- **Legacy PID file**: Not checked, but process predates current session
- **HTTP response**: Connection timeout (exit code 28) -- process is hung
- **Data source**: `running-estimate.json` which contains session c0dc2ddc-f data
  (meta.sessionId = "c0dc2ddc-f464-404d-a637-8103afda27af", endedAt set)

The process was started by the SessionStart hook of an earlier session. It's still
listening on the socket but not serving responses. This could be a Python HTTP server
that has exhausted file descriptors or hit a threading deadlock.

**The running-estimate.json itself is stale** -- it was exported by the SessionEnd hook
of session c0dc2ddc-f. The current session (2d439e32-3) never updated it because the
SessionEnd hook hasn't fired yet (session is still active).

---

## Finding 3: generate-dashboard.py Has No --db Flag

Confirmed by searching: no `--db`, no `sqlite`, no `.db` references anywhere in
`scripts/generate-dashboard.py`. The dashboard extension investigation from session
c0dc2ddc-f recommended adding `--db` as Phase 1 work. That work has not been done.

The `harness-db.py` export function (`export_session_to_dict()`) already produces
JSON compatible with the dashboard's `renderDashboard()` JS. The bridge exists but
is not connected.

---

## Finding 4: Two Export Scripts, Neither Automated

| Script | Location | Data flow |
|--------|----------|-----------|
| `export-snapshot.py` | `.scratch/session-c0dc2ddc-f/` | SQLite -> JSON snapshot |
| `export-mission-control.py` | `.scratch/session-2d439e32-3/` | SQLite -> static HTML (self-contained) |

The current session's `export-mission-control.py` is the better tool -- it combines
export and HTML generation in one script, has the full command center HTML template
embedded, and produces a deployable `index.html` directly. No intermediate JSON step.

---

## Finding 5: SessionEnd Hook Exports JSON, Not HTML

`shared/hooks/harness-db-sessionend.sh` runs:
```
harness-db.py session end --id $SESSION_ID
harness-db.py process-events --session $SESSION_ID
harness-db.py ship
harness-db.py export --format json --session $SESSION_ID
```

This exports to `running-estimate.json` (for git carry-forward and the local
JSON dashboard). It does NOT:
- Run `export-mission-control.py` to produce static HTML
- Run `vercel deploy` to update nobulai.tools
- Trigger any external service

---

## Proposed Automated Pipeline

### Option A: SessionEnd Hook Extension (Simplest)

Add to `harness-db-sessionend.sh`:
```bash
# After JSON export, also export static HTML and deploy to Vercel
EXPORT_MC="$PROJECT_ROOT/.scratch/session-*/export-mission-control.py"
# or better: promote to scripts/export-mission-control.py

"$PYTHON" "$PROJECT_ROOT/scripts/export-mission-control.py" \
    --db "$PROJECT_ROOT/.aitools/sessions/${SESSION_ID}.db" \
    --out "$PROJECT_ROOT/.scratch/mc-deploy/"

if command -v vercel >/dev/null 2>&1; then
    vercel "$PROJECT_ROOT/.scratch/mc-deploy/" --yes --prod >/dev/null 2>&1 || true
fi
```

**Pros**: Simple, runs automatically, uses existing infrastructure
**Cons**: Only updates at session end (not during session), requires vercel CLI auth,
adds 5-10s to session shutdown

### Option B: Periodic Refresh During Session (Best for live updates)

A background process (started at SessionStart) that:
1. Polls the session SQLite DB every 30-60 seconds
2. If `updated_at` changed, runs export-mission-control.py
3. Deploys to Vercel (or Cloudflare Pages)

This could be:
- A cron-like loop in a background script
- A Python daemon alongside the dashboard server
- An extension to generate-dashboard.py's `--serve` mode (add `--deploy-vercel` flag)

**Pros**: Near-real-time updates during active sessions
**Cons**: Continuous Vercel deployments (rate limits?), more complexity

### Option C: Hybrid (Recommended)

1. **SessionStart**: Kill zombie dashboard, start fresh with `--db` mode (requires implementing the --db flag in generate-dashboard.py)
2. **During session**: Local dashboard reads SQLite directly (no JSON intermediary)
3. **Periodic (every 5 min)**: Background process exports and deploys to Vercel
4. **SessionEnd**: Final export + deploy + JSON archive for git carry-forward

This separates concerns:
- Local dashboard = real-time, reads SQLite directly
- Public dashboard = near-real-time, static HTML on Vercel
- Archive = JSON in git, updated at session end

### Implementation Priority

| Step | What | Effort | Impact |
|------|------|--------|--------|
| 1. Promote export-mission-control.py to scripts/ | Move from scratch, make it a first-class tool | 30 min | Enables everything else |
| 2. Add deploy-to-vercel.sh | Wrapper: export + vercel deploy | 15 min | One-command refresh |
| 3. Add to SessionEnd hook | Auto-deploy at session end | 10 min | No more frozen dashboards |
| 4. Background refresh daemon | Periodic re-export + deploy during session | 2-4 hrs | Near-real-time public dashboard |
| 5. Add --db to generate-dashboard.py | Local dashboard reads SQLite directly | 2-4 hrs | Eliminates JSON intermediary for local |

---

## Finding 6: Vercel Setup Details

- **Project**: nobul/mission-control-deploy
- **Project ID**: prj_YCZBY1wSiHzH1r0cmNNct1Csr3yv
- **Org**: team_VaiHNEeMZE3FPBzYoVvgPdk0
- **Custom domain**: nobulai.tools (configured 6h ago)
- **Auth**: nobul-jose (verified working)
- **Deploy time**: ~3-7 seconds (static HTML, no build step)
- **Rate**: At least 9 deployments in the last 7 hours (no rate limiting observed)

The `.vercel/project.json` exists in both the old deploy dir and the current session's
dist/, pointing to the same project. Deploying from either location hits the same
Vercel project.

---

## Finding 7: Data Available in Current Session DB

Session `2d439e32-3` has:
- 53 messages (21 findings, 32 sitreps)
- 0 missions, 0 delegations, 0 decisions, 0 observations
- Session metadata (started at 22:58:10Z, platform darwin, no schwerpunkt)

The zero counts for missions/delegations/decisions confirm the prior investigation's
OL-2: the write-side hooks for those tables don't exist yet. The only structured data
being written is messages (from the Stop hook's surfacing duty).

---

## Immediate Actions Completed

1. Exported current session DB to static HTML: `export-mission-control.py --db 2d439e32-3.db --out dist/`
2. Deployed to Vercel production: `vercel dist/ --yes --prod`
3. Verified at nobulai.tools via chrome-devtools: session 2d439e32-3, ACTIVE, 53 messages
4. Screenshot saved: `nobulai-tools-current-session.png`

---

## Key Architectural Decisions (for commander review)

1. **export-mission-control.py should be promoted to scripts/** -- it's the best
   current tool for the SQLite->static HTML pipeline. The older export-snapshot.py +
   build.py two-step is more complex for no benefit.

2. **The local dashboard needs the --db flag** -- this is the highest-impact
   improvement. Without it, the local dashboard depends on running-estimate.json
   which is only updated at session end. With --db, it reads the live SQLite DB.

3. **SessionEnd hook should auto-deploy to Vercel** -- 3 lines of bash in the
   existing hook eliminates the "frozen dashboard" problem entirely.

4. **The zombie dashboard process should be killed and restarted** -- PID 4685 on
   port 8411 is hung. The SessionStart hook should detect and kill unresponsive
   instances (health check before re-use).

5. **Long-term: Cloudflare relay replaces Vercel** -- Vercel is the stopgap.
   The Cloudflare relay pattern (already mentioned in architecture docs) would
   allow real-time updates without redeployment.
