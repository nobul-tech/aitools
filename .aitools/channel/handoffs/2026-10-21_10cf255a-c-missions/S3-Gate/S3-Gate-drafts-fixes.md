# S3-Gate drafts fixes: S4 §2 "Not fixed in a copy", applied

**Intent**: **Purpose**: Record which S4-Review-C findings S3-Gate applied to copies of the S5-Tools drafts, and which remain known defects, so the commander reviews the corrected copies, not the originals. **Scope**: The four S5-Tools drafts that S4-Review §2 "Not fixed in a copy" names (`/tool-adopt`, `/tool-eval`, `/tool-registry` SKILL.md, `framework-tool-lifecycle.md`). NOT the decision tree (rev 4 changelog). NOT the drafts S4-Review already corrected. **Audience**: The commander at the gate; the agent that later writes these protected files.

Originals (read-only provenance): `/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions/S5-Tools/S5-Tools-drafts/`. Corrected copies: `S3-Gate-drafts/dot-claude/skills/{tool-adopt,tool-eval,tool-registry}/SKILL.md` and `S3-Gate-drafts/reference/framework-tool-lifecycle.md`. Each has a `.s5-to-s3gate.diff` next to it. The folder is named `dot-claude/`, never `.claude/` (nested-skill hazard, handoff section I).

## Applied

| Finding | File | Change |
|---|---|---|
| C-08 (major) | tool-adopt step 3 | The 11-bullet field list is replaced with "every field in the reference section 'Tool registry schema 1.1' that the entry lacks, for every method on each target platform", validated by conformance checks 1-6. The research-source rule is kept. This removes the three contradictions: `kind` everywhere, `update` required, one preferred method "per environment" |
| C-08 | tool-eval step 7 | "its `kind`, `package`, `family` (Linux), update command" is replaced with "the data the reference 'Tool registry schema 1.1' requires for that method" |
| C-08 | tool-registry step 1 | The `install` / `update` / `updateChannel` bullets become one "Decision-tree data" bullet pointing to the reference, validated by checks 1-6. The lifecycle bullet keeps only the non-tree fields |
| C-09 (rest) | tool-adopt step 3; tool-eval step 7; framework table row "Release management" | The channel list and default are no longer restated; they point to the reference "Update channels" |
| C-22 (minor) | tool-adopt step 7; tool-eval step 9 | "a new exception rule" / "an exception to the decision tree" become "a deviation from the decision tree" (the governed "tool exception" is per machine) |
| C-28 (minor) | all three skills | Section numbers become section titles: "Setup script shape after migration", "Test matrix", "Leaves: log line, summary row, ACTION, exit", "Update channels", "Install-method detection", "Tool registry schema 1.1", "Pre-commit conformance check" |
| C-33 (minor) | framework-tool-lifecycle.md | DRAFT banner moved above the `**Intent**` block |

Also applied. S4-Review lists these as fixed, but the fix had only reached the rule and tree drafts, not these files:

| Finding | File | Change |
|---|---|---|
| C-13 | tool-adopt frontmatter `description`; framework "Planned hook" line | "changing any scripts/setup-* script" becomes "changing a tool setup script (one named by a registry lifecycle.setupScript)" |
| C-23 | framework cross-reference | "the other 'adopt'" becomes "the managed-file 'adopt'" |
| C-26 | framework table row "Verification after change" | "script-standards Standard 4" becomes `@reference/script-standards-detail.md` "Standard 4" |
| C-27 | framework table row "Make-before-break" | "(issue #12)" becomes "(GitHub issue #12)" |
| rev 4 | tool-registry Schema section and table; tool-adopt step 4 | Names the new `resolveBy` field (rev 4 §6). The step 4 shape cites "bash and PowerShell" (rev 4 §7.6) |

No intent statement was changed. The only edits near an intent are the S3-Gate banner lines, which sit outside the `**Intent**:` text.

## Known defects left in these copies

- **Paths depend on S2-Layout PR-b.** All three skills live under `.claude/skills/` in these drafts. If PR-b is approved, `/tool-eval` and `/tool-registry` move to `shared/skills/`, and `@registries/tool-registry.json` becomes a resolver call (`aitools-registry.py`). `/tool-adopt` stays project-level (S2-Layout §5 "Sibling-mission impacts"). The copies are not retargeted, because the sequencing question (review page item C-SEQ) is open.
- **C-14 "detection signature"** is a pending glossary decision (review page section c). The copies keep "detection signatures" (registry description) and "detection layer" (framework hook line) as they were.
- **tool-registry still cites `@registries/tool-registry.json` in prose.** This is allowed for the governing skill (governed-data-access.md "What may reference JSON file paths").
- **Framework "Implementing Artifacts"** lists `.claude/skills/tool-eval/SKILL.md` and `tool-registry` at their current paths (same PR-b dependency).
