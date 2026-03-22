# Barrier Analysis: Suggestion C (Carry-Forward Amendment)

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Subject**: Amendment to cross-machine carry-forward principle in `.claude/rules/aitools-workspace.md`

## Proposed amendment (Suggestion C)

Replace:
> "MUST be tracked in git so it survives machine switches via pull"

With:
> "MUST be persisted in the repo. In git repos, this means tracked (not gitignored). In cloud-synced folders, this means saved to the synced location. In local-only repos, the user is responsible for backup."

---

## 1. Scenario Replay Results

### Scenario 1: Git repo user

**Result: PASS**

The clause "In git repos, this means tracked (not gitignored)" is unambiguous. A developer reading this knows: `git add` the file, do not put it in `.gitignore`. The parenthetical "(not gitignored)" is a useful clarification -- it addresses the exact failure the current `.aitools/` blanket gitignore creates (see briefings-location-decision.md section 3: `.aitools/` in root `.gitignore` currently prevents tracking of `running-estimate.json` and `harvesting/`). No interpretation needed.

### Scenario 2: Google Drive user

**Result: PASS**

"Saved to the synced location" is clear for cloud-synced folders. Google Drive syncs all files within the Drive folder automatically. A user placing `.aitools/` inside a Drive-backed folder gets carry-forward without any additional action. The phrase correctly identifies that the user's only obligation is to save the file in the right place -- the sync mechanism handles the rest.

### Scenario 3: NAS user

**Result: PASS with caveat**

"The user is responsible for backup" is honest and correct. NAS shares may or may not have automatic backup/sync. The amendment does not pretend to solve a problem the harness cannot solve. However, "backup" is slightly imprecise -- backup implies recovery from loss, while carry-forward implies access from another machine. A NAS that is mounted on both machines already provides carry-forward without "backup." The real distinction is: is the folder accessible from the other machine? If yes, carry-forward works. If no, the user must arrange it.

Suggested refinement: "In local-only repos, the user is responsible for ensuring cross-machine access" would be more precise than "backup." But this is a minor accuracy issue, not a failure.

### Scenario 4: Hook developer

**Result: PASS**

A hook developer (e.g., implementing `session-archive.sh`) can read this and write dispatch logic:

```
if git repo:
  git add + git commit (tracked, not gitignored)
else:
  write to disk (cloud sync or local persistence handles the rest)
```

The enumeration gives the hook developer three concrete cases to handle. This is more actionable than an abstract principle like "persisted in a way that survives machine switches." The developer knows what each case requires.

### Scenario 5: Agent writing code

**Result: PASS**

An agent encountering this rule gets explicit per-mechanism guidance. When creating a new carry-forward artifact (e.g., briefing documents), the agent can determine: am I in a git repo? Then ensure the file is tracked. Am I in a Drive folder? Then save normally. The decision tree is embedded in the wording.

### Scenario 6: Future repo types (S3 bucket, IPFS, remote containers)

**Result: PARTIAL PASS -- maintainability concern**

The enumeration covers three cases: git, cloud-synced, local-only. Future repo types must be classified into one of these buckets or a new clause added. Assessment:

- **S3 bucket**: Behaves like cloud-synced -- save to location, sync handles the rest. Covered by existing clause.
- **IPFS**: Conceptually different -- content-addressed, not location-addressed. NOT covered.
- **Remote dev container (GitHub Codespaces, Gitpod)**: These ARE git repos. Covered.
- **Dropbox / OneDrive / LucidLink / Suite Studios**: Cloud-synced. Covered.

The three categories (git, cloud-synced, local-only) form a reasonable taxonomy. Most foreseeable repo types fit. Truly novel storage paradigms (IPFS, blockchain-backed) would require amendment, but these are speculative. The taxonomy is stable enough for the harness's current and near-future scope.

Risk: Each new mechanism category requires updating a rule file (protected, requires review). This is acceptable -- the carry-forward principle is foundational, and changes to it SHOULD require deliberate review.

### Scenario 7: Rules are governance, not howtos

**Result: CONCERN -- borderline role violation**

This is the most interesting scenario. The workspace rule (`.claude/rules/aitools-workspace.md`) is a governance artifact. Its intent statement says: "Govern the `.aitools/` workspace namespace." The current carry-forward principle is a governing constraint: "MUST be tracked in git." This is a rule -- it tells you WHAT must be true.

Suggestion C shifts toward HOW:

| Clause | Nature |
|--------|--------|
| "MUST be persisted in the repo" | Governance (WHAT) |
| "In git repos, this means tracked (not gitignored)" | Implementation guidance (HOW) |
| "In cloud-synced folders, this means saved to the synced location" | Implementation guidance (HOW) |
| "In local-only repos, the user is responsible for backup" | Implementation guidance (HOW) |

The first clause is pure governance. The subsequent three clauses are per-mechanism elaboration -- they explain HOW to satisfy the governance constraint for each repo type.

**Is this a role violation?** The harness design principle "Skills as enablement" says skills are process implementations and rules govern. The three-layer pattern says rules state intent and trigger directives.

However: the current wording ("tracked in git so it survives machine switches via pull") ALSO mixes governance and implementation. It says WHAT (tracked) and HOW (in git, via pull). Suggestion C is not introducing a new pattern -- it is extending the existing pattern to cover more cases.

The question is whether the enumeration belongs in:
- The rule (always in context, concise, governance)
- A reference file (loaded on demand, detailed, implementation)
- A skill (accessed when needed, process)

**Assessment**: The enumeration is short (three clauses, one sentence each). It does not create maintenance burden in the rule. Moving it to a reference file would leave the rule with only "MUST be persisted in the repo" -- which is so abstract it provides no actionable constraint. An agent reading "persisted in the repo" without the per-mechanism clauses would not know whether gitignored files count as "persisted." The elaboration is necessary for the rule to be unambiguous, which is a design principle ("Ambiguity is a defect").

**Verdict on Scenario 7**: The per-mechanism elaboration is justified by the ambiguity principle. A governance rule that can be read two ways is itself a defect. The three clauses eliminate that ambiguity at acceptable length cost.

---

## 2. Strengths

1. **Eliminates the original failure**: The current wording excludes non-git repos from the harness. Suggestion C explicitly covers three repo types, making the carry-forward principle universal.

2. **Actionable for each case**: Unlike an abstract principle ("persisted in a way that survives"), Suggestion C tells the reader exactly what to do for their repo type. No interpretation required.

3. **Honest about limitations**: The local-only clause does not pretend the harness can solve a problem it cannot. It names the user's responsibility explicitly.

4. **Backward compatible**: The git clause preserves the exact current semantics for git repos. Existing git-based workflows, hooks, and check scripts do not need to change their behavior -- only the rule text changes.

5. **Enables hook dispatch**: Hook developers get an enumerated set of cases to implement, rather than an open-ended abstraction they must interpret.

6. **Self-documenting for the workspace table**: The workspace structure table column "Tracked" (which currently implies git tracking) can be reinterpreted per the rule: "tracked" means "persisted per the carry-forward mechanism appropriate to the repo type."

---

## 3. Weaknesses

1. **Length**: At ~45 words, Suggestion C is approximately 3x the length of the current wording (~15 words). In a rule that is always in context, every word has a token cost. However, the rule file is 66 lines total -- this amendment adds roughly one line net.

2. **Borderline governance/implementation mixing**: The per-mechanism clauses explain HOW to persist, not just WHAT must be persisted. As analyzed in Scenario 7, this is justified by the ambiguity principle but is worth noting as a conscious tradeoff.

3. **"Backup" imprecision for local-only**: As noted in Scenario 3, "backup" implies loss recovery rather than cross-machine access. A NAS mounted on both machines provides carry-forward without backup. Minor but worth correcting.

4. **"Saved to the synced location" is nearly tautological**: For cloud-synced folders, saying "save to the synced location" tells the user to do what they would do anyway -- save a file in the folder that syncs. The clause is correct but adds minimal informational value. Its real value is completeness: it confirms that no special action (like git add) is needed for cloud-synced repos.

5. **Downstream references still say "git"**: The planning brief, handoff prompt, and release notes contain ~20+ references to "tracked in git" or "carry-forward via pull." Amending the rule alone does not fix the downstream language. These would need updating for full consistency, though they are not protected files (plans and harvested artifacts are historical).

6. **The "Tracked" column in the workspace table**: The table uses "tracked" and "gitignored" as column values. In a non-git repo, these terms are meaningless. The table would need a footnote or the column header would need rewording (e.g., "Persisted" instead of "Tracked"). This is a cascading change within the same file, so it can be done atomically.

---

## 4. Verdict: ACCEPT with two minor amendments

**Accept Suggestion C.** It is the strongest of the options because it eliminates ambiguity, covers the three real-world repo types, and provides actionable guidance without crossing into process territory. The per-mechanism enumeration is justified by the harness design principle that ambiguity is a defect.

### Recommended minor amendments

**Amendment 1**: Replace "backup" with "cross-machine access" in the local-only clause:

> "In local-only repos, the user is responsible for cross-machine access."

Rationale: "Backup" implies loss recovery. The carry-forward principle is about access from another machine, not loss prevention. A NAS mounted on two machines provides carry-forward without backup.

**Amendment 2**: When applying the amendment, also update the "Tracked" column header in the workspace structure table within the same file to "Persisted" (or add a footnote: "In git repos, 'tracked' means committed to git. In other repos, 'persisted' means saved to the repo folder."). This prevents a within-file inconsistency where the rule says "persisted" but the table says "tracked/gitignored."

### Final proposed wording (with amendments applied)

> "MUST be persisted in the repo. In git repos, this means tracked (not gitignored). In cloud-synced folders, this means saved to the synced location. In local-only repos, the user is responsible for cross-machine access."

### Note on downstream references

The ~20+ downstream references to "tracked in git" and "carry-forward via pull" in plans, handoff prompts, and release notes are historical artifacts. They document what the rule said at the time of writing. They do not need retroactive correction -- the rule is the source of truth, and future sessions will read the amended rule. If any of these files are actively consumed (handoff prompt for the current mission), they should be updated as part of the mission execution, not as part of this amendment.
