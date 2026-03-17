# Intent Approval Evolution: Session eaacf9da

**Session**: 2026-03-15, 22:57-00:22 UTC (85 minutes)
**Plan**: Tool Operations Framework + Incidents Rename (8 batches, 72 files)
**Agent model**: claude-opus-4-6

## Executive Summary

The agent learned a critical lesson during batch 1: sub-agents cannot receive
feedback from the user during execution. When a sub-agent wrote a protected
file without an intent statement, the user could only approve or deny the
tool call -- not explain what was missing. This forced the agent to adopt
a "pre-approve all intents before delegation" pattern that made subsequent
batches dramatically smoother. By batch 5, the agent was presenting 4 intents
in a single consolidated block and getting one-word approvals ("beautiful").

## Timeline

### Phase 1: Batch 1 -- The Learning Moment

**L68 (23:00:59) -- First intent presentation (assistant)**

The agent presents the incidents.json intent and two incident drafts for
approval before delegating. This is the first protected-content checkpoint:

> "Before delegating batch 1, I need your approval on the creative content --
> the rest is mechanical rename."

The incidents.json intent is presented in a code block. Two incident entries
(#26 and #27) are presented in full detail tables. The agent asks about both
the intent quality and whether #27 duplicates #25.

**L73 (23:02:11) -- User gives feedback (user)**

> "im ok with duplicates. the intent looks pretty good but add something
> about not just tracking but also adapting/continuous improvement. it does
> more than just track right?"

The user approves the direction but asks for a refinement to the intent.

**L74 (23:02:17) -- Agent revises (assistant)**

Agent immediately revises the intent's `purpose` field to include "drive
corrective actions" and the full remediation cycle. Asks: "Good to go?"

**L78 (23:02:29) -- User approves (user)**

> "perfect"

**L79 (23:02:44) -- User interrupts (user)**

> "[Request interrupted by user]"

The user interrupted the agent before it started delegating. Something was
wrong.

**L81 (23:03:03) -- User catches a missing audience (user)**

> "hmm actually the audience: programmatic code likes hooks and other things"

The user noticed the audience field omitted programmatic consumers.

**L83 (23:03:10) -- Agent fixes (assistant)**

Agent adds "check scripts, hooks" to the audience. User says "perfect" at L87.

**L91 (23:06:17) -- Batch 1 delegation (assistant)**

The agent delegates batch 1 to a sub-agent. The briefing includes the
*pre-approved* incidents.json intent verbatim. However, the briefing for
`incident-governance.md` says only "Rewrite the file with these changes" --
it does NOT include a pre-drafted intent block. The briefing mentions adding
an `**Intent**:` block is needed but doesn't provide the exact text.

**L128-130 (23:12:41-42) -- The friction point**

The sub-agent is executing (renaming the skill directory). The user sees the
sub-agent's work and queues a message: "its missing its intent" (line 130).
The sub-agent is producing a file without the required intent statement, and
the user cannot communicate this to the running sub-agent.

**L136 (23:12:48) -- User interrupts sub-agent (user)**

> "[Request interrupted by user for tool use]"

**L139-140 (23:12:48) -- User reports the problem (user)**

> "use this guidance as 'carry forward'"
> "its missing its intent"

**L142 (23:13:07) -- Main agent catches it proactively (assistant)**

The main agent (not the sub-agent) realizes the issue and immediately drafts
the missing intent for `incident-governance.md`, matching the style of other
rules. This happened *before* the user's explicit complaint at L146.

**L146 (23:13:15) -- User articulates the UX problem (user)**

> "hey an agent asked for approvaly on an md file. the file was missing an
> intent. i tried to say no tab amend to tell it that but i couldnt"

This is the pivotal UX report: the approval dialog for sub-agent tool calls
only offers approve/deny -- there's no way to send feedback like "no, and
here's why."

**L149 (23:13:37) -- THE PIVOT: Agent articulates the lesson (assistant)**

> "That's the sub-agent interaction limitation -- you can only approve/deny
> tool calls, you can't send feedback back to a running agent. The agent has
> no channel for 'no, but here's why.'"
>
> "This reinforces the approach: **every file that needs an intent must have
> it drafted and approved by you before I delegate**. The sub-agent gets the
> exact content to write, not instructions to figure it out."
>
> "For batch 1 specifically, that means I need to pre-approve intents for:
> - `incidents.json` -- approved above
> - `incident-governance.md` -- just drafted, pending your OK
> - `incident/SKILL.md` -- needs a draft (current gap/SKILL.md has no intent
>   block either)"

This is the explicit codification of the new pattern: pre-draft all intents,
get user approval, then delegate with verbatim content.

**L154 (23:13:37) -- User confirms (user)**

> "yeah"

**L160 (23:15:22) -- User provides additional guidance (user)**

> "follow our intent pattern intent/purpoose audience. also yeah the subagent
> asked about incident-governance.md and you about gap-governance.md so there
> was rename thing in between"

User points out a formatting issue (the bold-label pattern) and a concurrent
rename confusion.

**L162 (23:15:55) -- Agent presents consolidated intent table (assistant)**

The agent presents the SKILL.md intent draft using the correct bold-label
pattern and shows a tracking table:

> | File | Status |
> |------|--------|
> | `incidents.json` (meta.intent) | Approved |
> | `incident-governance.md` (**Intent**: block) | Approved |
> | `incident/SKILL.md` (## Intent section) | ^^^ this draft |

**L167 (23:17:19) -- User approves (user)**

> "lookd hoof" (looks good)

**L213-339 -- Main agent completes batch 1 directly**

After the sub-agent's partial work, the main agent finishes the remaining
batch 1 work itself (intents, cross-reference updates, etc.) rather than
re-delegating.

### Phase 2: Batches 2-4 -- Mechanical Renames (No New Intents)

Batches 2-4 were purely mechanical `gap` -> `incident` renames across rules,
skills, hooks, reference docs, scripts, plans, and cursor rules. No new files
were created, so no new intents were needed. The agent delegated these to
sub-agents with straightforward find-and-replace briefings.

No user interaction was needed during these batches.

### Phase 3: Batch 5 -- The Mature Pattern

**L863 (23:43:01) -- Consolidated intent presentation (assistant)**

The agent presents ALL FOUR intents for the new batch 5 files in a single
message:

> "Now batch 5: Tool-ops framework artifacts. This is the design-intensive
> batch -- 6 new files + 3 updates. I need to draft intents for the new
> files before delegating. Let me draft them."

Then in one block:
1. `.claude/rules/tool-ops.md` (rule) -- full intent in code block
2. `reference/framework-tool-ops.md` (framework reference) -- full intent
3. `reference/tool-ops.json` (registry) -- full JSON intent
4. `.claude/skills/tool-ops/SKILL.md` (skill) -- full intent

Ends with: "Do these look right, or should I adjust before delegating batch 5?"

**L868 (23:48:42) -- One-word approval (user)**

> "beautiful"

No revisions needed. The agent had learned the user's style from batches 1's
back-and-forth -- concise intent structure, correct bold-label formatting,
proper scope/audience conventions.

**Contrast with batch 1**: In batch 1, the intent for incidents.json alone
took 3 rounds of revision (tracking -> tracking+corrective, audience fix,
format fix). In batch 5, 4 intents were approved in a single round with
one word.

### Phase 4: Batch 6 -- Single Intent, Immediate Approval

**L937 (23:53:24) -- Single new intent presented (assistant)**

Only one new file in batch 6 (`tool-ops-claude-code.md`) needed an intent.
The agent presents it along with a scope question about effectiveness.md:

> "**Batch 5 verified.** Before delegating batch 6, here's the intent for
> `tool-ops-claude-code.md`:"

**L942 (23:54:06) -- Approval with minor concern (user)**

> "beautiful. not sure about effectiveness.md but ok"

Approved immediately. The user's reservation was about a scope decision (how
many incidents to migrate), not about the intent quality.

### Phase 5: Batches 7-8 -- No New Intents Needed

Batch 7 (SessionEnd hook) and batch 8 (final verification) did not create
new protected files requiring intent statements. The hook is a shell script
(no intent block needed), and batch 8 was pure verification + cross-ref
updates. The agent delegated both without needing user approval on creative
content.

## What Changed: The Three Adaptations

### 1. Pre-approval before delegation (L149 -- explicit)

The most visible change. After the batch 1 friction, the agent explicitly
committed to drafting all intents before delegation:

> "every file that needs an intent must have it drafted and approved by you
> before I delegate. The sub-agent gets the exact content to write, not
> instructions to figure it out."

This eliminated the UX problem where users can only approve/deny sub-agent
actions without providing feedback.

### 2. Consolidated presentation (L863 -- behavioral)

By batch 5, the agent presented all 4 intents in a single message rather than
one at a time. This reduced the number of approval round-trips from potentially
4+ (if each needed revision) to exactly 1.

### 3. Style calibration (L863 -- implicit)

The agent learned the user's preferences through the batch 1 iterations:
- Bold-label format (`**Purpose**:`, `**Scope**:`, `**Audience**:`)
- Scope uses negative boundaries ("NOT X. NOT Y.")
- Audience includes both agent and programmatic consumers
- Purpose uses active verbs, not just "track"

By batch 5, the drafts matched the user's expectations on the first try.

## Interaction Statistics

| Batch | New intents | Rounds to approve | User response | Time to approve |
|-------|-------------|-------------------|---------------|-----------------|
| 1 | 3 | 3+ (iterative) | "perfect" x2, corrections, "lookd hoof" | ~15 min |
| 2-4 | 0 | 0 | (no interaction needed) | 0 |
| 5 | 4 | 1 | "beautiful" | ~5 min |
| 6 | 1 | 1 | "beautiful" | ~42 sec |
| 7-8 | 0 | 0 | (no interaction needed) | 0 |

## Root Cause of Batch 1 Friction

The plan instructed the agent to "Read the intent-writing skill as reference
for the process" and follow "the source-of-truth review gate: draft the full
content, present for user review, write only after approval." The agent
correctly pre-approved the incidents.json intent but delegated batch 1 before
drafting intents for the other 2 files. The sub-agent then hit the
intent requirement during execution and had no way to get feedback from the
user.

The plan itself contributed to this -- it said "all protected file changes"
needed pre-approval but didn't enumerate which specific files in each batch
would need new intents. The agent had to discover this through the failure.

## Pattern for Future Plans

The session produced a reusable pattern for plans involving sub-agent delegation
of protected file creation:

1. **Enumerate intent-requiring files per batch** in the plan itself
2. **Main agent drafts all intents** before the first delegation
3. **Present as a consolidated batch** for single-round approval
4. **Sub-agent briefing includes verbatim intent text**, not "figure out the intent"
5. **Track approval status** in an explicit table (Approved / Pending / Draft)
