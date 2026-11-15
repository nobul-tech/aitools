# Shell Integration & PATH Ownership

**Intent**: **Purpose**: Document how aitools owns shell integration and
PATH precedence so the harness resolves managed tools (uv python,
cursor-agent, brew bash) deterministically across login and
non-interactive contexts on every platform. **Scope**: The managed
marked-block convention (PATH block and Windows shell integration block),
repair and damage reporting, canonical PATH order, what aitools owns vs
preserves, the per-platform profile and rc targets, and the
`harness_python`/`Get-HarnessPython` resolver for non-interactive
contexts. NOT the setup-script internals (`scripts/setup-user-shell.*`).
NOT the tool-ops resolution/verification model (`/tool-ops`). NOT tool
install methods (`/tool-registry` skill). **Audience**: Every agent or
operator reasoning about why a managed tool resolves the way it does.

v1.1 (2026-11-13, M3-Fixes-A): `setup-user-shell` is the single owner of
the profile and rc lines (incidents #172, #173): Windows integration block,
repair, damage reporting, legacy migration; installer Step 7 only runs it.

---

## The problem this solves

A managed tool is only useful if the harness actually invokes the
*managed copy*. The failure mode is a **managed-tool shadow**: the
canonical binary is on disk and current, but another entry earlier on
`PATH` wins. The seeding case: `python3` resolving to Homebrew's
`/opt/homebrew/bin/python3` instead of the uv shim at
`~/.local/bin/python3` in the harness's non-interactive contexts
(SessionStart/SessionEnd hooks, `aitools install`, the Claude Code Bash
tool, cron/MDM), because the `~/.local/bin` prepend lived only in an
interactive `*.rc` while `brew shellenv` (login) pushed `/opt/homebrew/bin`
ahead.

The fix has two layers:

1. **Login-shell PATH ownership** — a marked block the harness owns in
   the login profile, placed last so it re-asserts precedence.
2. **A deterministic resolver** — a library function that returns the
   managed interpreter regardless of `PATH`, for contexts where no login
   profile is sourced at all.

## The managed block

aitools owns a single marked region in the **login** profile:

```
# >>> aitools managed >>>
# Owned by aitools (scripts/setup-user-shell.sh). Placed last so it re-asserts
# PATH precedence for harness-managed tools. Edit via the script, not by hand.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$PATH:$HOME/.cargo/bin"
[ -d "$HOME/go/bin" ] && export PATH="$PATH:$HOME/go/bin"
# <<< aitools managed <<<
```

### Marker convention

- Start: `# >>> aitools managed >>>`
- End: `# <<< aitools managed <<<`
- A marker is a whole line (surrounding whitespace ignored). A block runs
  from a start line to the first end line after it; everything between is
  ours.
- The block is replaced **in place** on every run. If absent, it is
  appended at end-of-file. A profile whose blocks are already current is
  not rewritten (row `managed block unchanged`, no backup); any other
  write backs the profile up first (`<profile>.bak.<UTC>`).
- Everything outside the markers is the user's and is never touched,
  except our own stray marker lines (below).
- The block is owned by `setup-user-shell.{sh,ps1}` — edit the script,
  not the profile.

### Repair and damage (incident #172)

- **Duplicate blocks** collapse to one, at the first block's position
  (row `collapsed N blocks to 1`). A marker line with no partner is
  removed.
- **Damage not guessed at**: the profile does not parse (`.ps1`: parser
  errors; `.sh`: `bash -n` fails), or a stray line of our block sits
  outside the markers (a line containing `_aitoolsLocalBin` or
  `Owned by aitools (scripts/setup-user-shell.`). Those lines are left in
  place; the run reports WARN `profile damage left in place` and an
  ACTION naming the newest clean `<profile>.bak.<UTC>` (at most one block
  of each kind, parses, no stray lines), or "repair by hand" when none
  qualifies.
- A write that would make the profile parse worse is refused (ERROR
  `managed block splice failed parse check`, profile unchanged).

### Shell integration block (Windows)

`setup-user-shell.ps1` also owns a second block in `$PROFILE`:

```
# >>> aitools shell integration >>>
# Owned by aitools (scripts/setup-user-shell.ps1). Edit via the script, not by hand.
. '<aitools clone>\shared\shell\aliases.ps1'
function aitools { & "$HOME\.local\bin\aitools.ps1" @args }
function hh { & "$HOME\.local\bin\hh.ps1" @args }
# <<< aitools shell integration <<<
```

It is separate from the PATH block because it holds a machine-specific
path and needs `aliases.ps1`, which the MDM `deploy/` copy does not ship:
there the block is not written and an existing one is left as it is (WARN
`aliases.ps1 not found`). The legacy `# aitools shell integration` /
`# ai-tooling shell integration` lines (written by `aitools-install.ps1`
Step 7 until incident #173) are migrated: the marker line, the following
lines of a known shape (dot-source of `...aliases.ps1`, `function aitools
{...}`, `function hh {...}`) and at most one blank line above it are
removed; the first other line ends the old block and is kept. The new
block takes the first legacy block's place.

### Why "placed last" matters

Re-asserting precedence at the end of the profile is what makes the fix
robust without rewriting the user's own lines. The block runs after any
earlier installer prepends (grok, antigravity); its `brew shellenv`
re-prepends Homebrew and the `~/.local/bin` line re-prepends the managed
bin dir — so the managed copies end up ahead of everything that ran
before, regardless of how messy the rest of the profile is.

## Canonical PATH order (macOS/Linux)

```
~/.local/bin  →  /opt/homebrew/bin  →  grok / antigravity / other installer bins  →  system
```

- `~/.local/bin` first — uv python shims and `cursor-agent` win.
- `/opt/homebrew/bin` second — brew bash 5.x wins over system bash 3.2,
  and ahead of unmanaged installer bins.
- Unmanaged installer bins (grok, antigravity) sit behind — reachable
  by name, never shadowing a managed tool.

## What aitools owns vs preserves

| | |
|---|---|
| **Owns** | The marked blocks (`setup-user-shell`): PATH block in the login profile, shell integration block in `$PROFILE`, and the two `# aitools shell integration` / `source "<aitools>/shared/shell/aliases.sh"` lines in the rc files. The `agent → cursor-agent` symlink in `~/.local/bin` is owned by `setup-user-cursor` (step 2b) |
| **Preserves** | Everything outside the markers — user aliases, unmanaged installer lines, completions, prompt config |

The interactive `*.rc` (`~/.bashrc`, and `~/.zshrc` when it exists) keeps
only the `source aliases.sh` line, written by `setup-user-shell.sh`
(appended when the marker line is missing, left alone when present; the
legacy `# ai-tooling` pair is removed). PATH ownership lives in the login
profile, not the rc. `aitools-install` Step 7 only runs `setup-user-shell`.

## Per-platform targets

| Platform | Login profile (PATH block) | Interactive rc (aliases) |
|----------|----------------------------|--------------------------|
| macOS/Linux (bash) | `~/.bash_profile` | `~/.bashrc` (created if absent), `~/.zshrc` (only if it exists) — all three written by `setup-user-shell.sh` |
| Windows (PowerShell) | `$PROFILE` | `$PROFILE` (shell integration block) |

zsh is not handled: a zsh login shell (macOS default) does not read
`~/.bash_profile`, so the managed block does not apply there; the harness's
own non-interactive contexts use `harness_python` (below). (Gap, not decided.)

On Windows there is no brew; the managed block prepends `$HOME\.local\bin`
(the aitools/uv bin dir) for the session. The macOS/Linux login shell is
read by Terminal.app when its shell is set to brew bash.

## The deterministic resolver (non-interactive contexts)

The login-profile block fixes interactive and login-inheriting shells. It
does **not** help a raw `bash -c` from launchd/cron/MDM, which sources no
profile. For those, harness code resolves the managed interpreter
directly:

- Bash: `harness_python` in `@scripts/aitools-lib.sh`
- PowerShell: `Get-HarnessPython` in `@scripts/aitools-lib.ps1`

Both prefer the uv shim (`~/.local/bin/python3`), then fall back to a
`PATH` lookup. Harness code that needs Python and can source the library
(e.g. `@scripts/aitools-dashboard.sh` `find_python`) calls the resolver
rather than a bare `python3`.

**Hooks are the exception.** Hook scripts (`shared/hooks/*.sh`) are
standalone deployed files and **cannot source the library** (see
`@.claude/rules/cross-platform.md`). A hook that needs the managed
interpreter must inline the shim preference
(`PY="$HOME/.local/bin/python3"; [ -x "$PY" ] || PY=python3`) rather than
call `harness_python`.

## Origin

Design record: `plans/tooling-resolution-and-artifact-registry.md`
(Workstream A). Seeded by `aitools install` on nobul-mac reporting
`python3` resolving to Homebrew's interpreter in non-interactive contexts.

## Cross-references

- Setup script: `@scripts/setup-user-shell.sh` / `@scripts/setup-user-shell.ps1`
- Install wiring: `@scripts/aitools-install.sh` / `.ps1` (Step 7, runs `setup-user-shell` only)
- Tests: `tests/setup-user-shell/test-setup-user-shell.ps1` (Windows) and `.sh` (macOS/Linux)
- Resolver: `harness_python` / `Get-HarnessPython` in `@scripts/aitools-lib.sh` / `.ps1`
- Cross-platform shell rules: `@.claude/rules/cross-platform.md`
- Tool-ops resolution/verification model: `/tool-ops` skill
- Tool install methods: `/tool-registry` skill
