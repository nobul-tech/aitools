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

1. **Observe** (1+ week): Deploy with the check's mode variable set to `"observe"`
   (e.g. `MODE_OR="observe"`). Hook logs what it would block to
   `~/.aitools/logs/<hook-name>.log` but always exits 0.
2. **Review**: Audit the log for false positives. Fix matching logic.
3. **Enforce**: Set the mode variable to `"enforce"`. Hook blocks violations (exit 2).

### Pre-deploy verification

Before deploying any hook change (new rule, mode promotion, or matching logic fix):

1. **Syntax check**: `bash -n shared/hooks/<hook>.sh` — catches parse errors only
2. **Smoke-test**: run the hook against a clean input and verify exit 0:
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
     | bash shared/hooks/standing-order-guard.sh
   echo "exit: $?"
   ```
3. **Violation test**: run against a known-bad input and verify the expected outcome
   (exit 2 in enforce, log entry in observe):
   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"git status && git log"}}' \
     | bash shared/hooks/standing-order-guard.sh
   echo "exit: $?"
   ```

`bash -n` is not sufficient for hooks using `set -euo pipefail` — it passes syntax
but cannot catch unset variable errors (`-u`) or runtime failures. Always smoke-test.
(I12: stale `$MODE` reference caused crash-on-every-call after a refactor; `bash -n` passed.)

### When to reset to observe

- After adding new rules or patterns to an existing hook
- After changing matching logic (e.g., adding pipeline exemptions)
- After Claude Code version upgrades that may change tool input formats

### Implementation

`standing-order-guard.sh` uses the `violation()` helper and declares mode variables:
- `violation "message" "$MODE_VAR" "check-name"` — mode drives observe vs. enforce;
  an empty mode argument defaults to `"enforce"`
- Log location: `~/.aitools/logs/` (`<hook-name>.log`, written in observe mode only)
- Each check has its own mode variable (`MODE_AND`, `MODE_OR`, etc.) for granular rollout:
  - `"enforce"` — zero false positives confirmed in log; blocks violations (exit 2)
  - `"observe"` — logs what would be blocked; always exits 0

**Current enforcement state (standing-order-guard.sh):**

| Check | Variable | State | Notes |
|-------|----------|-------|-------|
| `&&` | `MODE_AND` | enforce | Zero false positives in log |
| `$()` | `MODE_SUBSHELL` | enforce | Zero false positives in log |
| `\|\|` | `MODE_OR` | enforce | Promoted 2026-03-24; zero false positives |
| `;` | `MODE_SEMICOLON` | enforce | Promoted 2026-03-24; commands starting with `pwsh`, `powershell` or `perl` are exempt |
| backticks | `MODE_BACKTICK` | enforce | Promoted 2026-03-24; zero false positives |
| 4+ lines (scratch files) | `MODE_SCRATCH` | enforce | Zero false positives in log |
| `*`/`?` in `rm` | none (literal `"enforce"`) | enforce | No mode variable; cannot be set to observe without adding one |
| `cat`/`head`/`tail`/`sed`/`awk` outside a pipeline | none (literal `"enforce"`) | enforce | No mode variable |
| `echo`/`printf` redirect on first line | none (literal `"enforce"`) | enforce | No mode variable |

**Current enforcement state (other PreToolUse hooks):**

| Hook | Variable | State | Notes |
|------|----------|-------|-------|
| `delegation-duty-guard.sh` | none (hardcoded) | observe | Since 2026-03-24; always exits 0; missing duty elements go to stderr as a reminder, not to a log file |

Review logs with: `cat ~/.aitools/logs/standing-order-guard.log` (absent while every
check enforces). Blocks are not written to that log; when the hook runs inside a git
repo whose root has `.scratch/.current-session`, each block is a `hook_block` event
in `<session dir>/events.jsonl`.
