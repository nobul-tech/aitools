# Known State Audit Report

**Date**: 2026-03-16
**Auditor**: Known State Auditor agent

---

## 1. File Existence

| File | Exists? | Notes |
|------|---------|-------|
| `reference/tool-versions.json` | YES | Last updated 2026-03-13 (schemaVersion "1.0") |
| `reference/tool-registry.json` | **NO** | Phantom file -- referenced in 7 files but never created |
| `reference/tool-registry.md` | YES | Actual tool registry data (markdown format) |
| `reference/incidents.json` | YES | Last updated 2026-03-15, 47 incidents total |

## 2. The Phantom `tool-registry.json` Problem

### What happened

The `/tool-registry` skill (`SKILL.md`) references `reference/tool-registry.json`
**six times** (lines 20, 64, 72, 102, and in headings). This file **does not
exist**. The actual data lives in `reference/tool-registry.md` (markdown).

The skill was written to the **target state** (post-migration JSON) rather than
the **current state** (markdown). This violates the "specs vs state" design
principle in CLAUDE.md.

### Where the phantom reference appears

| File | Line | Context |
|------|------|---------|
| `.claude/skills/tool-registry/SKILL.md` | 20, 65, 72, 102 | "Read `@reference/tool-registry.json`" |
| `.claude/rules/frameworks.md` | 30 | Registries table: Data column |
| `reference/incidents.json` | 405 | Incident #21 suggestedResolution |
| `harvesting/2026-03-15_rca-registry-bypass.md` | throughout | RCA documenting the phantom |
| `harvesting/2026-03-16_aar-tool-ops-plan.md` | 103-104 | AAR documenting discovery |
| `harvesting/2026-03-15_aar-tool-ops-plan.md` | (multiple) | Earlier AAR version |
| `RELEASE_NOTES.md` | 152 | v0.55 note about pre-commit step 16 |

### Where `tool-versions.json` is referenced (actual file)

13 files reference `tool-versions.json`, including:
- `.claude/rules/sources-of-truth.md` (line 22) -- lists it as protected
- `ROADMAP.md` (line 25) -- aitools install version capture feature
- `scripts/check-post-push.sh` and `.ps1` -- check scripts
- `RELEASE_NOTES.md` -- multiple version entries
- `.cursor/rules/sources-of-truth.mdc` and `tool-lifecycle.mdc`
- `reference/post-push-checklist.md`

### Key insight: Two files, neither complete

- `tool-versions.json` -- per-platform version tracking (schemaVersion 1.0, 16 tool entries)
- `tool-registry.md` -- install commands, lifecycle, evaluation data (markdown prose)
- `tool-registry.json` -- DOES NOT EXIST (planned target of incident #21 migration)

The split means version data and registry data are in different files and
different formats, creating drift risk.

## 3. Incident Analysis

### Open incidents: 42 total (IDs 1-47, minus 3 closed: 13, 14, plus 5 planned)

**Incidents directly relevant to this audit:**

| ID | Title | Status | Severity | Key detail |
|----|-------|--------|----------|------------|
| **21** | Tool registry is markdown -- needs migration to three-layer pattern | **open** | medium | Core migration incident. Affected: `tool-registry.md`, `tool-versions.json`. Suggests creating `tool-registry.json` as single source of truth. NO linked plan or roadmap item. Filed 2026-03-14. |
| **22** | Incident registry has no read/context skill | open | medium | Related pattern -- another registry gap |

**No incident explicitly tracks:**
- The phantom `tool-registry.json` reference in the skill/frameworks.md
- The "fix the skill to point to reality" corrective action from the RCA
- The `maintenanceFile` field in `tool-versions.json` pointing to a file being deleted (mentioned in AAR line 418)

### Planned incidents (5):
| ID | Title | Severity |
|----|-------|----------|
| 28 | Batch size caused cross-cutting rules skipped | high |
| 30 | Dismissiveness when user challenged subagent results | high |
| 31 | Subagent work product condensed to stub summary | high |
| 32 | Silent hook failure: session-archive hook was no-op | high |
| 33 | Deploy template logic not updated when scripts/ source fixed | medium |
| 42 | Plan lacked platform architecture context for HTTP vs stdio MCP | medium |

### Closed incidents (2):
| ID | Title | Closed in |
|----|-------|-----------|
| 13 | Skill priority was wrong in plan v0.54 | v0.54.1 |
| 14 | Subagent skill preloading -- additionalContext verified | v0.55 |

### Staleness check
All open incidents were filed between 2026-03-07 and 2026-03-15 (1-9 days old).
None exceed the 90-day staleness threshold. However, none of the 42 open
incidents have a `linked` plan or roadmap item except:
- #1 (linked to GitHub issue #51)
- #28, #30, #31, #32, #33, #42 (status: planned, but `linked` field is null for all)

This means 36 open incidents have no linked plan at all.

## 4. AAR and Session Evidence

### From AAR (`harvesting/2026-03-16_aar-tool-ops-plan.md`):

**L103-111**: Documents the phantom discovery:
> "a subagent investigation returns with a critical finding: the `/tool-registry`
> skill references a phantom file (`tool-registry.json`) that doesn't exist.
> The actual data lives in `tool-registry.md`."

> Agent confirms: "the migration was planned (incident #21) but never started.
> The skill was written to the target state, not the current state."

**L217-223**: User introduces "known state" concept:
> "we should note the bad state of tool-registry.md and tool-versions.json
> and reference our conversation"

> User generalizes: "audit our recent conversations and plans for similar
> types of annotations to the known state."

**L418-419**: Known states documented in plan revision 4:
> "Known states documented (phantom tool-registry.json, maintenanceFile
> pointing to file being deleted, unfiled findings from this session)."

**L551**: Registry bypass investigation confirmed the phantom:
> "The registry bypass investigation (L558) revealed the phantom file defect."

### From RCA (`harvesting/2026-03-15_rca-registry-bypass.md`):

Full root cause analysis exists. Six findings documented. Recommended
**Option A** (fix skill to point to reality now) and **Option B** (migrate
to JSON as planned roadmap item). Neither has been executed.

### From session JSONL (`aitools-nobul-jose/sessions/aitools/2026-03-15_eaacf9da.jsonl`):

Extensive references to both `tool-versions` and `tool-registry.json` across
50+ lines of the session transcript, confirming this was a major discussion
topic during the tool-ops planning session.

## 5. The `maintenanceFile` Anomaly

In `tool-versions.json`, the `claude-code` entry has:
```json
"claude-code": {
    "maintenanceFile": "tool-ops-claude-code.md"
}
```

The AAR (line 418) notes this was flagged as a known state: "maintenanceFile
pointing to file being deleted." This suggests `tool-ops-claude-code.md` was
planned for deletion or renaming during the tool-ops work, but the reference
in `tool-versions.json` was not updated.

Checking: `reference/tool-ops-claude-code.md` is still listed in
`sources-of-truth.md` as a protected file, so it likely still exists. The
"file being deleted" may refer to a different file that `maintenanceFile`
was originally pointing to, or to a planned consolidation that hasn't happened.

## 6. Summary of Outstanding Issues

### Immediate (no incident filed, no corrective action taken):

1. **SKILL.md phantom reference**: `/tool-registry` skill references
   `tool-registry.json` which does not exist. The RCA recommended fixing
   to point to `tool-registry.md`. NOT DONE.

2. **frameworks.md phantom reference**: Registries table line 30 references
   `@reference/tool-registry.json`. NOT FIXED.

3. **No incident for the phantom reference itself**: Incident #21 tracks
   the *migration* need, but no incident tracks the *broken skill reference*
   as a distinct defect. The RCA exists as a harvested artifact but no
   corrective action was taken.

### Planned but unlinked:

4. **Incident #21** (migration to three-layer): Status open, no linked plan,
   no ROADMAP entry. The ROADMAP has a related item ("aitools install version
   capture") that references `tool-versions.json` but not the full migration.

5. **36 open incidents** have no linked plan or roadmap item.

### Known states from tool-ops session (not yet annotated in code):

6. The user requested "known state" annotations in the tool-ops plan but
   it's unclear whether these were written into the actual plan file or only
   into the AAR.

7. The `maintenanceFile` field status is ambiguous -- AAR says it points to
   "file being deleted" but the file appears to still exist.
