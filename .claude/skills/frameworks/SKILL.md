---
name: frameworks
description: "Read the framework registry and add new frameworks.
  Use when checking if a framework exists, looking up a framework's
  artifacts, adding a new adopted framework, or discussing which
  discipline governs a decision point."
---

## Intent

**Purpose**: Provide governed access to the framework registry and
the process for adding new frameworks. **Scope**: Reading framework
entries from `@reference/framework-registry.json`, adding new
frameworks with user approval, and checking framework coverage for
a domain. NOT the adoption lifecycle (see
`@reference/framework-adoption.md`). NOT individual framework
documentation (see `reference/framework-*.md` files). **Audience**:
Any agent checking whether a framework addresses their decision
point, or adding a new adopted framework.

## Reading frameworks

1. Read `@reference/framework-registry.json`
2. Look up in `frameworks` array by name, discipline, or governed
   domain
3. Present the entry with: name, what it governs, source discipline,
   key concepts, reference file, and implementing artifacts
4. If the caller needs the full framework documentation, point to
   the `referenceFile` path

### Checking coverage

Given a domain or decision point:

1. Read the registry
2. Search `governs` fields for relevant frameworks
3. If found: present the framework and its artifacts
4. If not found: this is a governance gap — the domain has no
   governing framework. Report as a potential framework adoption
   opportunity per `@reference/framework-adoption.md`

## Adding a framework

When a new framework has been designed through the DTCC (steps 4-6
of `@reference/framework-adoption.md`):

1. Check `@reference/framework-registry.json` — is it already
   registered?
2. Check the `pending` array — is it tracked as pending adoption?
3. If not registered, draft the entry:

### Required fields

```json
{
  "name": "Human-readable framework name",
  "governs": "What domain or class of decisions this framework covers",
  "discipline": "Source discipline (e.g., Quality management, Information security)",
  "concepts": ["Key concept 1", "Key concept 2"],
  "referenceFile": "reference/framework-<name>.md",
  "artifacts": [
    "List of implementing artifacts (rules, skills, hooks, reference files)"
  ]
}
```

### For pending adoptions

Frameworks discovered but not yet fully adopted go in the `pending`
array with:

```json
{
  "name": "Framework name",
  "governs": "What it would cover",
  "discipline": "Source discipline",
  "concepts": ["Key concepts"],
  "gap": 0,
  "referenceFile": "reference/gap-NNN-short-name.md or null"
}
```

### Writing the changes

1. Draft the JSON entry with all required fields
2. If adding to `frameworks` (not `pending`), verify:
   - Reference file exists (`reference/framework-<name>.md`)
   - At least one implementing artifact exists
   - Entry in `.claude/rules/frameworks.md` is not needed (the rule
     reads from the registry, not a static list)
3. Present for review — `framework-registry.json` is protected per
   `@.claude/rules/sources-of-truth.md`
4. Write if approved

## Cross-References

- Framework rule: `@.claude/rules/frameworks.md`
- Registry data: `@reference/framework-registry.json`
- Adoption lifecycle: `@reference/framework-adoption.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Governance audit: `/audit` skill (validates framework health)
- Gap filing: `/gap` skill (when coverage gap found)
