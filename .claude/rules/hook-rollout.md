## Hook Rollout Practice (this repo)

All PreToolUse hooks must go through an observe-then-enforce cycle before blocking.

### Phases

1. **Observe** (1+ week): Deploy with `MODE="observe"`. Hook logs what it would
   block to `~/.claude/hooks/logs/<hook-name>.log` but always exits 0.
2. **Review**: Audit the log for false positives. Fix matching logic.
3. **Enforce**: Switch to `MODE="enforce"`. Hook blocks violations (exit 2).

### When to reset to observe

- After adding new rules or patterns to an existing hook
- After changing matching logic (e.g., adding pipeline exemptions)
- After Claude Code version upgrades that may change tool input formats

### Implementation

Every PreToolUse hook must have a `MODE` variable and use the `violation()` helper:
- `MODE="observe"` at the top of the script
- `violation "message"` instead of direct `echo >&2; exit 2`
- Log location: `~/.claude/hooks/logs/`

Review logs with: `cat ~/.claude/hooks/logs/standing-order-guard.log`
