# Intent Sentinel Stop Hook — Design Document

**Session**: KHGOmVeNNM | **Date**: 2026-03-23
**Author**: S3 (Operations)
**File**: `.scratch/session-KHGOmVeNNM/intent-sentinel-stop.sh`

---

## Problem Statement

During long research phases (approximately 100K tokens of file reads), the agent lost track of the user's instruction and jumped from research into execution without permission. This is within-conversation context rot on user intent — a single-agent, single-conversation problem that the existing multi-agent context rot mitigations (FP-2 techniques) do not address.

## How It Works

The hook fires after every agent response (Stop event, command type). It reads the session transcript from the JSONL file and performs two independent checks:

### Function 1: Turns-Since-Human Tracker

1. On each fire, the hook scans the last 500 lines of the transcript JSONL using Perl.
2. It counts how many assistant turns have occurred since the last human message (excluding sidechain/subagent entries).
3. If the count exceeds 3 turns (configurable), the hook extracts the user's last instruction text from the transcript.
4. The extracted text is truncated to 300 characters and injected via stderr as an "INTENT CHECK" reminder.
5. A cooldown of 5 turns prevents over-injection — after firing, the hook stays quiet for 5 more agent turns before checking again.

### Function 2: Phase Transition Detector

1. The hook scans the last 200 lines of the transcript for tool usage patterns (tool_use entries in the JSONL).
2. It builds a sequence of recent tool names and looks for the specific failure pattern: a streak of 5+ Read/Grep/Glob calls followed by a Write or Edit.
3. When this pattern is detected, it injects a "PHASE TRANSITION DETECTED" warning that asks the agent to verify alignment with the user's instruction before continuing execution.
4. This function only fires if Function 1 did not already inject (prevents double-injection on the same turn).
5. Has its own separate cooldown tracking (5 turns).

## What Triggers Injection

| Trigger | Condition | Injection |
|---------|-----------|-----------|
| Agent autonomy | 3+ agent turns with no human input | INTENT CHECK with the user's last instruction quoted |
| Research-to-execution shift | 5+ consecutive Read/Grep calls followed by a Write/Edit | PHASE TRANSITION warning asking for user confirmation |

## What Gets Injected

### Intent Check (Function 1)

```
INTENT CHECK (N agent turns since last user input): The user's
instruction was: "<first 300 chars of last human message>" — Are you
still aligned with this intent? If you are transitioning from research
to execution, confirm with the user first. Do not jump from
investigation into code changes without explicit permission.
```

### Phase Transition Warning (Function 2)

```
PHASE TRANSITION DETECTED: You have been reading files (N+ consecutive
Read/Grep calls) and just performed a Write. This looks like a shift
from research to execution. Before continuing: (1) Does this write
align with the user's instruction? (2) Did you report your findings
to the user before acting? (3) If this is a scratch/notes file, carry
on. If this changes repo files, confirm with the user first.
```

## Performance Characteristics

| Operation | Cost | Mitigation |
|-----------|------|------------|
| Read stdin JSON | <1ms | BASH_REMATCH regex (no fork) |
| Read/write marker files | <1ms | /tmp filesystem, small files |
| Scan transcript tail (500 lines) | ~5-10ms | `tail -500` limits I/O; Perl is single-pass |
| Extract intent text | ~5ms | Only runs when threshold is hit (not every turn) |
| Tool sequence parsing | ~5ms | `tail -200` limits I/O; only runs if Function 1 didn't fire |

**Total worst case**: approximately 15-20ms when both functions run their full logic. **Typical case**: approximately 3-5ms (threshold not hit, only turn counter + threshold check).

The cooldown mechanism means full parsing happens at most once every 5 turns, keeping average cost low.

## How It Complements the Existing Lagebeurteilung Checkpoint Hook

The three Stop hooks address different failure modes of context rot:

| Hook | What It Detects | What It Injects |
|------|-----------------|-----------------|
| **Lagebeurteilung checkpoint** (estimate-refresh-stop.sh) | Context window filling up (turn-count heuristic) | Reminder to update the running estimate with current situation |
| **Surfacing duty** (surfacing-duty-stop.sh) | Time-based reminder + incident language without filing | Reminder to file incidents and check for ambiguities |
| **Intent sentinel** (this hook) | Agent operating autonomously without user input; research-to-execution phase shift | User's actual instruction re-quoted; phase transition warning |

The Lagebeurteilung hook cares about *situation awareness* — is the running estimate current? The intent sentinel cares about *mission alignment* — is the agent still doing what the user asked? These are complementary: an agent can have a perfectly current running estimate while executing a task the user never authorized.

The surfacing duty hook operates on a time basis (every 30 minutes). The intent sentinel operates on a *turn* basis (every N agent-autonomous turns). A fast agent producing many turns in quick succession will trigger the intent sentinel long before the surfacing duty fires.

## State Files

All state is stored in `/tmp/aitools-intent-{session_id}/`:

| File | Purpose | Format |
|------|---------|--------|
| `turn-count` | Total turns this session | Integer |
| `last-intent-inject-turn` | Turn number of last intent injection | Integer |
| `last-phase-inject-turn` | Turn number of last phase transition injection | Integer |

Files are session-ephemeral — `/tmp` cleanup handles lifecycle.

## Platform Compatibility

- **macOS**: Native bash + perl (both pre-installed)
- **Windows Git Bash**: bash + perl (bundled with Git for Windows)
- **No platform-specific commands used**: The hook does not use `stat`, `date -d`, `find -printf`, or any other command that diverges between macOS and GNU. All heavy parsing is done by Perl, which is portable.
- **No grep -P**: All regex parsing uses Perl directly (per cross-platform.md hook portability rules)

## Assumptions

1. **Transcript JSONL format is stable**: The hook parses `"type":"human"` and `"type":"assistant"` fields, and the `message.content[].text` structure for human messages. If Claude Code changes this format, the hook will silently stop extracting intent (fail-safe — never blocks).

2. **500 lines is sufficient lookback**: The hook reads the last 500 lines of the transcript. In a session with very long assistant responses (large code blocks), the last human message could be further back. The 500-line window is a trade-off between reliability and performance.

3. **Tool names in transcript are reliable**: The phase transition detector depends on tool_use entries appearing in the transcript JSONL with a `"name"` field. This is the observed format but is not formally specified.

4. **Single-text-block human messages**: The intent extraction takes the first `"type":"text"` block from the human message's content array. Multi-block messages (e.g., text + image) will only surface the first text block.

5. **Sidechain filtering is sufficient**: The hook filters out `"isSidechain":true` entries when counting turns. This prevents subagent activity from inflating the turn count.

## Tuning Recommendations (Post-Deployment)

1. **TURNS_THRESHOLD (currently 3)**: Start aggressive. If the hook fires too often during normal multi-step operations (where the agent is legitimately executing a user-approved plan), increase to 5. If it misses drift, decrease to 2.

2. **READ_STREAK_THRESHOLD (currently 5)**: May need to increase to 8-10 if the agent frequently reads a few files before making scratch notes (legitimate pattern). The key question: at what Read count does "browsing" become "deep research that might cause intent loss"?

3. **COOLDOWN_TURNS (currently 5)**: If the agent acknowledges the reminder but continues drifting, decrease to 3 for more persistent re-injection. If the reminder is annoying and the agent is always aligned, increase to 8-10.

4. **MAX_INTENT_CHARS (currently 300)**: May need to increase for complex instructions that lose meaning when truncated. May need to decrease if injections are adding too much context.

5. **Transcript lookback (currently 500 lines)**: Monitor whether the last human message is ever outside this window. If so, increase to 1000 — but measure the performance impact.

6. **Phase transition scratch exemption**: Currently the hook does not distinguish scratch writes from repo writes. A future enhancement could check whether the Write/Edit target path contains `.scratch/` and suppress the warning for scratch-only writes.

7. **Integration with Lagebeurteilung**: Consider having the intent sentinel and Lagebeurteilung hooks share the turn counter (read from the same marker file) to avoid redundant counting. Currently they maintain independent counters.

## Edge Cases Found During Design

1. **Queue-operation messages**: Claude Code sometimes stores user input as `"type":"queue-operation"` rather than `"type":"human"` (per incident in incidents.json). The current implementation only looks for `"type":"human"`. This could cause the hook to overcount agent-autonomous turns in some edge cases. A future fix would also check for queue-operation entries with user content.

2. **Compact resets**: When the user runs `/compact`, the transcript may be truncated or rewritten. The hook's tail-based scanning will naturally adapt (it reads the current state of the file), but the marker files in /tmp will retain the old turn count. This is harmless — the turn count just stays higher than the actual transcript length.

3. **Multi-block content**: Human messages can contain text + images + file references. The intent extraction only surfaces the first text block. For messages like "Look at this screenshot and fix the bug", the text portion may be sufficient, but the screenshot context is lost.

4. **Very fast sessions**: If the agent produces 3+ turns in under a second (possible with simple tool calls), the hook will fire and inject. This is correct behavior — fast autonomous operation is exactly when drift risk is highest.

5. **Subagent activity**: Subagent turns appear in the transcript with `"isSidechain":true`. These are correctly filtered out. However, if a subagent's work causes the main agent to produce multiple turns of processing the results, those main-agent turns DO count toward the threshold. This is correct — the main agent processing subagent results without user input is a legitimate drift scenario.
