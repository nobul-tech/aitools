# /incident-response expected behaviors

## Auto-trigger tests

Should auto-load when:
- Something went wrong (error, violation, failed deployment)
- User says "what happened?" or "why did this break?"
- User asks to write a postmortem or incident entry
- A recurring bug is identified

Should NOT auto-load for:
- Normal debugging (use tool-specific skills)
- Planned refactoring (that's /planning)
- Filing a gap (that's /gap — though incidents may produce gaps)

## Lifecycle coverage
- Should walk through all 8 phases when appropriate
- Should reference /rca for the investigation phase
- Should recommend corrective action TYPE based on recurrence

## Escalation
- First occurrence → behavioral coaching item
- 2nd occurrence → warn about recurrence pattern
- 3+ occurrences → recommend structural fix (hook/skill/rule)
