# Investigation: Nested Agent Spawning in Claude Code

**Date**: 2026-03-26
**Session**: dfbc4091-e
**Question**: Can Claude Code agents (launched via the Agent tool) themselves launch further agents?

## Verdict

**No. Subagents cannot spawn other subagents.** This is an intentional design constraint enforced by Claude Code, not a configuration issue. Nesting depth is strictly limited to 2 levels.

## Evidence

### 1. Official Documentation (code.claude.com/docs/en/sub-agents.md)

Three explicit statements:

- **Line 52** (Plan subagent description): "This prevents infinite nesting (subagents cannot spawn other subagents) while still gathering necessary context."
- **Line 308** (Agent tool restriction): "If `Agent` is omitted from the `tools` list entirely, the agent cannot spawn any subagents. This restriction only applies to agents running as the main thread with `claude --agent`. Subagents cannot spawn other subagents, so `Agent(agent_type)` has no effect in subagent definitions."
- **Line 679** (Best practices note): "Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."

### 2. Empirical Test

Launched a general-purpose subagent (which the system prompt claims has `Tools: *`) and asked it to report available tools and attempt to spawn a sub-subagent:

**Result**: The Agent tool was NOT present in the subagent's tool inventory. Available tools were: Bash, Edit, Glob, Grep, Read, Write, Skill, ToolSearch, plus deferred tools (Task*, WebFetch, WebSearch, NotebookEdit, Cron*, Worktree*, chrome-devtools MCP). The Agent tool is stripped at the platform level regardless of the `Tools: *` declaration.

### 3. Tool-Ops Registry (tool-ops.json)

No deny rules or governance modes related to nested agent spawning. The only Agent-related deny rule blocks the `claude-code-guide` subagent (Haiku accuracy issue, incident #34730). The nesting restriction is upstream in Claude Code itself, not configurable via hooks or deny rules.

### 4. Harness Documentation (aitool-continue, handoff, planning skills)

The harness documents "recursive delegation with no depth limit" as a design principle — but this refers to the *conceptual* delegation duty (each delegating agent carries forward operational learning). It does NOT override the Claude Code platform constraint. The practical limit noted in the harness ("~2-3 levels") matches the actual hard limit of 2.

## Architecture

```
Level 0: Main thread (interactive session or `claude --agent <name>`)
         → CAN spawn subagents via Agent tool
         → CAN use Agent(type) to restrict which subagent types

Level 1: Subagents (spawned via Agent tool)
         → CANNOT spawn sub-subagents
         → Agent tool is stripped from their tool inventory
         → Agent(agent_type) in subagent definitions has no effect
```

## The `--agent` Flag Distinction

When you run `claude --agent coordinator`, the "coordinator" agent definition becomes the MAIN THREAD — it replaces the default system prompt. Since it IS the main thread (not a subagent), it CAN spawn subagents. But those subagents still cannot go deeper.

This enables a coordinator pattern:
```yaml
name: coordinator
description: Coordinates work across specialized agents
tools: Agent(worker, researcher), Read, Bash
```

The coordinator runs as main thread and can delegate to `worker` and `researcher` subagents. But `worker` and `researcher` cannot delegate further.

## Documented Workarounds

### 1. Skills (run in main conversation context)
Skills execute in the main conversation, not in isolated subagent context. A skill can access the full tool set including Agent. However, skills are prompt injections, not isolated execution — they share context with the main conversation.

### 2. Chain Subagents (sequential delegation from main)
The main conversation spawns Agent A, gets result, then spawns Agent B with A's result as context. This simulates depth through sequential breadth:
```
Main → Agent A (research) → result → Main → Agent B (implement using A's findings)
```

### 3. Agent Teams (experimental, separate instances)
Multiple independent Claude Code instances coordinating via shared task list and direct messaging. Each teammate is a full session that CAN spawn its own subagents. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag. Higher token cost.

## Harness Implications

1. The harness's "recursive delegation" principle (aitool-continue, handoff skills) is aspirational — the platform caps depth at 2. The principle governs *how* delegation happens (carry forward context, operational learning), not *how deep*.

2. The `Tools: *` declaration for general-purpose agents in the system prompt is misleading — the Agent tool is actually stripped at the platform level for all subagents regardless of declared tool access.

3. The tool-ops registry has no entry for this constraint because it's not configurable. It's a hard platform limit, not a governance mode that could be promoted from audit to active.

## Sources

- Official docs: code.claude.com/docs/en/sub-agents.md (read via chrome-devtools)
- Official docs: code.claude.com/docs/en/agent-teams.md (read via chrome-devtools)
- Tool-ops registry: reference/tool-ops.json
- Tool-ops reference: reference/tool-ops-claude-code.md
- Empirical test: general-purpose subagent launched in this session
