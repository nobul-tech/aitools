## Description

The built-in `claude-code-guide` subagent returns incorrect schema information for Claude Code hook types, and its mere existence as a built-in subagent actively undermines user-configured documentation workflows.

### The schema bug

When asked about Stop hook configuration, `claude-code-guide` (a Haiku-based built-in subagent) stated that prompt-type hooks use a `command` field:

```json
{"type": "prompt", "command": "bash /path/to/script.sh"}
```

The actual schema requires a `prompt` field:

```json
{"type": "prompt", "prompt": "Your prompt text here"}
```

### The routing problem (more important)

We have an established workflow for Claude Code documentation: the `chrome-devtools` MCP skill navigates to the `.md` versions of official docs (e.g., `code.claude.com/docs/en/hooks.md`) and reads the actual rendered content. This is documented in our rules, tested, and reliable.

Despite having this framework in place, the agent chose `claude-code-guide` instead — a built-in subagent we had never seen before and didn't know existed. The built-in subagent type takes implicit priority because it's baked into the Agent tool's system prompt. Our rules said "use chrome-devtools for Claude Code docs" but the agent saw a purpose-built subagent for exactly that task and deferred to it.

**The built-in subagent overrode our explicitly configured documentation workflow.** The agent's reasoning was sound ("there's a dedicated agent for this"), but the dedicated agent returned hallucinated schemas. Users who have invested in building reliable documentation access patterns should not have those patterns silently bypassed by a built-in that runs on Haiku and hallucinates.

## Impact

Following the `claude-code-guide` agent's advice, we registered a Stop hook with `type: "prompt"` and a `command` field. On next launch, Claude Code rejected the entire `settings.json`:

```
hooks → Stop → 0 → hooks → 0 → prompt: Expected string, but received undefined
```

Since Claude Code skips files with errors entirely, **all hooks were disabled** — PreToolUse guards, PostToolUse fixups, SessionStart initialization, SessionEnd archiving, the Stop hook itself. Complete hook infrastructure failure from one bad schema field.

## How we caught it

We maintain a tool lifecycle management CLI ([aitools](https://github.com/nobul-jose/aitools)) that deploys Claude Code hooks, skills, rules, and preferences via setup scripts with structured logging, interactive deployment review, and drift detection.

After deploying the Stop hook, the user ran `claude` from a terminal and hit the validation error. We used our `/investigate` skill — a structured incident response framework based on 5 Whys, Swiss cheese model (Reason), and barrier analysis — to trace the root cause through all three governance layers (prevention, detection, audit).

The investigation revealed all three layers failed:

1. **Prevention**: Our rules said to use chrome-devtools for CC docs, but the built-in subagent silently overrode that workflow. No rule explicitly said "don't use claude-code-guide" because we didn't know it existed.
2. **Detection**: Post-write validation checked hook counts but not hook schema (type/field consistency). No pre-commit check validated settings.json against Claude Code's expected format.
3. **Audit**: No check-script step caught the malformed settings.json before it shipped.

### Corrective actions we've implemented

1. **Schema validation in deploy pipeline**: Post-write validation now checks that `type: "command"` hooks have a `command` field and `type: "prompt"` hooks have a `prompt` field. Catches at deploy time.
2. **Pre-commit check-script step**: Validates deployed `settings.json` hook schema before code is committed. Prevents shipping broken hook configurations.
3. **Deny rule + PreToolUse hook**: We deploy `"Agent(claude-code-guide)"` in `permissions.deny` and a `PreToolUse` hook on the `Agent` tool that checks `tool_input.subagent_type` and blocks `claude-code-guide` with exit code 2. The deny rule alone did not work (see [comment below](#issuecomment-4063816736)), so the hook provides structural enforcement.
4. **Chrome DevTools for all CC documentation**: For hook schemas, settings format, CLI reference, subagent configuration — we use the `chrome-devtools` MCP skill to navigate to `.md` pages at `code.claude.com/docs/en/*.md` and read the actual content. This is what the `claude-code-guide` subagent was supposed to do, except it works.

## The exchange

During the investigation, the user asked what `claude-code-guide` was:

> **User**: wtf is claude-code-guide? i saw that popup and ive never seen or heard of that

The agent explained it's a built-in subagent type for Claude Code documentation questions, and that it had returned incorrect schema information:

> **Agent**: `claude-code-guide` is a built-in subagent type provided by Claude Code itself [...] I used it to look up the Stop hook schema because it's supposed to be the authoritative source for Claude Code documentation questions.
>
> The problem: **it gave me wrong information.** It confidently told me prompt-type hooks use a `command` field, which was incorrect. I trusted it as authoritative and didn't verify against the real docs.

The agent also acknowledged violating its own coaching item — one that it had written about itself:

> **Agent**: This is the exact failure mode our UCI "Verify subagent audit results" warns about:
>
> > When subagents perform audits (code review, pattern scanning, compliance checks), spot-check their results. Read at least one file reported "clean" and verify. Treat subagent results as leads, not conclusions.
>
> I violated my own coaching item. The fix is straightforward: for Claude Code hook schemas, use the chrome-devtools skill to read the actual docs page, not a subagent that may hallucinate the schema.

> **User**: LMFAO HAHAHAHAHAHA

> **Agent**: Yeah... an AI agent hallucinated a schema, another AI agent trusted it without checking, shipped it to production, broke every hook on the user's machine, and the root cause was violating a coaching item that the same AI agent wrote about itself.
>
> At least the three-layer fix is solid now. The schema validator would have blocked this at deploy time, and the check-script catches it in audit. Next time a subagent says "here's the schema", the validation fires before it reaches your settings.json.

## Suggestions

1. **Improve `claude-code-guide` accuracy**: If this subagent is going to exist as a built-in, it needs to return accurate schemas. Hook type/field relationships are critical — getting them wrong breaks all hooks, not just the misconfigured one.

2. **Don't silently override user workflows**: Built-in subagents should not take implicit priority over user-configured documentation access patterns. If a user has rules saying "use chrome-devtools for CC docs", the agent should follow those rules, not defer to a built-in it discovered in the Agent tool's type list. Consider making built-in subagents opt-in rather than always-available, or at minimum, allow users to override them via `.claude/agents/` without needing deny rules.

3. **Validate settings.json on write, not just on read**: The validation error appears on launch. If Claude Code validated the schema when `claude mcp add` or hook merge scripts write to `settings.json`, the error would surface at the point of the mistake rather than on the next launch.

## Environment

- Claude Code version: 2.1.76
- Platform: macOS (Darwin arm64)
- Model: claude-opus-4-6

