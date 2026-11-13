# Intent Documentation

**Intent**: **Purpose**: Document the framework for declaring purpose,
scope, and audience in every file and major section. **Scope**: What
knowledge management and ISO documentation principles we adopted and
why. NOT the process for writing intents (see `/intent-writing` skill).
NOT the process for auditing intents (see `/intent-audit` skill). NOT
the review of intent changes (D-DEL5, user rule `delegation.md`).
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
- **Review after** → an intent change is written in its final
  location and committed; the commit or PR body lists it old -> new
  under "Review after", and the commander reviews it after (D-DEL5,
  user rule `delegation.md`). Intent shapes interpretation — getting
  it wrong has downstream effects across sessions.
- **Intent verification** → `/intent-audit` skill checks each
  section against the stated intent, classifies drift, and surfaces
  findings for the DTCC.
- **Detection hook** (planned) → PreToolUse prompt hook on
  Write/Edit reminds agents to check intent before writing.

## How It's Maintained

- `/intent-writing` skill teaches the drafting process
- `/intent-audit` skill checks alignment on demand
- Intent changes are reviewed after the write: old -> new under
  "Review after" in the commit or PR body (D-DEL5, user rule
  `delegation.md`)
- PreToolUse hook (planned, governance plan step 8) provides
  real-time detection
- Existing files are backfilled incrementally — new files must
  include intent at creation time

## Implementing Artifacts

- `@shared/skills/intent-writing/SKILL.md` (drafting process)
- `@shared/skills/intent-audit/SKILL.md` (verification process)

## Cross-References

- Framework registry: `/frameworks` skill
- Framework adoption: `@reference/framework-adoption.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Governed vocabulary: `@reference/framework-governed-vocabulary.md`
  (intent uses governed terms: purpose, intent scope, audience)
