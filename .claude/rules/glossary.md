## Glossary (this repo)

**Intent**: **Purpose**: List every governed term, base artifact,
and scope modifier so agents always have them in context. **Scope**:
The word list only. NOT the definitions (use `/glossary` skill).
NOT the composition convention (see
`@reference/framework-governed-vocabulary.md`). **Audience**: Every
agent, every session.

### Scope modifiers

project
shared
dotprofile
user

### Base artifacts

alias
claude
config
hook
rule
skill

### Terms

accept & adopt
adoption
agent
aitools
aitools repo
ambiguity
Anthropic
Claude Code
CC
artifact
audience
audit
auto-merge menu
configuration
controlled distribution
context rot
created
cross-reference
cursor rule
deployment scope
design principle
DP
detection
discovery context
discovery-to-continuation cycle
DTCC
discipline
dotprofile repo
drift
expected
file classification
framework
gap
governed file
governed vocabulary
harness
impact
intelligence
intent
intent scope
intent verification
key decision
KD
managed tool
merge-conflict menu
observation
orchestration
platform
preserved
prevention
process deviation
provenance
project coaching item
PCI
project standing order
PSO
purpose
registry
scope creep
skill-as-capability
skipped
state audit
suggested resolution
surfacing duty
The Commander
three-layer governance
trigger
updated
user coaching item
UCI
user standing order
USO
verified

accepting session
assumption
Auftrag
blast radius
blocker
cross-boundary
delegating agent
handoff
Lagebeurteilung
lifecycle transition
Mitdenken
Reibung
Schwerpunkt

### When to invoke /glossary

Invoke the `/glossary` skill (not the raw JSON file) when ANY of
these arise in conversation:

- Checking whether a term is governed
- Discussing what to name a concept
- Resolving a terminology ambiguity (two words for same thing, or
  one word with two meanings)
- Adding a new governed term
- User mentions "glossary", "governed term", "vocabulary", or asks
  "what should we call X?"

The skill provides the governed PROCESS (check rule, check JSON,
determine type, draft entries, present for review). Reading the file
directly bypasses that process.

Definitions: `/glossary` skill
Composition: `@reference/framework-governed-vocabulary.md`
