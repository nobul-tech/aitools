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

### Managed-file review choices and merge

Every choice in the managed-file review menus has one defined effect. Code:
`prompt_diff_review` in `@scripts/aitools-lib.sh` (twin: `Prompt-DiffReview`
in `@scripts/aitools-lib.ps1`); mission SOURCE-TRUTH implements this model.
State machine: `@reference/managed-file-deployment.md`.

**SOURCE is the source of truth.**
- **SOURCE**: the file in the repo (or dotprofile) being deployed
- **LOCAL**: the deployed copy on disk

There is no ancestor and no deploy state: the only comparison is SOURCE
against LOCAL.
- LOCAL equals SOURCE: verified, nothing written.
- LOCAL differs, non-interactive run (no terminal, EOF, or `--force`):
  SOURCE written to LOCAL. No merge runs.
- LOCAL differs, interactive run: the review menu.

**Text files** (markdown, shell): one review per file, with the full menu,
including AI merge.

**JSON files:** SOURCE owns every field. Node compares SOURCE and LOCAL
field by field (key path; a whole array is one field), and each differing
field is one review. A field only in LOCAL is kept in LOCAL and never
written to SOURCE without a review. Key order is preserved. No text or AI
merge. `sync_managed_json` / `Sync-ManagedJson` (settings.json) keep their
profile-mirror rule: a leaf only in the live file auto-adopts into
profile.json. cli-config.json uses its own merge (`setup-user-cursor`).

**Adopt and merge write the repo immediately.** On accept & adopt or merge &
adopt, the library writes the result to LOCAL and copies it to the repo
(the adopt target) in the same step, before the next file is reviewed. After
that SOURCE, LOCAL and the repo are identical, so the next run verifies the
file and asks nothing. A file with no adopt target is not offered adopt or
merge.

**Choices.**

| Choice | LOCAL | Repo (source of truth) |
|---|---|---|
| overwrite | SOURCE written | unchanged |
| accept & adopt (file, or JSON field) | LOCAL kept | LOCAL copied to the repo immediately |
| merge & adopt (text only; AI merge) | merge written | merge copied to the repo immediately |
| skip | unchanged | unchanged; reviewed again next run |
| abort | unchanged | unchanged; the script logs an error and exits 2 |

**Failure handling.** Before any write, back up every file the step will
write: LOCAL, and the repo file for an adopt or merge. After writing,
validate (text: non-empty; JSON: parses, required keys present). If a write,
the AI merge or a validation fails: restore the backups, log the error with
its reason, report the file as ERROR in the summary, and continue with the
next file. One failed file never stops the run, and a failure never leaves a
half-written file.

**Rules.**
- The library performs the repo write-back itself, given the adopt target's
  path. Callers pass the path; they do not copy files back themselves.
- Adopting into a protected file (`.claude/rules/sources-of-truth.md`) is
  allowed. It writes only the working tree and logs a WARN that names the
  file; the review gate applies at commit and PR.
- AI merge applies to text files only and follows the prompt design,
  validation and telemetry rules above (speed `balanced`, permissions
  `none`, at most 1 retry, preview before write).

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

### User-facing AI invocations

When an AI invocation is visible to the user (interactive prompt, not background):

1. **Transparency**: Display the backend (claude/agent), speed tier, and purpose
   before the invocation starts
2. **Progress**: Show an animated spinner for operations expected to take >3 seconds
3. **Failure severity**: When the user explicitly requested the AI operation and it
   fails after retries, log_error (not log_warn). log_warn is for
   background/optional AI operations with automatic fallbacks

Details: `@reference/agentic-framework.md`
