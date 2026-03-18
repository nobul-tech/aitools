# Reading Order Audit: Decisions #53, #54, and Missing Decisions

**Date**: 2026-03-16
**Source**: `plans/mission-command-briefing/planning-brief.json` meta.readingOrder
**Auditor**: S2 (session RTzBnBupE6)

## Finding: 6 decisions missing from readingOrder

The `meta.readingOrder.sequence` in the brief JSON stops at phase 11. The
handoff prompt (`plans/mission-command-briefing/handoff-prompt.md`) describes
phases 12 and 13, but these were never written into the brief's actual
`readingOrder` field. Missing decisions:

| ID | Decision | Status |
|----|----------|--------|
| #31 | MERGED into #8 | merged — correctly excluded |
| #49 | Flat verb skill naming | agreed |
| #50 | Running estimate | agreed |
| #51 | Plan-writing protocol | agreed |
| #52 | Plan Writer role definition | agreed |
| #53 | Governed document drift prevention | proposed |
| #54 | Harness improvement cycle | proposed |

The /brief skill presents decisions in readingOrder. Any decision not in
readingOrder will not be presented, meaning S3 would miss 6 active decisions
during plan consumption. This is a critical data integrity issue.

---

## Q1: Where should #53 (governed document drift prevention) go?

**Recommendation: Phase 10 (Infrastructure decisions), after #42.**

Rationale:

1. **It IS infrastructure.** Decision #53 creates three concrete artifacts:
   `governedBy` schema field (data infrastructure), `rule-write-impact.sh`
   (hook infrastructure), and `plan-gate.sh` extension (hook infrastructure).
   These are structural enforcement mechanisms, not process definitions.

2. **Its dependencies are all in earlier phases.** #53's related decisions
   span phases 4-11 (#3 in phase 4, #29/#41 in phase 5, #20/#22/#26 in
   phase 6, #45 in phase 8, #34 in phase 10, #35 in phase 11). By phase 10,
   the reader has seen every dependency except #35 (phase 11) and the
   not-yet-placed #50 and #54. But #35 is a principle ("structural over
   behavioral") that #53 implements, not a sequential dependency.

3. **It extends #41 (plan-gate) and #42 (intent-enforcement).** Component (4)
   of #53 is explicitly "extend plan-gate.sh (decision #41)." Decision #42
   is already in phase 10. Placing #53 immediately after #42 groups all hook
   infrastructure together.

4. **Phase 11 (Process) is wrong.** #53 is not a process decision. It is
   concrete infrastructure (schema field, two hooks) that enforces a
   governance concern. The process it supports is documented elsewhere.

5. **Phase 13 (end) is actively harmful.** The plan-gate drift check
   (component 4) should be understood by S3 before the plan-writing
   protocol (#51/#52). If S3 reads #51 first without knowing about drift
   prevention, the Plan Writer's systemic-finding escalation (component 15
   of #51) lacks context about what drift prevention infrastructure exists.

**Placement: Phase 10, items: [32, 33, 34, 42, 53]**

---

## Q2: Where should #54 (harness improvement cycle) go?

**Recommendation: Phase 11 (Process decisions), after #48.**

Rationale:

1. **It IS process, not infrastructure.** Decision #54 explicitly states in
   component (12): "Placement: orchestration pattern, not a new skill. Main
   agent follows steps using existing skills." There are no new hooks, no new
   schema fields, no new scripts. It is a 12-step process definition.

2. **It depends on #35 and #48 (both in phase 11).** #54's rationale directly
   cites #35 ("structural enforcement over behavioral") and #48 ("fix-right
   is the default"). These are its philosophical foundations. The reader
   should encounter those principles before seeing the cycle that
   operationalizes them.

3. **It is referenced by #51 (plan-writing protocol).** Component (15) of #51
   says: "invoke the harness improvement cycle per decision #54." If #54 is
   read AFTER #51, the reader encounters a forward reference to an unknown
   process. Placing #54 in phase 11 (before the plan-writing protocol in
   phase 12) eliminates the forward reference.

4. **Phase 9 (Operational Learning) is close but wrong.** Phase 9 contains
   framework-specific operational learning decisions (#1, #2, #10-12, #14,
   #18, #30, #46, #47). These are concrete capabilities (session archive,
   harvesting, scratch). #54 is a meta-process that governs how ALL findings
   become fixes across ALL frameworks. It belongs with the other cross-cutting
   process decisions (#35, #48), not with domain-specific capabilities.

5. **Phase 12 (plan-writing) is tempting but wrong.** Although #51 references
   #54, the improvement cycle is not specific to plan-writing. It applies to
   any session where a finding surfaces. Placing it in phase 12 would
   incorrectly scope it to plan-writing.

**Placement: Phase 11, items: [35, 48, 54]**

---

## Q3: Other readingOrder issues

### Issue 1: Decisions #49, #50, #51, #52 are also missing

The handoff prompt describes a "Phase 12: Plan-writing protocol" with
decisions #49, #50, #51, #52. This was never written into the brief's
readingOrder. These 4 decisions need a phase.

**Recommendation:**

- **#49 (flat verb naming)**: Phase 6 (Mission Command). Naming conventions
  (#16) are already in phase 6. #49 refines naming for skills specifically.
  It should follow #16. However, #49 also affects operational learning skills
  (/debrief, /harvest) and mission analysis skills (/brief). It is truly
  cross-cutting. Phase 6 is acceptable because that is where naming (#16) and
  skill definitions (#4, #44) already live.

- **#50 (running estimate)**: Phase 10 (Infrastructure). The running estimate
  is infrastructure: a schema, a SessionStart hook, a file path convention.
  It depends on #22 (channel, phase 6) and #23 (schemas, phase 6), both
  already read by phase 10. Place after #34 (which governs the .aitools/
  namespace where the estimate lives) and before #42.

- **#51 (plan-writing protocol)** and **#52 (Plan Writer role)**: New Phase 12
  (Plan-writing protocol). These two decisions define the process by which S3
  writes the plan. They depend on almost everything in phases 4-11. They must
  be read last among the decisions (before only the governance additions, if
  any remained). #52 depends on #51 (defines the role that #51's protocol
  uses), so order is #51 then #52.

### Issue 2: Phase 10 ordering with #50 and #53 inserted

With #50 and #53 added, phase 10 items should be ordered by dependency:

1. #32 (log_ship/telemetry) — foundational infrastructure
2. #33 (Auth0 credentials) — feeds #32
3. #34 (.aitools/ namespace) — directory structure
4. #50 (running estimate) — lives in .aitools/ (#34), needs channel (#22)
5. #42 (intent-enforcement hook) — hook infrastructure
6. #53 (drift prevention) — extends plan-gate (#41), hook infrastructure

### Issue 3: #49 placement ambiguity

Decision #49 is about naming conventions for skills. It could go in:
- Phase 6 (Mission Command) — where #16 (naming conventions) already lives
- Phase 9 (Operational Learning) — where many of the named skills (#46, #47) live
- A new "Cross-cutting conventions" phase between 9 and 10

I recommend phase 6 after #16. The naming convention is foundational context
that helps the reader parse all subsequent skill references. Reading "skills
use flat verbs" in phase 6 means every skill reference in phases 7-12 is
immediately parseable.

### Issue 4: No other existing decisions are misplaced

All 47 decisions currently in readingOrder phases 1-11 are correctly placed.
No re-sequencing needed within existing phases.

---

## Updated readingOrder JSON

```json
"readingOrder": {
  "description": "Recommended consumption sequence for the executing agent. IDs are stable — this reorders without renumbering. /brief skill presents decisions in this order.",
  "sequence": [
    {
      "phase": "1. Critical blockers — resolve before anything",
      "items": ["F1", "F2", "F3", "F17"]
    },
    {
      "phase": "2. All facts — verified ground truth",
      "items": ["F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "F16", "F18"]
    },
    {
      "phase": "3. All assumptions — accepted for planning, unverified",
      "items": ["A1", "A2", "A3", "A4", "A5", "A6", "A7"]
    },
    {
      "phase": "4. Framework definitions — build mental model before reading decisions",
      "items": [3, 8, 13, 36, 37, 38]
    },
    {
      "phase": "5. Critical blocker resolution decisions",
      "items": [29, 39, 40, 41]
    },
    {
      "phase": "6. Mission Command decisions",
      "items": [4, 5, 6, 7, 15, 16, 49, 17, 19, 20, 22, 23, 24, 25, 26, 27, 28, 44]
    },
    {
      "phase": "7. Platform Engineering decisions",
      "items": [9]
    },
    {
      "phase": "8. Mission Analysis decisions",
      "items": [21, 43, 45]
    },
    {
      "phase": "9. Operational Learning decisions",
      "items": [1, 2, 10, 11, 12, 14, 18, 30, 46, 47]
    },
    {
      "phase": "10. Infrastructure decisions",
      "items": [32, 33, 34, 50, 42, 53]
    },
    {
      "phase": "11. Process decisions",
      "items": [35, 48, 54]
    },
    {
      "phase": "12. Plan-writing protocol",
      "items": [51, 52]
    }
  ]
}
```

### Changes from current readingOrder

| Change | Rationale |
|--------|-----------|
| #49 inserted in phase 6 after #16, before #17 | Naming convention — foundational context for all skill references |
| #50 inserted in phase 10 after #34, before #42 | Infrastructure: schema + hook + file path. Depends on #34 (.aitools/ namespace) |
| #53 inserted in phase 10 after #42 | Infrastructure: governedBy field + 2 hooks. Extends #41 (plan-gate) |
| #54 inserted in phase 11 after #48 | Process: orchestration pattern. Depends on #35/#48 principles |
| #51, #52 in new phase 12 | Plan-writing protocol depends on everything in phases 4-11. Must be last |
| Phase 13 eliminated | All decisions now placed in phases 6, 10, 11, or 12 |

### Key sequencing properties preserved

- #53 (drift prevention) is read BEFORE #51 (plan-writing) — S3 knows what drift infrastructure exists when reading the Plan Writer's systemic-finding escalation
- #54 (improvement cycle) is read BEFORE #51 (plan-writing) — S3 understands the cycle that #51 component (15) references
- #50 (running estimate) is read AFTER #34 (.aitools/) and BEFORE #53 — the namespace is established, then state management, then drift prevention
- #49 (flat verbs) is read BEFORE any phase that references specific skill names
