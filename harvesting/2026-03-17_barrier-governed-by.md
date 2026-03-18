# Barrier Analysis: `governedBy` Schema Field

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-16
**Proposal**: Add optional `governedBy` field to planning brief decision schema,
enabling decisions to reference a governing rule instead of duplicating design details
in components.
**Framework**: Configuration Management / Deming PDCA (single source of truth)

---

## 1. Replay: Would This Have Prevented the 3 Critical Inconsistencies?

The three critical inconsistencies (from workspace-audit.json) are:

| # | Decision | Inconsistency |
|---|----------|--------------|
| C1 | #22 | Entire `.aitools/channel/` marked gitignored. Workspace rule says `running-estimate.json` is TRACKED. |
| C2 | #34 | Components (3) and (5) gitignore all of `channel/`. Workspace rule carves out `running-estimate.json`. |
| C3 | #50 | Running estimate lives in session-scoped dir (gitignored), archived at SessionEnd. Workspace rule puts it at fixed tracked path. |

### Exact sequence with `governedBy` in place

**Step 1**: Decisions #3, #22, #26, #34, #50 are written during session b8a9ed4e
with detailed components describing workspace paths, gitignore rules, and running
estimate placement.

**Step 2**: The workspace rule (`.claude/rules/aitools-workspace.md`) is written
later in the same session. It supersedes #34 and refines the channel gitignore model
(session dirs ignored, running-estimate tracked).

**Step 3 (without `governedBy`)**: The 5 decisions retain their original component
text. The rule says it supersedes #34. An agent reading the brief gets stale
workspace design. Three critical inconsistencies exist.

**Step 3 (with `governedBy`)**: When the workspace rule is written, the author
adds `"governedBy": ".claude/rules/aitools-workspace.md"` to decisions #3, #22,
#26, #34, #50 and simplifies their workspace-path components to reference the rule.

**But here is the problem**: The `governedBy` field does not prevent the
inconsistencies at the time the decisions are written. It prevents them only if
**someone remembers to add the field and simplify the components when the rule is
written**. The inconsistencies arose because the rule was written without
back-patching the decisions. `governedBy` is a mechanism for back-patching. It
makes back-patching cheaper (one field + one line per decision vs 10 component
amendments) but it does not make back-patching automatic.

**Specific replay**:

- **C1 (#22)**: `governedBy` would have replaced components (1) and (6) with
  "Per `.claude/rules/aitools-workspace.md`". The `/brief` skill would read the
  rule and present the current gitignore model. **Would have prevented** -- IF
  the field was added when the rule was written.

- **C2 (#34)**: Same. Components (3) and (5) simplified. The workspace rule line
  62 already says "decision #34 is superseded" -- `governedBy` formalizes that
  into a machine-readable field. **Would have prevented** -- IF added.

- **C3 (#50)**: Components (3), (6), (7), (8) describe the archive-at-SessionEnd
  model. The workspace rule's tracked-at-fixed-path model is fundamentally
  different. `governedBy` would have replaced these with a reference. **Would have
  prevented** -- IF added.

**Verdict on replay**: `governedBy` converts a 10-amendment task into a
5-decision-field + 5-component-simplification task. It changes the per-change cost
from O(n components) to O(1 per decision). But it does not prevent the forgetting
-- it requires the same discipline (back-patch when rule changes) with lower cost
per action.

---

## 2. Failure Modes

### 2a. Governed data bypass (agent reads JSON directly)

**Risk**: MEDIUM. An agent reads `planning-brief.json` directly, sees `governedBy`
field, and either ignores it (reads the simplified component text literally) or
doesn't know how to resolve it (has no access to the /brief skill).

**Existing mitigation**: The governed data access rule
(`.claude/rules/governed-data-access.md`) already mandates skill-gated access.
The brief should be read via the /brief skill (decision #45). The /brief skill
would resolve `governedBy` references.

**Residual risk**: Subagents and agents without rules loaded. They read the JSON
raw. But this is the EXISTING bypass vector for all governed data -- `governedBy`
does not make it worse. The simplified component text ("Workspace structure per
.claude/rules/aitools-workspace.md") is self-documenting enough that even a raw
reader would know to check the rule.

**Assessment**: Acceptable. No worse than status quo. The simplified text is
actually better for raw readers than the current stale detailed text.

### 2b. Dangling reference (rule deleted/renamed)

**Risk**: LOW. Rules in `.claude/rules/` are protected files (sources-of-truth.md).
Deletion or rename requires user review. A renamed rule that breaks `governedBy`
references would be caught by:

- **/brief skill**: Attempts to read the rule, fails, reports the broken reference.
- **/audit skill**: Cross-reference check finds dangling `governedBy` path.
- **Check scripts**: Could add a step validating `governedBy` paths exist.

**Standard mitigation from CM**: Foreign key validation. The /brief skill validates
`governedBy` paths on read. The /audit skill validates them periodically.

**Assessment**: Low risk, standard mitigation available.

### 2c. Circular governance (rule references brief, brief references rule)

**Risk**: NEGLIGIBLE. The workspace rule already references decision #34 ("Planning
brief decision #34 is superseded by this rule"). `governedBy` goes the other
direction (decision #34 references the rule). This is not circular -- it's
bidirectional acknowledgment. The rule is authoritative; the decision defers.
Circular would be if the rule's content depended on the decision's content for
its own definition, which it does not.

**Assessment**: Not a real risk. The dependency is unidirectional: rule defines,
decision defers.

### 2d. Over-simplification (agent loses implementation detail)

**Risk**: MEDIUM-HIGH. This is the most serious failure mode. The current 10
component amendments in the proposals section of workspace-audit.json contain
specific implementation guidance:

- Decision #50 component (3): "If .aitools/channel/running-estimate.json does not
  exist, seeds a stub. If it exists, reads and continues."
- Decision #50 component (6): "Lives at .aitools/channel/running-estimate.json
  (tracked in git, fixed path). Updated in place."
- Decision #22 component (6): ".aitools/.gitignore: ignore channel/session-*/,
  track channel/running-estimate.json"

If these are all collapsed to "Workspace structure per workspace rule," the
executing agent must derive the implementation from the rule. The rule
(aitools-workspace.md) is 66 lines. It contains the structure table but NOT
the implementation specifics (how the hook should handle existing vs new
estimates, how gitignore entries should be written, the read path for S2
intelligence prep).

**The rule governs structure. The decision governs implementation.**

Collapsing implementation into "see the rule" means the executing agent must
infer implementation from structure. This is a loss of information density in
the brief -- the brief exists precisely to give agents all resolved decisions
without re-derivation.

**Mitigation**: Partial `governedBy`. Only components that duplicate the rule's
**structural** facts (directory layout, gitignore classification) get simplified.
Components that describe **implementation** (hook behavior, read paths, seeding
logic) remain detailed. The `governedBy` field signals "this decision's structural
assertions defer to the rule" not "this decision is empty, read the rule."

**Assessment**: Serious if applied wholesale. Manageable if applied selectively
to structural components only. Requires clear guidance on what gets simplified
and what stays.

---

## 3. Three-Layer Governance Check

### Prevention

**Yes, this leverages existing governed data access rules.** The planning brief
is governed data (decision #45). The /brief skill is the access layer. Adding
`governedBy` to the schema is extending the skill's resolution logic. The rule
(`.claude/rules/governed-data-access.md`) already mandates skill-gated access.
`governedBy` adds a new resolution step within the skill, not a new governance
layer.

The `governedBy` field itself is a prevention mechanism: it prevents duplication
by design. A decision with `governedBy` cannot drift from the rule because it
does not contain the driftable text.

### Detection

**Yes, the brief-read-guard hook (decision #45) can enforce /brief skill usage.**
Decision #45 establishes that the planning brief is governed data. A PreToolUse
hook on Read operations targeting `planning-brief.json` could inject a reminder
to use /brief. The /brief skill would resolve `governedBy` fields automatically.

Additionally, a detection hook could fire when `planning-brief.json` is modified:
validate that any decision with `governedBy` does not contain components that
duplicate the governing rule's structural assertions. This is more sophisticated
than current detection but feasible.

### Audit

**Yes, /audit can validate `governedBy` fields.** Three checks:

1. **Reference validity**: Every `governedBy` path exists as a file.
2. **Consistency**: Components in decisions with `governedBy` do not contradict
   the governing rule's structural assertions.
3. **Coverage**: Decisions that reference workspace paths but lack `governedBy`
   are flagged as potential candidates.

Check 3 is the proactive version -- it finds decisions that SHOULD have
`governedBy` but don't. This addresses the "forgetting to add the field" problem
from the replay analysis.

---

## 4. Efficiency Comparison

### Initial cost

| Approach | Work items | Complexity |
|----------|-----------|------------|
| **10 amendments** | 10 component edits across 5 decisions | Copy-paste from proposals. Mechanical. ~15 min. |
| **`governedBy` field** | Schema change + /brief skill update + 5 decisions get field + 5-10 component simplifications | Schema design, skill logic, selective simplification. ~45 min. |

`governedBy` costs ~3x more upfront.

### Per-change cost (when the workspace rule changes again)

| Approach | Work items |
|----------|-----------|
| **10 amendments** | Re-audit all 5 decisions, identify which components drift, amend each. O(n) where n = affected components. |
| **`governedBy` field** | Zero brief amendments. The /brief skill reads the updated rule. O(0). |

This is where `governedBy` pays off. The workspace rule will change -- it's a
new rule governing an evolving namespace. Every change currently requires
re-auditing and amending the brief. With `governedBy`, the brief stays current
automatically for structural assertions.

### Reading cost (for agents consuming the brief)

| Approach | Agent experience |
|----------|-----------------|
| **10 amendments** | Agent reads self-contained decisions. All info inline. No additional file reads. |
| **`governedBy` field** | Agent (via /brief skill) reads decision, follows `governedBy` to read the rule, merges structural info from rule with implementation info from decision. One extra file read per governed decision. |

The reading cost is higher with `governedBy` -- one additional file read per
governed decision. For 5 decisions with the same governing rule, the /brief skill
can cache: read the rule once, apply to all 5. Net cost: 1 extra file read
total. Negligible.

### Break-even

`governedBy` breaks even after the workspace rule changes once without needing
brief amendments. Given that the rule was written this session and will certainly
evolve during implementation, break-even is expected within 1-2 sessions.

---

## 5. Institutional Precedent

### Configuration management (single source of truth)

`governedBy` is a direct implementation of the DRY (Don't Repeat Yourself)
principle applied to governed documents. In configuration management:

- **Deming PDCA**: The rule is the "Plan" artifact. Decisions that duplicate
  plan content create maintenance burden in "Check" (audit) and "Act" (correct).
  `governedBy` eliminates the duplication at source.

- **ISO 10007 (Configuration Management)**: Configuration items should have a
  single authoritative source. When multiple documents reference the same design
  decision, a master-subordinate relationship prevents drift. `governedBy` is
  the subordinate marker.

- **Database normalization (3NF)**: A fact should be stored in one place. The
  workspace structure is a fact. It should be defined in the rule and referenced
  (not duplicated) in the brief. `governedBy` is the foreign key.

### Standard failure modes from industry

1. **Stale references**: The governing document changes but the reference
   relationship breaks (renamed, deleted, restructured). Mitigated by reference
   validation in /brief and /audit.

2. **Abstraction leak**: The simplified component loses context that was
   important. An engineer reads "per design spec" and misses a constraint that
   was inline before. Mitigated by selective simplification (implementation
   detail stays, structural duplication goes).

3. **Resolution complexity**: "Follow the reference chain" becomes multi-hop
   when governing documents reference other governing documents. Not a risk here
   -- `governedBy` is one level deep (decision -> rule). No transitive governance.

4. **Adoption resistance**: Teams resist indirection because inline text is
   easier to read. The brief is consumed by AI agents via the /brief skill, not
   by humans scanning JSON. The skill resolves the indirection transparently.
   This failure mode does not apply.

5. **Partial adoption**: Some decisions get `governedBy`, others with the same
   governing relationship don't. Creates inconsistency about which decisions are
   authoritative. Mitigated by audit check #3 (coverage: flag decisions that
   reference workspace paths without `governedBy`).

---

## 6. Verdict

**PARTIAL** -- reduces risk significantly but does not fully prevent.

### What it prevents

- **Future drift**: Once `governedBy` is in place, the workspace rule can change
  without brief amendments. The 3 critical inconsistencies would not recur for
  the same class of change (structural workspace modifications). This is genuine
  prevention for future changes.

### What it does not prevent

- **The original incident**: The 3 inconsistencies arose because the rule was
  written without back-patching the decisions. `governedBy` still requires
  someone to add the field when writing the rule. It reduces the cost of
  back-patching (from 10 amendments to 5 field additions) but does not
  eliminate the need for the back-patching action.

- **Forgetting to add `governedBy`**: If a new rule supersedes new decisions
  and nobody adds the field, the same class of inconsistency recurs. The audit
  check (flag decisions referencing workspace paths without `governedBy`) is the
  detection layer for this, but detection is reactive, not preventive.

### What would achieve full prevention

The complete barrier requires three elements:

1. **`governedBy` field** (this proposal) -- eliminates duplication, makes
   back-patching cheap. Structural prevention for future drift.

2. **Rule-writing checklist item** -- when writing a rule that supersedes
   brief decisions, add `governedBy` to affected decisions as part of the rule
   creation process. Process prevention for the forgetting failure mode. Could
   be enforced by a hook on writes to `.claude/rules/`: "Does this rule
   supersede any brief decisions? If so, update `governedBy`."

3. **Audit coverage check** -- /audit flags decisions with workspace paths but
   no `governedBy`. Detection layer for when (1) and (2) are both missed.

### Recommendation

**Proceed with `governedBy`, but scope it correctly:**

- Apply to structural assertions only (directory layout, gitignore classification,
  scope boundaries). These are the facts the workspace rule defines.
- Keep implementation details in decision components (hook behavior, seeding
  logic, read paths, archive procedures). These are the HOW that the brief
  exists to provide.
- Add audit check for coverage (decisions with workspace paths lacking `governedBy`).
- Consider the rule-writing checklist item as a follow-on.

The 10 current amendments are still needed as the initial alignment action --
`governedBy` prevents the class of problem going forward but does not retroactively
fix the 3 critical inconsistencies in the existing text. However, the amendments
can be simpler: instead of 10 detailed rewrites, the affected structural components
become one-line references, and only the implementation components get detailed
amendments.

### Score justification

PARTIAL because:
- Would NOT have prevented the original incident (requires the same "remember to
  back-patch" discipline, just at lower cost)
- WOULD prevent recurrence of the same class (once in place, structural drift is
  impossible for governed decisions)
- Addresses the right class of problem (duplication as the root cause of drift)
- Has manageable failure modes (all covered by existing governance layers)
- Standard CM pattern with well-understood industry failure modes
