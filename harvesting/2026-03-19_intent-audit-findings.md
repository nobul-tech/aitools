# Intent Audit Findings — 2026-03-17

## Scope

Audited all 49 harness artifacts for intent statement presence,
completeness, and quality:
- 23 project rules (.claude/rules/*.md)
- 9 project skills (.claude/skills/*/SKILL.md)
- 8 user skills (shared/skills/*/SKILL.md)
- 9 hooks (shared/hooks/*.sh)

## Summary

| Category | Total | Has Intent | Missing | Incomplete |
|----------|-------|-----------|---------|------------|
| Project rules | 23 | 9 (39%) | **14** | 0 |
| Project skills | 9 | 8 (89%) | 0 | **1** |
| User skills | 8 | 3 (38%) | **3** | **2** |
| Hooks | 9 | 9 (100%) | 0 | 0 |
| **Total** | **49** | **29 (59%)** | **17** | **3** |

**20 artifacts (41%) need intent work** — 17 missing entirely, 3 incomplete.

## Intent Quality Standard

Per CLAUDE.md design principle "Document intent" and the `/intent-writing`
skill, every file needs:
- **Purpose**: what it exists to deliver (active verb)
- **Scope**: what's covered AND explicitly excluded (NOT boundaries)
- **Audience**: who consumes it

Format: `**Intent**: **Purpose**: ... **Scope**: ... **Audience**: ...`
(markdown files) or header comment block (code files).

---

## F8: Rules Missing Intent Statements (14 files)

These rules have NO `**Intent**:` block. They jump straight from the
heading into content. Per the "Document intent" design principle,
every markdown file must state its intent.

| Rule | Has content sections | Complexity |
|------|---------------------|------------|
| agentic-standards.md | 8 sections | High — prompt design, tiers, anti-patterns |
| config-file-safety.md | 5 sections + YAML frontmatter | High — merge rules, managed fields |
| cross-platform.md | 10+ sections | High — OS guards, exemptions, gotchas |
| deploy-paths.md | 3 sections + YAML frontmatter | Medium |
| documentation-standards.md | 6 sections + YAML frontmatter | Medium |
| git-safety.md | 3 sections | Low — focused, short |
| hook-rollout.md | 3 sections + YAML frontmatter | Medium |
| interactive-menus.md | 7 sections | High — menus, encoding, JSON review |
| managed-file-deployment.md | 5 sections + YAML frontmatter | High |
| plan-execution.md | 1 section | Low — focused, short |
| script-standards.md | 20+ sections | Very high — largest rule file |
| smoke-test-pattern.md | 2 sections | Low — focused, short |
| sources-of-truth.md | 4 sections | High — protected files table |
| web-sources.md | 3 sections + YAML frontmatter | Low |

**Priority ranking** (highest ambiguity risk first):
1. **script-standards.md** (13,893 bytes, 20+ sections) — largest rule,
   most likely to be misread without intent boundaries
2. **cross-platform.md** (4,505 bytes, 10+ sections) — broad scope,
   overlaps with interactive-menus and config-file-safety
3. **config-file-safety.md** (6,160 bytes) — unclear boundary with
   managed-file-deployment and interactive-menus
4. **sources-of-truth.md** (4,995 bytes) — governs protected files but
   no stated boundary distinguishing it from incident-governance
5. **managed-file-deployment.md** (4,179 bytes) — unclear boundary with
   interactive-menus.md
6. **interactive-menus.md** (3,044 bytes) — unclear boundary with
   managed-file-deployment.md and config-file-safety.md
7. **agentic-standards.md** (3,705 bytes) — broad, overlaps with
   script-standards for AI invocation logging

The bottom 7 (deploy-paths, documentation-standards, git-safety,
hook-rollout, plan-execution, smoke-test-pattern, web-sources) are
shorter and more focused — lower ambiguity risk.

## F9: Skills Missing Intent Statements (3 files)

These skills have NO intent statement of any kind — no `## Intent`
section, no `**Intent**:` block, no purpose/scope/audience structure.

| Skill | Scope | What it has instead |
|-------|-------|-------------------|
| a11y-debugging | User | Jumps straight to "## Core Concepts" |
| chrome-devtools | User | Jumps straight to "## Core Concepts" |
| planning | User | Jumps straight to "## Session Working Convention" |

These are all user-level skills deployed to `~/.claude/skills/` and
`~/.cursor/skills/`. Without intent, agents have no boundary guidance
for what content belongs in these files vs. elsewhere.

## F10: Skills with Incomplete Intents (3 files)

These skills have SOME purpose/scope content but not the full
`**Intent**:` structure.

### /audit (project skill)
- **Has**: `## Purpose` section + `## Scope` section (separate headings)
- **Missing**: No `**Intent**:` block, no explicit **Audience**
- **Gap**: Format doesn't match the standard. Purpose and scope are
  separate sections rather than a unified intent statement. Audience
  is implied ("user invokes /audit explicitly") but not stated.

### /investigate (user skill)
- **Has**: `## Purpose` section with description
- **Missing**: No scope boundaries, no audience, no exclusions
- **Gap**: Purpose reads as a description ("Structured response to
  incidents...") rather than a deliverable. No NOT boundaries.

### /optimize-plan (user skill)
- **Has**: `## Purpose` section with description
- **Missing**: No scope boundaries, no audience, no exclusions
- **Gap**: Has one informal exclusion ("NOT a one-shot review") but
  no formal scope or audience.

## F11: Intent Format Inconsistency (intent-audit skill)

The `/intent-audit` skill itself (shared/skills/intent-audit/SKILL.md)
has an intent statement but uses a **prose format** rather than the
standard `**Purpose**: ... **Scope**: ... **Audience**: ...` structure.

Current: paragraph-style with inputs/outputs and NOT exclusions.
Missing: explicit `**Audience**:` label.

This is the skill that DEFINES intent quality — it should exemplify
the standard it enforces.

## F12: Hooks — Intent Present but Format Varies

All 9 hooks have header comment blocks describing purpose and scope.
This is the correct format for code files per CLAUDE.md. However:

| Hook | Has purpose | Has scope/trigger | Has hook contract | Has design decisions |
|------|-----------|-------------------|-------------------|---------------------|
| block-claude-code-guide.sh | Yes | Yes | Yes (exit codes, stdout/stderr) | No |
| glossary-skill-guard.sh | Yes | Yes | **No** | No |
| harvest-session.sh | Yes | Yes | **No** (implicit) | Yes |
| scratch-init.sh | Yes | Yes | **No** (implicit) | Yes |
| session-archive.sh | Yes | Yes | Yes (partial) | Yes |
| sh-file-fixup.sh | Yes | Yes | Yes (exit codes, stderr) | No |
| standing-order-guard.sh | Yes | Yes | Yes (exit codes, stderr) | Yes (rollout modes) |
| surfacing-duty-stop.sh | Yes | Yes | Yes (exit codes, stderr, perf) | No |
| tool-ops-session-audit.sh | Yes | Yes | Yes (exit codes, error handling) | No |

**3 hooks lack explicit hook contracts**: glossary-skill-guard.sh,
harvest-session.sh, scratch-init.sh. The hook contract (stdin format,
exit codes, stdout vs stderr behavior) is critical for maintenance —
without it, future editors may change output channels without
understanding the consequences (see F2 in rule-effectiveness-audit.md
for the stderr vs stdout inconsistency).

## F13: User-Level vs Project-Level Intent Coverage Gap

| Level | With intent | Without | Coverage |
|-------|-----------|---------|----------|
| Project rules | 9 | 14 | 39% |
| Project skills | 8 | 1 | 89% |
| User rules | 1 | 0 | 100% (only 1 file) |
| User skills | 3 | 5 | 38% |
| Hooks | 9 | 0 | 100% |

**Project skills are well-covered (89%)** — only `/audit` is incomplete.
**User skills are poorly covered (38%)** — 5 of 8 need work.
**Project rules are poorly covered (39%)** — 14 of 23 need work.
**Hooks are fully covered (100%)** — all have header comment blocks.

The gap correlates with age: the 9 rules WITH intents were added
during the governance framework buildout (March 2026). The 14 WITHOUT
predate that effort.

---

## Cross-Reference to Previous Findings

- F1-F7: Rule effectiveness audit (rule-effectiveness-audit.md)
- F8-F13: This document (intent audit)
- F5 (sources-of-truth prevention-only) compounds with F8 (sources-of-truth
  missing intent) — this high-value rule has neither intent boundaries
  nor enforcement hooks

## Recommendations

### Quick wins (low effort, high value)
1. Add intents to the 7 low-complexity rules (git-safety, plan-execution,
   smoke-test-pattern, web-sources, deploy-paths, documentation-standards,
   hook-rollout) — short files, clear scope
2. Add intents to 3 missing user skills (a11y-debugging, chrome-devtools,
   planning) — clear purpose from content
3. Add hook contracts to 3 hooks (glossary-skill-guard, harvest-session,
   scratch-init) — 2-3 comment lines each

### Deeper work (medium effort)
4. Add intents to high-complexity rules (script-standards, cross-platform,
   config-file-safety, sources-of-truth, managed-file-deployment,
   interactive-menus, agentic-standards) — requires careful boundary
   drawing between overlapping rules
5. Upgrade /audit, /investigate, /optimize-plan intents to standard format
6. Fix /intent-audit's own intent to match the standard it enforces

### Batch strategy
Per PSO (sub-agent execution for large plans): 20 intent additions
across 20 files = sub-agent execution required. Batch by category
(rules, then skills, then hooks), 3-5 files per batch, verify
between batches.
