# Manual Rule Changes Required

These changes were blocked by permission restrictions on `.claude/rules/` files.
Apply them manually or grant Edit permission and re-run.

---

## 1. `.claude/rules/glossary.md` -- Add 13 terms to word list

Insert these terms (alphabetically) into the `### Terms` section,
after `verified` and before the blank line before `### When to invoke /glossary`:

```
accepting session
assumption
Auftrag
blast radius
blocker
cross-boundary
delegating agent
handoff
Lagebeurteilung
lifecycle transition
Mitdenken
Reibung
Schwerpunkt
```

---

## 2. `.claude/rules/incident-governance.md` -- P-2 ambiguity routing

### Change 1: Add row to "What does NOT go here" table

After the `| Tool evaluation | /tool-eval skill |` row, add:

```
| Terminological ambiguity | `/glossary` skill (see ambiguity routing) |
```

### Change 2: Add step to decision tree

After step 2, insert:

```
3. A term has multiple meanings, or a key concept has no definition? -> `/glossary` skill
```

And renumber existing steps 3-4 to 4-5.

### Change 3: Replace surfacing duty section

Replace the entire `### Surfacing duty` section (lines 133-145) with:

```markdown
### Surfacing duty

Every planning and coding session must actively look for deficiencies.
This is continuous, not periodic:

- Reading a rule? Is it clear? Could it be read two ways?
- Following a cross-reference? Does the target exist and match?
- Making a decision with no rule? Is that a governance incident?
- Something broke in production? File with root cause analysis.
- Using a term? Is the meaning clear and consistent across the harness?

#### Ambiguity routing

Found something? Route it by type:

- **Terminological ambiguity** (a term has multiple meanings, two
  terms mean the same thing, or a key concept has no governed
  definition): file via the `/glossary` skill.
- **Structural ambiguity** (a spec is unclear, contradictory, or
  missing; code deviates from spec; an operational incident
  occurred): file via the `/incident` skill.

If mid-task and cannot file immediately, leave a `TODO(incident):`
or `TODO(glossary):` comment in the current file. The `/audit` skill
scans for unfiled markers.
```

### Change 4: Update audit skill interface

In the `### Skill interfaces` section, update the `/audit` bullet:

```
- Reports: incidents, inconsistencies, broken cross-references, stale entries,
  duplicate IDs, unfiled `TODO(incident):` and `TODO(glossary):` markers
```

### Change 5: Update intent scope line

In the `**Intent**:` block at the top, add `ambiguity routing` to the scope:

```
**Scope**: Filing process, severity classification,
lifecycle states, surfacing duty, ambiguity routing, staleness rules,
hook specifications.
```

### Change 6: Fix typo

Line 186: `disci pline` should be `discipline` (remove extra space).

---

## 3. `.claude/rules/aitools-workspace.md` -- Add handoffs row

In the `### Workspace structure` table under `Project-scoped`, after the
`channel/running-estimate.json` row, add:

```
| `channel/handoffs/` | tracked | Handoff prompts from completed sessions (see `/handoff` skill) |
```

---

## 4. Deployment

After applying rule changes, deploy updated skills:

```bash
cp shared/skills/handoff/SKILL.md ~/.claude/skills/handoff/SKILL.md
cp shared/skills/handoff/SKILL.md ~/.cursor/skills/handoff/SKILL.md
cp shared/skills/scratch/SKILL.md ~/.claude/skills/scratch/SKILL.md
```
