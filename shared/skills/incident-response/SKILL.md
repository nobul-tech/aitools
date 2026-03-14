---
name: incident-response
description: "Full incident lifecycle from detection through follow-up. Use when something went wrong — a rule was violated, a deployment failed, a bug recurred, or a process broke down. Covers triage, investigation, remediation, corrective actions, and verification."
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

Use the `/rca` skill for deep investigation. Quick assessment:
- What happened? (timeline)
- What was the immediate cause?
- What were the contributing factors? (Swiss cheese model — multiple
  layers had to fail for the incident to occur)
- Has this happened before? (check effectiveness tracker)

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

## Near-Miss Reporting

Things that almost went wrong but were caught:
- Hook observed a pattern but didn't block (observe mode)
- Code review caught an issue before commit
- User noticed something odd and asked about it

Near-misses are valuable signals. They don't need the full lifecycle,
but logging them in the session helps `/audit` identify trends.
