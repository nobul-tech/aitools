# Cross-Reference Integrity Investigation Report

**Date**: 2026-03-16
**Investigator**: S2 Cross-Reference Integrity Investigator
**Repo**: `/Users/pepe/repos/aitools`

---

## Investigation 1: Phantom tool-registry.json

### Status: CONFIRMED -- phantom reference, no corrective action taken

The RCA at `harvesting/2026-03-15_rca-registry-bypass.md` fully documents
the root cause. Summary:

- `reference/tool-registry.json` does **NOT exist**
- The actual data file is `reference/tool-registry.md` (markdown)
- Incident I21 in `reference/incidents.json` tracks the migration need

### Files referencing the phantom (active references that would mislead agents)

| File | Line | Type | Severity |
|------|------|------|----------|
| `.claude/rules/frameworks.md` | 30 | `@` ref in registries table | **HIGH** -- always in agent context |
| `.claude/skills/tool-registry/SKILL.md` | 20 | `@` ref in "Reading tool entries" | **CRITICAL** -- direct agent instruction |
| `.claude/skills/tool-registry/SKILL.md` | 64 | `@` ref in "Updating version tracking" | **CRITICAL** -- direct agent instruction |
| `.claude/skills/tool-registry/SKILL.md` | 72 | backtick path in "Schema" | **HIGH** -- describes non-existent schema |
| `.claude/skills/tool-registry/SKILL.md` | 102 | `@` ref in "Cross-References" | **HIGH** -- reinforces phantom |

### Files referencing the phantom (descriptive/historical only -- not broken)

| File | Lines | Context |
|------|-------|---------|
| `harvesting/2026-03-15_rca-registry-bypass.md` | multiple | The RCA itself |
| `harvesting/2026-03-15_aar-tool-ops-plan.md` | 104, 418 | AAR documenting the problem |
| `harvesting/2026-03-16_aar-tool-ops-plan.md` | 104, 418 | AAR copy (harvesting artifact) |
| `RELEASE_NOTES.md` | 152 | Historical release note |
| `reference/incidents.json` | 405 | Incident I21 documenting the migration need |

### What an agent would experience invoking /tool-registry right now

1. Agent loads `.claude/skills/tool-registry/SKILL.md`
2. Step 1 says: "Read `@reference/tool-registry.json`"
3. Agent attempts to read it -- **file not found**
4. Agent may fall back to grepping for it, discover `tool-registry.md`
5. Agent reads `tool-registry.md` but encounters a schema mismatch:
   the skill describes a `schemaVersion: "2.0"` JSON structure with
   sections like `install`, `delivery`, `health`, `evaluation` -- none
   of which exist in the markdown file
6. Agent is confused, may present incomplete or wrong data

**The RCA recommended Option A (fix skill to point to reality) as an
immediate action. This was NOT done.** No corrective action was taken
despite the RCA being filed on 2026-03-15.

---

## Investigation 2: maintenanceFile anomaly

### Status: NOT a current defect -- resolved by the consolidation

The `maintenanceFile` field in `reference/tool-versions.json` line 22:
```json
"claude-code": {
  "maintenanceFile": "tool-ops-claude-code.md"
}
```

The file `reference/tool-ops-claude-code.md` **EXISTS**. It was created
during the v0.61.2 consolidation when `claude-code-maintenance.md`,
`claude-code-practices.md`, and `claude-code-windows-shell.md` were merged.

### AAR context

The AAR at `harvesting/2026-03-16_aar-tool-ops-plan.md` line 418-419 says:
> "Known states documented (phantom tool-registry.json, maintenanceFile
> pointing to file being deleted, unfiled findings from this session)."

This referred to a **transient state during the planning session** where
the consolidation was being planned but not yet executed. The consolidation
has since been completed:
- `RELEASE_NOTES.md` line 39 documents the merge
- `reference/tool-ops-claude-code.md` exists and is the correct target

### Minor issue: path format

The `maintenanceFile` value is `tool-ops-claude-code.md` (filename only),
while the `_meta.relatedDocs.claudeCodeMaintenance` value is
`reference/tool-ops-claude-code.md` (with directory prefix). This
inconsistency is cosmetic -- check scripts handle it correctly (line 490
and 548 of the check-post-push scripts skip `maintenanceFile` entries).

**Verdict**: No action needed. The anomaly documented in the AAR has been
resolved by the consolidation.

---

## Investigation 3: Broad Cross-Reference Audit

Automated scan of `.claude/rules/`, `.claude/skills/`, `.cursor/rules/`,
`reference/`, `CLAUDE.md`, and `ROADMAP.md`. Raw output: 86 matches.
After classification, here are the **real broken references** (not false
positives from template patterns, function names, or test fixtures).

### Category A: Phantom file references (files that never existed or were deleted)

| # | Source File | Line | Broken Reference | Severity | Notes |
|---|-----------|------|-----------------|----------|-------|
| 1 | `.claude/rules/frameworks.md` | 30 | `@reference/tool-registry.json` | HIGH | Phantom -- see Investigation 1 |
| 2 | `.claude/skills/tool-registry/SKILL.md` | 20,64,72,102 | `@reference/tool-registry.json` | CRITICAL | Phantom -- see Investigation 1 |
| 3 | `.claude/skills/harvest/SKILL.md` | 29,69 | `@reference/harvest-manifest.json` | HIGH | Actual file is `harvesting/harvest-manifest.json` (wrong directory) |
| 4 | `.cursor/rules/documentation-standards.mdc` | 36 | `@.claude/rules/cursor-rule-parity.md` | MEDIUM | Deleted in v0.54 -- stale reference |
| 5 | `reference/cursor-practices.md` | 160 | `.claude/rules/cursor-rule-parity.md` | MEDIUM | Deleted in v0.54 -- stale reference |
| 6 | `reference/claude-code-effectiveness.md` | 117 | `.claude/rules/surface-silent-failures.md` | LOW | Deleted/renamed rule -- historical reference in effectiveness tracker |
| 7 | `reference/claude-code-effectiveness.md` | 128 | `deploy-paths.md` | LOW | Short name without path prefix -- ambiguous |
| 8 | `reference/tool-ops-claude-code.md` | 45 | `.claude/rules/post-push.md` | MEDIUM | No such rule exists |
| 9 | `reference/tool-ops-claude-code.md` | 63 | `.claude/rules/pre-commit.md` | MEDIUM | No such rule exists |
| 10 | `reference/cursor-practices.md` | 42 | `.cursor/mcp.json` | LOW | Repo-local MCP config -- may not be committed |
| 11 | `reference/cursor-practices.md` | 184 | `.cursor/skills/` | LOW | Directory doesn't exist in repo |

### Category B: Planned but not yet created (future files referenced in test fixtures or aspirational docs)

| # | Source File | Line | Reference | Notes |
|---|-----------|------|-----------|-------|
| 12 | `.claude/skills/tool-ops/tests/expected-behaviors.md` | 70 | `reference/tool-ops-cursor.md` | Test fixture -- describes expected behavior for a future tool-ops entry |
| 13 | `.claude/skills/audit/tests/expected-behaviors.md` | 12-13 | `@reference/nonexistent.md`, `@.claude/rules/cursor-rule-parity.md` | **Intentional** test cases for the audit skill's detection accuracy |
| 14 | `reference/plans/warp-big-maybe.md` | 11,36,60 | `reference/warp-setup.md`, `reference/warp-practices.md` | Speculative plan -- warp terminal files never created |

### Category C: False positives (not real broken refs)

These 72 entries are NOT broken references -- they are:

- **Function names in backticks** (19 instances): `deploy_managed_file`,
  `deploy_tracker_record`, etc. -- these are function names, not file paths
- **Template patterns** (12 instances): `scripts/setup-<tool>.sh`,
  `reference/<name>.json`, etc. -- generic patterns with angle brackets
- **Runtime artifacts** (5 instances): `deploy.log` -- created at runtime,
  not committed
- **Dual-script shorthand** (8 instances): `scripts/setup-user-claude.sh/.ps1`
  -- convention meaning "both .sh and .ps1 variants"
- **Windows path format** (1 instance): `shared\claude-shared.md` --
  backslash path in CLAUDE.md cross-platform table
- **Script prefix without extension** (1 instance):
  `scripts/aitools-install` -- shorthand for both `.sh` and `.ps1`

---

## Summary of Actionable Findings

### CRITICAL (agent-breaking)

1. **`/tool-registry` skill is broken** -- references `reference/tool-registry.json`
   which does not exist. Any agent invoking this skill will fail on step 1.
   The RCA recommended fixing the skill to point to `reference/tool-registry.md`
   as an immediate action. **This was not done.** (4 references in SKILL.md)

2. **`/harvest` skill has wrong manifest path** -- references
   `@reference/harvest-manifest.json` but actual file is
   `harvesting/harvest-manifest.json`. The `shared/hooks/harvest-session.sh`
   hook correctly uses `harvesting/harvest-manifest.json` (line 105, 159),
   so the hook works but the skill directs agents to the wrong location.
   (2 references in SKILL.md)

### HIGH (misleading agent context)

3. **`frameworks.md` registries table** lists `@reference/tool-registry.json`
   as the tool registry data file. This is in `.claude/rules/` which is
   always in context, continuously reinforcing the phantom.

### MEDIUM (stale references from deleted files)

4. **`cursor-rule-parity.md`** deleted in v0.54 but still referenced by:
   - `.cursor/rules/documentation-standards.mdc` line 36
   - `reference/cursor-practices.md` line 160

5. **`.claude/rules/post-push.md` and `.claude/rules/pre-commit.md`**
   referenced in `reference/tool-ops-claude-code.md` lines 45 and 63
   but do not exist. The actual checklist files are in `reference/`
   (`reference/pre-commit-checklist.md`, `reference/post-push-checklist.md`).

### LOW (cosmetic or historical)

6. Various stale references in `reference/claude-code-effectiveness.md`
   (historical effectiveness tracker) and `reference/cursor-practices.md`
   (`.cursor/mcp.json`, `.cursor/skills/` directory).

---

## Corrective Actions Recommended

### Immediate (fix agent-breaking issues)

1. **Fix `/tool-registry` skill**: Update SKILL.md lines 20, 64, 72, 102
   to reference `reference/tool-registry.md` instead of
   `reference/tool-registry.json`. Update schema section to describe
   the actual markdown format, not the aspirational JSON format.

2. **Fix `/harvest` skill**: Update SKILL.md lines 29 and 69 to reference
   `harvesting/harvest-manifest.json` instead of
   `@reference/harvest-manifest.json`.

3. **Fix `frameworks.md` registries table**: Update line 30 to reference
   `reference/tool-registry.md` instead of `@reference/tool-registry.json`.

### Short-term (fix stale references)

4. **Fix `documentation-standards.mdc`**: Remove or update the
   `cursor-rule-parity.md` reference on line 36.

5. **Fix `cursor-practices.md`**: Remove or update the
   `cursor-rule-parity.md` reference on line 160.

6. **Fix `tool-ops-claude-code.md`**: Change `.claude/rules/post-push.md`
   to `reference/post-push-checklist.md` and `.claude/rules/pre-commit.md`
   to `reference/pre-commit-checklist.md`.
