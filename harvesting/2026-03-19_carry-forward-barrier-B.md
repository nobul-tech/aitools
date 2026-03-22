# Barrier Analysis: Carry-Forward Amendment -- Suggestion B

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Subject**: Replace "MUST be tracked in git so it survives machine switches via pull" with "MUST be persisted in the repo's backing storage"

**Comparison baseline**: Suggestion A -- "MUST be persisted in a way that survives machine switches"

---

## 1. Scenario Replay

### Scenario 1: Git repo user (~/repos/aitools)

**Amended text in context**: "Project state that carries forward between sessions -- running estimates, consolidated findings, harvested artifacts -- MUST be persisted in the repo's backing storage."

**Question**: Would this user know to `git add`?

**Result: PARTIAL.** The phrase "repo's backing storage" implies git for a git repo, but it does not name the action. The current text says "tracked in git" -- that maps directly to `git add` + `git commit`. "Persisted in the repo's backing storage" requires the reader to (a) identify that their repo's backing storage is git, and then (b) determine what "persisted in git" means operationally. The indirection is one step longer than the current text. However, any developer working in a git repo already knows what git tracking means -- the indirection is trivial for the target audience (developers, per CLAUDE.md "End users are developers").

An agent reading this rule would need to resolve "backing storage" to "git" and then determine the persistence action (`git add`). This is inferrable but not explicit.

**Verdict: Adequate.** The developer audience makes the indirection safe. An explicit "for git repos, this means tracking via git add/commit" parenthetical would be belt-and-suspenders but not strictly necessary.

### Scenario 2: Google Drive user (Drive/project-x)

**Amended text in context**: "...MUST be persisted in the repo's backing storage."

**Result: CLEAR.** The repo's backing storage is Google Drive. "Persisted in Google Drive" = save the file. Google Drive sync handles the rest. The user writes a file to `Drive/project-x/.aitools/channel/running-estimate.json`, and cloud sync persists it. No additional action required -- the act of writing IS persistence.

This is actually clearer than Suggestion A ("persisted in a way that survives machine switches"), because Suggestion A puts the burden on the user to evaluate WHETHER their storage survives machine switches. Suggestion B says "persist in the backing storage" and leaves it to the storage to provide whatever durability it provides. The user's choice of storage mechanism IS the answer.

**Verdict: Clear and actionable.** Stronger than Suggestion A for this scenario.

### Scenario 3: NAS user (/Volumes/NAS/shared)

**Amended text in context**: "...MUST be persisted in the repo's backing storage."

**Result: CLEAR.** The repo lives on the NAS. The backing storage is the NAS filesystem. Writing a file to the NAS directory = persistence in the backing storage. If the NAS is network-mounted on multiple machines, carry-forward is automatic. If it's only accessible from one machine, carry-forward is limited -- but that's a property of the user's infrastructure choice, not a rule failure.

**Verdict: Clear.** Same as Scenario 2 -- the user's storage choice determines the durability guarantee.

### Scenario 4: Hook developer writing SessionEnd hook

**Question**: Does "backing storage" give the hook developer enough guidance to write the persistence logic?

**Result: PROBLEMATIC.** A hook needs to know what to DO, not what to AIM FOR. The current text ("tracked in git") gives a direct implementation: `git add` + `git commit`. Suggestion A ("persisted in a way that survives machine switches") gives a goal -- the hook developer must figure out the mechanism. Suggestion B ("persisted in the repo's backing storage") gives a target -- but the hook still needs to discover what the backing storage IS and what the persistence action IS for that storage.

Concretely, the SessionEnd hook would need:

1. Detect repo type: is this a git repo? (check for `.git/`)
2. If git: `git add <file>` + `git commit`
3. If not git: just write the file (it's already on the filesystem; if it's cloud-synced, sync handles it)

The phrase "backing storage" doesn't help with step 1 (detection) or steps 2-3 (action selection). But importantly, neither does Suggestion A. Both require the hook developer to build a detection+dispatch pattern. The current git-only text avoids this entirely by assuming git.

**Verdict: No worse than Suggestion A, but both are weaker than the current text for implementers.** The rule's job is to state the principle; the hook's implementing code handles the dispatch. This is an acceptable separation of concerns -- the rule governs the what, the code governs the how.

### Scenario 5: Agent writing code

**Question**: Can an agent determine the right persistence action from "repo's backing storage"?

**Result: ADEQUATE.** An agent working in a Claude Code session can check for `.git/` to determine if the repo is a git repo. If yes, `git add`. If no, the file is already persisted to the filesystem -- no additional action needed. The phrase "backing storage" points the agent toward "whatever this repo uses" rather than hardcoding git.

However, there is a subtlety: an agent might interpret "persisted in the repo's backing storage" as requiring an EXPLICIT persistence action beyond just writing the file. In a Google Drive folder, writing the file IS persistence. The agent doesn't need to do anything extra. But the phrase "MUST be persisted" could read as "you must take a persistence action" rather than "the file must end up in durable storage." This is a minor ambiguity -- "persisted" as a verb (requiring action) vs "persisted" as a state (requiring a result).

**Verdict: Adequate with minor ambiguity.** The verb/state ambiguity is real but unlikely to cause incorrect behavior in practice.

### Scenario 6: What IS "backing storage"?

**Question**: Is this term self-evident or does it introduce a new undefined concept?

**Result: TERM NEEDS EXAMINATION.** "Backing storage" is not a governed term. It appears exactly once in the codebase today -- in the proposed "repo" definition from the briefings-location-decision.md: "The harness provides capabilities (`.aitools/`) to repos regardless of their backing storage." That definition uses "backing storage" as a property of a repo without defining what it means.

In general computing, "backing store" / "backing storage" has an established meaning: the underlying persistent storage mechanism behind a higher-level abstraction (e.g., the disk is the backing store for a virtual memory system; S3 is the backing store for an application's file API). This meaning maps well here: git is the backing store for a git repo's versioned state; Google Drive is the backing store for a cloud-synced folder.

However, the term has a subtle mismatch: for a git repo, "backing storage" could mean either (a) git itself (the version control system) or (b) the filesystem that git uses. These differ:
- If backing storage = git: "persisted in git" means `git add` + `git commit`. Uncommitted files are NOT persisted.
- If backing storage = filesystem: "persisted in the filesystem" means just writing the file. Uncommitted files ARE persisted (on disk, just not tracked by git).

This ambiguity matters. For carry-forward to work across machines via `git pull`, the file must be committed to git -- written to the filesystem is not enough. So for git repos, "backing storage" must mean "git" (the VCS), not "the disk." But for Google Drive folders, "backing storage" means "the filesystem" (which Google Drive syncs). The term means different things for different repo types, and the reader must resolve the correct meaning based on context.

**Verdict: The term is not self-evident. It introduces a concept that carries an ambiguity (VCS vs filesystem) that matters for the git-repo case.** It is NOT immediately obvious that an uncommitted file in a git repo fails to satisfy "persisted in the repo's backing storage" -- a reasonable reader could argue that a file on disk IS persisted in the backing storage (the filesystem), even if git doesn't know about it.

---

## 2. Strengths

1. **Concreteness via indirection.** "The repo's backing storage" ties the persistence mechanism to the repo's own nature rather than naming a specific technology. This makes the principle automatically correct for any repo type -- git, cloud, NAS, local -- without enumerating them. Suggestion A ("in a way that survives machine switches") is abstract and goal-oriented; Suggestion B is concrete by pointing to a specific thing (the backing storage) even if that thing varies.

2. **Shorter than Suggestion A.** "MUST be persisted in the repo's backing storage" is 9 words. "MUST be persisted in a way that survives machine switches" is 12 words. In a rule that's always in context, brevity has value.

3. **Terminological coherence.** The proposed "repo" definition already uses "backing storage" -- "The harness provides capabilities to repos regardless of their backing storage." Using the same term in the carry-forward principle creates internal consistency. If "repo" is governed and its definition mentions "backing storage," the carry-forward principle inherits clarity from that definition.

4. **Eliminates the git assumption.** The current text hardcodes git. Suggestion B removes the hardcoding without losing specificity (unlike Suggestion A, which loses specificity by being purely goal-oriented).

5. **Naturally handles the NAS/local case.** Suggestion A says "survives machine switches" -- but for a NAS-mounted folder, machine switches are irrelevant (the folder is already accessible from all machines). Suggestion B says "persisted in the backing storage" -- the NAS filesystem IS the backing storage, and writing to it IS persistence. No awkward "this principle doesn't quite apply to your case" reading.

---

## 3. Weaknesses

1. **VCS-vs-filesystem ambiguity for git repos (Scenario 6).** The critical weakness. For a git repo, "backing storage" is ambiguous between "git" and "the filesystem." An uncommitted file is on the filesystem but not in git. The carry-forward principle requires git tracking (for `pull` to carry it to another machine), but a reader could interpret "persisted in the repo's backing storage" as satisfied by an uncommitted file on disk. This is the same class of error that the principle exists to prevent.

   Suggestion A avoids this by focusing on the outcome ("survives machine switches") rather than the mechanism -- an uncommitted file does NOT survive a machine switch via `git pull`, so it clearly fails Suggestion A's test. Suggestion B's "persisted in backing storage" could be argued to pass even for uncommitted files.

2. **"Backing storage" is undefined.** The term is not governed and has no entry in the glossary. Introducing it in the carry-forward principle creates a dependency on an undefined concept. Per `.claude/rules/glossary.md`, terms used in rules should be governed. Using an ungoverned term in a governing principle is an ambiguity -- exactly what the principle design should avoid.

   Mitigation: govern the term via `/glossary` before or alongside the amendment. But this adds scope to what should be a simple text change.

3. **Implementation guidance is weaker.** The current text ("tracked in git so it survives machine switches via pull") gives both mechanism (git tracking) and rationale (survives via pull). Suggestion B gives only the target ("backing storage") with no rationale. A hook developer or agent reading Suggestion B gets less guidance on the "why" and "how" than either the current text or Suggestion A.

4. **The phrase is a tautology risk.** "Persisted in the repo's backing storage" approaches "stored in the storage." For a Google Drive folder, it reads: "files in this Google Drive folder must be persisted in Google Drive." That is always true -- anything written to the folder is in Google Drive. The principle becomes trivially satisfied and thus provides no governance. The carry-forward principle should create an obligation (you MUST do something specific), not describe a property that's always true.

   Compare with Suggestion A: "persisted in a way that survives machine switches" creates a testable obligation. If the user's setup doesn't survive machine switches, they're violating the principle. Suggestion B's obligation is trivially met by writing any file anywhere in the repo -- which may or may not survive a machine switch.

5. **Loses the "survive machine switches" intent.** The carry-forward principle exists to ensure cross-machine continuity. The current text names both the mechanism (git) and the goal (survive machine switches). Suggestion A keeps the goal but drops the mechanism. Suggestion B keeps neither -- it names a different mechanism (backing storage) and drops the goal entirely. A reader of Suggestion B might not understand WHY the principle exists.

---

## 4. Verdict: AMEND

**Suggestion B as written: reject.** The VCS-vs-filesystem ambiguity (weakness 1), the tautology risk for non-git repos (weakness 4), and the loss of the "survive machine switches" intent (weakness 5) are each individually concerning. Together, they make the amended text less effective than Suggestion A and potentially less effective than the original for git repos (where it introduces an ambiguity that doesn't exist today).

**Suggestion B can be rescued** by combining its concreteness with Suggestion A's intent clarity:

> "MUST be persisted in the repo's backing storage so it survives machine switches"

This hybrid:
- Keeps B's concreteness: "the repo's backing storage" (not abstract "in a way")
- Keeps A's testable intent: "so it survives machine switches" (the goal)
- Resolves the VCS ambiguity: for a git repo, an uncommitted file does NOT survive machine switches, so it fails the principle even though it IS on the filesystem
- Avoids the tautology: writing a file to a Google Drive folder satisfies "backing storage" but the "survives machine switches" clause adds a testable obligation (does Google Drive sync actually work on your setup?)

This hybrid is 12 words -- same as Suggestion A, shorter than the current text (15 words), and carries more information than either individual suggestion.

### Should "backing storage" be governed?

**Yes, but not blocking.** If "repo" is governed (per the briefings-location-decision recommendation) and its definition includes "backing storage" with examples (git, cloud sync, NAS filesystem), then "backing storage" inherits enough definition from the "repo" term to be self-evident. Governing it separately is cleaner but not strictly required if "repo" is governed first. If the hybrid wording is adopted, governing "backing storage" via `/glossary` would remove the last ambiguity.

### Summary

| Criterion | Current text | Suggestion A | Suggestion B | Hybrid (B+A) |
|-----------|-------------|-------------|-------------|---------------|
| Git repo clarity | Explicit | Clear (goal test) | Ambiguous (VCS vs FS) | Clear (goal test) |
| Non-git repo clarity | Fails (git assumed) | Clear | Clear (tautological) | Clear |
| Implementation guidance | Strong | Moderate | Weak | Moderate |
| Testable obligation | Yes | Yes | Weak (tautology risk) | Yes |
| Intent preservation | Full | Partial (goal only) | None | Full |
| Brevity | 15 words | 12 words | 9 words | 12 words |
| New undefined terms | None | None | "backing storage" | "backing storage" |
