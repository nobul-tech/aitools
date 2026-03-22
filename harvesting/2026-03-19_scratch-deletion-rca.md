# Root Cause Analysis: Handoff Prompt References Scratch Files That Will Be Deleted

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Methodology**: 5 Whys, Swiss Cheese, Barrier Analysis

---

## 1. What Each Verifier Checked and Why It Missed the Issue

### Verification 1 (`handoff-verification.md`)

**Criterion 2 (Reference Integrity)**: Checked 30+ file paths using `ls -la`
or equivalent. Verified every path resolves to a file on disk. Verdict: PASS
with "No broken references found."

**What it missed**: The check was purely point-in-time: "does the file exist
RIGHT NOW?" It never asked: "will the file exist when the next session reads
this handoff?" The verifier had no knowledge of the SessionEnd hook lifecycle.

**Compounding factor**: The verifier's Criterion 1 (Self-Containment) analysis
explicitly RELIED on the false premise that scratch persists. Line 37-38:
"scratch directories persist on disk and the session-state-audit section 3.2
states scratch is NOT auto-cleaned." The verifier accepted the handoff's own
claim as evidence rather than verifying it against the actual hook code.

### Verification 2 (`handoff-final-verification.md`)

**Criterion 2 (Reference Integrity)**: Repeated the same check -- `ls -la`
on all paths. Added new files from amendments (D.7 referenced
`intent-heuristic-findings.md`). Verdict: PASS with "30+ paths verified, 0
broken."

**What it missed**: Same gap as Verification 1. Additionally, line 28-29
explicitly states: "scratch persists on disk" -- the false premise was not
just unchallenged, it was propagated as verified fact.

**Criterion 7 (CC Operational Correctness)**: This was the closest any
verifier got to catching the issue. It cross-checked against tool-ops.json
and tool-ops-claude-code.md. But tool-ops.json only documents one hook
(`block-claude-code-guide.sh`), and tool-ops-claude-code.md item #2
documents the SessionEnd hook API contract (session_id, cwd,
transcript_path on stdin) but says nothing about what the hook DOES with
scratch files. The verifier checked whether CC operational claims in the
handoff were correct -- it never checked whether the SessionEnd hook would
invalidate the handoff's assumptions.

### Verification 3 (`handoff-final-verification-v2.md`)

**Criterion 2 (Reference Integrity)**: Verified 3 new file references
from D.8 additions. Also re-verified all prior references. Verdict: PASS.

**What it missed**: Identical gap. This verifier additionally invoked the
`/tool-ops` skill and read both `tool-ops.json` and
`tool-ops-claude-code.md`. It verified counts ("1 of 9 hooks has tool-ops
verification specs"), verified JSONL message types, and verified D.8
claims. But it never read `harvest-session.sh` to understand what the
SessionEnd hook actually does. The tool-ops entry for claude-code documents
one hook (`block-claude-code-guide.sh`); the other 8 hooks (including
`harvest-session.sh`) are not in tool-ops.json at all.

### Common failure across all three

All three verifiers defined "reference integrity" as: **"Does the file
exist on disk right now?"** None defined it as: **"Will the file exist
when the consuming agent reads this path?"** This is a temporal blindspot
-- the verification checks the present state but the handoff is consumed
in a future state (after SessionEnd fires).

---

## 2. Five Whys

### Why 1: Why wasn't the scratch deletion caught by verification?

Because "reference integrity" (Criterion 2) is defined as "does every file
path referenced in the handoff exist on disk?" (`/handoff` skill, step 5,
criterion 2). It checks present-tense existence. The SessionEnd hook fires
AFTER verification but BEFORE the next session reads the handoff. The
criterion has a temporal gap.

### Why 2: Why didn't the verifiers check post-session file survival?

Because no verification criterion asks about file lifecycle. The 9 criteria
in the `/handoff` skill cover: self-containment, reference integrity (now),
reading order, scope governance, completeness, consistency, CC operational
correctness, ambiguity, and barrier test. None ask: "what happens to
referenced files between sessions?" The verifiers faithfully executed the
criteria they were given.

### Why 3: Why was the handoff written to scratch in the first place?

Because the `/handoff` skill's step 4 delegation template says: "Write the
handoff to: [HANDOFF_PATH] (Use the location from the schwerpunkt-assessment,
or the existing handoff path if updating, or **[SESSION_DIR]/handoff-prompt-draft.md
if no location was determined**)" (SKILL.md lines 278-281). The fallback
path is the session scratch directory. The schwerpunkt-assessment (line 181)
recommended `plans/mission-command-briefing/handoff-prompt.md` as the
permanent location, but the S3 writer used the scratch fallback path and the
handoff was drafted there. The main agent never moved it.

### Why 4: Why doesn't the /handoff skill explicitly warn about scratch ephemerality?

Because the skill's prerequisites section (lines 56-65) says: "note that
the SessionEnd hook will handle artifact harvesting -- the handoff does not
need to wait for it." This acknowledges the SessionEnd hook exists but
frames it positively ("it handles harvesting for you") rather than as a
threat ("it will delete the scratch directory"). The skill does not connect
"SessionEnd hook runs" to "your handoff's scratch references will break."

### Why 5 (Root): Why is session lifecycle knowledge not part of the verification model?

Because the `/handoff` skill was designed with a static verification model.
The 9 criteria verify the handoff as a **document** (is it self-contained?
are references valid? is it complete?) but not as a **system artifact** (how
does it interact with hooks, lifecycle events, and other automated
processes?). The verification model assumes the environment is stable between
verification and consumption. This assumption is wrong -- the SessionEnd
hook is a state-altering event that fires in between.

---

## 3. Swiss Cheese Analysis

### Layer 1: Prevention (Rules in Context)

| Rule/Skill | What it says | Did it prevent? | Why not? |
|------------|-------------|-----------------|----------|
| `/scratch` skill | Lines 97-109: "Ephemeral (deleted at session end)" and "The SessionEnd hook (`harvest-session.sh`) classifies contents and handles both -- deleting ephemeral files and harvesting artifacts" | NO | The skill documents that scratch is ephemeral and that the SessionEnd hook cleans up. But this information was not connected to the handoff location decision. The schwerpunkt-assessment subagent (S2) explicitly contradicted this, stating on line 162-163: "The current `.scratch/` session directories are NOT automatically cleaned up between sessions -- they persist on disk." |
| `aitools-workspace.md` rule | Line 26: "Session-ephemeral data (scratch files, in-flight channel messages) is gitignored -- it belongs to one session on one machine." | NO | The rule clearly states scratch is session-ephemeral. But the S2 subagent either did not read this rule, misinterpreted it, or overrode it with a false belief about the hook behavior. |
| `artifact-harvesting.md` rule | Lines 65-66: "SessionEnd hook: classify `.scratch/` contents, harvest artifacts, delete ephemeral files" | NO | States the hook deletes ephemeral files. Does not explicitly state it also removes the session directory itself. An agent could read this as "deletes individual ephemeral files but leaves the directory." |
| `/handoff` skill | Line 314: "If scratch files were deleted, would the inlined content suffice?" (Criterion 1) | PARTIAL | Criterion 1 asks about scratch deletion as a hypothetical. But this is framed as a self-containment test ("would the handoff still work?"), not as a factual warning ("scratch WILL be deleted"). The verifiers treated this as a thought experiment, not a prediction. |

**Prevention layer verdict**: The documentation exists -- scratch is ephemeral, the SessionEnd hook deletes it. But this knowledge is scattered across 3 artifacts (scratch skill, workspace rule, harvesting rule) and none of them say the specific sentence: "Do not put handoff prompts in scratch because the SessionEnd hook will delete the directory before the next session reads them." The prevention layer had the facts but not the connection.

### Layer 2: Detection (Hooks and Real-Time Checks)

| Detection mechanism | What it does | Did it detect? | Why not? |
|---------------------|-------------|----------------|----------|
| SessionEnd hook (`harvest-session.sh`) | Lines 60-94: classifies files. Lines 80-85: `.md` files classified as non-ephemeral (except `*log*`, `*output*`, `*dump*`). Line 99-113: copies non-ephemeral files to `harvesting/` with date prefix. Lines 165-166: `rm -rf "$SESSION_DIR"` and `rm -f "$SCRATCH_DIR/.current-session"` | N/A | The hook does exactly what it's designed to do. It has no awareness of handoff prompts or their referencing patterns. It treats `handoff-prompt-draft.md` the same as any other `.md` file -- harvest it, then delete the directory. |
| No "handoff in scratch" detection hook exists | -- | N/A | There is no hook that checks whether files in scratch are referenced by other artifacts and warns before deletion. |

**Detection layer verdict**: No detection mechanism exists for this failure mode. The SessionEnd hook is the cause, not a detector. No hook validates that handoff prompts are in permanent locations.

### Layer 3: Audit (Verification and Deep Review)

| Audit mechanism | What it checks | Did it catch? | Why not? |
|-----------------|---------------|---------------|----------|
| Handoff verification (9 criteria) | Criterion 2: file path existence on disk | NO | Point-in-time check. No temporal awareness. |
| Handoff verification (9 criteria) | Criterion 1: "If scratch files were deleted, would inlined content suffice?" | NO | This question was treated as a hypothetical self-containment test, not as a factual lifecycle prediction. Verifier 1 answered: "yes for Wave 1 items 1-3" and noted scratch "persists on disk." Verifier 2 repeated: "scratch persists on disk." Neither recognized that scratch WILL be deleted. |
| Handoff verification (9 criteria) | Criterion 7: CC operational correctness | NO | Checked CC-specific behaviors (write denial, subagent context gap, JSONL types). Did not check hook side-effects on file lifecycle. |
| Handoff verification (9 criteria) | Criterion 9: barrier test (fresh agent simulation) | NO | Simulated a fresh agent reading the handoff and executing Wave 1. Did not simulate what happens before the agent even starts (session lifecycle hooks fire, scratch is deleted). The simulation started from "agent opens the handoff" not from "new session begins." |

**Audit layer verdict**: The audit criteria are comprehensive for document quality but blind to system lifecycle. The 9 criteria verify the handoff as a static document, not as a participant in the session lifecycle.

### Swiss Cheese Summary

All three layers had holes, and the holes aligned:

1. **Prevention**: Scratch ephemerality is documented but not connected to handoff location decisions
2. **Detection**: No hook detects "handoff referencing ephemeral paths"
3. **Audit**: Verification criteria check present-state file existence, not post-lifecycle file survival

The false claim in the schwerpunkt-assessment (line 162-163: "scratch dirs are NOT auto-cleaned") passed through all three layers unchallenged. It was:
- Not contradicted by any rule in the subagent's context (prevention gap)
- Not detected by any hook (detection gap)
- Accepted as fact by three independent verifiers who cited it as evidence (audit gap)

---

## 4. Barrier Analysis

### Option A: /handoff skill specifies a permanent location

The `/handoff` skill's step 4 should mandate that the handoff prompt be
written to a permanent (tracked) location, not to the session scratch
directory. The fallback `[SESSION_DIR]/handoff-prompt-draft.md` should be
removed or replaced with a rule: "If no permanent location is determined,
ask the user."

**Effectiveness**: HIGH. Eliminates the root cause -- the handoff would
never be in scratch to begin with. The schwerpunkt-assessment actually
recommended `plans/mission-command-briefing/handoff-prompt.md` as the
location; the skill's fallback to scratch overrode that recommendation.

**Cost**: LOW. One paragraph change in the skill.

**Residual risk**: Referenced scratch files (investigations, findings) would
still be deleted. But those are Layer 2 (depth reading) -- the handoff itself
would survive and the next session could fall back to the inlined Layer 1
content.

### Option B: Verification criteria include "post-session survival"

Add a 10th criterion or extend criterion 2: "For every file path in the
handoff: will this file exist when the next session starts? Consider
session lifecycle hooks (SessionEnd) that may move, rename, or delete
files."

**Effectiveness**: MEDIUM-HIGH. Would catch this specific failure. But
requires the verifier to have knowledge of session lifecycle hooks, which
is itself a knowledge-distribution problem.

**Cost**: LOW. One criterion addition.

**Residual risk**: Verifier may not know about all lifecycle hooks. The
verification would need to read `harvest-session.sh` and understand its
behavior. This is feasible but adds load.

### Option C: /scratch skill explicitly warns about session-end deletion

The `/scratch` skill should add a prominent warning section:

> **WARNING: Session scratch directories are DELETED at session end.**
> The SessionEnd hook (`harvest-session.sh`) copies non-ephemeral files
> to `harvesting/` and then removes the entire session directory. Never
> write artifacts to scratch that must survive to the next session.
> Handoff prompts, carry-forward state, and any file that the next
> session must read at a specific path MUST be written to a permanent
> (git-tracked) location.

**Effectiveness**: MEDIUM. Depends on agents reading the scratch skill
before making location decisions. The schwerpunkt-assessment subagent
apparently did not read or did not believe the existing documentation
about scratch ephemerality.

**Cost**: VERY LOW. One paragraph.

**Residual risk**: Agents that don't invoke the skill (or whose context
doesn't include it) won't see the warning.

### Option D: A hook detects handoff-like files in scratch and warns

A PreToolUse hook on Write/Edit could check whether the target path is
in `.scratch/` and the filename contains "handoff" or matches a pattern.
If so, emit a warning: "Writing a handoff prompt to scratch. This file
will be deleted at session end. Consider writing to a permanent location."

**Effectiveness**: MEDIUM-HIGH. Would catch this at write time, before
verification even begins.

**Cost**: MEDIUM. Requires a new hook, pattern matching, and testing.

**Residual risk**: Pattern matching may miss handoff-like files with
non-obvious names. Also adds friction for legitimate scratch use of
handoff drafts that will be moved later.

### Recommended combination

**A + B + C** (all three are low-cost, complementary):
- A prevents handoff-in-scratch (root cause elimination)
- B catches any future temporal reference integrity failures (defense in depth)
- C makes scratch ephemerality impossible to miss (knowledge distribution)

D is optional -- useful if the pattern recurs despite A+B+C.

---

## 5. Root Cause Classification

This is **all four** of the suggested categories, layered:

1. **Knowledge gap** (proximate cause): The schwerpunkt-assessment S2
   subagent believed scratch directories persist across sessions. This
   false belief was stated explicitly (line 162-163: "The current
   `.scratch/` session directories are NOT automatically cleaned up
   between sessions -- they persist on disk") and was never challenged.
   Three verifiers propagated this false belief as verified fact.

2. **Verification gap** (enabling cause): The 9-criteria verification model
   defines reference integrity as point-in-time file existence, not
   lifecycle-aware file survival. Even if the verifiers had known about
   the SessionEnd hook, the criteria did not ask them to check for it.

3. **Skill gap** (structural cause): The `/handoff` skill has a fallback
   path that writes the handoff to scratch (`[SESSION_DIR]/handoff-prompt-draft.md`).
   This is a self-contradictory design: the skill produces an artifact
   meant to survive across sessions but stores it in a location designed
   to be destroyed at session end.

4. **Governed-data-access issue** (systemic cause): The scratch lifecycle
   documentation is split across three artifacts (scratch skill, workspace
   rule, harvesting rule). None of them state the critical implication for
   handoff location decisions. The S2 subagent that wrote the
   schwerpunkt-assessment apparently did not have the scratch skill or
   workspace rule in its context, or read them and drew the wrong
   conclusion. The subagent context gap (CC item #5 in tool-ops) means
   subagents don't inherit project rules -- they must be explicitly
   given the relevant context.

**Primary root cause**: The `/handoff` skill's fallback location
(`[SESSION_DIR]/handoff-prompt-draft.md`) places a cross-session artifact
in a session-scoped location. This is a design contradiction in the skill
itself.

**Contributing root cause**: The S2 subagent made a false factual claim
about scratch persistence that was never challenged because no verification
criterion requires reading the SessionEnd hook code.

---

## 6. Recommended Fixes

### Fix 1: /handoff skill -- remove scratch fallback for handoff location (CRITICAL)

In SKILL.md step 4 delegation template, change:

```
Write the handoff to: [HANDOFF_PATH]
(Use the location from the schwerpunkt-assessment, or the existing
handoff path if updating, or [SESSION_DIR]/handoff-prompt-draft.md
if no location was determined)
```

To:

```
Write the handoff to: [HANDOFF_PATH]
(Use the location from the schwerpunkt-assessment, or the existing
handoff path if updating. If no permanent location was determined,
STOP and ask the user. Never write the final handoff to the session
scratch directory -- scratch is deleted at session end by the
SessionEnd hook.)
```

### Fix 2: /handoff skill -- add lifecycle criterion to verification (HIGH)

In SKILL.md step 5, extend criterion 2:

```
2. **Reference integrity**: Does every file path referenced in the
   handoff exist on disk? Read each path to verify. Report any broken
   references. ADDITIONALLY: for each referenced path, determine
   whether the file will survive the session lifecycle. Files in
   .scratch/ session directories will be deleted by the SessionEnd
   hook (harvest-session.sh). If the handoff references scratch paths,
   note which files will be moved to harvesting/ (with date-prefixed
   names at different paths) and which will be deleted entirely.
   Report paths that will break after the session ends.
```

### Fix 3: /scratch skill -- add deletion warning (MEDIUM)

Add a prominent section to the scratch skill after "Session scratch
directory":

```
### Session-end lifecycle

Session scratch directories are DELETED at session end. The SessionEnd
hook (`harvest-session.sh`):
1. Classifies each file (ephemeral vs artifact)
2. Copies artifacts to `harvesting/` with a date prefix
3. Deletes the ENTIRE session directory (`rm -rf`)
4. Removes `.scratch/.current-session`

Never write artifacts to scratch that must survive to the next session
at a known path. Handoff prompts, carry-forward state, and any file
another session must read MUST be written to a permanent (git-tracked)
location.

Note: artifacts copied to `harvesting/` get renamed with a date prefix
(e.g., `2026-03-18_filename.md`). Any references to the original
scratch path will break. References to the harvested path
(`harvesting/YYYY-MM-DD_filename.md`) will work, but the exact date
prefix depends on when the SessionEnd hook runs.
```

### Fix 4: /handoff skill -- add lifecycle awareness to step 3 (MEDIUM)

In SKILL.md step 3 (Lagebeurteilung), add to the delegation template
under "1.4 Logistics":

```
   - Scratch lifecycle: the session scratch directory will be
     deleted by the SessionEnd hook. Any files the handoff references
     in scratch will either be moved to harvesting/ (with renamed
     paths) or deleted entirely. Factor this into the handoff
     location decision and reference strategy.
```

### Fix 5: Subagent context injection for scratch lifecycle (LOW)

When delegating to S2/S3 subagents that make location or reference
decisions, inject the scratch skill's lifecycle section into the
delegation prompt. This addresses the subagent context gap (CC item #5).

---

## 7. Relationship to the Bootstrap Problem

The handoff prompt itself (section H) identifies the "bootstrap problem":
a system cannot fully verify itself and needs at least one external
verification layer. The example given was check-post-push.sh being broken
for 16 days undetected because the check script that validates check
scripts doesn't exist.

This scratch-deletion failure is the SAME pattern applied to verification:

**Bootstrap problem (check scripts)**: The harness has 70+ structural
check steps but zero functional testing. The tester doesn't test itself.

**Bootstrap problem (handoff verification)**: The handoff verification
has 9 criteria but no lifecycle awareness. The verifier doesn't verify
the verification environment.

In both cases, the system operates at one level of abstraction (code
correctness / document completeness) but the failure mode is at a
different level (runtime behavior / system lifecycle). The verification
criteria are self-referentially complete -- they verify everything they
know to verify -- but they don't know what they don't know.

The deeper pattern: **verification blind spots are invisible to the
verification process that has them.** You cannot detect a missing
criterion by checking the existing criteria. This is why the user caught
it and three independent verifiers did not -- the user has knowledge of
the system lifecycle that is not encoded in the verification criteria.

This confirms the bootstrap problem finding and extends it: it is not
just check scripts and functional testing. It applies to any verification
process where the criteria are defined by the same system being verified.
The harness needs external verification layers -- whether that's the user,
a CI pipeline, or a meta-verification process that checks the criteria
themselves against the system's lifecycle model.

### The false-claim propagation chain

The most concerning aspect is not just the missing criterion -- it is the
false factual claim that propagated unchallenged through 5 artifacts:

1. **schwerpunkt-assessment.md** (S2 subagent): "scratch dirs are NOT
   auto-cleaned between sessions" (line 162-163, line 457)
2. **handoff-prompt-draft.md** (S3 subagent): "These files persist on
   disk (gitignored but not auto-cleaned)" (line 19)
3. **handoff-verification.md** (Verifier 1): "scratch directories persist
   on disk and the session-state-audit section 3.2 states scratch is NOT
   auto-cleaned" (lines 37-38)
4. **handoff-final-verification.md** (Verifier 2): "scratch persists on
   disk" (line 29)
5. **handoff-final-verification-v2.md** (Verifier 3): did not repeat the
   claim but also did not challenge it

The S2 subagent made a false factual claim. The S3 subagent repeated it.
Three verifiers cited it as evidence. Nobody read `harvest-session.sh`
lines 165-166 (`rm -rf "$SESSION_DIR"`). The fact was available -- the
scratch skill, workspace rule, and harvesting rule all document scratch
ephemerality. But the specific connection between "scratch is ephemeral"
and "the SessionEnd hook will `rm -rf` the directory" was never traced to
the code.

This is a separate class of failure from the verification gap: it is a
**factual claim that was never verified against source code**, propagated
through a chain of trust where each subsequent agent trusted the prior
agent's claim rather than checking independently. The three "independent"
verifiers were not truly independent -- they all inherited the false
premise from the handoff itself or the schwerpunkt-assessment.

---

## Summary

| Category | Finding |
|----------|---------|
| **Proximate cause** | S2 subagent falsely claimed scratch persists across sessions |
| **Enabling cause** | Verification criterion 2 checks present-state file existence, not lifecycle survival |
| **Structural cause** | /handoff skill defaults handoff to scratch (`[SESSION_DIR]/handoff-prompt-draft.md`) |
| **Systemic cause** | Scratch lifecycle documentation is fragmented; subagents lack rules context |
| **Failed layers** | Prevention (no connected warning), Detection (no hook), Audit (criteria blind to lifecycle) |
| **Recommended fixes** | 5 fixes: skill location mandate, lifecycle criterion, scratch warning, Lagebeurteilung injection, subagent context |
| **Bootstrap connection** | Same pattern as check-script bootstrap problem -- the verifier cannot verify what its criteria don't cover |
