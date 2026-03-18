# Barrier Analysis: Amendment + Codification Pattern

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-16
**Subject**: Proposed amendment + codification pattern for planning brief consistency management
**Standard**: Legal/regulatory codification (US Code, EU acquis communautaire)

---

## 1. Replay: Would This Have Prevented the 3 Critical Inconsistencies?

The 3 critical inconsistencies from the workspace audit:

| ID | Inconsistency | Root Cause |
|----|---------------|------------|
| C1 | Decision #22 says entire `.aitools/channel/` is gitignored; workspace rule says `running-estimate.json` is tracked | Rule written after decision, decision never updated |
| C2 | Decision #34 says gitignore "ignores scratch/ and channel/"; workspace rule requires finer-grained model | Same temporal gap |
| C3 | Decision #50 puts running estimate in session-scoped dir (gitignored); workspace rule puts it at fixed tracked path | Incompatible architectures, later rule supersedes |

**Walking through the counterfactual sequence:**

1. The workspace rule (`.claude/rules/aitools-workspace.md`) is written, establishing the carry-forward principle and the tracked `running-estimate.json`.
2. Under the proposed pattern, the rule author would write an **amendment record**: "Decisions #22, #34, #50 are affected. Here are the specific component changes required."
3. The amendment record would then be **applied** to the brief JSON -- the 10 component-level edits from the audit proposals.
4. `/brief consolidate` would verify the brief matches.

**Verdict: NO, this would NOT have prevented the inconsistencies.**

The failure happened at step 2 -- the rule author did not produce amendments. The amendment + codification pattern assumes that the person changing the rule will also produce the amendment record. But that is exactly the same assumption the current system makes: the person changing the rule should also update the brief. The pattern adds a structured format for recording the changes, but the human/agent failure mode is identical -- they forget, or don't realize the brief is affected.

The workspace rule was written in a different session than the brief. The agent writing the rule had no obligation (or perhaps awareness) to check the brief for conflicts. Adding an "amendment record" requirement doesn't change that -- it just means they'd also forget to write the amendment record.

**Where it would have helped:** If the inconsistencies had been *detected* (by a hook, a check script, or an S2 audit) and someone needed to *fix* them, the amendment record would have provided a clean audit trail of the fix. But prevention requires detection, not documentation format.

---

## 2. Failure Modes

### 2.1 Amendment applied incorrectly

**Risk: Medium.** The 10 proposals in the audit are precise (old text, new text, barrier analysis per proposal). But the planning brief JSON has deeply nested structure -- `components` arrays inside `decisions` objects. A wrong array index or a text match that doesn't account for JSON escaping produces a silent corruption. The brief is 44k+ tokens; manual verification of each amendment is expensive.

**Institutional parallel:** The US Code codification process has a dedicated Office of the Law Revision Counsel (OLRC) that does nothing but apply amendments to the code. Even with a dedicated team, they maintain "positive law" vs "non-positive law" titles because some codifications haven't been verified. The lesson: applying amendments correctly is hard enough to require dedicated tooling and verification.

### 2.2 Consolidation script has bugs

**Risk: Medium-High.** A `/brief consolidate` mode would need to:
- Read the brief JSON (44k+ tokens, 52 decisions, nested components/artifacts/kpis)
- Read all amendment records
- Apply amendments in sequence
- Produce valid JSON that parses and passes schema validation
- Handle edge cases: amendments to deleted decisions, amendments to previously amended text, conflicting amendments

This is essentially a merge tool. The harness already has experience with merge complexity (the `deploy_managed_file` / `Deploy-ManagedFile` state machine for interactive deployment). Building another merge tool is non-trivial work with its own class of bugs.

### 2.3 Amendment records drift from actual brief state

**Risk: High.** This is the core failure mode. If someone edits the brief directly (bypassing the amendment record), the amendment trail becomes fiction. This is exactly the problem that produced the current inconsistencies -- the rule was written without updating the brief. Now we'd have rule, brief, AND amendment records that can all drift independently.

**Institutional parallel:** The EU acquis communautaire suffers from exactly this. The acquis is the consolidated body of EU law, but individual member state transpositions, ECJ rulings, and informal amendments create drift between the "consolidated" text and reality. EUR-Lex maintains a "consolidated text" service, but it carries a disclaimer: "This document is meant purely as a documentation tool and the institutions do not assume any liability for its contents."

### 2.4 Multiple amendments to same decision conflict

**Risk: Low-Medium.** If two rules are written in different sessions, both affecting decision #34, the amendment records could conflict. Sequential application (first-in-wins or last-in-wins) doesn't handle semantic conflicts where both amendments are partially correct. This maps to the legal concept of "irreconcilable amendments" -- rare but devastating when it happens.

### 2.5 The "apply amendments" step is still O(n) manual work

**Risk: Certain.** This is not a risk, it's a fact. Writing an amendment record and then applying it is strictly MORE work than just editing the brief directly. The amendment record is an additional artifact that must be created, reviewed, and maintained. The proposal trades O(n) unstructured edits for O(n) structured edits + O(1) amendment record creation. Total work increases.

The efficiency gain is supposed to come from `/brief consolidate` -- but that only helps if you need to regenerate the brief from scratch, which is not the normal workflow. The normal workflow is: rule changes, brief needs 3-10 component edits, done.

---

## 3. Three-Layer Governance Check

### Prevention

**Does this pattern prevent future inconsistencies?**

No. The pattern documents amendments after they're identified. It does not prevent the situation where a rule is written and the brief is not updated. Prevention would require:

- A hook that fires when any rule in `.claude/rules/` is written/edited, checks whether the planning brief references affected decisions, and alerts the agent to write amendments
- A pre-commit check that validates brief decisions against their governing rules
- A mandatory "affected decisions" field in the rule itself

The amendment record is a *remediation* format, not a *prevention* mechanism. It makes fixes cleaner but doesn't stop the drift from occurring.

### Detection

**Could a hook or check script verify brief matches amendments?**

Yes, but the detection is better aimed at rule-vs-brief consistency, not amendment-vs-brief consistency. Two detection strategies:

1. **Amendment completeness check**: verify all amendment records have been applied to the brief. This catches "amendment written but not applied" -- a real but minor failure mode.

2. **Rule-brief consistency check** (more valuable): for each decision in the brief that references a governing rule, verify the decision's components don't contradict the rule. This is what the S2 workspace audit did manually. Automating it would require semantic understanding (an AI-powered check, not a regex), but the structured JSON format makes it feasible.

Strategy 2 is strictly more valuable than strategy 1 because it catches the actual failure mode (drift) rather than an intermediate artifact (amendment records).

### Audit

**Does the amendment trail enable compliance verification?**

Yes -- this is where the pattern genuinely adds value. An amendment record that says "on 2026-03-16, decisions #22, #34, #50 were amended to align with `.claude/rules/aitools-workspace.md` carry-forward principle" provides:

- When the change happened
- Why (which rule triggered it)
- What changed (old text, new text)
- Who verified (the approver)

This is useful for the AAR process, for understanding how the brief evolved, and for debugging when a decision's history matters. But it's audit value (retrospective), not prevention value (prospective).

---

## 4. Efficiency Comparison

### Initial cost

| Item | Estimate |
|------|----------|
| Amendment record schema | 1-2 hours (JSON schema, fields, validation) |
| `/brief consolidate` mode | 4-8 hours (read amendments, apply to JSON, validate, handle edge cases) |
| `/brief amend` mode | 2-4 hours (create structured amendment from rule diff) |
| Check script for completeness | 2-3 hours |
| **Total** | **9-17 hours** |

### Per-change cost (when the rule changes again)

**Current approach (no amendment pattern):**
- Detect affected decisions: manual audit or S2 task (~30 min)
- Write the edits: ~5 min per component change
- Review and approve: ~10 min total
- **Total: ~1 hour for 10 amendments**

**With amendment pattern:**
- Detect affected decisions: same (~30 min)
- Write amendment record: ~15 min (structured, but more fields)
- Apply amendments: ~5 min per component change (same as current)
- Review and approve: ~15 min (amendment record + applied changes)
- **Total: ~1.5 hours for 10 amendments**

The amendment pattern is **50% more expensive per change** due to the additional amendment record artifact. The investment pays off only if:
- You need to reconstruct the brief from scratch frequently (unlikely -- the brief is a living document, not a generated artifact)
- You need audit trail for compliance purposes (valuable but not blocking)
- Multiple independent rule changes happen simultaneously (rare in practice)

### Reading cost (for agents consuming the brief)

No change. The brief JSON remains the reading artifact. Agents don't read amendment records. The consolidation is invisible to consumers.

---

## 5. Institutional Precedent

### US Code codification process

The US Code is organized by the OLRC into 54 titles. The process:

1. Congress passes a Public Law (the "amendment")
2. The OLRC classifies affected code sections
3. The OLRC edits the US Code to incorporate the changes
4. Periodically, Congress "enacts a title into positive law" -- making the consolidated code authoritative rather than the individual statutes

**Lessons that apply:**

- **Dedicated codification office**: The OLRC exists because applying amendments correctly is a full-time job. In our context, there's no dedicated codification agent. The overhead falls on whoever writes the rule.
- **Positive law vs evidence of law**: Non-positive-law titles of the US Code are "prima facie evidence of the law" but the Statutes at Large (individual public laws) remain authoritative. This maps to our situation: is the brief the source of truth, or are the rules? The workspace rule explicitly says it supersedes decisions #34. In legal terms, the rules are "positive law" and the brief is "evidence of the decisions." The amendment pattern doesn't change this hierarchy -- it just documents the updates.
- **Years of lag**: Many US Code titles have multi-year lag between statute passage and codification. The OLRC prioritizes but can't keep up. Our brief already has this lag problem -- the workspace rule was written before the brief was updated.

### EU acquis communautaire

- **Consolidation is informational only**: EUR-Lex consolidated texts carry no legal authority. The individual directives and regulations are authoritative. This is a cautionary tale -- maintaining a "consolidated" version that has no binding force creates a false sense of currency.
- **Transposition drift**: Member states transpose directives differently, creating N versions of "the same" rule. Our analog: if the brief is consumed by multiple agents in different sessions, each agent's interpretation is a "transposition."

### Key institutional lesson

**Both systems separate the amendment (what changed) from the consolidation (the reading artifact).** But both systems also demonstrate that the consolidation step is expensive, error-prone, and perpetually behind. The amendment record is useful for audit; the consolidation is useful for reading; neither prevents the underlying problem of "someone changed a rule and forgot to update the dependent artifact."

The real institutional lesson is: **the prevention mechanism in legislation is the legislative process itself** -- committee review, floor debate, conference committees all catch conflicts before a law passes. Our analog would be a review gate: before a rule can be committed, its impact on the brief must be assessed. That's a process/hook solution, not a documentation format solution.

---

## 6. Verdict

### Score: PARTIAL

The amendment + codification pattern **reduces risk but does not prevent** the class of inconsistency observed.

**What it does well:**
- Provides clean audit trail for brief evolution
- Structures the remediation workflow (when inconsistencies are found)
- Enables future "what changed and why" analysis for AARs
- The amendment record format itself (old text, new text, triggering rule, barrier analysis) is genuinely useful

**What it does not do:**
- Prevent rules from being written without updating the brief
- Detect rule-brief inconsistencies automatically
- Reduce the per-change work (it increases it by ~50%)
- Eliminate the need for manual S2 audits like the one that found these inconsistencies

**What would actually prevent the inconsistencies:**

A **rule-impact hook** that fires on Write/Edit to `.claude/rules/*.md`:
1. Reads the modified rule
2. Scans the planning brief for decisions that reference the affected domain
3. Flags potential inconsistencies to the agent
4. Logs a `TODO(amendment):` if the agent acknowledges but defers

This is a Prevention layer fix. The amendment pattern is an Audit layer fix. Per the harness design principle ("Three-layer governance: Prevention catches what Detection misses, Detection catches what Audit misses"), the prevention layer is the right investment.

### Recommendation

1. **Skip the full amendment + codification infrastructure** (schema, consolidation tool, check script). The ROI is negative for the current scale (52 decisions, ~2 rule changes per week).
2. **Adopt the amendment record format** as a lightweight convention -- when amending the brief, include the old/new text and triggering rule in the commit message or a co-located changelog. No tooling needed.
3. **Build the rule-impact detection** -- a PreToolUse hook on Write/Edit to `.claude/rules/` that checks for brief impact. This prevents the class of failure, not just documents it.
4. **The 10 amendments from the audit should be applied directly** to the brief JSON, with a commit message that serves as the amendment record. The workspace audit JSON (`workspace-audit.json`) already contains the full audit trail in its `proposals` array -- that IS the amendment record, just produced after the fact rather than at rule-writing time.
