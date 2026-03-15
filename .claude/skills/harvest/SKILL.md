---
name: harvest
description: "Manage the artifact harvesting lifecycle — harvest
  session artifacts, evaluate for promotion, review for generalization,
  prune stale items. Use when harvesting code from .scratch/, reviewing
  harvesting/ contents, promoting artifacts, or running generalization
  analysis."
---

## Intent

**Purpose**: Implement the artifact harvesting lifecycle — moving
artifacts from ephemeral scratch to tracked harvesting, evaluating
promotion candidates, running generalization analysis, and managing
the harvest manifest. **Scope**: The harvesting process, manifest
operations, promotion workflow, and generalization review. NOT the
harvesting governance (`@.claude/rules/artifact-harvesting.md`). NOT
the ephemeral scratch pattern (`/scratch` skill). NOT the source
discipline (`reference/framework-artifact-harvesting.md`).
**Audience**: Any agent harvesting session artifacts, evaluating
candidates, or running generalization reviews.

## Harvesting an artifact

When a session produces reusable code, prompts, or patterns:

1. Move file from `.scratch/session-xxx/` to `harvesting/`
2. Rename with date prefix: `YYYY-MM-DD_descriptive-name.ext`
3. Add entry to `@reference/harvest-manifest.json` via this skill:
   - `harvested`: today's date
   - `session`: project/date_sessionprefix
   - `description`: what problem this solved
   - `type`: code | prompt | research | pattern
   - `language`: python | bash | powershell | markdown | null
   - `status`: harvested
4. Commit the artifact + manifest update

## Manifest schema

```json
{
  "meta": {
    "schemaVersion": "1.0",
    "governance": ".claude/rules/artifact-harvesting.md",
    "skill": "/harvest",
    "lastAudit": "YYYY-MM-DD"
  },
  "artifacts": {
    "YYYY-MM-DD_name.ext": {
      "harvested": "YYYY-MM-DD",
      "session": "project/YYYY-MM-DD_prefix",
      "description": "What problem this solved",
      "type": "code",
      "language": "python",
      "status": "harvested",
      "promotedTo": null,
      "pruneAfter": "YYYY-MM-DD"
    }
  }
}
```

Status lifecycle: `harvested` → `candidate` → `promoted` | `pruned`

## Evaluating artifacts (SessionStart)

Lightweight check, < 1 second:

1. Read `@reference/harvest-manifest.json`
2. For each artifact:
   - Calculate age (days since harvested)
   - Check git log for references: `git log --all --oneline -- harvesting/<file>`
   - If age > 30 AND zero refs AND not flagged → auto-prune
   - If age > 7 AND has refs OR flagged → mark as `candidate`
3. Update manifest with new statuses
4. Log summary: "harvesting/: N artifacts, M candidates, K pruned"
5. Ship KPIs to Datadog

## Promoting an artifact

When a candidate is approved for promotion:

1. Determine target location:
   - Utility script → `scripts/`
   - Check/audit logic → integrate into check scripts
   - Skill pattern → `.claude/skills/` or `shared/skills/`
   - Shell alias → `shared/shell/`
2. Move or refactor the artifact to its target
3. Update manifest: `status: "promoted"`, `promotedTo: "<path>"`
4. The artifact file stays in `harvesting/` as a record (or delete
   if fully absorbed — user's choice)

## Pruning

Auto-pruning at SessionStart per rule criteria:

1. Delete the file from `harvesting/`
2. Update manifest: `status: "pruned"`
3. KPI: `artifacts_pruned_count`

## Generalization review (`/harvest review`)

AI-powered analysis, on-demand or triggered by `aitools` sync:

1. Read all `candidate` and `harvested` artifacts
2. Read harness inventory:
   - Existing scripts (`scripts/*.sh`, `scripts/*.ps1`)
   - Existing skills (`.claude/skills/`, `shared/skills/`)
   - Check scripts (`scripts/check-*.sh`)
   - Recent git history (patterns in recent commits)
3. For each artifact, assess:
   - Does this duplicate an existing tool? → suggest merge
   - Does this extend an existing tool? → suggest enhancement
   - Is this a new capability? → suggest new script/skill
   - Is this too specific to generalize? → suggest keep or prune
4. Present recommendations to user
5. KPI: `generalization_candidates`, `generalization_actions_taken`

## KPI definitions

| KPI | When shipped | What it measures |
|-----|-------------|-----------------|
| `harvest_count` | SessionEnd | Artifacts harvested this session |
| `harvest_inventory` | SessionStart | Total artifacts in harvesting/ |
| `harvest_age_p50` | SessionStart | Median age of harvested artifacts |
| `harvest_pruned` | SessionStart | Artifacts auto-pruned this check |
| `harvest_candidates` | SessionStart | Artifacts meeting promotion criteria |
| `harvest_promoted` | On promote | Artifacts promoted to harness |
| `harvest_promotion_rate` | SessionStart | promoted / total ever harvested |
| `generalization_reviewed` | /harvest review | Artifacts analyzed |
| `generalization_actions` | /harvest review | Recommendations acted on |

## When to invoke /harvest

- Harvesting an artifact from `.scratch/` to `harvesting/`
- Reviewing harvesting/ contents for promotion
- Running generalization analysis (`/harvest review`)
- Manually promoting or pruning an artifact
- User says /harvest

## Cross-References

- Harvesting governance: `@.claude/rules/artifact-harvesting.md`
- Ephemeral scratch: `/scratch` skill
- Source discipline: `reference/framework-artifact-harvesting.md`
- Governed data access: `@.claude/rules/governed-data-access.md`
