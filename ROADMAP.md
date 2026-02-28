# Roadmap

Active and planned work items for the ai-tooling project.
Detailed plans live in `plans/`. See `RELEASE_NOTES.md` for completed work.

## In Progress

| Item | Plan | Priority | Summary |
|------|------|----------|---------|

## Planned

| Item | Plan | Priority | Summary |
|------|------|----------|---------|
| Chrome DevTools research subagent | -- | Medium | Custom subagent type for web doc reading tasks. Passes proper context (rules, CLAUDE.md) and uses Chrome DevTools MCP skill. Enables parallel doc fetches without losing project rules. |
| Tool lifecycle gaps | -- | Medium | Security/credential docs, cleanup for all tools, troubleshooting guides, ~~version management~~, CVE response, deprecation path |
| Log location discoverability | -- | Medium | Document log paths (`deploy.log`, `clip2md.log`, `checks.log`, `checks.jsonl`) in CLAUDE.md, README, and rules. Add `aitools logs` command to open/tail/clear logs. Assess log rotation and management. |
| Conditional template blocks | [#5](https://github.com/nobul-jose/ai-tooling/issues/5) | Medium | Platform-gated sections in CLAUDE.md templates (e.g., `{{#if WINDOWS}}...{{/if}}`). Enables Windows-only or macOS-only coaching/rules without auto-memory. |
| clip2: unified clipboard command | [#3](https://github.com/nobul-jose/ai-tooling/issues/3) | Medium | Refactor `clip2md` into `clip2` with format subcommands (`md`, `pdf`). Requires PDF tool evaluation. |
| Session search & view | [#4](https://github.com/nobul-jose/ai-tooling/issues/4) | Low | `aitools sessions search <query>` and `sessions view <file>` for working with archived transcripts |

## Completed

*Completed items move to RELEASE_NOTES.md.*

| Item | Version | Summary |
|------|---------|---------|
| Error handling audit | v0.22 | Error handling rules, full script audit, 5 violations + 4 logic bugs fixed |
| Rust as managed tool | v0.22 | Full lifecycle: setup scripts, installer, deploy, aliases |
| Check script logging | v0.22 | File logging (`checks.log`/`checks.jsonl`), OS guards, `StepPass` detail support |
| Per-platform tool approval | v0.22 | Platform status fields present in all tool entries |
| User repo & session archive | v0.22 | Phases A+B, bugs #1/#2, v2 profiles, template interpolation, multi-machine init |
| Interactive clobber protection | v0.21 | `--dry-run`/`--force` flags, clobber detection, corrupt file handling, PS1 node-free conversion |
