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
filing gaps discovered during the audit (use `/gap` after). NOT for
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

### 5. Propose resolution

For each finding, propose a specific action:
- **Move**: name the destination file (create if needed)
- **Split**: propose new file with its own intent
- **Amend intent**: draft the revised intent (protected — needs
  user approval)
- **File gap**: when no destination exists, file via `/gap`

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
- Gap filing: `/gap` skill
