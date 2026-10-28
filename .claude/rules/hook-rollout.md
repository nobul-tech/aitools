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
4. **Exemption test** (when the change adds an exemption): run the exempted form
   and verify exit 0 with no log entry, and run each near-miss write form and verify
   it is still blocked (e.g. for #82: `sed -n '60,75p' file` exits 0;
   `sed -i s/a/b/ file`, `sed 's/a/b/w out' file`, `sed s/a/b/ file > out`,
   `sed -n 1p -i file`, `sed -n '1,5w out' file`, `sed -n 1p file > out`, and a
   two-line command whose first line is `sed -n 1p file` exit 2).

`bash -n` is not sufficient for hooks using `set -euo pipefail` — it passes syntax
but cannot catch unset variable errors (`-u`) or runtime failures. Always smoke-test.
(I12: stale `$MODE` reference caused crash-on-every-call after a refactor; `bash -n` passed.)

### When to reset to observe

- After adding new rules or patterns to an existing hook
- After changing matching logic so a check blocks commands it did not block before
- After Claude Code version upgrades that may change tool input formats

A matching change that only narrows what a check blocks (an exemption: commands
that were blocked now pass, nothing new is blocked) keeps the check's current mode;
the exemption test above verifies it. A change that widens what is blocked, or both
narrows and widens, resets the check to observe. (Commander, 2026-10-21: the #82
`sed -n` exemption kept `MODE_SED` at enforce.)

A check with no mode variable gets one when it is reset (it cannot observe otherwise).

### Implementation

`standing-order-guard.sh` uses the `violation()` helper and declares mode variables:
- `violation "message" "$MODE_VAR" "check-name"` — mode drives observe vs. enforce;
  an empty mode argument defaults to `"enforce"`
- Log location: `~/.aitools/logs/` (`<hook-name>.log`, written in observe mode only)
- Each check has its own mode variable (`MODE_AND`, `MODE_OR`, `MODE_SED`, etc.)
  for granular rollout:
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
| `cat`/`head`/`tail`/`awk` outside a pipeline | none (literal `"enforce"`) | enforce | No mode variable |
| `sed` outside a pipeline | `MODE_SED` | enforce | Read-only `sed -n '<N[,M]>p' <file>` exempt since 2026-10-21 (incident #82), single-line commands only; a narrowing change, so the check stayed at enforce |
| `echo`/`printf` redirect on first line | none (literal `"enforce"`) | enforce | No mode variable |

**Current enforcement state (other PreToolUse hooks):**

| Hook | Variable | State | Notes |
|------|----------|-------|-------|
| `delegation-duty-guard.sh` | `MODE_DUTY` | observe | Since 2026-03-24; element 7 (`md-prefix`, D-DEL1) added 2026-10-05; since 2026-10-26 checks the eight `/delegate` v2.0 elements of the Agent prompt and prints a reminder to load `/delegate` on every Agent call (D-DEL7); matcher `Agent\|Workflow` from 2026-10-26 (a widening change, so it stayed observe), back to `Agent` since 2026-10-28 (Workflow calls moved to `workflow-delegation-guard.sh`: a narrowing change, mode unchanged); its eight-element Perl block sits between the `delegation elements block` markers, shared verbatim with `workflow-delegation-guard.sh`; exits 0 and sends the reminder and missing elements to Claude as stdout `hookSpecificOutput.additionalContext` JSON (Claude Code ignores stderr on exit 0; until 2026-10-26 the reminder went to stderr only and never reached Claude) and to stderr for the transcript (`enforce` exits 2, stderr); no log file -- one `delegation` event per call (with `tool`) goes to `<session dir>/events.jsonl` when `.scratch/.current-session` exists at the git root; tests: `tests/hooks/test-delegation-duty-guard.sh` |
| `workflow-delegation-guard.sh` | `MODE_WF_DUTY` | observe | New check, since 2026-10-28; PreToolUse matcher `Workflow` (Claude Code fires one PreToolUse per Workflow call with the whole script, none per `agent()`); a Perl lexer finds each static `agent(` call site in the `script` / `scriptPath` file, resolves its prompt (string and template literals, constants, `+`) and scores it for the eight `/delegate` v2.0 elements with the block shared verbatim with `delegation-duty-guard.sh` (parity tested); prompts built at run time (calls, member access) are reported unresolved, not scored; one whole-script score on a lexer failure, the resolution budget, or the 2 s time guard; a script with no `agent(` call is nothing to check and never blocks (spec v1.1); exits 0 and sends the reminder, a per-agent summary, the 5 worst prompts and guidance as stdout `hookSpecificOutput.additionalContext` JSON (at most 4,000 characters) and to stderr (`enforce` exits 2, stderr, when a scored prompt or the fallback score has a gap); no log file -- one `delegation` event per `agent()` call site (`src` `wdg`, `scope` `agent`, `agent` label; `why` for an unresolved, fallback or not-checked event) goes to `<session dir>/events.jsonl` when `.scratch/.current-session` exists at the git root; tests: `tests/hooks/test-workflow-delegation-guard.sh` |

Review logs with: `cat ~/.aitools/logs/standing-order-guard.log` (absent while every
check enforces). Blocks are not written to that log; when the hook runs inside a git
repo whose root has `.scratch/.current-session`, each block is a `hook_block` event
in `<session dir>/events.jsonl`.

The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks,
retirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`.
`deploy-harness` copies it to `~/.aitools/rules/` and `setup-user-cursor` fans it
out to `~/.cursor/rules/`; it reaches `~/.claude/rules/` once `setup-user-claude`
fans out the harness rules.
