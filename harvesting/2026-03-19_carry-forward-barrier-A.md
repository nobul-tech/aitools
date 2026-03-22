# Barrier Analysis: Suggestion A (Carry-Forward Principle Amendment)

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Subject**: Replace "MUST be tracked in git so it survives machine switches via pull" with "MUST be persisted in a way that survives machine switches"

---

## 1. Does This Amendment Prevent the Original Failure?

The original failure: the carry-forward principle explicitly names git as the only mechanism, which excludes non-git repos from the harness. A Google Drive folder, a NAS share, or a Dropbox project cannot comply with "tracked in git" because they have no git.

**Suggestion A does prevent this failure.** It removes the git-only gate. Any repo -- git, cloud-synced, NAS, local -- can satisfy "persisted in a way that survives machine switches." The principle becomes mechanism-agnostic: the requirement is the outcome (data survives), not the method (git pull).

However, preventing the exclusion failure is not the only concern. The amendment must also avoid *introducing* new failures. That is what the scenario replays test.

---

## 2. Scenario Replays

### Scenario 1: Git Repo User (~/repos/aitools)

**Current wording**: "MUST be tracked in git so it survives machine switches via pull." The git user reads this and knows exactly what to do: `git add` the file, commit, push. The wording names the tool, the action, and the mechanism in one sentence.

**Suggestion A**: "MUST be persisted in a way that survives machine switches." The git user reads this and... knows the file must persist. But the wording does not say HOW. A developer working in a git repo would likely infer "tracked in git," but the rule no longer states it. The inference depends on the reader's experience.

**Failure mode**: Low risk for experienced developers. Moderate risk for agents. An agent reading this rule in a git repo has no explicit instruction to `git add`. It must combine two facts: (1) this is a git repo, and (2) "persisted" in a git repo means "tracked." This is a reasoning step the current wording eliminates.

**Verdict**: Mild regression in clarity for the most common case.

### Scenario 2: Google Drive User (Drive/project-x)

**Current wording**: Impossible to comply. User cannot "track in git" a Google Drive folder (not without `git init`, which defeats the purpose of using Drive).

**Suggestion A**: "MUST be persisted in a way that survives machine switches." The Google Drive user reads this and can immediately comply: files in Google Drive auto-sync. Saving the file IS persisting it. The requirement is met by the storage medium itself -- no extra action needed.

**Failure mode**: None. This is the scenario Suggestion A exists to serve. Cloud-synced folders inherently satisfy "persisted in a way that survives machine switches."

**Verdict**: Clear improvement. Removes an impossible requirement and replaces it with one that's automatically satisfied.

### Scenario 3: NAS User (/Volumes/NAS/shared)

**Current wording**: Cannot comply (no git).

**Suggestion A**: "MUST be persisted in a way that survives machine switches." The NAS user reads this. NAS shares are accessible from multiple machines simultaneously -- no sync delay, no pull needed. Files saved to NAS are immediately available on any connected machine.

**Failure mode**: Low. NAS shares are multi-machine accessible by definition. The only failure mode is if the NAS goes offline, but that's infrastructure, not a carry-forward design flaw.

However, there is a subtle gap: a LOCAL folder (not NAS, not cloud-synced, not git) does NOT survive machine switches. The user saves to `/Users/pepe/projects/local-only/`. Suggestion A says "persisted in a way that survives machine switches." The local folder does NOT survive. The user should be warned -- but the rule gives no guidance on what to do when persistence is NOT achievable. Current wording doesn't address this either (it simply assumes git), but the new wording opens the door to repos where carry-forward is structurally impossible.

**Verdict**: Improvement for NAS. Introduces an unaddressed edge case for truly local-only folders.

### Scenario 4: Hook Developer Writing SessionEnd Hook

**Current wording**: The hook developer knows: "tracked in git" means the hook should `git add` carry-forward files. The existing `harvest-session.sh` already uses `git log` for pruning decisions (line 195-198) and `session-archive.sh` uses `git rev-parse --show-toplevel` (line 60). Both hooks already assume git.

**Suggestion A**: "MUST be persisted in a way that survives machine switches." The hook developer reads this and faces a design question: what does "persist" mean programmatically? In a git repo, it means `git add`. In a Google Drive folder, it means... nothing (already persisted by saving). In a NAS share, same. The hook must now branch on repo type:

```
if git repo:
    git add <file>
elif cloud-synced:
    # no-op, already persisted
elif local:
    # warn? fail? no-op?
```

The current hooks (`harvest-session.sh` line 34, `session-archive.sh` line 60-64) already have a partial version of this: they try `git rev-parse --show-toplevel` and fall back to `$CWD` if it fails. But they don't have a "persist" abstraction -- they do git operations when git is available and skip them when not.

**Failure mode**: Moderate. The principle changes but the hooks don't get a clear implementation contract. "Persisted" is a design goal, not an implementation instruction. The hook developer must figure out the dispatch logic themselves. This is solvable (check for `.git/`, dispatch accordingly), but it's work the current wording avoids by assuming git everywhere.

**Verdict**: Regression in implementability. The rule becomes aspirational without providing the mechanism taxonomy that hooks need to act on it.

### Scenario 5: Agent Writing Code

**Current wording**: Agent reads "tracked in git" and writes code that does `git add`, `git commit`. Unambiguous.

**Suggestion A**: Agent reads "persisted in a way that survives machine switches." The agent must now determine:
1. What type of repo is this?
2. What does "persist" mean for this repo type?
3. What code should I write?

For question 1, the agent can check for `.git/` directory. For question 2, the agent must reason: git repo = git add; non-git = file save is sufficient. For question 3, the agent writes a conditional.

**Failure mode**: Moderate. The agent CAN reason through this, but it has to perform inference that the current wording eliminates. More critically: agents tend to take the literal path. "Persisted in a way that survives machine switches" gives no concrete action. An agent might conclude "the file is already saved to disk, therefore it is persisted" -- which is technically true for the current machine but does NOT survive machine switches for a local-only folder. The rule's vagueness creates a reasoning trap.

**Verdict**: Regression in actionability for agents. Current wording is directly executable; Suggestion A requires multi-step reasoning with a risk of incorrect conclusions.

---

## 3. Strengths

1. **Removes the git-only gate**: The primary purpose is achieved. Non-git repos can now be part of the harness with carry-forward capabilities.

2. **Correct abstraction level**: The principle SHOULD be about the outcome (survives machine switches), not the mechanism (git pull). This is good design -- it future-proofs against storage mechanisms we haven't considered yet.

3. **Aligns with the companion decision**: "Repo" is now defined as "any OS-accessible folder." The carry-forward principle must match this expanded scope, and Suggestion A does.

4. **Minimal change**: Single sentence replacement. Low risk of cascading edits elsewhere in the rule (though other files reference "tracked in git" and will need amendment -- see section 4.2 below).

5. **The principle's closing sentence already supports it**: Line 28-29 already says "if data needs to survive a machine switch, it must be tracked" -- and that sentence uses "tracked" without the "in git" qualifier. Suggestion A makes the principle sentence consistent with this existing, already-mechanism-agnostic summary.

---

## 4. Weaknesses

### 4.1 Loss of Actionability

The current wording is simultaneously a principle AND an instruction: "tracked in git" tells you both WHAT to achieve (persistence) and HOW to achieve it (git tracking). Suggestion A keeps the WHAT but drops the HOW. For the most common case (git repos), this is a clarity regression.

### 4.2 The Workspace Table Still Says "Tracked"

The workspace structure table (lines 35-40) has a column header "Tracked" with values "tracked" and "gitignored." These terms are git-specific. If the principle becomes mechanism-agnostic, the table column is now misleading:

| Directory | Tracked | Purpose |
|-----------|---------|---------|
| `channel/running-estimate.json` | tracked | ... |
| `harvesting/` | tracked | ... |

What does "tracked" mean for a Google Drive folder? Everything is "tracked" (synced). What does "gitignored" mean for a NAS? Nothing. The table's vocabulary assumes git, and Suggestion A does not address this.

### 4.3 Hook Implementation Gap

As shown in Scenario 4, the hooks have no persistence abstraction. The principle changes but the implementation contract does not. This creates a spec-implementation gap: the rule says "persisted" but the hooks only know about git. Fixing this requires either:
- A persistence dispatch function (check repo type, act accordingly)
- Hook documentation that explains the mapping

Neither is part of Suggestion A.

### 4.4 The "Session-Ephemeral" Sentence Breaks

Line 25-26: "Session-ephemeral data (scratch files, in-flight channel messages) is gitignored -- it belongs to one session on one machine."

"gitignored" is a git-specific mechanism for marking files as session-ephemeral. In a non-git repo, this concept has no equivalent. Cloud-synced folders sync EVERYTHING -- there is no "gitignore" for Google Drive. Scratch files that should be ephemeral would persist and sync across machines, violating the principle that they "belong to one session on one machine."

Suggestion A only amends the carry-forward sentence. It does not address the symmetric problem: how do you make data ephemeral in a non-git repo?

### 4.5 Local-Only Folders Are Unaddressed

As identified in Scenario 3, a truly local folder (no git, no cloud sync, no NAS) cannot satisfy "persisted in a way that survives machine switches." The rule provides no guidance for this case. Should the harness warn the user? Refuse to create carry-forward data? Degrade gracefully? Suggestion A opens this door but doesn't walk through it.

### 4.6 Downstream References

The planning brief (lines 1555, 3327, 3328 in `planning-brief.json`) repeatedly says "tracked in git" for running estimate and channel state. The handoff prompt (line 356) says "state that needs to survive machine switch MUST be in git." RELEASE_NOTES.md (line 66) says "carry-forward state (running estimates) tracked in git." These all need updating, but they are downstream of the principle -- fixing the principle is the right first step, and the downstream fixes follow.

---

## 5. Verdict: AMEND

Suggestion A is directionally correct but insufficiently specific. It solves the exclusion problem (non-git repos can participate) but creates an actionability problem (no one knows what "persisted" means concretely for their repo type).

### Recommended Amendment

Replace the single-sentence swap with a two-part structure: the mechanism-agnostic principle PLUS a mechanism table that restores actionability.

Proposed replacement for lines 19-29:

```markdown
### Cross-machine carry-forward principle

A user working on the same project across multiple machines (macOS,
Windows) must be able to pick up where they left off. Project state
that carries forward between sessions — running estimates, consolidated
findings, harvested artifacts — MUST be persisted in a way that
survives machine switches.

How persistence is achieved depends on the repo's backing storage:

| Backing storage | Carry-forward mechanism | Ephemeral isolation |
|----------------|------------------------|-------------------|
| Git repository | `git add` + commit; arrives via pull | `.gitignore` patterns |
| Cloud-synced folder (Drive, Dropbox, OneDrive) | Automatic; file save = synced | No native isolation; ephemeral data cleaned by SessionEnd hook |
| NAS / shared volume | Automatic; file save = available | No native isolation; ephemeral data cleaned by SessionEnd hook |
| Local-only folder | No carry-forward; single-machine only | N/A |

Session-ephemeral data (scratch files, in-flight channel messages)
belongs to one session on one machine. In git repos, this is enforced
by `.gitignore`. In non-git repos, the SessionEnd hook is responsible
for cleanup.

This principle governs every workspace design decision: if data
needs to survive a machine switch, it must be persisted via the
repo's carry-forward mechanism.
```

### Why This Works

1. **Preserves the mechanism-agnostic principle** (Suggestion A's strength)
2. **Restores actionability** via the mechanism table (addresses weakness 4.1)
3. **Addresses ephemeral isolation** for non-git repos (addresses weakness 4.4)
4. **Acknowledges local-only limitation** explicitly (addresses weakness 4.5)
5. **Gives hook developers a dispatch taxonomy** (addresses weakness 4.3)
6. **The workspace structure table column** ("Tracked") should be renamed to "Persisted" with values "persisted" / "ephemeral" to match the mechanism-agnostic language (addresses weakness 4.2)

### Risk of the Amended Version

The mechanism table adds weight to a rule that is currently lean (66 lines). This is justified because the carry-forward principle is foundational -- every workspace design decision derives from it (line 28-29). A few extra lines for the mechanism taxonomy prevents downstream ambiguity in hooks, agents, and user decisions.
