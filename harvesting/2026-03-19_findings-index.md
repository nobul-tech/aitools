# Session Findings Index — 2026-03-17

## Summary

4 audit documents, 17 findings, 13 recommendations (7 completed this session).
Bypass vectors in rules/reference/cursor files: 37 → 9 remaining.
Incident #50 filed. Harness definition updated across 3 files.

## Findings by Source

### Rule Effectiveness Audit (rule-effectiveness-audit.md)

| # | Finding | Severity |
|---|---------|----------|
| F1 | Governed data access: only glossary.json has hook enforcement. 5 other registries (framework-registry, incidents, tool-ops, tool-registry, harvest-manifest) are unguarded | High |
| F2 | hookSpecificOutput channel inconsistency: block-guide→stdout, glossary-guard→stderr. May affect whether additionalContext reaches CC properly | Medium |
| F3 | 1003 observe-mode log entries ready for enforcement promotion review. Subagents are primary violators (grep/find/head) | Medium |
| F4 | Git checklist PSO has no enforcement layer. No reminder to run check scripts before commit/push | Medium |
| F5 | 15 of 23 rules are prevention-only (no hook or check-script backstop) | High |
| F6 | Cross-reference integrity clean. 140+ references, all resolve. 2 false positives in documentation-standards (example paths) | Info |
| F7 | Source-deployed parity clean. 9/9 hooks, 16/16 skills, all configs match | Info |

### Intent Audit (intent-audit-findings.md)

| # | Finding | Severity |
|---|---------|----------|
| F8 | 14 of 23 project rules missing intent statements | High |
| F9 | 3 user skills missing intent entirely (a11y-debugging, chrome-devtools, planning) | Medium |
| F10 | 3 skills with incomplete intents — have purpose but no scope/audience (/audit, /investigate, /optimize-plan) | Medium |
| F11 | /intent-audit skill doesn't follow its own format standard (prose, no explicit Audience label) | Low |
| F12 | 3 hooks missing explicit hook contracts in headers (glossary-guard, harvest-session, scratch-init) | Low |
| F13 | User-level intent coverage gap: user skills at 38% vs project skills at 89% | Medium |

### Intent Heuristic Investigation (intent-heuristic-findings.md)

| # | Finding | Severity |
|---|---------|----------|
| F14 | Both intent skills have the recency-weighting principle ("weight recent > old") but not the mechanism — no process for scanning conversations, no weighting tiers, no signal categories, no dynamic exemplar refresh | High |
| F15 | User preference signals extracted from 7 sessions (Mar 15-16): 9 approvals, 10 corrections, 4 redirections, 3 escalations cataloged with exact quotes | Info |
| F16 | User explicitly directed skill updates (3 quotes across 2 sessions) and approved proposed sections, but conversation-scanning heuristic was reduced to parenthetical | High |

### Governed-Data-Access Investigation (governed-data-investigation.md)

| # | Finding | Severity |
|---|---------|----------|
| F17 | Step 16 "known failure" rationalization proven wrong — JSON paths in rules ARE bypass vectors. Agent read `framework-registry.json` path from `frameworks.md` and accessed the file directly, defeating the `/frameworks` skill gate. Proven live in this session. **Filed as Incident #50** | High |

## Recommendations

| # | Action | Findings | Effort | Status |
|---|--------|----------|--------|--------|
| R1 | Update /intent-writing exemplar calibration with full heuristic | F14, F16 | Medium | Draft ready |
| R2 | Update /intent-audit exemplar comparison with full heuristic | F14, F16 | Medium | Draft ready |
| R3 | Both skills share same signal vocabulary (5 categories) | F14, F15 | Low | Open |
| R4 | Add intents to 14 rules + 6 skills (batch strategy per PSO) | F8, F9, F10, F13 | High | Open |
| R5 | Extend governed-data hook to cover all registries (not just glossary) | F1, F17 | Medium | Open |
| R6 | Review observe-mode log data for enforcement promotion | F3 | Medium | Open |
| R7 | Remove governed JSON paths from rules and reference files | F17 | Low | **DONE** — 28 paths removed across 10 files |
| R8 | Reclassify step 16 known failure as real failure | F17 | Low | **DONE** (step 16 now passes) |
| R9 | New hook: rules-json-guard.sh — fires on Write/Edit to rules, warns when governed JSON paths introduced | F17, F1 | Medium | Design drafted |
| R10 | Update harness definition (CLAUDE.md, reference/harness.md, glossary.json) | F17 | Medium | **DONE** |
| R11 | Create artifact-roles rule + skill (define what rules/skills/references/registries/hooks are for) | F17 | Medium | Design discussed, not yet drafted |
| R12 | Move governed registries to `registries/` directory | F17, F1 | High | Deferred — 59 files, needs plan |
| R13 | Fix incident-governance.md 3 remaining incidents.json refs | F17 | Low | Pending — user has approach |

## Files Changed This Session

### Governed-data-access bypass fixes (R7)

| File | Paths removed | What changed |
|------|--------------|-------------|
| `.claude/rules/frameworks.md` | 2 | `reference/framework-registry.json` → `the framework registry` |
| `.claude/rules/tool-lifecycle.md` | 1 | `reference/tool-registry.json` → `/tool-registry skill` |
| `.claude/rules/documentation-standards.md` | 1 | `incidents.json` → `/incident skill` |
| `.claude/rules/tool-ops.md` | 1 | `tool-ops.json` → `the tool-ops registry` |
| `reference/framework-adoption.md` | 6 | `framework-registry.json` (×5) + `incidents.json` (×1) → skill refs |
| `reference/framework-governed-vocabulary.md` | 4 | `glossary.json` (×3) + `framework-registry.json` (×1) → skill refs |
| `reference/framework-three-layer-governance.md` | 1 | `framework-registry.json` → `/frameworks skill` |
| `reference/managed-file-deployment.md` | 1 | `incidents.json` → `/incident skill` |
| `reference/script-standards-detail.md` | 1 | `glossary.json` → `/glossary skill` |
| `.cursor/rules/managed-file-deployment.mdc` | 2 | `incidents.json` (×2) → `/incident skill` |

### Harness definition update (R10)

| File | What changed |
|------|-------------|
| `CLAUDE.md` | Mission expanded: added governance, state; harness definition inline |
| `reference/harness.md` | Full rewrite: crisp definition, all JSON paths removed, artifact roles scoped out |
| `reference/glossary.json` | harness term definition updated to match |

### Incident filed

| ID | Title | Severity |
|----|-------|----------|
| #50 | sources-of-truth.md protected files table exposes all governed registry JSON paths as bypass vectors | High |

## Remaining Governed Registry Bypass Vectors (excluding plans/)

| Location | Count | Status |
|----------|-------|--------|
| `.claude/rules/sources-of-truth.md` | 6 | Incident #50 — needs overhaul + barrier analysis |
| `.claude/rules/incident-governance.md` | 3 | Pending — user has approach |
| **Total** | **9** | |

## Discussed but Deferred

- **Artifact-roles rule + skill**: Define what each harness artifact type is for. Rule governs, skill implements. Self-referentially, the rule must follow its own definition (governance only, no process). Discussed in detail, not yet drafted.
- **Registries directory**: Move governed JSON files from `reference/` to `registries/`. 59 files reference these paths. Needs a plan with batch execution.
- **Recency heuristic provenance research**: Web searches started for AAR, military doctrine, ISO frameworks that inform the recency weighting. Interrupted — to be continued.
- **Handoff prompt step 16 rationalization**: Now obsolete (step 16 passes). Will be cleaned up in next handoff.
- **incident-governance.md easy fix**: User was about to explain approach. Still pending.

## Test Artifacts Produced

| File | Purpose |
|------|---------|
| verify-hooks.sh | Hook source parity + skill parity checks |
| verify-settings.py | Settings.json structure validation (v1, found MCP key issue) |
| verify-mcp.py | MCP server cross-tool parity (v1, superseded) |
| verify-all.py | Comprehensive verification: settings, hooks, skills, rules, MCP, configs |
| test-hook-violations.sh | Hook functional tests with violation inputs |
| test-remaining-hooks.sh | Extended tests: USO detection, channel verification, coverage gaps |
| audit-rule-enforcement.py | Three-layer coverage map for all 23 rules |
| audit-rule-crossrefs.py | Cross-reference integrity audit for all rules |
| scan-json-refs.py | Full codebase scan for governed JSON path references |
| search-mission.sh | Session transcript search for harness scope expansion signals |

## What Was Verified (All Pass)

- 9/9 hooks: syntax valid, source matches deployed, functional tests pass
- 16/16 user skills: source matches deployed (Claude + Cursor)
- 9/9 project skills: present with content
- 23/23 project rules: present, cross-references resolve
- settings.json: 3 preferences correct, 3 deny rules present, 9 hooks registered across 5 events
- MCP: 3 servers configured in both CC and Cursor, parity confirmed
- tool-ops verification spec: both test cases pass
- check-pre-commit step 16: PASS (after R7 fixes)
