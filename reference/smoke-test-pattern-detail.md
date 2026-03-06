# Smoke Test Pattern — Detail

## Single script (Windows / PS1)

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\jdpal\repos\aitools\scripts\setup-foo.ps1" > /tmp/smoke-foo.log 2>&1
echo "exit: $?"
```

## Single script (macOS / bash)

```bash
bash scripts/setup-foo.sh > /tmp/smoke-foo.log 2>&1
echo "exit: $?"
```

## Platform dispatch

On Windows (Git Bash), always use `pwsh -File` for `.ps1`. Never run `.sh`
setup scripts on Windows (PSO: platform-native dispatch).

On macOS, run `.sh` directly. PS1 validation via `pwsh -File` if pwsh is
installed (managed tool).

## Inspecting results

If exit != 0, read the log with the Read tool.
If exit == 0 and you need to verify specific output, use Grep on the log file.

**Windows path note**: Git Bash `/tmp/` maps to `%LOCALAPPDATA%\Temp\` (e.g.,
`C:\Users\<user>\AppData\Local\Temp\`). The Read and Grep tools need the
Windows path. Use `cygpath -w /tmp/smoke-foo.log` to get it, or use the
known mapping directly.

## Full install

```bash
# Windows
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\jdpal\repos\aitools\scripts\aitools-install.ps1" > /tmp/smoke-install.log 2>&1
echo "exit: $?"

# macOS
bash scripts/aitools-install.sh > /tmp/smoke-install.log 2>&1
echo "exit: $?"
```

Then verify with Grep:
- `grep -c '\[error\]' /tmp/smoke-install.log` — should be 0
- `grep '\[ERR\]' /tmp/smoke-install.log` — summary panel errors

## Cleanup

Delete log files after reading: `rm /tmp/smoke-*.log`

## Why not inline?

- Setup scripts produce 50-200+ lines with ANSI colors, winget progress bars, download stats
- Bash tool result becomes unwieldy; pass/fail buried in noise
- Interactive prompts (winget agreements) can hang — scripts already handle these with `--accept-source-agreements` but output is still verbose
