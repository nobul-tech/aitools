## Summary

Records the 2026-10-21 nesting probe in `reference/tool-ops-claude-code.md` ("Sub-agent Nesting Depth"), and re-verifies item #27 at 2.1.307.

| Launched via | Has Agent | Has Workflow | Deepest level that ran |
|---|---|---|---|
| Agent tool from the main session | yes at levels 1-2, no at level 3 | no | 3 |
| A Workflow `agent()` call | no | no | 1 |

It also records that worktree-isolated agents refuse commands that set `HOME`.

Commander-approved text (protected file).

## Commits

- afaa7ed tool-ops-claude-code: launch path decides whether delegates can delegate

## Verification

- Two probes on Claude Code 2.1.307 (macOS): an Agent-tool chain and a Workflow agent. Each level reported its tool list and `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (unset at every level).
- The L2 and L3 entries come from the L2 agent's own report.
- Not run: pre-commit/pre-push. The change is docs-only, and pre-commit step 6 fails on main regardless (a harvesting `.sh` file is tracked as 100644).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
