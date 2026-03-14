---
name: glossary
description: "Read governed vocabulary definitions and add new terms.
  Use when checking a term's meaning, adding a new governed term, or
  resolving a terminology ambiguity."
---

## Intent

**Purpose**: Provide access to governed vocabulary definitions and
the process for adding new terms. **Scope**: Reading definitions from
`@reference/glossary.json`, adding new terms with user approval, and
resolving terminology ambiguities. NOT the word list itself (that's
in `@.claude/rules/glossary.md`, always in context). NOT the
composition convention or framework documentation (see
`@reference/framework-governed-vocabulary.md`). **Audience**: Any
agent that encounters a governed term and needs its definition, or
any agent that needs to add a new term.

## Reading definitions

1. Read `@reference/glossary.json`
2. Look up the term in `terms`, `facets.scopeModifiers`, or
   `facets.baseArtifacts`
3. If the term has `abbreviationOf`, follow the reference to the
   full term
4. Present the definition and source

## Adding governed vocabulary

When a word is used repeatedly in conversation or appears in multiple
files without a consistent definition, it should be governed.

1. Check `@.claude/rules/glossary.md` — is it already listed?
2. Check `@reference/glossary.json` — does it have a definition?
3. If not governed, determine what type it is:

### Adding a term

A standalone concept (e.g., `ambiguity`, `framework`, `intent`).

- Draft JSON entry in `terms` with required fields
- Draft corresponding line in the glossary rule under "### Terms"
- If the term has an abbreviation, add both the full term and
  abbreviation as separate lines in the rule, grouped together

### Adding a scope modifier

A new deployment scope (e.g., if a new scope beyond project/shared/
dotprofile/user were needed).

- Draft JSON entry in `facets.scopeModifiers` with the modifier
  name and its meaning
- Draft corresponding line in the glossary rule under
  "### Scope modifiers"
- Update composition examples in
  `@reference/framework-governed-vocabulary.md`

### Adding a base artifact

A new harness artifact type that composes with scope modifiers
(e.g., if a new artifact type beyond alias/claude/config/hook/rule/
skill were introduced).

- Draft JSON entry in `facets.baseArtifacts` with the artifact
  name and what it is
- Draft corresponding line in the glossary rule under
  "### Base artifacts"
- Update composition examples in
  `@reference/framework-governed-vocabulary.md`

### Writing the changes

For all types:

1. Draft the JSON entry with all required fields
2. Draft the corresponding line(s) in the glossary rule
3. Present both for review — both files are protected per
   `@.claude/rules/sources-of-truth.md`
4. Write both if approved

Both files must be updated in the same operation. A term in the JSON
without a line in the rule is invisible to agents. A term in the rule
without a JSON entry has no authoritative definition.

## Resolving ambiguity

When a term is used with multiple meanings (like "scope" or "rule"):

1. Identify all distinct meanings in use
2. Create specific governed terms for each meaning
   (e.g., `intent scope`, `deployment scope`, `scope creep`)
3. Remove the ambiguous standalone term from the glossary
4. Update all files that use the ambiguous term to use the specific
   governed term

## Required fields

### Terms

```json
{
  "definition": "What this term means in our harness",
  "source": "file where this term is primarily defined"
}
```

Optional:
- `abbreviationOf` — for abbreviation entries (e.g., `DP` → `design principle`)
- `sourceDiscipline` — when adopted from an external field

### Scope modifiers

```json
"modifierName": "What this scope means — where artifacts at this scope live"
```

### Base artifacts

```json
"artifactName": "What this artifact type is and where it lives at each scope"
```

## Cross-References

- Word list: `@.claude/rules/glossary.md`
- Definitions: `@reference/glossary.json`
- Framework: `@reference/framework-governed-vocabulary.md`
- Intent audit: `/intent-audit` skill (catches undefined terms)
- Governance audit: `/audit` skill (validates glossary health)
