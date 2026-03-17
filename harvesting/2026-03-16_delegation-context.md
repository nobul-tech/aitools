# Delegation Context for Subagents

## Standing Orders (MUST follow)

- **Dedicated tools for file ops**: Use Read/Edit/Write/Grep/Glob for file
  operations. Bash is for shell execution only.
- **Scratch files for complex scripting**: Never inline long commands in Bash.
  Write to the session scratch directory, execute from there.
  Session scratch dir: `/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/`
- **Simple Bash commands only**: No `$(...)`, backticks, `&&`, `||`, `;` in
  destructive commands. For sequential commands, make separate Bash calls.
- **No silent failures in reusable code**: Never suppress errors without
  checking results.

## Scratch Skill (condensed)

All temp files go in: `/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/`

| File | Name | Purpose |
|------|------|---------|
| Temp script | `task-<name>.sh` | Complex commands |
| Output capture | `<name>.log` | Captured output |

Pattern for complex scripts:
```bash
cat > "/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/task-NAME.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
# ... logic ...
SCRIPT
bash "/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/task-NAME.sh"
```

## Script Standards (condensed — from .claude/rules/script-standards.md)

- All reusable scripts: structured logging (log/log_ok/log_error/log_warn)
- Block order: shebang, set -euo pipefail, source aitools-lib, logging_init, OS guard, body, exit footer
- Error suppression must have immediate result check
- Cross-platform grep: never `grep -P`, use `perl -ne` or `grep -E`
- Exit footer: check $ERRORS + $WARNINGS, exit 1 on errors

## Cross-Platform Rule (condensed — from .claude/rules/cross-platform.md)

- `.sh` targets macOS/Linux, `.ps1` targets Windows
- EXCEPTION: hooks and build-deploy.sh run bash on ALL platforms
- Hooks must work on macOS BSD AND Windows Git Bash (GNU coreutils)
- Known differences: `stat -f` (BSD) vs `stat -c` (GNU), `date` flags,
  path separators
- After creating .sh files on Windows: `git update-index --chmod=+x`

## Project Context

Working directory: `/Users/pepe/repos/aitools`
This is the aitools repo — cross-platform tool lifecycle management CLI.
Mission: one CLI for tool installs, configs, AI context orchestration.

## Report Format

Write findings to a file in the session scratch directory:
`/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/<assigned-filename>`

Return a brief summary in your response, noting where the full report was saved.
