## Update: `Agent(Claude Code Guide)` deny rule does not work

### Finding

The deny rule `"Agent(Claude Code Guide)"` deployed in corrective action #3 (commit 46c93b3) **does not block the subagent**. Verified by invoking `claude-code-guide` — it ran successfully and returned 43K tokens of (partly hallucinated) content despite the deny rule being present in `~/.claude/settings.json`.

### Root cause

**Pattern mismatch**: The deny rule uses `Agent(Claude Code Guide)` (display name with spaces), but the [official docs](https://code.claude.com/docs/en/sub-agents.md) state the pattern must match the subagent's **name field**. The internal identifier is `claude-code-guide` (lowercase, hyphenated), not "Claude Code Guide".

Additionally, upstream issues [#25000](https://github.com/anthropics/claude-code/issues/25000) and [#6699](https://github.com/anthropics/claude-code/issues/6699) document that subagent deny rules may be bypassed entirely, so even with the corrected pattern, the deny mechanism may not be reliable.

### Fix implemented

**Defense in depth** — both layers:

1. **Fixed deny pattern**: `Agent(Claude Code Guide)` → `Agent(claude-code-guide)`
2. **Added PreToolUse hook on Agent tool**: A command hook with matcher `Agent` that checks `tool_input.subagent_type` and exits with code 2 (block) when the value is `claude-code-guide`. This is the structural fix — the [hooks docs](https://code.claude.com/docs/en/hooks.md) explicitly support `PreToolUse` blocking on the `Agent` tool.

**Verified**: After deploying the hook, invoking `claude-code-guide` returns:
```
PreToolUse:Agent hook error: Blocked: claude-code-guide subagent is denied.
It returns inaccurate schema information (see issue #34730).
Use the chrome-devtools skill to read official docs at code.claude.com/docs/en/*.md instead.
```

### Note for the Claude Code team

The `SubagentStart` event [explicitly cannot block](https://code.claude.com/docs/en/hooks.md#subagentstart) subagent creation. Users who want to deny a built-in subagent via hooks must use `PreToolUse` on the `Agent` tool instead, which is not immediately obvious. The `permissions.deny` mechanism with `Agent(name)` syntax would be the natural way to do this, but it doesn't appear to work for built-in subagents (at minimum, the docs could clarify whether the name should match the display name or the internal identifier).
