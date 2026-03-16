---
name: governed-data
description: "Manage governed data access — add new governed registries,
  audit compliance, verify three-layer enforcement. Use when creating
  a new JSON registry, checking if a file should be governed, or
  auditing governed data access patterns."
---

## Intent

**Purpose**: Implement the governed data access process — adding new
governed registries, auditing compliance with the access principle,
and maintaining the three-layer enforcement pattern. **Scope**: The
operational process for governed data management. NOT the access
principle itself (`@.claude/rules/governed-data-access.md`). NOT the
source discipline documentation
(`reference/framework-governed-data-access.md`). NOT the registries
table (`@.claude/rules/frameworks.md`). **Audience**: Any agent
creating a new JSON registry, auditing governed data compliance, or
checking whether a file should be governed.

## Content placement standard

Each layer has a distinct role. Duplicating content across layers
causes drift.

- **Reference files** describe WHAT was adopted and WHY (concepts,
  discipline credits, rationale). They name concepts and point to
  rules/skills for requirements and processes. They NEVER state
  requirements or contain operational procedures.
- **Rules** state REQUIREMENTS (MUST/MUST NOT, gates, enforcement).
  They delegate process to skills and depth to reference files.
  They are lean governance.
- **Skills** contain PROCESSES (steps, criteria definitions,
  validation, templates). They point to rules for authority.

A reference file that states requirements is duplicating the rule.
A rule that describes processes is duplicating the skill. Name the
concept in the reference file, state the requirement in the rule,
implement the process in the skill.

## Adding a new governed registry

When creating a new JSON registry that requires skill-gated access:

1. **Create the governing skill** — the process for reading and
   writing the registry. The skill's SKILL.md is the ONLY non-programmatic
   file that may reference the JSON file path.
2. **Add trigger directive** to the governing rule — states WHEN
   to invoke the skill. Uses imperative language ("Invoke /skill
   when...").
3. **Design the detection hook spec** — what to detect when the
   governed file is accessed directly.
4. **Add to registries table** in `@.claude/rules/frameworks.md`
   via the `/frameworks` skill.
5. **Apply controlled distribution** — reference the SKILL in all
   rules and documentation, never the JSON file path.
6. **Update pre-commit** — add the file to step 16's governed
   files list in `scripts/check-pre-commit.sh/.ps1`.

All artifacts are created together. A governed file without its
skill is ungoverned data. A skill without its trigger directive is
ungoverned process.

## Auditing compliance

Check whether governed data access is being bypassed:

1. Run pre-commit step 16 — checks `.claude/rules/` and `CLAUDE.md`
   for direct JSON references
2. Search reference files for governed JSON paths:
   `grep -rn 'glossary\.json\|framework-registry\.json\|incidents\.json\|tool-registry\.json\|tool-ops\.json' reference/*.md`
3. Search skills for JSON paths that shouldn't be there (skills
   other than the governing skill referencing the JSON)
4. Report findings — each hit is a bypass vector to fix

## When to invoke /governed-data

- Creating a new JSON registry
- Auditing governed data compliance
- Checking whether a file should be governed (file classification)
- Discussing the content placement standard (reference vs rule vs skill)
- User says /governed-data

## Cross-References

- Access principle: `@.claude/rules/governed-data-access.md`
- Source disciplines: `reference/framework-governed-data-access.md`
- Registries table: `@.claude/rules/frameworks.md`
- Pre-commit enforcement: `scripts/check-pre-commit.sh/.ps1` step 16
