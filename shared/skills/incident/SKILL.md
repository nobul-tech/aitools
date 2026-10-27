---
name: incident
description: "File an incident in incidents.json. Use when a spec deviation, broken cross-reference, ambiguity, or operational failure is found that should be tracked. Also use when the user says /incident or asks to file an incident."
---

## Intent

**Purpose**: File harness deficiencies into `registries/incidents.json`
with structured fields, severity classification, and root cause
tracking — the operational tool for the surfacing duty. **Scope**:
Filing process, classification, and entry formatting only. NOT for
reading/browsing incidents. NOT for deep governance review (`/audit`
skill). NOT for investigating root causes (`/investigate` skill).
**Audience**: Agents fulfilling surfacing duty, agents prompted by
the incident-governance rule, agents triaging subagents' `INCIDENT:` (or legacy `AMBIGUITY:`) findings.

## Where the files live

This is a user-level skill: `aitools install` deploys it to
`~/.claude/skills/` and `~/.cursor/skills/`, so it loads in every repo.
Its source is `shared/skills/incident/` in the aitools repo. Every repo path
below (`registries/`, `reference/`, `.claude/rules/`, `scripts/`) is relative
to the aitools clone:

- **Session on aitools** (the clone or one of its worktrees): the paths
  resolve from the repo root. Reads and reviewed writes happen here.
- **Session on any other repo**: use the clone named by `repoPath` in
  `~/.aitools/config.json` (`%USERPROFILE%\.aitools\config.json` on
  Windows). Read current data: `git -C <repoPath> fetch origin`, then read
  `origin/main` (`git -C <repoPath> show origin/main:<path>`), not the
  working tree, which may be stale or hold other agents' edits. Never edit
  that checkout's working tree from another repo's session. A reviewed
  write goes on a new branch in a worktree created from `origin/main`
  (`git -C <repoPath> worktree add -b <branch> <path> origin/main`) and
  ships as a PR; if that is not possible, open an issue on
  `nobul-tech/aitools` with the drafted change.
- **No clone on this machine**: read the read-only copies under
  `~/.aitools/registries/` and `~/.aitools/reference/` once deploy-harness
  installs them. Never edit those copies; propose the change as an issue on
  `nobul-tech/aitools` instead.
- **None of these exist**: say the data is unavailable and stop. Do not
  answer from memory.

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
- A subagent reported `INCIDENT:` (or legacy `AMBIGUITY:`) findings → triage and file here

## When NOT to use

- Planned feature → add to `ROADMAP.md`
- Specific bug with repro steps → `gh issue create`
- Process improvement → `ROADMAP.md` or RFC
- Tool evaluation → `/tool-eval` skill

## Filing process

### Step 1: Read current state

Read `registries/incidents.json` in full. It is longer than the Read tool's
2,000-line default: read it in parts with `offset`/`limit` until the end of the
file, and never choose an id from a partial read (#122). Note the highest ID
across both the `incidents` and the `closed` arrays. The new entry gets
`highest + 1`. Cross-check with a one-line count when a shell is available:

```bash
python3 -c 'import json; d=json.load(open("registries/incidents.json")); print(max(i["id"] for i in d["incidents"] + d["closed"]))'
```

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

`registries/incidents.json` is a protected file (sources-of-truth gate).
Present the proposed entry to the user before writing. Show:
- The severity rationale
- The full JSON entry
- Which spec/rule is affected

### Step 5: Write if approved

Add the entry to the `incidents` array. Update `meta.lastUpdated` to today.

## Closing an incident

When an incident is resolved:
1. **Record the corrective action.** Set `correctiveAction` to what was done:
   the PR or commit, the files and functions changed, and how the fix was
   verified. Fill `rootCause` and `preventionLayer` too when they are known;
   operational incidents need both before closing
   (`.claude/rules/incident-governance.md`, "Field quality rules"). Update
   `updated` to today. This is a protected write: present it for review
   with the close.
2. Move the entry from `incidents` to `closed` array
3. Add `closedIn` (version, or PR and commit) and `closedDate` fields
4. Remove the other detailed fields. Keep `id`, `title`, `correctiveAction`,
   `closedIn` and `closedDate` (and `rootCause` and `preventionLayer` when
   set), so the closed entry still says how it was fixed.
5. Mention in release notes: "Resolves Incident #N"

## Quick filing from subagent output

When a subagent reports `INCIDENT: <description>` (or the legacy `AMBIGUITY: <description>`):
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
- Incident data: `@registries/incidents.json`
- Audit skill: `.claude/skills/audit/SKILL.md`
