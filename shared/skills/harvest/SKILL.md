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

## Where the files live

This is a user-level skill: `aitools install` deploys it to
`~/.claude/skills/` and `~/.cursor/skills/`, so it loads in every repo.
Its source is `shared/skills/harvest/` in the aitools repo.

- `.scratch/`, `harvesting/` and `harvesting/harvest-manifest.json` belong
  to the **current** repo (harvesting runs in every project).
- The governance and inventory paths (`.claude/rules/`, `reference/`,
  `scripts/`, `shared/skills/`) are in the aitools clone: on aitools they
  resolve from the repo root; elsewhere use the clone named by `repoPath` in
  `~/.aitools/config.json` (`%USERPROFILE%\.aitools\config.json` on Windows).
  A promotion into the harness is a change to that clone.

## Harvesting an artifact

When a session produces reusable code, prompts, or patterns:

1. Copy (do not move) the file from `.scratch/session-<id>/` to
   `harvesting/`; the SessionEnd/SessionStart harvester does this
   automatically for every non-ephemeral top-level file.
2. Name: `<UTC date>_session-<id10>_<original name>` (the harvester adds
   `_<n>_` on a name collision).
3. The manifest entry in `@harvesting/harvest-manifest.json` is written by
   the harvester (`type` defaults to `code`, `description` to
   "Auto-harvested from session scratch", `pruneAfter` = harvested + 30
   days); correct `description`, `type` (code | prompt | research |
   pattern) and `language` (python | bash | powershell | markdown | null)
   by hand when you promote.
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

The harvester itself creates only `{"schemaVersion": "1.0", "lastAudit":
null}` in `meta`; `governance` and `skill` are optional, hand-maintained
keys.

Status lifecycle: `harvested` → `candidate` → `promoted` | `pruned`

## Evaluating artifacts (SessionStart)

At SessionStart (`session-catchup.sh` → `ait-harvest.py catchup`), entries
past `pruneAfter` (harvested + 30 days) whose status is not
`promoted`/`pruned` are re-classified: referenced in git history under
`harvesting/` → `candidate`; otherwise → `pruned`. Pruning only changes the
manifest status; the file stays in `harvesting/` until removed by hand.
There is no "keep" flag and no 7-day rule yet (the governance rule's
criteria are ahead of the code). `meta.lastAudit` is updated when anything
changes. No KPI is shipped.

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

Auto-pruning at SessionStart (see above) only sets `status: "pruned"` in the
manifest; it never deletes the file. Delete a pruned file by hand if it is
no longer wanted.

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

Planned, not implemented: no hook or script emits these KPIs today.

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
