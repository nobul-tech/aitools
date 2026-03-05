# Plan Execution -- Detail Reference

Companion to `.claude/rules/plan-execution.md`. Defines the sub-agent execution
pattern, rule injection template, and verification protocol.

## Why

I17 (2026-03-05): `-ErrorAction SilentlyContinue` written without result check in
aitools-lib.ps1 during a 9-part plan. Root cause: rule fade across long execution.
Same pattern as I1 (batch size), I7 and I11 (error-handling in plan-phase code).
Fourth occurrence of error-suppression violations despite prior remediations.

Structural fix: fresh sub-agents per batch ensure rules are front-and-center in
context, not faded 50K tokens back.

## When to use sub-agents

| Condition | Sub-agent required? |
|-----------|-------------------|
| 3+ code files in the plan | Yes |
| Any change to `scripts/aitools-lib.sh` or `.ps1` | Yes |
| Any change to `scripts/build-deploy.sh` | Yes |
| 1-2 code files, no lib changes | No (direct execution OK) |

Plans below the threshold still require the error-handling audit step (section 4).

## Plan structure requirements

Every code batch in the plan must include:

1. **File list** -- exact paths to read and modify
2. **Verbatim edits** -- old_string / new_string for each change
3. **Error-handling audit** -- checklist applied to each code block (see section 4)
4. **Verification steps** -- syntax checks, build, compliance

## Sub-agent prompt template

```
You are modifying files in the aitools repo. Apply the exact edits below.
Do NOT improvise or add code not specified in the edits.

## Error-handling rules (non-negotiable)

These rules apply to ALL code you write or modify:

1. Every `-ErrorAction SilentlyContinue` MUST have a null/empty check within 3 lines
2. Every `2>/dev/null` MUST have a comment explaining why AND a result check
3. Every `|| true` MUST have a comment explaining why AND a result check
4. Every try/catch MUST have a catch that logs or re-throws; empty catch {} is NEVER OK
5. Exception: command-existence checks (Get-Command, command -v) with explicit fallback
6. Every log_error/LogError for a file write MUST pair with write_summary ERROR
7. Prefer `-ErrorAction Stop` with try/catch over `-ErrorAction SilentlyContinue`
8. `rm -f` in bash is OK for cleanup (ignores nonexistent; targeted, not blanket)

## Edits to apply

[verbatim edits from plan]

## After applying edits

Report what you changed. Flag any concern about the edits.
```

## Error-handling audit checklist

Before approving any plan code block, verify each line against:

| Pattern | Required | Check |
|---------|----------|-------|
| `-ErrorAction SilentlyContinue` | Null check within 3 lines | Does the next 1-3 lines test the result? |
| `-ErrorAction Stop` | try/catch wrapping | Is the call inside a try block? |
| `2>/dev/null` | Comment + result check | Is there a `#` comment AND an if/test? |
| `\|\| true` | Comment + result check | Is there a `#` comment AND a subsequent check? |
| `try { } catch { }` | Catch body non-empty | Does catch log or re-throw? |
| `log_error` / `LogError` | Paired write_summary | Is there a `write_summary ERROR` nearby? |
| `Get-Content` (no -ErrorAction) | Error handling present | Is this in a try/catch or have -ErrorAction? |
| `cp` / `Copy-Item` | Failure handling | What happens if the copy fails? |

## Verification protocol

After each sub-agent batch:

1. **Spot-check**: Main agent reads modified files, compares key sections to plan
2. **Syntax**: `bash -n` for .sh; `pwsh -NoProfile -Command '..ParseFile..'` for .ps1
3. **Compliance scan**: Grep for `-ErrorAction SilentlyContinue` -- verify each has check
4. **Build**: `bash scripts/build-deploy.sh` (after lib or setup script changes)
5. **Functional**: dry-run where applicable
