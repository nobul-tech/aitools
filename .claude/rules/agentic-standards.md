## Agentic Standards (this repo)

### Framework usage

All AI CLI invocations in reusable scripts must use `invoke_ai` / `Invoke-AI`
from aitools-lib. Direct `claude -p` or `agent -p` only in contexts where
aitools-lib is not loaded (e.g., interactive shell aliases with opportunistic
fallback).

Default: `none` permissions, `balanced` speed. Escalate only when needed.

### Prompt design

Every prompt function must follow the structured prompt pattern:

1. **Role** -- who the AI is acting as ("You are a file merge tool")
2. **Context** -- what it's working with (file type, source, deploy purpose)
3. **Task** -- specific action ("apply the changes from the diff to LOCAL")
4. **Constraints** -- rules about conflicts, preservation, what to keep/change
5. **Output format** -- exact expectations ("no commentary, no code fences")

Prompts must be self-contained -- never reference file paths when tool use is
disabled. Inline all content using XML delimiters.

### Prompt evaluation

Before shipping a new or modified prompt:

1. **Test against samples** -- run with realistic inputs in `.scratch/`
2. **Verify validation** -- output must pass the prompt's validation function
3. **Check edge cases** -- empty input, large input, conflicting content
4. **Document limitations** -- in the prompt function's header comment

At runtime, log every AI invocation to deploy.log:
- Speed tier, backend (claude/agent), validation result, retry count
- On failure: full rejected output via `log_detail` for post-mortem

### Prompt iteration

When a prompt fails in production:
1. Read rejected output from deploy.log (`[detail] ai-rejected:` lines)
2. Identify the failure mode (which validation check, why)
3. Update the prompt to address the failure
4. Re-test against the original failing input + other samples
5. Ship the updated prompt

### Speed tiers

| Tier | When to use | claude model | agent model |
|------|-------------|-------------|-------------|
| `fast` | Simple extraction, naming, classification | haiku | auto (default) |
| `balanced` | Merge, summarization, moderate complexity | sonnet | auto (default) |
| `quality` | Complex reasoning, code generation | opus | auto (default) |

Agent CLI note: uses `--model auto` (account default) for all tiers.
Speed hints via prompt prefix only. Update when explicit models available.

### Permission tiers

| Tier | When to use |
|------|-------------|
| `none` | Text-only tasks -- merge, naming, summary. **This is the default.** |
| `readonly` | Tasks that need file context but shouldn't write |
| `full` | Full agentic tasks requiring file/shell access |
| `dangerous` | Autonomous operations -- requires explicit justification |

### Anti-patterns

- Vague prompts without explicit output format specification
- Prompts that reference file paths when `--allowedTools ""` is set
- AI invocations without validation callbacks
- Fire-and-forget calls without checking output or exit code
- Hardcoded model names (use speed tiers)
- Suppressing AI errors without logging (`2>/dev/null` without result check)
- Prompts tested only manually -- write `.scratch/` test scripts

Details: `@reference/agentic-framework.md`
