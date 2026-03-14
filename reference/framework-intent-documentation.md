# Intent Documentation

**Intent**: **Purpose**: Document the framework for declaring purpose,
scope, and audience in every file and major section. **Scope**: What
knowledge management and ISO documentation principles we adopted and
why. NOT the process for writing intents (see `/intent-writing` skill).
NOT the process for auditing intents (see `/intent-audit` skill). NOT
the protection rule (see `@.claude/rules/sources-of-truth.md`).
**Audience**: Agents encountering intent statements, framework
adoption work.

## Source Discipline

Knowledge management — specifically:
- **ISO/ITIL/CMMI document structure** — every document states its
  purpose (what it delivers), scope (what's covered and excluded),
  and intended audience (who reads it)
- **Documentation as governance** — intent statements shape how all
  future sessions interpret a file. A file without intent is
  ambiguous by definition.
- **Intent verification** — adopted from conformance checking
  (process mining / quality management). Checking that content
  matches its stated intent.

## How We Adopted It

- **Three-component intent** → purpose, scope, audience. Adapted
  from ISO document structure to work across markdown files, code
  files, JSON files, and section-level declarations.
- **Protected activity** → intent statements require user approval
  before writing or modifying, same gate as sources-of-truth.
  Intent shapes interpretation — getting it wrong has downstream
  effects across sessions.
- **Intent verification** → `/intent-audit` skill checks each
  section against the stated intent, classifies drift, and surfaces
  findings for the DTCC.
- **Detection hook** (planned) → PreToolUse prompt hook on
  Write/Edit reminds agents to check intent before writing. The
  agent has the `/intent-audit` skill in context via SubagentStart
  cache.

## How It's Maintained

- `/intent-writing` skill teaches the drafting process
- `/intent-audit` skill checks alignment on demand
- Intent protection in `@.claude/rules/sources-of-truth.md` gates
  all writes
- PreToolUse hook (planned, governance plan step 8) provides
  real-time detection
- Existing files are backfilled incrementally — new files must
  include intent at creation time

## Implementing Artifacts

- `@shared/skills/intent-writing/SKILL.md` (drafting process)
- `@shared/skills/intent-audit/SKILL.md` (verification process)
- `@.claude/rules/sources-of-truth.md` (protection gate)
- `@CLAUDE.md` "Document intent" design principle

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Framework adoption: `@reference/framework-adoption.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Governed vocabulary: `@reference/framework-governed-vocabulary.md`
  (intent uses governed terms: purpose, intent scope, audience)
