# Delegation Protocol Evolution Report

**Source**: Session transcript `aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl` (1317 lines)
**Session**: Tool-ops planning session, 2026-03-15
**Extracted by**: Delegation Protocol Historian, 2026-03-16

---

## Timeline Overview

The execution protocol emerged organically during the tool-ops plan
writing. It began as instructions for how sub-agents should handle
governed data, then grew through 7 user interventions into a
fully recursive delegation framework with identity, military
doctrine grounding, and harness-specific constraints.

| Approx. Line | Event | Initiator |
|---|---|---|
| L1096-L1101 | User raises governed JSON handling gap in plan | User |
| L1103 | Agent names it "execution protocol" | Agent |
| L1111 | User confirms the name, demands deeper content | User |
| L1115-L1124 | Ambiguity purge (4 passes, "wtf is bootstrap?") | User |
| L1129-L1137 | Known states added (tool-registry, unfiled incidents) | User |
| L1187 | **Delegation duty born** | User |
| L1224 | Military doctrine connection (Mission Command, OPORD/FRAGORD) | Agent |
| L1236 | User demands harness constraint adaptation | User |
| L1242 | 5 harness constraints codified | Agent |
| L1254-L1264 | Delegation becomes recursive and generalized | Agent |
| L1268 | "Include the plan" added (FRAGORD without OPORD) | Agent |
| L1271 | **Identity duty born** | User |
| L1278-L1316 | Final version with addressee framing | Agent |

---

## 1. The Triggering Moment (~L1096-L1103)

### User's exact words (L1096, tool_result rejection message)

> use expcplicit instructions to use skills for json modifications. where we cant use an existing skill to achieve our intent and the executing agent has to modify the json file itself, what should we instruct the agent to do? audit the plan for this (read it line by line) and re-write it from scratch to achieve this goal. ask me any clarifying questions

### User's clarifying answer (L1101, in response to agent's question about bootstrap)

> i kind of want to govern the intent make sure thats clear. i want the executing agent to read this entire plan before making any changes. i want it to audit the most recent conversations for intents we have written together that i was happy and exited about as examples. the more recent the conversation where i confirmed i was happy, the more weight that intent should have. the original intent we wroge in the conversation we wrote is still there. i had some questions on it. i didnt mention this before but i felt it was a bit too verbose. are these instructions clear for how the agent should be launched and how its prompt/instructions should be written?

### Agent's response (L1103) -- naming the concept

> Crystal clear. The plan needs an **execution protocol** section that tells sub-agents exactly how to handle governed data changes -- especially intent writing. And the tool-ops.json intent in the plan is too verbose compared to other governed JSON intents (glossary.json's is one line). Let me trim it and add the protocol.

---

## 2. The Ambiguity Purge (~L1111-L1124)

### User confirms the name, rejects the summary (L1111)

> execution protocl is the write term, but it does more than what you summarized. re-read my prompt and, based on my agreement that execution protocll is what it lacks, respond back to me with a revised message

### User catches undefined term (L1115)

> you used a term there we havent defined. wtf is bootstrap? re-read your last prompt, remove ambiguities from instructions to executing agent, do mutlple passes of this and come back to me before rewriting the plan

### User refines skill invocation (L1122)

> instruction 2 is not quite clear. i dont think our skill is good enough yet. i think my explicit instructions are better. it should look at the skill itself, but it should not invoke it. is that possible? revise and audit the rest of what you just said and print it back out to me before we move forward

The agent did 4 passes of self-audit (L1117), identifying and removing:
- "bootstrap" -- not governed, not defined
- "calibrate verbosity" -- vague
- "more weight" -- undefined mechanism

The result was a clean 4-step protocol (L1124):
1. Read the full plan
2. Intent writing (read skill as reference, do not invoke; use recent approved intents as examples)
3. Governed JSON modifications (skill when available; source-of-truth gate otherwise)
4. All protected file changes (source-of-truth gate)

---

## 3. Known States (~L1129-L1137)

### User demands state documentation (L1129)

> we shouldl note the bad state of tool-registry.md and tool-versions.json and reference our conversation where we cover this as instructions for any and all executing agents, just so they know

### User demands an audit for similar issues (L1135)

> audit our recent conversations and plans for similar types of annotations to the known state. are our current gaps clean or is there stuff out there that we havent documented? (i know we are renaming them, that should also be clear to all agents executing, especially the one renaming it and the one verifying and the main exeucting agent). review what you just said to me and address this points. try to generalize and do some audits and re-print before we continue

This added step 5 (Known States) with 4 conditions: tool-registry.json phantom, tool-versions.json stale reference, unfiled incidents from the session, and in-flight terminology rename.

---

## 4. Delegation Duty Born (~L1187)

### User's exact words (L1187)

> also, include instructions for the executing agents that, before they delegate work to a subagents, they need to review and update the instructions passed on what has been accomplished thus far, and if we have deviated from the plan, and if other things have surfaced. basically, all executing agents have a duty to improve and refine the prompt they are delegating to the delagating agent. the executing agent should know, as much as they can, they are one piece of a larger puzzle.

### Agent's response (L1189) -- step 6 first draft

> **6. Delegation duty**: Before delegating work to a sub-agent, the executing agent must:
>    - Review what has been accomplished in prior batches
>    - Check whether execution has deviated from the plan
>    - Note any new findings that surfaced during prior batches
>    - Update the sub-agent's prompt with all of the above
>    - Make clear to the sub-agent that it is one piece of a larger effort -- state which batch it's executing, what came before, and what comes after
>    - The goal: each sub-agent receives a prompt that reflects the current state of the work, not the state at plan-writing time

### User's reaction (L1194)

> thats beautiful. now re-read our plan, line by line, and re-write it from scratch apllying that everywhere

---

## 5. Military Doctrine Connection (~L1224)

The agent independently connected the delegation duty to military operational planning frameworks (L1224):

**1. Mission Command (Auftragstaktik)**

> "Commanders direct *what* and *why*; subordinate commanders devise *how*."
>
> This IS our delegation duty. The executing agent tells the sub-agent the batch objective and context (what + why). The sub-agent figures out how.

**2. OPORD / WARNORD / FRAGORD**

| Military | Our equivalent |
|---|---|
| **OPORD** (full operational order) | The plan file |
| **WARNORD** (advance notice) | The "what the sub-agent needs to know" section in each batch |
| **FRAGORD** (delta update) | The delegation duty step: "check for deviations, update the prompt" |

**3. Backbrief**

> "Conduct a backbrief at the end of the OPORD to ensure personnel understand the order." Our verification step after each batch is the backbrief.

---

## 6. The 5 Harness Constraints on Delegation (~L1236-L1242)

### User demands adaptation to harness reality (L1236)

> remember the limitations and capbilities of our harness and the need to adapt/adpt these frameworks to those constraints. re-read from the beginning and re-write from scratch with this additional note in mind

### Agent's codification of the 5 constraints (L1242)

> **Execution protocol step 6 (delegation duty)** now explicitly documents the harness constraints that shape how military mission command concepts apply here:
> - Sub-agents don't persist -- each starts fresh, so briefings must be complete, not deltas
> - Sub-agents don't inherit rules -- critical rules must be injected into the prompt
> - No mid-execution updates -- the main agent waits and addresses findings in the next batch
> - No peer communication -- only the main agent carries awareness across batches
> - Verification happens after execution, not before (no backbrief in this harness)

---

## 7. Delegation Becomes Recursive and Generalized (~L1254-L1264)

This was agent-initiated. During a rewrite pass, the agent noticed 6 references to "main agent" and recognized the protocol should apply at any level of delegation, not just the top-level orchestrator.

### Agent's summary of the change (L1264)

> - **Step 6 is now universal**: "Any agent that delegates work to another agent must follow this duty. This applies recursively." No more "main agent" -- every reference now says "delegating agent" and "delegated agent."
> - **Constraints generalized**: "Delegated agents do not persist" instead of "sub-agents do not persist between batches." Applies at any level of the chain.
> - **"What every delegating agent must do"** replaces "What the main agent must do" -- the duty is the same regardless of where in the chain you sit.
> - **Batch plan intro** generalized: "The delegating agent must follow step 6" instead of "The main agent must follow step 6."
> - **Batch briefing sections** renamed from "Situational awareness for sub-agent briefing" to "Situational awareness for briefing" -- because the briefing could be written by any agent in the chain, not just the top-level one.
> - **Risk #7** reworded: "Context gap at every delegation" instead of "Sub-agent context gap."
> - Zero remaining references to "main agent" in the plan.

---

## 8. "Include the Plan" -- FRAGORD Without OPORD (~L1268)

### Agent catches the logical gap (L1268)

> You're right -- the briefing tells the delegated agent about deviations from a plan it was never given. That's a FRAGORD without the base OPORD.
>
> The fix: add an explicit bullet about including the plan itself (execution protocol + relevant sections). Let me audit the rest of the protocol for similar completeness gaps before rewriting.

The agent audited step 6 and found one gap:

| Bullet | What it provides | What's missing |
|---|---|---|
| "deviations from the original plan" | Delta from plan | **The plan itself** |

> **Fix**: Add a bullet before "deviations" that says to include the execution protocol (always) and the relevant sections of this plan for the delegated work. The delegating agent uses judgment about which sections -- a batch 7 sub-agent doesn't need the full incidents rename spec, but it does need the execution protocol, its batch section, and the hook/schema specs it's implementing.

---

## 9. Identity Duty Born (~L1271)

### User's exact words (L1271)

> also, its a duty on the delagating agent to ensure each subagent know its idneitty. it should do as best it can to include an identity profile for the subagent. go ahead and continue

### Agent's implementation (L1278)

> Two fixes in this rewrite:
>
> **1. Plan included in briefing** -- new bullet "Include the plan" in step 6: give the delegated agent the execution protocol (always) and the relevant plan sections. The delegated agent cannot follow deviations from a plan it was never given.
>
> **2. Identity established** -- new bullet "Establish identity" in step 6: tell the delegated agent who it is, what role it plays, which batch it owns, how its work fits the larger effort. Each batch now has an **"Identity for delegated agent"** section with a specific role description (schema migration agent, skill updater, framework architect, consolidation agent, hook engineer, verification agent).

---

## 10. Final "Carry Awareness" Framing (~L1283-L1316)

### User's final instruction (L1283)

> to answer your last question, yeah i think the answer is yes. re-write the plan one more time from scratch to implement that "carry awareness" in the opening of the plan itself and audit for other places

### Agent's three reinforcement points (L1316)

> Three reinforcement points:
> 1. **Opening addressee** (line 3) -- establishes the role
> 2. **Protocol opening** (line 48) -- "you (the executing agent reading this plan)"
> 3. **Batch plan intro** (line 436-442) -- "You delegate... You are the only element that persists"
>
> Step 6 stays generic ("any agent that delegates") because the duty is recursive. But the plan's voice is clearly addressed to the executing agent who carries awareness.

---

## 11. The Final Execution Protocol

The final version lives in `/Users/pepe/.claude/plans/gleaming-cooking-unicorn.md`, lines 45-167. The complete structure:

### Plan Opening (addressee)

> **To the executing agent**: This plan is addressed to you. You are the
> persistent element across all 8 batches -- you read this plan in full,
> delegate batches to other agents, verify results between batches, and
> carry situational awareness that no delegated agent can carry for itself.
> Delegated agents start fresh with no memory of prior work. What you pass
> forward in each briefing is the only context they have. Your awareness
> is the thread that holds this effort together.

### Protocol Preamble

> Every agent at every level of the delegation chain must follow this
> protocol -- whether it is you (the executing agent reading this plan), a
> delegated agent executing a batch, or a delegated agent's own delegated
> agent handling a subset of work. When you delegate, include this protocol
> in the briefing so the delegated agent operates under the same rules.

### Step 1: Read the full plan first

Read this entire plan before making any changes to any file.

### Step 2: Intent writing

Read the intent-writing skill as reference (do not invoke). Audit recent
conversations for approved intents as examples. Match conciseness of
existing governed JSON intents.

### Step 3: Governed JSON modifications

Use governing skill when available. Source-of-truth review gate for
structural changes.

### Step 4: All protected file changes

Source-of-truth review gate: draft, present, write after approval.

### Step 5: Known states

4 conditions: tool-registry.json phantom, tool-versions.json stale ref,
unfiled incidents, in-flight terminology rename.

### Step 6: Delegation duty

**Harness constraints (4):**
- Delegated agents do not persist (start fresh, no memory)
- Delegated agents do not inherit project rules or CLAUDE.md
- Delegated agents cannot receive updates mid-execution
- Delegated agents cannot communicate with each other

**What every delegating agent must do before delegating:**
1. **Establish identity** -- tell the delegated agent who it is, what role it plays, how its work fits the larger effort
2. **Include the plan** -- execution protocol (always) + relevant plan sections
3. **Include prior results** -- actual results, not plan descriptions; state deviations and their impact
4. **Include what comes after** -- what work follows this delegation
5. **Inject critical rules** -- error-handling, source-of-truth gate, governed-data-access as needed
6. **Note deviations** -- what changed from the plan and why
7. **Note new findings** -- issues surfaced during prior work

**After the delegated agent completes:**
- Verify results before delegating the next piece of work (only mechanism to catch errors; no pre-execution confirmation in this harness)

---

## Observations

### Concept Genealogy

| Concept | Origin | How it entered |
|---|---|---|
| Execution protocol | Agent named it (L1103) | User confirmed the name (L1111) |
| Ambiguity purge | User demanded it (L1115) | "wtf is bootstrap?" |
| Known states | User demanded it (L1129) | "note the bad state" |
| Delegation duty | User articulated it (L1187) | "a duty to improve and refine the prompt" |
| Military grounding | Agent connected it (L1224) | Mission Command, OPORD/FRAGORD |
| Harness constraints | User demanded adaptation (L1236) | "remember the limitations" |
| Recursive generalization | Agent initiated it (L1254-L1264) | Found "main agent" references |
| Include the plan | Agent caught logical gap (L1268) | "FRAGORD without the base OPORD" |
| Identity duty | User articulated it (L1271) | "ensure each subagent know its identity" |
| Carry awareness | User confirmed it (L1283) | Address the plan to the executing agent |

### Pattern

The user drove the conceptual leaps (delegation duty, identity duty, harness
constraints). The agent drove the structural refinements (recursion,
FRAGORD-without-OPORD, military connections). Neither could have produced the
final result alone -- the user had the vision but not the plan structure; the
agent had the structure but not the vision.

### Key Quotes That Defined the Protocol

1. **"they are one piece of a larger puzzle"** (L1187) -- the core insight that agents need situational awareness
2. **"a duty to improve and refine the prompt"** (L1187) -- delegation as an active responsibility, not just task assignment
3. **"remember the limitations and capabilities of our harness"** (L1236) -- military doctrine is inspiration, not specification
4. **"ensure each subagent know its identity"** (L1271) -- agents work better when they know who they are
5. **"FRAGORD without the base OPORD"** (L1268) -- you cannot tell an agent about deviations from a plan it was never given
