---
name: intent-audit
description: "Audit a file against its intent statement. Use when
  checking if a file's content matches its stated purpose, or when
  content may have drifted beyond scope."
---

## Intent

Equip the agent with a structured process for intent verification:
given a file and its intent statement, check each section against
the stated purpose, classify content that has drifted beyond scope,
and surface findings for the discovery-to-continuation cycle.

Inputs: a file path (the agent reads the file and its intent).
Outputs: an alignment report classifying each finding by type. Each
finding is a potential trigger for the discovery-to-continuation
cycle (`@reference/framework-adoption.md`).

NOT for writing intent statements (see `/intent-writing`). NOT for
filing gaps discovered during the audit (use `/incident` after). NOT for
deciding where displaced content should live (that requires design
decisions informed by `@reference/framework-adoption.md`).

## When to use

- After significant additions to a file
- When a file feels "too big" or covers too many topics
- During `/audit` governance reviews
- When moving content between files
- Periodically on high-traffic files (CLAUDE.md, rules, reference
  files)

## Process

### 1. Read the intent

Read the file's intent statement (`**Intent**:` block or header
comment). If the file has no intent statement, flag that as the
first finding — every file needs one per the Document intent
design principle (`@CLAUDE.md`).

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
| Conciseness matches exemplars | Comparable length to recently approved intents | 2x-3x longer |

If the intent fails quality checks, classify as **Intent quality gap** —
distinct from "Intent too narrow/broad" (which is about coverage). A
quality gap means the intent exists but wouldn't pass the
`/intent-writing` checklist.

### 1c. Scan for ambiguity

Perform at least 2 passes over the intent statement:

**Pass 1 — Undefined terms**: Flag any term not in the governed
vocabulary AND not self-evident to a fresh agent with no project
context. "Harness" is governed. "Bootstrap" is not — and means
different things in different contexts.

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

### 2. Decompose the content

For each section in the file, identify:
- What purpose does this section serve?
- Who consumes it (agent, script, human)?
- Is it process (how to do something) or state (what currently
  exists)?

### 3. Check alignment

For each section, ask three questions:
- **Serves the purpose?** Does this section directly support what
  the file exists to deliver?
- **Within scope?** Is this within the stated inclusions and
  exclusions?
- **Right audience?** Does this section's consumer match the
  intent's stated audience?

### 4. Classify findings

Each misalignment is one of:

| Finding | Meaning | Resolution |
|---------|---------|------------|
| **Scope creep** | Content serves a valid purpose but belongs elsewhere | Move to correct file, add `@` reference |
| **State in process** | Mutable data in a process/convention document | Move to registry JSON or state file |
| **Process in state** | How-to guidance in a data file | Move to rule or reference |
| **Missing home** | Content has no correct destination yet | File a gap — the harness is missing a home for this content |
| **Intent too narrow** | Content is correct here but intent doesn't cover it | Propose intent amendment (protected activity) |
| **Intent too broad** | Intent promises more than the file delivers | Propose intent amendment or split file |
| **Intent quality gap** | Intent exists but fails quality criteria from `/intent-writing` | Revise intent per quality checklist |
| **Intent ambiguity** | Intent contains undefined or multi-meaning terms | Ambiguity purge per `/intent-writing` multi-pass process |

### 4b. Compare to exemplar intents

After classifying findings, compare the audited intent to the
current best exemplars (weight recent > old):

**Exemplar ranking** (as of 2026-03-16, most recent first):

1. `reference/tool-ops.json` meta.intent — approved 2026-03-15
2. `.claude/rules/tool-ops.md` **Intent** — approved 2026-03-15
3. `.claude/rules/governed-data-access.md` **Intent** — approved 2026-03-14
4. `reference/incidents.json` meta.intent — approved 2026-03-15
5. `reference/glossary.json` meta.intent — approved 2026-03-15

**Comparison dimensions**:
- **Structure**: Does it follow the same purpose/scope/audience pattern?
- **Conciseness**: Is it comparable length, or significantly longer/shorter?
- **Specificity**: Are exclusions as concrete? Is audience as specific?
- **Active voice**: Does purpose use the same verb pattern?

If the audited intent is structurally weaker than the exemplars,
flag as **Intent quality gap** with the specific dimension that
diverges.

### 5. Propose resolution

For each finding, propose a specific action:
- **Move**: name the destination file (create if needed)
- **Split**: propose new file with its own intent
- **Amend intent**: draft the revised intent (protected — needs
  user approval)
- **File gap**: when no destination exists, file via `/incident`

Present all findings and proposed resolutions to the user before
making changes. Moving content between files and amending intents
are both protected activities.

## Output format

```
## Intent Audit: <filename>

**Intent**: <quoted intent statement>

### Aligned
- Section X: serves intent ✓
- Section Y: serves intent ✓

### Findings
1. **<finding type>**: <section name>
   - Content: <what's there>
   - Issue: <why it doesn't align>
   - Resolution: <move to X / split into Y / amend intent>

### Summary
- N sections aligned
- N findings (N scope creep, N state-in-process, ...)
- N proposed moves, N intent amendments, N gaps to file
```

## Detection pairing

This skill is the audit layer for intent. The detection layer is a
lightweight PreToolUse prompt hook on Write/Edit that reminds:
"Check target file's intent before writing." The agent already has
this skill in context (injected via SubagentStart cache) to know
what that means. The hook spec lives in
`@plans/governance-and-compliance-framework.md` step 8.

## Anti-patterns

- Auditing without reading the intent first (you'll rationalize
  everything as aligned)
- Proposing to delete content without identifying where it belongs
- Amending the intent to match whatever content exists (intent
  guides content, not the other way around — unless the intent was
  genuinely wrong)
- Auditing only at file level (section-level intents matter too)

## Cross-References

- Intent writing: `/intent-writing` skill
- Framework: `@reference/framework-adoption.md`
- Protection rule: `@.claude/rules/sources-of-truth.md`
- Gap filing: `/incident` skill
