# Verification Lifecycle Gap Audit

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Methodology**: Full-chain failure analysis, cross-boundary verification audit
**Builds on**: `scratch-deletion-rca.md` (same session)

---

## Executive Summary

The /handoff skill was designed, built, deployed, and verified three times
by independent subagents. All three passed it as READY. None caught that:

1. The handoff prompt was written to a scratch directory that the SessionEnd
   hook deletes (`harvest-session.sh` lines 165-166: `rm -rf "$SESSION_DIR"`)
2. The handoff references 22+ scratch files whose paths will change or
   vanish after session end
3. The schwerpunkt-assessment subagent made a false factual claim that
   scratch directories "are NOT automatically cleaned up between sessions"
   (line 162-163) -- and this false claim propagated unchallenged through
   all 5 downstream artifacts

The deeper finding: **the verification workflow has no concept of session
lifecycle transitions.** The /handoff skill exists to bridge sessions, but
it was only tested within a single session. No one simulated "what happens
when this session ends and the next one begins."

This is a class of bug I will call **cross-boundary verification failure**:
testing artifacts that exist across lifecycle boundaries (session end/start,
machine switch, deploy pipeline) without testing the boundary crossing
itself.

---

## 1. Every Missed Catch Point

### 1.1 The schwerpunkt-assessment subagent (Step 3)

**What it did**: Assessed handoff feasibility. Section 3.2 recommended
referencing scratch paths in the handoff because "The current `.scratch/`
session directories are NOT automatically cleaned up between sessions --
they persist on disk" (line 162-163). The risk register (section 8) rated
"Scratch directory cleaned up before next session reads it" as **Low
probability** (line 457).

**What it should have done**: Read `harvest-session.sh` (4 hops from the
/scratch skill cross-reference) to verify the claim about scratch
persistence. Lines 165-166 are unambiguous: `rm -rf "$SESSION_DIR"` and
`rm -f "$SCRATCH_DIR/.current-session"`.

**Why it failed**: The S2 subagent was delegated without scratch lifecycle
facts in its prompt. It had access to files on disk but was not told to
verify scratch persistence against the hook code. It made an inference
("scratch is gitignored, so it persists") rather than verifying against
the implementation.

**What existed that could have caught it**:
- `/scratch` skill, lines 108-110: "The SessionEnd hook
  (`harvest-session.sh`) classifies contents and handles both -- deleting
  ephemeral files and harvesting artifacts."
- `.claude/rules/aitools-workspace.md`, line 26: "Session-ephemeral data
  (scratch files, in-flight channel messages) is gitignored -- it belongs
  to one session on one machine."
- `.claude/rules/artifact-harvesting.md`, lines 65-66: "SessionEnd hook:
  classify `.scratch/` contents, harvest artifacts, delete ephemeral files"

All three say scratch is ephemeral. None say the specific sentence the
subagent needed: "the SessionEnd hook runs `rm -rf` on the entire session
directory." The subagent had the facts but not the connection.

### 1.2 The handoff writer subagent (Step 4)

**What it did**: Wrote the handoff to
`.scratch/session-Z1IhGrcgGO/handoff-prompt-draft.md`. The /handoff
skill's step 4 template says: "Write the handoff to: [HANDOFF_PATH]
(Use the location from the schwerpunkt-assessment, or the existing
handoff path if updating, or [SESSION_DIR]/handoff-prompt-draft.md if no
location was determined)."

**What it should have done**: Used the schwerpunkt-assessment's
recommendation (line 181-190): "Write to
`plans/mission-command-briefing/handoff-prompt.md`". This was the
permanent, tracked location. The assessment recommended it. The S3 writer
used the fallback instead.

**Why it failed**: The S3 subagent may not have read the assessment's
location recommendation closely enough, or treated the scratch path as a
"draft" location that would be moved later. The skill's fallback path
(`[SESSION_DIR]/handoff-prompt-draft.md`) was the path of least
resistance.

**What existed that could have caught it**: The schwerpunkt-assessment
itself. The S3 writer was told to read it. The assessment's section 3.2
prerequisite P3 explicitly says: "RECOMMENDED:
`plans/mission-command-briefing/handoff-prompt.md` (update existing)".

### 1.3 The main agent (orchestrator, between Steps 4 and 5)

**What it did**: After the S3 writer completed, the main agent "verified
the output file exists" and "read the first 30 lines to confirm it has
the expected structure" (skill step 4 post-completion instructions). It
did not move the handoff to a permanent location.

**What it should have done**: Noticed the handoff was in scratch (not at
the recommended permanent location) and either moved it or flagged it.
The skill's step 4 says to verify the output file exists but does not say
to verify the output file is in a permanent location.

**Why it failed**: The skill does not require the orchestrator to verify
the handoff location against the assessment's recommendation. The
orchestrator's verification scope is: "does the file exist? does it have
the right structure?" Not: "is the file in a permanent location?"

### 1.4 Verification 1 (`handoff-verification.md`)

**Criterion 2 (Reference Integrity)**: Checked 30+ file paths via `ls`.
Every path resolved. Verdict: PASS.

**What it missed**: Every path was checked for present-state existence,
not future-state survival. The verifier explicitly accepted the
schwerpunkt-assessment's false claim about scratch persistence, citing it
as evidence (line 37-38): "scratch directories persist on disk and the
session-state-audit section 3.2 states scratch is NOT auto-cleaned."

**Criterion 1 (Self-Containment)**: Asked "If scratch files were deleted,
would inlined content suffice?" This was treated as a hypothetical
thought experiment, not as a factual prediction. The verifier answered
"yes for Wave 1 items 1-3" and noted scratch "persists on disk."

**Criterion 9 (Barrier Test)**: Simulated a fresh agent reading the
handoff and attempting Wave 1. The simulation started at "agent opens
the handoff file" -- not at "new session begins, hooks fire, scratch
is deleted."

**What existed that could have caught it**: The verifier was given 9
criteria. None ask about post-session file survival. The verifier
executed the criteria faithfully. The criteria themselves are the gap.

### 1.5 Verification 2 (`handoff-final-verification.md`)

**Same gaps as Verification 1.** Additionally invoked `/tool-ops` skill
and read `tool-ops.json` and `tool-ops-claude-code.md`. Cross-checked
CC operational claims. Verified hook counts ("1 of 9 hooks has tool-ops
verification specs").

**What it missed**: Tool-ops.json documents only one hook
(`block-claude-code-guide.sh`). The other 8 hooks, including
`harvest-session.sh`, are not in tool-ops. The verifier verified the
count was accurate but did not read the undocumented hooks to understand
their behavior. It verified the known world without questioning the
unknown.

Explicitly stated (line 28-29): "scratch persists on disk." The false
claim was propagated as verified fact for a second time.

### 1.6 Verification 3 (`handoff-final-verification-v2.md`)

**Same gaps as Verifications 1 and 2.** This verifier again invoked
`/tool-ops` and verified new content (D.8 additions). It verified that
"1 of 9 hooks has verification specs" and accepted this as a neutral
fact rather than an alarm signal. Eight hooks have no verification
specs. One of those eight is the hook that would destroy the handoff.

**What it missed**: Same as before, plus: the verifier was the third
independent agent to certify READY without reading `harvest-session.sh`.
The word "independent" is misleading -- all three verifiers inherited
the same criteria, the same false premise from the schwerpunkt-assessment,
and the same tool-ops documentation that omits 8 of 9 hooks.

### 1.7 The /handoff skill design (prevention layer)

**What exists**: The skill's prerequisites section (lines 56-65) says:
"note that the SessionEnd hook will handle artifact harvesting -- the
handoff does not need to wait for it." This acknowledges the SessionEnd
hook but frames it positively ("it handles harvesting for you"), not as
a threat ("it will delete the scratch directory"). The skill's step 4
has a fallback path pointing to scratch. The skill's verification
criteria have no lifecycle awareness.

**What should exist**: The skill should contain an explicit rule: "The
handoff MUST be written to a permanent (tracked) location -- never to
session scratch." The verification criteria should include: "Will
referenced files survive the SessionEnd hook?"

### 1.8 The /scratch skill (prevention layer)

**What exists**: The scratch skill documents that files are "Ephemeral
(deleted at session end)" (line 97) and that "The SessionEnd hook
(`harvest-session.sh`) classifies contents and handles both -- deleting
ephemeral files and harvesting artifacts" (lines 108-110).

**What is missing**: No explicit warning says "the session directory
itself is `rm -rf`'d." The skill says files are "deleted" but does not
say the directory is removed entirely. An agent could read "deleting
ephemeral files and harvesting artifacts" as: ephemeral files are
deleted, artifacts are moved, but the directory and any remaining files
persist. This is wrong -- `harvest-session.sh` lines 165-166 delete the
entire directory unconditionally after processing.

### 1.9 The tool-ops registry (detection layer)

**What exists**: Tool-ops.json documents one hook
(`block-claude-code-guide.sh`) out of 9. It has no entries for
`harvest-session.sh`, `session-archive.sh`, or `scratch-init.sh`. The
verification spec pattern (`mock-json-pipe`) tests individual hooks in
isolation.

**What is missing**: No documentation of what `harvest-session.sh` does
to the filesystem. No lifecycle sequence testing. No concept of hook
interaction testing.

### 1.10 The SessionEnd hook ordering (no catch point exists)

`session-archive.sh` and `harvest-session.sh` both fire on SessionEnd.
There is no documented ordering guarantee. `session-archive.sh` copies
the transcript to the user repo (it does not touch scratch).
`harvest-session.sh` harvests scratch files and then deletes the session
directory. If `session-archive.sh` ran after `harvest-session.sh`, it
would still work (it reads the transcript from CC's storage, not from
scratch).

But the handoff prompt -- if it were in scratch -- would be harvested
(copied to `harvesting/` with a date prefix) and then the original
deleted. The path in the handoff's own metadata would be wrong. The
path every verifier checked would be broken.

**No catch point exists** because: no hook checks whether files in
scratch are referenced by other committed artifacts. The SessionEnd
lifecycle is a one-way operation with no pre-flight validation.

---

## 2. The Simulation Gap

### Why session transition testing was never considered

The /handoff skill bridges two sessions. Its entire purpose is to
produce an artifact that survives from Session N to Session N+1. But it
was only tested within Session N.

The verification (step 5) used a worktree for isolation. This simulated
a "fresh agent" -- an agent with no conversation history reading the
handoff for the first time. But a worktree does not simulate a fresh
SESSION. A fresh session has:

1. **SessionEnd hooks fire** (on the ending session): `harvest-session.sh`
   classifies, harvests, and deletes scratch. `session-archive.sh`
   archives the transcript.
2. **Time passes**: The user closes the terminal, switches machines,
   sleeps, or does nothing.
3. **SessionStart hooks fire** (on the new session): `scratch-init.sh`
   creates a new session directory and cleans up stale session dirs
   older than 24 hours.

The worktree simulation tested step 3 (a fresh agent reading the
handoff) without testing steps 1-2 (the state changes that happen
before the fresh agent exists). The simulation assumed the filesystem
is static between sessions. It is not.

### Why this assumption was natural

The /handoff skill's design process focused on the CONTENT of the
handoff (is it self-contained? are decisions clear? are exclusions
specific?) not on the ENVIRONMENT in which the handoff will be consumed.
The 9 criteria verify the handoff as a document -- a text artifact. They
do not verify it as a participant in a system with lifecycle events.

This is because the handoff was modeled after a human-to-human briefing:
write it, verify it, hand it over. In a human-to-human handoff, the
briefing document does not self-destruct between the sender writing it
and the recipient reading it. The skill's designers did not consider
that the digital equivalent of "hand it over" involves automated
processes (hooks) that modify the filesystem.

### What would session transition simulation look like?

A minimal simulation:

1. **Before verification**: Run `harvest-session.sh`'s classification
   logic (not the actual deletion) against the handoff's directory.
   Report: which files would be classified as ephemeral? Which as
   artifacts? Which would be harvested to `harvesting/`? What would the
   new paths be?

2. **After classification**: Verify that the handoff itself would NOT be
   deleted (it's a `.md` file, so it would be classified as an artifact
   and harvested -- but its path would change from
   `.scratch/session-XXX/handoff-prompt-draft.md` to
   `harvesting/2026-03-18_handoff-prompt-draft.md`).

3. **Path integrity check**: For every path referenced in the handoff,
   determine the post-SessionEnd path. If a referenced file would move
   to `harvesting/`, the reference would need to be updated. If it would
   be deleted (ephemeral), the inlined content in the handoff must suffice.

4. **SessionStart simulation**: Run `scratch-init.sh`'s stale-dir cleanup
   logic. Would any referenced directories be cleaned up? (The 24-hour
   threshold means dirs older than 24h are deleted -- if the next session
   starts more than 24h later, even non-deleted session dirs would be
   cleaned up.)

---

## 3. The /tool-ops Gap

### Why hook sequence testing does not exist

Tool-ops.json has a verification spec for one hook. The verification
pattern (`mock-json-pipe`) tests a single hook in isolation: pipe JSON
to stdin, check exit code and stdout. This is unit testing for hooks.

No concept of integration testing exists:
- No test verifies what happens when `harvest-session.sh` and
  `session-archive.sh` both fire on the same SessionEnd event
- No test verifies what happens when `scratch-init.sh` fires on
  SessionStart after `harvest-session.sh` fired on SessionEnd
- No test verifies what filesystem state exists between SessionEnd
  and SessionStart

The handoff problem is a sequence issue: `harvest-session.sh` fires
AFTER the handoff is written but BEFORE the next session reads it.
Individual hook tests cannot catch sequence bugs because they test
each hook in isolation from the lifecycle it participates in.

### Should tool-ops have lifecycle sequence tests?

Yes. The harness has 9 hooks that participate in a lifecycle with at
least 4 distinct events (SessionStart, SessionEnd, PreToolUse,
PostToolUse). The hooks modify shared state (the filesystem). Testing
them in isolation is necessary but not sufficient.

### What lifecycle sequence tests would look like

A new verification type in tool-ops.json:

```json
{
  "type": "lifecycle-sequence",
  "target": "SessionEnd-to-SessionStart",
  "setup": {
    "create": [
      ".scratch/session-TEST/handoff-prompt-draft.md",
      ".scratch/session-TEST/investigation.md",
      ".scratch/session-TEST/commit-msg.txt",
      ".scratch/.current-session"
    ]
  },
  "sequence": [
    {
      "hook": "session-archive.sh",
      "event": "SessionEnd",
      "expectEffect": "transcript copied to user repo"
    },
    {
      "hook": "harvest-session.sh",
      "event": "SessionEnd",
      "expectEffect": [
        "commit-msg.txt deleted (ephemeral)",
        "investigation.md copied to harvesting/ with date prefix",
        "handoff-prompt-draft.md copied to harvesting/ with date prefix",
        ".scratch/session-TEST/ deleted",
        ".scratch/.current-session deleted"
      ]
    },
    {
      "hook": "scratch-init.sh",
      "event": "SessionStart",
      "expectEffect": [
        "new .scratch/session-XXXXXXXXXX/ created",
        "new .scratch/.current-session written"
      ]
    }
  ],
  "assertions": [
    "no file referenced by harvesting/2026-*_handoff-prompt-draft.md still points to .scratch/session-TEST/*"
  ]
}
```

This would catch: handoff-in-scratch, path references to deleted dirs,
ordering dependencies between hooks, filesystem assumptions that hold
during the session but not across sessions.

---

## 4. The Delegation Gap

### What should have been injected into subagent prompts

The /handoff skill delegates to S2 (schwerpunkt assessment) and S3
(handoff writer). Neither delegation template includes scratch lifecycle
facts.

**What the S2 delegation should include**:

```
CRITICAL CONTEXT: Session scratch directories are DELETED at session end.
The SessionEnd hook (harvest-session.sh) runs `rm -rf` on the entire
session directory after harvesting qualifying files to `harvesting/`.
Files in scratch will NOT exist when the next session starts. The handoff
MUST be written to a permanent (tracked) location. References to scratch
files will break -- the receiving session will need to read the harvested
copies at `harvesting/YYYY-MM-DD_filename.md` instead.
```

**What the S3 delegation should include**:

```
LOCATION RULE: Never write the handoff to the session scratch directory.
Scratch is deleted by the SessionEnd hook. Write to the location
recommended by the schwerpunkt-assessment, or to the existing handoff
path if updating. If no permanent location was determined, STOP and ask
the user.
```

### Is scratch lifecycle a "critical rule" for delegation?

Yes. The delegation duty says "inject critical rules." Any subagent that
makes a location decision or references file paths must know that scratch
is ephemeral. This is as critical as the subagent context gap itself --
a subagent that writes a cross-session artifact to a session-scoped
location has produced a self-destructing artifact.

### The broader delegation gap

The current delegation duty focuses on operational concerns: identity,
context files, output location, WRITE_BLOCKED signal, foreground for
writers, verify output. It does not include "lifecycle facts about the
output environment." The subagent knows WHERE to write but not WHAT
WILL HAPPEN to what it writes.

This is a category: **environmental lifecycle facts**. Other examples:
- `.aitools/` is currently gitignored (OT-2) -- writing there means the
  file won't be tracked
- `deploy/` is fully generated and reset to HEAD on every pull -- edits
  there are ephemeral
- Harvested files get date-prefixed names that differ from their original
  names -- references to original names will break

Every subagent that writes files should know which directories are
permanent, which are ephemeral, and which are generated.

---

## 5. The Skill Design Gap

### Why the scratch fallback is a design defect

The /handoff skill's step 4 delegation template has this fallback chain:

1. Use the location from the schwerpunkt-assessment
2. Or the existing handoff path if updating
3. Or `[SESSION_DIR]/handoff-prompt-draft.md` if no location was
   determined

Option 3 is the default fallback. Defaults should be SAFE. A default
that destroys the artifact it produces is a design defect.

The reasoning behind option 3 was probably: "if no permanent location
is known, write to scratch as a draft, and the orchestrator or user will
move it later." But the skill does not include a step for "move the
draft to a permanent location." Step 4 writes the handoff. Step 5
verifies it. Step 6 amends it. Step 7 presents it. Step 8 commits it.
Between steps 4 and 5, the orchestrator verifies "the output file
exists" -- but does not check whether it should be moved.

The fallback path and the missing "move to permanent location" step
together form a trap: the handoff is written to scratch, verified in
scratch, amended in scratch, and committed from scratch. At no point
does anyone question whether scratch is the right place. Then the
session ends and the hook deletes it.

### The self-contradiction

The /handoff skill knows about SessionEnd hooks (prerequisites section,
line 63-65). It knows that scratch files are ephemeral (cross-references
section, line 526: "/scratch skill"). It produces an artifact that MUST
survive across sessions. And its default fallback writes that artifact
to an ephemeral location.

This is not a knowledge gap -- the skill has the knowledge. It is a
failure to connect: "I know scratch is ephemeral" + "I know the
handoff must survive" does not produce "therefore I must not write the
handoff to scratch" because the skill treats these as separate concerns
in separate sections.

### The "Project without plans/" adaptation

The skill has an adaptation section (lines 519-521):

> **Project without plans/ directory**:
> - The handoff is written to the scratch directory
> - The user decides where to commit it (if anywhere)

This explicitly endorses writing handoffs to scratch for projects
without a `plans/` directory. This is a design-level endorsement of the
defective pattern, not just a fallback. The adaptation section should
say: "The handoff is written to a permanent location chosen by the user.
Ask the user for a location."

---

## 6. Recommended Additions to /handoff

### 6.1 Step 4 delegation template: Remove scratch fallback (CRITICAL)

Replace the current fallback (already done in the RCA, but confirming
the fix here):

**Current** (lines 278-285):
```
Write the handoff to: [HANDOFF_PATH]
(Use the location from the schwerpunkt-assessment, or the existing
handoff path if updating, or [SESSION_DIR]/handoff-prompt-draft.md
if no location was determined)
```

**Proposed**:
```
Write the handoff to: [HANDOFF_PATH]
(Use the location from the schwerpunkt-assessment, or the existing
handoff path if updating. The handoff MUST be written to a PERMANENT
tracked location -- never to session scratch. Scratch directories are
deleted by the SessionEnd hook (harvest-session.sh lines 165-166).
A handoff in scratch will not survive the session it was created in.
Typical locations: plans/<briefing-name>/handoff-prompt.md or
.aitools/briefings/<name>/handoff-prompt.md)
```

### 6.2 Verification criterion 2: Add lifecycle awareness (CRITICAL)

**Current** (lines 313-316):
```
2. **Reference integrity**: Does every file path referenced in the
   handoff exist on disk? Read each path to verify. Report any broken
   references.
```

**Proposed**:
```
2. **Reference integrity**: Does every file path referenced in the
   handoff exist on disk? Read each path to verify. Report any broken
   references. CRITICAL: also verify that referenced files will SURVIVE
   the session lifecycle. Files in `.scratch/` are deleted by the
   SessionEnd hook (harvest-session.sh). The handoff itself must NOT
   be in scratch. Referenced scratch files will be harvested to
   `harvesting/` with date-prefixed names -- if the handoff references
   scratch paths, note that these paths will change after session end.
```

### 6.3 Verification criterion 9: Add lifecycle simulation (HIGH)

Extend the barrier test to include pre-session lifecycle:

**Add to criterion 9**:
```
   Additionally: simulate the session lifecycle transition. Before the
   fresh agent reads the handoff, the SessionEnd hook fires:
   - harvest-session.sh classifies scratch files, harvests artifacts to
     harvesting/, and deletes the session directory
   - scratch-init.sh creates a new session directory
   Which referenced files will move? Which will be deleted? Can the
   fresh agent still execute Wave 1 after these state changes?
```

### 6.4 Step 3 delegation template: Add scratch lifecycle context (HIGH)

Add to the Lagebeurteilung template under "1.4 Logistics":

```
   - Scratch lifecycle: the session scratch directory will be deleted
     by the SessionEnd hook (harvest-session.sh lines 165-166:
     `rm -rf "$SESSION_DIR"`). Any files the handoff references in
     scratch will either be moved to harvesting/ (with renamed paths)
     or deleted entirely. Factor this into the handoff location
     decision and reference strategy.
```

### 6.5 "Project without plans/" adaptation: Remove scratch endorsement (HIGH)

**Current** (lines 519-521):
```
**Project without plans/ directory**:
- The handoff is written to the scratch directory
- The user decides where to commit it (if anywhere)
```

**Proposed**:
```
**Project without plans/ directory**:
- Ask the user for a permanent location for the handoff
- Suggest: project root, a `docs/` directory, or `.aitools/handoffs/`
- Never write the handoff to the session scratch directory
```

### 6.6 Delegation duty: Add environmental lifecycle injection (MEDIUM)

Add a 7th item to the delegation duty (after item 6 "Verify output
exists"):

```
7. **Environmental lifecycle facts**: When the subagent makes location
   or reference decisions, inject critical facts about the output
   environment:
   - `.scratch/` session directories are deleted at session end
   - `harvesting/` files get date-prefixed names (paths change)
   - `deploy/` is fully generated and reset on pull
   - `.aitools/` may be gitignored (check OT-2 status)
```

---

## 7. Recommended Additions to /tool-ops

### 7.1 Document all 9 hooks in tool-ops.json (HIGH)

Currently: 1 of 9 hooks has a tool-ops entry. The other 8 -- including
both SessionEnd hooks that alter the filesystem -- are undocumented.
Every hook that modifies shared state should have a tool-ops entry with:
- What it does to the filesystem
- What triggers it
- What ordering guarantees exist (or don't)
- What side effects other hooks or artifacts should be aware of

### 7.2 Add lifecycle-sequence verification type (HIGH)

The current `mock-json-pipe` verification type tests individual hooks.
Add a `lifecycle-sequence` type that tests hook chains:

- **Setup**: Create known filesystem state
- **Sequence**: Run hooks in event order
- **Assertions**: Verify filesystem state after the full sequence

Key sequences to test:
- SessionEnd: `session-archive.sh` then `harvest-session.sh`
  (or reverse -- ordering is not guaranteed)
- SessionEnd-to-SessionStart: full lifecycle transition
- PreToolUse chain: multiple PreToolUse hooks on the same event

### 7.3 Add harvest-session.sh entry to tool-ops.json (CRITICAL)

This hook alters the filesystem in a way that affects other artifacts.
It should be documented with:

```json
{
  "event": "SessionEnd",
  "matcher": null,
  "script": "harvest-session.sh",
  "purpose": "Classify scratch contents, harvest artifacts, delete session dir",
  "sideEffects": [
    "Copies non-ephemeral files to harvesting/ with date prefix",
    "Deletes entire session scratch directory (rm -rf)",
    "Removes .scratch/.current-session",
    "Prunes stale entries from harvest-manifest.json"
  ],
  "interactionWarnings": [
    "Files referenced by handoff prompts will move or be deleted",
    "Any artifact in scratch that must be read at a specific path will break"
  ]
}
```

---

## 8. Recommended Additions to /scratch Skill

### 8.1 Add explicit deletion warning (CRITICAL)

After the "Session scratch directory" section, add:

```markdown
### Session-end lifecycle

**WARNING: Session scratch directories are DELETED at session end.**

The SessionEnd hook (`harvest-session.sh`):
1. Classifies each file by extension (ephemeral vs artifact)
2. Copies artifacts to `harvesting/` with a date prefix
   (e.g., `2026-03-18_filename.md`)
3. Deletes the ENTIRE session directory (`rm -rf "$SESSION_DIR"`)
4. Removes `.scratch/.current-session`

**Never write to scratch any artifact that:**
- Must survive to the next session at a known path
- Is referenced by other committed artifacts at its scratch path
- Is a handoff prompt, carry-forward state, or cross-session document

Artifacts copied to `harvesting/` get renamed. References to original
scratch paths will break. The harvested copy's path includes a date
prefix that cannot be predicted in advance.
```

### 8.2 Add lifecycle cross-reference (MEDIUM)

In the cross-references section, add:

```markdown
- Session lifecycle: harvest-session.sh (what happens at session end)
- Stale cleanup: scratch-init.sh (24h cleanup at session start)
```

---

## 9. The Broader Lesson: Cross-Boundary Verification Failure

### The class of bug

This is a **cross-boundary verification failure**: testing an artifact
that exists across a lifecycle boundary without testing the boundary
crossing itself.

The boundary in this case is the session lifecycle transition:
Session N ends -> hooks fire -> filesystem changes -> Session N+1 starts.
The handoff was verified within Session N (does it exist? is it
self-contained? are references valid?) but not across the boundary
(will it still exist? will references still resolve? will the receiving
session find it?).

### Other instances of this class

This pattern appears anywhere artifacts cross lifecycle boundaries:

1. **Machine switch boundary**: The cross-machine carry-forward
   principle says state must survive machine switches. Files tracked in
   git survive. Files not tracked (scratch, local config) do not. Testing
   a carry-forward artifact on one machine does not test whether it
   survives `git pull` on another.

2. **Deploy pipeline boundary**: `deploy/` scripts are generated by
   `build-deploy.sh` and reset to HEAD on every pull. An edit made to a
   deploy script during a session will survive within that session but
   will be lost on the next `aitools` run. Testing the edit within the
   session does not test whether it survives the deploy pipeline.

3. **Hook chain boundary**: A PreToolUse hook may modify a file that a
   PostToolUse hook reads. Testing each hook individually does not test
   the data flow between them.

4. **Harvesting boundary**: A file in `harvesting/` with status
   `harvested` will be auto-pruned after 30 days if it has zero git
   references and is not flagged `keep`. Testing the file's existence
   today does not test whether it will exist in 31 days.

5. **Config deployment boundary**: A change to `shared/claude-shared.md`
   propagates to `~/.claude/CLAUDE.md` on the next `aitools` run. Testing
   the change in the repo does not test whether the deployed copy matches.

### The root pattern

In every case:
- An artifact is created in Environment A
- It is verified in Environment A (the verification passes)
- A lifecycle event transforms Environment A into Environment B
- The artifact fails in Environment B

The verification is correct within its scope. The scope does not include
the lifecycle transformation. The failure is not in the verification
EXECUTION but in the verification SCOPE.

### Why this is hard to catch

Cross-boundary verification requires the verifier to:
1. Know that a lifecycle boundary exists
2. Know what the boundary transformation does
3. Know which artifacts cross the boundary
4. Test those artifacts against the transformed state

Step 1 is the hardest. If you don't know a boundary exists, you can't
test across it. The handoff verifiers did not think of the SessionEnd
hook as a "boundary" because the hook fires automatically, silently, and
after the verification is already complete. The hook is invisible from
the verification's perspective.

This is the bootstrap problem applied to verification: **a verification
process cannot verify what it does not know exists.** The 9 criteria
were comprehensive within their model of reality. Their model of reality
did not include the SessionEnd hook as a state-altering event.

### The fundamental asymmetry

There is a fundamental asymmetry between creating and consuming:

- **Creating** happens within a session: the agent has full context,
  full filesystem access, all tools available
- **Consuming** happens in a different session: different context,
  potentially different filesystem state, different machine

Verification happens at creation time, not consumption time. It
verifies the artifact in the creation environment. But the artifact
will be consumed in a different environment. The gap between the two
environments is where cross-boundary bugs live.

### The fix at the framework level

The harness needs a concept of **boundary-aware verification**: for any
artifact that crosses a lifecycle boundary, verification must include
testing against the post-boundary state.

This means:
- Identifying all lifecycle boundaries (session end/start, machine
  switch, deploy pipeline, pruning, config deployment)
- For each boundary: documenting what state changes occur
- For each artifact that crosses a boundary: testing whether it survives
  the state changes

The /handoff skill fix (adding lifecycle simulation to criterion 2 and 9)
is a local fix for this specific case. The broader fix is a framework
concept: every verification process that validates cross-boundary
artifacts must include a "boundary simulation" step.

---

## 10. The False-Claim Propagation Chain

### How the false claim entered the assessment

The schwerpunkt-assessment S2 subagent wrote (section 3.2, line 162-163):

> "The current `.scratch/` session directories are NOT automatically
> cleaned up between sessions -- they persist on disk."

And in the risk register (line 457):

> "Scratch directory cleaned up before next session reads it | Low"

This claim is factually false. `harvest-session.sh` lines 165-166:
```bash
rm -rf "$SESSION_DIR"
rm -f "$SCRATCH_DIR/.current-session"
```

**How the false claim was generated**: The S2 subagent likely:
1. Knew that `.scratch/` is gitignored (true)
2. Inferred that gitignored files persist on disk between sessions (partially true -- the `.scratch/` directory itself persists, but session subdirectories are deleted by the hook)
3. Did NOT read `harvest-session.sh` to verify this inference
4. Stated the inference as fact

**How the false claim propagated**:

| Step | Agent | What it did | Citation |
|------|-------|-------------|----------|
| 1 | S2 (schwerpunkt) | Generated the false claim | line 162-163 |
| 2 | S3 (handoff writer) | Repeated it | handoff-prompt-draft.md line 19: "persist on disk (gitignored but not auto-cleaned)" |
| 3 | Verifier 1 | Cited it as evidence for PASS | handoff-verification.md lines 37-38 |
| 4 | Verifier 2 | Repeated it as verified fact | handoff-final-verification.md line 29 |
| 5 | Verifier 3 | Did not repeat but did not challenge | handoff-final-verification-v2.md (silent acceptance) |

**Why nobody challenged it**: Each agent trusted the prior agent's
assertion. The verifiers' mandate was to verify the HANDOFF against
the SESSION STATE AUDIT and SCHWERPUNKT ASSESSMENT -- not to verify
the assessment's factual claims against source code. The verification
chain had no step that said "verify the assessment's environmental
claims by reading the actual hook code."

This is a **trust chain failure**: in a multi-agent workflow, each
agent trusts the prior agent's work product. If the first agent makes
a false factual claim, subsequent agents inherit it as context and
build on it. Independence requires independent verification of factual
claims, not just independent evaluation of quality criteria.

---

## Summary of Findings

### Catch points (10 missed)

| # | Catch point | Agent/Layer | Why it missed |
|---|-------------|-------------|---------------|
| 1 | S2 schwerpunkt assessment | S2 subagent | Made false claim about scratch persistence without reading hook code |
| 2 | S3 handoff writer location choice | S3 subagent | Used scratch fallback instead of assessment's recommended permanent location |
| 3 | Main agent post-Step-4 verification | Orchestrator | Checked file existence, not file location permanence |
| 4 | Verification 1, criterion 2 | Verifier 1 | Point-in-time file check, no lifecycle awareness |
| 5 | Verification 1, criterion 9 | Verifier 1 | Simulated fresh agent, not fresh session with hooks |
| 6 | Verification 2, criterion 2 | Verifier 2 | Same gap, propagated false claim as verified fact |
| 7 | Verification 2, criterion 7 (tool-ops) | Verifier 2 | tool-ops omits 8 of 9 hooks; checked known world only |
| 8 | Verification 3, criterion 2 | Verifier 3 | Same gap; third "independent" verifier with same blind spot |
| 9 | /handoff skill design (fallback path) | Prevention layer | Default fallback points to ephemeral location |
| 10 | /scratch skill documentation | Prevention layer | Documents ephemerality but not the specific `rm -rf` |

### Root causes (4 layers)

| Layer | Root cause |
|-------|-----------|
| Knowledge gap (proximate) | S2 subagent believed scratch persists; false claim never challenged |
| Verification gap (enabling) | 9 criteria verify present state, not post-lifecycle state |
| Skill gap (structural) | /handoff skill defaults handoff to scratch; a cross-session artifact in a session-scoped location |
| System gap (systemic) | No concept of boundary-aware verification; no lifecycle sequence testing in tool-ops |

### Recommended changes

| # | Change | Severity | Target |
|---|--------|----------|--------|
| 1 | Remove scratch fallback from /handoff step 4 | CRITICAL | SKILL.md |
| 2 | Add lifecycle awareness to verification criterion 2 | CRITICAL | SKILL.md |
| 3 | Add deletion warning to /scratch skill | CRITICAL | SKILL.md |
| 4 | Document harvest-session.sh in tool-ops.json | CRITICAL | tool-ops.json |
| 5 | Add lifecycle simulation to verification criterion 9 | HIGH | SKILL.md |
| 6 | Add scratch lifecycle to step 3 delegation template | HIGH | SKILL.md |
| 7 | Fix "project without plans/" adaptation | HIGH | SKILL.md |
| 8 | Document all 9 hooks in tool-ops.json | HIGH | tool-ops.json |
| 9 | Add lifecycle-sequence verification type | HIGH | tool-ops.json |
| 10 | Add environmental lifecycle facts to delegation duty | MEDIUM | SKILL.md |
| 11 | Add lifecycle cross-references to /scratch skill | MEDIUM | SKILL.md |

### The broader lesson

This is a **cross-boundary verification failure**. The /handoff skill
produces an artifact that crosses a lifecycle boundary (session end/start).
The verification was comprehensive within the session but blind to the
boundary crossing. The fix is not just to patch the /handoff skill -- it
is to establish **boundary-aware verification** as a harness concept:
for any artifact that crosses a lifecycle boundary, verification must
include testing against the post-boundary state.

The class includes: session transitions, machine switches, deploy
pipelines, pruning cycles, and config deployments. Each boundary has
state-altering events. Each event can invalidate assumptions that hold
on one side of the boundary. Testing within a boundary is necessary
but not sufficient. The boundary crossing itself must be tested.

---

## Appendix: The Existing RCA

The `scratch-deletion-rca.md` in this session directory provides:
- 5 Whys analysis (consistent with this audit)
- Swiss Cheese analysis (consistent -- same three-layer gap)
- Barrier analysis with 4 options (A: remove fallback, B: add lifecycle
  criterion, C: add scratch warning, D: add hook detection)
- Recommended combination: A + B + C

This audit extends the RCA with:
- All 10 missed catch points (RCA identified 5)
- The simulation gap analysis (new)
- The tool-ops gap analysis (new)
- The delegation gap analysis (new)
- The skill design gap analysis (deeper than RCA)
- The broader cross-boundary verification failure class (new)
- Specific recommended changes with severity ratings (new)
- The false-claim propagation chain analysis (deeper than RCA)
