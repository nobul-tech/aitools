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

Every entry in the `gaps` array:

```json
{
  "id": 1,
  "title": "Short title",
  "status": "open | planned | closed",
  "severity": "critical | high | medium | low",
  "type": "gap | ambiguity",
  "affected": ["file1.sh", "file2.ps1"],
  "linked": "roadmap item, plan, or issue (null if none)",
  "description": "What's wrong and what the spec says.",
  "plannedFix": "How to resolve (null if unknown).",
  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD"
}
```

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

### Hook specifications

**SubagentStart hook** (command type) — injects into every subagent:
- Surfacing duty: report ambiguities with `AMBIGUITY:` prefix in response
- Scratch namespace: use `.scratch/{session_id}_{agent_type}_` prefix
- Skill awareness: list available compliance skills
- Subagents are sensors, not filers — main agent triages and files via `/gap`

**PreToolUse agent hook on known-gaps.json** (agent type):
- Fires on Edit/Write targeting `reference/known-gaps.json`
- Validates: required fields present, severity/status/type are valid enums,
  ID is sequential, JSON is well-formed
- **Fail-open**: on timeout or error, allow the edit. /audit catches later.
- Timeout: 30 seconds

**PreToolUse prompt hook on protected files** (prompt type):
- Fires on Edit/Write targeting files in sources-of-truth protected table
- Lightweight Haiku check: "you're editing a protected file — verify
  cross-references and downstream dependencies"
- Does not block, context injection only
