# Intent Heuristic Findings — 2026-03-17

## Scope

Investigated the gap between the full intent heuristic (as documented
in the handoff prompt and harvested investigation) and what the
/intent-writing and /intent-audit skills actually contain. Audited
5 sessions from March 16 and 2 from March 15 for user preference
signals on intent quality.

## Source Material Audited

| Source | What it contains |
|--------|-----------------|
| `plans/mission-command-briefing/handoff-prompt.md` §F | Fullest version: 5-category preference extraction, date-range recency tiers, same-session override rule, Plan Writer delegation template |
| `harvesting/2026-03-16_investigate-intent-heuristics.md` | 7 heuristics extracted from session evidence, gap analysis of both skills, proposed new sections (approved by user at 79b05dd0:1233) |
| `harvesting/2026-03-16_intent-approval-evolution.md` | Timeline of batch 1→5 evolution: 3-round→1-round approval, consolidated presentation, style calibration |
| `shared/skills/intent-audit/SKILL.md` | Current skill: has step 1b (quality audit), 1c (ambiguity scan), 4b (exemplar comparison with static list) |
| `shared/skills/intent-writing/SKILL.md` | Current skill: has pre-write audit, multi-pass ambiguity removal, consolidated presentation, quality criteria, style calibration |
| 5 sessions from 2026-03-16 | b8a9ed4e, 79b05dd0, 37ab88e4, 276dee5c, ed02d497 |
| 2 sessions from 2026-03-15 | eaacf9da (tool-ops execution), 84280c8b (tool-ops plan) |

## F14: Skills Have the Principle but Not the Mechanism

Both skills say `"weight recent > old"` as a parenthetical and have
a hardcoded exemplar list (dated 2026-03-15/16). They are missing:

1. **How to find approved intents** — no process for scanning
   conversation history for approval/rejection signals
2. **How to weight them** — no recency tiers, no same-session
   override rule, no cross-project signal distinction
3. **What signals to look for** — no categorization of user
   feedback (approval/rejection/correction/redirection/escalation)
4. **When to update** — exemplar list is static with no guidance
   on when or how to refresh it

### Evidence from the handoff prompt (section F)

The handoff prompt contains the FULL heuristic, scoped to the
Plan Writer role:

```
Weight by recency:
- March 14-16: highest weight
- March 9-13: high weight
- March 1-6: medium weight
- February: low weight
- Cross-project sessions: different signal
- Same session: later exchanges override earlier
```

Plus a 5-category preference extraction framework:
- APPROVALS: "beautiful", "thats pretty damn beautiful", "perfect"
- REJECTIONS: "wtf is bootstrap?", "weak sauce", "not right"
- REDIRECTIONS: "re-read from the beginning and re-write from scratch"
- ESCALATIONS: "do barrier analysis", "audit our recent conversations"
- CORRECTIONS: "the audience: programmatic code likes hooks"

### Evidence from the investigation file

`harvesting/2026-03-16_investigate-intent-heuristics.md` Heuristic 2:

> User's exact words: "the more recent the conversation where i
> confirmed i was happy, the more weight that intent should have"

Source: delegation-evolution.md §1, L1101

### What the skills currently have

**`/intent-writing`** line 92:
> "Read 2-3 recently approved intents (weight recent > old)"

**`/intent-audit`** line 127:
> "weight recent > old" with a static exemplar ranking (5 entries)

Both mention the principle but provide no process for discovering,
weighting, or refreshing exemplars from conversation history.

## F15: User Preference Signals Extracted (Mar 15-16)

### Approval signals (what "good" looks like)

| Session | User message | Context |
|---------|-------------|---------|
| eaacf9da | "beautiful" | 4 intents presented in one block (batch 5) |
| eaacf9da | "beautiful. not sure about effectiveness.md but ok" | Single intent (batch 6) |
| eaacf9da | "perfect" (×2) | After revising incidents.json intent |
| eaacf9da | "lookd hoof" | SKILL.md intent with tracking table |
| b8a9ed4e | "thats pretty damn beautiful. great work." | After framework names/intents presented |
| 79b05dd0 | "this is pretty beautiful, yes agree with all of that" | Framework intents reviewed |
| 79b05dd0 | "the proposed sections for the intent skills are approved" | Heuristic sections for both skills |
| 79b05dd0 | "approved" (×6) | Various proposals |
| 84280c8b | "thats beautiful" | After plan rewrite applying governance |

### Correction signals (what needs fixing)

| Session | User message | What was wrong |
|---------|-------------|---------------|
| eaacf9da | "add something about not just tracking but also adapting/continuous improvement" | Purpose too passive — "track" alone is incomplete |
| eaacf9da | "the audience: programmatic code likes hooks and other things" | Audience omitted programmatic consumers |
| eaacf9da | "follow our intent pattern intent/purpose audience" | Format didn't match standard |
| eaacf9da | "its missing its intent" | File written without intent statement |
| 84280c8b | "wtf is bootstrap?" | Undefined term in agent's prompt |
| 84280c8b | "remove ambiguities from instructions to executing agent, do multiple passes" | Single-pass ambiguity check insufficient |
| 79b05dd0 | "the suggested resolution is weak sauce" | Corrective action too weak (UCI vs structural) |
| 79b05dd0 | "i noticed you wrote a decision on a new hook and didnt include a proposed intent. fix that" | Missing intent on new artifact |
| 79b05dd0 | "that table shouldnt exist at all [...] write its intent and body and cross-reference from scratch" | State in process file — rewrite needed |
| 37ab88e4 | "i dont think we captured my intent right, though i may have accepted a decision without reviewing it" | Intent drift — accepted without review |

### Redirection signals (process was wrong)

| Session | User message | What changed |
|---------|-------------|-------------|
| 84280c8b | "re-read your last prompt, remove ambiguities... do multiple passes of this and come back to me before rewriting" | Multi-pass became mandatory |
| 79b05dd0 | "audit the intent, each field... remove ambiguity and call out any ambiguity" | Field-level audit required |
| 79b05dd0 | "launch a subagent... to audit all intents with the heuristic we defined earlier" | Heuristic must be part of the skill |
| 37ab88e4 | "audit our recent conversations from today and yesterday thoroughly" | Conversation scanning as investigation method |

### Escalation signals (deeper investigation needed)

| Session | User message | What was escalated |
|---------|-------------|-------------------|
| 37ab88e4 | "use /investigate and barrier analysis with a subagent" | Structural analysis before deciding |
| 37ab88e4 | "audit the work performed... ensure all intent is preserved" | Post-implementation intent verification |
| 79b05dd0 | "can we make a write hook that blocks writes with a hint that any new framework/artifact must have an intent?" | Intent enforcement hook proposed |

## F16: User's Explicit Directive to Update Skills

From session b8a9ed4e (Mar 16), line 267:

> "for writing intents, checkout what we did in the tool-ops plan for
> yesterday. those instructions worked out very well, they talk about
> looking at conversation history for intents written by you that i
> liked and/or refined and got right. the more recent the work the
> more weight those should have. can we capture this in our
> intent-writing skill? try to generalize other things you see from
> the AAR and the planning and execution of that test-ops plan"

From session 79b05dd0 (Mar 16), line 564:

> "do we have enough to update the /intent-writing and /intent-audit
> skills? i think the heuristic we use should be part of the skill"

From session 79b05dd0 (Mar 16), line 1233:

> "the proposed sections for the intent skills are approved"

The user explicitly requested these updates, the investigation
produced the specific sections, and the user approved them. The
sections were partially integrated (quality criteria, ambiguity
removal, style calibration) but the conversation-scanning heuristic
and recency weighting mechanism were reduced to parenthetical
mentions.

## Recommendations

### R1: Update /intent-writing exemplar calibration

Replace the current "Exemplar calibration" subsection (lines 89-99)
with the full version including:
- Signal categories table (approval/rejection/correction/redirection/escalation)
- Recency weighting tiers (current+prior session → past week → past month → older)
- Same-session override rule
- Cross-project signal distinction
- Dynamic exemplar discovery process
- "Update when new intents are approved" guidance

### R2: Update /intent-audit exemplar comparison

Replace the current "4b. Compare to exemplar intents" section
(lines 124-145) with the full version including:
- Exemplar discovery process (scan transcripts, not just codebase)
- Recency weighting tiers (same as R1)
- Staleness detection for the exemplar ranking
- Correction signals as stronger exemplars than first-try approvals

### R3: Both skills should share the same signal vocabulary

The 5-category signal framework (approval, rejection, correction,
redirection, escalation) should use identical terminology in both
skills. /intent-writing uses signals to calibrate before drafting.
/intent-audit uses signals to evaluate after the fact. Same signals,
different phase.

### Proposed text for both changes

See the proposed edits presented to the user earlier in this session
(before this file was created). Both were drafted and presented for
review but not yet approved for writing.
