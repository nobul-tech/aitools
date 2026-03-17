# Investigation: Intent Skill Heuristics Extraction

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-16
**Blocking**: Decisions #39 (intent-writing) and #40 (intent-audit)
**Source material**: delegation-evolution.md, intent-approval-evolution.md,
decision-quality-audit.md, current skill files, 3 governed JSON exemplars

---

## 1. What Each Skill Currently Has (Gap Analysis)

### /intent-writing — Current Coverage

The skill currently covers:

| Area | Status | Notes |
|------|--------|-------|
| Three components (purpose/scope/audience) | Present | Well-documented with examples |
| Format by file type (md, JSON, code) | Present | Markdown, JSON, code all covered |
| Common failure modes | Present | 6 anti-patterns listed |
| Process (draft, present, iterate, write) | Present | 5-step process |
| Anti-patterns | Present | 3 listed (write after, copy, skip section-level) |
| Protection gate reference | Present | Links to sources-of-truth |

**What's MISSING** (proven heuristics from session evidence):

| Gap | Source | Evidence |
|------|--------|----------|
| Multi-pass ambiguity removal | delegation-evolution.md §2 | 4 passes killed "bootstrap", "calibrate verbosity", "more weight" — undefined terms that would have confused executing agents |
| Weight-by-recency for examples | delegation-evolution.md §1, L1101 | User's exact words: "audit the most recent conversations for intents we have written together... the more recent the conversation where i confirmed i was happy, the more weight that intent should have" |
| Pre-write governed term audit | delegation-evolution.md §2 | The ambiguity purge found "bootstrap" — a term not in the glossary, not defined anywhere. The governed term check catches this class of error |
| Consolidated presentation pattern | intent-approval-evolution.md §Phase 3 | Batch 5: 4 intents presented in one block, approved in one word ("beautiful"). Batch 1: 1 intent took 3 rounds and 15 minutes. Consolidation reduces approval friction by 10-15x |
| Style calibration from exemplars | intent-approval-evolution.md §Three Adaptations | Agent learned through batch 1 iterations: bold-label format, negative scope boundaries ("NOT X. NOT Y."), active verbs in purpose, audience includes programmatic consumers. By batch 5, first-try approval |
| Quality criteria checklist | decision-quality-audit.md | 6-criterion checklist (A-F) for decision quality — adaptable to intent quality |
| Conciseness calibration | delegation-evolution.md §1, L1103 | Agent's insight: "the tool-ops.json intent in the plan is too verbose compared to other governed JSON intents (glossary.json's is one line)". User confirmed verbosity was a concern (L1101) |

### /intent-audit — Current Coverage

The skill currently covers:

| Area | Status | Notes |
|------|--------|-------|
| Content-vs-intent alignment check | Present | 3-question framework (purpose, scope, audience) |
| Finding classification | Present | 6 types (scope creep, state-in-process, etc.) |
| Resolution proposals | Present | Move, split, amend, file gap |
| Output format | Present | Structured report template |
| Detection pairing | Present | PreToolUse hook reference |
| Anti-patterns | Present | 4 listed |

**What's MISSING** (proven heuristics from session evidence):

| Gap | Source | Evidence |
|------|--------|----------|
| Intent quality audit | intent-approval-evolution.md §Phase 1 | The skill only audits content-vs-intent alignment. It does NOT audit whether the intent itself is good. Batch 1 showed intents needed 3 rounds of revision — the intent was present but insufficient |
| Purpose concreteness check | decision-quality-audit.md criterion C | "WHAT to do but don't break it down into concrete sub-steps" — same failure mode in intents. "Track harness deficiencies" rejected; "Track AND drive corrective actions" accepted (intent-approval-evolution L73) |
| Scope exclusion check | All exemplar intents | Every approved intent uses "NOT X. NOT Y." pattern. An intent without exclusions is incomplete — confirmed across all 9 rule intents and 3 JSON intents |
| Audience specificity check | intent-approval-evolution L81 | User caught "agents" as too vague — demanded "check scripts, hooks" be added. Generic audience = missing consumers |
| Multi-pass ambiguity detection | delegation-evolution.md §2 | Agent did 4 self-audit passes. Each pass found terms the previous missed. Single-pass audits miss ambiguities that compound |
| Barrier analysis on intent | delegation-evolution.md §2 (L1115) | "wtf is bootstrap?" — if an agent read only this intent, would it know what belongs and what doesn't? The test: can a fresh agent with NO project context correctly classify 3 pieces of content as in-scope or out-of-scope using only the intent? |
| Comparison to exemplar intents | intent-approval-evolution §Phase 3 | By batch 5, the agent calibrated against approved exemplars. The audit skill should do the same — compare audited intent against the best exemplars and flag structural gaps |

---

## 2. What Needs to Be Added (Specific New Sections)

### For /intent-writing — New Sections

#### Section: Pre-Write Audit (insert after "Process" step 1, before step 2)

```markdown
## Pre-write audit

Before drafting, perform these checks:

### Governed term audit

Scan draft content for terms. For each term:
1. Is it in the `/glossary` skill's governed vocabulary?
2. If not, is it widely understood without definition?
3. If neither — the term is ambiguous. Replace with a governed
   term, define it, or remove it.

The ambiguity purge from session 84280c8b found "bootstrap",
"calibrate verbosity", and "more weight" as undefined terms that
would have confused executing agents. Four passes were needed to
catch them all. Do at least two passes.

### Exemplar calibration

Read 2-3 recently approved intents (weight recent > old):
- JSON intents: check `meta.intent` in governed JSON files
- Rule intents: check `**Intent**:` blocks in `.claude/rules/`
- Skill intents: check `## Intent` sections in skill files

Calibrate your draft to match the conciseness and structural
patterns of approved exemplars. The best governed JSON intents are
one clause per field. Rule intents use negative scope boundaries
("NOT X. NOT Y.") and name specific consumers in audience.
```

#### Section: Multi-Pass Ambiguity Removal (insert after Pre-Write Audit)

```markdown
## Multi-pass ambiguity removal

After drafting the intent, perform at least 2 self-audit passes
before presenting to the user:

**Pass 1 — Undefined terms**: Read every word. Is each term either
(a) in the governed vocabulary, (b) a common English word, or
(c) defined in the file itself? Flag anything else.

**Pass 2 — Vague mechanisms**: Look for phrases that describe
an outcome without specifying the mechanism. "Ensure quality" —
how? "Manage lifecycle" — which gates? Replace with specifics
or remove.

**Pass 3 (if anything changed in passes 1-2)**: Re-read the
complete intent after edits. Edits can introduce new ambiguities.

The 4-pass ambiguity purge in session 84280c8b killed terms at
every level — a word ("bootstrap"), a phrase ("calibrate
verbosity"), and a mechanism ("more weight"). Each pass found
something the previous missed.
```

#### Section: Consolidated Presentation (insert after "Process" step 3)

```markdown
## Consolidated presentation

When multiple files in one task need intents, present ALL drafts
in a single message for single-round approval:

1. Draft all intents in the batch
2. Present them together with a tracking table:
   ```
   | File | Intent status |
   |------|---------------|
   | `file-a.md` | Draft below |
   | `file-b.json` | Draft below |
   | `file-c.md` | Draft below |
   ```
3. User reviews and approves the batch, or requests specific
   revisions

**Evidence**: In the tool-ops execution session (eaacf9da), batch 1
presented intents one at a time — 3 rounds, 15 minutes, corrections
on audience and purpose. By batch 5, the agent presented 4 intents
in one block — 1 round, approval in one word ("beautiful"), ~42
seconds for batch 6. Consolidation reduced approval friction by
10-15x.

**Why this matters for delegation**: Sub-agents cannot receive
user feedback during execution. Every intent that requires user
approval MUST be pre-approved before delegation. The sub-agent
receives verbatim intent text, not instructions to draft intent.
```

#### Section: Quality Criteria (insert after "Common failure modes")

```markdown
## Quality criteria

Apply this checklist to every intent before presenting for approval.
Adapted from the 6-criterion decision quality checklist (session
b8a9ed4e):

| Criterion | Check | Failure mode |
|-----------|-------|--------------|
| **Concrete purpose** | Does purpose name the specific deliverable, not just the topic? | "This file is about deployment" vs "Define which tools are managed and their install methods" |
| **Negative scope** | Does scope include at least one "NOT" exclusion? | Without boundaries, scope creep is inevitable |
| **Specific audience** | Does audience name specific consumers (skills, scripts, agents, hooks)? | "Agents" is too vague — which agents, doing what? |
| **Active verbs** | Does purpose use active verbs (govern, track, define, equip)? | Passive voice ("is used for") hides what the file actually does |
| **No restated title** | Does intent add information beyond the filename/title? | "This section covers the discovery cycle" — the title says that |
| **Exemplar match** | Does the structure match recently approved intents? | Stylistic mismatch signals the drafter didn't calibrate |
```

#### Section: Style Calibration (insert after or merged with Quality Criteria)

```markdown
## Style calibration

The approved intent style has converged through iteration:

**Markdown rules** (`.claude/rules/*.md`):
- Format: `**Intent**: **Purpose**: ... **Scope**: ... **Audience**: ...`
  as a single flowing paragraph
- Purpose: one clause, active verb, names the specific governance domain
- Scope: "X only. NOT Y. NOT Z." pattern — at least 2-3 exclusions
  referencing skill/framework/data that live elsewhere
- Audience: "Every agent, every session" OR specific consumers +
  context for why

**Governed JSON** (`meta.intent` in registry files):
- Format: `{ "purpose": "...", "scope": "...", "audience": "..." }`
- Purpose: one sentence, often a noun phrase with qualifying dash
- Scope: "X only. NOT Y. NOT Z." — same pattern as markdown but
  shorter
- Audience: names specific skills, scripts, hooks by name

**Skills** (`## Intent` section):
- Format: opening paragraph addressing all three, then "NOT X" lines
- More conversational than rules/JSON — skills are read by agents
  in working context
- Must name what the skill does NOT do (prevent confusion with
  related skills)
```

### For /intent-audit — New Sections

#### Section: Intent Quality Audit (insert as new step between current steps 1 and 2)

```markdown
### 1b. Audit the intent itself

Before checking content against intent, check whether the intent
itself is good. A well-aligned file with a bad intent is still
broken — the intent will guide future sessions to produce wrong
content.

Apply the quality criteria from `/intent-writing`:

| Check | Pass | Fail |
|-------|------|------|
| Purpose names specific deliverable | "Track harness deficiencies and drive corrective actions" | "Track things" |
| Scope has negative boundaries | "NOT the filing process. NOT the framework doc" | No exclusions |
| Audience names consumers | "/incident skill, /audit skill, check scripts, hooks" | "Agents" |
| Active verbs in purpose | "Govern", "Equip", "Define", "Track" | "Is about", "Contains" |
| No restated title | Adds information beyond filename | Repeats filename in different words |
| Conciseness matches exemplars | Comparable length to recently approved intents | 2x-3x longer than similar intents |

**Finding type**: If the intent fails quality checks, classify as
**Intent quality gap** — distinct from "Intent too narrow/broad"
(which is about coverage). A quality gap means the intent exists
but wouldn't pass the `/intent-writing` checklist.
```

#### Section: Multi-Pass Ambiguity Detection (insert after intent quality audit)

```markdown
### 1c. Scan for ambiguity

Perform at least 2 passes over the intent statement:

**Pass 1 — Undefined terms**: Flag any term that is not in the
governed vocabulary AND not self-evident to a fresh agent with no
project context. "Harness" is governed. "Bootstrap" is not — and
means different things in different contexts.

**Pass 2 — Terms with multiple meanings**: Flag terms that could
mean different things to different consumers. "Deployment" in this
codebase means both "managed file deployment" (interactive menu)
and "MDM/enterprise deployment" (deploy/ scripts). If the intent
uses "deployment" without qualification, that's ambiguous.

**Pass 3 — Barrier test**: Read ONLY the intent statement (ignore
the file's actual content). Mentally classify 3 hypothetical pieces
of content:
1. Something clearly in scope
2. Something clearly out of scope
3. Something borderline

If you cannot confidently classify #2 or #3 from the intent alone,
the intent has insufficient boundaries. Flag as **Intent ambiguity**.
```

#### Section: Exemplar Comparison (insert after "Classify findings")

```markdown
### 4b. Compare to exemplar intents

After classifying findings, compare the audited intent to the
current best exemplars (weight recent > old):

**Exemplar ranking** (as of 2026-03-16, most recent first):

1. `reference/tool-ops.json` meta.intent — approved 2026-03-15
   (batch 5, single-round approval)
2. `reference/incidents.json` meta.intent — approved 2026-03-15
   (batch 1, after 3-round iteration)
3. `reference/glossary.json` meta.intent — approved 2026-03-15
4. `.claude/rules/tool-ops.md` **Intent** — approved 2026-03-15
5. `.claude/rules/governed-data-access.md` **Intent** — approved
   2026-03-14
6. `.claude/rules/incident-governance.md` **Intent** — approved
   2026-03-15

**Comparison dimensions**:
- **Structure**: Does it follow the same purpose/scope/audience
  pattern?
- **Conciseness**: Is it comparable length, or significantly
  longer/shorter?
- **Specificity**: Are exclusions as concrete? Is audience as
  specific?
- **Active voice**: Does purpose use the same verb pattern?

If the audited intent is structurally weaker than the exemplars,
flag as **Intent quality gap** with the specific dimension that
diverges.
```

#### Update: Finding Classification Table (add new row)

```markdown
| **Intent quality gap** | Intent exists but fails quality criteria | Revise intent per `/intent-writing` quality checklist |
| **Intent ambiguity** | Intent contains undefined or multi-meaning terms | Ambiguity purge per `/intent-writing` multi-pass process |
```

---

## 3. Exemplar Intents from the Codebase (Ranked by Quality)

### Tier 1: Best exemplars (approved single-round, most recent)

**#1 — `reference/tool-ops.json` meta.intent**
```json
"intent": {
  "purpose": "Per-tool operational metadata for managed tools with deep harness integration — governance modes, deny rules, hooks, context injection, KPIs, and verification specs",
  "scope": "Operational metadata and governance modes only. NOT the ops knowledge itself. NOT install/versions. NOT incidents. NOT the framework definition",
  "audience": "/tool-ops skill, /audit skill, tool-ops-session-audit.sh hook, setup scripts"
}
```
- Approved: batch 5, session eaacf9da, one-word approval ("beautiful")
- Strengths: purpose uses noun-phrase-with-dash pattern, scope has 4 exclusions, audience names 4 specific consumers
- Date: 2026-03-15

**#2 — `.claude/rules/tool-ops.md` Intent block**
```
**Intent**: **Purpose**: Govern per-tool operational metadata for
managed tools with deep harness integration — governance modes,
deny rules, hooks, context injection, and verification specs.
**Scope**: The operational governance principle and trigger directive
only. NOT the ops data itself (`/tool-ops` skill). NOT the framework
documentation (`reference/framework-tool-ops.md`). NOT per-tool ops
references (`reference/tool-ops-*.md`). **Audience**: Every agent,
every session — tool behavior assumptions are the failure mode.
```
- Approved: batch 5, session eaacf9da, same one-word approval batch
- Strengths: purpose mirrors JSON but scoped to rule's role, scope links to skill (not JSON path), audience adds "why" clause
- Date: 2026-03-15

**#3 — `.claude/rules/governed-data-access.md` Intent block**
```
**Intent**: **Purpose**: Govern how governed JSON registries are
accessed — skill-gated, never direct. **Scope**: The access
principle and its enforcement. NOT which registries exist (see
`@.claude/rules/frameworks.md` registries table). NOT the framework
theory (`reference/framework-governed-data-access.md`). **Audience**:
Every agent, every session.
```
- Strengths: most concise rule intent — purpose is 10 words after the dash. Maximum information density.
- Date: 2026-03-14

### Tier 2: Good exemplars (approved after iteration)

**#4 — `reference/incidents.json` meta.intent**
```json
"intent": {
  "purpose": "Track harness deficiencies and drive corrective actions — spec deviations, ambiguities, and operational incidents with root cause analysis, remediation, and prevention layer assignment",
  "scope": "Incident entries only. NOT the filing process (incident-governance.md rule). NOT the framework documentation (framework-incident-governance.md). NOT incident reference files (reference/incident-*.md)",
  "audience": "/incident skill, /audit skill, check scripts, hooks, agents checking whether a deficiency has already been filed"
}
```
- Approved: batch 1, session eaacf9da, after 3 rounds (user added "drive corrective actions", "check scripts, hooks")
- Strengths: purpose evolved from "track" to "track and drive corrective actions" per user feedback. Audience expanded to include programmatic consumers per user correction.
- Date: 2026-03-15
- Learning: the initial draft said "track" — the user pushed for active improvement language. This is the canonical example of purpose being too passive.

**#5 — `reference/glossary.json` meta.intent**
```json
"intent": {
  "purpose": "Provide the authoritative definition for every governed term in the harness",
  "scope": "Definitions, facets, and abbreviation mappings only. NOT the word list (glossary rule). NOT the composition convention (framework-governed-vocabulary.md). NOT usage guidance (/glossary skill)",
  "audience": "/glossary skill, /audit skill, agents resolving terminology questions"
}
```
- Strengths: purpose is a single clause. Scope references 3 specific exclusions with parenthetical pointers. Audience is specific.
- Date: 2026-03-15

### Tier 3: Adequate (functional but less refined)

**#6 — `.claude/rules/glossary.md` Intent block**
```
**Intent**: **Purpose**: List every governed term, base artifact,
and scope modifier so agents always have them in context. **Scope**:
The word list only. NOT the definitions (use `/glossary` skill).
NOT the composition convention (see
`@reference/framework-governed-vocabulary.md`). **Audience**: Every
agent, every session.
```
- Adequate but purpose describes content ("list every governed term") rather than deliverable. Compare to governed-data-access ("govern how registries are accessed") which names the action.

---

## 4. Key Heuristics Summary (for plan writer)

### Heuristic 1: Multi-Pass Ambiguity Removal
**Source**: delegation-evolution.md §2
**Evidence**: 4 passes found "bootstrap" (undefined), "calibrate verbosity" (vague), "more weight" (no mechanism)
**Skill gap**: Neither skill mentions multi-pass. /intent-writing says "iterate" but doesn't describe the self-audit loop.
**Addition**: Explicit 2-3 pass process with named pass types (undefined terms, vague mechanisms, re-check after edits)

### Heuristic 2: Weight-by-Recency for Examples
**Source**: delegation-evolution.md §1 (L1101), intent-approval-evolution.md
**Evidence**: User's exact words: "the more recent the conversation where i confirmed i was happy, the more weight that intent should have"
**Skill gap**: /intent-writing has no guidance on using exemplars. /intent-audit has no comparison framework.
**Addition**: Exemplar calibration step with ranked exemplar list, comparison dimensions

### Heuristic 3: Pre-Write Governed Term Audit
**Source**: delegation-evolution.md §2 (L1115, "wtf is bootstrap?")
**Evidence**: Agent used "bootstrap" — not in glossary, not defined. User caught it. The term would have confused any executing agent.
**Skill gap**: Neither skill references /glossary or governed vocabulary
**Addition**: Check every term against governed vocabulary before presenting intent for approval

### Heuristic 4: Consolidated Presentation Pattern
**Source**: intent-approval-evolution.md §Phase 3
**Evidence**: Batch 1: 1 intent, 3 rounds, 15 min. Batch 5: 4 intents, 1 round, ~5 min. Batch 6: 1 intent, ~42 sec.
**Skill gap**: /intent-writing says "present to user" but doesn't mention batching
**Addition**: When multiple intents in one task, present all in single message with tracking table

### Heuristic 5: Quality Criteria Checklist
**Source**: decision-quality-audit.md (6 criteria), intent-approval-evolution.md (batch 1 corrections)
**Evidence**: The 6 criteria (scope, trace, enumerate, current, merge, refs) adapted to intent: concrete purpose, negative scope, specific audience, active verbs, no restated title, exemplar match
**Skill gap**: /intent-writing has "failure modes" but no structured checklist. /intent-audit has no intent-quality check.
**Addition**: 6-criterion quality checklist for both skills

### Heuristic 6: Barrier Analysis on Intent
**Source**: delegation-evolution.md §2 (the "wtf is bootstrap?" moment)
**Evidence**: The test: read ONLY the intent. Can you classify 3 pieces of content as in/out of scope? If not, the intent has insufficient boundaries.
**Skill gap**: /intent-audit checks content against intent but never tests whether the intent itself provides sufficient discrimination
**Addition**: Barrier test step in /intent-audit — classify hypothetical content using only the intent statement

### Heuristic 7: Style Convergence Documentation
**Source**: intent-approval-evolution.md §Three Adaptations (style calibration)
**Evidence**: Bold-label format, negative scope boundaries, active verbs in purpose, programmatic consumers in audience — all emerged through iteration and are now consistent across all 9 rule intents and 3 JSON intents
**Skill gap**: /intent-writing shows format examples but doesn't document the converged style as a norm to match
**Addition**: Style calibration section documenting the approved patterns for rules, JSON, and skills
