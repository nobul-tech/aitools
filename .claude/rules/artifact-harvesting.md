## Artifact Harvesting (this repo)

**Intent**: **Purpose**: Govern the lifecycle of reusable artifacts
produced during sessions — code, prompts, patterns, research. Ensure
artifacts are harvested, evaluated, and either promoted into the
harness or pruned. **Scope**: Harvesting gates, pruning criteria,
promotion criteria, generalization triggers. NOT the harvesting
process itself (`/harvest` skill). NOT the ephemeral scratch pattern
(`/scratch` skill). NOT the source discipline documentation
(`reference/framework-artifact-harvesting.md`). **Audience**: Every
agent producing code, prompts, or reusable patterns during a session.

### Governing principle

Every session produces artifacts beyond the primary deliverable —
utility scripts, exploration tools, research documents, prompt
patterns. These represent tactical solutions to real problems. Left
unharvested, they disappear. Harvested and evaluated, they become
candidates for harness improvement.

### What MUST be harvested

At session end, any non-ephemeral file in `.scratch/` that represents
reusable work:
- Code (scripts, utilities, one-off tools)
- Prompts (patterns that produced good results)
- Research (evaluation documents, analysis outputs)
- Patterns (approaches that could be generalized)

### What MUST NOT be harvested

- Commit message files
- Build/check logs
- Temp output captures
- Files already committed to a permanent location

### Pruning criteria

Artifacts MUST be auto-pruned when ALL of these are true:
- Age > 30 days since harvested
- Zero references in git log
- Not flagged "keep" in the manifest
- Status is still `harvested` (never reached `candidate`)

### Promotion criteria

Artifacts become promotion candidates when ANY of these are true:
- Referenced in git log (used in a commit)
- Manually flagged by user or agent
- Age > 7 days AND similar pattern detected in harness inventory

Promotion candidates MUST be presented to the user for review.

### Generalization

Artifacts that solve a specific problem may generalize into harness
tools. Generalization is evaluated via `/harvest review` (AI-powered
analysis against harness inventory, git history, and KPIs). Triggers:
- `aitools` sync when candidates exist
- On-demand via `/harvest review`
- Future: periodic Modal job for cross-session pattern analysis

### Automation

- **SessionEnd hook**: classify `.scratch/` contents, harvest
  artifacts, delete ephemeral files, ship KPIs
- **SessionStart hook**: audit `harvesting/`, auto-prune stale,
  log candidates, ship inventory KPIs
- **`aitools` sync**: prompt for candidate review if any exist

### Cross-references

- Harvesting process: `/harvest` skill
- Ephemeral scratch files: `/scratch` skill
- Harvest manifest: `/harvest` skill (governed data)
- Source discipline: `reference/framework-artifact-harvesting.md`
