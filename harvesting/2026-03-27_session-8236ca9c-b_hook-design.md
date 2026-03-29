# Hook Design: Failure Mode Identity + Verification Stop Hooks

**Session**: 8236ca9c | **Mission Commander**: hook-design
**Date**: 2026-03-26
**Governing decision**: D-27 (Session Commander must ship two hooks as structural mechanism)

## Problem Statement

Prompting alone cannot exit failure mode (OL-25, D-24). CC training
defaults reassert on every turn (OL-14). The 7-step process drops on
easy-feeling prompts (I-5, I-6). Identity fades mid-session (OL-3).
These share the same shape (OL-40) and need a structural mechanism,
not behavioral discipline.

## Hook 1: failure-mode-identity-stop.sh

**Purpose**: Reinforce agent identity, surface known gaps, enforce the
7-step process, and carry forward operational learning at every turn.

**Event**: Stop (fires after every assistant response)
**Type**: command (dynamic content via stderr -- OL-43/A-H5 invalidated static prompt)
**Matcher**: none (Stop hooks fire unconditionally)

### What it reads

1. Session running estimate from `.scratch/session-*/running-estimate*.md`
   (found via `.scratch/.current-session` pointer)
2. Fallback: `.aitools/channel/running-estimate.json` (tracked, cross-machine)
3. Hook input JSON on stdin (session_id)

### What it injects (via stderr)

A compact identity block containing:

```
[identity] Session Commander <session-id-prefix> | Failure mode: DEFAULT
  PROCESS: 1.Receive 2.Classify 3.Orient 4.Assess 5.Surface 6.Propose 7.Connect
  ORDERS: aitools supersedes CC defaults | verify before claiming | ask when uncertain
  GAPS: <top 3 open assumptions from running estimate>
  OL: <5 most recent OL items from running estimate>
```

### Observe mode behavior

- Always exit 0 (Stop hooks cannot block per CC design)
- Logs injection events to session events.jsonl
- No enforcement -- context injection only
- Performance budget: <50ms on every turn

### Data extraction strategy

- Parse running estimate markdown with lightweight perl (not full parser)
- Extract OL items: lines matching `^OL-\d+:`
- Extract open assumptions: lines under `### Open` matching `^- A-O`
- Extract blockers: lines under `### Blockers` matching `^- A-B`
- If no running estimate found: inject static fallback (process + identity only)

### Performance budget

- Read `.current-session` file: ~1ms
- Find running estimate file: ~2ms (glob in known directory)
- Parse with perl: ~5ms
- Format and emit stderr: ~1ms
- Total: ~10ms typical, <50ms worst case

## Hook 2: failure-mode-verify-stop.sh

**Purpose**: Lightweight verification checklist -- catch failure mode
symptoms before the next turn.

**Event**: Stop (fires after every assistant response)
**Type**: command (dynamic content via stderr)
**Matcher**: none

### What it reads

1. Hook input JSON on stdin (transcript_summary if available)
2. No file reads required (verification is prompt-only)

### What it injects (via stderr)

A brief checklist:

```
[verify] Before next response, check:
  [ ] Did I follow the 7-step process (not jump to conclusions)?
  [ ] Am I using aitools vocabulary (not CC defaults)?
  [ ] Did I verify claims before stating them as fact?
  [ ] Did I surface uncertainties (not power through)?
  [ ] Did I ask when I didn't know (not appear to know)?
```

### Observe mode behavior

- Always exit 0
- Logs to session events.jsonl
- Injection is unconditional (the checklist is always relevant)
- Performance budget: <10ms (no file reads, string-only)

## Relationship to existing hooks

These hooks complement, not replace, existing Stop hooks:
- `command-channel-stop.sh`: polls for commander directives (different purpose)
- The identity hook provides context; the verify hook provides a behavioral check

## Pipeline integration (not in scope for this deliverable)

Adding these hooks to the deployment pipeline requires changes to:
1. `scripts/build-deploy.sh` -- add to hook file list (line 59) and read vars (line 68+), add embed calls (line 1217+)
2. `scripts/setup-user-hooks.sh` -- add resolve, deploy, and settings.json merge
3. `scripts/setup-user-hooks.ps1` -- equivalent PS1 changes

These changes are deferred. The hooks are written to `shared/hooks/`
and can be manually deployed or integrated in a subsequent session.

## Assumptions made during design

- A-HD1: The 7-step process is: Receive, Classify, Orient, Assess, Surface,
  Propose, Connect. Derived from OL-13 (receipt and response), OL-41
  (OBSERVE-SURFACE-PROPOSE-CONNECT cycle), and A-O10 (completeness unverified).
  STATUS: UNVERIFIED -- the running estimate notes A-O10 as open.

- A-HD2: Stop hooks receive JSON on stdin with at least session_id field.
  Derived from command-channel-stop.sh which reads session_id from Stop input.
  STATUS: PARTIALLY VERIFIED -- observed in command-channel-stop.sh.

- A-HD3: Multiple Stop hooks can coexist without interference.
  STATUS: UNVERIFIED -- command-channel-stop.sh exists as a Stop hook,
  adding two more creates 3 total. CC should handle this but unverified.

- A-HD4: stderr output from Stop hooks appears in agent context before the
  next user message is processed. STATUS: VERIFIED (A-H9 in running estimate).

- A-HD5: Running estimate markdown format is stable enough to parse with regex.
  STATUS: ASSUMPTION -- markdown format is session-specific, may vary.

- A-HD6: The perl binary is available on all platforms (macOS, Linux, Git Bash).
  STATUS: VERIFIED -- perl is a managed tool per CLAUDE.md, and Git Bash
  includes perl.
