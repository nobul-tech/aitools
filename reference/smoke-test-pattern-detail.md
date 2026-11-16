# Smoke Test Pattern — Detail

## Single script (Windows / PS1)

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE\repos\aitools\scripts\setup-foo.ps1" > .scratch/smoke-foo.log 2>&1
echo "exit: $?"
```

## Single script (macOS / bash)

```bash
bash scripts/setup-foo.sh > .scratch/smoke-foo.log 2>&1
echo "exit: $?"
```

## Platform dispatch

On Windows (Git Bash), always use `pwsh -File` for `.ps1`. Never run `.sh`
setup scripts on Windows (`@.claude/rules/cross-platform.md` "OS guard + dispatch rule").

On macOS, run `.sh` directly. PS1 validation via `pwsh -File` if pwsh is
installed (managed tool).

## Inspecting results

If exit != 0, read the log with the Read tool.
If exit == 0 and you need to verify specific output, use Grep on the log file.

## Full install

```bash
# Windows
pwsh -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE\repos\aitools\scripts\aitools-install.ps1" > .scratch/smoke-install.log 2>&1
echo "exit: $?"

# macOS
bash scripts/aitools-install.sh > .scratch/smoke-install.log 2>&1
echo "exit: $?"
```

Then verify with Grep:
- `grep -c '\[error\]' .scratch/smoke-install.log` — error log lines; should be 0
- `grep '\[ERR\]' .scratch/smoke-install.log` — the panel's red lines, one per
  error: `<name> <what>: <reason>`
- `grep '\[!\]' .scratch/smoke-install.log` — the panel's yellow lines, one per
  warning, each saying what is wrong or what to do
- `grep -F '  >>  ' .scratch/smoke-install.log` — the panel's ACTION lines

The panel format is `reference/logging.md` 8.5. A green `[ok]` line means the
tool has no warning and no error; a warning never recolours a tool's line. Only
the entry point that started the run (`aitools`, `aitools install`) draws the
panel. A setup script run on its own records nothing and draws no panel
(`reference/logging.md` 8.3, "Outside a run"): check its log lines instead. To
keep a run's summary file, set `AITOOLS_PRESERVE_SUMMARY=1`: a copy is kept as
`last-summary.txt` in the log directory.

## Cleanup

Leave the logs in the session scratch directory; the SessionEnd harvester
classifies them as ephemeral. Never `rm` with a glob from the Bash tool (USO
"Simple Bash commands only").

## Why not inline?

- Setup scripts produce 50-200+ lines with ANSI colors, winget progress bars, download stats
- Bash tool result becomes unwieldy; pass/fail buried in noise
- Interactive prompts (winget agreements) can hang — scripts already handle these with `--accept-source-agreements` but output is still verbose
