---
name: gap
description: "File a gap or ambiguity in known-gaps.json. Use when a spec deviation, broken cross-reference, or ambiguity is found that should be tracked. Also use when the user says /gap or asks to file a gap."
---

## Purpose

File deviations from spec (gaps) and unresolved ambiguities into
`reference/known-gaps.json`. This is the operational tool for the
surfacing duty defined in `.claude/rules/gap-governance.md`.

## When to use

- A rule says X but code does Y → **gap**
- A rule is unclear or contradictory → **ambiguity**
- No spec exists for a common decision → **ambiguity** (governance gap)
- A cross-reference points to missing content → **gap**
- A subagent reported `AMBIGUITY:` findings → triage and file here

## When NOT to use

- Planned feature → add to `ROADMAP.md`
- Specific bug with repro steps → `gh issue create`
- Process improvement → `ROADMAP.md` or RFC
- Tool evaluation → `/tool-eval` skill

## Filing process

### Step 1: Read current state

Read `reference/known-gaps.json`. Note the highest ID in the `gaps` array.
The new entry gets `highest + 1`.

### Step 2: Classify

Use the decision tree:

1. Is there a spec (rule or reference) that addresses this?
   - **Yes, code deviates** → type: `gap`
   - **Yes, but spec is unclear** → type: `ambiguity`
   - **No spec exists for a common decision** → type: `ambiguity`
2. One-off bug with repro steps? → Don't file here, use `gh issue create`
3. Feature we want but haven't built? → Don't file here, add to ROADMAP

### Step 3: Assign severity

| Level | Meaning |
|-------|---------|
| `critical` | Deployment, data loss, security, cross-machine propagation |
| `high` | Silent wrong behavior, rule violations in production code |
| `medium` | Documentation drift, minor behavioral inconsistency |
| `low` | Cleanup, style, future-proofing |

### Step 4: Format the entry

```json
{
  "id": <next_id>,
  "title": "Short descriptive title",
  "status": "open",
  "severity": "<critical|high|medium|low>",
  "type": "<gap|ambiguity>",
  "affected": ["file1.sh", "file2.ps1"],
  "linked": null,
  "description": "What's wrong and what the spec says.",
  "plannedFix": "How to resolve, or null if unknown.",
  "created": "<today YYYY-MM-DD>",
  "updated": "<today YYYY-MM-DD>"
}
```

### Step 5: Present for review

`reference/known-gaps.json` is a protected file (sources-of-truth gate).
Present the proposed entry to the user before writing. Show:
- The classification rationale
- The full JSON entry
- Which spec/rule is affected

### Step 6: Write if approved

Add the entry to the `gaps` array. Update `meta.lastUpdated` to today.

## Closing a gap

When a gap is resolved:
1. Move the entry from `gaps` to `closed` array
2. Add `closedIn` (version) and `closedDate` fields
3. Remove the detailed fields (keep id, title, closedIn, closedDate)
4. Mention in release notes: "Resolves Gap #N"

## Quick filing from subagent output

When a subagent reports `AMBIGUITY: <description>`:
1. Read the finding
2. Determine if it's real (spot-check against the referenced file)
3. If real, follow the filing process above
4. If false positive, discard

## Multiple gaps in one session

File them one at a time, incrementing IDs. Present all entries as a batch
for user review if filing multiple gaps at once.

## Cross-References

- Framework: `@reference/framework-gap-governance.md`
- Operational rule: `@.claude/rules/gap-governance.md`
- Discovery cycle: `@reference/framework-adoption.md`
- Gap data: `@reference/known-gaps.json`
- Audit skill: `.claude/skills/audit/SKILL.md`
