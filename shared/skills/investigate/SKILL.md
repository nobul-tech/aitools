---
name: investigate
description: "Investigate when something went wrong. Use when a rule was violated, a deployment failed, a bug recurred, or a process broke down. Covers the full lifecycle: triage, RCA (5 Whys, Swiss cheese model), remediation, corrective actions, barrier analysis, and verification."
---

## Purpose

Structured response to incidents — things that went wrong or almost went
wrong. Covers the full lifecycle so findings become durable improvements,
not just one-time fixes.

If the same type of incident recurs after a corrective action, the
corrective action was wrong — not the person. Structural fixes (hooks,
skills, rules) prevent recurrence. Behavioral coaching alone doesn't.

## Incident Lifecycle

### 1. Detection

How the incident was found:
- Hook blocked a violation (standing-order-guard)
- User reported unexpected behavior
- `/audit` skill found an inconsistency
- Check script flagged a failure
- Code review caught an issue
- Near-miss: something almost went wrong but was caught

### 2. Triage

Assess severity and blast radius:
- **Critical**: deployment broken, data loss, security exposure
- **High**: silent wrong behavior, propagated to other machines
- **Medium**: wrong but contained, no user impact
- **Low**: cosmetic, style, cleanup

Does this need immediate mitigation? If so, fix first, investigate after.

### 3. Investigation (RCA)

#### 5 Whys

Ask "why" iteratively until you reach a systemic cause:

1. Why did the deploy fail? → The hook script had a syntax error.
2. Why wasn't the syntax error caught? → No pre-deploy validation ran.
3. Why didn't pre-deploy validation run? → The checklist step was skipped.
4. Why was it skipped? → The commit was rushed after a long session.
5. Why was the session long enough to cause rushing? → No session budget
   convention existed.

The fix isn't "be more careful" (Why 1). The fix is the session budget
convention (Why 5).

#### Contributing factors (Swiss cheese model)

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

#### Timeline reconstruction

For complex incidents, build a timeline:

```
T-30m: Session started, plan loaded
T-20m: Batch 1 completed, tests passed
T-10m: Batch 2 started, scope expanded mid-batch
T-5m:  Error-handling rule violated (not noticed)
T-0:   Committed without running check scripts
T+5m:  User reported broken behavior
```

#### Common root cause categories

| Category | Example | Typical fix |
|----------|---------|-------------|
| **Rule fade** | Rule in context but ignored after 2 hours | Smaller batches, verification between |
| **Missing enforcement** | Rule exists but no hook blocks violations | Promote from rule to hook |
| **Scope creep** | Plan expanded mid-session, new code untested | Session budget, batch discipline |
| **Assumption** | "Probably X" without verification | File as gap, ask the user |
| **Tool gap** | No skill for the tool being used | Build the skill |
| **Stale spec** | Rule references deleted file or old behavior | `/audit` detects, file as gap |

#### RCA output format

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

### 4. Remediation

Fix the immediate issue. This is the "make it work now" step.

### 5. Corrective Action

Prevent recurrence. Choose the right type:

| Type | When | Example | Durability |
|------|------|---------|------------|
| **Behavioral** (coaching item) | First occurrence, low severity | "Remember to run check scripts" | Low — fades over time |
| **Structural** (new rule/hook/skill) | Recurrence, or high severity | Hook blocks the bad pattern | High — enforced automatically |
| **Environmental** (tool/config change) | Systemic issue | Permission pre-approval, PATH fix | High — removes the trigger |

**Rule of thumb**: If a coaching item exists and the incident recurred,
escalate to structural. Behavioral fixes that don't hold are not fixes.

### 6. Verification

After implementing the corrective action:
- Can you reproduce the original incident? It should now be blocked/caught.
- Run the scenario that triggered the incident — verify the fix works.
- If structural: verify the hook/skill/rule fires correctly.

### 7. Dissemination

Record the incident so others (and future sessions) learn from it:
- **Effectiveness tracker**: Add incident entry (I-number, description,
  RCA, remediation, corrective action)
- **Coaching item**: If behavioral, add to CLAUDE.md coaching section
- **Gap filing**: If a spec deviation, file via `/gap`
- **Rule/hook update**: If structural, commit the change

### 8. Follow-up

Check that the corrective action holds:
- In the next 3 sessions: did the same incident type recur?
- `/audit` skill checks: are coaching items with 3+ recurrences flagged?
- If the corrective action didn't hold: escalate (behavioral → structural)

## Incident Entry Format

For the effectiveness tracker:

```
### I<N>: <Short title> (<date>)

**What happened**: <description>
**RCA**: <root cause + contributing factors>
**Remediation**: <what was fixed immediately>
**Corrective action**: <behavioral|structural|environmental> — <what was done>
**Recurrence**: <first occurrence | Nth recurrence of I<M>>
**Status**: <open | verified | recurring>
```

## Evaluating Corrective Actions (Barrier Analysis)

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

### Three-layer check

When analyzing a failure, check all three governance layers:

- **Prevention**: Was there a rule with a trigger directive? Did the
  agent have it in context? Was the directive clear and imperative?
- **Detection**: Was there a hook that should have caught the bypass?
  Did it fire? If not, why not?
- **Audit**: Would `/audit` have flagged this as a gap? If not, what
  check is missing?

A failure that passes through all three layers reveals a systemic gap.
A failure caught by detection but not prevention reveals a rule gap.
A failure only caught by audit reveals both rule and detection gaps.

## Escalation

- Same root cause category 3+ times → structural fix required
- Contributing factor is "missing hook" → build the hook
- Contributing factor is "missing skill" → build the skill
- Fix didn't hold after verification → wrong fix, re-investigate

## Near-Miss Reporting

Things that almost went wrong but were caught:
- Hook observed a pattern but didn't block (observe mode)
- Code review caught an issue before commit
- User noticed something odd and asked about it

Near-misses are valuable signals. They don't need the full lifecycle,
but logging them in the session helps `/audit` identify trends.

## Cross-References

- Framework: `@reference/framework-incident-investigation.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Gap filing: `.claude/skills/gap/SKILL.md`
