# Roadmap

Active and planned work items for the ai-tooling project.
Detailed plans live in `plans/`. See `RELEASE_NOTES.md` for completed work.

## In Progress

| Item | Plan | Priority | Summary |
|------|------|----------|---------|
| Per-platform tool approval | [plan](plans/per-platform-tool-approval.md) | High | Separate tool approval pipeline per platform (macOS/Windows) |
| User repo & session archive | [plan](plans/user-repo-and-session-hooks.md) | High | Phase A+B implemented. Bugs #1/#2 fixed. v2 profiles, template interpolation, multi-machine user init. |

## Planned

| Item | Plan | Priority | Summary |
|------|------|----------|---------|
| Tool lifecycle gaps | -- | Medium | Security/credential docs, cleanup for all tools, troubleshooting guides, ~~version management~~, CVE response, deprecation path |
| Log location discoverability | -- | Medium | Document log paths (deploy.log, clip2md.log) in CLAUDE.md, README, and rules. Add `aitools logs` command to open/tail/clear logs. Assess log rotation and management. |
| clip2: unified clipboard command | [#3](https://github.com/nobul-jose/ai-tooling/issues/3) | Medium | Refactor `clip2md` into `clip2` with format subcommands (`md`, `pdf`). Requires PDF tool evaluation. |
| Session search & view | [#4](https://github.com/nobul-jose/ai-tooling/issues/4) | Low | `aitools sessions search <query>` and `sessions view <file>` for working with archived transcripts |

## Completed

*Completed items move to RELEASE_NOTES.md.*
