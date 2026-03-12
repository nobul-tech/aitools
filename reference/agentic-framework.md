# Agentic Framework -- Detail Reference

Companion to `.claude/rules/agentic-standards.md`. Defines the `invoke_ai` /
`Invoke-AI` interface, backend detection, speed/permission mapping, retry
mechanism, telemetry format, and prompt design standard.

## `invoke_ai` / `Invoke-AI` interface

### Bash

```bash
# invoke_ai SPEED PERMISSIONS [VALIDATE_FN [MAX_RETRIES]]
# Reads prompt from stdin, writes output to stdout
# Returns 0=success, 1=failure; sets AI_REJECT_REASON on failure
invoke_ai balanced none validate_fn 1
```

### PowerShell

```powershell
$output = $prompt | Invoke-AI -Speed "balanced" -Permissions "none" `
    -ValidateFn "validate_fn" -MaxRetries 1
# Returns output string on success, $null on failure
# Sets $script:AIRejectReason on failure
```

### Parameters

| Parameter | Bash | PowerShell | Default |
|-----------|------|-----------|---------|
| Speed | `$1` | `-Speed` | `balanced` |
| Permissions | `$2` | `-Permissions` | `none` |
| Validate function | `$3` | `-ValidateFn` | (none) |
| Max retries | `$4` | `-MaxRetries` | `0` |

## Backend detection

1. Check for `claude` CLI (`command -v` / `Get-Command`)
2. If not found, check for `agent` CLI
   - On Windows Git Bash: `pwsh -NoProfile -Command 'Get-Command agent ...'`
3. If neither found: return failure, set `AI_REJECT_REASON`

## Speed tier mapping

### Claude CLI (full control)

| Tier | `--model` | `--effort` | `--append-system-prompt` |
|------|-----------|-----------|--------------------------|
| `fast` | `haiku` | `low` | "Be concise and direct." |
| `balanced` | `sonnet` | *(omit)* | *(omit)* |
| `quality` | `opus` | `high` | "Take your time. Be thorough." |

### Agent CLI (no model flag)

| Tier | Prompt prefix |
|------|---------------|
| `fast` | "Be concise and direct. Prioritize speed.\n\n" |
| `balanced` | *(none)* |
| `quality` | "Take your time. Be thorough and precise.\n\n" |

## Permission tier mapping

| Tier | claude flags | agent flags |
|------|-------------|-------------|
| `none` | `--allowedTools ""` | `--mode ask` |
| `readonly` | `--allowedTools "Read Glob Grep"` | `--mode plan` |
| `full` | *(default)* | *(default)* |
| `dangerous` | `--dangerously-skip-permissions` | `--force` |

### Common flags (always set)

- claude: `-p --no-session-persistence`
- agent: `-p --trust`

## Retry mechanism

On validation failure with retries remaining:
1. Log rejected output per-line via `log_detail` / `LogDetail`
2. Prepend to prompt: `"Your previous output was rejected: {reason}. Try again.\n\n"`
3. Re-invoke with augmented prompt
4. On success: log accepted
5. If exhausted: return failure

## Telemetry format

```
[2026-03-12T15:32:36Z] [setup-user-claude] [info] AI invocation: speed=balanced backend=claude attempt=1 result=accepted
```

Failed merge example:
```
[2026-03-12T15:32:36Z] [setup-user-claude] [warn] AI invocation: speed=balanced backend=claude attempt=1 result=rejected reason=AI wrapped output in code fences -- need raw content
[2026-03-12T15:32:36Z] [setup-user-claude] [detail] ai-rejected: ```markdown
[2026-03-12T15:32:36Z] [setup-user-claude] [detail] ai-rejected: # Shared Claude Code Preferences
[2026-03-12T15:32:36Z] [setup-user-claude] [detail] ai-rejected: ...
[2026-03-12T15:32:38Z] [setup-user-claude] [info] AI invocation: speed=balanced backend=claude attempt=2 result=accepted
```

### File-only telemetry (bash)

`invoke_ai` uses `_ai_log()` (file-only) instead of `log()` to avoid polluting
stdout when output is captured via `$()`. PS1 `Invoke-AI` uses standard `Log`
(`Write-Host` goes to Information stream, not Output stream).

## Prompt design standard

Every prompt function follows the 5-part structure:

1. **Role** -- "You are merging a managed configuration file..."
2. **Context** -- file description, source/local semantics, what's being deployed
3. **Task** -- specific action with clear deliverable
4. **Constraints** -- rules about conflicts, preservation, boundaries
5. **Output format** -- "no commentary, no code fences, no explanation"

## Prompt evaluation lifecycle

1. **Design** -- write prompt following 5-part pattern
2. **Test** -- run with realistic inputs in `.scratch/`
3. **Ship** -- deploy in script with validation callback
4. **Monitor** -- read `[detail] ai-rejected:` lines from deploy.log
5. **Iterate** -- update prompt based on failure patterns

## Validation patterns

### Merge validation (5 checks)

| Check | What it detects | Rejection message |
|-------|----------------|-------------------|
| 1 | Conversational response | "AI responded conversationally instead of producing merged content" |
| 2 | Code fence wrapping | "AI wrapped output in code fences -- need raw content" |
| 3 | Refusal language | "AI indicated it couldn't perform the merge" |
| 4 | Truncation | "Output too short (X chars, expected Y+) -- likely truncated" |
| 5 | Structural rewrite | "Rewrote too much (N/M section headers preserved, need 60%+)" |

### Validation wrapper pattern

```bash
_MERGE_VALIDATE_SOURCE=""
_MERGE_VALIDATE_LOCAL=""
_merge_validate() {
    validate_ai_merge_output "$1" "$_MERGE_VALIDATE_SOURCE" "$_MERGE_VALIDATE_LOCAL"
    AI_REJECT_REASON="$MERGE_REJECT_REASON"
}
```

## Current prompts inventory

| Function | Language | Speed | Permissions | Purpose |
|----------|----------|-------|-------------|---------|
| `_ai_prompt_merge` / `Get-AiMergePrompt` | bash/PS1 | balanced | none | Initial config file merge |
| `_ai_prompt_merge_refine` / `Get-AiMergeRefinePrompt` | bash/PS1 | balanced | none | User-driven merge refinement |
| `_clip2md_ai` | bash/PS1 | fast | none | Clipboard filename + summary |

## Anti-patterns (expanded)

- **Incident #24**: AI wrote conversational response instead of merged content. Fix: validation checks 1+3.
- **Incident #25**: Check 3 matched bare "permission" keyword in config content. Fix: sentence-level refusal patterns.
- **Incident #27**: Rejected output dumped to console as wall of text. Fix: `log_detail` per-line (file-only).
- **Check 5 false reject**: Verbatim 8-char line match was too strict for files with short lines. Fix: header preservation (60% threshold).
- **Incident #32**: Code fence wrapping despite "no code fences" instruction. Prompt saying "no code fences" in a numbered list is insufficient; models treat numbered constraints as suggestions. Fix: ALL-CAPS emphasis in output format rules + explicit negative example + defense-in-depth strip in merge function.

## Future extensions

- Configurable model mapping (user preference in `profile.json`)
- API key backend (direct Anthropic API, no CLI needed)
- Modal compute backend for batch processing
- Budget control (per-invocation cost tracking)
- Structured JSON output mode with schema validation

## Deploy state migration

Any file-tracking system with shadows/ancestors must handle pre-existing files
that were deployed before the tracking was introduced. Bootstrap shadow from
current deployed content -- this makes the first post-bootstrap auto-merge process
only the NEW template changes, which is correct.

Pattern: when `get_deploy_shadow` returns empty but file exists on disk, seed
shadow with current content before attempting auto-merge.
