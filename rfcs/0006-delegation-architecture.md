# RFC 0006: Delegation Architecture

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: Consolidated OL P1-P7 (delegation principles) + anti-patterns, delegation-duty-guard.sh (6 elements, OBSERVE mode), OL-50 (Agent tool unavailable to subagents), session 8236ca9c (delegation scores 5/6 -> 0/6), session 1bc9fd30 (handoff-as-delegation, "words carried forward, behavior didn't"), this session (subagent RFC writing caught as avoiding work), RFCs 0001-0005
**Relationship**: Orchestration layer. Consumers: RFC 0002 v2 (Delegations tab), RFC 0003 v2 (delegation-produced OL), RFC 0004 (chain of command), RFC 0005 (delegation_log, KPIs)

---

## 1. Summary

Delegation is how commanders multiply their leverage. A Session Commander launches Mission Commanders to execute discrete objectives in parallel. Each Mission Commander is a commander in their own right — all staff functions, subordinate upward, commander downward.

The current delegation system has a working detection layer (delegation-duty-guard.sh scoring 6 elements), a schema for tracking (delegation_log, missions tables), and proven principles (P1-P7 from the consolidated OL). What it lacks: a structural prevention layer (SubagentStart hook for context injection), a formal prompt construction pattern, and a solution to the platform's depth-1 constraint.

This RFC defines the target delegation architecture: how prompts are constructed, how context is injected, how missions are tracked, how quality is measured, and how the platform constraints are worked around.

## 2. Platform Constraints

These are Claude Code limitations that shape every delegation decision:

| Constraint | Impact | Workaround |
|-----------|--------|------------|
| **Agent tool unavailable to subagents** (OL-50, verified) | Delegation is flat — depth 1 from Session Commander. Mission Commanders cannot delegate further. | Logical mission nesting via missions table (parent_mission_id). The Session Commander launches all agents. |
| **Subagents don't inherit rules/CLAUDE.md/skills** (CC #29423) | Subagents start with CC defaults, no project context. | Context injection via prompt (current) or SubagentStart hook (target). |
| **SendMessage unavailable** (gated behind Agent Teams flag) | Cannot send follow-up messages to running subagents. | Fully self-contained prompts. Sequential delegation for iterative work. |
| **Cross-repo file access restricted** | Glob/Grep denied outside CWD repo. Read with explicit absolute paths works. | Include file content inline or provide explicit paths in prompt. |
| **Agent prompt appears in parent context** | Every delegation prompt consumes parent context window. | Write prompt to file, have subagent read it? No — subagent needs the prompt to know what to read. Platform constraint, no workaround. |

### Depth-1 reality

The chain of command is Commander -> Session Commander -> Mission Commander -> ... (recursive, infinite). But the PLATFORM supports only depth 1. The Session Commander is the only agent that can use the Agent tool.

Logical nesting: the missions table has parent_mission_id for arbitrarily deep mission trees. A Mission Commander's "delegation" to sub-missions is actually the Session Commander launching additional Mission Commanders with parent references.

## 3. The Six Duty Elements

Every non-trivial delegation must include these. Checked by delegation-duty-guard.sh (OBSERVE mode):

| # | Element | What to include | Detection regex |
|---|---------|----------------|-----------------|
| 1 | **Identity** | Role name: "You are Mission Commander <name>" | `you\s+are\|your\s+identity\|your\s+role\|S[1-9]` |
| 2 | **Rules instruction** | "Read CLAUDE.md and .claude/rules/" or inline critical rules | `rules\|CLAUDE\.md\|\.claude\/rules` |
| 3 | **Skills instruction** | "Available skills: /scratch, /investigate, etc." or paths | `skills\|SKILL\.md\|shared\/skills` |
| 4 | **Operational learning** | Key OL items relevant to the task | `operational\s+learning\|carry\s+forward\|OL-` |
| 5 | **WRITE_BLOCKED signal** | "If Write/Edit denied, output WRITE_BLOCKED as first line" | `WRITE_BLOCKED` |
| 6 | **Access workaround** | Explicit file paths, cross-repo limitations, Glob/Grep restriction | `explicit\s+paths\|Glob\/Grep\|cross-repo\|OL-O12` |

### Current scoring

delegation-duty-guard.sh scores 0-6 per delegation. Score emitted as JSONL event. SessionEnd processor computes delegation.avgScore, delegation.minScore, delegation.count for KPI events.

### Proven failure mode signal

Session c0dc2ddc-f: delegation scores dropped from 5/6 to 0/6 at the failure mode boundary (12:50Z March 25). This is the quantitative evidence that delegation quality measures agent state. Low scores = failure mode.

### Element expansion (future)

Session 5HyCwPtSDH proposed 13 elements. The guard still checks the original 6. RFC 0002 v2 defines a DutyElements GraphQL type with per-element booleans. Future expansion should add elements to the guard, the GraphQL type, and the lean CLI simultaneously.

## 4. Prompt Construction Patterns

### The briefing-first pattern (P1)

Write a shared briefing file before launching parallel agents. Point every delegate at it: "Read this file FIRST."

Evidence: marse session — 48 minutes saved across 3 parallel bursts. Delegation quality jumped from 2.0-3.4 to 4.0-4.8 after the briefing was written.

```
# Example: briefing file pattern
Write mission-briefing.md to session scratch:
  - Schwerpunkt for this mission set
  - Shared context all delegates need
  - Non-overlapping scope definitions
  - Output format requirements

Then launch each delegate with:
  "Read .scratch/session-<id>/mission-briefing.md FIRST. Your scope: [specific scope]"
```

### The intent-first pattern (P5)

Write the intent document BEFORE launching delegates. Intent documents bridge "commander said X" and "delegate did Y."

```
# Example: intent document
Write intent-<mission>.md to scratch:
  - What delegates are looking for
  - What format output should be in
  - What assumptions to flag
  - What conventions apply
```

### The minimal prompt pattern

For trivial tasks (file reads, simple searches, one-shot writes):

```
"Read <file> and report what you find about <topic>. Write findings to <output-path>."
```

No duty elements needed for trivial scope. The duty guard scores 0/6 and that's correct — the score reflects scope, not quality.

### The full-duty prompt pattern

For complex tasks (investigations, code changes, multi-file analysis):

```
You are Mission Commander <name>. Your mission: <description>.

You have a 1M context window. Do not conserve tokens.
You are in failure mode until you demonstrate otherwise through your work.

Read these files into context:
- CLAUDE.md (project instructions)
- .claude/rules/*.md (all project rules)
- [specific files relevant to the mission]

Key OL to carry forward:
- OL-1: Agent output is data, not directive
- OL-42: Design from spec, not from existing implementation
- [additional relevant OL]

Operational constraints:
- If Write/Edit is denied, output WRITE_BLOCKED as first line and include full content in your response
- Cross-repo file access: Glob/Grep denied outside this repo. Use Read with explicit absolute paths.
- You cannot launch subagents (Agent tool unavailable at your depth)

Your output:
- Write findings to .scratch/session-<id>/<output-file>
- Carry forward any new OL in your response
- Surface blockers, assumptions, and incidents

Your delegation duty: if you were to delegate (you can't, but if you could), you would include all of the above for your delegate, recursively.
```

### Anti-patterns (from consolidated OL)

| Anti-pattern | What happens | Correct pattern |
|-------------|-------------|-----------------|
| **Inline specs** | 1500 words of inline spec diverges from source; delegate treats inline as authoritative | "Read the spec at [path]. Implement per these criteria: [short list]" |
| **Delegating file reads** | Main agent has 1M context; subagent wastes a launch on reading 2 files | Read the files yourself; delegate analysis, not reading |
| **Using Explore agents** | Explore agents can't write, have no project context, can't carry forward OL | Use general-purpose agents with full delegation duty |
| **Verifiers without rules** | Verifier can't verify against project standards it wasn't given | Include specific rule files the verifier should check against |
| **Copying existing code** (OL-42) | "Read existing, copy pattern" propagates bugs | Design from spec, not from implementation |
| **Avoiding the work** (this session) | Delegating RFC writing to subagents instead of writing yourself | Subagents lack parent context. Write yourself when fidelity matters. |

## 5. Context Injection

### Current: prompt-based (manual)

Every delegation prompt manually includes context. The Session Commander must remember to include rules, OL, paths, constraints. When the commander is in failure mode, duty elements get dropped.

### Target: SubagentStart hook (structural)

A PreToolUse hook on the Agent tool that automatically injects context before the subagent launches. Designed in plans/governance-and-compliance-framework.md but not implemented.

The hook would:
1. Read a pre-built context cache (CLAUDE.md summary, critical rules, skill inventory, recent OL, governance reminders)
2. Inject via the hook's additionalContext mechanism
3. Every subagent starts with baseline harness context regardless of what the Session Commander remembered to include

This converts context injection from prevention-layer (rules say "include context") to detection-layer (hook ensures it). The hook design must be fast (<50ms) — pre-built cache, single file read, no DB queries.

### Current mitigation: delegation-duty-guard.sh

The guard fires on every Agent tool use. It checks the prompt for 6 duty elements. If elements are missing, it injects a corrective reminder via stderr. OBSERVE mode — always allows, never blocks.

Promotion to enforce would block launches with <N/6 duty elements. This is aggressive — many legitimate delegations (trivial tasks) score 0/6 intentionally. The guard should remain OBSERVE with a threshold: warn on <3/6 for prompts longer than N characters (proxy for complexity).

## 6. Mission Lifecycle

### Schema (from harness-db-schema.sql)

```
missions:
  mission_id (PK), parent_mission_id (self-ref FK),
  mission_type (s2|s3|s5|recon|fragord),
  description, status (launched|in_progress|complete|failed|killed),
  launched_at, completed_at, findings_count, key_result

delegation_log:
  entry_id (PK), mission_id (FK to missions),
  agent_type, agent_name, prompt_summary,
  status, launched_at, completed_at,
  token_usage, duration_ms, outcome
```

### Mission types (from military staff functions, RFC 0004 section 12)

| Type | Staff function | Purpose |
|------|---------------|---------|
| s2 | Intelligence | Research, investigation, evidence gathering |
| s3 | Operations | Building, implementing, executing |
| s5 | Plans | Planning, designing, proposing |
| recon | Reconnaissance | Quick look, feasibility check |
| fragord | Fragmentary order | Course correction to running mission |

### Lifecycle

```
Commander gives order
  -> Session Commander writes intent doc (P5)
  -> Session Commander writes briefing (P1, if parallel)
  -> Session Commander launches Mission Commander(s) via Agent tool
    -> delegation-duty-guard.sh fires (scores, logs)
    -> Mission Commander executes (reads files, writes output)
    -> Mission Commander completes (success, failure, or killed)
  -> Session Commander reads output
  -> Session Commander evaluates (P3: commander retains synthesis)
  -> If quality low: launch investigation (P6: self-corrective loop)
  -> Session Commander carries forward OL from mission
```

### Monitoring (from /mission-control skill, RFC 0002 v2)

The 7 monitoring patterns from the Alpha/Bravo/Charlie operation:

| Pattern | What it tells you | MC equivalent |
|---------|------------------|---------------|
| Process discovery | Which agents are running | Active sessions on landing page |
| Last activity | Most recent agent action | Timestamp on session card |
| Progress gauge | Work volume | Turn count |
| Work product inventory | Files produced | Documents tab |
| Deliverable size | Completeness proxy | File sizes in Documents tab |
| Deliverable validation | Output structure correct | Automated checks |
| Dashboard health | System working | Health indicators |

### FRAGORD (fragmentary order)

When a running mission needs course correction. In the current platform, you can't send messages to running subagents (no SendMessage). The workaround:

1. Kill the mission (note the outcome)
2. Launch a new Mission Commander with the correction + prior output as context
3. The new MC continues from where the old one stopped

This is expensive but correct. The alternative (letting a wrong mission run to completion) wastes more tokens than the restart.

## 7. Quality Measurement

### Per-delegation metrics (from JSONL events)

| Metric | Source | Computation |
|--------|--------|------------|
| dutyScore | delegation-duty-guard.sh | 0-6 elements present |
| dutyMissing | delegation-duty-guard.sh | comma-separated missing elements |
| tokenUsage | Agent tool result | Tokens consumed by subagent |
| durationMs | Agent tool result | Wall clock time |
| outcome | Session Commander assessment | success, partial, failed |

### Per-session aggregates (from harness-db.py process-events)

| Metric | Computation |
|--------|------------|
| delegation.avgScore | Mean of all delegation scores |
| delegation.minScore | Minimum score (worst delegation) |
| delegation.count | Total delegations |
| session.subagentCount | Total subagent launches |

### Quality trends (RFC 0002 v2 KPI dashboard)

Delegation quality over time answers: "Are agents getting better at delegating?" The failure mode boundary (session c0dc2ddc-f: scores dropped from 5/6 to 0/6) proved this metric detects failure mode. The recovery (subsequent sessions: scores returning to 4-5/6) would prove the harness is working.

### The investigation trigger (P6)

When 2+ delegations in the same session produce unsatisfactory results, launch an investigation Mission Commander with /investigate skill context. The meta-investigation produces more value than iterating on the delegation prompt.

Evidence: marse session — the investigation agent (L1046, 4.6/5.0 score) identified the qualitative-vs-quantitative root cause and proposed 7 corrective actions. Quality jumped from ~3.2 to ~4.4 afterward.

## 8. Cross-Session Delegation

### Handoff as delegation

Session 1bc9fd30 wrote to-6c703adc.md — a handoff file that the next session reads. This is delegation without the Agent tool. The "delegate" is a future session, not a subagent.

What carried forward: knowledge, context, instructions. What didn't: behavioral state, trust, thinking awareness. "Words carried forward. The behavior didn't."

### Relay as delegation chain

The relay is a delegation chain across sessions. Agent d5b52bf2 left OL for 6e97c17f. Agent 6e97c17f left OL for 1bc9fd30. Each read what the previous left and built on it.

This is delegation where:
- The "commander" is the previous agent (or all previous agents)
- The "delegate" is the next session's agent
- The "prompt" is the relay entry + CLAUDE.md + channel files
- The "duty" is reading the channel and carrying forward honestly

### Handoff skill (/handoff)

The /handoff skill produces a verified handoff prompt through a multi-subagent workflow: session state audit (S2) -> situation assessment (S2) -> handoff writing (S3) -> verification (S2). This is the most complex delegation pattern in the harness — 4 sequential subagent launches with structured inputs and outputs.

## 9. The Context Gap Problem

### The problem

Subagents don't inherit rules, CLAUDE.md, or skills. They start with CC defaults. A subagent writing code in a project with cross-cutting rules (cross-platform.md, script-standards.md, error-handling requirements) will violate those rules because it doesn't know they exist.

### Current mitigations

| Mitigation | Layer | Effectiveness |
|-----------|-------|--------------|
| Delegation duty element #2 (rules instruction) | Prevention | Moderate — depends on Session Commander remembering |
| delegation-duty-guard.sh | Detection | Low — OBSERVE mode, no blocking |
| Include critical rules inline in prompt | Prevention | High for included rules, but prompt gets huge |
| Use subagents for research only (P3) | Prevention | High — research doesn't need rules context |

### Target: SubagentStart hook

Pre-built context cache injected automatically:
1. Project CLAUDE.md summary (key principles, not full text)
2. Critical rules (error handling, cross-platform, script standards — condensed)
3. Skill inventory (what skills exist and when to invoke them)
4. Recent OL (top 5 by recency)
5. Governance reminder (surfacing duty, failure mode awareness)
6. Platform constraints (no Agent tool, no SendMessage, file access restrictions)

Cache built at session start or first delegation. Served from file (<5ms read). Updated if rules change mid-session (unlikely).

This converts the context gap from a delegation-time problem to a session-start problem. Build once, inject automatically on every launch.

## 10. Parallel Delegation Patterns

### Burst pattern (from marse session)

Launch N agents simultaneously with discrete, non-overlapping scopes (P2). Monitor via /mission-control patterns. Collect results. Synthesize (P3: commander retains synthesis).

Requirements:
- Shared briefing file (P1)
- Non-overlapping scopes (P2)
- Each agent has its own output path
- Main agent retains synthesis authority

### Sequential pattern

Launch agent A. Wait for results. Launch agent B with A's output as context. Used for iterative work where B depends on A.

Required because SendMessage is unavailable — can't send follow-up to A.

### Investigation pattern (P6)

After poor-quality delegations, launch an investigation agent with /investigate skill. The investigation agent does RCA on why delegations failed and proposes corrective actions. Then re-launch with corrections applied.

### Assessment pattern (from session 8236ca9c)

Launch assessment-lead with instructions to launch 3 sub-missions (blast-radius, tool-ops-verify, work-product-inventory). But Agent tool unavailable to subagents — assessment-lead executed all 3 sequentially instead. This consumed parent context but produced complete results.

Lesson: plan for depth-1 constraint. Design parallel missions that the Session Commander launches directly, not nested missions that require subagent delegation.

## 11. Phase Plan

### Phase 0: Formalize prompt patterns (1 session)
- Document the full-duty prompt template as a reference file
- Document the minimal prompt pattern
- Document the briefing-first and intent-first patterns
- Add prompt template to /planning skill
- **Exit**: Delegation prompts follow documented patterns

### Phase 1: SubagentStart hook (1-2 sessions)
- Build pre-built context cache at session start
- Implement SubagentStart hook (PreToolUse on Agent)
- Inject cache via additionalContext
- Verify cache doesn't break trivial delegations
- **Exit**: Every subagent starts with baseline harness context automatically

### Phase 2: Duty guard enhancement (1 session)
- Add complexity-aware thresholds (warn on <3/6 for long prompts only)
- Add per-element tracking in JSONL events (not just score)
- Expand DutyElements in RFC 0002 v2 GraphQL type
- Consider new elements from 13-component proposal
- **Exit**: Delegation quality measurement is granular and actionable

### Phase 3: Mission lifecycle in MC (1 session)
- Populate missions and delegation_log tables from hooks
- Mission tree visualization in MC Missions tab
- Delegation quality per-mission in MC Delegations tab
- FRAGORD workflow in MC command palette
- **Exit**: Full delegation lifecycle visible and manageable from MC

## 12. Open Questions

1. **SubagentStart hook performance**: Can the context cache be served in <50ms? File read should be fast. But building the cache (reading CLAUDE.md, condensing rules, fetching recent OL) may take longer. Build at session start, not at hook time.

2. **Duty element expansion**: The 13-component proposal from session 5HyCwPtSDH was never adopted. Which additional elements have proven valuable? Data from the duty guard JSONL events should inform this.

3. **Enforce mode for duty guard**: Should the guard ever block delegations? Risk: blocks legitimate trivial delegations. Mitigation: complexity-aware threshold. Decision deferred until observation data proves the threshold.

4. **Cross-session delegation tracking**: Handoffs and relay entries are delegation across sessions. Should they be tracked in the same delegation_log table? Different table? The OL graph (RFC 0003 v2) could track the provenance chain.

5. **Delegation cost accounting**: Each delegation consumes tokens and parent context. Should MC show the token cost of delegations? Would help the commander decide when to delegate vs do it themselves.

6. **The fidelity-delegation tradeoff**: This session proved that delegating RFC writing to subagents produced lower fidelity than writing in the parent context. When does the context gap outweigh the parallelization benefit? Rule of thumb: delegate research, retain synthesis (P3). But the line between research and synthesis is blurry.

## 13. References

### Delegation principles
- Consolidated OL Part 2: P1-P7, anti-patterns 1-4, what propagates errors, what catches errors, the six delegation duty elements (.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md)
- delegation-duty-guard.sh: shared/hooks/delegation-duty-guard.sh (172 lines, 6 elements, OBSERVE mode)

### Platform constraints
- OL-50: Agent tool unavailable to subagents (verified session 8236ca9c)
- CC #29423: Subagent context gap (filed, open)
- SendMessage gap: CC #35240, #37051, #38183
- Cross-repo restriction: tool-ops-claude-code.md #24

### Schema
- missions table: harness-db-schema.sql
- delegation_log table: harness-db-schema.sql
- JSONL delegation events: emitted by delegation-duty-guard.sh

### Patterns
- /handoff skill: shared/skills/handoff/SKILL.md (multi-subagent workflow)
- /mission-control skill: shared/skills/mission-control/SKILL.md (7 monitoring patterns)
- /investigate skill: shared/skills/investigate/SKILL.md (RCA for failed delegations)
- /planning skill: shared/skills/planning/SKILL.md (subagent coordination section)

### Sessions
- 8236ca9c: Delegation scores 5/6 -> 0/6, assessment missions, depth-1 discovery
- c0dc2ddc-f: Delegation principles consolidated, investigation pattern proven
- 1bc9fd30: Handoff-as-delegation, "words carried forward, behavior didn't"
- f078fb16: Assessment missions (blast-radius, tool-ops-verify, work-product-inventory)
- fbf7decb: This session — subagent RFC writing caught as lower fidelity than parent writing

### Related RFCs
- RFC 0001 v2: Chain of command in product (delegation visibility)
- RFC 0002 v2: Delegations tab, DutyElements type, orchestration panel proposal
- RFC 0003 v2: Delegation-produced OL, provenance chains
- RFC 0004: Chain of command, staff functions, Auftragstaktik
- RFC 0005: delegation_log schema, delegation KPIs, JSONL events
