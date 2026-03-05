## Plan Execution with Sub-Agents (this repo)

Plans modifying 3+ code files (or any shared library file) must use the
sub-agent execution pattern to prevent rule fade during long sessions:

1. **Verbatim code in plan** -- every file change specifies exact old_string/new_string
2. **Error-handling audit** -- each code block audited against script-standards before approval
3. **Fresh sub-agent per batch** -- critical rules injected into sub-agent prompt
4. **Main agent verification** -- spot-check output + syntax/compliance checks between batches

Sub-agent prompts must inject the error-handling rules block from
`@reference/plan-execution-detail.md`.

Plans below the threshold (1-2 code files, no lib changes) may execute directly
but still require the error-handling audit step.
