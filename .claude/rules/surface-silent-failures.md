## Surface Silent Failures (this repo)

This project uses config-gated features (session-archive hook, userRepoPath, etc.) that
exit silently when config keys are missing. A silent no-op is worse than a visible error
because it gives the appearance of working.

When exploring or auditing this codebase:

1. **If a feature is a no-op due to a missing config key, say so at the top of any summary
   or plan** -- not buried in a table row. Use "FEATURE X IS CURRENTLY INACTIVE" framing.
2. **Do not describe a feature as "working" if it has never fired in production.** Distinguish
   "code is correct" from "feature is operational."
3. **Name the exact fix command** -- e.g., "run `aitools user init` to write userRepoPath" --
   not just "needs configuration."
