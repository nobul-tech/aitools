## Gap Governance (this repo)

### What goes in known-gaps.json

`reference/known-gaps.json` tracks deviations from spec and unresolved
ambiguities. Two types:

| Type | Definition | Example |
|------|-----------|---------|
| **Gap** | Code deviates from an existing spec | Bash script missing `backup_file` that PS1 has |
| **Ambiguity** | Spec is unclear, contradictory, or missing | Two rules give conflicting error-handling guidance |

### What does NOT go here

| Finding | Where it goes |
|---------|---------------|
| Planned feature | `ROADMAP.md` |
| Specific bug with repro | GitHub issue (`gh issue create`) |
| Process improvement | `ROADMAP.md` or RFC |
| Tool evaluation | `@reference/tool-registry.md` |

### Decision tree

1. Is there a spec (rule or reference) that addresses this?
   - **Yes, code deviates** → Gap
   - **Yes, but spec is unclear** → Ambiguity
   - **No spec exists for a common decision** → Ambiguity (governance gap)
2. One-off bug with repro steps? → GitHub issue
3. Feature we want but haven't built? → Roadmap item

### Required fields

Every entry in the `gaps` array. Field descriptions are prescriptive —
follow them exactly to prevent thin or ambiguous entries. See
`@reference/framework-adoption.md` for the discovery cycle that
produces these fields.

```json
{
  "id": 1,
  "title": "Name the specific deficiency, not the symptom or trigger",
  "status": "open | planned | closed",
  "severity": "critical | high | medium | low",
  "type": "gap | ambiguity",
  "affected": ["files that need to change to resolve this gap"],
  "linked": "plan, roadmap item, or issue tracking resolution (null if none)",
  "referenceFile": "reference/gap-NNN-short-name.md for gaps that went through the full discovery cycle (steps 4-6). null for simple code deviations.",

  "observation": "What concrete state did you observe? Quote specific text, cite specific files and line numbers, name specific behaviors. Facts only — no interpretation. If you cannot point to a specific file or behavior, this may not be a gap.",

  "expected": "What specific rule, reference, principle, or convention says the state should be different? Cite the source as file:section. If NO spec exists, write 'No spec exists for: [topic]' — that makes this an ambiguity, not a gap.",

  "impact": "What breaks, degrades, or is at risk if this is not fixed? Name the affected workflow, user experience, or downstream system. 'Documentation drift' is not enough — say what drifts from what and who is affected.",

  "discoveryContext": "What plan step or task were you executing when this surfaced? What harness artifacts (rules, references, gaps, code, plans) did you audit before filing? Include session date. If a session archive exists, include the reference.",

  "discipline": "If this maps to an established field of practice, name it. See reference/framework-registry.json for the taxonomy. null if this is a simple code deviation.",

  "frameworks": "Specific frameworks from the named discipline that inform resolution. Give the consumer enough to evaluate them without prior knowledge. null if no discipline applies.",

  "suggestedResolution": "A starting point for whoever picks this up — NOT a commitment. The consumer's context, plan state, and priorities will differ from yours. Describe the direction and list options if multiple approaches exist. Name which harness artifacts would be created or modified.",

  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD"
}
```

### Field quality rules

- **title**: Name the deficiency itself. "Hook script deployment"
  — rejected. "Hook scripts deployed without backup or interactive
  review" — accepted.
- **observation vs expected**: Together these must make the gap
  self-evident to a reader who has never seen it before. If you can't
  fill both, you may not understand the gap well enough to file it.
- **impact**: Must be concrete. "Affects deployment" — rejected.
  "User customizations in hook scripts are silently overwritten on
  every aitools install" — accepted.
- **discoveryContext**: Must include what you audited. "Found during
  code review" — rejected. "Found while executing governance plan
  step 4. Audited: `@.claude/rules/gap-governance.md`,
  `@scripts/setup-user-hooks.sh`:L45-60,
  `@.claude/rules/sources-of-truth.md`. Session: 2026-03-14" —
  accepted.
- **discipline/frameworks**: Only populated when the gap maps to an
  established field. Most code-deviation gaps leave these null.
- **suggestedResolution**: Must list options when the path isn't
  obvious. Must name specific harness artifacts. "Fix it" — rejected.
  "Create user-level rule process-discipline.md covering plan
  adherence. Alternative: extend `@.claude/rules/gap-governance.md`
  with a process section" — accepted.
- **referenceFile**: Required for gaps that went through the full
  discovery cycle (steps 4-6: recognition, research, adaptation).
  The reference file captures the depth that JSON fields cannot.
  null for simple code deviations.

### Severity

| Level | Meaning |
|-------|---------|
| Critical | Deployment, data loss, security, cross-machine propagation |
| High | Silent wrong behavior, rule violations in production code |
| Medium | Documentation drift, minor behavioral inconsistency |
| Low | Cleanup, style, future-proofing |

### Lifecycle

- **Open** — filed, severity assigned
- **Planned** — linked to a roadmap item or plan
- **Closed** — fix verified, moved to `closed` array with version and date

No "in progress" state — the linked plan or roadmap item tracks that.

### Surfacing duty

Every planning and coding session must actively look for ambiguities.
This is continuous, not periodic:

- Reading a rule? Is it clear? Could it be read two ways?
- Following a cross-reference? Does the target exist and match?
- Making a decision with no rule? Is that a governance gap?

Found something? File it via the `/gap` skill or leave a `TODO(gap):`
comment in the current file if mid-task. The `/audit` skill scans for
unfiled `TODO(gap):` markers.

### Staleness

Gaps open more than 90 days without a linked plan are stale. The
`/audit` skill flags these. Stale gaps must be either planned or
closed with rationale.

### Concurrency

Gap IDs use sequential integers. If two sessions race and create
duplicate IDs, the `/audit` skill detects and flags for renumbering.
Accept the rare race rather than over-engineering file locking.

### Skill interfaces

**`/gap`** — file a gap or ambiguity:
- Reads `known-gaps.json`, determines next ID
- Walks through classification (decision tree above)
- Formats entry with all required fields
- Presents for review (protected file gate applies)
- Writes if approved
- Model-invocable: yes (auto-triggers when spec deviation found)
- User-invocable: yes

**`/audit`** — deep governance review:
- Reads all rules, references, CLAUDE.md
- Reports: gaps, inconsistencies, broken cross-references, stale entries,
  duplicate IDs, unfiled `TODO(gap):` markers
- User-invocable: yes
- Model-invocable: no (`disable-model-invocation: true`)

### Decisions tracking

Ambiguities resolved during a session belong in the plan file's
"Foundational Decisions" section — not here. known-gaps.json is for
OPEN items needing work. Resolved decisions need a durable home in the
plan or reference that produced them.

### Framework adoption

When a gap maps to an established discipline (steps 4-6 of the
discovery cycle), the resolution involves adopting concepts from that
discipline into the harness. See `@reference/framework-adoption.md`
for the full lifecycle and `@.claude/rules/frameworks.md` for the
current framework registry.

The gap entry captures the discovery and design phases (steps 1-6).
Implementation and integration (steps 7-8) are tracked by the linked
plan or roadmap item. Continuation (step 9) — resuming the
interrupted work — happens in the session, not the gap.

### Hook specifications

Full hook architecture: `@plans/governance-and-compliance-framework.md`
§Hook Specifications. Summary:

- **SubagentStart** (command): pre-built cache serves all skill content
  + governance duty + scratch namespace via single file read (~5ms).
  Subagents are sensors, not filers — report `AMBIGUITY:` findings.
- **PreToolUse on known-gaps.json** (agent): validates required fields,
  enums, sequential IDs. Fail-open on timeout/error.
- **PreToolUse on protected files** (prompt): cross-reference reminder.
- **PreToolUse on Edit/Write** (prompt): error-suppression detection.
- **PreToolUse on Bash git commands** (prompt): checklist reminder.
- **Stop** (prompt): ambiguity check — were findings surfaced or filed?
