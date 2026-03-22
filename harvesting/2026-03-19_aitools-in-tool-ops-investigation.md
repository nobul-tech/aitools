# Investigation: Should aitools Be a tool-ops Entry?

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Session**: Z1IhGrcgGO

## 1. Entry Criteria Check

The `/tool-ops` skill (SKILL.md lines 80-86) defines four entry criteria.
A tool needs an ops entry when ANY of these are true:

| Criterion | aitools meets it? | Evidence |
|-----------|-------------------|----------|
| Hooks that fire during sessions | **Ambiguous** | aitools deploys 9 hooks to `~/.claude/hooks/` but they fire IN Claude Code, not in aitools. aitools is the deployer/manager; Claude Code is the executor. |
| Deny rules blocking specific permissions | **Ambiguous** | `setup-user-mcp.sh` deploys 3 deny rules (`MCP(vercel)`, `MCP(webflow)`, `Agent(claude-code-guide)`) to `~/.claude/settings.json`. aitools writes them; Claude Code enforces them. |
| Special documentation access methods | **No** | aitools documentation is standard markdown in-repo. No chrome-devtools navigation, no special access method needed. |
| Version-dependent behaviors affecting the harness | **No** | aitools has no external version. It IS the harness. Version-dependent behaviors come from Claude Code's version changes, which are already tracked in `tool-ops-claude-code.md`. |

**Verdict**: aitools meets 0 of 4 criteria cleanly. The 2 "ambiguous" cases
resolve to NO once the boundary is analyzed (section 2).

## 2. Boundary Analysis: aitools vs claude-code

This is the core question. There are two possible mental models:

### Model A: Separate entities with a management relationship

- Claude Code is the **platform** (runtime, hooks API, settings consumer, session manager)
- aitools is the **orchestrator** (deploys hooks, writes settings, manages configs, builds deploy scripts)
- The boundary is: Claude Code **consumes** what aitools **produces**

Under this model, hooks "belong to" aitools (it writes them) AND claude-code
(it executes them). The deny rules are managed by aitools but enforced by
claude-code.

### Model B: One integrated system

- Claude Code + aitools = the harness
- There is no meaningful boundary; operational metadata about one is inherently about the other
- tool-ops.json for claude-code already IS tool-ops for the whole harness

### Evidence for Model B (the integrated view)

1. **The claude-code tool-ops entry already tracks the hooks aitools deploys.**
   `tool-ops.json` `tools.claude-code.hooks` lists `block-claude-code-guide.sh`
   -- that hook is authored, tested, and deployed by aitools, but tracked under
   claude-code because that's where it fires.

2. **The deny rules are already in the claude-code entry.** The
   `Agent(claude-code-guide)` deny rule in `tool-ops.json` is deployed by
   `setup-user-mcp.sh` (an aitools script) but tracked under claude-code.

3. **Version dependencies are already Claude Code's.** Every version-dependent
   behavior in `tool-ops-claude-code.md` is a Claude Code version dependency.
   aitools doesn't have an independent version that affects the harness.

4. **The harness.md architecture says it explicitly.** The harness has 5
   components: Platform (Claude Code), Configuration, Orchestration, Managed
   Tools, and Frameworks. aitools spans Configuration + Orchestration. It's not
   a managed tool -- it IS the management layer.

5. **The framework documentation says it explicitly.** `framework-tool-ops.md`
   line 41: "Claude Code was the first entry -- its deny rules, hooks, and
   version dependencies were scattered across multiple harness files before
   consolidation." The consolidation was of Claude Code's operational knowledge,
   not aitools' operational knowledge.

### Evidence for Model A (separate entities)

1. **aitools has its own operational behaviors** that could drift: build
   pipeline, deploy script generation, setup script logic, check scripts.

2. **aitools could theoretically have its own hooks** -- e.g., a SessionStart
   hook that validates aitools repo state, or a pre-build hook.

3. **Governance mode graduation could apply** to aitools-specific behaviors
   (e.g., "is the harvest-session hook working correctly?" is an aitools
   question, not a Claude Code question).

### Boundary verdict

**Model B is correct, but incomplete.** The current claude-code tool-ops entry
tracks the right things but its scope description doesn't acknowledge that it
covers aitools-deployed content. The fix is not a new entry -- it's a scope
clarification in the existing entry.

## 3. Barrier Analysis: Three Options

### Option A: Add "aitools" as a separate tool-ops entry alongside claude-code

**What it would contain:**

```json
"aitools": {
  "governanceModes": {
    "hooks": "audit",
    "deployPipeline": "audit",
    "configDeployment": "audit"
  },
  "hooks": [
    { "event": "SessionEnd", "script": "harvest-session.sh", "purpose": "Harvest artifacts" },
    { "event": "SessionEnd", "script": "session-archive.sh", "purpose": "Archive transcripts" },
    { "event": "SessionEnd", "script": "tool-ops-session-audit.sh", "purpose": "Drift detection" },
    { "event": "PreToolUse", "matcher": "Bash", "script": "standing-order-guard.sh", "purpose": "Enforce standing orders" },
    { "event": "PreToolUse", "matcher": "Read|Grep", "script": "glossary-skill-guard.sh", "purpose": "Skill guard" },
    { "event": "PreToolUse", "matcher": "Agent", "script": "block-claude-code-guide.sh", "purpose": "Block buggy subagent" },
    { "event": "PostToolUse", "matcher": "Write|Edit", "script": "sh-file-fixup.sh", "purpose": "Fix line endings" },
    { "event": "Stop", "script": "surfacing-duty-stop.sh", "purpose": "Surfacing duty reminder" },
    { "event": "PreToolUse", "matcher": "Bash", "script": "scratch-init.sh", "purpose": "Init scratch dir" }
  ],
  "denyRules": [
    { "id": "at-deny-mcp-vercel", "permissionPattern": "MCP(vercel)", "reason": "Disabled by default" },
    { "id": "at-deny-mcp-webflow", "permissionPattern": "MCP(webflow)", "reason": "Disabled by default" },
    { "id": "at-deny-guide-subagent", "permissionPattern": "Agent(claude-code-guide)", "reason": "Buggy" }
  ],
  "kpis": [
    { "name": "hookDeploymentDrift", "source": "setup-user-hooks diff", "unit": "mismatched hooks" },
    { "name": "buildPipelineSuccess", "source": "build-deploy.sh exit code", "unit": "pass/fail" }
  ]
}
```

**Problem**: This creates duplicate ownership. The `block-claude-code-guide.sh`
hook is already in `tools.claude-code.hooks`. The `Agent(claude-code-guide)`
deny rule is already in `tools.claude-code.denyRules`. We'd have to split
ownership (who "owns" a hook -- the deployer or the executor?) or duplicate
entries. Both are worse than the current state.

**Does it resolve an actual problem?** No. There is no operational incident,
no agent confusion, and no drift caused by the absence of an aitools entry.
The hooks work. The deny rules work. The deploy pipeline works.

**Risk**: Creates a governance surface area expansion with no corresponding
operational benefit. Agents now have to check two entries to understand one
hook. The three-layer governance pattern becomes recursively self-referential:
tool-ops tracks hooks, hooks enforce tool-ops, and the tool deploying the hooks
is tracked BY tool-ops tracking hooks.

### Option B: Expand claude-code entry to include aitools operational metadata

**What it would look like**: Add sections to the existing claude-code entry
for "deployment pipeline" or "harness orchestration" metadata.

**Problem**: This conflates two concepts. The claude-code entry is about Claude
Code's behaviors as a platform. Adding aitools deployment metadata would make
the entry about "everything the harness does" -- which is what CLAUDE.md, rules,
and reference files already cover.

**Does it resolve an actual problem?** No, for the same reasons as Option A.

**Risk**: The claude-code entry loses focus. It currently answers a clear
question: "how does Claude Code behave operationally?" Adding aitools metadata
makes it answer: "how does everything work?" That's what the rest of the
harness documentation already does.

### Option C: Don't add -- aitools is the harness, not a tool it manages

**Rationale**: tool-ops exists for tools the harness manages, not for the
harness managing itself. The framework documentation explicitly says this is
a lean pull system -- entries are created when operational complexity causes
incidents. aitools has not caused an operational incident from absence of
tool-ops metadata.

**What already governs aitools operations?**

| Concern | Current governance | Location |
|---------|-------------------|----------|
| Hook deployment | `setup-user-hooks.sh/.ps1` + `managed-file-deployment.md` | scripts + reference |
| Deny rule deployment | `setup-user-mcp.sh/.ps1` | scripts |
| Build pipeline | `build-deploy.sh` + `git-safety.md` | scripts + rules |
| Config deployment | `setup-user-claude.sh/.ps1` + menus | scripts + reference |
| Version tracking | Not applicable (aitools has no external version consumers) | N/A |
| Drift detection | Check scripts (`check-pre-commit`, etc.) | scripts |
| Hook behavior | `tool-ops-claude-code.md` (tracks CC-side behavior) | reference |
| Operational incidents | `/incident` skill | skill + JSON |

**Does NOT adding it miss anything?** No. Every operational concern is already
covered by a specific governance artifact. The gap identified in this
investigation is not "we need a tool-ops entry" but "the claude-code tool-ops
entry should acknowledge it covers aitools-deployed content."

## 4. Existing Incidents and Decisions

- **No incident** filed about aitools operational tracking.
- **No planning brief decision** about aitools in tool-ops.
- **No ROADMAP item** about aitools tool-ops entry.
- The planning brief's decisions #5 (deny rules), #6 (deny rule registration),
  and #20 (one hook per feature) all route to `tool-ops.json` via the
  claude-code entry -- none propose an aitools entry.
- `reference/harness.md` explicitly categorizes aitools as spanning
  "Configuration + Orchestration" -- not as a managed tool.

## 5. Recommendation

**Option C: Do not add an aitools tool-ops entry.**

### Rationale

1. **aitools is not a tool in the tool-registry sense.** It is not installed
   via `setup-*.sh/.ps1`. It is not versioned for external consumers. It has
   no platform lifecycle status. The tool-registry governs tools the harness
   manages; aitools IS the harness.

2. **Self-referential governance is a complexity trap.** If the harness tracks
   itself as a managed tool, then the tool-ops-session-audit hook (which audits
   tool-ops entries) would audit the aitools entry, which describes the
   tool-ops-session-audit hook, which audits the entry that describes it. This
   is the kind of recursive governance that creates ambiguity (a design
   principle violation) without resolving an operational problem.

3. **The lean pull principle says no.** `framework-tool-ops.md`: "entries are
   created on demand when a tool earns deep integration, not speculatively for
   every managed tool." The trigger is operational complexity causing incidents.
   aitools has not caused such an incident.

4. **Every operational concern is already governed.** See the table in Option C
   above. There is no ungoverned aitools operational behavior.

5. **The existing claude-code entry already covers the right things.** Hooks
   deployed by aitools are tracked under claude-code because that's where they
   execute. This is the correct attribution: track operational behavior where
   it manifests, not where it originates.

### Minor improvement opportunity

The claude-code tool-ops reference (`reference/tool-ops-claude-code.md`) could
benefit from a brief note acknowledging that the hooks and deny rules tracked
in its tool-ops.json entry are deployed by aitools setup scripts. This is a
documentation clarification, not a schema change. It would help an agent
understand the full lifecycle: aitools authors/deploys -> tool-ops.json
tracks -> Claude Code executes.

This is a trivial documentation fix, not an incident or roadmap item.

## 6. Structured AAR

### What was the question?

Should aitools (the harness) be tracked as a managed tool in /tool-ops?

### What did we find?

- aitools meets 0 of 4 entry criteria cleanly
- The boundary between aitools and claude-code is not two separate tools but
  one integrated system: aitools produces, Claude Code consumes
- All aitools operational concerns are already governed by existing artifacts
- No incidents, decisions, or roadmap items call for this
- Adding it would create duplicate ownership and recursive governance

### What's the answer?

No. tool-ops is for tools the harness manages. The harness managing itself in
tool-ops is over-engineering that creates ambiguity without resolving an
operational problem.

### What alternative exists?

None needed. The existing governance (scripts, rules, reference files, check
scripts, incidents) fully covers aitools operations. A minor documentation
note in `tool-ops-claude-code.md` about the aitools deployment relationship
would improve clarity.

### What does existing governance already cover?

- **Hook deployment**: `setup-user-hooks.sh/.ps1` + `managed-file-deployment.md`
- **Deny rules**: `setup-user-mcp.sh/.ps1` + tool-ops.json claude-code entry
- **Build pipeline**: `build-deploy.sh` + `git-safety.md` rule
- **Config deployment**: setup scripts + interactive menus + `managed-file-deployment.md`
- **Drift detection**: `check-pre-commit.sh/.ps1`, `check-pre-push.sh/.ps1`, `check-post-push.sh/.ps1`
- **Hook execution behavior**: `tool-ops-claude-code.md` version dependencies
- **Operational incidents**: `/incident` skill + `incidents.json`
- **Framework governance**: `.claude/rules/frameworks.md` + `/frameworks` skill
