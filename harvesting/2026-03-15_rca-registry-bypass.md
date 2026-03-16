# RCA: Tool Registry Governed Data Access Bypass

**Date**: 2026-03-15
**Incident**: Main agent read `reference/tool-registry.json` directly after loading `/tool-registry` skill
**Severity**: Medium (governance violation, no data corruption)

---

## Timeline

1. User asked to load `/tool-registry` skill and view Claude Code entry
2. Skill loaded successfully -- its SKILL.md says to read `@reference/tool-registry.json`
3. Main agent used Grep to search `reference/tool-registry.json` directly
4. File does not exist (only `reference/tool-registry.md` exists)
5. Agent caught itself, fell back to `.md` file
6. User flagged the bypass: "hey why were you trying to read the registry json directly"

## Root Cause Analysis

### Finding 1: The skill references a file that does not exist

The `/tool-registry` skill (`SKILL.md`) references `@reference/tool-registry.json`
**six times** (lines 20, 64, 72, 102, and in headings). This file does not exist.
The actual data file is `reference/tool-registry.md` (markdown, not JSON).

This is the **primary cause** of the bypass. The agent loaded the skill, read
its instruction "Read `@reference/tool-registry.json`", and attempted to do
exactly that. The skill itself directed the agent to access the file directly --
which is the correct behavior per the governed-data-access rule (skills ARE
allowed to reference file paths). The problem is the path is wrong.

### Finding 2: The registries table also references the phantom file

`.claude/rules/frameworks.md` line 30:
```
| Tool registry | `@.claude/rules/tool-lifecycle.md` | `@reference/tool-registry.json` | -- | `/tool-registry` |
```

This is a second source of the wrong path. The `@` reference in rules files
is not auto-resolved (per CC v2.1.x behavior), so it does not load the file
into context. But it provides the path as a text pointer, reinforcing the
agent's belief that `tool-registry.json` exists.

### Finding 3: Gap #21 already documents this as an open migration

`reference/incidents.json` gap #21:
- **Title**: "Tool registry is markdown -- needs migration to three-layer pattern"
- **Status**: open
- **Filed**: 2026-03-14

The gap correctly identifies that `tool-registry.md` needs to become
`tool-registry.json` to match the three-layer pattern (rule + JSON + skill).
The suggested resolution: "Migrate to: tool-registry.json (structured data,
single source of truth), per-tool reference files (reference/tool-*.md),
/tools read skill, /tool-eval write skill."

### Finding 4: The skill was written as if migration had already happened

The skill's schema section (lines 72-88) describes a `schemaVersion: "2.0"`
JSON structure with sections like `install`, `delivery`, `health`,
`evaluation`, `lifecycle`, `versions`, `maintenance`, `authentication`,
`nonPreferredMethods`, `buildPrereqs`, `knownPaths`, `overrides`. None of
this exists yet -- the actual registry is a flat markdown file.

The skill was written to spec (the target state) rather than to reality
(the current state). This is the "specs vs state" design principle violation
flagged in CLAUDE.md: "Never describe a feature as 'working' if it hasn't
fired in production."

### Finding 5: The governed-data-access bypass check has a blind spot

Pre-commit step 16 uses this filter to exclude table rows from the bypass
audit:
```bash
grep -v '^.*:.*|.*|.*|.*|'
```

This correctly excludes the `frameworks.md` registries table. But the
exclusion means the phantom `@reference/tool-registry.json` reference in
`frameworks.md` is never flagged. This is acceptable IF the file actually
existed (table rows in the registries table are the canonical place to list
data files). The problem is the file doesn't exist.

### Finding 6: Tool registry is the ONLY registry still in markdown

| Registry | Data File | Exists? | Format |
|----------|-----------|---------|--------|
| Frameworks | `reference/framework-registry.json` | Yes | JSON |
| Incidents | `reference/incidents.json` | Yes | JSON |
| Glossary | `reference/glossary.json` | Yes | JSON |
| Tool registry | `reference/tool-registry.json` | **No** | **N/A** |
| Tool registry (actual) | `reference/tool-registry.md` | Yes | Markdown |
| Tool evaluation | `reference/evaluations/` | Yes | Per-file markdown |
| Artifact harvesting | `harvesting/` | Yes | Directory |

The tool registry is the sole holdout from the three-layer JSON pattern.
`reference/tool-versions.json` exists as a separate version-tracking file,
creating a split source of truth (also noted in gap #21).

## Why the Agent Bypassed the Skill

The agent did NOT bypass the skill -- it followed the skill's own instructions.
The skill said "Read `@reference/tool-registry.json`" and the agent tried to
do exactly that. The governed-data-access rule permits skills to reference file
paths directly. The failure mode was:

1. Skill loaded (correct)
2. Skill instructed agent to read a specific file (correct per governance)
3. File does not exist (the actual defect)
4. Agent searched for the file via Grep (reasonable recovery attempt)
5. Agent found the `.md` file and read that instead (pragmatic fallback)
6. User correctly identified this as suspicious behavior

The bypass appearance was a symptom of the phantom file reference, not a
governance violation by the agent.

## Corrective Actions Needed

### Immediate (fix the phantom reference)

**Option A -- Fix the skill to point to reality:**
Update `SKILL.md` to reference `reference/tool-registry.md` (what actually
exists). Update `frameworks.md` registries table to match. This gets the
skill working today but accepts the markdown-format gap.

**Option B -- Migrate to JSON (resolve gap #21):**
Create `reference/tool-registry.json` with the schema the skill already
describes. Migrate data from `tool-registry.md`. This is the correct
long-term fix but is a large effort (gap #21 says "plan as a roadmap item").

**Recommended**: Option A now, Option B as a planned roadmap item. The skill
should describe reality, not aspiration.

### Medium-term (gap #21 resolution)

1. Add tool-registry migration to ROADMAP.md
2. Plan the migration: markdown -> JSON, merge tool-versions.json data,
   update all consumers (scripts that grep tool-registry.md)
3. Execute migration
4. Update skill to match

### Process improvement

1. **Skill review gate**: When writing a skill that references a data file,
   verify the file exists before shipping. Add to pre-commit checks.
2. **Phantom file detection**: Add a pre-commit step that verifies all
   `@reference/` paths in skills and rules resolve to actual files.
3. **Specs-vs-state audit**: Skills describing JSON schemas for files that
   don't exist yet should be flagged. A skill should describe what IS, and
   a plan or gap should describe what SHOULD BE.

## Files Examined

- `/Users/pepe/repos/aitools/.claude/rules/governed-data-access.md`
- `/Users/pepe/repos/aitools/.claude/rules/frameworks.md` (line 30)
- `/Users/pepe/repos/aitools/.claude/skills/tool-registry/SKILL.md`
- `/Users/pepe/repos/aitools/reference/tool-registry.md` (actual file)
- `/Users/pepe/repos/aitools/reference/incidents.json` (gap #21)
- `/Users/pepe/repos/aitools/.claude/rules/tool-lifecycle.md`
- `/Users/pepe/repos/aitools/scripts/check-pre-commit.sh` (step 16)
- `/Users/pepe/repos/aitools/.claude/rules/sources-of-truth.md`
