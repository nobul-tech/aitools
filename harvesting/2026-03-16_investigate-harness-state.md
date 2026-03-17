# Harness State Audit Report

**Date**: 2026-03-16
**Auditor**: Harness State Auditor (S2 function)
**Scope**: Framework registry, rules, CLAUDE.md, skills, glossary

---

## 1. Framework Registry Integrity

**File**: `reference/framework-registry.json` (lastUpdated: 2026-03-15)

### 1.1 Reference File Existence

All 13 framework reference files exist:

| Framework | Reference File | Exists |
|-----------|---------------|--------|
| Three-layer governance | reference/framework-three-layer-governance.md | YES |
| Incident governance | reference/framework-incident-governance.md | YES |
| Source-of-truth protection | reference/framework-source-of-truth.md | YES |
| Tool lifecycle | reference/framework-tool-lifecycle.md | YES |
| Managed file deployment | reference/framework-managed-file-deployment.md | YES |
| Hook rollout | reference/framework-hook-rollout.md | YES |
| Incident investigation | reference/framework-incident-investigation.md | YES |
| Framework adoption | reference/framework-adoption.md | YES |
| Governed vocabulary | reference/framework-governed-vocabulary.md | YES |
| Intent documentation | reference/framework-intent-documentation.md | YES |
| Governed data access | reference/framework-governed-data-access.md | YES |
| Artifact harvesting | reference/framework-artifact-harvesting.md | YES |
| Tool operations | reference/framework-tool-ops.md | YES |

### 1.2 Artifact Existence

| Framework | Artifact | Exists | Issue |
|-----------|----------|--------|-------|
| Three-layer governance | .claude/skills/audit/SKILL.md | YES | |
| Tool lifecycle | reference/evaluations/ | EMPTY | Directory exists but contains zero files |
| Hook rollout | shared/hooks/standing-order-guard.sh | YES | |
| Incident investigation | shared/skills/investigate/SKILL.md | YES | |
| Governed data access | .claude/skills/governed-data/SKILL.md | YES | |
| Artifact harvesting | shared/hooks/harvest-session.sh | YES | |
| Artifact harvesting | harvesting/ | YES | Contains 11 files |
| Tool operations | shared/hooks/tool-ops-session-audit.sh | YES | |
| Tool operations | reference/tool-ops.json | YES | |
| Tool operations | reference/tool-ops-claude-code.md | YES | |

**FINDING F1**: `reference/evaluations/` directory is empty. The tool-evaluation rule states "Every install method decision MUST be documented in reference/evaluations/" but no evaluation files exist. This may indicate evaluations have not yet been created, or were not committed.

### 1.3 lastUpdated Staleness

Given the rapid pace (22 commits on 2026-03-15), several frameworks have `lastUpdated: 2026-03-14` -- two days ago. These may or may not be stale depending on whether their artifacts changed on 2026-03-15:

| Framework | lastUpdated | Days Old |
|-----------|-------------|----------|
| Three-layer governance | 2026-03-14 | 2 |
| Source-of-truth protection | 2026-03-14 | 2 |
| Managed file deployment | 2026-03-14 | 2 |
| Hook rollout | 2026-03-14 | 2 |
| Incident investigation | 2026-03-14 | 2 |
| Framework adoption | 2026-03-14 | 2 |
| Governed vocabulary | 2026-03-14 | 2 |
| Intent documentation | 2026-03-14 | 2 |
| Incident governance | 2026-03-15 | 1 |
| Tool lifecycle | 2026-03-15 | 1 |
| Governed data access | 2026-03-15 | 1 |
| Artifact harvesting | 2026-03-15 | 1 |
| Tool operations | 2026-03-15 | 1 |

**FINDING F2**: Eight frameworks have lastUpdated of 2026-03-14 while 22 commits landed on 2026-03-15. At least some of these may have been affected. Low severity -- timestamps are advisory.

### 1.4 Pending Frameworks

| Framework | Incident | Status |
|-----------|----------|--------|
| Process discipline | I20 | OPEN |

Incident #20 is confirmed still open with status "open". The pending entry is valid.

---

## 2. Rules vs Reference Files

### 2.1 Intent Statement Coverage

22 rule files examined. 10 have formal `**Intent**:` statements, 12 do not:

**Have intent statements:**
- artifact-harvesting.md
- frameworks.md
- glossary.md
- governed-data-access.md
- incident-governance.md
- tool-evaluation.md
- tool-lifecycle.md
- tool-ops.md

(Note: frameworks.md and glossary.md have their intent nested in the `**Intent**:` block.)

**Missing formal intent statements:**
- agentic-standards.md
- config-file-safety.md
- cross-platform.md
- deploy-paths.md
- documentation-standards.md
- git-safety.md
- hook-rollout.md
- interactive-menus.md
- managed-file-deployment.md
- plan-execution.md
- script-standards.md
- smoke-test-pattern.md
- sources-of-truth.md
- web-sources.md

**FINDING F3**: 14 of 22 rules files lack formal intent statements. The "Document intent" design principle in CLAUDE.md states "existing files are backfilled incrementally" so this is expected debt, but the coverage gap is notable -- 64% of rules lack intent.

### 2.2 Framework Registry Presence

Rules that reference a framework in the registry:

| Rule | Framework | In Registry |
|------|-----------|-------------|
| artifact-harvesting.md | Artifact harvesting | YES |
| frameworks.md | Framework adoption | YES |
| glossary.md | Governed vocabulary | YES |
| governed-data-access.md | Governed data access | YES |
| hook-rollout.md | Hook rollout | YES |
| incident-governance.md | Incident governance | YES |
| managed-file-deployment.md | Managed file deployment | YES |
| tool-evaluation.md | Tool lifecycle | YES |
| tool-lifecycle.md | Tool lifecycle | YES |
| tool-ops.md | Tool operations | YES |

Rules without a corresponding framework (operational rules, not framework-based):
- agentic-standards.md, config-file-safety.md, cross-platform.md, deploy-paths.md, documentation-standards.md, git-safety.md, interactive-menus.md, plan-execution.md, script-standards.md, smoke-test-pattern.md, sources-of-truth.md, web-sources.md

No issues found here -- these are operational rules that don't need framework backing.

### 2.3 `@`-Reference Validation

All `@`-referenced files verified. Key findings:

**All target files EXIST** for these commonly referenced paths:
- `@reference/script-standards-detail.md`
- `@reference/managed-file-deployment.md`
- `@reference/cross-platform-detail.md`
- `@reference/agentic-framework.md`
- `@reference/framework-adoption.md`
- `@reference/tool-evaluation-criteria.md`
- `@reference/tool-evaluation-playbook.md`
- `@reference/smoke-test-pattern-detail.md`
- `@reference/plan-execution-detail.md`
- `@reference/user-repo.md`
- `@reference/framework-governed-vocabulary.md`
- `@scripts/aitools-lib.sh`
- `@scripts/aitools-lib.ps1`
- `@plans/governance-and-compliance-framework.md`
- `@.cursor/rules/managed-file-deployment.mdc`

No broken `@`-references found.

### 2.4 Content vs Intent Check

**FINDING F4**: Several rules without intent statements contain substantial process/how-to content mixed with governance directives. Most notable:
- `script-standards.md` (297 lines) -- extensive implementation detail that could be split between rule (governance) and reference (detail). It does reference `@reference/script-standards-detail.md` for detail, but the rule itself is very long.
- `config-file-safety.md` (171 lines) -- contains code examples and reference examples list, which is more reference material than governance.

These are borderline -- the rules reference separate detail files, so some overlap is expected.

---

## 3. CLAUDE.md Consistency

### 3.1 Registries Table (in frameworks.md)

The registries table in `.claude/rules/frameworks.md` lists 7 registries:

| Registry | Data File Listed | File Exists | Issue |
|----------|-----------------|-------------|-------|
| Frameworks | `@reference/framework-registry.json` | YES | |
| Incidents | `@reference/incidents.json` | YES | |
| Glossary | `@reference/glossary.json` | YES | |
| Tool registry | `@reference/tool-registry.json` | **NO** | File is .md not .json |
| Tool evaluation | `reference/evaluations/` | YES (empty) | |
| Artifact harvesting | `harvesting/` | YES | |
| Tool operations | `@reference/tool-ops.json` | YES | |

**FINDING F5 (HIGH)**: The registries table references `@reference/tool-registry.json` but this file does not exist. The actual file is `reference/tool-registry.md` (a markdown file). Incident #21 already tracks the migration to three-layer pattern, but the registries table currently references a non-existent file. This is a broken cross-reference in a rule file that is always in context.

### 3.2 Key Decisions Staleness

Reviewed all Key Decisions in CLAUDE.md:

1. "home base" for AI conversations -- still valid
2. Shared preferences / CLAUDE.md template -- still valid
3. `/tool-registry` skill access point -- still valid
4. Install methods via `/tool-eval` -- still valid
5. `claude mcp add` nested sessions -- still valid
6. AI CLI invocations via `invoke_ai` -- still valid
7. deploy/ lifecycle -- still valid
8. Governed data changes -- still valid
9. Tool-ops framework -- still valid (newly added)

No stale Key Decisions found.

### 3.3 Deploy Scripts List

CLAUDE.md lists these deploy script categories:
- Config scripts: `setup-user-claude`, `-mcp`, `-skills`, `-hooks`, `setup-cursor-ide-mcp`, `setup-user-cursor`
- Tool scripts: `setup-vercelcli`, `-pandoc`, `-rust`, `-typst`, `-gh-cli`, `-python`, `-uv`, `-modal`, `-go`, `-datadog`, `-perl`

**Actual deploy/ contents (17 .sh + 17 .ps1 = 34 files):**

.sh files: setup-user-claude, setup-user-cursor, setup-cursor-ide-mcp, setup-vercelcli, setup-pandoc, setup-rust, setup-typst, setup-gh-cli, setup-python, setup-uv, setup-modal, setup-go, setup-datadog, setup-perl, **setup-user-mcp**, **setup-user-skills**, **setup-user-hooks**

**FINDING F6 (MEDIUM)**: CLAUDE.md deploy list mentions `setup-user-claude`, `-mcp`, `-skills`, `-hooks` as config scripts, which matches `setup-user-mcp.sh`, `setup-user-skills.sh`, `setup-user-hooks.sh`. The CLAUDE.md text uses shortened names with dashes (`-mcp`, `-skills`, `-hooks`) that map correctly. No actual mismatch found on closer inspection -- the notation is just abbreviated.

All .ps1 counterparts exist for every .sh file. Platform parity is complete.

### 3.4 Governed File Definition Completeness

**FINDING F7 (MEDIUM)**: The `governed file` term in glossary.json lists only 3 governed files: "incidents.json (/incident), glossary.json (/glossary), framework-registry.json (/frameworks)". But `reference/tool-ops.json` is also governed (accessed via `/tool-ops` skill). The definition is incomplete -- it should also list `tool-ops.json (/tool-ops)`.

---

## 4. Skills Audit

### 4.1 Complete Skills Inventory

**Project-level skills** (`.claude/skills/`): 9 skills
1. audit -- Deep governance review (disable-model-invocation: true)
2. frameworks -- Framework registry access
3. glossary -- Governed vocabulary definitions
4. governed-data -- Governed data access management
5. harvest -- Artifact harvesting lifecycle
6. incident -- Incident filing
7. tool-eval -- Tool evaluation
8. tool-ops -- Tool operations metadata
9. tool-registry -- Tool registry access

**User-level skills** (`shared/skills/`): 8 skills
1. a11y-debugging -- Accessibility debugging via Chrome DevTools
2. chrome-devtools -- Chrome DevTools browser automation
3. intent-audit -- Intent verification
4. intent-writing -- Intent statement drafting
5. investigate -- Incident investigation (RCA)
6. optimize-plan -- Plan review/improvement
7. planning -- Session planning strategy
8. scratch -- Ephemeral session scratch files

### 4.2 Intent Statement Coverage

| Skill | Has Intent | Format |
|-------|-----------|--------|
| audit | YES | "## Purpose" |
| frameworks | YES | "## Intent" |
| glossary | YES | "## Intent" |
| governed-data | YES | "## Intent" |
| harvest | YES | "## Intent" |
| incident | YES | "## Intent" |
| tool-eval | YES | "## Intent" |
| tool-ops | YES | "## Intent" |
| tool-registry | YES | "## Intent" |
| a11y-debugging | NO | Starts with "## Core Concepts" |
| chrome-devtools | NO | Starts with "## Core Concepts" |
| intent-audit | YES | "## Intent" |
| intent-writing | YES | "## Intent" |
| investigate | YES | "## Purpose" |
| optimize-plan | YES | "## Purpose" |
| planning | NO | Starts with "## Session Working Convention" |
| scratch | YES | "## Intent" |

**FINDING F8**: 3 of 17 skills lack intent statements: `a11y-debugging`, `chrome-devtools`, and `planning`.

### 4.3 Trigger Directive Audit (Orphaned Skills)

Skills SHOULD have trigger directives in rules files that state WHEN to invoke them.

| Skill | Trigger Directive in Rules | Status |
|-------|---------------------------|--------|
| /audit | incident-governance.md | OK |
| /frameworks | frameworks.md | OK |
| /glossary | glossary.md | OK |
| /governed-data | governed-data-access.md | OK (implicit) |
| /harvest | artifact-harvesting.md | OK |
| /incident | incident-governance.md | OK |
| /tool-eval | tool-evaluation.md, tool-lifecycle.md | OK |
| /tool-ops | tool-ops.md | OK |
| /tool-registry | tool-evaluation.md, tool-lifecycle.md, web-sources.md | OK |
| /scratch | artifact-harvesting.md (cross-ref only) | WEAK |
| /a11y-debugging | NONE | ORPHANED |
| /chrome-devtools | NONE | ORPHANED |
| /intent-writing | NONE | ORPHANED |
| /intent-audit | NONE | ORPHANED |
| /investigate | NONE | ORPHANED |
| /optimize-plan | NONE | ORPHANED |
| /planning | NONE | ORPHANED |

**FINDING F9 (MEDIUM)**: 7 user-level skills have no trigger directive in any rule file. These are "orphaned" in the sense that nothing in the always-in-context rules tells agents WHEN to invoke them. They rely on Claude Code's auto-trigger based on the skill description alone. This is a gap per the CLAUDE.md design principle "Skills as enablement" which states "Every skill with auto-trigger behavior requires three artifacts: the skill itself, a trigger directive in its governing rule, and a detection hook spec."

However, this applies specifically to skills with "auto-trigger behavior" -- user-level skills deployed via `shared/skills/` may be considered outside the project harness's governance scope (they're cross-project). The principle may need clarification on whether user-level skills require project-level trigger directives.

---

## 5. Glossary Health

### 5.1 Term Count Comparison

| Source | Count |
|--------|-------|
| glossary.json terms | 70 |
| glossary.md terms list | 66 |

### 5.2 Sync Analysis

**Scope modifiers**: IN SYNC (4/4)
**Base artifacts**: IN SYNC (6/6)

**Terms in JSON but not in rule (4)**:
- `hook`
- `incident`
- `rule`
- `skill`

**FINDING F10 (MEDIUM)**: 4 terms exist in `glossary.json` but are missing from the term list in `.claude/rules/glossary.md`. These are: `hook`, `incident`, `rule`, `skill`. Notably, `rule` and `skill` also appear in the base artifacts list, and `hook` is also a base artifact -- so there's an argument they're covered there. But `incident` is neither a scope modifier nor a base artifact -- it is a standalone term that should appear in the Terms section.

All terms in the rule are present in JSON -- no reverse mismatches.

---

## 6. Cross-Cutting Findings Summary

### High Priority

| ID | Finding | Affected |
|----|---------|----------|
| F5 | Registries table references `@reference/tool-registry.json` which does not exist (actual file is .md) | `.claude/rules/frameworks.md` line 30 |

### Medium Priority

| ID | Finding | Affected |
|----|---------|----------|
| F1 | `reference/evaluations/` is empty despite being the required destination for tool evaluation docs | reference/evaluations/ |
| F7 | `governed file` glossary definition incomplete -- missing tool-ops.json | reference/glossary.json |
| F9 | 7 user-level skills lack trigger directives in any rule | shared/skills/ (7 of 8 skills) |
| F10 | 4 terms in glossary.json not listed in glossary.md rule | .claude/rules/glossary.md |

### Low Priority

| ID | Finding | Affected |
|----|---------|----------|
| F2 | 8 framework lastUpdated timestamps at 2026-03-14 despite heavy 2026-03-15 activity | reference/framework-registry.json |
| F3 | 14 of 22 rules files lack formal intent statements (64%) | .claude/rules/ |
| F4 | Some rules contain more implementation detail than governance | script-standards.md, config-file-safety.md |
| F8 | 3 of 17 skills lack intent statements | a11y-debugging, chrome-devtools, planning |

### Already Tracked

| Finding | Tracked By |
|---------|-----------|
| Tool registry is markdown not JSON (F5 root cause) | Incident #21 |
| reference/evaluations/ empty (F1) | Implicit in tool-eval process -- no evaluations have been conducted yet |

### Incident Summary

- 39 open incidents
- 6 planned incidents
- 0 closed incidents

---

## 7. Recommendations

1. **Fix F5 immediately**: Change `@reference/tool-registry.json` to `@reference/tool-registry.md` in `.claude/rules/frameworks.md` registries table, or note it as pending the I21 migration. The current reference is a broken cross-reference in an always-in-context rule.

2. **Add missing glossary terms (F10)**: Add `hook`, `incident`, `rule`, `skill` to the Terms section of `.claude/rules/glossary.md`. These exist in the JSON but not in the rule's word list.

3. **Update governed file definition (F7)**: Add `tool-ops.json (/tool-ops)` to the governed file term definition in glossary.json.

4. **Clarify user-level skill trigger scope (F9)**: The "Skills as enablement" design principle requires trigger directives for auto-trigger skills. Clarify whether this applies to user-level skills or only project-level skills. If it applies to both, the 7 orphaned user-level skills need trigger directives added to appropriate rules.

5. **Intent backfill (F3, F8)**: Continue incremental backfill. Priority: rules referenced most frequently by other artifacts.
