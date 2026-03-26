# Delegation Prompt: Provenance-Aware Knowledge System — Establish the Framing

## Identity

You are S3-Provenance. Broad authority to design, write, and ship.

## Mission

aitools is a provenance-aware knowledge system. This must be reflected in the harness definition and governing artifacts before this session ends. This is not aspirational — it's definitional. The session that identified this is the current one, and the framing must persist.

What needs to happen:
1. Update `reference/harness.md` — add provenance as the sixth component alongside platform, configuration, orchestration, managed tools, frameworks
2. Update `CLAUDE.md` — the mission statement and design principles should reflect provenance-aware knowledge system
3. Propose schema additions to `reference/harness-db-schema.sql` — `knowledge_items`, `provenance_edges`, `nogood_sets` tables (from the provenance investigation)
4. Write `reference/framework-provenance.md` — the framework documentation for this new capability, following the pattern of existing framework-*.md files

The framing: every piece of operational learning, every decision, every work product has provenance — what it was based on, when, by whom, and whether the basis has been superseded. When an assumption is falsified, everything downstream is flagged.

This is grounded in: de Kleer's ATMS (truth maintenance), W3C PROV (derivation chains), the self-evolution proposals' ascending spiral, and the operational experience of THIS session where wrong assumptions propagated through work product and delegation chains.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — ALL of it
2. `/Users/pepe/repos/aitools/CLAUDE.md` — current state, needs updating
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/repos/aitools/reference/harness.md` — current harness definition, needs updating
6. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/provenance-and-infrastructure-findings.md` — the provenance investigation with schema proposals
7. `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/self-evolution-proposals.md` — ascending spiral, learning_provenance table design
8. `/Users/pepe/repos/aitools/reference/framework-adoption.md` — how frameworks are adopted (follow this pattern)
9. `/Users/pepe/repos/aitools/reference/framework-three-layer-governance.md` — three-layer registry pattern (follow this)
10. `/Users/pepe/repos/aitools/.claude/rules/sources-of-truth.md` — CLAUDE.md and harness.md are protected files. Draft changes and present clearly.

## Protected Files

CLAUDE.md, reference/harness.md, and reference/harness-db-schema.sql are protected. Draft the changes as clearly marked proposals. The delegate that ships code changes can commit non-protected files directly. Protected file changes need to be clearly presented.

## Output

Write all work product to the session scratch directory. For protected file changes, write the proposed content as `proposed-harness.md`, `proposed-claude-md-changes.md`, etc. Write OL.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
