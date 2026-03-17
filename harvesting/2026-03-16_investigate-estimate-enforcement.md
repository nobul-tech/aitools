# S2 Investigation: Running Estimate Enforcement Mechanism

**Author**: S2 (Intelligence), session uyZ7TELqpP
**Date**: 2026-03-16
**Method**: Barrier analysis per option, incident replay, decision #20 analysis
**Classification**: Investigation findings for S3/user decision

---

## 1. Incident Replay

### What happened

S3 launched ~15 subagents during the audit session. No running estimate
existed. No channel directory existed. The carry-forward between
subagents was ad-hoc text embedded in delegation prompts — unstructured,
lossy, not archived. Two S2 AAR files were written to `.scratch/` because
`.aitools/channel/` did not exist. When the session was relaunched, all
accumulated state was lost except what survived in the planning brief
(which was the pre-execution artifact, not the execution state).

### The causal chain

```
1. No channel directory exists (decision #22 not implemented)
2. No running estimate exists (carry-forward-design.md is a proposal, not an instance)
3. S3 launches subagents using raw Agent tool (not /delegate skill)
4. Each subagent gets ad-hoc context in prompt text
5. Subagent outputs (including S2 AARs) go to .scratch/ (only dir available)
6. Session crashes or is relaunched
7. .scratch/ from prior session is pruned by scratch-init.sh (24h TTL)
8. All execution state is lost
```

**Root cause**: No structural enforcement — the running estimate and
channel directory are design artifacts (in carry-forward-design.md and
decision #22) but have no implementation. Nothing prevented S3 from
delegating without them.

### What would "prevented" look like?

A mechanism that ensured, before the first Agent tool call:
1. `.aitools/channel/session-XXX/` exists
2. A stub running estimate exists in that directory
3. The agent is aware both exist (via context injection)

---

## 2. Barrier Analysis: Four Options

### Option 1: SessionStart Hook (channel-init.sh with estimate stub)

**Mechanism**: A SessionStart hook (like scratch-init.sh) that creates
`.aitools/channel/session-XXX/`, writes `.current-session`, and creates
a stub running estimate JSON with `meta` + empty `situation.currentState`
+ empty `conclusions.assessment`.

**Barrier analysis — would it have prevented the incident?**

| Question | Answer |
|----------|--------|
| Would it have created the running estimate before the first subagent? | **YES**. SessionStart fires before any user interaction. The estimate would exist from moment zero. |
| Would it have prevented AAR files going to scratch? | **PARTIALLY**. The channel directory would exist, but subagents launched via raw Agent tool (not /delegate) would not know to use it. The hook creates the directory but cannot force agents to write there. Context injection ("channel dir is at X") helps but is not enforcement. |
| Would it have provided carry-forward to the relaunched session? | **NO** — unless paired with a SessionEnd archival hook (channel-archive.sh). The channel dir itself is ephemeral (gitignored). Without archival, relaunch still loses state. But with the archival pipeline (decision #36 component 8), yes. |
| Failure modes | (a) Overhead for trivial sessions — user has accepted this. (b) Stub estimate is empty — S3 must still populate it before first delegation. The stub prevents "file doesn't exist" errors but does not prevent "file is empty/stale." (c) No enforcement that anyone reads or updates the estimate. |

**Latency impact**: ~5ms (mkdir + write small JSON). Negligible.

**Existing pattern**: `scratch-init.sh` is the exact same pattern — create
dir, prune stale, write pointer. Proven, simple, reliable.

### Option 2: PreToolUse on Agent Hook (estimate-gate.sh)

**Mechanism**: A PreToolUse hook on the Agent tool that checks whether
`.aitools/channel/.current-session` exists and contains a running
estimate. If not, creates the channel dir + stub estimate before allowing
the Agent call to proceed.

**Barrier analysis — would it have prevented the incident?**

| Question | Answer |
|----------|--------|
| Would it have created the running estimate before the first subagent? | **YES**. The first Agent call triggers creation. Timing is perfect — estimate exists exactly when needed. |
| Would it have prevented AAR files going to scratch? | **PARTIALLY** — same as Option 1. Channel dir exists, but subagents don't inherently know to use it unless told. |
| Would it have provided carry-forward to the relaunched session? | **Same as Option 1** — requires SessionEnd archival. |
| Failure modes | (a) Adds latency to every Agent tool call (not just the first — must check every time). (b) Hook runs for ALL Agent calls, including claude-code-guide blocks. Must compose with existing block-claude-code-guide.sh. (c) Cannot inject context into the Agent call itself — can only allow/deny. A PreToolUse hook that allows still cannot modify the agent's prompt to include the estimate path. (d) If it denies + provides corrective context, the agent must retry, adding latency and token cost. |

**Critical limitation discovered**: PreToolUse hooks can **deny** (with
corrective context) or **allow** (silently). They **cannot modify the
tool input**. This means a PreToolUse hook cannot inject the running
estimate into the subagent's prompt. It can only:
- Allow (and hope the agent already included it)
- Deny with a message like "create a running estimate first, then retry"

This is a significant barrier to effectiveness. The agent would need to:
1. Attempt Agent call
2. Get denied with "create estimate first"
3. Create the estimate
4. Retry the Agent call

That is a two-round-trip pattern for the first delegation. And it relies
on the agent correctly interpreting the deny reason — behavioral, not
structural.

**Latency impact**: ~5ms per Agent call (file existence check). But denial
+ retry adds ~30-60s of agent processing time for the first delegation.

### Option 3: The /delegate Skill

**Mechanism**: The `/delegate` skill (decision #4) includes estimate
creation/update as part of its delegation process. Before building the
delegation briefing, it checks for the running estimate, creates one if
missing, updates it with current state, and extracts the relevant subset
for the delegation.

**Barrier analysis — would it have prevented the incident?**

| Question | Answer |
|----------|--------|
| Would it have created the running estimate before the first subagent? | **ONLY IF /delegate was used**. In the incident, all 15 subagents were launched via raw Agent tool. /delegate was never invoked. This option has zero enforcement against the actual failure mode. |
| Would it have prevented AAR files going to scratch? | **NO** — same reason. If /delegate isn't used, its logic never runs. |
| Would it have provided carry-forward to the relaunched session? | **NO** — /delegate runs in the session's agent context. If the session crashes before /delegate saves to channel, the state is lost with the agent. |
| Failure modes | **(a) The fundamental failure mode: bypass.** This is exactly how the incident occurred. The agent used raw Agent tool instead of /delegate. A skill is behavioral enforcement — it works when followed, fails silently when ignored. (b) Subagents don't inherit skills, so they cannot invoke /delegate themselves. (c) Circular dependency: /delegate needs the channel dir to exist before it can write the estimate there. Who creates the channel dir? |

**This option is necessary but not sufficient.** /delegate is the right
place for estimate *maintenance* (update, extract, inject into briefing).
But it cannot be the *creation* or *enforcement* mechanism because it can
be bypassed.

### Option 4: Combination (Hook ensures infrastructure, Skill maintains state)

**Mechanism**: Two layers working together:
- **SessionStart hook**: creates channel dir + stub estimate (infrastructure)
- **/delegate skill**: reads, updates, and extracts the estimate (maintenance)
- **Optional PreToolUse on Agent**: lightweight "does estimate exist?" check
  that denies with corrective context if somehow missing

**Barrier analysis — would it have prevented the incident?**

| Question | Answer |
|----------|--------|
| Would it have created the running estimate before the first subagent? | **YES** — SessionStart hook guarantees it. |
| Would it have prevented AAR files going to scratch? | **PARTIALLY** — channel dir exists (hook created it). Subagents still need to be told to use it (via /delegate briefing). If agent bypasses /delegate, subagents don't know about channel. But: the channel dir EXISTS, so if any process (hook, skill, manual) writes there, it works. |
| Would it have provided carry-forward to the relaunched session? | **YES** — if SessionEnd archival (channel-archive.sh) is also implemented. The estimate is in channel (created by hook), updated by /delegate, archived by SessionEnd hook. Full pipeline. |
| Failure modes | (a) Agent bypasses /delegate — estimate exists but is stale (stub values never updated). Better than no estimate, but the stub is misleading if it says "currentState: Plan execution starting" 15 delegations later. (b) More moving parts — two artifacts (hook + skill) must stay in sync. (c) The PreToolUse layer adds marginal value if SessionStart already created everything. |

---

## 3. Decision #20 Analysis: One Hook or Many?

### The question

Decision #20 says: "One hook per feature — new hooks for new capabilities,
never conflate."

The user said: "the same hook can clean up old files" — suggesting
`channel-init.sh` should also prune stale channel dirs and create the
estimate stub.

Is this a violation of decision #20?

### Analysis

**What is the "feature"?** The feature is **channel readiness** — ensuring
the channel infrastructure is in a usable state when the session starts.
This has three sub-operations:

1. **Create**: `mkdir -p .aitools/channel/session-XXX/`
2. **Prune**: Remove channel dirs older than 24h (orphans from crashed sessions)
3. **Seed**: Write stub running estimate JSON

**Comparison with scratch-init.sh**: The existing `scratch-init.sh` hook
already combines create + prune in one script (lines 27-34: prune stale,
lines 37-40: create new). This is accepted practice. Nobody filed an
incident against scratch-init.sh for combining these.

**The current plan separates them**: Decision #36 component 10 proposes
`channel-init.sh` (create) and `channel-prune.sh` (prune) as separate
hooks. This was the strict reading of decision #20.

**The user override**: The user explicitly said combining is acceptable for
this case. The rationale: channel creation, pruning, and estimate seeding
are one concern — "channel readiness." They share the same trigger
(SessionStart), the same directory tree (`.aitools/channel/`), and the same
failure domain (if any fails, the channel is not ready).

### Verdict

**Not a violation.** Decision #20's rationale is: "One hook doing 5 things
= one bug breaks 5 features." Channel readiness is one feature. The
sub-operations (create, prune, seed) are steps in achieving that feature,
not independent features. A bug in pruning does not break creation (they
are sequential, independent operations with separate error handling).

**Precedent**: scratch-init.sh combines create + prune. The proposed
channel-init.sh should follow the same pattern.

**Recommended update to decision #20**: Add an exception note: "Operations
on the same directory tree with the same trigger and same failure domain
may be combined. Example: scratch-init.sh (create + prune), channel-init.sh
(create + prune + seed)."

**Recommended update to decision #36**: Merge `channel-init.sh` and
`channel-prune.sh` into one `channel-init.sh` hook. Reduce F18's new hook
count from 8 to 7.

---

## 4. Recommendation

### Primary recommendation: Option 4 (Combination), simplified

**Two artifacts, two layers:**

1. **`channel-init.sh` (SessionStart hook)** — structural enforcement
   - Creates `.aitools/channel/session-XXX/`
   - Writes `.aitools/channel/.current-session`
   - Prunes channel dirs older than 24h
   - Seeds a stub running estimate: `{timestamp}_s3_running-estimate.json`
   - Outputs context to agent: "Channel dir: {path}. Running estimate: {path}. Use /delegate for all subagent launches."
   - Pattern: identical to scratch-init.sh (proven, ~5ms, zero overhead concern)

2. **`/delegate` skill** — behavioral maintenance
   - Before delegation: reads estimate, updates situation/findings/conclusions, extracts subset for briefing
   - After delegation: updates delegation log, absorbs findings
   - The estimate goes from "stub" to "useful" through /delegate usage

**Do NOT add a PreToolUse hook for this.** Rationale:
- SessionStart already guarantees the infrastructure exists
- PreToolUse cannot inject context into the Agent call (only deny/allow)
- PreToolUse would add latency to every Agent call for marginal value
- The existing `block-explore-agent.sh` (decision #5) already occupies the PreToolUse:Agent slot for enforcement
- Adding another PreToolUse:Agent hook risks composition bugs (two hooks both returning JSON on the same event)

### Why this combination, specifically

Replaying the incident with this combination:

```
Timeline with proposed mechanism:
1. Session starts
2. channel-init.sh fires (SessionStart)
   → .aitools/channel/session-XXX/ created
   → stub running-estimate.json created
   → Agent sees: "Channel dir: ..., Running estimate: ..., Use /delegate"
3. S3 receives context injection about channel + estimate
4. S3 uses /delegate for first subagent
   → /delegate reads stub estimate, updates it, extracts for briefing
   → Subagent receives delegation briefing with estimate extract
   → Subagent writes AAR to channel dir (told by briefing)
5. S3 uses /delegate for second subagent
   → /delegate reads updated estimate (version 2), includes prior results
   → Carry-forward is structural, not ad-hoc
...
15. Session crashes or is relaunched
   → Running estimate is in .aitools/channel/ (survived)
   → channel-archive.sh (SessionEnd) archives to .aitools/harvesting/
   → Next session: S2 reads archived estimate at plan start
```

**Barrier effectiveness for each failure in the incident:**

| Failure | Barrier | Effective? |
|---------|---------|------------|
| No channel directory | channel-init.sh creates it | **YES** — structural, cannot be bypassed |
| No running estimate | channel-init.sh seeds it | **YES** — structural, cannot be bypassed |
| AAR files go to scratch | Delegation briefing says "write to channel dir" | **PARTIAL** — requires /delegate usage. If bypassed, AAR goes to scratch. But channel dir EXISTS, so manual recovery is possible |
| Ad-hoc carry-forward | /delegate reads estimate, injects structured extract | **PARTIAL** — requires /delegate usage. If bypassed, carry-forward is ad-hoc. But estimate EXISTS, so any process can read it |
| State lost on relaunch | channel-archive.sh archives estimate | **YES** — if SessionEnd fires. Crash without SessionEnd = estimate survives until next prune (24h) |
| Agent bypasses /delegate | Context injection says "Use /delegate" | **PARTIAL** — behavioral. Future: block-explore-agent.sh could be extended to warn when Agent is used without /delegate (but that is a separate investigation) |

### Remaining gap: /delegate bypass

The one failure mode this combination does NOT fully prevent is S3
using raw Agent tool instead of `/delegate`. The estimate exists (hook
created it), but remains stale (nobody updated it).

Possible future enforcement for this gap:
- **Stop hook** (aar-reminder.sh pattern): detect Agent tool usage
  without /delegate, nudge agent
- **PreToolUse on Agent**: deny if estimate version is stale (has not
  been updated since last delegation completed). But this adds the
  latency/retry problems analyzed above.
- **Rule in delegation.md**: "Never use raw Agent tool for plan
  delegations. Always use /delegate." — behavioral but in context.

Recommendation: Start with the rule (prevention layer). The SessionStart
hook (detection layer) ensures the infrastructure exists. If /delegate
bypass becomes a pattern, escalate to a PreToolUse hook.

### Implementation priority

```
Phase 1 (immediate — enables all other work):
  channel-init.sh (SessionStart hook)
  - Create channel dir + prune + seed estimate
  - Follows scratch-init.sh pattern exactly

Phase 2 (with /delegate skill implementation):
  /delegate skill reads and updates the estimate
  - Component 3 of delegation duty uses estimate fields
  - Delegation log maintained in estimate

Phase 3 (with SessionEnd pipeline):
  channel-archive.sh (SessionEnd hook)
  - Archives estimate to .aitools/harvesting/
  - Enables cross-session carry-forward
```

---

## 5. Summary of Findings

| Finding | Detail |
|---------|--------|
| **Most effective structural enforcement** | SessionStart hook (channel-init.sh) — creates infrastructure unconditionally, proven pattern, ~5ms, user accepted overhead |
| **Most effective behavioral maintenance** | /delegate skill — reads, updates, extracts estimate as part of delegation duty |
| **Least effective standalone** | /delegate skill alone — bypassed in exactly the incident we are analyzing |
| **PreToolUse hook** | Not recommended — cannot inject context, adds latency, marginal value over SessionStart |
| **Decision #20 verdict** | Combining channel-init + prune + estimate-seed is NOT a violation — one feature (channel readiness), one trigger, one failure domain. Precedent: scratch-init.sh |
| **Remaining gap** | /delegate bypass — mitigate with rule (prevention), escalate to hook if pattern recurs |

---

## Sources Consulted

- `shared/hooks/scratch-init.sh` — existing SessionStart hook pattern
- `shared/hooks/block-claude-code-guide.sh` — existing PreToolUse:Agent pattern
- `plans/mission-command-briefing/planning-brief.json` — decisions #5, #20, #22, #36
- `.scratch/session-uyZ7TELqpP/carry-forward-design.md` — running estimate schema and lifecycle
- Claude Code hooks documentation (code.claude.com/docs/en/hooks.md) — PreToolUse contract: allow (no output) or deny (JSON with permissionDecision)
