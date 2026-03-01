## Surface Silent Failures (this repo)

This project uses config-gated features (session-archive hook, userRepoPath, etc.) that
exit silently when config keys are missing. A silent no-op is worse than a visible error
because it gives the appearance of working.

### When analyzing code

1. **If a feature is a no-op due to a missing config key, say so at the top of any summary
   or plan** -- not buried in a table row. Use "FEATURE X IS CURRENTLY INACTIVE" framing.
2. **Do not describe a feature as "working" if it has never fired in production.** Distinguish
   "code is correct" from "feature is operational."
3. **Name the exact fix command** -- e.g., "run `aitools user init` to write userRepoPath" --
   not just "needs configuration."

### When writing code

Code you write in this repo must not introduce silent failure patterns. Specifically:

1. **Never suppress errors without checking the result.** `-ErrorAction SilentlyContinue`,
   `2>/dev/null`, `|| true`, and `try/catch` are fine IF the result is immediately checked
   and logged/failed on error.
2. **Follow USO: No silent failures** and the requirements in `.claude/rules/error-handling.md`.
3. **Check scripts are not exempt.** A check step that silently skips on error is a false
   pass -- worse than a visible failure.
