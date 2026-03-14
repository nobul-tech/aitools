---
name: rca
description: "Root cause analysis for investigating incidents. Use when asking 'why did this happen?' — applies 5 Whys, contributing factors analysis, and Swiss cheese model. Subset of /incident-response focused on the investigation phase."
---

## Purpose

Investigate WHY something went wrong. This is the investigation phase
of the `/incident-response` lifecycle, broken out for when you need
just the analysis, not the full lifecycle.

## Techniques

### 5 Whys

Ask "why" iteratively until you reach a systemic cause:

1. Why did the deploy fail? → The hook script had a syntax error.
2. Why wasn't the syntax error caught? → No pre-deploy validation ran.
3. Why didn't pre-deploy validation run? → The checklist step was skipped.
4. Why was it skipped? → The commit was rushed after a long session.
5. Why was the session long enough to cause rushing? → No session budget
   convention existed.

The fix isn't "be more careful" (Why 1). The fix is the session budget
convention (Why 5).

### Contributing factors (Swiss cheese model)

Incidents rarely have a single root cause. Multiple layers of defense
had to fail:

```
Layer 1 (Prevention): Rule existed but was ignored (rule fade)
Layer 2 (Detection): Hook was in observe mode, not enforce
Layer 3 (Audit): Check script wasn't run before commit
Layer 4 (Review): User didn't spot the issue in the diff
```

Fix: strengthen the weakest layer, don't just add another rule to
Layer 1.

### Timeline reconstruction

For complex incidents, build a timeline:

```
T-30m: Session started, plan loaded
T-20m: Batch 1 completed, tests passed
T-10m: Batch 2 started, scope expanded mid-batch
T-5m:  Error-handling rule violated (not noticed)
T-0:   Committed without running check scripts
T+5m:  User reported broken behavior
```

The timeline often reveals where attention shifted and why the
violation wasn't caught.

## Common root cause categories

| Category | Example | Typical fix |
|----------|---------|-------------|
| **Rule fade** | Rule in context but ignored after 2 hours | Smaller batches, verification between |
| **Missing enforcement** | Rule exists but no hook blocks violations | Promote from rule to hook |
| **Scope creep** | Plan expanded mid-session, new code untested | Session budget, batch discipline |
| **Assumption** | "Probably X" without verification | File as gap, ask the user |
| **Tool gap** | No skill for the tool being used | Build the skill |
| **Stale spec** | Rule references deleted file or old behavior | `/audit` detects, file as gap |

## Output format

```markdown
### RCA: <incident title>

**Immediate cause**: <what directly failed>
**Contributing factors**:
1. <factor> (layer: prevention|detection|audit)
2. <factor> (layer: ...)

**Root cause**: <systemic issue at the deepest why>

**Recommended corrective action**:
- Type: behavioral | structural | environmental
- Action: <specific change>
- Verification: <how to confirm the fix works>

**Recurrence risk**: low | medium | high
```

## Evaluating corrective actions (barrier analysis)

Before recommending a fix, test it against the incident that motivated it:

1. **Replay** the timeline with the proposed fix in place
2. **At each decision point**: would the fix have changed the outcome?
3. **If yes** → fix addresses this failure mode. Ship it.
4. **If no** → fix addresses a different class of failure. Ask:
   - Is it still valuable for that other class? (Keep, but don't claim
     it fixes THIS incident)
   - Does the actual failure mode need a different fix type?
     (Information problem → hook. Reasoning problem → skill/coaching.
     Process problem → rule/checklist.)
5. **Document coverage**: "This hook prevents X-class failures.
   It does NOT prevent Y-class failures (reasoning/connection)."

No single mechanism is definitive. The three-layer model acknowledges
this — each layer catches what the previous missed. Evaluate proposed
fixes honestly, don't overclaim.

## When to escalate

- Same root cause category 3+ times → structural fix required
- Contributing factor is "missing hook" → build the hook
- Contributing factor is "missing skill" → build the skill
- Fix didn't hold after verification → wrong fix, re-investigate
