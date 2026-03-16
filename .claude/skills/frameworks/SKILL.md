---
name: frameworks
description: "Read, update, and add frameworks in the registry.
  Use when checking if a framework exists, looking up a framework's
  artifacts, updating a stale entry, adding a new adopted framework,
  or discussing which discipline governs a decision point."
---

## Intent

**Purpose**: Provide governed access to the framework registry —
reading entries, updating existing frameworks, adding new ones, and
checking coverage for a domain. **Scope**: All CRUD operations on
the framework registry. NOT the adoption lifecycle (see
`@reference/framework-adoption.md`). NOT individual framework
documentation (see `reference/framework-*.md` files). **Audience**:
Any agent checking whether a framework addresses their decision
point, updating a framework's artifacts, or adding a new framework.

## Reading frameworks

1. Read `@reference/framework-registry.json`
2. Look up in `frameworks` array by name, discipline, or governed
   domain
3. Present the entry with: name, what it governs, source discipline,
   key concepts, reference file, implementing artifacts, lastUpdated
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

## Updating a framework

When a framework's artifacts, concepts, or governance scope change:

1. Read current entry from `@reference/framework-registry.json`
2. Identify what changed:
   - **Artifacts** — new rules, skills, data files added or removed?
     Verify each artifact path exists.
   - **Concepts** — new concepts introduced? Old concepts no longer
     relevant?
   - **Governs** — scope expanded or narrowed?
3. Check the reference file (`referenceFile`) — does it reflect the
   changes? Flag for separate update if stale.
4. Draft updated entry with all required fields + updated
   `lastUpdated`
5. Present for review (protected file)
6. Write if approved

### Staleness

Entries without `lastUpdated` or with `lastUpdated` >90 days old
are stale. The `/audit` skill flags these. Stale entries MUST be
reviewed — artifacts may have been added, removed, or renamed
without the registry being updated.

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
  ],
  "lastUpdated": "YYYY-MM-DD"
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
  "incident": 0,
  "referenceFile": "reference/incident-NNN-short-name.md or null"
}
```

### Writing the changes

For both adds and updates:

1. Draft the JSON entry with all required fields
2. Verify:
   - Reference file exists (`reference/framework-<name>.md`)
   - At least one implementing artifact exists
   - Each artifact path in the list is valid (file or directory exists)
   - `lastUpdated` is set to today
3. Present for review — the registry is protected per
   `@.claude/rules/sources-of-truth.md`
4. Write if approved

## Framework reference file template

Every `reference/framework-*.md` file MUST have these sections:

1. **Intent** — purpose, scope, audience
2. **Source Discipline(s)** — what discipline the concepts come from,
   key authors/works cited
3. **How We Adopted It** — how discipline concepts map to harness
   artifacts
4. **How It's Maintained** — ongoing care, what triggers updates
5. **Implementing Artifacts** — list of rules, skills, data files,
   hooks (reference skills not JSON paths)
6. **Cross-References** — links to related frameworks, rules, skills

When updating a framework, verify the reference file matches the
registry entry. If artifacts diverge, update both together.

## Cross-References

- Framework rule: `@.claude/rules/frameworks.md`
- Governed data access: `@.claude/rules/governed-data-access.md`
- Adoption lifecycle: `@reference/framework-adoption.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Governance audit: `/audit` skill (validates framework health)
- Incident filing: `/incident` skill (when coverage gap found)
