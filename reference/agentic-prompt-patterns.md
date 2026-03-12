# Agentic Prompt Patterns for `claude -p`

Safe patterns for using `claude -p` in aitools scripts (deploy, setup, merge).

## Core Rules

1. **Inline all content** — never reference file paths in prompts. The claude CLI
   with `--allowedTools ""` cannot read files. Use XML delimiters to embed content:
   ```
   <SOURCE>
   ${source_content}
   </SOURCE>
   ```

2. **Disable tool use** — `--allowedTools ""` for text-only tasks (merge, rewrite).
   Prevents the model from attempting file reads or shell commands.

3. **Disable session persistence** — `--no-session-persistence` for utility calls.
   These are one-shot operations; no session state should leak between invocations.

4. **Validate before accepting** — call `validate_ai_merge_output` (bash) /
   `Test-AiMergeOutput` (PS1) before writing any AI-generated content to disk.
   Checks for: conversational text, code fences, permission language, truncation,
   structural overlap with inputs.

5. **Offer refinement** — after validation passes, show a preview and let the user
   choose `[y]es accept / [r]efine / [n]o reject`. Refinement re-invokes claude
   with the previous result + user feedback.

6. **Write back to source** — when merged content is accepted, sync it to the
   dotprofile repo (`<userRepoPath>/claude/rules/`) and auto commit/push.

7. **Log rejected output** — always log rejected AI output to `deploy.log` for
   post-incident debugging. Use `log` (not `log_warn`) for the raw content.

## Incident Context

These patterns were established after Incident #24 (2026-03-11), where the AI merge
feature (v0.50.1) corrupted `~/.claude/rules/concurrent-agents.md` by writing Claude's
conversational response instead of merged content. See GitHub issue #24.

## Functions

| Language | Validation | Merge |
|----------|-----------|-------|
| Bash | `validate_ai_merge_output` in `aitools-lib.sh` | `_invoke_ai_merge` in `aitools-lib.sh` |
| PowerShell | `Test-AiMergeOutput` in `aitools-lib.ps1` | `Invoke-AiMerge` in `aitools-lib.ps1` |
