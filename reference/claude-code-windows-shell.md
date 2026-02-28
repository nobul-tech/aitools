# Claude Code on Windows: Shell Limitations

Claude Code's Bash tool is **hardcoded to Git Bash on Windows**. The `CLAUDE_CODE_SHELL` environment variable exists but is **broken on Windows** -- it is silently ignored regardless of how it's set.

Baseline: Claude Code 2.1.51 | Last verified: 2.1.62 (2026-02-27)

## Upstream Issues

| Issue | Title | Status |
|-------|-------|--------|
| [#7490](https://github.com/anthropics/claude-code/issues/7490) | Allow users to configure which shell the Bash tool uses | Open |
| [#25558](https://github.com/anthropics/claude-code/issues/25558) | CLAUDE_CODE_SHELL environment variable ignored on Windows | Open |
| [#5049](https://github.com/anthropics/claude-code/issues/5049) | CC native on Windows: not really shell aware | Open |
| [#16225](https://github.com/anthropics/claude-code/issues/16225) | Improve PowerShell shell configuration support for Windows | Open |
| [#20453](https://github.com/anthropics/claude-code/issues/20453) | CLAUDE_CODE_SHELL not respected on Windows | Closed (no fix) |

## What Does NOT Work

- `CLAUDE_CODE_SHELL=pwsh` as an environment variable -- ignored
- `env.CLAUDE_CODE_SHELL` in `settings.json` -- ignored
- No setting, extension, or MCP server can change the Bash tool's shell on Windows

## Working Workarounds

### Run a PowerShell command from the Bash tool

```bash
pwsh -NoProfile -Command 'Your-Command Here'
```

Single-quote the `-Command` argument so bash doesn't expand `$` variables meant for PowerShell.

### Run a .ps1 script from the Bash tool

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "path/to/script.ps1"
```

This is the pattern used by `aitools install` (see the `install` command in `scripts/aitools`).

### Multi-line PowerShell from the Bash tool

```bash
pwsh -NoProfile -Command '
  $items = Get-ChildItem -Path .
  foreach ($item in $items) {
    Write-Host $item.Name
  }
'
```

## Quoting Gotchas

| Pattern | Works? | Why |
|---------|--------|-----|
| `pwsh -Command 'Write-Host $env:PATH'` | Yes | Single quotes prevent bash expansion |
| `pwsh -Command "Write-Host $env:PATH"` | No | Bash expands `$env` (empty), PowerShell gets broken command |
| `pwsh -Command 'Write-Host "hello world"'` | Yes | Inner double quotes are fine inside outer single quotes |
| `pwsh -Command "Write-Host 'hello world'"` | Risky | Bash may expand special chars in the outer double quotes |

**Rule of thumb:** Always single-quote the outer `-Command` string. Use double quotes inside for PowerShell string interpolation.

## Recommended Pattern: Write-then-Execute

For anything beyond a trivial one-liner, **do not use inline `-Command`**. The quoting rules above become unmanageable for multi-statement scripts with variables, loops, or string interpolation.

**Default pattern**: Write the PowerShell code to a temp `.ps1` file using the Write tool, then execute with `-File`:

```bash
# Step 1: Use the Write tool to create a temp .ps1 file with full PS syntax
# Step 2: Execute it cleanly — no quoting issues
pwsh -NoProfile -ExecutionPolicy Bypass -File "path/to/temp.ps1"
# Step 3: Delete the temp file when done
```

Benefits:
- No escaping between bash and PowerShell
- Full PowerShell syntax — readable, editable with the Edit tool
- Same pattern works for validation scripts
- Tools like pandoc, git, etc. resolve correctly in the script's PATH context

**Only use inline `-Command`** for trivial one-liners where a temp file would be overkill (e.g., `pwsh -Command '$PSVersionTable.PSVersion'`).

## Impact on This Repo

This repo provides both `.ps1` and `.sh` variants of all scripts. On Windows, Claude Code can run `.sh` scripts natively (Git Bash) but must use the `pwsh -File` workaround for `.ps1` scripts. PS 7 (`pwsh`) is the project baseline -- all dispatch uses `pwsh`, not `powershell.exe`.

Once Anthropic fixes the upstream issues, we can simplify by setting `CLAUDE_CODE_SHELL=pwsh` and running `.ps1` scripts directly.
