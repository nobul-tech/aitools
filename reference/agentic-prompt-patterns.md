# Agentic Prompt Patterns for AI CLI

Patterns for using AI CLI tools (`claude -p`, `agent -p`) in aitools scripts.

## Framework

All AI invocations in reusable scripts use `invoke_ai` / `Invoke-AI` from
aitools-lib. See `reference/agentic-framework.md` for the full spec and
`.claude/rules/agentic-standards.md` for the governing rule.

### Key principles

1. **Inline all content** -- never reference file paths in prompts. Use XML delimiters.
2. **Disable tool use** -- `none` permission tier for text-only tasks.
3. **Disable session persistence** -- handled automatically by `invoke_ai`.
4. **Validate before accepting** -- every invocation uses a validation callback.
5. **Offer refinement** -- show preview, let user choose `[y]es / [r]efine / [n]o`.
6. **Log rejected output** -- `log_detail` per line for post-mortem.

## Functions

| Language | Invocation | Validation | Merge prompt | Refine prompt |
|----------|-----------|-----------|--------------|---------------|
| Bash | `invoke_ai` | `validate_ai_merge_output` | `_ai_prompt_merge` | `_ai_prompt_merge_refine` |
| PS1 | `Invoke-AI` | `Test-AiMergeOutput` | `Get-AiMergePrompt` | `Get-AiMergeRefinePrompt` |

## Incident Context

These patterns were established after Incident #24 (2026-03-11), where the AI merge
feature (v0.50.1) corrupted `~/.claude/rules/concurrent-agents.md` by writing Claude's
conversational response instead of merged content. See GitHub issue #24.

Subsequent improvements:
- v0.50.2: Validation checks, refinement loop
- v0.51.0: `log_detail` for rejected output, progress message
- v0.52.0: `invoke_ai` framework, structured prompts, header preservation, speed tiers
