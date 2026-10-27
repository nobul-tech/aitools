# S3-FanoutImpl-DocsScan: proposed glossary entries (fan-out vocabulary)

By S3-FanoutImpl-DocsScan, 2026-10-26, for the FO-7 writer. Read through
the `/glossary` skill ("Reading definitions": `terms`, `facets`; required
fields `definition`, `source`; optional `abbreviationOf`,
`sourceDiscipline`). Both `registries/glossary.json` and
`.claude/rules/glossary.md` are protected: write them together, as a version
in the FO-7 PR, listed under "Review after" (FD-8; the skill's "Writing the
changes" steps 1-4). Glossary `meta.lastUpdated` on main: 2026-10-21.

## 1. Are they governed today?

| Term | In `.claude/rules/glossary.md` | In the glossary JSON | Close governed terms |
|------|-------------------------------|----------------------|---------------------|
| fan-out | no | no | -- |
| retired | no | no | -- |
| removed | no | no | deployment outcomes `created`, `updated`, `verified`, `skipped`, `preserved`, `recovered`, `accept & adopt` |
| harness files | no | no | `harness` (the whole aitools system) |
| trigger directive | no | no | `trigger` (the DTCC start event) |

Check method: a scan of `terms` keys for `fan`, `retir`, `remov`,
`harness file`, `directive` returned nothing (glossary skill, read
2026-10-26); the rule's word list (in context) has none of them.

## 2. Proposed term entries (`terms`)

```json
"fan-out": {
  "definition": "The deployment step that copies the deployed harness's rules and skills (~/.aitools/rules, ~/.aitools/skills) into each tool's own user location: setup-user-claude to ~/.claude/rules and ~/.claude/skills, setup-user-cursor to ~/.cursor/rules (converted to .mdc) and ~/.cursor/skills. Every name except the retired ones is fanned out; the fan-out updates its own copies, removes its own copies of retired names, and preserves every other file. Distinct from deploy-harness, which fills ~/.aitools from the repos.",
  "source": "reference/rules.md section 6; reference/skills.md section 6; plans/skills-and-rules-fanout.md FD-1..FD-4 (2026-10-26)"
},
"retired": {
  "definition": "Manifest state of a rule or skill: its name was in the previous rules or skills manifest and no source listed on this deploy-harness run has it. deploy-harness backs up and removes its ~/.aitools copy; each fan-out consumer backs up and removes its own deployed copy (outcome: removed). A name is retired only by a source that was listed on the run. Not a deployment outcome.",
  "source": "reference/harness.md \"Rules manifest and retired rules\", \"Skills manifest and retired skills\"; PR #100; plans/skills-and-rules-fanout.md contract 3.2"
},
"removed": {
  "definition": "Deployment outcome: a deployed copy was backed up (backup verified) and deleted because its source retired it. Recorded by a fan-out consumer with deploy_tracker_record / Record-DeployOutcome, counted as 'N removed' in the summary. Not a deploy_managed_file return value. A copy that does not match a harness copy is kept with a warning instead.",
  "source": "reference/managed-file-deployment.md (Functions, Caller Responsibilities); plans/rules-fanout-claude.md Q7 and Batch A"
},
"harness files": {
  "definition": "The summary tool name for deploy-harness: the files it deploys into ~/.aitools (reference, registries, hooks, skills, rules, bin; config.json through setup-user-config). Its OK / WARN / ERROR rows cover that whole step, including name conflicts between sources and manifest writes. Distinct from harness (the whole aitools system).",
  "source": "reference/harness.md \"Deployed harness (~/.aitools)\"; SC-mission-packet.md section 6 (summary name \"harness files\")"
},
"trigger directive": {
  "definition": "The section of a rule that states when to invoke its skill, headed '### When to invoke /<skill>': 'Invoke the /<skill> skill when ANY of these arise:' plus a bullet list ending with the user naming the skill. A rule without one for its skill is a governance gap. Distinct from trigger (the event that starts the DTCC).",
  "source": "reference/framework-three-layer-governance.md \"Rule-skill governance\"; reference/rules.md section 4 item 7"
}
```

Lines for `.claude/rules/glossary.md` "### Terms", appended to the second
block (the block that starts `accepting session`), alphabetical inside it is
not required by the file (the first block is not strictly sorted either):

```
fan-out
harness files
removed
retired
trigger directive
```

## 3. Facet updates (optional, same PR)

`facets.baseArtifacts` today:

```
"rule": "Claude Code rule file (.md in .claude/rules/ or ~/.claude/rules/)",
"skill": "Skill definition (SKILL.md in .claude/skills/, shared/skills/, or ~/.claude/skills/)"
```

Proposed:

```
"rule": "Rule file: .md in .claude/rules/, shared/rules/, the dotprofile claude/rules/, ~/.aitools/rules/ (deployed harness) or ~/.claude/rules/; converted to .mdc in ~/.cursor/rules/",
"skill": "Skill directory with a SKILL.md: in .claude/skills/, shared/skills/, the dotprofile claude/skills/, ~/.aitools/skills/ (deployed harness), ~/.claude/skills/ or ~/.cursor/skills/"
```

The skill's "Adding a base artifact" step says a facet change also updates
the composition examples in `reference/framework-governed-vocabulary.md`
(lines 59 and 72 there: inventory item 54).

## 4. Related wording (not glossary entries)

- `reference/script-standards-detail.md` "Governed summary outcomes" gets a
  `"removed"` row once the term is approved (inventory item 45).
- "trigger" vs "trigger directive": `reference/rules.md` section 4 already
  separates them; the glossary entry makes it governed (rules.md section 9
  TODO(glossary) closes).
- "skills manifest" / "rules manifest": defined in `reference/harness.md`;
  not proposed as terms (file names, not concepts). Say if you want them.

## 5. Provenance

Definitions are built from `plans/skills-and-rules-fanout.md` v1.0 sections
1 and 3, `plans/rules-fanout-claude.md` sections 3, 9 (Q7), the #100 Manifest
draft (`git show feature/fanout-base:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-Manifest/S3-H2-Manifest-drafts/reference/harness.md`),
`reference/rules.md` sections 4 and 6, `reference/framework-three-layer-governance.md`
"Rule-skill governance", and the existing outcome entries (`created`,
`updated`, `preserved`) for style.
