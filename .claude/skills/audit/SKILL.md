---
name: audit
description: "Deep governance review of aitools rules, references, skills, and gaps. Use when asked to audit, review governance health, or check for inconsistencies. Reports gaps, broken cross-references, stale entries, and unfiled TODO(gap) markers."
disable-model-invocation: true
---

## Purpose

Comprehensive governance health check for the aitools project. Reads all
rules, references, CLAUDE.md, known-gaps.json, and the codebase to report
issues that the prevention layer (rules) and detection layer (hooks)
missed.

This is the audit layer of the three-layer governance model.

## Scope

### Cross-reference validation
- Every `@path/file` reference in `.claude/rules/*.md` → verify file exists
- Every `@path/file` reference → verify the referenced section/heading exists
- References from rules to reference files → content matches claims

### Known-gaps.json health
- IDs sequential (no duplicates, no gaps in sequence)
- All required fields present per gap-governance.md schema
- Severity/status/type values are valid enums
- Gaps open > 90 days without a linked plan → flag as stale
- Entries in `closed` array have closedIn and closedDate

### Unfiled findings
- Scan codebase for `TODO(gap):` markers → report unfiled gaps
- Check if subagent output in current session contains `AMBIGUITY:` prefixes
  that weren't filed

### Rule compliance
- Do rules reference current artifacts? (not deleted files, renamed sections)
- Are standing orders (USO/PSO) still accurate?
- Do design principles in CLAUDE.md match the plan?

### Skill health
- Skill inventory count matches plan file claims
- Every skill in `shared/skills/` and `.claude/skills/` has a SKILL.md
- Every skill has a `tests/` directory (eval coverage)
- Skill descriptions are present and specific enough for auto-triggering
- Pre-built cache size estimate vs 10% budget

### Plan consistency
- Skill counts match across all sections
- Implementation step markers (done/not done) are current
- Foundational decisions numbered correctly
- No duplicate sections
- ROADMAP entry matches plan scope

### Incident recurrence
- Read effectiveness tracker (if accessible via userRepoPath)
- Identify coaching items with 3+ recurrences → flag for structural fix
- Check if corrective actions from incidents are implemented

## Output format

```markdown
## Governance Audit Report — YYYY-MM-DD

### Cross-References
- ✓ N references validated
- ✗ N broken references (list each)

### Known Gaps
- N open (N critical, N high, N medium, N low)
- N stale (open > 90 days without plan)
- N duplicate IDs (list each)

### Unfiled Findings
- N TODO(gap) markers found (list locations)
- N AMBIGUITY: items not filed

### Rule Compliance
- N rules checked, N issues found

### Skill Health
- N/M skills have tests/ (coverage %)
- Pre-built cache estimate: Nk chars (X% of budget)

### Plan Consistency
- Skill count: plan says N, actual N
- Implementation: N/M steps done
- N issues found

### Incidents
- N coaching items with 3+ recurrences
- N corrective actions pending verification

### Summary
- Total issues: N
- Action items: (list)
```

## How to run

User invokes `/audit` explicitly. The skill:
1. Reads all rules files (`.claude/rules/*.md`)
2. Reads CLAUDE.md and plan file
3. Reads `reference/known-gaps.json`
4. Scans for `TODO(gap):` markers via Grep
5. Checks skill directories for completeness
6. Produces the report above

## What it does NOT do

- Does not write to any file (read-only analysis)
- Does not file gaps automatically (use `/gap` for that)
- Does not modify rules or references
- Does not auto-trigger (user must invoke explicitly)
