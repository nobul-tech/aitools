# Context Rot Research: Intent Resurfacing During Long Execution Phases

**S2 Intelligence Product** | Session KHGOmVeNNM | 2026-03-23
**Mission**: Research existing context rot framework proposal and hook architecture to answer: "How can we keep resurfacing user intent and operational learning WHILE an agent is executing/thinking?"

---

## Files Read (Full Content Provided Above)

1. `.scratch/session-5HyCwPtSDH/s2c-framework-proposals.json` — FP-2 (Context Rot framework)
2. `shared/hooks/estimate-refresh-stop.sh` — Lagebeurteilung checkpoint hook
3. `shared/hooks/surfacing-duty-stop.sh` — Surfacing duty hook
4. `shared/hooks/session-archive.sh` — SessionEnd transcript archiver (reference for hook input schema)
5. `plans/governance-and-compliance-framework.md` — Hook specifications section
6. `reference/tool-ops-claude-code.md` — CC version deps, hook event documentation
7. `scripts/setup-user-hooks.sh` — Hook deployment (shows all configured events)

---

## Q1: What Does FP-2 Already Propose for Context Rot Mitigation?

FP-2 ("Context Rot Mitigation Framework") proposes **five techniques**, all framed as **Mission Command tactics** (not a separate framework):

| # | Technique | Trigger | Type |
|---|-----------|---------|------|
| 1 | Fresh subagent pattern | Session >2h or >50 tool calls | Structural |
| 2 | Write-verify-amend cycle | Any S3 output for downstream consumption | Structural |
| 3 | FRAGORD kill-and-replace | New findings contradict running subagent | Structural |
| 4 | Running estimate freshness check | Before any final deliverable | Behavioral |
| 5 | Operational learning duty injection | Every delegation (at END of prompt) | Structural |

**Key insight from FP-2**: "Context rot is not a GOVERNANCE problem (no rule is missing) — it is a PHYSICS problem (LLM context window has recency bias, long sessions dilute rule salience). The mitigation is structural (how you compose agents) not behavioral (telling agents to pay attention)."

**What FP-2 does NOT address**: The specific failure mode that triggered this research — context rot on the USER'S INSTRUCTION within a single agent's conversation. All five techniques are about inter-agent composition (subagents, delegation, verification). None address the case where a single agent reads 100K tokens of files and loses track of what the user asked it to do. This is a within-conversation, single-agent problem, not a delegation problem.

---

## Q2: What Hook Events Are Available in CC and What Data Do They Receive?

### Hook Events (from `setup-user-hooks.sh` and `governance-and-compliance-framework.md`)

| Event | When It Fires | Data on stdin | Output Contract |
|-------|--------------|---------------|-----------------|
| **SessionStart** | Session begins | `{session_id, cwd, ...}` | stdout: JSON with `hookSpecificOutput` for context injection |
| **SessionEnd** | Session ends | `{session_id, cwd, transcript_path}` | Exit code only |
| **PreToolUse** | Before a tool call | `{tool_name, tool_input, session_id, cwd, agent_id, agent_type}` | Exit 0=allow, Exit 2=block; stderr=feedback |
| **PostToolUse** | After a tool call | `{tool_name, tool_input, tool_output, session_id, cwd}` | Exit code; stderr=feedback |
| **Stop** | After every agent response | `{session_id, cwd, transcript_path, ...}` | Exit 0=allow, Exit 2=block; **stderr → shown to agent as feedback** |
| **InstructionsLoaded** | After CLAUDE.md/rules load | `{session_id, cwd, ...}` | (Not yet used in harness) |
| **PermissionRequest** | Permission prompt shown | `{tool_name, session_id, ...}` | Async telemetry |
| **SubagentStart** | Subagent launched | `{session_id, cwd, agent_id, agent_type}` | stdout: JSON with `hookSpecificOutput.additionalContext` for context injection |

### Hook Types

| Type | Behavior |
|------|----------|
| `command` | Runs a shell command. stderr → agent feedback. stdout → structured output (event-dependent). |
| `prompt` | Static string injected as context. No dynamic computation. |
| `agent` | AI-powered validation (30s timeout). Can block or allow. |

### Critical Capability: Stop Hook stderr → Agent Feedback

The Stop hook fires after **every agent response**. When it is `type: "command"`, anything written to stderr is shown to the agent as feedback on its **next turn**. This is the primary injection mechanism for mid-conversation context.

Both existing Stop hooks (`estimate-refresh-stop.sh` and `surfacing-duty-stop.sh`) use this pattern.

---

## Q3: Can a Hook Inject the User's Last Instruction into Agent Context?

**Yes.** The Stop hook can do this. Here is the mechanism:

### Data Available to Stop Hook

The Stop hook receives `transcript_path` in its stdin JSON (confirmed by `surfacing-duty-stop.sh` line 30). The transcript is a JSONL file where each line is a JSON object with a `type` field (`"human"` or `"assistant"`).

### Extraction Method

The hook can:
1. Read `transcript_path` from stdin JSON
2. Parse the JSONL backwards to find the last `"type": "human"` entry
3. Extract the user's message text
4. Inject it via stderr as a reminder

### Performance Constraint

The hook must be fast (<50ms). Reading the full JSONL transcript backwards is feasible for moderate sessions but could be slow for very long sessions. Mitigation options:
- `tail -N` the transcript and scan backwards (the surfacing-duty hook already does `tail -100`)
- Cache the last-seen human message offset in a marker file (like estimate-refresh does for turn count)
- Only extract on trigger conditions (not every turn)

### Proof of Concept

```bash
# Extract last human message from JSONL transcript
last_human=$(tail -500 "$transcript_path" 2>/dev/null | \
  perl -ne 'if (/"type"\s*:\s*"human"/) { $last = $_; } END { print $last if $last; }')

# Extract the message text (simplified — actual structure may vary)
if [ -n "$last_human" ]; then
    # Inject as stderr feedback
    printf 'INTENT REMINDER: User last said: %s' "$last_human" >&2
fi
```

### Limitation: Stop Hook Fires After Agent Response, Not During Thinking

The Stop hook fires AFTER the agent has already produced its response. It cannot interrupt mid-thought. The injected reminder appears at the START of the agent's next turn. This means:

- If the agent produced a bad response (jumped to execution), the Stop hook injects the reminder AFTER the damage is done
- The reminder helps the agent self-correct on its NEXT turn
- It does NOT prevent the first violation — it catches and corrects

This is the fundamental structural limitation: CC hooks are **turn-boundary** mechanisms. There is no **mid-thought** injection point in the current CC architecture.

---

## Q4: Structural Options for Keeping Intent Visible During Long Execution Phases

### Option A: Stop Hook Intent Reminder (Implementable Now)

**Mechanism**: Stop hook extracts user's last instruction and injects it as stderr feedback every N turns or after detecting the agent has been reading files for M consecutive turns without user interaction.

**Trigger heuristics**:
- Turn count since last human message > threshold (e.g., 5 tool calls without user input)
- Consecutive Read/Grep tool calls detected (research phase indicator)
- Time elapsed since last human message > threshold (e.g., 10 minutes)

**Strengths**: Uses existing infrastructure. Low implementation cost. Proven pattern (estimate-refresh already does turn-based injection).

**Weaknesses**: Post-hoc — fires after the agent's response, not during thinking. Cannot prevent the first violation, only catch it on the next turn. The agent has already spent tokens on the wrong path.

### Option B: PreToolUse Intent Injection (Implementable Now)

**Mechanism**: PreToolUse hook on Read/Write/Edit tools detects when the agent has been in a long research phase (many consecutive Read calls) and injects the user's intent as a reminder BEFORE the next tool call.

**Trigger heuristic**: After N consecutive Read/Grep calls (research phase), inject before the N+1th call: "INTENT REMINDER: Your mission is: [last human message]. Are you still investigating, or are you ready to report findings?"

**Strengths**: Fires BEFORE the tool call, so the agent sees the reminder before it acts. Can distinguish research phase (many Reads) from execution phase (Writes/Edits).

**Weaknesses**: PreToolUse prompt hooks inject a static string (cannot be dynamic). PreToolUse command hooks CAN be dynamic but add latency to every tool call. Need to be very selective about when to inject (false positive risk on every Read).

**CRITICAL FINDING**: PreToolUse `type: "command"` hooks can return `decision: "block"` or allow via exit code, and stderr is shown as feedback. But for a `type: "prompt"` hook, the content is static (defined at deploy time). To inject DYNAMIC content (the user's actual last message), we need `type: "command"`.

### Option C: Instruction Echo File (Structural, Implementable Now)

**Mechanism**: SessionStart hook or a new PreToolUse hook writes the user's last instruction to a well-known file in `.scratch/` (e.g., `.scratch/session-{id}/CURRENT-INTENT.md`). Agent rules in CLAUDE.md say "Before starting execution, re-read CURRENT-INTENT.md."

**Trigger**: The hook updates the file every time a new human message appears in the transcript.

**Strengths**: The file is always current. The agent can re-read it at any time. Rules can reference it. Subagents can read it too (if given the path).

**Weaknesses**: Behavioral — depends on the agent choosing to read the file. Context rot is exactly the failure mode where agents stop following behavioral rules. This is the "telling agents to pay attention" approach that FP-2 explicitly identifies as insufficient.

### Option D: Compact + Re-inject Pattern (Structural, Requires User Action)

**Mechanism**: When the agent reaches a context threshold (detectable via turn count or estimated token usage), it compacts the conversation. The compact operation preserves the system prompt (CLAUDE.md, rules) but loses mid-conversation context. A hook detects the compact (session restart?) and injects the last instruction + running estimate as fresh context.

**Strengths**: True context reset. Rules regain full salience. User intent is fresh.

**Weaknesses**: Requires user to trigger `/compact` or accept an agent suggestion to compact. Loses mid-conversation reasoning that hasn't been written to files. The agent must externalize all findings before compacting.

### Option E: Delegation Checkpoint (Structural, Requires Pattern Change)

**Mechanism**: Instead of a single agent doing 100K tokens of research then acting, the user's instruction is encoded as a formal mission with explicit boundaries: "INVESTIGATE [topic]. REPORT findings. DO NOT EXECUTE without explicit permission." The Stop hook detects when the agent transitions from Read-heavy to Write/Edit-heavy behavior and injects: "You appear to be transitioning from investigation to execution. Your mission boundary was INVESTIGATE only. Confirm with user before proceeding."

**Trigger heuristic**: Ratio of Read/Grep calls to Write/Edit/Bash calls shifts. First Write/Edit after a streak of 5+ Read/Grep calls triggers the reminder.

**Strengths**: Addresses the EXACT failure mode (research → execution jump). Structural detection, not behavioral compliance. Uses existing Stop hook infrastructure.

**Weaknesses**: Heuristic-based — may fire on legitimate research-then-write patterns (e.g., writing findings to scratch). Needs tuning.

### Recommendation: Combine A + E

**Option A** (Stop hook intent reminder) provides the base: every N turns, remind the agent what the user asked. Low cost, proven pattern, catches generic drift.

**Option E** (delegation checkpoint) provides the targeted fix: detect the research→execution phase transition and inject a hard reminder at that boundary. This is the specific structural fix for the observed failure mode.

Both use the Stop hook's stderr→agent feedback mechanism. They can be implemented as extensions to `estimate-refresh-stop.sh` or as a new hook.

---

## Q5: How Does estimate-refresh-stop.sh Work?

### Trigger
Fires on **every agent response** (Stop event, command type).

### Input
Reads JSON from stdin. Extracts `session_id` and `cwd`.

### Mechanism: Two Functions

**Function 1: Turn Tracking (Mechanical)**
- Maintains a turn count in `/tmp/aitools-estimate-{session_id}/turn-count`
- Increments on every fire
- No judgment, pure counter

**Function 2: Lagebeurteilung Checkpoint (Context-Aware)**
- Heuristic: each agent turn uses ~2-5K tokens. At 200K context, 20% = 40K = ~10-20 turns
- Fires at turn 15, then every 15 turns thereafter
- Tracks last injection turn in `/tmp/aitools-estimate-{session_id}/last-lage-turn`
- When triggered, injects via stderr:
  ```
  Lagebeurteilung checkpoint (turn N): Context is growing. Update the running estimate
  with current situation, new findings, and decisions. [specific fields to refresh]
  ```

**Function 3: Estimate Freshness (Staleness Detection)**
- Every 10 turns (when Lage didn't fire), checks running estimate file mtime
- If >30 minutes stale, injects: "Running estimate is N minutes stale. Consider updating."
- Uses platform-dispatched `stat` (macOS BSD vs GNU)
- Searches both `.aitools/channel/running-estimate.json` and `.scratch/session-*/` paths

### Output Contract
- stderr: reminder text (shown to agent as feedback on next turn)
- Exit 0 always (never blocks)
- Must be fast (<50ms)

### Key Design Decisions
- Turn-based intervals (not time-based for the Lage checkpoint) — because the agent may be idle between turns
- Marker files in `/tmp/` — session-ephemeral, no cleanup needed
- Conservative interval (15 turns) — better to remind too early than too late
- Never blocks — always exit 0

---

## OBSERVATIONS

1. **The gap is within-conversation, not inter-agent.** FP-2's five techniques all address multi-agent composition. The observed failure (agent loses user intent after 100K tokens of file reads) is a single-agent, single-conversation problem. FP-2 identifies the physics correctly ("recency bias dilutes rule salience") but the proposed mitigations don't reach the single-agent case.

2. **Stop hook is the proven injection point.** Both existing Stop hooks demonstrate the pattern: fire after every response, use marker files for state tracking, inject via stderr. The infrastructure is mature and tested. A new Stop hook (or extension to the existing ones) is the lowest-risk path.

3. **PreToolUse is the higher-value injection point but riskier.** A PreToolUse hook on Read fires BEFORE the tool call, giving the agent the reminder before it acts. But it fires on EVERY Read call, which adds latency and noise. The selectivity challenge is harder than Stop.

4. **The transcript_path field gives access to conversation history.** The Stop hook receives `transcript_path` in its stdin JSON. The surfacing-duty hook already reads the last 100 lines of the transcript. This means a Stop hook CAN extract the user's last instruction from the JSONL transcript. This is the enabling capability.

5. **CC has no mid-thought injection point.** All hooks fire at turn boundaries (before tool call, after tool call, after response). There is no mechanism to inject context while the agent is thinking/generating. The best we can do is inject at the START of the next turn, which means one turn of potential drift before correction.

6. **The estimate-refresh hook already solves a related problem.** It detects context growth (via turn count) and injects a structured reminder to update the running estimate. The intent-reminder problem has the same shape: detect a condition (distance from last user instruction), inject a structured reminder (the instruction itself or a summary).

## SURFACES (Assumptions Revealed)

1. **Assumption: Rules prevent context rot.** FP-2 says this is false — context rot is physics, not governance. But the harness still relies heavily on behavioral rules ("Before starting execution, check X"). The observed failure proves rules alone are insufficient for within-session intent preservation.

2. **Assumption: The agent remembers the user's instruction.** This is the core unsafe assumption. After 100K tokens of file reads, the user's instruction is at token position ~N (where N could be 50K+ tokens back). LLM attention mechanisms give it reduced weight relative to recent content. No mechanism currently forces re-attention.

3. **Assumption: Turn count correlates with context consumption.** The estimate-refresh hook assumes 2-5K tokens per turn. But a Read call that loads a 5000-line file consumes far more context than a simple Bash command. Turn count is a weak proxy for actual context distance from the user's instruction. A better proxy would be: number of tokens read since last human message (approximated by file sizes read via Read tool).

4. **Assumption: One reminder is enough.** The Lage checkpoint fires every 15 turns. But if the agent is deep in a research phase and gets one "update your estimate" reminder, it may acknowledge it and continue researching without actually updating. The surfacing-duty hook has a 30-minute cooldown. Neither has a mechanism to detect whether the agent actually acted on the reminder.

## PROPOSALS

### Proposal 1: Intent Sentinel Stop Hook (Minimal, Buildable Now)

Add a third function to `estimate-refresh-stop.sh` (or create a new `intent-sentinel-stop.sh`):

- Track turns since last human message (from transcript)
- After N turns of agent-only activity (no human input), inject: "INTENT CHECK (turn {N} since last user input): User's instruction was: [first 200 chars of last human message]. Are you still aligned with this intent? If transitioning from research to execution, confirm with user first."
- Track research→execution phase transition: count consecutive Read/Grep vs Write/Edit tool calls (requires reading recent transcript entries, not just turn count)

### Proposal 2: Phase Transition Detector (Higher Value, More Complex)

A PreToolUse hook on Write/Edit that:
- Reads marker files to check if the agent has been in a Read-heavy phase
- If this is the FIRST Write/Edit after 5+ consecutive Read/Grep calls, inject: "Phase transition detected: you've been reading files and are now writing. Verify: (1) Does this align with user's instruction? (2) Did you report findings before executing? (3) Is this a scratch file (OK) or a permanent change (needs permission)?"
- Distinguishes scratch writes (allowed) from repo writes (needs confirmation)

### Proposal 3: Externalized Intent Pattern (Structural, Longer Term)

- SessionStart hook or scratch-init writes a `CURRENT-INTENT.md` file from the first human message
- Stop hook updates it when a new human message appears
- Agent rules reference it: "At phase transitions, re-read `.scratch/session-{id}/CURRENT-INTENT.md`"
- Subagent delegation includes the intent file path
- Running estimate includes an `intent` field that must match CURRENT-INTENT

This combines behavioral (rules) with structural (file always exists, hooks keep it current).

## CONNECTS (Relationship to Existing OL Patterns)

1. **Lagebeurteilung** (periodic reassessment): The intent reminder IS a Lagebeurteilung — just scoped to user intent rather than situation awareness. It fits within the existing estimate-refresh hook's design philosophy.

2. **OBSERVE-SURFACE-PROPOSE-CONNECT**: This research itself demonstrates the duty. The observation (agent lost user intent) led to surfacing (FP-2 gap analysis), proposals (three structural fixes), and connection (to existing Lage and Stop hook patterns).

3. **Decision #35** (hooks > coaching for recurring patterns): The failure mode is recurring (this is not the first time an agent jumped from research to execution). Per decision #35, this should be addressed with a hook, not a coaching item. The Stop hook intent sentinel is the right layer.

4. **Three-layer governance**: Prevention = rules saying "don't execute without permission" (already exist, insufficient alone). Detection = Stop hook detecting phase transition and injecting reminder (proposed). Audit = `/audit` skill checking session transcripts for unauthorized execution (future). The Detection layer is the gap.

5. **FP-1 (Operational Learning)**: This research is a data point for the operational learning cycle. The failure was observed, analyzed, and structural fixes proposed. If a fix is shipped and works, the next session can verify. If it doesn't work, the AAR feeds back into the cycle. The meta-observation: the harness's ability to analyze its own failures (via harvested AARs and framework proposals) is itself an output of operational learning.

---

## Summary of Answers

| Question | Answer |
|----------|--------|
| What does FP-2 propose? | 5 techniques for multi-agent context rot. Does NOT address within-conversation single-agent intent loss. |
| What hook events are available? | SessionStart, SessionEnd, PreToolUse, PostToolUse, Stop, InstructionsLoaded, PermissionRequest, SubagentStart |
| Can a hook inject user's last instruction? | YES — Stop hook receives transcript_path, can extract last human message, inject via stderr |
| Structural options? | 5 options (A-E). Recommend combining A (periodic intent reminder) + E (phase transition detector) |
| How does estimate-refresh work? | Turn counter + Lage checkpoint every 15 turns + staleness check every 10 turns, all via Stop hook stderr |
