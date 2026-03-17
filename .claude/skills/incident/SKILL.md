---
name: incident
description: "File an incident in incidents.json. Use when a spec deviation, broken cross-reference, ambiguity, or operational failure is found that should be tracked. Also use when the user says /incident or asks to file an incident."
---

## Intent

**Purpose**: File harness deficiencies into `reference/incidents.json`
with structured fields, severity classification, and root cause
tracking — the operational tool for the surfacing duty. **Scope**:
Filing process, classification, and entry formatting only. NOT for
reading/browsing incidents. NOT for deep governance review (`/audit`
skill). NOT for investigating root causes (`/investigate` skill).
**Audience**: Agents fulfilling surfacing duty, agents prompted by
the incident-governance rule, subagents triaging `AMBIGUITY:` findings.

## Known Limitations

This skill is outdated and ineffective in its current form. It does not
reflect the current state of the harness — specifically, it lacks
escalation awareness (pattern matching against existing incidents),
does not enforce structural fixes for recurring root causes (3+
occurrences), and suggests behavioral coaching (UCIs) as resolutions
when hooks are the most effective structural mechanism. Fixing this
skill needs further investigation. See planning brief decision #35
and incident #48.

## When to use

- A rule says X but code does Y → **incident** (spec deviation)
- A rule is unclear or contradictory → **incident** (ambiguity)
- No spec exists for a common decision → **incident** (governance gap)
- A cross-reference points to missing content → **incident**
- Something went wrong with real impact → **incident** (operational)
- A subagent reported `AMBIGUITY:` findings → triage and file here

## When NOT to use

- Planned feature → add to `ROADMAP.md`
- Specific bug with repro steps → `gh issue create`
- Process improvement → `ROADMAP.md` or RFC
- Tool evaluation → `/tool-eval` skill

## Filing process

### Step 1: Read current state

Read `reference/incidents.json`. Note the highest ID in the `incidents` array.
The new entry gets `highest + 1`.

### Step 2: Classify severity

| Level | Meaning |
|-------|---------|
| `critical` | Deployment, data loss, security, cross-machine propagation |
| `high` | Silent wrong behavior, rule violations in production code |
| `medium` | Documentation drift, minor behavioral inconsistency |
| `low` | Cleanup, style, future-proofing |

### Step 3: Format the entry

```json
{
  "id": <next_id>,
  "title": "Name the specific deficiency, not the symptom or trigger",
  "status": "open",
  "severity": "<critical|high|medium|low>",
  "affected": ["file1.sh", "file2.ps1"],
  "linked": null,
  "referenceFile": null,
  "observation": "What concrete state did you observe?",
  "expected": "What spec says the state should be different?",
  "impact": "What breaks if this is not fixed?",
  "discoveryContext": "What were you doing when this surfaced?",
  "discipline": null,
  "frameworks": null,
  "suggestedResolution": "Starting point for resolution.",
  "rootCause": null,
  "correctiveAction": null,
  "preventionLayer": null,
  "created": "<today YYYY-MM-DD>",
  "updated": "<today YYYY-MM-DD>"
}
```

### Step 4: Present for review

`reference/incidents.json` is a protected file (sources-of-truth gate).
Present the proposed entry to the user before writing. Show:
- The severity rationale
- The full JSON entry
- Which spec/rule is affected

### Step 5: Write if approved

Add the entry to the `incidents` array. Update `meta.lastUpdated` to today.

## Closing an incident

When an incident is resolved:
1. Move the entry from `incidents` to `closed` array
2. Add `closedIn` (version) and `closedDate` fields
3. Remove the detailed fields (keep id, title, closedIn, closedDate)
4. Mention in release notes: "Resolves Incident #N"

## Quick filing from subagent output

When a subagent reports `AMBIGUITY: <description>`:
1. Read the finding
2. Determine if it's real (spot-check against the referenced file)
3. If real, follow the filing process above
4. If false positive, discard

## Multiple incidents in one session

File them one at a time, incrementing IDs. Present all entries as a batch
for user review if filing multiple incidents at once.

## Cross-References

- Framework: `@reference/framework-incident-governance.md`
- Operational rule: `@.claude/rules/incident-governance.md`
- Discovery cycle: `@reference/framework-adoption.md`
- Incident data: `@reference/incidents.json`
- Audit skill: `.claude/skills/audit/SKILL.md`
