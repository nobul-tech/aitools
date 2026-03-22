# Q4 + Q10 Ambiguity and Consistency Audit

**Auditor**: S2 (Intelligence)
**Date**: 2026-03-18
**Scope**: Q4 (artifact lifecycle) and Q10 (artifact roles and enforcement) investigated against the planning brief, workspace rule, harness definition, glossary, and governing rules.

---

## Pass 1: Undefined or Ambiguous Terms

### 1.1 Terms used in Q4 not in governed vocabulary

| Term | Used in | Status | Severity | Recommendation |
|------|---------|--------|----------|---------------|
| briefing | Q4 throughout, proposed directory name | NOT governed | Should-resolve | "briefing" appears 47+ times in Q4 as a first-class concept but is absent from glossary.md. A fresh agent would not know whether "briefing" means the JSON planning brief, a delegation handoff prompt, or the act of briefing someone. Must be added via /glossary before implementation. |
| AAR | Q4 section 2.2, lifecycle table | NOT governed | Should-resolve | "AAR" (After Action Review) is used as a known concept throughout Q4 and the planning brief (decision #36) but is not in the governed vocabulary. The brief defines it in decision #36 but a fresh agent hitting Q4 alone would need to infer meaning. |
| operational artifact | Q4 title, section 1 | NOT governed | Informational | Q4's title is "Lifecycle of Operational Artifacts" but "operational artifact" is not a governed term. The glossary has "artifact" but not "operational artifact." Q4 itself defines 5 specific types (briefings, AARs, plans, investigation reports, running estimates), making "operational artifact" a category label rather than a term that needs governing. Recommend: use "operational artifact" informally (it is self-evident from context) but do not govern it. |
| intelligence product | Q4 section 1 ("Three categories"), section 2.4 | NOT governed | Should-resolve | Q4 calls investigation reports "intelligence products" and says they are "S2 outputs." This term is not governed and introduces military jargon without an entry in the glossary. A fresh agent could confuse "intelligence product" with the broader concept of S2 analysis. |
| promotion / promoted | Q4 sections 2.1-2.4, section 5 ("promotion gate") | NOT governed | Blocker | "Promotion" is used 14+ times in Q4 as the mechanism by which artifacts move between lifecycle stages. The glossary has no entry. The harvesting rule uses "Promotion criteria" (line 31) but does not define the term. This is the core concept of Q4 — the lifecycle IS a series of promotions. Without a governed definition, "promote" could mean: move to a new directory, change status in the manifest, upgrade to a higher governance tier, or simply "make permanent." All four interpretations appear in different Q4 paragraphs. |
| content placement standard | Q10 section 3 (Options B, C), section 4 | NOT governed | Informational | Q10 references the "Content placement standard" as an existing section in the /governed-data skill. Confirmed: it exists at SKILL.md line 82. This is a skill-internal concept, not a governed term. Acceptable as-is since Q10 correctly identifies it as living in the skill. |
| artifact role | Q10 throughout | NOT governed | Should-resolve | Q10's entire thesis is that each artifact type has a "role." This term is not governed. The harness.md already references a future `/artifact-roles` skill (line 11, 71). Without a governed definition, "role" could mean: purpose, constraints, content type, or governance level. Q10 defines it operationally (MUST contain / MUST NOT contain) but the term itself needs governing. |
| role violation | Q10 section 2 | NOT governed | Informational | Used 4 times in Q10. Self-evident from context (content in a file that violates the file's artifact role). Does not need governing — it is a diagnostic term, not an operational one. |
| framework artifact | Q10 section 4, decision #42 | NOT governed | Should-resolve | Decision #42 uses "framework artifact" to mean files matching specific path patterns (.claude/rules/*.md, .claude/skills/*/SKILL.md, etc.). Q10 uses the same term. The glossary does not define it. A fresh agent would not know whether a hook is a "framework artifact" (Q10 says yes in section 1; decision #42's path patterns say no). |
| delegation context | Q4 section 3 "What lives in briefings/" table | NOT governed | Informational | Used to describe what a handoff prompt provides. Self-evident in context. |
| carry-forward | Q4 sections 2.1, 2.5, section 5 | In glossary indirectly | Informational | The workspace rule uses "carry-forward" as a governing principle. Not in the glossary word list explicitly, but "cross-machine carry-forward principle" is described in aitools-workspace.md. Q4 uses it consistently with the workspace rule's definition. |

### 1.2 Terms used in Q10 not in governed vocabulary

| Term | Used in | Status | Severity | Recommendation |
|------|---------|--------|----------|---------------|
| prevention layer / detection layer / audit layer | Q10 throughout | Partially governed | Informational | "prevention" and "detection" are in the glossary. "audit" is in the glossary. "three-layer governance" is in the glossary. The compound "prevention layer" etc. are self-evident compositions per the governed vocabulary composition convention. No action needed. |
| capability bypass | Q10 section 1 (Rules), section 2 | NOT governed | Informational | Used 3 times. Defined operationally in governed-data-access.md ("A JSON path in a non-skill file is a bypass vector"). Self-evident. |
| heuristic | Q10 section 2 | NOT governed | Informational | Used to describe what hooks check. Common English word, self-evident. |

### Pass 1 Summary

- **1 blocker**: "promotion" — core concept of Q4, used 14+ times, undefined
- **5 should-resolve**: "briefing," "AAR," "intelligence product," "artifact role," "framework artifact"
- **7 informational**: terms that are self-evident or composed from governed terms

---

## Pass 2: Contradictions and Gaps with the Planning Brief

### 2.1 Q4 contradictions with existing decisions

| Finding | Severity | Details |
|---------|----------|---------|
| **Q4 proposes `briefings/` at repo root; decision #34 consolidates everything under `.aitools/`** | Blocker | Decision #34 says "All aitools workspace features live under .aitools/ at repo root — scratch, channel, harvesting are user-level capabilities." Q4 explicitly evaluates this (Option C) and rejects it, arguing briefings are "project content, not harness capabilities." But Q4 does not acknowledge that decision #34 is an agreed decision in the brief. Q4 should either: (a) acknowledge the tension with #34 and explain why briefings are an exception, or (b) propose amending #34 to exclude briefings from the `.aitools/` consolidation. Currently Q4 implicitly amends #34 without saying so. |
| **Q4 says AARs go through harvesting pipeline; decision #36 says AARs are always produced in `.aitools/channel/` and archived by `channel-archive.sh`** | Should-resolve | Q4 section 2.2 says AAR lifecycle is `scratch -> harvesting/ -> consumed -> pruned/promoted`. Decision #36 component (11) says AAR is produced in `.aitools/channel/session-XXX/` and copied to `.aitools/harvesting/`. Q4's lifecycle omits the channel stage entirely. Q4 was apparently written before decision #36 was finalized (or without reading #36's full components). The correct lifecycle per #36 is: `channel -> harvesting -> consumed -> pruned/promoted`. Q4 must align with #36. |
| **Q4 proposes `harvesting/` at repo root; decision #34 moves it to `.aitools/harvesting/`** | Blocker | Q4's lifecycle diagram (section 5) shows `harvesting/` at the repo root. Decision #34 component (4) explicitly says ".aitools/harvesting/ — artifact harvesting lifecycle (was harvesting/). Tracked in git." Q4 uses the OLD path throughout. This is a direct contradiction with an agreed decision. |
| **Q4 does not reference decisions #50 (running estimate) or #53 (governed drift)** | Should-resolve | Decision #50 makes the running estimate a first-class governed concept with a detailed schema and lifecycle. Q4 section 2.5 mentions running estimates but without referencing #50. Decision #53 introduces `governedBy` for cross-document consistency — if briefings are governed data (decision #45), the briefing directory's governance would interact with #53. Q4 does not mention either. |
| **Q4 does not reference decision #36's absorption of artifact harvesting** | Should-resolve | Decision #36 explicitly absorbs the artifact harvesting framework into Operational Learning. Q4 treats harvesting as an independent framework. The harvesting rule (`.claude/rules/artifact-harvesting.md`) is marked status "absorbed" in #36's artifacts. Q4 should acknowledge this absorption and frame harvesting as a component of Operational Learning, not a standalone framework. |

### 2.2 Q10 contradictions with existing decisions

| Finding | Severity | Details |
|---------|----------|---------|
| **Q10 says "no new skill needed" but `reference/harness.md` already references `/artifact-roles` skill** | Should-resolve | `reference/harness.md` line 11 says "NOT artifact roles — what each artifact type is for and what it must not contain (see `/artifact-roles` skill)." Line 71 says "Artifact roles: `/artifact-roles` skill." The harness definition was rewritten AFTER decisions were made and explicitly scoped out artifact roles to a future `/artifact-roles` skill. Q10 recommends Option C (no new skill, enrich `/governed-data`). This contradicts what `harness.md` already promises. Either Q10 must update harness.md to remove the `/artifact-roles` reference, or Q10 must accept that a `/artifact-roles` skill IS expected. |
| **Q10 proposes a "lean standalone rule" (`.claude/rules/artifact-roles.md`) but no corresponding decision exists in the brief** | Should-resolve | Q10's recommendation includes a new rule file. The planning brief has no decision for artifact-roles. Decisions #39 and #40 cover intent skills. Decision #42 covers intent-enforcement hooks. But none cover an artifact-roles rule. Q10 would need a new decision added to the brief, or it must map to an existing decision. |
| **Q10's hook detection overlaps with decision #42 (intent-enforcement hook)** | Informational | Q10 proposes `artifact-role-guard.sh` that checks Write/Edit to harness file paths. Decision #42 proposes `intent-enforcement.sh` that checks Write to new framework artifact files. The scopes overlap but are not identical: #42 checks for intent PRESENCE in new files; Q10's hook checks for role VIOLATIONS in any write. These could conflict if both fire on the same Write operation. Q10 should address the interaction. |
| **Q10 does not reference decision #54 (harness improvement cycle)** | Informational | Decision #54 defines the process by which findings become verified fixes. Q10's proposed hook detections would surface findings that feed #54's cycle. Q10 should cross-reference #54. |

### 2.3 Decisions Q4 and Q10 should reference but do not

| Decision | Why it is relevant | Which report misses it |
|----------|-------------------|----------------------|
| #34 (namespace consolidation) | Directly governs where harvesting, scratch, and channel live. Q4 uses pre-consolidation paths. | Q4 |
| #36 (Operational Learning) | Absorbs artifact harvesting. Changes AAR lifecycle. Q4 treats harvesting as independent. | Q4 |
| #50 (running estimate) | Defines carry-forward state lifecycle. Q4 covers running estimates without referencing it. | Q4 |
| #53 (governed drift) | Introduces `governedBy` field. If briefings are governed data per #45, they interact with #53. | Q4 |
| #54 (harness improvement cycle) | Defines finding-to-fix process. Q10's hooks generate findings that feed this cycle. | Q10 |
| #51 (plan-writing protocol) | Defines how S3 writes plans from briefs. Q4's briefing lifecycle ends at "plan execution consumes the brief" — should reference #51 for HOW. | Q4 |

### 2.4 Decisions that Q4/Q10 implicitly amend

| Decision | How it is implicitly amended | Report |
|----------|------------------------------|--------|
| #34 | Q4 proposes `briefings/` at repo root, contradicting #34's "all under `.aitools/`" scope. Q4 argues briefings are project content, not harness capabilities — this is a legitimate exception but is NOT framed as an amendment to #34. | Q4 |
| #36 | Q4 describes a harvesting lifecycle that predates #36's absorption. Q4's lifecycle would need to be updated to show harvesting as an Operational Learning component, not a standalone pipeline. | Q4 |

---

## Pass 3: Internal Consistency Between Q4 and Q10

### 3.1 Briefings "not ephemeral" vs reference files "on demand for depth"

Q4 states: "Briefings are living documents during planning. They are NOT ephemeral — created directly in `briefings/<name>/`."

Q10 states: "A reference file describes WHAT was adopted and WHY... It is consulted on demand for depth."

**Finding**: These do not conflict. Q4 describes briefings as a NEW artifact type (not a reference file). Q10 describes the role of existing reference files. However, Q10's role definitions do not include "briefing" as an artifact type. Q10 defines 5 types: rules, skills, reference files, registries, hooks. Briefings would be a 6th type. Q10 does not mention this expansion. **Severity: Should-resolve.** If Q4 introduces a new artifact type, Q10's role framework must accommodate it.

### 3.2 AARs in harvesting pipeline vs governed-data skill "owns content placement"

Q4 says: "AARs go through the harvesting pipeline (scratch -> harvesting -> consumed -> pruned/promoted)."

Q10 says: The governed-data skill's content placement standard defines "what goes where." Q10 recommends enriching `/governed-data` with full role definitions.

**Finding**: The governed-data skill currently has a one-line mention of content placement (SKILL.md line 82: "Discussing the content placement standard (reference vs rule vs skill)"). It does NOT mention AARs, briefings, harvesting, or channel. Q10's recommendation to enrich the skill with artifact-role definitions does not mention the new artifact types Q4 introduces (briefings, AARs, investigation reports). If `/governed-data` is to own content placement, it must know about ALL content types — including the ones Q4 defines. **Severity: Should-resolve.**

### 3.3 `briefings/` governance gap

Q4 proposes a new `briefings/` directory and says "A briefings/ directory requires a governing rule (`.claude/rules/briefings.md` or similar)."

Q10 says "no new skill needed" and recommends enriching `/governed-data` with content placement.

**Finding**: These may conflict. If briefings get their own rule (`.claude/rules/briefings.md`), that is a new always-in-context rule. Q10 argues against new rules (Option A weakness: "yet another rule always in context"). But Q4 explicitly says one is needed. The resolution depends on whether briefings are governed by their own rule (Q4's recommendation) or by the general content placement standard in `/governed-data` (Q10's recommendation). **Severity: Should-resolve.**

### 3.4 Q4's "promotion" concept vs Q10's "content placement"

Q4 defines promotion as the mechanism artifacts move between lifecycle stages (scratch -> harvesting -> reference, or harvesting -> briefings).

Q10 defines content placement as knowing "what goes where" based on artifact roles.

**Finding**: These are describing the same problem from different angles. Q4 focuses on the lifecycle (WHEN and WHERE artifacts move). Q10 focuses on the type system (WHAT belongs WHERE based on its role). They need to be reconciled: content placement (Q10) should include promotion criteria (Q4), and promotion (Q4) should reference the role definitions (Q10). Currently they are independent. **Severity: Informational.** Natural complementarity, not contradiction.

### 3.5 Missing cross-references between Q4 and Q10

Q4 does not reference Q10's artifact role definitions. Q10 does not reference Q4's lifecycle stages. A fresh agent reading only Q4 would not know about role constraints. A fresh agent reading only Q10 would not know about lifecycle stages. If both are implemented, they must cross-reference each other. **Severity: Informational.**

---

## Pass 4: Consistency with the Workspace Rule

### 4.1 Briefings fall outside the workspace scope

`.claude/rules/aitools-workspace.md` defines project-scoped artifacts under `.aitools/`:

| Directory | Tracked | Purpose |
|-----------|---------|---------|
| `scratch/` | gitignored | Session-ephemeral working files |
| `channel/session-*/` | gitignored | Session-ephemeral messages |
| `channel/running-estimate.json` | tracked | Carry-forward state |
| `harvesting/` | tracked | Artifact lifecycle |

Q4 proposes `briefings/` at the repo root (NOT under `.aitools/`), arguing briefings are "project-specific content, not harness capabilities."

**Finding**: Q4's reasoning is sound and consistent with the workspace rule's governing principle: ".aitools/ holds harness capabilities that persist across sessions and machines." Briefings are indeed project content, not harness capabilities. However, the workspace rule does not mention `briefings/` at all, and does not anticipate tracked project directories outside `.aitools/`. The workspace rule may need a "what is NOT in .aitools/" section to make the boundary explicit. **Severity: Informational.**

### 4.2 Q4 uses pre-consolidation paths

Q4's lifecycle diagram (section 5) uses `harvesting/` (repo root) instead of `.aitools/harvesting/` (per decision #34 and the workspace rule). The workspace rule says `harvesting/` is under `.aitools/`. Q4 contradicts this. Already flagged in Pass 2 as a blocker.

### 4.3 Decision #34 status in workspace rule

The workspace rule states: "Decision #34 status: Planning brief decision #34 is superseded by this rule." This means the workspace rule IS the authoritative source on where `.aitools/` things live. Q4 must align with the workspace rule, not with decision #34 directly. Q4 does not reference the workspace rule at all. **Severity: Should-resolve.**

---

## Pass 5: Consistency with the Harness Definition

### 5.1 Harness.md references `/artifact-roles` skill that Q10 says is not needed

`reference/harness.md` line 11:
> NOT artifact roles — what each artifact type is for and what it must not contain (see `/artifact-roles` skill).

`reference/harness.md` line 71:
> Artifact roles: `/artifact-roles` skill

Q10 recommends Option C: no dedicated `/artifact-roles` skill. Instead, enrich `/governed-data` and add a lean rule.

**Finding**: Harness.md was written (or rewritten) with the expectation that `/artifact-roles` would be a separate skill. Q10 contradicts this. If Q10's recommendation is adopted, `reference/harness.md` must be updated to remove the `/artifact-roles` references and replace them with the actual location of artifact-role documentation (the enriched `/governed-data` content placement standard, plus the new lean `artifact-roles.md` rule). **Severity: Should-resolve.**

### 5.2 Harness.md lists 5 components — does `briefings/` affect them?

The 5 components are: Platform, Configuration, Orchestration, Managed tools, Frameworks.

Q4 proposes `briefings/` as a new top-level directory. This does not introduce a new harness COMPONENT — briefings are project content produced USING the harness, not a harness capability. The harness definition does not need a new component.

However, the Orchestration component description mentions "plans, and reference files" as things the harness manages. If briefings are added, Orchestration should mention them too — the harness manages the briefing lifecycle via `/brief` skill (decision #45), the channel infrastructure, and the harvesting pipeline.

**Finding**: `reference/harness.md` Orchestration component should mention briefings once Q4 is implemented. **Severity: Informational.**

### 5.3 Q10's lean rule and the Configuration component

Q10 proposes `.claude/rules/artifact-roles.md` — a new rule. This fits within the existing Configuration component (rules are project-level configuration). No update needed to the harness definition for this. **Severity: None.**

### 5.4 Six artifact types vs five

`reference/harness.md` currently scopes out artifact roles to the `/artifact-roles` skill. Q10 defines 5 artifact types: rules, skills, reference files, registries, hooks. Q4 implicitly adds a 6th: briefings. If Q10's artifact-role framework is implemented, it must account for briefings (and potentially plans, AARs, investigation reports — all types Q4 defines).

**Finding**: Q10 defines 5 harness artifact types. Q4 defines 5 operational artifact types (briefings, AARs, plans, investigation reports, running estimates). These are different taxonomies for different purposes — Q10's types are about governance (what MUST/MUST NOT be in a file), Q4's types are about lifecycle (where artifacts live and how they move). Both are needed. But they must not be conflated. The artifact-role framework (Q10) does not need to govern ALL content types — only harness infrastructure files. Briefings, plans, and AARs are content produced BY the harness, not part of it. **Severity: Informational.** This distinction should be documented explicitly.

---

## Summary

### Finding counts

| Pass | Blockers | Should-resolve | Informational |
|------|----------|---------------|---------------|
| 1. Undefined terms | 1 | 5 | 7 |
| 2. Brief contradictions | 2 | 5 | 2 |
| 3. Q4-Q10 consistency | 0 | 3 | 2 |
| 4. Workspace rule | 0 | 1 | 1 |
| 5. Harness definition | 0 | 1 | 3 |
| **Total** | **3** | **15** | **15** |

### Blockers (must resolve before proceeding)

1. **"Promotion" is undefined** (Pass 1): Core concept of Q4 used 14+ times with no governed definition. Four different interpretations appear across the document.

2. **Q4 uses pre-consolidation paths** (Pass 2): Q4 shows `harvesting/` at repo root throughout. Decision #34 (agreed) and the workspace rule (authoritative) both place it at `.aitools/harvesting/`. Q4's lifecycle diagram, migration plan, and all path references use the wrong location.

3. **Q4 proposes `briefings/` at repo root without acknowledging decision #34** (Pass 2): Decision #34 says "all workspace features under `.aitools/`." Q4 argues briefings are an exception (project content, not harness capabilities) but does not frame this as an amendment to #34. The argument is valid — but the brief must be formally amended with a decision that explicitly carves out the exception.

### Recommendation

**Amend Q4 before proceeding.** The three blockers are all in Q4. Specifically:

1. Add "promotion" to the governed vocabulary via /glossary (or define it inline and flag for governance).
2. Update ALL paths in Q4 to use `.aitools/harvesting/` per decision #34 and the workspace rule.
3. Frame the `briefings/` proposal as an explicit exception to decision #34, with rationale. Consider whether a new brief decision is needed (e.g., "Decision #55: Briefings live at repo root, not under .aitools/, because they are project content").
4. Align Q4's AAR lifecycle with decision #36 (channel -> harvesting, not scratch -> harvesting).

**Q10 can proceed with amendments.** Q10's should-resolve items are mostly alignment issues with `reference/harness.md` (which already references `/artifact-roles` skill) and missing cross-references to Q4. These can be resolved during implementation by either: (a) creating the `/artifact-roles` skill that harness.md promises (reversing Q10's recommendation), or (b) updating harness.md to point to the enriched `/governed-data` content placement standard instead.

The Q4-Q10 interaction (Pass 3) requires coordination: whoever implements Q10's artifact-role framework must include Q4's artifact types in the content placement standard, and whoever implements Q4's lifecycle must reference Q10's role definitions.
