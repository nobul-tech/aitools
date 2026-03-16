# RCA: Agent(Claude Code Guide) deny rule not enforced

**Date**: 2026-03-15
**Detection**: User-requested verification test
**Severity**: High — silent wrong behavior (false sense of security)

## Timeline

```
2026-03-15 T-60m:  Commit 46c93b3 deployed "Agent(Claude Code Guide)" to
                   permissions.deny in setup-user-mcp (bash + PS1)
2026-03-15 T-0:    User asked to verify deny rule works
2026-03-15 T+1m:   Agent invoked claude-code-guide subagent — it ran successfully
2026-03-15 T+2m:   Confirmed: deny rule is a no-op
```

## Evidence gathered

### 1. Current state
- `~/.claude/settings.json` line 85: `"Agent(Claude Code Guide)"` in deny array
- Subagent invoked with `subagent_type: "claude-code-guide"` — executed without block
- Subagent returned 43K tokens of (partly hallucinated) hook schema info

### 2. Official documentation (chrome-devtools, verbatim)

**Permissions docs** (code.claude.com/docs/en/permissions.md):
> Use the format `Agent(subagent-name)` where `subagent-name` matches
> the subagent's **name field**.

Examples given: `Agent(Explore)`, `Agent(my-custom-agent)`

**Sub-agents docs** (code.claude.com/docs/en/sub-agents.md):
> This works for both built-in and custom subagents.

Built-in subagent table shows display name "Claude Code Guide" (with spaces,
mixed case). But the `subagent_type` parameter used in Agent tool calls is
`claude-code-guide` (lowercase, hyphenated).

**Hooks docs** (code.claude.com/docs/en/hooks.md):
- SubagentStart: "**cannot block subagent creation**" (explicit)
- PreToolUse: CAN match on `Agent` tool, receives `tool_input.subagent_type`
- PreToolUse: CAN return `permissionDecision: "deny"` to block tool calls

### 3. Upstream issues
- **#25000** (closed/duplicate): "Sub-agents bypass permission deny rules"
  Confirms subagents bypass deny rules and per-command approval
- **#6699** (closed/assigned): "deny permissions in settings.json are not enforced"
  Broader deny enforcement failure in v1.0.93, presumably patched

### 4. Our issue
- **#34730** (open): Filed about the schema bug and routing problem.
  Mentions the deny rule as a corrective action, but doesn't note it's broken.

## 5 Whys

1. **Why didn't the deny rule block the subagent?**
   The `Agent(Claude Code Guide)` pattern doesn't match the internal name.

2. **Why doesn't the pattern match?**
   The docs say to use the "name field" — the internal identifier is
   `claude-code-guide` (lowercase, hyphenated), not "Claude Code Guide"
   (display name with spaces). We used the display name.

3. **Why did we use the display name?**
   The built-in subagent table in the docs lists it as "Claude Code Guide"
   and the examples (`Agent(Explore)`, `Agent(Plan)`) use capitalized names
   that happen to match both display name and internal name for those agents.

4. **Why wasn't this tested before deploying?**
   The commit (46c93b3) says "(tested: macOS)" but the test was likely
   confirming the settings.json was written correctly, not that the deny
   actually blocked the subagent.

5. **Why was there no verification that the deny actually works?**
   No check-script step validates deny rule effectiveness. The deploy
   pipeline validates hook *schema* (corrective action from the original
   incident) but not *permission rule effectiveness*.

**Possible alternative root cause**: Even with the correct name, deny rules
for Agent may not work at all (per #25000). This needs testing.

## Contributing factors (Swiss cheese model)

```
Layer 1 (Prevention): Docs ambiguous — "name field" vs display name unclear
                      for built-in agents where they differ. No CC docs
                      example uses a multi-word built-in agent name.
Layer 2 (Detection):  No hook or check validates deny rule effectiveness.
                      The deploy pipeline validates schema, not behavior.
Layer 3 (Audit):      No check-script step tests "can I still invoke the
                      denied agent?" after deployment.
```

## Immediate cause

Pattern mismatch: `Agent(Claude Code Guide)` (display name) vs
`claude-code-guide` (internal name/subagent_type).

## Root cause

Untested corrective action from the original incident (I-series entry for
the hook schema bug). The deny rule was deployed without verifying it
actually blocks the subagent. Additionally, the Claude Code docs don't
clarify how built-in multi-word agent names map to deny patterns.

## Recommended corrective actions

### Option A: Fix the deny pattern (quick, uncertain)

Change `Agent(Claude Code Guide)` to `Agent(claude-code-guide)` and test.

**Risk**: May still not work if #25000 (subagent deny bypass) is unfixed.
**Verification**: Invoke `claude-code-guide` after change, confirm it's blocked.

### Option B: PreToolUse hook on Agent tool (structural, reliable)

The hooks docs confirm:
- PreToolUse matches on tool name `Agent`
- `tool_input` includes `subagent_type` field
- Hook can return `permissionDecision: "deny"`

Hook script:
```bash
#!/bin/bash
# block-claude-code-guide.sh
# Blocks the built-in claude-code-guide subagent (Haiku model)
# which returns inaccurate hook schema information.
# See: https://github.com/anthropics/claude-code/issues/34730
SUBAGENT_TYPE=$(jq -r '.tool_input.subagent_type // empty')

if [ "$SUBAGENT_TYPE" = "claude-code-guide" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "claude-code-guide subagent is denied. Use chrome-devtools skill against official docs instead. See issue #34730."
    }
  }'
fi
```

Hook config (in settings.json):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"/Users/pepe/.claude/hooks/block-claude-code-guide.sh\""
          }
        ]
      }
    ]
  }
}
```

**Durability**: High — fires before the tool call, cannot be bypassed.
**Verification**: Invoke `claude-code-guide`, confirm it's blocked with reason.

### Option C: Both A + B (defense in depth)

Fix the deny pattern AND add the hook. If CC fixes the deny mechanism
upstream, both layers enforce. If deny stays broken, the hook catches it.

## Recommended approach: Option C

1. Fix deny pattern: `Agent(claude-code-guide)` (test immediately)
2. Add PreToolUse hook on Agent tool (structural enforcement)
3. Keep the deny rule regardless — it's the documented mechanism
4. Update GH issue #34730 with findings about deny bypass

## Recurrence risk

**Medium** — the hook provides structural enforcement, but:
- New built-in subagents could appear without our knowledge
- The hook only blocks `claude-code-guide` by name

## Dissemination

- [ ] Update GH issue #34730 with deny bypass findings
- [ ] Add incident entry to effectiveness tracker
- [ ] Deploy corrective actions (Option C)
- [ ] Add check-script step: "verify denied agents are actually blocked"

## Barrier analysis

**Replay with Option B in place:**
1. Agent decides to invoke claude-code-guide → PreToolUse fires
2. Hook reads subagent_type → matches "claude-code-guide"
3. Hook returns permissionDecision: "deny" with reason
4. Agent sees denial reason, uses chrome-devtools instead

Would this have prevented the original incident? **Yes** — the subagent
would never have executed, so no hallucinated schema would have been
returned, and the hook config would not have been corrupted.

Coverage: This hook prevents claude-code-guide invocation failures.
It does NOT prevent other built-in subagents from returning bad info
(different class of failure — would need per-agent evaluation or a
blanket "no built-in helper agents" policy).
