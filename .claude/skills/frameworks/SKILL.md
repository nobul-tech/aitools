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

## Where the files live

This is a project skill: its source is `.claude/skills/frameworks/` in the
aitools repo, and it is not deployed to user scope. Claude Code loads it only
in sessions inside the aitools repo, from the checkout. Every repo path below
(`registries/`, `reference/`, `.claude/rules/`, `scripts/`) is relative to the
aitools clone. The cases below for other repos and for machines without a
clone apply only if the skill is deployed to user scope again:

- **Session on aitools** (the clone or one of its worktrees): the paths
  resolve from the repo root. Reads and reviewed writes happen here.
- **Session on any other repo**: use the clone named by `repoPath` in
  `~/.aitools/config.json` (`%USERPROFILE%\.aitools\config.json` on
  Windows). Read current data: `git -C <repoPath> fetch origin`, then read
  `origin/main` (`git -C <repoPath> show origin/main:<path>`), not the
  working tree, which may be stale or hold other agents' edits. Never edit
  that checkout's working tree from another repo's session. A reviewed
  write goes on a new branch in a worktree created from `origin/main`
  (`git -C <repoPath> worktree add -b <branch> <path> origin/main`) and
  ships as a PR; if that is not possible, open an issue on
  `nobul-tech/aitools` with the drafted change.
- **No clone on this machine**: read the read-only copies under
  `~/.aitools/registries/` and `~/.aitools/reference/` once deploy-harness
  installs them. Never edit those copies; propose the change as an issue on
  `nobul-tech/aitools` instead.
- **None of these exist**: say the data is unavailable and stop. Do not
  answer from memory.

## Reading frameworks

1. Read `@registries/framework-registry.json`
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

1. Read current entry from `@registries/framework-registry.json`
2. Identify what changed:
   - **Artifacts** — new rules, skills, data files added or removed?
     Verify each artifact path exists.
   - **Concepts** — new concepts introduced? Old concepts no longer
     relevant?
   - **Governs** — scope expanded or narrowed?
3. Check the reference file (`referenceFile`) — does it reflect the
   changes? Flag for separate update if stale.
4. Write the updated entry with all required fields + updated
   `lastUpdated`, as a version
5. Commit it; list the entry old -> new under "Review after" in the
   commit or PR body, and the commander reviews the diff after (D-DEL5,
   user rule `delegation.md`)

### Staleness

Entries without `lastUpdated` or with `lastUpdated` >90 days old
are stale. No skill or check flags them today: check `lastUpdated`
whenever you read an entry. Stale entries MUST be reviewed —
artifacts may have been added, removed, or renamed without the
registry being updated.

## Adding a framework

When a new framework has been designed through the DTCC (steps 4-6
of `@reference/framework-adoption.md`):

1. Check `@registries/framework-registry.json` — is it already
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
3. Write it as a version and commit it; list it under "Review after"
   in the commit or PR body (D-DEL5)

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
- Incident filing: `/incident` skill (when coverage gap found)
