---
name: mission-control
description: "Monitor running missions -- process health, activity,
  work products, deliverable validation. Use when launching competing
  missions, checking mission progress, assessing mission health, or
  deciding whether to FRAGORD a mission. Codifies the 7 ad-hoc
  monitoring patterns that worked in multi-mission operations."
---

## Intent

**Purpose**: Provide structured monitoring for concurrent autonomous
missions -- process health, activity tracking, work product inventory,
deliverable validation, and dashboard health. Codifies the ad-hoc
shell commands that provided actual visibility when dashboards showed
zeros. **Scope**: Monitoring and assessment only. NOT mission
launching (that is the delegating agent's responsibility). NOT
dashboard rendering (see `generate-dashboard.py`). NOT session
lifecycle (see `/scratch` and `/handoff` skills). NOT the running
estimate schema (see the template at
`.aitools/templates/mission-running-estimate.json`). **Audience**:
Any agent operating as a commander over concurrent missions, or any
agent maintaining its own running estimate.

## When to use

Invoke `/mission-control` when ANY of these conditions arise:

- User says `/mission-control` or asks about mission status
- Launching concurrent missions (pre-flight verification)
- Checking whether a running mission is active or stalled
- Assessing mission health across multiple instances
- Deciding whether to FRAGORD (fragmentary order) a mission
- Validating a mission's deliverable after completion
- Setting up a running estimate for a new mission
- User asks about dashboard ports, processes, or health

## The 7 monitoring commands

These commands are the empirically-validated monitoring stack. They
were the ACTUAL monitoring that worked when dashboards showed zeros
during a 3-mission operation (Alpha/Bravo/Charlie, 2026-03-24).

### Layer 1: Infrastructure health (pre-flight)

**Pattern 1: Process discovery**

```bash
ps aux | grep generate-dashboard
```

Reveals which dashboard server processes are running, their PIDs,
which port each is on, and which estimate file each reads. Also
reveals orphaned processes from prior sessions.

Use the dashboard wrapper for managed instances:

```bash
bash scripts/aitools-dashboard.sh --status
```

**Pattern 7: Dashboard health check**

```bash
bash scripts/aitools-dashboard.sh --health-check
```

Two-layer check: HTTP liveness (server responds with 200) AND data
quality (running estimate has all dashboard-expected fields). Exit
code 0 = healthy, 1 = unhealthy or no instances running.

For ad-hoc port checks when instances are not managed:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/
```

### Layer 2: Activity monitoring (continuous)

**Pattern 2: Last activity extraction**

```bash
tail -1 <transcript>.jsonl | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('type','?'), d.get('message',{}).get('content','')[:100]
      if isinstance(d.get('message',{}), dict) else '')
"
```

Shows the last thing each mission agent did -- its most recent tool
call, response, or assistant message. This is the real-time activity
indicator.

Transcript locations: `~/.claude/projects/<project-hash>/<uuid>.jsonl`

To find the most recent transcript for a project:

```bash
ls -t ~/.claude/projects/*/session-*.jsonl | head -5
```

**Pattern 3: Progress gauge**

```bash
wc -l <transcript>.jsonl
```

Rough proxy for how much work an agent has done. Higher line counts
indicate more conversation turns. Compare across missions to gauge
relative progress. A mission at 21K lines is deep into reading; one
at 3K lines may have finished quickly or stalled early.

### Layer 3: Work product inventory (periodic)

**Pattern 4: Work product inventory**

```bash
ls <scratch-dir>/
```

Lists what files each mission has produced. File names reveal the
approach: `pillar-governance.json` + `pillar-implementation.json`
indicates a generate-then-assemble strategy. `merge-final.py` +
`add-pillar2.py` indicates iterative assembly. This is richer than
any self-reported status.

**Pattern 5: Deliverable size and growth**

```bash
wc -c <output-file>
```

Deliverable size is a proxy for completeness. Poll periodically to
see growth rate -- a file growing steadily indicates active writing.
A file that stopped growing may indicate stall or completion.

### Layer 4: Deliverable validation (post-flight)

**Pattern 6: Deliverable validation**

```bash
python3 -c "
import json
with open('<output-file>') as f:
    d = json.load(f)
print(f'Size: {len(json.dumps(d))} chars')
print(f'Top keys: {list(d.keys())}')
for k in d:
    if isinstance(d[k], dict):
        print(f'  {k}: {list(d[k].keys())[:5]}')
    elif isinstance(d[k], list):
        print(f'  {k}: [{len(d[k])} items]')
"
```

Validates: (1) valid JSON, (2) expected top-level structure,
(3) non-empty sections. This is the acceptance test.

## Pre-flight verification protocol

Before launching concurrent missions, verify ALL of these:

1. **Port availability**: For each assigned port, confirm it is free:
   ```bash
   lsof -iTCP:<port> -sTCP:LISTEN
   ```
   Empty output = available. If occupied, either stop the occupant
   or reassign the port.

2. **Template compliance**: Each mission copies the running estimate
   template and fills in its identity:
   ```bash
   cp .aitools/templates/mission-running-estimate.json \
      <mission-scratch-dir>/running-estimate.json
   ```
   Then replace PLACEHOLDER values with mission-specific data.

3. **Dashboard data quality**: After the mission starts and writes
   its first estimate update, run the health check:
   ```bash
   bash scripts/aitools-dashboard.sh --health-check
   ```
   If unhealthy, fix the estimate before the mission proceeds with
   real work.

4. **Process isolation**: Each mission's scratch directory is clean
   (no leftover files from prior runs).

5. **Monitoring readiness**: The commander can access all dashboards:
   ```bash
   bash scripts/aitools-dashboard.sh --status
   ```

## Running estimate maintenance

### The template

The running estimate template at
`.aitools/templates/mission-running-estimate.json` contains ALL
fields that `generate-dashboard.py` expects. Missions MUST start
from this template so dashboards never show silent zeros.

### Behavioral update guidance

Agents should update their running estimate at each phase boundary.
This is a behavioral pattern, not a structural enforcement --
decision #35 established that UCIs are ineffective, and the
structural fix (hooks auto-writing) comes with SQLite migration.

Until then, the template + validation + health check create a
structural gate that catches failures early.

**Update pattern** (copy into mission code):

```python
import json

def update_running_estimate(path, phase_description, completed_item=None, delegation=None):
    """Update running estimate with current progress.

    Call at each phase boundary. The running estimate feeds the live
    dashboard -- stale data means the commander has no visibility.
    """
    with open(path) as f:
        est = json.load(f)

    # Update current state
    est['situation']['currentState'] = phase_description

    # Track completed work
    if completed_item:
        est['situation']['completedWork'].append(completed_item)

    # Track delegations
    if delegation:
        est['delegationLog'].append(delegation)

    # Bump version and timestamp
    est['meta']['version'] = est['meta'].get('version', 0) + 1
    from datetime import datetime, timezone
    est['meta']['updated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    with open(path, 'w') as f:
        json.dump(est, f, indent=2)
```

**Delegation log entry format** (matches dashboard expectations):

```python
{
    "id": "D1",
    "type": "s2",       # s2 | s3 | s1 | verifier
    "mission": "Audit project rules for coverage gaps",
    "status": "complete",  # running | complete | blocked | failed
    "agentType": "subagent",
    "dutyFulfilled": {
        "identity": True,
        "context": True,
        "output": True,
        "writeBlocked": True,
        "verify": True
    }
}
```

## Mission health assessment

Use these indicators to assess overall mission health:

| Indicator | Healthy | Warning | Critical |
|-----------|---------|---------|----------|
| Dashboard HTTP | 200 | -- | Non-200 or no response |
| Estimate fields | All present | -- | Missing fields (zeros) |
| Transcript growth | Growing | Flat 5+ min | Flat 15+ min |
| Work products | New files appearing | No new files 10+ min | No files at all |
| Deliverable size | Growing | Flat | Zero or missing |

### When to FRAGORD a mission

Issue a fragmentary order (course correction) when:

- Dashboard shows all zeros after 5+ minutes (schema mismatch)
- Transcript growth stopped but mission is not complete
- Mission is producing files but not the expected deliverable
- Mission took an incorrect architectural approach (visible from
  file names in work product inventory)
- Port conflict detected (mission on wrong port)

A FRAGORD is a targeted correction, not a restart. Inject a message
to the mission agent with the specific fix needed.

## Multi-mission dashboard

When operating multiple missions concurrently, use the multi-mission
view to see all missions in a single summary:

```bash
python3 scripts/generate-dashboard.py \
  --multi-dir <parent-dir> \
  --serve --port 8420
```

The `--multi-dir` flag scans the directory for
`*/running-estimate.json` files and renders a summary table showing
mission name, schwerpunkt, delegation count, and overall status.
Click through to individual mission dashboards for detail.

For static generation:

```bash
python3 scripts/generate-dashboard.py \
  --multi-dir <parent-dir> \
  --output multi-dashboard.html
```

## Finding mission transcripts

Claude Code stores transcripts at:
```
~/.claude/projects/<project-path-hash>/<session-uuid>.jsonl
```

To identify which transcript belongs to which mission:
1. Check file modification times against mission launch times
2. Read the first few lines of each transcript for the mission prompt
3. Check file sizes -- missions with more work have larger transcripts

## Cross-references

- Running estimate template: `.aitools/templates/mission-running-estimate.json`
- Dashboard generator: `scripts/generate-dashboard.py`
- Dashboard lifecycle: `scripts/aitools-dashboard.sh`
- Session scratch: `/scratch` skill
- Session handoff: `/handoff` skill
- Session planning: `/planning` skill
- Governed vocabulary: `/glossary` skill (terms: Schwerpunkt,
  Lagebeurteilung, Reibung, FRAGORD, running estimate)
- UCI ineffectiveness: Decision #35 (running estimate v9)
- Ad-hoc patterns source: `.scratch/session-RnTOD5XJFi/adhoc-monitoring-patterns.md`
- Gap analysis source: `.scratch/session-RnTOD5XJFi/mission-control-gap-analysis.md`
