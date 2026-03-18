# Barrier Analysis: FRAGORD Pattern for Planning Brief Maintenance

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-16
**Subject**: Proposal to use FRAGORD pattern instead of direct brief amendments
**Standard**: FM 101-5-2 (decision #27 in planning brief), three-layer governance

---

## 1. Replay: Would FRAGORD Have Prevented the 3 Critical Inconsistencies?

The 3 critical inconsistencies (from workspace-audit.json):

1. **Decision #22**: Entire `.aitools/channel/` marked gitignored, contradicting the workspace rule's tracked `running-estimate.json`
2. **Decision #34**: Same wholesale gitignore, plus gitignore spec component (5) that ignores all of `channel/`
3. **Decision #50**: Running estimate lives in session-scoped dir (gitignored), contradicting the workspace rule's fixed tracked path

### Replay of the actual failure sequence

1. Sessions `84280c8b`, `eaacf9da`, `b8a9ed4e` produced decisions #22, #34, #50 with the "everything in channel is gitignored" model
2. A later session wrote `.claude/rules/aitools-workspace.md` with the carry-forward principle: `running-estimate.json` is tracked at a fixed path
3. The workspace rule noted "Decision #34 is superseded" (line 62) but did not update the brief
4. Decisions #22, #34, #50 in the brief still describe the old architecture
5. The plan execution session (uyZ7TELqpP) implemented the old architecture from the brief, not the new one from the rule

### Replay with FRAGORD in place

1. Sessions produce decisions #22, #34, #50 as before (no change)
2. Later session writes the workspace rule AND issues FRAGORD-001-workspace.json
3. FRAGORD-001 references decisions #22, #34, #50 and states: "running-estimate.json is tracked at `.aitools/channel/running-estimate.json`; only `session-*/` is gitignored"
4. /brief skill presents decisions with FRAGORD overlay applied
5. Plan execution session reads the brief via /brief, sees the amended decisions

**Would the inconsistencies have been prevented?** Only if the executing agent read the brief through the /brief skill (which applies overlays). If the agent read the JSON directly, it would still see the old text. The FRAGORD does not change the physical content of the brief -- it layers on top. So:

- **If /brief skill is the only access path**: Yes, prevented. The agent would see amended decisions.
- **If agent reads planning-brief.json directly**: No, not prevented. The agent sees stale text.

This is the same bypass risk that governed-data-access already addresses. The brief is governed data; the /brief skill is the access layer. But the /brief skill does not exist yet (it's proposed in decision #49). The FRAGORD pattern requires the /brief skill to be effective.

**Verdict on replay: PARTIAL.** The FRAGORD would have prevented the inconsistency IF the /brief skill existed and was the sole access path. Without the skill, it is just another file that agents might not read.

---

## 2. Failure Modes

### 2a. Agent reads brief without reading FRAGORDs (bypass)

**Likelihood**: High in the near term (the /brief skill does not exist yet). Medium once the skill exists (governed-data-access rule prevents direct JSON access).

**Mitigation**: The governed-data-access rule already prohibits direct JSON access to governed files. If the brief is governed data (decision #45 says it is), agents must use the /brief skill. The skill applies FRAGORDs. But this requires:
- The /brief skill to exist (not yet built)
- The governed-data-access rule to explicitly list planning-brief.json (not yet listed)
- A detection hook (pre-commit step or PreToolUse) to catch direct reads

**Residual risk**: Before the skill is built, FRAGORDs are just files in a directory that agents may not know to look for. During this gap, the FRAGORD pattern provides zero protection.

### 2b. FRAGORD references stale decision IDs after brief refactoring

**Likelihood**: Low. The brief schema uses stable IDs (meta.readingOrder says "IDs are stable -- this reorders without renumbering"). Decision #31 was merged into #8 but ID 31 still exists as a tombstone. This stability convention means FRAGORDs referencing decision IDs survive refactoring.

**Mitigation**: The /brief skill or /audit skill validates that all FRAGORD decision references point to existing IDs. Broken references are surfaced.

**Residual risk**: If the brief were ever renumbered (unlikely given the design), all FRAGORDs would break simultaneously. But the convention explicitly prevents this.

### 2c. Multiple FRAGORDs accumulate (amendment pile-up)

**Likelihood**: Medium over time. Every time the workspace rule (or any governing rule) changes, a new FRAGORD is issued. After 5-10 rule changes, agents must apply 5-10 FRAGORDs on top of the original brief. This is the military "amendment stack" problem.

**Mitigation options**:
- **Consolidation**: Periodically merge FRAGORDs into the brief itself (a "new edition"). The military does this: FRAGORDs accumulate until a new OPORD is issued that incorporates all changes.
- **FRAGORD versioning**: Each FRAGORD supersedes the prior one for the same decision. Only the latest FRAGORD per decision applies.
- **Auto-consolidation threshold**: After N FRAGORDs (e.g., 5), the /brief skill prompts for a brief rewrite that absorbs all amendments.

**Residual risk**: Without a consolidation policy, the amendment stack grows unbounded. The military solves this with periodic OPORD rewrites. We would need the same discipline.

### 2d. FRAGORD conflicts with another FRAGORD

**Likelihood**: Low. FRAGORDs are issued sequentially (one session at a time). Conflicts would require two sessions racing to amend the same decision, which the concurrency rule already governs (check `git diff` before editing).

**Mitigation**: The /brief skill detects conflicting FRAGORDs (two FRAGORDs amending the same component of the same decision) and surfaces the conflict.

**Residual risk**: Minimal. Sequential issuance makes this unlikely.

---

## 3. Three-Layer Governance Check

### Prevention

**Current state**: No rule or directive prevents bypass. The FRAGORD files would be inert data that agents might not know about.

**Required**: The governing rule for the brief (either a new `.claude/rules/planning-brief.md` or an addition to an existing rule) must state: "When reading the planning brief, also read all FRAGORD files in the same directory. The /brief skill applies FRAGORDs automatically."

**Assessment**: Prevention layer is NOT in place. It would need to be built.

### Detection

**Possible hook**: A PreToolUse hook on Read that detects when `planning-brief.json` is being read could inject a reminder: "FRAGORDs exist in this directory. Read them or use /brief." This is similar to the existing cross-reference reminder hook pattern (`.claude/rules/incident-governance.md` hook specifications).

**Assessment**: Detection layer is feasible but NOT in place. It would need to be built.

### Audit

**Possible audit**: The /audit skill could verify FRAGORD consistency:
- All FRAGORD decision references point to existing decisions
- No decision has conflicting FRAGORDs
- FRAGORDs align with the governing rule they reference
- No stale FRAGORDs (the rule has been updated but the FRAGORD was not reissued)

**Assessment**: Audit layer is feasible and straightforward. It could be added to /audit's existing consistency checks.

### Overall governance assessment

The FRAGORD pattern would need all three layers to be effective. Currently zero layers exist. The pattern is not self-enforcing -- it requires infrastructure (skill + hook + audit check) that must be built alongside the FRAGORD mechanism itself.

---

## 4. Efficiency Comparison

### Current approach: 10 individual amendments across 5 decisions

| Cost type | Current approach | FRAGORD approach |
|-----------|-----------------|------------------|
| **Initial cost** | Zero mechanism cost. Just edit the JSON. | Build: FRAGORD schema, /brief skill overlay logic, governance rule, detection hook, audit check. Estimated: 5-8 files, 2-3 sessions of work. |
| **Per-change cost** (when workspace rule changes again) | O(n) -- re-audit affected decisions, amend each component. The audit already identified 10 components across 5 decisions. Each change to the workspace rule requires re-running this audit. | O(1) -- issue one FRAGORD that references the affected decisions and states the changes. One file, one session. |
| **Reading cost** (for agents consuming the brief) | Zero overhead. Agent reads the brief, gets the current state. | Extra step: agent must read the brief + all FRAGORDs, or use /brief skill which applies overlays. The /brief skill absorbs this cost, but adds latency (read N+1 files instead of 1). |
| **Correctness cost** | High risk of partial updates. The workspace-audit.json found 3 critical + 2 ambiguous + numerous consistent observations. Manual amendment of 10 components across 5 decisions is error-prone. | Lower risk for omission (one FRAGORD covers all), but higher risk of bypass (agent skips FRAGORD). |
| **Maintenance cost over time** | Each amendment is permanent -- the brief stays self-consistent. No ongoing maintenance. | FRAGORDs accumulate. Need periodic consolidation. Ongoing maintenance cost. |

### Efficiency verdict

The FRAGORD approach has **better per-change cost** (O(1) vs O(n)) but **much higher initial cost** and **ongoing maintenance cost**. For a brief with 52 decisions that will be executed once to produce a plan, the break-even point is approximately 3 rule changes. If the workspace rule changes once more after the initial amendments, the current approach wins on total cost. If it changes 3+ more times before the plan is executed, FRAGORD wins.

Given that the brief is a planning artifact (consumed during plan writing, then historical), not a living operational document, the number of future rule changes is likely low. The brief will be consumed, the plan written, and the brief becomes archival.

---

## 5. Institutional Precedent

### How FRAGORD works in the military

The Fragmentary Order (FRAGORD) is defined in FM 101-5-2 (US Army) as an abbreviated form of an operation order (OPORD) issued after the OPORD to change or modify that order. Key characteristics:

1. **Same format as OPORD** but only includes changed paragraphs/sections
2. **References the parent OPORD** by number and DTG (date-time group)
3. **Sequential numbering** -- FRAGORD 001, 002, etc.
4. **Cumulative** -- each FRAGORD is applied on top of the OPORD + all prior FRAGORDs
5. **Recipients must have the parent OPORD** -- a FRAGORD without context is useless
6. **Issuing authority** -- the same HQ that issued the OPORD
7. **Triggers new OPORD** when amendments become too numerous to track

### What maps well to our context

- **Reference by ID**: Our decisions have stable IDs, like OPORD paragraph numbers. A FRAGORD can reference "Decision #22, component (1)" precisely.
- **Cumulative application**: /brief skill applies FRAGORDs in sequence, same as a military staff officer reads FRAGORDs in order.
- **Consolidation trigger**: The military issues a new OPORD when FRAGORDs accumulate. We could consolidate FRAGORDs into a brief rewrite.
- **Same authority**: The user (Commander) approves both the brief and FRAGORDs.

### What gets lost in adaptation

- **Distribution mechanism**: Military FRAGORDs are actively pushed to recipients via communication channels. Our FRAGORDs are passive files that agents must know to read. The military never has the "bypass" problem because FRAGORDs are delivered, not discovered.
- **Operational tempo**: Military FRAGORDs are issued during ongoing operations when conditions change faster than a new OPORD can be written. Our brief is not under operational pressure -- we can afford to amend it directly.
- **Training**: Every military staff officer is trained to check for FRAGORDs. Our agents have no such training unless we build it into rules and hooks.
- **Time-sensitivity**: Military FRAGORDs address urgent battlefield changes. Our inconsistencies are not time-sensitive -- they are design drift that can be fixed at leisure.

### Adaptation assessment

The FRAGORD pattern is designed for a scenario we do not have: time-pressure updates to a living operational plan during execution. Our planning brief is a pre-execution artifact being refined before plan writing begins. The military equivalent would be amending the OPORD between staff planning sessions -- which is done by issuing a new edition, not a FRAGORD.

Decision #27 in the brief already adapts FRAGORD correctly for our context: "FRAGORD is kill-and-replace -- terminate stale delegation and reissue." That adaptation is about mid-execution delegation changes, not about pre-execution planning brief maintenance. Applying FRAGORD to brief maintenance is a second-order adaptation that stretches the concept beyond its natural fit.

---

## 6. Verdict

**Score: PARTIAL** -- reduces risk but does not prevent, and introduces new risks.

### Why not PASS

1. **The FRAGORD would not have prevented the inconsistencies without the /brief skill**, which does not exist. The inconsistencies arose because the workspace rule superseded decisions without back-patching them. A FRAGORD file sitting next to the brief is equally ignorable as the workspace rule's "Decision #34 is superseded" note.

2. **The pattern solves a problem we do not have.** The brief is not a living operational document under time pressure. It is a pre-execution planning artifact being refined. Direct amendment (the 10-component approach) produces a self-consistent brief that any agent can read without special tooling.

3. **The initial infrastructure cost is disproportionate** for a planning brief that will be consumed once. Building the FRAGORD mechanism (schema, skill overlay logic, governance rule, detection hook, audit check) is 5-8 files of work to avoid editing 10 JSON components.

4. **The amendment pile-up failure mode introduces ongoing maintenance** that direct amendment does not have.

### Why not FAIL

1. **The per-change cost advantage is real.** If the workspace rule (or other governing rules) continue to evolve before the plan is executed, the FRAGORD pattern saves audit and amendment work.

2. **The pattern preserves decision provenance.** Direct amendment overwrites the original decision text. A FRAGORD preserves what was originally decided and what changed -- useful for the AAR and future learning.

3. **The pattern is institutionally sound.** It maps well to FM 101-5-2 and our existing decision #27 FRAGORD adaptation. The concept is coherent even if the application context is a stretch.

### Recommendation

**Do the 10 amendments now. Consider the FRAGORD pattern for the plan itself (not the brief).**

The planning brief is a pre-execution artifact. Amend it directly so it is self-consistent before plan writing begins. This is the military equivalent of issuing a corrected OPORD before the operation, not issuing FRAGORDs during it.

The FRAGORD pattern has genuine value for the **plan** once execution begins -- when conditions change during multi-batch execution and the plan needs mid-execution updates. That is the scenario decision #27 already describes, and it is the scenario the military designed FRAGORDs for.

If the brief becomes a reusable, long-lived artifact (used across multiple plans, not just one), revisit. At that point the per-change cost advantage and provenance preservation would justify the infrastructure investment.
