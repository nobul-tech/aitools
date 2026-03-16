## Incident Governance (this repo)

**Intent**: **Purpose**: Govern how harness deficiencies are filed,
classified, tracked, and resolved — the operational process for the
surfacing duty. **Scope**: Filing process, severity classification,
lifecycle states, surfacing duty, staleness rules, hook specifications.
NOT the incident data itself (`/incident` skill). NOT the framework
documentation (`reference/framework-incident-governance.md`). NOT
incident reference files (`reference/incident-*.md`). **Audience**:
Every agent, every session — surfacing duty is continuous.

### What gets filed via /incident skill

The `/incident` skill tracks deviations from spec, unresolved
ambiguities, and operational incidents requiring root cause analysis.

| Finding | Definition | Example |
|---------|-----------|---------|
| **Spec deviation** | Code deviates from an existing spec | Bash script missing `backup_file` that PS1 has |
| **Ambiguity** | Spec is unclear, contradictory, or missing | Two rules give conflicting error-handling guidance |
| **Operational incident** | Something went wrong in production | Built-in subagent bypassed deny rule, causing hooks to be disabled |

### What does NOT go here

| Finding | Where it goes |
|---------|---------------|
| Planned feature | `ROADMAP.md` |
| Specific bug with repro | GitHub issue (`gh issue create`) |
| Process improvement | `ROADMAP.md` or RFC |
| Tool evaluation | `/tool-eval` skill |

### Decision tree

1. Is there a spec (rule or reference) that addresses this?
   - **Yes, code deviates** → Incident (spec deviation)
   - **Yes, but spec is unclear** → Incident (ambiguity)
   - **No spec exists for a common decision** → Incident (governance ambiguity)
2. Something went wrong in production with real impact? → Incident (operational)
3. One-off bug with repro steps? → GitHub issue
4. Feature we want but haven't built? → Roadmap item

### Required fields

Every entry in the `incidents` array. Field descriptions are prescriptive —
follow them exactly to prevent thin or ambiguous entries. See
`@reference/framework-adoption.md` for the discovery cycle that
produces these fields.

```json
{
  "id": 1,
  "title": "Name the specific deficiency, not the symptom or trigger",
  "status": "open | planned | closed",
  "severity": "critical | high | medium | low",
  "affected": ["files that need to change to resolve this incident"],
  "linked": "plan, roadmap item, or issue tracking resolution (null if none)",
  "referenceFile": "reference/incident-NNN-short-name.md for incidents that went through the full discovery cycle (steps 4-6). null for simple code deviations.",

  "observation": "What concrete state did you observe? Quote specific text, cite specific files and line numbers, name specific behaviors. Facts only — no interpretation. If you cannot point to a specific file or behavior, this may not be an incident.",

  "expected": "What specific rule, reference, principle, or convention says the state should be different? Cite the source as file:section. If NO spec exists, write 'No spec exists for: [topic]' — that makes this an ambiguity.",

  "impact": "What breaks, degrades, or is at risk if this is not fixed? Name the affected workflow, user experience, or downstream system. 'Documentation drift' is not enough — say what drifts from what and who is affected.",

  "discoveryContext": "What plan step or task were you executing when this surfaced? What harness artifacts (rules, references, incidents, code, plans) did you audit before filing? Include session date. If a session archive exists, include the reference.",

  "discipline": "If this maps to an established field of practice, name it. Check via /frameworks skill for the taxonomy. null if this is a simple code deviation.",

  "frameworks": "Specific frameworks from the named discipline that inform resolution. Give the consumer enough to evaluate them without prior knowledge. null if no discipline applies.",

  "suggestedResolution": "A starting point for whoever picks this up — NOT a commitment. The consumer's context, plan state, and priorities will differ from yours. Describe the direction and list options if multiple approaches exist. Name which harness artifacts would be created or modified.",

  "rootCause": "What underlying condition allowed this to happen? null if not yet analyzed. For operational incidents, 5 Whys or barrier analysis recommended.",

  "correctiveAction": "What was done or will be done to fix this specific instance? null if not yet addressed.",

  "preventionLayer": "Which governance layer (Prevention/Detection/Audit) will prevent recurrence? null if not yet determined.",

  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD"
}
```

### Field quality rules

- **title**: Name the deficiency itself. "Hook script deployment"
  — rejected. "Hook scripts deployed without backup or interactive
  review" — accepted.
- **observation vs expected**: Together these must make the incident
  self-evident to a reader who has never seen it before. If you can't
  fill both, you may not understand the incident well enough to file it.
- **impact**: Must be concrete. "Affects deployment" — rejected.
  "User customizations in hook scripts are silently overwritten on
  every aitools install" — accepted.
- **discoveryContext**: Must include what you audited. "Found during
  code review" — rejected. "Found while executing governance plan
  step 4. Audited: `@.claude/rules/incident-governance.md`,
  `@scripts/setup-user-hooks.sh`:L45-60,
  `@.claude/rules/sources-of-truth.md`. Session: 2026-03-14" —
  accepted.
- **discipline/frameworks**: Only populated when the incident maps to an
  established field. Most code-deviation incidents leave these null.
- **suggestedResolution**: Must list options when the path isn't
  obvious. Must name specific harness artifacts. "Fix it" — rejected.
  "Create user-level rule process-discipline.md covering plan
  adherence. Alternative: extend `@.claude/rules/incident-governance.md`
  with a process section" — accepted.
- **referenceFile**: Required for incidents that went through the full
  discovery cycle (steps 4-6: recognition, research, adaptation).
  The reference file captures the depth that JSON fields cannot.
  null for simple code deviations.
- **rootCause / correctiveAction / preventionLayer**: Populated during
  or after investigation. null is acceptable for newly filed incidents.
  Operational incidents should have these filled before closing.

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

Every planning and coding session must actively look for incidents.
This is continuous, not periodic:

- Reading a rule? Is it clear? Could it be read two ways?
- Following a cross-reference? Does the target exist and match?
- Making a decision with no rule? Is that a governance incident?
- Something broke in production? File with root cause analysis.

Found something? File it via the `/incident` skill or leave a `TODO(incident):`
comment in the current file if mid-task. The `/audit` skill scans for
unfiled `TODO(incident):` markers.

### Staleness

Incidents open more than 90 days without a linked plan are stale. The
`/audit` skill flags these. Stale incidents must be either planned or
closed with rationale.

### Concurrency

Incident IDs use sequential integers. If two sessions race and create
duplicate IDs, the `/audit` skill detects and flags for renumbering.
Accept the rare race rather than over-engineering file locking.

### Skill interfaces

**`/incident`** — file an incident:
- Reads `incidents.json`, determines next ID
- Walks through classification (decision tree above)
- Formats entry with all required fields
- Presents for review (protected file gate applies)
- Writes if approved
- Model-invocable: yes (auto-triggers when spec deviation found)
- User-invocable: yes

**`/audit`** — deep governance review:
- Reads all rules, references, CLAUDE.md
- Reports: incidents, inconsistencies, broken cross-references, stale entries,
  duplicate IDs, unfiled `TODO(incident):` markers
- User-invocable: yes
- Model-invocable: no (`disable-model-invocation: true`)

### Decisions tracking

Ambiguities resolved during a session belong in the plan file's
"Foundational Decisions" section — not here. incidents.json is for
OPEN items needing work. Resolved decisions need a durable home in the
plan or reference that produced them.

### Framework adoption

When an incident maps to an established discipline (steps 4-6 of the
discovery cycle), the resolution involves adopting concepts from that
discipline into the harness. See `@reference/framework-adoption.md`
for the full lifecycle and `@.claude/rules/frameworks.md` for the
current framework registry.

The incident entry captures the discovery and design phases (steps 1-6).
Implementation and integration (steps 7-8) are tracked by the linked
plan or roadmap item. Continuation (step 9) — resuming the
interrupted work — happens in the session, not the incident.

### Hook specifications

Full hook architecture: `@plans/governance-and-compliance-framework.md`
§Hook Specifications. Summary:

- **SubagentStart** (command): pre-built cache serves all skill content
  + governance duty + scratch namespace via single file read (~5ms).
  Subagents are sensors, not filers — report `INCIDENT:` findings.
- **PreToolUse on incidents.json** (agent): validates required fields,
  enums, sequential IDs. Fail-open on timeout/error.
- **PreToolUse on protected files** (command): cross-reference reminder.
- **PreToolUse on Edit/Write** (command): error-suppression detection.
- **PreToolUse on Bash git commands** (command): checklist reminder.
- **PostToolUse on Write/Edit** (command): sh-file-fixup (CRLF, chmod, git index).
- **Stop** (command): surfacing duty — periodic reminder + incident-acknowledgment
  detection. Uses stderr for agent feedback. NOTE: Claude Code `type: "prompt"`
  hooks require a static `prompt` string field (not a command/script path).
  Dynamic Stop hooks must use `type: "command"` with stderr output.
