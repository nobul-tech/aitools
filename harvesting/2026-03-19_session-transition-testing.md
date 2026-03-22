# Should /handoff include session lifecycle transition simulation?

**Date**: 2026-03-18
**Question**: Should the /handoff skill verify that the handoff survives the SessionEnd -> SessionStart lifecycle?
**Trigger incident**: Handoff prompt written to scratch, verified 3x as READY, would have been deleted by SessionEnd hook. User caught it.

---

## 1. Lifecycle Sequence Analysis

### What happens at session end (in order)

Claude Code fires all `SessionEnd` hooks. Per `setup-user-hooks.sh` lines 301-309, three hooks are registered:

| Order | Hook | What it does |
|-------|------|--------------|
| 1 | `session-archive.sh` | Copies transcript `.jsonl` to dotprofile repo (`sessions/<project>/`). Reads `config.json` for `userRepoPath`. No scratch interaction. |
| 2 | `harvest-session.sh` | Reads `.scratch/.current-session` to find session dir. Classifies every file by extension. Moves non-ephemeral files to `harvesting/` with date prefix. **Deletes the entire session directory** (line 165: `rm -rf "$SESSION_DIR"`). Clears `.current-session` marker (line 166). |
| 3 | `tool-ops-session-audit.sh` | Runs mock-json-pipe contract tests against deployed hook scripts. Writes to `~/.claude/hooks/logs/tool-ops-audit.jsonl`. No scratch interaction. |

### What happens at session start

One `SessionStart` hook:

| Hook | What it does |
|------|--------------|
| `scratch-init.sh` | Creates `.scratch/` if missing. Prunes session dirs older than 24h. Creates fresh `session-XXXXXXXXXX` via `mktemp`. Writes path to `.current-session`. Outputs path to agent as context. |

### The critical sequence for handoff survival

```
Session N (current):
  Agent writes handoff to [LOCATION]
  Agent verifies handoff exists at [LOCATION]     -- PASS (file exists NOW)
  Session ends

SessionEnd hooks fire:
  1. session-archive.sh  -- transcript archived (irrelevant to handoff)
  2. harvest-session.sh  -- IF [LOCATION] is in session dir:
     - .md files matching *log*|*output*|*dump* -> DELETED (ephemeral)
     - .md files NOT matching those patterns -> MOVED to harvesting/
       as YYYY-MM-DD_filename.md (renamed!)
     - Session dir deleted (rm -rf)
  3. tool-ops-session-audit.sh  -- irrelevant to handoff

Session N+1 starts:
  scratch-init.sh creates new session dir
  Agent reads handoff from [LOCATION]             -- FAIL if location was session dir
```

### Classification rules for handoff files (harvest-session.sh lines 64-94)

A file named `handoff-prompt.md` would be classified as:
- Extension `.md` -> check name patterns
- Does NOT match `*log*|*output*|*dump*` -> **non-ephemeral**
- **Result: MOVED to `harvesting/YYYY-MM-DD_handoff-prompt.md`**

So a handoff in scratch would NOT be deleted -- it would be **moved and renamed**. But the handoff's own internal references to scratch paths WOULD break, and the receiving agent would be told "read plans/X/handoff-prompt.md" but the file would actually be at `harvesting/2026-03-18_handoff-prompt.md`.

This is arguably WORSE than deletion -- the handoff exists but is mislocated, its references are broken, and the receiving agent can't find it at the documented path.

---

## 2. Five Options with Barrier Analysis

### Option A: Dry-run the SessionEnd hook

**Mechanism**: Add `--dry-run` mode to `harvest-session.sh`. In /handoff step 5 (verification), invoke `harvest-session.sh --dry-run` against the handoff's file paths to see what would happen.

**Catches the specific bug?** Yes. Dry-run would report "handoff-prompt.md would be MOVED to harvesting/".

**Catches the class of bugs?** Yes, for any file in scratch. But only tests the harvest hook, not other SessionEnd hooks.

**Complexity**: Medium. Requires modifying a production hook to support a new mode. The hook currently reads stdin JSON -- dry-run would need a different invocation path.

**Fragility**: Low. Testing the actual hook means the test stays in sync with the hook's behavior.

**Follows existing patterns?** No. No hook currently has a dry-run mode. The tool-ops verification pattern uses mock-json-pipe (pipe synthetic input, check output) but for PreToolUse hooks, not SessionEnd.

**Barrier analysis**:
- (+) Tests the real classification logic -- no drift possible
- (+) Could be reused by other tools that need lifecycle pre-flight
- (-) Modifying a hook that "must never break Claude Code" adds risk
- (-) Dry-run mode is dead code in production -- only used by /handoff
- (-) Hook runs as a separate process -- no way to pass "test these specific files" without protocol change

### Option B: Simulate classification in the verifier

**Mechanism**: The step 5 verifier subagent reads `harvest-session.sh`'s classification rules (the case statement at lines 64-94) and applies them to each file path in the handoff.

**Catches the specific bug?** Yes. Simulation would flag ".md in session dir -> would be harvested and renamed."

**Catches the class of bugs?** Partially. Only catches what the simulation implements. If the hook adds new classification rules, the simulation drifts.

**Complexity**: Low-Medium. The verifier subagent already reads files for reference integrity. Adding "also read harvest-session.sh and apply its case logic" is conceptually simple but requires the subagent to parse bash case statements.

**Fragility**: HIGH. The classification logic is duplicated. When harvest-session.sh changes (new file types, new patterns, new behavior), the simulation must be updated independently. This is the classic "two sources of truth" failure.

**Follows existing patterns?** No. The harness explicitly avoids logic duplication.

**Barrier analysis**:
- (+) No production code changes
- (+) Self-contained in the skill
- (-) FATAL: duplicates classification logic. Two sources of truth is an ambiguity by definition (design principle: "ambiguity is a defect")
- (-) AI subagent parsing bash case statements is unreliable
- (-) Will silently give wrong answers when the hook changes

### Option C: Add "lifecycle survival" as a verification criterion

**Mechanism**: Add criterion 10 to the verifier: "For each referenced file path, determine: (a) is it in `.scratch/session-*`? (b) if yes, will it survive SessionEnd? (c) is the handoff itself in a permanent location?" This is a static location check, not a behavioral simulation.

**Catches the specific bug?** Yes. The check "is the handoff in `.scratch/session-*`?" immediately flags it.

**Catches the class of bugs?** Partially. Catches "file is in an ephemeral location" but not "file will be renamed by harvesting" or "file references depend on exact paths that will change."

**Complexity**: Low. It's a path-prefix check. No production code changes. No hook modification.

**Fragility**: Low. The rule "scratch session dirs are ephemeral" is architectural, not implementation detail. It's unlikely to change.

**Follows existing patterns?** Yes. The existing criterion 2 (reference integrity) already checks file existence. This extends it to check file persistence. The handoff SKILL.md already has the warning at lines 281-285: "The handoff MUST be written to a PERMANENT tracked location -- never to session scratch."

**Barrier analysis**:
- (+) Minimal change -- extends an existing verification criterion
- (+) The rule it enforces is already documented in the skill (lines 281-285)
- (+) No drift risk -- checks location, not behavior
- (+) Catches the most common failure mode (wrote to scratch)
- (-) Doesn't catch renamed-reference bugs (harvested file at different path)
- (-) Doesn't catch cross-session reference breakage in general

### Option D: Full lifecycle simulation in worktree

**Mechanism**: Launch a subagent in a worktree that runs the full SessionEnd hook sequence with mock input, then checks which files survived and which were moved/deleted, then runs SessionStart, then reads the handoff and verifies all references.

**Catches the specific bug?** Yes.

**Catches the class of bugs?** Yes -- most thorough option.

**Complexity**: Very high. Requires worktree setup, mock JSON construction, hook execution in isolation, file-state comparison, cleanup. The hooks read from stdin and expect specific JSON schemas. The harvest hook uses `node` for manifest updates. The archive hook reads `~/.aitools/config.json`.

**Fragility**: High. Any change to hook input schemas, hook dependencies, or execution environment breaks the simulation. The simulation environment is different from the real hook environment (different stdin, different cwd, different env vars).

**Follows existing patterns?** Partially. The tool-ops verification pattern uses mock-json-pipe, but for simple stdin->stdout hooks, not for hooks that modify the filesystem. Worktree-based testing exists in the harness but for code verification, not lifecycle simulation.

**Barrier analysis**:
- (+) Most thorough -- tests the actual hooks
- (+) Would catch any future hook that touches session files
- (-) VERY complex -- essentially building a test harness for the hook pipeline
- (-) Hooks have side effects (file moves, deletes, git operations) -- running them for real in a worktree is dangerous
- (-) Mock environment will never perfectly match real hook execution environment
- (-) Cost: 30+ seconds of subagent time, worktree creation, cleanup
- (-) Over-engineered for the actual failure mode

### Option E: Tool-ops lifecycle sequence test

**Mechanism**: Add a new verification type to `tool-ops.json`: `"lifecycle-sequence"`. Define the SessionEnd sequence with what each hook reads, writes, and deletes. The test verifies: after the full sequence, do specified files still exist?

**Catches the specific bug?** Depends on implementation. If it maps file paths to hook effects, yes.

**Catches the class of bugs?** Potentially. Generalizes to any artifact that must survive session boundaries.

**Complexity**: High. Requires extending the tool-ops verification framework with a new type. The existing `mock-json-pipe` type is simple (pipe input, check output). `lifecycle-sequence` would need to model file operations, ordering, and state.

**Fragility**: Medium. The sequence definition must be updated when hooks are added, removed, or modified. But it's a single source of truth (the tool-ops registry), not a duplication.

**Follows existing patterns?** Partially. Extends the existing tool-ops verification pattern. But `mock-json-pipe` is behavioral (test the hook's I/O contract). `lifecycle-sequence` is architectural (model the state machine). These are different concerns.

**Barrier analysis**:
- (+) Generalizable -- any cross-boundary artifact can use this
- (+) Lives in tool-ops.json -- governed data with a skill gate
- (+) Could power a pre-session-end check for any tool, not just /handoff
- (-) High complexity for a problem that has a simpler solution (Option C)
- (-) Modeling file operations in JSON is error-prone
- (-) The sequence model must stay in sync with the actual hooks -- another drift surface
- (-) Premature generalization: we have ONE known failure. Building a framework for a class of failures we haven't seen yet is speculative.

---

## 3. Recommendation: Option C (with a targeted enhancement)

### Why Option C

The root cause of the incident was not that the verification failed to simulate the lifecycle. The root cause was simpler: **the handoff was written to an ephemeral location despite explicit instructions not to**.

The SKILL.md already says (lines 281-285):
> The handoff MUST be written to a PERMANENT tracked location -- never to session scratch. Scratch directories are deleted by the SessionEnd hook (harvest-session.sh lines 165-166). A handoff in scratch will not survive the session it was created in.

The verification step already has criterion 2 (reference integrity) that checks file existence. The fix is to strengthen criterion 2 with a lifecycle survival sub-check, not to build a lifecycle simulation engine.

### Why not the others

| Option | Rejection rationale |
|--------|-------------------|
| A (dry-run hook) | Modifies production hooks for a testing concern. The hook's job is to clean up -- adding dry-run mode is scope creep for the hook. |
| B (simulate classification) | Fatal flaw: duplicates classification logic. Two sources of truth. Will drift. |
| D (full simulation) | Over-engineered. The failure mode is "wrote to wrong location" -- a path check catches it. Building a test harness for the entire hook pipeline is disproportionate to the risk. |
| E (tool-ops lifecycle) | Premature generalization. We have one known failure. If we see 3+ cross-boundary artifact failures, THEN build a framework. |

### The enhancement: criterion 2 gets a lifecycle sub-check

Current criterion 2 in the verifier prompt:
> **Reference integrity**: Does every file path referenced in the handoff exist on disk?

Proposed criterion 2 (enhanced):

> **Reference integrity**: Does every file path referenced in the handoff exist on disk? Read each path to verify. Report any broken references. **CRITICAL: also verify that referenced files will SURVIVE the session lifecycle.** Files in `.scratch/` are deleted by the SessionEnd hook (harvest-session.sh). The handoff itself must NOT be in scratch. Referenced scratch files will be harvested to `harvesting/` with date-prefixed names -- if the handoff references scratch paths, note that these paths will change after session end.

Wait -- this is ALREADY in the SKILL.md at lines 323-328 of the existing criterion 2. The skill already has this check. Let me re-read the verification step.

Looking at the SKILL.md step 5, criterion 2 (lines 322-328):

```
2. **Reference integrity**: Does every file path referenced in the
   handoff exist on disk? Read each path to verify. Report any broken
   references. CRITICAL: also verify that referenced files will SURVIVE
   the session lifecycle. Files in `.scratch/` are deleted by the
   SessionEnd hook (harvest-session.sh). The handoff itself must NOT
   be in scratch. Referenced scratch files will be harvested to
   `harvesting/` with date-prefixed names — if the handoff references
   scratch paths, note that these paths will change after session end.
```

**The criterion already exists.** It was added as a fix (presumably after this very incident or a similar one). And step 4 already has the instruction (lines 281-285) telling the writer subagent to put the handoff in a permanent location.

### So the real question becomes: why did the criterion fail?

The existing instructions tell the writer "don't put it in scratch" AND tell the verifier "check that it's not in scratch." Both instructions existed. The handoff still ended up in scratch.

This means the failure mode is NOT "the skill lacks a lifecycle check." The failure mode is one of:

1. **Subagent context gap**: The writer subagent didn't receive or didn't follow the SKILL.md instruction about permanent locations.
2. **Verification subagent ignored the criterion**: The verifier checked existence but skipped the lifecycle survival sub-check.
3. **"READY" verdict despite criterion failure**: The verifier may have flagged it but the main agent didn't act on it.

This changes the recommendation.

### Revised recommendation: Strengthen the enforcement, not the check

The check exists. The problem is enforcement. Three reinforcements:

**R1. Make the location decision EARLIER and EXPLICIT (step 3, not step 4)**

In step 3 (Lagebeurteilung), the assessment already proposes "where should the handoff be written?" But this is buried in section 3 of the assessment. Make it a BLOCKING prerequisite for step 4:

> Before launching the step 4 writer subagent, the main agent MUST:
> 1. Read the schwerpunkt-assessment's proposed location
> 2. Verify the proposed location is NOT in `.scratch/session-*`
> 3. If the proposed location IS in scratch, STOP and ask the user

**R2. Add a pre-flight check BETWEEN step 7 (present to user) and step 8 (commit)**

After the user approves but BEFORE committing, the main agent runs a 30-second pre-flight:

```
Pre-flight for session end:
1. Handoff location: [PATH] -- is it tracked in git? YES/NO
2. Referenced files in scratch: [LIST] -- will they survive? (harvested to harvesting/)
3. SessionEnd hooks will fire: session-archive, harvest-session, tool-ops-audit
4. Harvest-session will: delete session dir, move artifacts to harvesting/
5. Conclusion: handoff will / will NOT survive session end
```

This is not a simulation -- it's a static analysis that the main agent performs. No subagent, no hook execution, no worktree. Just path checks and a summary.

**R3. Add the handoff path to the "present to user" step**

Step 7 already shows "Where the handoff is: file path." Strengthen this to explicitly state whether the path is permanent:

> 1. **Where the handoff is**: `plans/X/handoff-prompt.md` (PERMANENT -- tracked in git)
>    -- or --
>    **Where the handoff is**: `.scratch/session-abc/handoff-prompt.md` (WARNING: EPHEMERAL -- will be moved by SessionEnd hook to `harvesting/2026-03-18_handoff-prompt.md`)

---

## 4. Draft Implementation

### Changes to SKILL.md

**Step 3 addition** (after the schwerpunkt-assessment subagent completes):

```markdown
**After the subagent completes**: Read the assessment. Verify:
- The Schwerpunkt verdict is YES or YES WITH CAVEATS
- The exclusion clauses are specific and justified
- The priority sequence is actionable
- **The proposed handoff location is a PERMANENT tracked path (not in
  `.scratch/session-*`).** If the assessment proposes scratch, override
  it: use the existing handoff path (if updating) or `plans/<name>/handoff-prompt.md`.
  If no permanent location is obvious, ask the user before proceeding.
```

**Step 7 addition** (in the "present to user" summary):

```markdown
Show the user a summary of the handoff:

1. **Where the handoff is**: file path, with persistence status:
   - PERMANENT (tracked in git, will survive session end)
   - EPHEMERAL (in scratch, will be moved/deleted by SessionEnd hook)
   If EPHEMERAL, this is a BLOCKER -- do not proceed to step 8.
   Return to step 4 to rewrite to a permanent location.
```

**New Step 7.5: Session end pre-flight** (between step 7 and step 8):

```markdown
### Step 7.5: Session end pre-flight

Before committing, verify the handoff will survive the session lifecycle:

1. **Handoff location check**: Is the handoff path outside `.scratch/`?
   If YES: PASS. If NO: BLOCKER -- return to step 4.

2. **Reference survival check**: For each file path referenced in the
   handoff, classify:
   - In `.scratch/session-*`: will be moved to `harvesting/YYYY-MM-DD_filename`
     by harvest-session.sh. The handoff's reference will break.
   - In `harvesting/`: will persist (unless auto-pruned after 30 days).
   - In tracked git paths: will persist.
   - Other: flag for review.

3. **Self-healing references**: If the handoff references scratch files
   that contain important content:
   - Option A: Copy the content into the handoff itself (inline it)
   - Option B: Move the file to a permanent location before committing
   - Option C: Note in the handoff that the file will be at
     `harvesting/YYYY-MM-DD_filename` after session end
   Present options to the user.

4. **Summary**: "Handoff at [PATH] will survive session end. N referenced
   files are in permanent locations. M scratch references will be
   harvested to harvesting/." -- or -- "BLOCKER: handoff and/or N
   critical references will not survive session end."

This step takes <30 seconds. It is a static analysis, not a simulation.
The main agent performs it directly (no subagent needed).
```

### No changes to tool-ops.json

This is a /handoff process improvement, not a tool-ops verification concern. If we later see cross-boundary survival as a general problem across multiple tools, THEN it belongs in tool-ops as a `lifecycle-sequence` verification type.

### No changes to harvest-session.sh

The hook does its job correctly. The fix is in the consumer (/handoff) that produces artifacts that must survive the hook's cleanup.

---

## 5. The Broader Pattern: Cross-Boundary Verification

### Where else do artifacts cross lifecycle boundaries?

| Artifact | Boundary crossed | Current protection | Gap? |
|----------|-----------------|-------------------|------|
| **Handoff prompt** | SessionEnd (scratch deleted) | SKILL.md says "permanent location" + verifier criterion 2 | YES -- enforcement weak (this incident) |
| **Harvested artifacts** | SessionEnd (moved from scratch to harvesting/) | harvest-session.sh classification | No -- designed to cross this boundary |
| **Session transcript** | SessionEnd (archived to dotprofile) | session-archive.sh copies it | No -- designed to cross |
| **Running estimate** | SessionEnd -> SessionStart (carry-forward state) | Tracked in git (`.aitools/channel/running-estimate.json`) | No -- in git |
| **Scratch files** | SessionEnd (deliberately deleted) | By design -- ephemeral | No -- deletion is correct behavior |
| **Commit message files** | SessionEnd (in scratch, ephemeral) | Classified as ephemeral by harvest hook | No -- consumed before session end |
| **Planning briefs** | Cross-session (multiple sessions read them) | In `plans/` -- tracked in git | No -- permanent by design |
| **Investigation products** | SessionEnd (written to scratch during investigation) | Harvested by SessionEnd hook; also should be committed if valuable | MAYBE -- depends on whether the agent commits them before session end |
| **Incident reference files** | Cross-session | In `reference/` -- tracked in git | No -- permanent by design |
| **Tool-ops audit log** | SessionEnd (written by hook) | Written to `~/.claude/hooks/logs/` (user-scoped, persistent) | No -- outside session dir |

### The general pattern

Artifacts that must survive session boundaries fall into three categories:

1. **Designed to cross**: harvested artifacts, transcripts, running estimates. These have explicit mechanisms (hooks, git tracking) that move them across the boundary.

2. **Must be committed before the boundary**: handoff prompts, investigation products, decisions. These are the agent's responsibility -- if they're in scratch at session end, they get harvested (renamed, moved) rather than preserved in place.

3. **Deliberately ephemeral**: commit messages, temp files, logs. These are consumed during the session and correctly deleted.

The failure mode is always category 2: an artifact that the agent SHOULD have committed to a permanent location but left in scratch. The fix is always the same: check the location before the boundary fires.

### Should this become a framework?

Not yet. The incident count is 1. The pattern is simple (check path prefixes). The fix is local to /handoff. If we see this pattern emerge in other skills (investigation products left in scratch, channel messages not committed, etc.), THEN generalize into a "cross-boundary survival" framework with:
- A registry of artifacts that must survive each boundary
- A pre-boundary check that verifies each artifact is in a surviving location
- A post-boundary audit that confirms nothing was lost

Until then, the /handoff-specific fix (step 7.5 pre-flight + stronger enforcement in steps 3 and 7) is sufficient.

---

## Summary

| Question | Answer |
|----------|--------|
| Should /handoff simulate the lifecycle? | No. Simulation is over-engineered for this failure mode. |
| What should /handoff do instead? | Three reinforcements: (R1) block on scratch location before writing, (R2) pre-flight check before committing, (R3) explicit persistence status in user presentation. |
| What's the root cause? | The skill already has the right instructions. The failure was enforcement: subagent didn't follow the "permanent location" instruction, and the main agent didn't catch it. |
| Is this a general problem? | Not yet. One incident. Monitor for recurrence in other skills before generalizing. |
| What changes? | SKILL.md steps 3, 7, and new step 7.5. No hook changes. No tool-ops changes. |
