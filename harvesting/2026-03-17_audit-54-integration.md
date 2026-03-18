# Audit: Decision #54 Integration

## 1. Reciprocal Link Fixes

Decision #54 declares `related: [4, 35, 36, 41, 44, 45, 46, 48, 53]`.

**All 9 are missing the reciprocal link back to 54:**

| Decision | Current `related` | Action |
|----------|------------------|--------|
| #4 | [3, 5, 6, 7, 19, 21, 23, 25, 26, 27, 28, 44, 46, 48] | Add 54 |
| #35 | [24, 30, 36, 41, 42, 48] | Add 54 |
| #36 | [1, 2, 10, 11, 14, 18, 24, 26, 30, 34, 35, 37, 40, 43, 44, 48] | Add 54 |
| #41 | [20, 29, 35, 39, 40, 45, 48] | Add 54 |
| #44 | [4, 25, 26, 36, 38, 46, 48] | Add 54 |
| #45 | [13, 29, 41, 43] | Add 54 |
| #46 | [4, 22, 34, 44, 47, 48] | Add 54 |
| #48 | [4, 24, 35, 36, 41, 44, 46] | Add 54 |
| #53 | [3, 20, 22, 26, 29, 34, 35, 41, 45, 50] | Add 54 |

**Additional decisions that SHOULD reference #54:**

| Decision | Rationale | Action |
|----------|-----------|--------|
| #50 (running estimate) | The improvement cycle (steps 2, 8) produces findings and verified fixes that update the running estimate. The estimate's `situation.deviations` and `findings` sections are populated by cycle outputs. Bidirectional: #54 should also add #50. | Add 54 to #50; add 50 to #54 |
| #51 (plan-writing protocol) | The write-review loop IS a simplified improvement cycle. When Plan Writer review reveals a systemic finding (not just a section rewrite), the cycle governs the response. The escalation path from #51 to #54 needs to be explicit. | Add 54 to #51; add 51 to #54 |
| #52 (Plan Writer role) | The Plan Writer may surface systemic findings during review that should escalate to the improvement cycle rather than being resolved ad-hoc in the review loop. The role definition should reference #54 as the escalation target. | Add 54 to #52; add 52 to #54 |

**Summary**: 12 decisions need 54 added to their `related` arrays. Decision #54 itself needs 50, 51, 52 added to its `related` array (becoming [4, 35, 36, 41, 44, 45, 46, 48, 50, 51, 52, 53]).

---

## 2. Handoff Prompt Exact Text Additions

### 2a. Section E (Plan-Writing Protocol) — after step 5 in the write-review loop (line 140)

Insert after line 140 (`5. Plan Writer approves or pushes back again`), before line 141 (`6. S3 moves to the next section`):

```
   5a. If Plan Writer review reveals a SYSTEMIC finding (governance gap, cross-cutting pattern, missing structural enforcement — not just "rewrite this paragraph"), escalate to the harness improvement cycle (decision #54) rather than ad-hoc revision. The cycle governs: investigate, structural-first generalization, barrier analysis, worktree-isolated fix, independent re-audit. S3 decides whether to run the cycle inline or defer to a later batch.
```

### 2b. Section F (Plan Writer Delegation Template) — new subsection after "Quality checklist for review" (after line 267)

Insert after line 267 (closing of quality checklist code block), before line 269 (`### Deduplication rule`):

```
### Escalation to improvement cycle

```
When your review reveals a finding that is SYSTEMIC — it affects multiple
sections, reveals a governance gap, or indicates a class of problem the
harness does not govern — do not attempt to fix it within the review loop.
Flag it explicitly:

  SYSTEMIC FINDING: [description]. This is not a section rewrite — it
  requires the harness improvement cycle (decision #54): investigation,
  structural-first generalization, barrier analysis, verified fix.

S3 decides the response: run the cycle inline, defer to a later batch,
or file an incident for future resolution. Your job is to DETECT and FLAG,
not to resolve systemic findings.
```
```

### 2c. Section H (What to Do) — amend step 4 (line 359)

Replace lines 359-363:

```
4. **Write the plan section by section** per the protocol in section E. For each section:
   - Write it
   - Launch the Plan Writer subagent using the template in section F
   - Revise based on Plan Writer review
   - Get Plan Writer approval
   - Move to next section
```

With:

```
4. **Write the plan section by section** per the protocol in section E. For each section:
   - Write it
   - Launch the Plan Writer subagent using the template in section F
   - Revise based on Plan Writer review
   - If Plan Writer flags a systemic finding, apply the harness improvement cycle (decision #54) — investigate, structural-first, barrier analysis, verified fix — or defer to a later batch
   - Get Plan Writer approval
   - Move to next section
```

### 2d. Section G (Critical Context) — amend decision #54 description in cross-cutting table (line 307)

Replace line 307:

```
| **#54** | **Process: harness improvement cycle (finding to verified fix)** |
```

With:

```
| **#54** | **Process: harness improvement cycle (finding to verified fix). Escalation target from Plan Writer review (section F) when systemic findings surface during plan writing** |
```

### 2e. Section G — amend last bullet in "Key sequencing" (after line 347)

Add new bullet after line 348:

```
5. **Throughout**: Decision #54 (improvement cycle) is a process pattern, not infrastructure — it governs how findings surfaced during plan execution become verified fixes. Plan Writer and S3 both reference it as the escalation path for systemic findings
```

---

## 3. Decision #51 Component Addition

**Yes, warranted.** The plan-writing protocol's write-review loop currently treats all Plan Writer feedback as section-level revision. It has no escalation path for systemic findings. Decision #54 provides exactly that path.

### Proposed component (15) for decision #51:

```json
"(15) Systemic finding escalation: when Plan Writer review reveals a finding that crosses section boundaries, reveals a governance gap, or indicates a class of problem the harness does not govern, the write-review loop pauses. S3 classifies: point fix (revise the section) or systemic (invoke the harness improvement cycle per decision #54 — investigate, structural-first generalization, barrier analysis, worktree-isolated fix, independent re-audit). The cycle is the escalation path from plan-writing to harness improvement. S3 decides whether to run inline or defer to a batch. This prevents the Plan Writer loop from becoming an ad-hoc rewrite engine for structural problems"
```

This component connects #51 to #54 by:
- Defining when to escalate (systemic vs point fix — mirrors #54's entry gate)
- Naming the process (#54's improvement cycle)
- Preserving S3's authority (S3 decides inline vs deferred)
- Preventing the anti-pattern (ad-hoc structural changes in review loop)
