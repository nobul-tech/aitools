# Decision #54: Harness Improvement Cycle — Finding to Verified Fix

**Author**: S2 (Intelligence)
**Date**: 2026-03-16
**Classification**: Process decision — self-refinement analysis

---

## 1. Analysis: Interactions, Scope, Placement

### What this decision captures

Session RTzBnBupE6 produced a 10-step workflow that emerged organically
but proved highly effective: a finding triggers structured investigation,
the investigation produces AAR-formatted proposals with barrier analysis,
proposals are executed by an editor subagent in worktree isolation,
a separate auditor subagent re-runs the original check to verify, and
unresolved items get parallel investigation. The cycle iterates until
clean, then presents to the user.

This is the harness's self-improvement process — how findings become
verified fixes. Without it, findings are ad-hoc and fixes are
unverified.

### Where does this live?

This is a PROCESS decision that touches multiple skills and rules:

- **`/investigate` skill** — already exists as the structured investigation
  tool. This decision formalizes that /investigate output feeds the cycle.
- **`/delegate` skill** — the delegation protocol governs how subagents
  are launched (S2 for investigation, S3 for editing, S2 for verification).
- **`/debrief` skill** — the AAR schema is the required output format
  (decision #44).
- **Operational Learning rule** — this cycle IS operational learning
  applied in real-time, not just at plan end.

The decision should NOT create a new skill. The workflow is an
orchestration pattern — the main agent follows the cycle using existing
skills (/investigate, /delegate, /debrief). A new skill would violate
the flat-verb principle (#49) and create a compound operation disguised
as a single action.

The right placement is:
1. A **process section in the operational learning rule** (`.claude/rules/operational-learning.md`, proposed in #36) — the cycle is an instance of operational learning applied in real-time
2. A **delegation template addition in /delegate skill** — the 3-subagent pattern (investigator, editor, auditor) becomes a reusable delegation template
3. A **brief decision** that captures the resolved design and references

### Interaction map with existing decisions

| Decision | Relationship | How they interact |
|----------|-------------|-------------------|
| #4 (Delegation duty) | Governs | The cycle uses delegation for every subagent launch. 8-component duty applies to each. |
| #35 (Structural > behavioral) | Principle | The cycle IS the structural mechanism for turning findings into verified harness fixes. Without it, "investigate findings" is a behavioral expectation. |
| #36 (Operational Learning) | Framework parent | The cycle is operational learning applied in real-time rather than at plan end. AAR schema is the output format. Barrier analysis is the validation method. |
| #44 (S2 AAR output) | Governs output | Every S2 subagent in the cycle produces AAR-formatted output (observations, insights, proposals with barrier analysis). |
| #48 (Fix-right decision tree) | Trigger | The fix-right tree's "can fix properly? can delegate?" steps lead INTO this cycle. The cycle is HOW you "do it right." |
| #53 (Governed document drift) | Instance | The workspace drift fix was the first instance of this cycle. The cycle produced decision #53. |
| #45 (Brief as governed data) | Complementary | The cycle may produce changes to the brief. Those changes go through /brief skill. |
| #41 (Plan-gate hook) | Complementary | The plan-gate ensures stale decisions don't escape. The cycle is how stale decisions get fixed. |
| #46 (Scratch collision prevention) | Applies | Multiple parallel subagents in the cycle need collision-resistant output naming. |

### Failure modes

1. **Infinite loop**: Finding → fix → re-audit finds more issues → fix → re-audit... Mitigation: cap at 3 iterations. After 3, present current state to user with outstanding items.
2. **Scope creep**: A finding about workspace gitignore leads to redesigning the entire workspace system. Mitigation: the cycle has a scope gate — each iteration re-checks against the ORIGINAL finding, not the expanded scope.
3. **Subagent quality**: S2 investigation produces bad analysis, S3 editor misapplies edits. Mitigation: spot-check after every subagent (UCI compliance, already proven in this session when spot-check caught S2's wrong claim).
4. **Over-engineering**: Every small finding gets the full 10-step cycle. Mitigation: the cycle has an entry gate — only findings with harness improvement potential proceed past step 4. Point fixes skip to step 7 directly.
5. **Parallel analysis wasted**: 3 barrier analyses launched for options where 1 is obviously best. Mitigation: parallel analysis only when options are genuinely competing (no clear winner without analysis).

### KPI considerations

- **Time from finding to verified fix**: Sessions between finding surfaced and fix verified clean by re-audit.
- **Re-audit pass rate**: Percent of fix attempts that pass re-audit on first try.
- **Iteration count**: Average iterations before clean (target: <= 2).
- **Spot-check catch rate**: Percent of subagent outputs where spot-check found material errors.
- **Parallel analysis efficiency**: Percent of parallel analyses where synthesis changed the pre-analysis favorite.

---

## 2. Draft v1 — Complete Decision JSON

```json
{
  "id": 54,
  "decision": "Harness improvement cycle: finding to verified fix through structured investigation, parallel barrier analysis, worktree-isolated editing, and independent re-audit — the process by which the harness improves itself",
  "rationale": "Session RTzBnBupE6 produced a 10-step workflow: user questioned `.aitools/channel/` placement → S2 investigated → main agent spot-checked (caught material error) → user clarified intent → S2 audited brief against new rule (AAR-format output with 14 proposals) → user pushed for institutional approaches → 3 parallel S2 barrier analyses on options from framework provenance → S3 applied amendments in worktree isolation → S2 re-audited (14→1 inconsistencies, 0 intent issues) → S2 designed structural fix. The workflow was effective because: (a) structured output (AAR schema) enabled mechanical consumption by downstream agents, (b) the same check that found the problem verified the fix (independent auditor from editor), (c) parallel barrier analysis with the same framework enabled apples-to-apples option comparison, (d) worktree isolation prevented half-applied edits from corrupting main, (e) spot-checking caught subagent errors before they propagated, (f) provenance-informed options searched institutional disciplines before inventing from scratch. Without this cycle formalized, each session reinvents the investigation-to-fix process, losing the structure that made it effective.",
  "context": "Session RTzBnBupE6: workspace rule (.claude/rules/aitools-workspace.md) superseded 5 planning brief decisions. The fix required: investigation (channel-placement-investigation.md), workspace audit (workspace-audit.json with 14 proposals), 3 parallel barrier analyses (barrier-governed-by.md, barrier-fragord.md, barrier-amendment.md), full prevention stack design (investigate-full-prevention.md), worktree-isolated amendment application (10/10 applied), independent re-audit (workspace-reaudit.json: 14→1, 0 intent issues), and structural decision design (investigate-governed-drift-decision.md producing decision #53). User explicitly pushed for efficiency ('this feels very inefficient'), institutional provenance ('search our framework provenance'), and bigger thinking ('what about hooks? think outside current capabilities').",
  "components": [
    "(1) Entry gate: finding emerges from any source (AAR proposal, /audit output, check script, user observation, S2 investigation, incident). Evaluate: does this finding have harness improvement potential? Point fixes (typo, missing field) skip to step 7. Systemic findings (pattern across decisions, new class of problem, governance gap) proceed through full cycle",
    "(2) S2 structured investigation: delegate to S2 with delegation duty (#4) + AAR schema injection (#44). S2 audits the finding against governing artifacts (rules, references, incidents, code). Output: AAR-format JSON — observations (what was found, with file citations), insights (why it matters, root cause), proposals (what to change, each with exact old/new text and barrier analysis). The proposals ARE the fix specification",
    "(3) Main agent spot-check: per UCI 'Verify subagent audit results' — read at least one file reported clean, verify one proposal's old_string matches the actual file content. This step is non-negotiable. Session RTzBnBupE6 proved its value when spot-check caught S2's central claim being wrong",
    "(4) Generalization check: can this finding improve the harness structurally? If yes: identify options and their institutional provenance (search framework registry via /frameworks for source disciplines). If the finding is a point instance of a known class, apply existing harness mechanism. If it reveals a new class: proceed to parallel barrier analysis",
    "(5) Parallel barrier analysis: when multiple options exist with no clear winner, launch N parallel S2 subagents (one per option). Each uses the SAME barrier analysis framework: replay the incident timeline with the proposed fix in place, verify it would have changed the outcome, identify remaining gaps, assess implementation cost and marginal prevention value. The same framework enables apples-to-apples synthesis",
    "(6) Option synthesis and user presentation: synthesize barrier analyses. Present to user with recommendation. User selects approach or pushes for deeper investigation ('think bigger'). User is the commander — sets intent and approves direction",
    "(7) Worktree-isolated editing: delegate to S3 subagent with isolation='worktree'. S3 receives exact edit specifications from the audit proposals (step 2 output). S3 applies edits mechanically — the audit produced the fix specification, the editor applies it. Worktree isolation prevents half-applied edits from corrupting main branch",
    "(8) Independent re-audit: delegate to a FRESH S2 subagent to re-run the SAME audit that produced the original proposals. The auditor is independent from the editor — different subagent, same check. Verify: zero inconsistencies on the original finding's scope, zero intent preservation issues. The same check that found the problem verifies the fix",
    "(9) Iterate on outstanding items: if re-audit finds remaining issues, classify each. Mechanical fixes: batch into another worktree edit pass. Systemic issues: launch parallel S2 subagents with /investigate + barrier analysis per issue. Cap at 3 iterations — after 3, present current state to user with outstanding items list",
    "(10) Completion: present verified results to user. Verified means: the re-audit (step 8) produced a clean result on the original finding's scope. Any structural decisions produced by the cycle (e.g., decision #53 from this session) are presented as proposals for the brief. User approves or requests changes",
    "(11) Scope discipline: each iteration re-checks against the ORIGINAL finding, not expanded scope discovered during investigation. Scope expansion requires explicit user approval. This prevents a gitignore finding from becoming a full workspace redesign unless the user directs it (as happened in this session when user said 'think bigger')",
    "(12) The cycle is orchestration, not a skill: the main agent follows these steps using existing skills (/investigate, /delegate, /debrief for AAR format). No new skill is created. The cycle is documented in the operational learning rule and the /delegate skill's template library"
  ],
  "frameworks": [
    {
      "name": "Operational learning",
      "status": "proposed",
      "note": "The cycle IS operational learning applied in real-time — AAR schema, barrier analysis, validated proposals. Extends the plan-end debrief to any-time improvement"
    },
    {
      "name": "Mission command",
      "status": "proposed",
      "note": "Delegation duty governs every subagent launch. User as commander — sets intent, approves direction, can redirect at any step"
    },
    {
      "name": "Incident investigation",
      "status": "existing",
      "note": "Barrier analysis methodology from safety engineering applied during option evaluation (step 5) and proposal validation (step 2)"
    },
    {
      "name": "Three-layer governance",
      "status": "existing",
      "note": "The cycle produces artifacts across all three layers: rules (prevention), hooks (detection), skills/audits (audit)"
    }
  ],
  "artifacts": [
    {
      "path": ".claude/rules/operational-learning.md",
      "status": "proposed",
      "scope": "project + user-level via dotprofile",
      "intent": "Add 'Harness improvement cycle' section documenting the finding-to-verified-fix process. This is a process section in the rule, not a new artifact"
    },
    {
      "path": ".claude/skills/delegate/SKILL.md",
      "status": "proposed",
      "scope": "project skill",
      "intent": "Add delegation templates for the 3 cycle roles: S2 investigator (AAR output + barrier analysis), S3 editor (worktree isolation + exact edit specs), S2 auditor (re-run original check + independent verification)"
    },
    {
      "path": "reference/framework-operational-learning.md",
      "status": "proposed",
      "scope": "project",
      "intent": "Document the cycle as the real-time application of operational learning. Session RTzBnBupE6 as the source instance. Interaction with plan-end debrief"
    }
  ],
  "kpis": [
    {
      "name": "findingToFixTime",
      "source": "cycle completion timestamps in channel messages",
      "unit": "sessions between finding surfaced and fix verified clean",
      "target": "<= 1 (resolved in the session that surfaces the finding)"
    },
    {
      "name": "reauditFirstPassRate",
      "source": "re-audit results (step 8)",
      "unit": "percent of fix attempts passing re-audit on first iteration",
      "target": ">= 80%"
    },
    {
      "name": "cycleIterationCount",
      "source": "cycle iteration tracking",
      "unit": "iterations before clean result",
      "target": "<= 2 average"
    },
    {
      "name": "spotCheckCatchRate",
      "source": "spot-check results (step 3)",
      "unit": "percent of subagent outputs where spot-check found material errors",
      "target": "trending to 0 (subagent quality improves with better delegation)"
    },
    {
      "name": "parallelAnalysisValueRate",
      "source": "barrier analysis synthesis (step 6)",
      "unit": "percent of parallel analyses where synthesis changed the pre-analysis favorite",
      "target": ">= 30% (if lower, parallel analysis is wasteful)"
    }
  ],
  "status": "proposed",
  "related": [4, 35, 36, 44, 46, 48, 53]
}
```

---

## 3. Barrier Analysis v1

### Replaying the workspace incident with this decision in place

**Step 1**: User notices `.aitools/channel/` at repo level, questions
whether it matches intent.

With decision #54 in context, the main agent recognizes this as a
**finding** and activates the entry gate (component 1). This is NOT a
point fix — it questions the design of the workspace structure. Entry
gate classifies it as "systemic" and proceeds through the full cycle.

**Step 2**: S2 structured investigation (component 2).

S2 is delegated per delegation duty (#4) with AAR schema injection
(#44). S2 audits the channel placement against governing artifacts.
Produces AAR-format output with observations, insights, and proposals.

**Would this have been faster?** Partially. The decision provides
the template for what S2 should produce. In the actual session, the
first S2 output was a traditional report (not AAR format). Decision
#44 already addresses this — #54 reinforces it by making step 2
explicit about "AAR-format JSON."

**Step 3**: Main agent spot-checks.

In the actual session, spot-check caught S2's wrong claim about
queue-operation messages. With #54, this step is NAMED and
NON-NEGOTIABLE. An agent following the cycle cannot skip it.

**Would this have caught the same error?** Yes — the step is
identical to what happened. The value is in making it a documented
step rather than an ad-hoc UCI compliance check.

**Step 4**: Generalization check.

The main agent asks: can this finding improve the harness? In the
actual session, this happened organically when the user and agent
discussed workspace design and produced a new rule. With #54, the
agent would explicitly check the framework registry for existing
governance of workspace structure, discover there is none, and
classify this as "new class of problem."

**Would this have been faster?** Maybe slightly faster — the agent
would not have needed to discover the "generalization" step through
conversation. But the user's clarification of intent was essential
regardless — the agent couldn't have generalized without knowing
the user's workspace intent.

**Step 5**: Parallel barrier analysis.

In the actual session, the user pushed for this: "search our
framework provenance." With #54, the agent would know to search
for institutional approaches from the start rather than needing
user prompting.

**Would the user still need to push?** This is the key question.
The user pushed because the agent proposed 10 individual amendments
(an O(n) approach) rather than looking for O(1) structural fixes.
With #54, component 4 says "identify options and their institutional
provenance." But the agent might still default to the mechanical
fix unless the decision explicitly says to look for structural
approaches BEFORE mechanical ones.

**Gap identified**: Component 4 does not explicitly prioritize
structural approaches over mechanical ones. The user's "think bigger"
push would still be needed.

**Step 6**: Option synthesis.

The actual session's synthesis worked well. No gap.

**Steps 7-8**: Worktree editing and re-audit.

These worked exactly as described. The decision captures them
faithfully.

**Step 9**: Outstanding items.

In the actual session, the re-audit found 1 remaining issue (cross-
decision hook architecture). The agent launched S2 for a deeper
investigation, producing the governed-drift-decision investigation.
This matches component 9.

### Remaining issues from barrier analysis v1

1. **Component 4 does not prioritize structural over mechanical fixes.**
   The user's most critical intervention was pushing the agent from
   "do 10 amendments" to "find a structural fix." The decision should
   explicitly encode this preference, connecting to decision #35
   (structural > behavioral) and #48 (fix-right default).

2. **No explicit mention of provenance search.** The user said
   "search our framework provenance for institutional approaches."
   This is a specific technique — not just "identify options" but
   specifically "search the source disciplines of our adopted
   frameworks." Component 4 mentions "institutional provenance"
   but in passing.

3. **Missing: user can redirect at any step.** The session showed
   the user redirecting twice: "this feels inefficient" (step 4→5)
   and "think outside current capabilities" (step 5→7 with expanded
   scope). Component 6 mentions user as commander, but the right
   to redirect at ANY step is not explicit.

4. **Interaction with #53 is too shallow.** Decision #53 is the
   PRODUCT of this cycle. The decision should note that #53 validates
   the cycle's effectiveness — the cycle produced a multi-element
   prevention stack with barrier analysis, something that would not
   have emerged from a simpler fix process.

5. **The "same check verifies the fix" principle is buried.**
   This is one of the most powerful design elements — the auditor
   re-runs the EXACT same check, not a different verification. This
   should be more prominent.

---

## 4. Draft v2 — Revised Decision JSON

Changes from v1:
- Component 4 revised: explicitly prioritize structural fixes per #35/#48, make provenance search a named step
- Component 6 revised: user can redirect at any step, not just at synthesis
- Component 8 revised: emphasize "same check verifies the fix" principle more prominently
- Rationale revised: add the "structural before mechanical" lesson
- Related array: add #41 and #45 for plan-gate and brief interactions

```json
{
  "id": 54,
  "decision": "Harness improvement cycle: finding to verified fix through structured investigation, parallel barrier analysis, worktree-isolated editing, and independent re-audit — the process by which the harness improves itself",
  "rationale": "Session RTzBnBupE6 produced a 10-step workflow: user questioned `.aitools/channel/` placement → S2 investigated (spot-check caught material error) → user clarified intent → S2 audited brief (AAR-format: 14 proposals with exact edit specs) → user pushed for institutional approaches over mechanical amendments → 3 parallel S2 barrier analyses on options from framework provenance (FRAGORD/FM 101-5-2, governedBy/ISO 10007, amendment+codification/legal) → synthesis selected governedBy → S3 applied amendments in worktree → S2 re-audited (14→1, 0 intent issues) → S2 designed structural fix (decision #53). Three design principles emerged: (a) structural fixes before mechanical — the user's push from '10 amendments' to 'find the structural root cause' was the highest-value intervention, per #35 and #48; (b) same check verifies the fix — the audit that discovered the problem is re-run by an independent agent to verify the fix, not a different verification; (c) provenance-informed options — search the source disciplines of adopted frameworks (via /frameworks) for institutional approaches before inventing from scratch. The cycle produced decision #53 (5-element prevention stack with Swiss cheese analysis), validating that the structured process generates higher-quality fixes than ad-hoc investigation.",
  "context": "Session RTzBnBupE6: workspace rule superseded 5 brief decisions. User explicitly pushed for efficiency ('this feels very inefficient' about 10-amendment approach), institutional provenance ('search our framework provenance'), bigger thinking ('what about hooks? think outside current capabilities'), and accuracy ('audit our conversation to ensure you capture my intent'). Artifacts produced by the cycle: channel-placement-investigation.md, workspace-audit.json, barrier-governed-by.md, barrier-fragord.md, barrier-amendment.md, investigate-full-prevention.md, investigate-governed-drift-decision.md, workspace-reaudit.json. The cycle consumed ~4 hours but produced a multi-element prevention stack with Swiss cheese analysis that would not have emerged from a simpler process.",
  "components": [
    "(1) Entry gate: finding emerges from any source (AAR proposal, /audit, check script, user, S2, incident). Classify: point fix (typo, missing field, single-file correction) skips to step 7. Systemic finding (pattern across decisions, new class of problem, governance gap) proceeds through full cycle. The gate prevents over-engineering trivial fixes while ensuring systemic findings get thorough treatment",
    "(2) S2 structured investigation: delegate to S2 per delegation duty (#4) with AAR schema injection (#44). S2 audits finding against governing artifacts (rules, references, incidents, code). Output: AAR-format JSON — observations (facts with file citations), insights (root cause analysis), proposals (exact old/new text per proposal + barrier analysis validating each). The proposals ARE the fix specification — they must contain enough detail for a downstream editor to apply mechanically",
    "(3) Main agent spot-check: per UCI 'Verify subagent audit results' — read at least one file reported clean, verify one proposal's old_string against actual file content, check one insight's cited line numbers. Non-negotiable. Session RTzBnBupE6: spot-check caught S2's central claim being factually wrong, preventing a cascade of incorrect fixes",
    "(4) Structural-first generalization: BEFORE proposing mechanical fixes, ask: does this finding reveal a class of problem the harness does not govern? Search the framework registry (via /frameworks) for source disciplines that address this class. Search provenance of adopted frameworks for institutional approaches (e.g., ISO 10007 configuration management for drift, FM 101-5-2 for plan amendments, safety engineering for barrier analysis). Per #35: structural enforcement over behavioral expectation. Per #48: 'fix right' is the default. Only fall back to mechanical fixes when investigation confirms no structural option exists or the structural fix has disproportionate cost. The user pushed the agent from '10 amendments' to 'find the structural root cause' — this component encodes that push as the default behavior",
    "(5) Parallel barrier analysis: when multiple structural options exist with no clear winner, launch N parallel S2 subagents (one per option). Each uses the SAME barrier analysis framework: replay the incident timeline with the proposed fix in place, verify it would have changed the outcome, identify remaining gaps (Swiss cheese model), assess implementation cost and marginal value. Same framework enables apples-to-apples synthesis. Options should be sourced from institutional provenance (step 4), not invented ad-hoc",
    "(6) Option synthesis and user presentation: synthesize barrier analyses — compare catch rates, implementation costs, marginal values, failure modes. Present recommendation to user. User is the commander at EVERY step — can redirect scope ('think bigger'), reject options ('this feels inefficient'), approve direction, or request deeper investigation. The cycle does not auto-proceed past any user-facing checkpoint without approval",
    "(7) Worktree-isolated editing: delegate to S3 subagent with isolation='worktree'. S3 receives exact edit specifications from audit proposals (step 2 output). The audit produced the fix specification; the editor applies it mechanically. Worktree isolation prevents half-applied edits from corrupting main. If edit specifications are ambiguous, the editor flags them for main agent review rather than interpreting",
    "(8) Independent re-audit — same check verifies the fix: delegate to a FRESH S2 subagent (not the original auditor, not the editor) to re-run the EXACT SAME audit that produced the original proposals. Same check, different agent. Verify: zero inconsistencies on the original finding's scope, zero intent preservation issues. This principle is load-bearing — using a different verification would not catch regressions in the original finding's scope. The auditor's output is the cycle's quality gate",
    "(9) Iterate on outstanding items: if re-audit finds remaining issues, classify each. Mechanical fixes: batch into another worktree edit pass (step 7). Systemic issues: launch parallel S2 subagents with /investigate + barrier analysis per issue (steps 4-6). Cap at 3 iterations — after 3, present current state to user with outstanding items list and recommendation (fix in this session vs defer to next)",
    "(10) Completion: present verified results to user. 'Verified' means the re-audit (step 8) produced a clean result on the original finding's scope. Structural decisions produced by the cycle are presented as brief decision proposals. User approves, requests changes, or defers",
    "(11) Scope discipline: each re-audit iteration checks against the ORIGINAL finding, not expanded scope discovered during investigation. Scope expansion requires explicit user approval ('think bigger'). This prevents a gitignore finding from becoming a full workspace redesign — unless the user directs it, as happened in session RTzBnBupE6 when the user said 'what about hooks? think outside current capabilities'",
    "(12) Placement: the cycle is orchestration, not a new skill. Main agent follows these steps using existing skills (/investigate, /delegate, /debrief for AAR format). Documented in: (a) operational learning rule — as the real-time improvement process, (b) /delegate skill — as delegation templates for the 3 cycle roles (investigator, editor, auditor), (c) framework reference — as the adopted process with session RTzBnBupE6 as source instance"
  ],
  "frameworks": [
    {
      "name": "Operational learning",
      "status": "proposed",
      "note": "The cycle IS operational learning applied in real-time — AAR schema for investigation output, barrier analysis for option validation, validated proposals for harness improvement. Extends the plan-end debrief to continuous improvement"
    },
    {
      "name": "Mission command",
      "status": "proposed",
      "note": "Delegation duty (#4) governs every subagent launch. User as commander at every checkpoint. Disciplined initiative within the cycle's structure"
    },
    {
      "name": "Incident investigation",
      "status": "existing",
      "note": "Barrier analysis methodology (safety engineering: Swiss cheese, 5 Whys, timeline replay) applied during option evaluation (step 5) and proposal validation (step 2)"
    },
    {
      "name": "Three-layer governance",
      "status": "existing",
      "note": "The cycle's products span all three layers. Prevention: rules, schema fields. Detection: hooks, skill guards. Audit: check scripts, /audit extensions"
    }
  ],
  "artifacts": [
    {
      "path": ".claude/rules/operational-learning.md",
      "status": "proposed",
      "scope": "project + user-level via dotprofile",
      "intent": "Add 'Harness improvement cycle' section: the finding-to-verified-fix process, entry gate, structural-first principle, same-check-verifies-fix principle, iteration cap, scope discipline"
    },
    {
      "path": ".claude/skills/delegate/SKILL.md",
      "status": "proposed",
      "scope": "project skill",
      "intent": "Add delegation templates for 3 cycle roles: (a) S2 investigator — AAR output with exact edit specs + barrier analysis, (b) S3 editor — worktree isolation + mechanical application of edit specs, (c) S2 auditor — re-run original check independently, verify zero inconsistencies"
    },
    {
      "path": "reference/framework-operational-learning.md",
      "status": "proposed",
      "scope": "project",
      "intent": "Document the improvement cycle as real-time operational learning. Session RTzBnBupE6 as source instance. Interaction with plan-end debrief. The three design principles (structural-first, same-check-verifies, provenance-informed)"
    }
  ],
  "kpis": [
    {
      "name": "findingToFixTime",
      "source": "cycle completion timestamps in channel messages",
      "unit": "sessions between finding surfaced and fix verified clean",
      "target": "<= 1 (resolved in the session that surfaces the finding)"
    },
    {
      "name": "reauditFirstPassRate",
      "source": "re-audit results (step 8)",
      "unit": "percent of fix attempts passing re-audit on first iteration",
      "target": ">= 80%"
    },
    {
      "name": "cycleIterationCount",
      "source": "cycle iteration tracking",
      "unit": "average iterations before clean result",
      "target": "<= 2"
    },
    {
      "name": "structuralFixRate",
      "source": "cycle outcomes — structural fix vs mechanical-only",
      "unit": "percent of systemic findings that produce structural fixes",
      "target": ">= 70%"
    },
    {
      "name": "spotCheckCatchRate",
      "source": "spot-check results (step 3)",
      "unit": "percent of subagent outputs where spot-check found material errors",
      "target": "trending to 0 (measures delegation quality improvement)"
    }
  ],
  "status": "proposed",
  "related": [4, 35, 36, 41, 44, 45, 46, 48, 53]
}
```

---

## 5. Barrier Analysis v2

### Replaying the incident again with v2 in place

**Step 1 (Entry gate)**: User questions `.aitools/channel/` placement.
Agent classifies as systemic (questions workspace design, not a typo).
Proceeds through full cycle. **No issue.**

**Step 2 (S2 investigation)**: S2 delegated with AAR schema. Produces
structured output. **No issue — same as v1.**

**Step 3 (Spot-check)**: Main agent spot-checks, catches S2 error.
Now explicitly named as non-negotiable. **Improved from v1.**

**Step 4 (Structural-first generalization)**: This is the key test.
In v1, the agent would have proposed 10 amendments. In v2, component
4 EXPLICITLY says "BEFORE proposing mechanical fixes, ask: does this
finding reveal a class of problem?" and "search the framework registry
for source disciplines."

Would the agent have searched for institutional approaches without
user prompting? With v2, yes — component 4 makes this the default
behavior, not a user-prompted exception. The user's push is encoded.

**But**: the agent still needs the user to clarify workspace intent
before it can generalize. The sequence is: (a) investigate the
finding, (b) user clarifies intent (produces the workspace rule),
(c) THEN generalize. Component 4 assumes the finding is already
understood. The actual session required a user-intent-clarification
step between investigation and generalization.

**Gap identified**: The cycle assumes the finding is clear enough to
generalize from. In practice, some findings require user intent
clarification before the cycle can proceed. This is not a separate
step — it is implicit in step 6 (user as commander at every
checkpoint). But it should be noted.

**Step 5 (Parallel barrier analysis)**: The 3 parallel analyses are
launched. Each uses the same framework. Synthesis identifies governedBy
as strongest. **No issue.**

**Steps 6-10**: Match the actual session flow. **No issues.**

### Remaining issues from barrier analysis v2

1. **User intent clarification is implicit, not explicit.** The
   actual session required the user to clarify workspace design
   intent before generalization could proceed. Component 6 says
   "user as commander at every step" but does not name this specific
   pattern: "when the finding touches user intent, the cycle pauses
   for intent clarification before proceeding." This is minor — it
   is covered by the commander principle — but worth noting for
   completeness.

2. **No mention of the "push for bigger thinking" pattern.** The
   user twice redirected the agent toward more ambitious analysis.
   Component 6 covers this ("user can redirect scope"), but the
   specific pattern of "the user sees the agent settling for a
   local optimum and pushes for a global one" is a recurring
   pattern worth naming.

3. **The decision is long.** 12 components is a lot. Could any be
   merged? Components 1 and 11 (entry gate and scope discipline)
   are both about scope. Components 6 and the "user redirects"
   pattern could be one. But: each component serves a distinct
   purpose in the sequence, and merging would lose the step-by-step
   clarity that makes the cycle followable.

### Assessment: v2 is clean enough to finalize

The two remaining issues are minor:
- Issue 1 (user intent clarification) is a sub-case of "user as
  commander" — documenting it as a note is sufficient, not worth
  a new component.
- Issue 2 (push for bigger thinking) is a coaching observation, not
  a process step — it belongs in the rationale or context, not in
  components.
- Issue 3 (decision length) — 12 components is within the range of
  existing decisions (#36 has 16 components, #53 has 8). The cycle
  has genuine complexity; compressing it would lose the step-by-step
  followability.

I will add a note to the rationale about user intent clarification
and the "push for bigger thinking" pattern rather than restructuring
the components.

---

## 6. Final Decision JSON

```json
{
  "id": 54,
  "decision": "Harness improvement cycle: finding to verified fix through structured investigation, parallel barrier analysis, worktree-isolated editing, and independent re-audit — the process by which the harness improves itself",
  "rationale": "Session RTzBnBupE6 produced a 10-step workflow: user questioned `.aitools/channel/` placement → S2 investigated (spot-check caught material error) → user clarified intent → S2 audited brief (AAR-format: 14 proposals with exact edit specs) → user pushed for institutional approaches over mechanical amendments → 3 parallel S2 barrier analyses on options from framework provenance (FRAGORD/FM 101-5-2, governedBy/ISO 10007, amendment+codification/legal) → synthesis selected governedBy → S3 applied amendments in worktree → S2 re-audited (14→1, 0 intent issues) → S2 designed structural fix (decision #53). Three design principles: (a) structural fixes before mechanical — the user's push from '10 amendments' to 'find the structural root cause' was the highest-value intervention, per #35/#48; (b) same check verifies the fix — the audit that discovered the problem is re-run by an independent agent, not a different verification; (c) provenance-informed options — search source disciplines of adopted frameworks before inventing from scratch. Two session patterns worth noting: the user twice pushed the agent from local optimum to global ('this feels inefficient' → structural fix, 'think outside current capabilities' → full prevention stack with hooks and telemetry), and user intent clarification was needed before generalization could proceed. The cycle produced decision #53 (5-element prevention stack with Swiss cheese analysis), validating that the structured process generates higher-quality fixes than ad-hoc investigation.",
  "context": "Session RTzBnBupE6: workspace rule superseded 5 brief decisions. User explicitly pushed for efficiency, institutional provenance, bigger thinking, and accuracy. Artifacts produced by the cycle: channel-placement-investigation.md, workspace-audit.json, barrier-governed-by.md, barrier-fragord.md, barrier-amendment.md, investigate-full-prevention.md, investigate-governed-drift-decision.md, workspace-reaudit.json. The cycle consumed ~4 hours but produced a multi-element prevention stack with Swiss cheese analysis. User directive: 'audit our conversation to ensure you capture my intent accurately.'",
  "components": [
    "(1) Entry gate: finding emerges from any source (AAR proposal, /audit, check script, user, S2, incident). Classify: point fix (typo, missing field, single-file correction) skips to step 7. Systemic finding (pattern across decisions, new class of problem, governance gap) proceeds through full cycle. The gate prevents over-engineering trivial fixes while ensuring systemic findings get thorough treatment",
    "(2) S2 structured investigation: delegate to S2 per delegation duty (#4) with AAR schema injection (#44). S2 audits finding against governing artifacts (rules, references, incidents, code). Output: AAR-format JSON — observations (facts with file citations), insights (root cause analysis), proposals (exact old/new text per proposal + barrier analysis validating each). The proposals ARE the fix specification — detailed enough for a downstream editor to apply mechanically",
    "(3) Main agent spot-check: per UCI 'Verify subagent audit results' — read at least one file reported clean, verify one proposal's old_string against actual file content, check one insight's cited line numbers. Non-negotiable. Session RTzBnBupE6: spot-check caught S2's central claim being factually wrong, preventing a cascade of incorrect fixes",
    "(4) Structural-first generalization: BEFORE proposing mechanical fixes, ask: does this finding reveal a class of problem the harness does not govern? Search the framework registry (via /frameworks) for source disciplines that address this class. Search provenance of adopted frameworks for institutional approaches. Per #35: structural enforcement over behavioral expectation. Per #48: fix-right is the default. Only fall back to mechanical fixes when investigation confirms no structural option exists or the structural fix has disproportionate cost",
    "(5) Parallel barrier analysis: when multiple structural options exist with no clear winner, launch N parallel S2 subagents (one per option). Each uses the SAME barrier analysis framework: replay incident timeline with proposed fix, verify it would have changed the outcome, identify remaining gaps (Swiss cheese model), assess implementation cost and marginal value. Same framework enables apples-to-apples synthesis",
    "(6) Option synthesis and user presentation: synthesize barrier analyses — compare catch rates, costs, marginal values, failure modes. Present recommendation. User is commander at EVERY step — can redirect scope, reject options, approve direction, request deeper investigation, or clarify intent. When the finding touches user intent or design philosophy, the cycle pauses for intent clarification before generalization proceeds",
    "(7) Worktree-isolated editing: delegate to S3 with isolation='worktree'. S3 receives exact edit specifications from audit proposals (step 2). The audit produced the fix specification; the editor applies mechanically. Worktree isolation prevents half-applied edits from corrupting main. Ambiguous specifications flagged for main agent review rather than interpreted",
    "(8) Independent re-audit — same check verifies the fix: delegate to a FRESH S2 (not the original auditor, not the editor) to re-run the EXACT SAME audit that produced the original proposals. Same check, independent agent. Verify: zero inconsistencies on original finding's scope, zero intent preservation issues. This principle is load-bearing — a different verification would miss regressions in the original scope",
    "(9) Iterate on outstanding items: if re-audit finds remaining issues, classify. Mechanical: batch into worktree edit pass (step 7). Systemic: launch parallel S2 with /investigate + barrier analysis (steps 4-6). Cap at 3 iterations — after 3, present current state to user with outstanding items and recommendation",
    "(10) Completion: present verified results to user. 'Verified' = re-audit (step 8) produced clean result on original finding's scope. Structural decisions produced by cycle presented as brief decision proposals. User approves, modifies, or defers",
    "(11) Scope discipline: each re-audit checks against ORIGINAL finding, not expanded scope. Scope expansion requires explicit user approval. Prevents a gitignore finding from becoming a workspace redesign — unless user directs it",
    "(12) Placement: orchestration pattern, not a new skill. Main agent follows steps using existing skills (/investigate, /delegate, /debrief). Documented in: (a) operational learning rule — real-time improvement process section, (b) /delegate skill — delegation templates for 3 cycle roles (investigator, editor, auditor), (c) framework reference — adopted process with source instance"
  ],
  "frameworks": [
    {
      "name": "Operational learning",
      "status": "proposed",
      "note": "The cycle IS operational learning applied in real-time — AAR schema, barrier analysis, validated proposals. Extends plan-end debrief to continuous improvement"
    },
    {
      "name": "Mission command",
      "status": "proposed",
      "note": "Delegation duty (#4) governs every subagent launch. User as commander at every checkpoint. Disciplined initiative within cycle structure"
    },
    {
      "name": "Incident investigation",
      "status": "existing",
      "note": "Barrier analysis methodology (Swiss cheese, 5 Whys, timeline replay) applied during option evaluation (step 5) and proposal validation (step 2)"
    },
    {
      "name": "Three-layer governance",
      "status": "existing",
      "note": "Cycle products span all three layers — rules (prevention), hooks (detection), skills/audits (audit)"
    }
  ],
  "artifacts": [
    {
      "path": ".claude/rules/operational-learning.md",
      "status": "proposed",
      "scope": "project + user-level via dotprofile",
      "intent": "Add 'Harness improvement cycle' section: finding-to-verified-fix process, entry gate, structural-first principle, same-check-verifies-fix principle, iteration cap, scope discipline"
    },
    {
      "path": ".claude/skills/delegate/SKILL.md",
      "status": "proposed",
      "scope": "project skill",
      "intent": "Add delegation templates for 3 cycle roles: S2 investigator (AAR output + exact edit specs + barrier analysis), S3 editor (worktree + mechanical application), S2 auditor (re-run original check, independent verification)"
    },
    {
      "path": "reference/framework-operational-learning.md",
      "status": "proposed",
      "scope": "project",
      "intent": "Document improvement cycle as real-time operational learning. Session RTzBnBupE6 as source instance. Three design principles. Interaction with plan-end debrief"
    }
  ],
  "kpis": [
    {
      "name": "findingToFixTime",
      "source": "cycle completion timestamps in channel messages",
      "unit": "sessions between finding surfaced and fix verified clean",
      "target": "<= 1 (resolved in session that surfaces the finding)"
    },
    {
      "name": "reauditFirstPassRate",
      "source": "re-audit results (step 8)",
      "unit": "percent of fix attempts passing re-audit on first iteration",
      "target": ">= 80%"
    },
    {
      "name": "cycleIterationCount",
      "source": "cycle iteration tracking",
      "unit": "average iterations before clean result",
      "target": "<= 2"
    },
    {
      "name": "structuralFixRate",
      "source": "cycle outcomes — structural fix vs mechanical-only",
      "unit": "percent of systemic findings producing structural fixes",
      "target": ">= 70%"
    },
    {
      "name": "spotCheckCatchRate",
      "source": "spot-check results (step 3)",
      "unit": "percent of subagent outputs where spot-check found material errors",
      "target": "trending to 0 (measures delegation quality improvement)"
    }
  ],
  "status": "proposed",
  "related": [4, 35, 36, 41, 44, 45, 46, 48, 53]
}
```

---

## 7. Summary of Refinements

### v1 → v2 changes

| Area | v1 | v2 | Why |
|------|----|----|-----|
| Component 4 | "identify options and their institutional provenance" | "BEFORE proposing mechanical fixes, search source disciplines. Per #35/#48: structural first" | User's push from 10-amendments to structural fix was the highest-value intervention. v1 did not encode this as default behavior |
| Component 6 | "User selects approach" | "User is commander at EVERY step — can redirect scope, reject options, clarify intent" | User redirected twice during the session. v1 only covered the synthesis checkpoint |
| Component 8 | "re-run the SAME audit" | Added "This principle is load-bearing" emphasis and explanation | The same-check-verifies-fix principle is one of the three core design elements but was underemphasized |
| Rationale | Described the session workflow | Added three named design principles + reference to #35/#48 | v1 listed what happened; v2 extracts the principles and connects to existing decisions |
| Related array | [4, 35, 36, 44, 46, 48, 53] | Added 41 (plan-gate) and 45 (brief as governed data) | Barrier analysis revealed the cycle interacts with plan-gate (step 8 is the cycle's quality gate, plan-gate is the downstream consumer) and brief governance |

### v2 → final changes

| Area | v2 | Final | Why |
|------|----|----|-----|
| Rationale | Missing user redirect pattern | Added: "user twice pushed agent from local optimum to global" and "user intent clarification needed before generalization" | Barrier analysis v2 identified these as patterns worth naming, but not worth separate components |
| Component 6 | "user can redirect" | Added: "When the finding touches user intent or design philosophy, the cycle pauses for intent clarification" | Barrier analysis v2 found that the actual session required intent clarification before generalization. Implicit in "user as commander" but worth making explicit |
| KPIs | Included parallelAnalysisValueRate | Replaced with structuralFixRate | Barrier analysis showed that measuring whether parallel analysis changed the favorite is too narrow. The broader metric — whether systemic findings produce structural fixes — better captures the cycle's intent |

### What the decision does NOT capture (intentional omissions)

1. **The specific workspace fix**: Decision #53 captures the workspace drift prevention. This decision captures the PROCESS that produced #53.
2. **Subagent implementation details**: How to configure worktree isolation, how to inject AAR schema — these belong in the /delegate skill, not in the decision.
3. **Hook specifications**: The cycle may produce hooks as outputs, but the cycle itself is not a hook — it is an orchestration pattern.
4. **A new skill**: The user workflow description noted "not a skill." The cycle uses existing skills (/investigate, /delegate, /debrief). Creating /improve or /refine would violate flat-verb naming (#49) and create a compound operation.
