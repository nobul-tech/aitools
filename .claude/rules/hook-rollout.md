---
paths:
  - scripts/**
  - deploy/**
  - shared/**
  - reference/**
  - plans/**
  - rfcs/**
  - .claude/rules/**
  - .cursor/rules/**
  - CLAUDE.md
  - RELEASE_NOTES.md
  - ROADMAP.md
  - README.md
---

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

Every PreToolUse hook uses the `violation()` helper and declares mode variables:
- `violation "message" "$MODE_VAR"` — mode drives observe vs. enforce
- Log location: `~/.claude/hooks/logs/`
- Global default `MODE_REST="observe"` covers all checks not yet promoted
- Per-check overrides (`MODE_AND`, `MODE_SUBSHELL`, etc.) allow granular rollout:
  - `"enforce"` — zero false positives confirmed in log; blocks violations (exit 2)
  - `"observe"` — logs what would be blocked; always exits 0

**Current enforcement state (standing-order-guard.sh):**

| Check | Variable | State | Notes |
|-------|----------|-------|-------|
| `&&` | `MODE_AND` | enforce | Zero false positives in log |
| `$()` | `MODE_SUBSHELL` | enforce | Zero false positives in log |
| `\|\|` | `MODE_REST` | observe | No false positives but low sample count |
| `;` | `MODE_REST` | observe | False positives: pwsh `-Command`, `perl -e` — fix matching before promoting |
| backticks | `MODE_REST` | observe | No false positives but low sample count |

Review logs with: `cat ~/.claude/hooks/logs/standing-order-guard.log`
