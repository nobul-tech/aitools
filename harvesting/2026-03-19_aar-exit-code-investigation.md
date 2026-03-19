# AAR: Exit Code 1 Investigation Chain

**Session**: Z1IhGrcgGO (2026-03-17/19)
**Scope**: From "what is exit 1" through full investigation chain
**Agent**: S3 (main session agent)
**Status**: Lessons identified, none learned (no proposals implemented/verified)

## Observations

### O-1: Assumptions are untracked outside the planning brief
Session-level assumptions (scratch persists, subagents have Write, next session will read handoff) are invisible until failure. 8 false assumptions identified, zero tracked before failure.

### O-2: Ambiguities are partially governed but inconsistently tracked
9 term ambiguities identified in conversation. Zero filed via /glossary or /incident. Surfacing duty doesn't distinguish terminological (→/glossary) from structural (→/incident).

### O-3: PCI language assumes a fixed S3
"S3 MUST inspect" should be "the delegating agent MUST inspect" — delegation duty is recursive per decision #7.

### O-4: "Next session" is an assumption
The handoff is an offer of continuity, not a mandate. The accepting session may not be the next CC session. Handoff language should say "the accepting session" not "the next session."

### O-5: Carry-forward data model needs session identity
Handoffs accumulate (one per session). Path should include session identity. Running estimate needs version tracking so accepting session can detect drift.

## Insights

### I-1: Assumptions need the same governance as incidents
Three-layer: surfacing duty (prevention), Lagebeurteilung walkthroughs (detection), /audit (audit). Tracked in running estimate (session-level) and planning brief (plan-level). Lifecycle: unverified → verified (becomes fact) OR falsified (becomes finding).

### I-2: Ambiguity routing needed
Terminological → /glossary. Structural → /incident. Surfacing duty must route explicitly.

### I-3: Delegation is a lifecycle transition — PCI applies at EVERY delegation
Every delegation crosses a context boundary. The 9-component delegation duty is a PCI. Recursive per decision #7.

### I-4: Handoff-session relationship is not 1:1
Handoffs are FROM session-A's S3 TO some-future-session's S3. Discovery via SessionStart hook. Staleness detection via running estimate version comparison.

### I-5: "Wave 0" assumption
Untracked session-level assumption. If the assumptions framework existed, it would have been surfaced and flagged.

## Proposals

### P-1: Assumptions framework
Track in running estimate (session-level) and planning brief (plan-level). Schema: {assumption, madeBy, madeAt, status, verifiedBy, impact}. Lagebeurteilung walkthroughs flush them out.

### P-2: Ambiguity routing
Extend surfacing duty: terminological → /glossary, structural → /incident. Update incident-governance.md.

### P-3: PCI language correction
"Delegating agent MUST inspect" not "S3 MUST inspect." Applies recursively.

### P-4: Handoff path with session identity
`.aitools/channel/handoffs/<session-date>_<session-prefix>.md`. SessionStart hook announces available handoffs.

### P-5: "Accepting session" language
Replace "next session" with "the accepting session." Add staleness note about running estimate version drift.

### P-6: Lagebeurteilung as general-purpose capability
Mandatory category walkthroughs for: incident response, session end, delegation, batch boundaries, session start. Categories: Forces/Terrain/Time/Logistics adapted per transition type.

## Glossary gaps
blocker, lifecycle transition, blast radius, assumption, accepting session, delegating agent, PCI, cross-boundary, Schwerpunkt, Lagebeurteilung, Reibung, Mitdenken, Auftrag, handoff (file vs process), session (CC vs working)

## Related decisions
#3 (Mission Command framework), #4 (delegation duty 8 components), #7 (recursive), #25 (staff functions), #26 (S2 at start/end), #34 (namespace), #36 (Operational Learning), #48 (fix-right), #50 (running estimate), #52 (Plan Writer calibration), #54 (harness improvement cycle)
