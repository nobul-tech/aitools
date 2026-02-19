## Concurrent Agent Coordination (this repo)

Multiple AI agents (Claude Code, Cursor Agent CLI) may edit this codebase concurrently.

Before editing a file, run `git diff` to check for unexpected changes from another agent session.

When modifying rules in `.claude/rules/*.md`, also update the corresponding `.cursor/rules/*.mdc` file (and vice versa). See the Rule Correspondence table in `reference/cursor-practices.md`.
